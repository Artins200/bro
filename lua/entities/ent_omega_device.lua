AddCSLuaFile()

ENT.Type        = "anim"
ENT.Base        = "base_anim"
ENT.PrintName   = "Omega Device (Chamber)"
ENT.Author      = "Rick Prime"
ENT.Category    = "Rick and Morty"
ENT.Spawnable   = true
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "ChargeStart")
	self:NetworkVar("Float", 1, "LastBlastTime")
	self:NetworkVar("Bool",  0, "IsCharging")
end

local MACHINE_SCALE = 3.2
local CORE_PULL_RAD = 210
local CORE_KILL_RAD = 68

if SERVER then
	function ENT:SpawnFunction(ply, tr, className)
		if not tr.Hit then return end
		local ent = ents.Create(className)
		ent:SetPos(tr.HitPos + Vector(0, 0, 95))
		ent:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
		ent:SetOwner(ply)
		ent:Spawn()
		ent:Activate()
		return ent
	end

	function ENT:Initialize()
		self:SetModel("models/hunter/blocks/cube1x1x1.mdl")
		self:DrawShadow(false)

		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableMotion(false)
		end

		self.NextScan = 0
	end

	function ENT:EraseVictimIntoOmega(victim, activator)
		if not IsValid(victim) then return end
		local sig = RICK_PORTAL.GetSubspeciesSignature(victim)
		if not sig then return end

		self:SetLastBlastTime(CurTime())
		self:EmitSound("RickOmega.Erase")
		util.ScreenShake(self:GetPos(), 14, 10, 1.3, 2000)

		local count, subName = RICK_PORTAL.EraseSubspeciesAcrossMultiverse(victim, activator or self:GetOwner())
		if subName then
			PrintMessage(HUD_PRINTTALK, string.format("[OMEGA DEVICE] Подвид «%s» поглощён ядром и СТЁРТ ИЗ ВСЕХ ВСЕЛЕННЫХ! (Удалено: %d)", subName, count))
		end
	end

	-- Press E near the Omega Device to pull & erase the nearest NPC/prop in front of it!
	function ENT:Use(activator)
		if not IsValid(activator) or not activator:IsPlayer() then return end

		local best, bestDist = nil, 420
		for _, ent in ipairs(ents.FindInSphere(self:GetPos(), 420)) do
			if IsValid(ent) and ent ~= self and ent ~= activator and not ent:IsPlayer() then
				local sig = RICK_PORTAL.GetSubspeciesSignature(ent)
				if sig and (ent:IsNPC() or ent:IsNextBot() or string.StartWith(ent:GetClass(), "prop_")) then
					local d = ent:GetPos():Distance(self:GetPos())
					if d < bestDist then
						bestDist = d
						best = ent
					end
				end
			end
		end

		if IsValid(best) then
			self:EmitSound("RickOmega.Charge")
			self:SetChargeStart(CurTime())
			self:SetIsCharging(true)
			self.PendingVictim = best
			self.PendingActivator = activator
		else
			activator:ChatPrint("[OMEGA DEVICE] Поднесите или заспавните рядом любое существо / NPC / предмет, чтобы стереть его подвид из всех вселенных!")
		end
	end

	function ENT:Think()
		local ct  = CurTime()
		local pos = self:GetPos()

		-- Complete scheduled E-triggered erasure
		if self:GetIsCharging() then
			if IsValid(self.PendingVictim) then
				-- Levitate victim straight into the glowing blue core!
				local dir = (pos - self.PendingVictim:WorldSpaceCenter())
				self.PendingVictim:SetPos(LerpVector(0.22, self.PendingVictim:GetPos(), pos - Vector(0, 0, 18)))
				local phys = self.PendingVictim:GetPhysicsObject()
				if IsValid(phys) then
					phys:Wake()
					phys:SetVelocity(dir * 4)
				end
			end

			if (ct - self:GetChargeStart()) >= 0.95 then
				self:SetIsCharging(false)
				if IsValid(self.PendingVictim) then
					self:EraseVictimIntoOmega(self.PendingVictim, self.PendingActivator)
				end
				self.PendingVictim = nil
			end

			self:NextThink(ct + 0.03)
			return true
		end

		-- Automatic gravitational pull & erasure when any NPC or prop is thrown into the Omega Core!
		for _, ent in ipairs(ents.FindInSphere(pos, CORE_PULL_RAD)) do
			if IsValid(ent) and ent ~= self and not ent:IsPlayer() then
				local sig = RICK_PORTAL.GetSubspeciesSignature(ent)
				if sig and (ent:IsNPC() or ent:IsNextBot() or string.StartWith(ent:GetClass(), "prop_")) then
					local dist = ent:WorldSpaceCenter():Distance(pos)
					if dist <= CORE_KILL_RAD then
						self:EraseVictimIntoOmega(ent, self:GetOwner())
						break
					elseif dist <= CORE_PULL_RAD then
						local pullDir = (pos - ent:WorldSpaceCenter()):GetNormalized()
						local phys = ent:GetPhysicsObject()
						if IsValid(phys) and phys:IsMotionEnabled() then
							phys:ApplyForceCenter(pullDir * phys:GetMass() * 420)
						elseif ent:IsNPC() then
							ent:SetVelocity(pullDir * 95)
						end
					end
				end
			end
		end

		self:NextThink(ct + 0.06)
		return true
	end
end

if CLIENT then
	function ENT:Initialize()
		self:SetRenderBounds(Vector(-160, -160, -160), Vector(160, 160, 160))
	end

	function ENT:Think()
		local dlightConVar = GetConVar("cl_rickportal_dlight")
		if not dlightConVar or dlightConVar:GetBool() then
			local ct = CurTime()
			local burst = math.Clamp(1.0 - (ct - self:GetLastBlastTime()) * 1.5, 0, 1)
			local dl = DynamicLight(self:EntIndex())
			if dl then
				dl.pos        = self:GetPos()
				dl.r          = 65
				dl.g          = 205
				dl.b          = 255
				dl.brightness = 3.6 + burst * 3.5
				dl.Decay      = 1000
				dl.Size       = 380 + burst * 280
				dl.DieTime    = ct + 0.08
			end
		end
	end

	function ENT:Draw()
		-- Drawn in DrawTranslucent so additive energy & containment rings blend cleanly
	end

	function ENT:DrawTranslucent()
		if not RICK_PORTAL or not RICK_PORTAL.OmegaRenderer then return end

		local ct     = CurTime()
		local charge = self:GetIsCharging() and math.Clamp((ct - self:GetChargeStart()) / 0.95, 0, 1) or 0
		local burst  = math.Clamp(1.0 - (ct - self:GetLastBlastTime()) * 1.5, 0, 1)
		local hover  = Vector(0, 0, math.sin(ct * 2.1) * 4.5)

		RICK_PORTAL.OmegaRenderer:DrawOmegaCore(self:GetPos() + hover, self:GetAngles(), MACHINE_SCALE, charge, burst)
	end
end
