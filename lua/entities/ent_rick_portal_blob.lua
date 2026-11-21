AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Rick's Portal Fluid"
ENT.Author    = "Rick Sanchez (C-137)"
ENT.Spawnable = false

function ENT:SetupDataTables()
	self:NetworkVar("Vector", 0, "StartPos")
	self:NetworkVar("Vector", 1, "LaunchDir")
	self:NetworkVar("Float",  0, "MaxTravelDist")
	self:NetworkVar("Int",    0, "PortalSlot") -- 1 = Primary (LMB), 2 = Secondary (RMB)
end

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/Combine_Helicopter/helicopter_bomb01.mdl")
		self:SetModelScale(0.2, 0)
		self:DrawShadow(false)

		self:PhysicsInitSphere(4, "default_silent")
		self:SetMoveType(MOVETYPE_FLY)
		self:SetSolid(SOLID_BBOX)
		self:SetCollisionBounds(Vector(-4, -4, -4), Vector(4, 4, 4))
		self:SetCollisionGroup(COLLISION_GROUP_PROJECTILE)

		self.SpawnTime   = CurTime()
		self.LastPos     = self:GetPos()
		self.Speed       = 1150
		self.Transformed = false

		local dir = self:GetLaunchDir()
		if dir:LengthSqr() < 0.01 then
			dir = self:GetForward()
		end
		dir:Normalize()
		self:SetVelocity(dir * self.Speed)

		util.SpriteTrail(self, 0, Color(138, 238, 72, 220), false, 16, 2, 0.28, 1 / 16, "trails/plasma")
	end

	function ENT:TransformIntoPortal(pos, surfaceNormal, isMidAir)
		if self.Transformed then return end
		self.Transformed = true

		local owner = self:GetOwner()
		local wep   = self.WeaponRef
		local slot  = self:GetPortalSlot()
		if slot ~= 1 and slot ~= 2 then slot = 1 end

		local portal = ents.Create("ent_rick_portal")
		if IsValid(portal) then
			local portalAng
			local spawnPos = pos

			if isMidAir then
				local toShooter = IsValid(owner) and (owner:WorldSpaceCenter() - pos) or (-self:GetLaunchDir())
				toShooter.z = 0
				if toShooter:LengthSqr() < 1 then
					toShooter = -self:GetLaunchDir()
				end
				toShooter:Normalize()
				portalAng = toShooter:Angle()

				local trFloor = util.TraceLine({
					start = spawnPos,
					endpos = spawnPos - Vector(0, 0, 56),
					mask = MASK_SOLID_BRUSHONLY
				})
				if trFloor.Hit then
					local neededZ = trFloor.HitPos.z + 54
					if spawnPos.z < neededZ then
						spawnPos.z = neededZ
					end
				end
			else
				local n = surfaceNormal:GetNormalized()
				portalAng = n:Angle()
				spawnPos = pos + n * 2.5

				if math.abs(n.z) < 0.35 then
					local trDown = util.TraceLine({
						start = spawnPos,
						endpos = spawnPos - Vector(0, 0, 54),
						mask = MASK_SOLID_BRUSHONLY
					})
					if trDown.Hit then
						spawnPos.z = math.max(spawnPos.z, trDown.HitPos.z + 53)
					end
				end
			end

			portal:SetPos(spawnPos)
			portal:SetAngles(portalAng)
			portal:SetOwner(owner)
			portal:SetIsFloorPortal((not isMidAir) and (surfaceNormal.z > 0.65))
			portal:SetIsMidAir(isMidAir and true or false)
			portal:Spawn()
			portal:Activate()

			if IsValid(wep) and wep.RegisterPortal then
				wep:RegisterPortal(slot, portal)
			end
		end

		self:Remove()
	end

	function ENT:Think()
		if self.Transformed then return end

		local curPos   = self:GetPos()
		local startPos = self:GetStartPos()
		local maxDist  = self:GetMaxTravelDist()
		if maxDist <= 0 then maxDist = 420 end

		local vel = self:GetVelocity()
		local stepEnd = curPos + vel * FrameTime()
		local tr = util.TraceHull({
			start  = self.LastPos or curPos,
			endpos = stepEnd,
			mins   = Vector(-3, -3, -3),
			maxs   = Vector(3, 3, 3),
			filter = { self, self:GetOwner() },
			mask   = MASK_SOLID
		})

		if tr.Hit then
			self:TransformIntoPortal(tr.HitPos, tr.HitNormal, false)
			return
		end

		local traveled = curPos:Distance(startPos)
		local frac = traveled / maxDist
		if frac > 0.68 then
			local slowFactor = math.Clamp(1.0 - ((frac - 0.68) / 0.32) * 0.78, 0.18, 1.0)
			self:SetVelocity(self:GetLaunchDir():GetNormalized() * (self.Speed * slowFactor))
		end

		if traveled >= maxDist or (CurTime() - self.SpawnTime) > 1.8 then
			self:TransformIntoPortal(curPos, -self:GetLaunchDir(), true)
			return
		end

		self.LastPos = curPos
		self:NextThink(CurTime())
		return true
	end

	function ENT:Touch(ent)
		if self.Transformed then return end
		if ent == self:GetOwner() then return end
		if IsValid(ent) and ent:GetClass() == "ent_rick_portal" then return end

		local tr = util.TraceLine({
			start  = self.LastPos or self:GetPos(),
			endpos = self:GetPos() + self:GetLaunchDir() * 24,
			filter = { self, self:GetOwner() }
		})
		self:TransformIntoPortal(tr.Hit and tr.HitPos or self:GetPos(), tr.Hit and tr.HitNormal or (-self:GetLaunchDir()), not tr.Hit)
	end
