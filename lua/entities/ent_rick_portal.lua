AddCSLuaFile()

ENT.Type        = "anim"
ENT.Base        = "base_anim"
ENT.PrintName   = "Rick's Green Portal"
ENT.Author      = "Rick Sanchez (C-137)"
ENT.Category    = "Rick and Morty"
ENT.Spawnable   = true
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "LinkedPortal")
	self:NetworkVar("Float",  0, "BirthTime")
	self:NetworkVar("Float",  1, "CloseTime")
	self:NetworkVar("Bool",   0, "IsClosing")
	self:NetworkVar("Bool",   1, "IsFloorPortal")
	self:NetworkVar("Bool",   2, "IsMidAir")
end

-- Duration of the green liquid -> portal transformation (in seconds)
local MORPH_DURATION = 0.88
local CLOSE_DURATION = 0.42
local PORTAL_RADIUS  = 50

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
		self:SetModel("models/hunter/plates/plate2x2.mdl")
		self:DrawShadow(false)

		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_BBOX)
		self:SetCollisionBounds(Vector(-24, -48, -56), Vector(24, 48, 56))
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

	-- Computes safe exit position & velocity when an entity steps into this portal
	function ENT:TeleportEntity(ent)
		if not IsValid(ent) then return end
		if self:GetIsClosing() then return end

		-- Wait until liquid has mostly morphed into a portal (~65% of morph)
		if (CurTime() - self:GetBirthTime()) < (MORPH_DURATION * 0.65) then return end

		local dest = self:GetLinkedPortal()
		if not IsValid(dest) or dest:GetIsClosing() then return end
		if (CurTime() - dest:GetBirthTime()) < (MORPH_DURATION * 0.55) then return end

		-- Per-entity cooldown so there is no infinite ping-pong loop
		local now = CurTime()
		if (self.TeleportCooldowns[ent] or 0) > now then return end
		if (dest.TeleportCooldowns and (dest.TeleportCooldowns[ent] or 0) > now) then return end

		local isPlayer = ent:IsPlayer()
		local isNPC = ent:IsNPC() or ent:IsNextBot()
		local phys = ent:GetPhysicsObject()
		if not isPlayer and not isNPC and not IsValid(phys) then return end
		if ent:GetClass() == "ent_rick_portal" or ent:GetClass() == "ent_rick_portal_blob" then return end

		self.TeleportCooldowns[ent] = now + 0.55
		dest.TeleportCooldowns = dest.TeleportCooldowns or {}
		dest.TeleportCooldowns[ent] = now + 0.55

		local outNormal = dest:GetForward()
		local exitPos = dest:GetPos() + outNormal * 44

		-- Keep players upright & clear of floors/walls at destination!
		if isPlayer or isNPC then
			if dest:GetIsFloorPortal() then
				exitPos = dest:GetPos() + Vector(0, 0, 18)
			elseif outNormal.z < -0.55 then
				-- Ceiling portal: drop cleanly underneath
				exitPos = dest:GetPos() + outNormal * 76
			else
				-- Wall or mid-air portal: place 46 units in front, ensure feet aren't buried in ground
				exitPos = dest:GetPos() + outNormal * 46 - Vector(0, 0, 34)
				local trFloor = util.TraceLine({
					start = exitPos + Vector(0, 0, 36),
					endpos = exitPos - Vector(0, 0, 12),
					mask = MASK_PLAYERSOLID_BRUSHONLY
				})
				if trFloor.Hit then
					exitPos.z = math.max(exitPos.z, trFloor.HitPos.z + 4)
				end
			end

			-- Final hull check so player never gets stuck inside geometry
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

		-- Preserve & redirect momentum through the portal (classic portal physics!)
		local inVel = isPlayer and ent:GetVelocity() or (IsValid(phys) and phys:GetVelocity() or ent:GetVelocity())
		local speed = math.max(inVel:Length(), dest:GetIsFloorPortal() and 340 or 230)
		local outVel = outNormal * speed

		if isPlayer then
			ent:SetPos(exitPos)
			-- Align player's horizontal view direction with exit portal normal
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

		-- Proximity scan so players walking/jumping into floor, mid-air, or wall portals ALWAYS trigger reliably!
		if IsValid(self:GetLinkedPortal()) and (now - self:GetBirthTime()) >= (MORPH_DURATION * 0.65) then
			local myPos = self:GetPos()
			local myFwd = self:GetForward()
			for _, ent in ipairs(ents.FindInSphere(myPos, PORTAL_RADIUS * 0.92)) do
				if ent ~= self and (ent:IsPlayer() or ent:IsNPC() or IsValid(ent:GetPhysicsObject())) then
					local center = ent:WorldSpaceCenter()
					local rel = center - myPos
					local planeDist = math.abs(rel:Dot(myFwd))
					local radialDist = (rel - myFwd * rel:Dot(myFwd)):Length()
					if planeDist < 34 and radialDist < (PORTAL_RADIUS * 0.88) then
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

	local unlitPolyMat = CreateMaterial("RickPortal_FluidPoly_v1", "UnlitGeneric", {
		["$basetexture"] = "color/white",
		["$vertexcolor"] = "1",
		["$vertexalpha"] = "1",
		["$translucent"] = "1",
		["$nocull"]      = "1"
	})

	-- Smooth elastic ease-out for organic liquid expansion
	local function EaseOutBack(t)
		local c1 = 1.45
		local c3 = c1 + 1
		return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2)
	end

	local function DrawTexturedRotatedQuad(mat, cx, cy, w, h, rotDeg, col)
		surface.SetMaterial(mat)
		surface.SetDrawColor(col.r, col.g, col.b, col.a)
		surface.DrawTexturedRectRotated(cx, cy, w, h, rotDeg)
	end

	-- Draws an organic, wobbling multi-vertex liquid silhouette during fluid -> portal morph
	-- AND as a living organic rim around the active portal!
	local function DrawOrganicLiquidDisk(cx, cy, rx, ry, ct, seed, wobbleAmt, col, segs)
		segs = segs or 36
		local poly = {}
		poly[#poly + 1] = { x = cx, y = cy }
		for i = 0, segs do
			local a = (i / segs) * math.pi * 2
			local wave1 = math.sin(a * 3 + ct * 4.2 + seed) * 0.42
			local wave2 = math.cos(a * 5 - ct * 5.8 + seed * 1.7) * 0.33
			local wave3 = math.sin(a * 8 + ct * 7.5) * 0.25
			local rMod = 1.0 + (wave1 + wave2 + wave3) * wobbleAmt
			poly[#poly + 1] = {
				x = cx + math.cos(a) * rx * rMod,
				y = cy + math.sin(a) * ry * rMod
			}
		end

		surface.SetMaterial(unlitPolyMat)
		surface.SetDrawColor(col.r, col.g, col.b, col.a)
		-- Draw triangle fan so concave waves never glitch!
		for i = 2, #poly - 1 do
			surface.DrawPoly({ poly[1], poly[i], poly[i + 1] })
		end
	end

	function ENT:Initialize()
		self.Seed = math.Rand(0, 100)
		self.Emitter = ParticleEmitter(self:GetPos(), false)
		self.NextAmbientParticle = 0
		self.DidSplashBurst = false
		self:SetRenderBounds(Vector(-80, -80, -80), Vector(80, 80, 80))
	end

	function ENT:OnRemove()
		if IsValid(self.Emitter) then
			self.Emitter:Finish()
		end
	end

	function ENT:SpawnSplashParticles()
		if not IsValid(self.Emitter) then return end
		local pos = self:GetPos()
		local fwd = self:GetForward()
		local right = self:GetRight()
		local up = self:GetUp()

		-- Initial burst of green portal liquid droplets splashing outward & coalescing
		for i = 1, 22 do
			local a = (i / 22) * math.pi * 2 + math.Rand(-0.15, 0.15)
			local radialDir = right * math.cos(a) + up * math.sin(a)
			local p = self.Emitter:Add("rick_portal/liquid_blob.png", pos + radialDir * math.Rand(2, 10))
			if p then
				p:SetVelocity(radialDir * math.Rand(55, 135) + fwd * math.Rand(15, 55))
				p:SetDieTime(math.Rand(0.45, 0.85))
				p:SetStartAlpha(250)
				p:SetEndAlpha(0)
				p:SetStartSize(math.Rand(8, 16))
				p:SetEndSize(math.Rand(2, 4))
				p:SetRoll(math.Rand(0, 360))
				p:SetRollDelta(math.Rand(-5, 5))
				p:SetColor(152, 238, 76)
				p:SetGravity(Vector(0, 0, -180))
				p:SetAirResistance(90)
			end
		end
	end

	function ENT:Think()
		local ct = CurTime()
		local pos = self:GetPos()

		if not self.DidSplashBurst then
			self.DidSplashBurst = true
			self:SpawnSplashParticles()
		end

		-- Ambient bubbling green droplets / dimensional sparks around the portal edge
		if IsValid(self.Emitter) and ct >= self.NextAmbientParticle and not self:GetIsClosing() then
			self.NextAmbientParticle = ct + 0.065
			self.Emitter:SetPos(pos)

			local a = math.Rand(0, math.pi * 2)
			local isFloor = self:GetIsFloorPortal()
			local rx = isFloor and 48 or 42
			local ry = isFloor and 48 or 55
			local rimPos = pos + self:GetRight() * (math.cos(a) * rx) + self:GetUp() * (math.sin(a) * ry)

			local p = self.Emitter:Add("rick_portal/liquid_blob.png", rimPos)
			if p then
				p:SetVelocity(self:GetForward() * math.Rand(6, 22) + VectorRand() * 14)
				p:SetDieTime(math.Rand(0.45, 0.8))
				p:SetStartAlpha(225)
				p:SetEndAlpha(0)
				p:SetStartSize(math.Rand(4.5, 8.5))
				p:SetEndSize(0.5)
				p:SetRoll(math.Rand(0, 360))
				p:SetRollDelta(math.Rand(-4, 4))
				p:SetColor(168, 245, 88)
				p:SetGravity(Vector(0, 0, -65))
				p:SetAirResistance(60)
			end
		end

		-- Green dynamic light casting Rick & Morty emerald glow onto nearby walls, floor & player!
		local dlightConVar = GetConVar("cl_rickportal_dlight")
		if not dlightConVar or dlightConVar:GetBool() then
			local age = ct - self:GetBirthTime()
			local openFrac = math.Clamp(age / MORPH_DURATION, 0, 1)
			local closeFrac = self:GetIsClosing() and (1.0 - math.Clamp((ct - self:GetCloseTime()) / CLOSE_DURATION, 0, 1)) or 1.0
			local pulse = 1.0 + math.sin(ct * 5.2 + (self.Seed or 0)) * 0.12

			local dl = DynamicLight(self:EntIndex())
			if dl then
				dl.pos = pos + self:GetForward() * 12
				dl.r = 95
				dl.g = 242
				dl.b = 62
				dl.brightness = 2.8 * openFrac * closeFrac * pulse
				dl.Decay = 1000
				dl.Size = 260 * openFrac * closeFrac
				dl.DieTime = ct + 0.08
			end
		end
	end

	-- Renders one side of the portal in 3D2D space (drawn on both front & back for mid-air 360° visibility!)
	function ENT:DrawPortalFace(pos, ang, ct)
		local seed = self.Seed or 0
		local age = math.max(0, ct - self:GetBirthTime())
		local morphT = math.Clamp(age / MORPH_DURATION, 0, 1)

		local closeMult = 1.0
		if self:GetIsClosing() then
			local cT = math.Clamp((ct - self:GetCloseTime()) / CLOSE_DURATION, 0, 1)
			closeMult = math.pow(1.0 - cT, 1.6)
		end

		local isFloor = self:GetIsFloorPortal()
		-- Classic Rick & Morty tall oval on walls/mid-air, round vortex on floor
		local baseW = isFloor and 560 or 470
		local baseH = isFloor and 560 or 600

		-- Continuous organic breathing, stretching, shearing & morphing!
		local breatheX = 1.0 + math.sin(ct * 2.6 + seed) * 0.048 + math.cos(ct * 5.9 + seed * 2) * 0.022
		local breatheY = 1.0 + math.cos(ct * 2.3 + seed * 1.3) * 0.052 + math.sin(ct * 5.1 + seed) * 0.024

		-- Liquid -> Portal Transformation Envelope:
		-- Starts as a tight, wildly wobbling green fluid blob (18% size), stretches & ripples outward,
		-- coalesces its satellite droplets, and blossoms into the swirling Rick & Morty vortex!
		local growCurve = EaseOutBack(morphT) * closeMult
		local liquidPhase = math.Clamp(1.0 - (morphT - 0.15) / 0.75, 0, 1) -- 1.0 = pure liquid, 0.0 = full portal
		if self:GetIsClosing() then
			liquidPhase = math.Clamp(liquidPhase + (1.0 - closeMult) * 0.85, 0, 1)
		end

		local curW = baseW * (0.14 + 0.86 * growCurve) * breatheX
		local curH = baseH * (0.14 + 0.86 * growCurve) * breatheY

		cam.Start3D2D(pos, ang, 0.2)
			-- STAGE 1 & LIVING RIM: Organic wobbling green fluid mass!
			-- During morphT 0..0.85, wobble is dramatic (0.28 -> 0.05) so you clearly see green liquid
			-- splashing, undulating, and transforming into the portal! Even at 1.0, subtle 0.045 rim wave stays alive.
			local wobble = 0.045 + liquidPhase * 0.26
			DrawOrganicLiquidDisk(0, 0, curW * 0.50, curH * 0.50, ct, seed, wobble, Color(156, 218, 76, 250), 40)

			if liquidPhase > 0.02 then
				-- Inner darker green viscous liquid core + cartoon white foam blobs coalescing into the swirl
				local liqAlpha = math.floor(255 * liquidPhase)
				DrawOrganicLiquidDisk(0, 0, curW * 0.36, curH * 0.36, ct * 1.3, seed + 4.2, wobble * 1.25, Color(42, 152, 62, liqAlpha), 32)

				-- Coalescing liquid droplets spiraling inward/outward as the fluid transforms!
				for i = 1, 8 do
					local orbAng = (i / 8) * math.pi * 2 + ct * (3.8 - morphT * 1.5) + seed
					local spread = (0.32 + math.sin(ct * 7 + i) * 0.16) * (0.5 + liquidPhase * 0.85)
					local bx = math.cos(orbAng) * curW * spread
					local by = math.sin(orbAng) * curH * spread
					local bSize = (55 + (i % 3) * 26) * (0.4 + growCurve * 0.6) * liquidPhase
					DrawTexturedRotatedQuad(matBlob, bx, by, bSize, bSize * 0.88, math.deg(orbAng) + ct * 90, Color(168, 236, 82, liqAlpha))
				end
			end

			-- STAGE 2: Smoothly emerging & continuously swirling multi-layer Rick & Morty green portal!
			local swirlAlpha = math.Clamp((morphT - 0.12) / 0.62, 0, 1) * 255
			if swirlAlpha > 1 then
				-- Smooth variable-speed rotation (slightly accelerates during opening, then hypnotically cruises & oscillates)
				local spinBase = ct * 46 + math.sin(ct * 1.35 + seed) * 16 + (1.0 - morphT) * 110
				local spinInner = -ct * 31 + math.cos(ct * 1.9 + seed) * 22
				local spinCore  = ct * 78 + math.sin(ct * 2.7) * 18

				-- Layer A: Main authentic Rick & Morty portal texture (from user's attached image!)
				-- Scaled slightly inside an elliptical transform so even as it rotates 360°, the portal maintains
				-- its living, breathing organic proportions and wobbling outer edge!
				DrawTexturedRotatedQuad(
					matSwirl,
					0, 0,
					curW * 0.98, curH * 0.98,
					spinBase,
					Color(255, 255, 255, swirlAlpha)
				)

				-- Layer B: Counter-warped translucent secondary swirl layer — creates genuine fluid morphing
				-- so internal green bands & foam bubbles constantly shift & deform relative to each other!
				local pulseInner = 0.78 + math.sin(ct * 3.4 + seed) * 0.08
				DrawTexturedRotatedQuad(
					matInnerSwirl,
					math.sin(ct * 2.9 + seed) * 8,
					math.cos(ct * 2.5 + seed) * 8,
					curW * pulseInner, curH * pulseInner,
					spinInner,
					Color(195, 255, 145, swirlAlpha * 0.62)
				)

				-- Layer C: Deep hypnotic fast-spinning center vortex eye
				local eyeScale = 0.44 + math.cos(ct * 4.3 + seed) * 0.06
				DrawTexturedRotatedQuad(
					matInnerSwirl,
					0, 0,
					curW * eyeScale, curH * eyeScale,
					spinCore,
					Color(150, 245, 105, swirlAlpha * 0.78)
				)

				-- Subtle dimmed tint if this portal isn't linked to a second portal yet (visual feedback, still bright green!)
				if not IsValid(self:GetLinkedPortal()) then
					DrawTexturedRotatedQuad(
						matInnerSwirl,
						0, 0,
						curW * 0.30, curH * 0.30,
						-spinCore * 1.2,
						Color(220, 255, 185, swirlAlpha * 0.35)
					)
				end
			end
		cam.End3D2D()
	end

	function ENT:Draw()
		self:DrawTranslucent()
	end

	function ENT:DrawTranslucent()
		local ct = CurTime()
		local pos = self:GetPos()
		local fwd = self:GetForward()

		-- Soft emerald atmospheric glow halo behind the portal
		local age = math.max(0, ct - self:GetBirthTime())
		local morphT = math.Clamp(age / MORPH_DURATION, 0, 1)
		local closeMult = self:GetIsClosing() and math.Clamp(1.0 - (ct - self:GetCloseTime()) / CLOSE_DURATION, 0, 1) or 1.0

		render.SetMaterial(matGlow)
		render.DrawSprite(pos + fwd * 2, 145 * morphT * closeMult, 165 * morphT * closeMult, Color(105, 245, 70, 125))

		-- Front 3D2D plane (facing +Forward)
		local frontAng = self:GetAngles()
		frontAng:RotateAroundAxis(frontAng:Up(), 90)
		frontAng:RotateAroundAxis(frontAng:Forward(), 90)
		self:DrawPortalFace(pos + fwd * 0.6, frontAng, ct)

		-- Back 3D2D plane (for mid-air portals so they look awesome from BOTH sides!)
		if self:GetIsMidAir() then
			local backAng = (-fwd):Angle()
			backAng:RotateAroundAxis(backAng:Up(), 90)
			backAng:RotateAroundAxis(backAng:Forward(), 90)
			self:DrawPortalFace(pos - fwd * 0.6, backAng, ct)
		end
	end
end
