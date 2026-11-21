AddCSLuaFile()

ENT.Type        = "anim"
ENT.Base        = "base_anim"
ENT.PrintName   = "Rick's Green Portal"
ENT.Author      = "Rick Sanchez"
ENT.Category    = "Rick and Morty"
ENT.Spawnable   = true
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "LinkedPortal")
	self:NetworkVar("Float",  0, "BirthTime")
	self:NetworkVar("Float",  1, "CloseTime")
	self:NetworkVar("Bool",   0, "IsClosing")
	self:NetworkVar("Bool",   1, "IsFloorPortal")
	self:NetworkVar("Bool",   2, "IsMidAir")
end

local MORPH_DURATION = 0.85
local CLOSE_DURATION = 0.40
local PORTAL_RADIUS  = 52

if SERVER then
	function ENT:SpawnFunction(ply, tr, className)
		if not tr.Hit then return end
		local ent = ents.Create(className)
		local normal = tr.HitNormal
		ent:SetPos(tr.HitPos + normal * 2.5)
		ent:SetAngles(normal:Angle())
		ent:SetOwner(ply)
		ent:SetIsFloorPortal(normal.z > 0.65)
		ent:SetIsMidAir(false)
		ent:Spawn()
		ent:Activate()
		return ent
	end

	function ENT:Initialize()
		-- Keep color alpha 255 and NoDraw FALSE so Source Engine ALWAYS calls ENT:Draw / ENT:DrawTranslucent!
		self:SetModel("models/hunter/plates/plate2x2.mdl")
		self:DrawShadow(false)

		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_BBOX)
		self:SetCollisionBounds(Vector(-28, -50, -58), Vector(28, 50, 58))
		self:SetTrigger(true)
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)

		self:SetBirthTime(CurTime())
		self:SetIsClosing(false)
		self.TeleportCooldowns = {}

		self:EmitSound("RickPortal.Open")

		local lifeCvar = GetConVar("sv_rickportal_lifetime")
		if lifeCvar and lifeCvar:GetFloat() > 0 then
			self.ExpireAt = CurTime() + lifeCvar:GetFloat()
		end
	end

	function ENT:CloseSmoothly()
		if self:GetIsClosing() then return end
		self:SetIsClosing(true)
		self:SetCloseTime(CurTime())
		self:EmitSound("RickPortal.Close")

		local linked = self:GetLinkedPortal()
		if IsValid(linked) and linked:GetLinkedPortal() == self then
			linked:SetLinkedPortal(NULL)
		end
		self:SetLinkedPortal(NULL)
	end

	function ENT:TeleportEntity(ent)
		if not IsValid(ent) then return end
		if self:GetIsClosing() then return end

		if (CurTime() - self:GetBirthTime()) < (MORPH_DURATION * 0.55) then return end

		local dest = self:GetLinkedPortal()
		if not IsValid(dest) or dest:GetIsClosing() then return end
		if (CurTime() - dest:GetBirthTime()) < (MORPH_DURATION * 0.50) then return end

		local now = CurTime()
		if (self.TeleportCooldowns[ent] or 0) > now then return end
		if (dest.TeleportCooldowns and (dest.TeleportCooldowns[ent] or 0) > now) then return end

		local isPlayer = ent:IsPlayer()
		local isNPC = ent:IsNPC() or ent:IsNextBot()
		local phys = ent:GetPhysicsObject()
		if not isPlayer and not isNPC and not IsValid(phys) then return end

		local cls = ent:GetClass()
		if cls == "ent_rick_portal" or cls == "ent_rick_portal_blob" or cls == "ent_omega_device" or cls == "ent_past_self_clone" then
			return
		end

		self.TeleportCooldowns[ent] = now + 0.55
		dest.TeleportCooldowns = dest.TeleportCooldowns or {}
		dest.TeleportCooldowns[ent] = now + 0.55

		local outNormal = dest:GetForward()
		if dest:GetIsMidAir() then
			local enterRel = (ent:WorldSpaceCenter() - self:GetPos()):Dot(self:GetForward())
			if enterRel < 0 then
				outNormal = -dest:GetForward()
			end
		end

		local exitPos = dest:GetPos() + outNormal * 46

		if isPlayer or isNPC then
			if dest:GetIsFloorPortal() then
				exitPos = dest:GetPos() + Vector(0, 0, 18)
				outNormal = Vector(0, 0, 1)
			elseif outNormal.z < -0.55 then
				exitPos = dest:GetPos() + outNormal * 76
			else
				exitPos = dest:GetPos() + outNormal * 48 - Vector(0, 0, 34)
				local trFloor = util.TraceLine({
					start = exitPos + Vector(0, 0, 36),
					endpos = exitPos - Vector(0, 0, 12),
					mask = MASK_PLAYERSOLID_BRUSHONLY
				})
				if trFloor.Hit then
					exitPos.z = math.max(exitPos.z, trFloor.HitPos.z + 4)
				end
			end

			if isPlayer then
				local mins, maxs = ent:GetHull()
				local trHull = util.TraceHull({
					start = exitPos + outNormal * 8,
					endpos = exitPos,
					mins = mins,
					maxs = maxs,
					filter = { ent, dest, self },
					mask = MASK_PLAYERSOLID
				})
				if trHull.StartSolid then
					exitPos = dest:GetPos() + outNormal * 64
				end
			end
		end

		local inVel = isPlayer and ent:GetVelocity() or (IsValid(phys) and phys:GetVelocity() or ent:GetVelocity())
		local speed = math.max(inVel:Length(), dest:GetIsFloorPortal() and 340 or 230)
		local outVel = outNormal * speed

		if isPlayer then
			ent:SetPos(exitPos)
			local flatNormal = Vector(outNormal.x, outNormal.y, 0)
			if flatNormal:LengthSqr() > 0.05 then
				local newEye = flatNormal:Angle()
				newEye.p = math.Clamp(ent:EyeAngles().p, -45, 45)
				newEye.r = 0
				ent:SetEyeAngles(newEye)
			end
			ent:SetLocalVelocity(outVel)
			ent:ScreenFade(SCREENFADE.IN, Color(115, 245, 75, 110), 0.28, 0.02)
		elseif isNPC then
			ent:SetPos(exitPos)
			ent:SetVelocity(outVel)
		elseif IsValid(phys) then
			ent:SetPos(exitPos)
			phys:Wake()
			phys:SetVelocity(outVel)
		end

		self:EmitSound("RickPortal.Enter")
		dest:EmitSound("RickPortal.Enter")
	end

	function ENT:StartTouch(ent)
		self:TeleportEntity(ent)
	end

	function ENT:Touch(ent)
		self:TeleportEntity(ent)
	end

	function ENT:Think()
		local now = CurTime()

		if self:GetIsClosing() then
			if (now - self:GetCloseTime()) >= CLOSE_DURATION then
				self:Remove()
				return
			end
			self:NextThink(now + 0.05)
			return true
		end

		if self.ExpireAt and now >= self.ExpireAt then
			self:CloseSmoothly()
			return
		end

		if IsValid(self:GetLinkedPortal()) and (now - self:GetBirthTime()) >= (MORPH_DURATION * 0.55) then
			local myPos = self:GetPos()
			local myFwd = self:GetForward()
			for _, ent in ipairs(ents.FindInSphere(myPos, PORTAL_RADIUS * 0.96)) do
				if ent ~= self and (ent:IsPlayer() or ent:IsNPC() or IsValid(ent:GetPhysicsObject())) then
					local center = ent:WorldSpaceCenter()
					local rel = center - myPos
					local planeDist = math.abs(rel:Dot(myFwd))
					local radialDist = (rel - myFwd * rel:Dot(myFwd)):Length()
					if planeDist < 38 and radialDist < (PORTAL_RADIUS * 0.92) then
						self:TeleportEntity(ent)
					end
				end
			end
		end

		self:NextThink(now + 0.04)
		return true
	end