end

if CLIENT then
	local matBlob = Material("rick_portal/liquid_blob.png", "smooth mips")
	local matGlow = Material("sprites/light_glow02_add")

	-- Built-in VTF particle material (guaranteed 100% purple-checkerboard-free in CLuaEmitter!)
	local matParticleDrop = CreateMaterial("RickPortal_FluidDropVTF_v2", "UnlitGeneric", {
		["$basetexture"] = "sprites/light_glow02",
		["$additive"]    = "1",
		["$vertexcolor"] = "1",
		["$vertexalpha"] = "1"
	})

	function ENT:Initialize()
		self.Seed     = math.Rand(0, 100)
		self.Emitter  = ParticleEmitter(self:GetPos(), false)
		self.NextDrip = 0
	end

	function ENT:OnRemove()
		if IsValid(self.Emitter) then
			self.Emitter:Finish()
		end
	end

	function ENT:Think()
		local pos = self:GetPos()

		if IsValid(self.Emitter) and CurTime() >= self.NextDrip then
			self.NextDrip = CurTime() + 0.022
			self.Emitter:SetPos(pos)

			local p = self.Emitter:Add(matParticleDrop, pos + VectorRand() * 3.5)
			if p then
				p:SetVelocity(VectorRand() * 28 - self:GetVelocity() * 0.08 + Vector(0, 0, -25))
				p:SetDieTime(math.Rand(0.28, 0.48))
				p:SetStartAlpha(255)
				p:SetEndAlpha(0)
				p:SetStartSize(math.Rand(9, 15))
				p:SetEndSize(math.Rand(2, 4))
				p:SetRoll(math.Rand(0, 360))
				p:SetRollDelta(math.Rand(-6, 6))
				p:SetColor(135, 248, 68)
				p:SetGravity(Vector(0, 0, -260))
				p:SetAirResistance(45)
			end
		end

		local dlightConVar = GetConVar("cl_rickportal_dlight")
		if not dlightConVar or dlightConVar:GetBool() then
			local dl = DynamicLight(self:EntIndex())
			if dl then
				dl.pos        = pos
				dl.r          = 95
				dl.g          = 245
				dl.b          = 65
				dl.brightness = 2.4
				dl.Decay      = 900
				dl.Size       = 160
				dl.DieTime    = CurTime() + 0.08
			end
		end
	end

	function ENT:Draw()
		local pos = self:GetPos()
		local ct  = CurTime() + (self.Seed or 0)

		render.SetMaterial(matGlow)
		render.DrawSprite(pos, 42, 42, Color(110, 255, 75, 195))

		render.SetMaterial(matBlob)
		for i = 1, 5 do
			local phase = ct * (8 + i * 1.7) + i * 2.1
			local offset = Vector(
				math.sin(phase) * 3.4,
				math.cos(phase * 1.15) * 3.4,
				math.sin(phase * 0.85 + 1.0) * 3.4
			)
			local sz = 18 + math.sin(ct * 12 + i) * 5.0
			render.DrawSprite(pos + offset, sz, sz * (0.85 + 0.25 * math.cos(phase)), Color(165, 245, 85, 250))
		end
	end
end