end

if CLIENT then
	local matSwirl      = Material("rick_portal/portal_swirl.png", "smooth mips")
	local matInnerSwirl = Material("rick_portal/portal_inner_swirl.png", "smooth mips")
	local matBlob       = Material("rick_portal/liquid_blob.png", "smooth mips")
	local matGlow       = Material("sprites/light_glow02_add")

	local matSplashVTF = CreateMaterial("RickPortal_SplashVTF_v3", "UnlitGeneric", {
		["$basetexture"] = "sprites/light_glow02",
		["$additive"]    = "1",
		["$vertexcolor"] = "1",
		["$vertexalpha"] = "1"
	})

	local matFluidDisk = CreateMaterial("RickPortal_FluidMesh_v3", "UnlitGeneric", {
		["$basetexture"] = "models/debug/debugwhite",
		["$vertexcolor"] = "1",
		["$vertexalpha"] = "1",
		["$translucent"] = "1",
		["$nocull"]      = "1"
	})

	local function EaseOutBack(t)
		local c1 = 1.42
		local c3 = c1 + 1
		return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2)
	end

	-- Pure 3D double-sided rotated quad (`render.DrawQuad` on BOTH winding orders!)
	-- Unlike `cam.Start3D2D`, `render.DrawQuad` NEVER suffers from 2D UI plane backface culling,
	-- works from BOTH sides 100% of the time, and is visible from every angle!
	local function DrawDoubleSided3DQuad(mat, center, axisRight, axisUp, halfW, halfH, rotRad, col)
		local c, s = math.cos(rotRad), math.sin(rotRad)
		local rVec = (axisRight * c + axisUp * s) * halfW
		local uVec = (-axisRight * s + axisUp * c) * halfH

		local p1 = center - rVec + uVec -- Top-Left
		local p2 = center + rVec + uVec -- Top-Right
		local p3 = center + rVec - uVec -- Bottom-Right
		local p4 = center - rVec - uVec -- Bottom-Left

		render.SetMaterial(mat)
		-- Front winding
		render.DrawQuad(p1, p2, p3, p4, col)
		-- Back winding (so looking from behind shows the exact spinning portal too!)
		render.DrawQuad(p2, p1, p4, p3, col)
	end

	-- Pure 3D wobbling organic green liquid polygon (drawn with `mesh.Begin` + `$nocull 1` so visible both sides!)
	local function Draw3DOrganicLiquid(center, axisRight, axisUp, rx, ry, ct, seed, wobbleAmt, col, segs)
		segs = segs or 32
		render.SetMaterial(matFluidDisk)

		mesh.Begin(MATERIAL_TRIANGLES, segs)
		for i = 0, segs - 1 do
			local a1 = (i / segs) * math.pi * 2
			local a2 = ((i + 1) / segs) * math.pi * 2

			local m1 = 1.0 + (math.sin(a1 * 3 + ct * 4.2 + seed) * 0.42 + math.cos(a1 * 5 - ct * 5.8 + seed * 1.7) * 0.33 + math.sin(a1 * 8 + ct * 7.5) * 0.25) * wobbleAmt
			local m2 = 1.0 + (math.sin(a2 * 3 + ct * 4.2 + seed) * 0.42 + math.cos(a2 * 5 - ct * 5.8 + seed * 1.7) * 0.33 + math.sin(a2 * 8 + ct * 7.5) * 0.25) * wobbleAmt

			local v1 = center + axisRight * (math.cos(a1) * rx * m1) + axisUp * (math.sin(a1) * ry * m1)
			local v2 = center + axisRight * (math.cos(a2) * rx * m2) + axisUp * (math.sin(a2) * ry * m2)

			mesh.Position(center)
			mesh.Color(col.r, col.g, col.b, col.a)
			mesh.TexCoord(0, 0.5, 0.5)
			mesh.AdvanceVertex()

			mesh.Position(v1)
			mesh.Color(col.r, col.g, col.b, col.a)
			mesh.TexCoord(0, 0, 0)
			mesh.AdvanceVertex()

			mesh.Position(v2)
			mesh.Color(col.r, col.g, col.b, col.a)
			mesh.TexCoord(0, 1, 1)
			mesh.AdvanceVertex()
		end
		mesh.End()
	end

	function ENT:Initialize()
		self.Seed = math.Rand(0, 100)
		self.Emitter = ParticleEmitter(self:GetPos(), false)
		self.NextAmbientParticle = 0
		self.DidSplashBurst = false
		self.SplashDrops = {}
		self:SetRenderBounds(Vector(-110, -110, -110), Vector(110, 110, 110))
	end

	function ENT:OnRemove()
		if IsValid(self.Emitter) then
			self.Emitter:Finish()
		end
	end

	function ENT:SpawnSplashParticles()
		local pos   = self:GetPos()
		local fwd   = self:GetForward()
		local right = self:GetRight()
		local up    = self:GetUp()
		local ct    = CurTime()

		self.SplashDrops = {}
		for i = 1, 22 do
			local a = (i / 22) * math.pi * 2 + math.Rand(-0.18, 0.18)
			local radialDir = right * math.cos(a) + up * math.sin(a)
			self.SplashDrops[#self.SplashDrops + 1] = {
				startPos = pos + radialDir * math.Rand(2, 9),
				vel      = radialDir * math.Rand(65, 145) + fwd * math.Rand(-28, 35),
				birth    = ct,
				dur      = math.Rand(0.45, 0.85),
				size     = math.Rand(11, 21)
			}
		end

		if IsValid(self.Emitter) then
			self.Emitter:SetPos(pos)
			for i = 1, 22 do
				local a = (i / 22) * math.pi * 2 + math.Rand(-0.15, 0.15)
				local radialDir = right * math.cos(a) + up * math.sin(a)
				local p = self.Emitter:Add(matSplashVTF, pos + radialDir * math.Rand(2, 10))
				if p then
					p:SetVelocity(radialDir * math.Rand(55, 130) + fwd * math.Rand(-25, 25))
					p:SetDieTime(math.Rand(0.45, 0.85))
					p:SetStartAlpha(255)
					p:SetEndAlpha(0)
					p:SetStartSize(math.Rand(12, 22))
					p:SetEndSize(math.Rand(2, 5))
					p:SetColor(135, 250, 68)
					p:SetGravity(Vector(0, 0, -140))
					p:SetAirResistance(90)
				end
			end
		end
	end

	function ENT:Think()
		local ct  = CurTime()
		local pos = self:GetPos()

		if not self.DidSplashBurst then
			self.DidSplashBurst = true
			self:SpawnSplashParticles()
		end

		if IsValid(self.Emitter) and ct >= self.NextAmbientParticle and not self:GetIsClosing() then
			self.NextAmbientParticle = ct + 0.065
			self.Emitter:SetPos(pos)

			local a = math.Rand(0, math.pi * 2)
			local isFloor = self:GetIsFloorPortal()
			local rx = isFloor and 48 or 44
			local ry = isFloor and 48 or 56
			local rimPos = pos + self:GetRight() * (math.cos(a) * rx) + self:GetUp() * (math.sin(a) * ry)

			local p = self.Emitter:Add(matSplashVTF, rimPos)
			if p then
				p:SetVelocity(VectorRand() * 20)
				p:SetDieTime(math.Rand(0.45, 0.85))
				p:SetStartAlpha(235)
				p:SetEndAlpha(0)
				p:SetStartSize(math.Rand(8, 14))
				p:SetEndSize(1)
				p:SetColor(150, 252, 78)
				p:SetGravity(Vector(0, 0, -45))
				p:SetAirResistance(60)
			end
		end

		local dlightConVar = GetConVar("cl_rickportal_dlight")
		if not dlightConVar or dlightConVar:GetBool() then
			local age = ct - self:GetBirthTime()
			local openFrac = math.Clamp(age / MORPH_DURATION, 0, 1)
			local closeFrac = self:GetIsClosing() and (1.0 - math.Clamp((ct - self:GetCloseTime()) / CLOSE_DURATION, 0, 1)) or 1.0
			local pulse = 1.0 + math.sin(ct * 5.2 + (self.Seed or 0)) * 0.12

			local dl = DynamicLight(self:EntIndex())
			if dl then
				dl.pos = pos + self:GetForward() * 6
				dl.r = 95
				dl.g = 242
				dl.b = 62
				dl.brightness = 3.0 * openFrac * closeFrac * pulse
				dl.Decay = 1000
				dl.Size = 275 * openFrac * closeFrac
				dl.DieTime = ct + 0.08
			end
		end
	end

	function ENT:Draw()
		-- Do not call self:DrawModel() so plate2x2 is invisible;
		-- DrawTranslucent renders the full 3D double-sided green portal!
	end

	function ENT:DrawTranslucent()
		local ct    = CurTime()
		local pos   = self:GetPos()
		local fwd   = self:GetForward()
		local right = self:GetRight()
		local up    = self:GetUp()
		local seed  = self.Seed or 0

		local age    = math.max(0, ct - self:GetBirthTime())
		local morphT = math.Clamp(age / MORPH_DURATION, 0, 1)

		local closeMult = 1.0
		if self:GetIsClosing() then
			local cT = math.Clamp((ct - self:GetCloseTime()) / CLOSE_DURATION, 0, 1)
			closeMult = math.pow(1.0 - cT, 1.6)
		end

		-- Soft emerald atmospheric glow behind & around the portal
		render.SetMaterial(matGlow)
		render.DrawSprite(pos, 155 * morphT * closeMult, 175 * morphT * closeMult, Color(105, 245, 70, 130))

		-- 3D Cartoon splash droplets during opening
		if self.SplashDrops and #self.SplashDrops > 0 then
			render.SetMaterial(matBlob)
			for i = #self.SplashDrops, 1, -1 do
				local d = self.SplashDrops[i]
				local dt = ct - d.birth
				if dt >= d.dur then
					table.remove(self.SplashDrops, i)
				else
					local frac = dt / d.dur
					local curP = d.startPos + d.vel * dt * (1.0 - frac * 0.45) + Vector(0, 0, -90 * dt * dt)
					local sz = d.size * (1.0 - frac * 0.8)
					render.DrawSprite(curP, sz, sz, Color(160, 242, 78, 255 * (1.0 - frac)))
				end
			end
		end

		local isFloor = self:GetIsFloorPortal()
		local halfW_Base = isFloor and 55 or 47
		local halfH_Base = isFloor and 55 or 60

		local breatheX = 1.0 + math.sin(ct * 2.6 + seed) * 0.048 + math.cos(ct * 5.9 + seed * 2) * 0.022
		local breatheY = 1.0 + math.cos(ct * 2.3 + seed * 1.3) * 0.052 + math.sin(ct * 5.1 + seed) * 0.024

		local growCurve = EaseOutBack(morphT) * closeMult
		local liquidPhase = math.Clamp(1.0 - (morphT - 0.15) / 0.75, 0, 1)
		if self:GetIsClosing() then
			liquidPhase = math.Clamp(liquidPhase + (1.0 - closeMult) * 0.85, 0, 1)
		end

		local hw = halfW_Base * (0.14 + 0.86 * growCurve) * breatheX
		local hh = halfH_Base * (0.14 + 0.86 * growCurve) * breatheY

		-- 1) Organic Wobbling 3D Green Liquid Rim & Morphing Fluid Mass (visible from both sides!)
		local wobble = 0.045 + liquidPhase * 0.26
		Draw3DOrganicLiquid(pos, right, up, hw * 0.97, hh * 0.97, ct, seed, wobble, Color(156, 218, 76, 250), 36)

		if liquidPhase > 0.02 then
			local liqAlpha = math.floor(255 * liquidPhase)
			Draw3DOrganicLiquid(pos + fwd * 0.15, right, up, hw * 0.70, hh * 0.70, ct * 1.3, seed + 4.2, wobble * 1.25, Color(42, 152, 62, liqAlpha), 28)
			Draw3DOrganicLiquid(pos - fwd * 0.15, right, up, hw * 0.70, hh * 0.70, ct * 1.3, seed + 4.2, wobble * 1.25, Color(42, 152, 62, liqAlpha), 28)

			for i = 1, 8 do
				local orbAng = (i / 8) * math.pi * 2 + ct * (3.8 - morphT * 1.5) + seed
				local spread = (0.55 + math.sin(ct * 7 + i) * 0.22) * (0.5 + liquidPhase * 0.75)
				local bCenter = pos + right * (math.cos(orbAng) * hw * spread) + up * (math.sin(orbAng) * hh * spread)
				local bRad = (6.0 + (i % 3) * 2.8) * (0.4 + growCurve * 0.6) * liquidPhase
				DrawDoubleSided3DQuad(matBlob, bCenter, right, up, bRad, bRad * 0.88, orbAng + ct * 1.5, Color(168, 236, 82, liqAlpha))
			end
		end

		-- 2) Multi-Layered Spinning Rick & Morty Green Portal Vortex (offset ±0.35..0.65u so ZERO Z-fighting and 100% double-sided!)
		local swirlAlpha = math.Clamp((morphT - 0.10) / 0.62, 0, 1) * 255
		if swirlAlpha > 1 then
			local spinBase  = math.rad(ct * 46 + math.sin(ct * 1.35 + seed) * 16 + (1.0 - morphT) * 110)
			local spinInner = math.rad(-ct * 31 + math.cos(ct * 1.9 + seed) * 22)
			local spinCore  = math.rad(ct * 78 + math.sin(ct * 2.7) * 18)

			-- Layer A: Main Rick & Morty Swirl (Front & Back planes slightly separated from liquid core)
			DrawDoubleSided3DQuad(matSwirl, pos + fwd * 0.35, right, up, hw, hh, spinBase, Color(255, 255, 255, swirlAlpha))
			DrawDoubleSided3DQuad(matSwirl, pos - fwd * 0.35, right, up, hw, hh, -spinBase, Color(255, 255, 255, swirlAlpha))

			-- Layer B: Counter-spinning Deformed Inner Vortex
			local pIn = 0.78 + math.sin(ct * 3.4 + seed) * 0.08
			local drift = right * (math.sin(ct * 2.9 + seed) * 1.5) + up * (math.cos(ct * 2.5 + seed) * 1.5)
			DrawDoubleSided3DQuad(matInnerSwirl, pos + fwd * 0.55 + drift, right, up, hw * pIn, hh * pIn, spinInner, Color(195, 255, 145, swirlAlpha * 0.65))
			DrawDoubleSided3DQuad(matInnerSwirl, pos - fwd * 0.55 + drift, right, up, hw * pIn, hh * pIn, -spinInner, Color(195, 255, 145, swirlAlpha * 0.65))

			-- Layer C: Fast Hypnotic Center Vortex Eye
			local eyeS = 0.44 + math.cos(ct * 4.3 + seed) * 0.06
			DrawDoubleSided3DQuad(matInnerSwirl, pos + fwd * 0.72, right, up, hw * eyeS, hh * eyeS, spinCore, Color(150, 245, 105, swirlAlpha * 0.80))
			DrawDoubleSided3DQuad(matInnerSwirl, pos - fwd * 0.72, right, up, hw * eyeS, hh * eyeS, -spinCore, Color(150, 245, 105, swirlAlpha * 0.80))
		end
	end
end
