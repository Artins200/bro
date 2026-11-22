AddCSLuaFile()
if SERVER then
	AddCSLuaFile("autorun/client/cl_rick_saucer_model.lua")
end

ENT.Type                  = "anim"
ENT.Base                  = "base_anim"
ENT.PrintName             = "Rick's Flying Saucer (Летающая тарелка)"
ENT.Author                = "Rick Sanchez"
ENT.Category              = "Rick and Morty"
ENT.Spawnable             = true
ENT.AdminOnly             = false
ENT.RenderGroup           = RENDERGROUP_BOTH
ENT.AutomaticFrameAdvance = true

-- Also expose it in Q > Vehicles, not just the scripted-entity list.
if list and list.Set then
	list.Set("Vehicles", "RickAndMortySaucer", {
		Name = "Rick's Flying Saucer",
		Class = "ent_rick_saucer",
		Category = "Rick and Morty",
		Model = "models/hunter/plates/plate2x2.mdl"
	})
end

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "PilotSeat")
	self:NetworkVar("Entity", 1, "Pilot")
end

if SERVER then
	local MAX_FORWARD_SPEED = 620
	local MAX_STRAFE_SPEED  = 430
	local MAX_LIFT_SPEED    = 360
	local BOOST_MULTIPLIER  = 1.45
	local PILOT_OFFSET      = Vector(-13, 0, -11)

	function ENT:SpawnFunction(ply, tr, className)
		if not tr.Hit then return end

		local saucer = ents.Create(className)
		if not IsValid(saucer) then return end

		saucer:SetPos(tr.HitPos + Vector(0, 0, 38))
		saucer:SetAngles(Angle(0, IsValid(ply) and ply:EyeAngles().y or 0, 0))
		saucer:Spawn()
		saucer:Activate()
		return saucer
	end

	function ENT:Initialize()
		-- The visible saucer is clientside-rendered; the simple box is its stable
		-- collision hull, independent of the model used by the spawn menu icon.
		self:SetModel("models/hunter/plates/plate2x2.mdl")
		self:DrawShadow(false)
		self:SetUseType(SIMPLE_USE)
		self:SetCollisionBounds(Vector(-104, -104, -25), Vector(104, 104, 62))
		self:SetRenderBounds(Vector(-132, -132, -82), Vector(132, 132, 92))
		self:SetCollisionGroup(COLLISION_GROUP_VEHICLE)

		self:PhysicsInitBox(Vector(-98, -98, -22), Vector(98, 98, 22))
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetMass(900)
			phys:EnableGravity(false)
			phys:EnableDrag(true)
			phys:SetDamping(1.2, 4.0)
			phys:Wake()
		end

		-- Keep a real prisoner-pod vehicle for normal GMod sit animations. It is
		-- deliberately NOT parented to the VPhysics saucer: parented Source
		-- vehicles often refuse EnterVehicle(). We reposition it during flight.
		local seat = ents.Create("prop_vehicle_prisoner_pod")
		if IsValid(seat) then
			seat:SetModel("models/nova/airboat_seat.mdl")
			seat:SetKeyValue("vehiclescript", "scripts/vehicles/prisoner_pod.txt")
			seat:SetKeyValue("limitview", "0")
			seat:SetPos(self:LocalToWorld(PILOT_OFFSET))
			seat:SetAngles(self:GetAngles())
			seat:Spawn()
			seat:Activate()
			seat:SetNoDraw(true)
			seat:SetNWEntity("RickSaucerOwner", self)
			self:SetPilotSeat(seat)
			self:SetNWEntity("RickSaucerSeat", seat)
		end

		self:SetPilot(NULL)
		self:SetNWFloat("RickSaucer_Speed", 0)
		self.LastFlightThink = CurTime()
		self.NextPilotUse = {}
	end

	function ENT:MountPilotManually(ply)
		if not IsValid(ply) or not ply:Alive() then return end
		if ply:InVehicle() then ply:ExitVehicle() end

		ply.RickSaucerRestore = {
			parent = ply:GetParent(),
			moveType = ply:GetMoveType(),
			solid = ply:GetSolid(),
			collisionGroup = ply:GetCollisionGroup()
		}

		self:SetPilot(ply)
		ply:SetNWEntity("RickSaucerVehicle", self)
		ply:SetNWBool("RickSaucerManualPilot", true)
		ply:SetParent(self)
		ply:SetLocalPos(PILOT_OFFSET)
		ply:SetLocalAngles(Angle(0, 0, 0))
		ply:SetMoveType(MOVETYPE_NONE)
		ply:SetSolid(SOLID_NONE)
		ply:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)

		-- Fallback for unusual servers where EnterVehicle rejects the hidden pod.
		-- The stock sit sequence keeps the player visibly seated under the dome.
		local sitSequence = ply:LookupSequence("sit_rollercoaster")
		if sitSequence and sitSequence >= 0 then
			ply:SetSequence(sitSequence)
			ply:SetCycle(0.15)
			ply:SetPlaybackRate(0)
		end
	end

	function ENT:EnterPilot(ply)
		if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
		if (self.NextPilotUse[ply] or 0) > CurTime() then return end
		self.NextPilotUse[ply] = CurTime() + 0.55
		ply.RickSaucerUseUntil = CurTime() + 0.55

		local currentPilot = self:GetPilot()
		if IsValid(currentPilot) then
			if currentPilot ~= ply then
				ply:ChatPrint("[ТАРЕЛКА] Место пилота уже занято.")
			end
			return
		end
		if ply:InVehicle() then return end

		local seat = self:GetPilotSeat()
		if IsValid(seat) and IsValid(seat:GetDriver()) then
			ply:ChatPrint("[ТАРЕЛКА] Место пилота уже занято.")
			return
		end

		self:SetPilot(ply)
		ply:SetNWEntity("RickSaucerVehicle", self)
		ply:SetNWBool("RickSaucerManualPilot", false)
		ply:ChatPrint("[ТАРЕЛКА] WASD — полёт, ПРОБЕЛ/CTRL — высота, SHIFT — форсаж, E — выйти.")

		if not IsValid(seat) then
			self:MountPilotManually(ply)
			return
		end

		ply:EnterVehicle(seat)

		-- EnterVehicle may fail silently for a custom hidden seat. Verify it and
		-- switch to a parented seated pose rather than leaving the player standing.
		local saucer = self
		timer.Simple(0.15, function()
			if not IsValid(saucer) or not IsValid(ply) or not ply:Alive() then return end
			if saucer:GetPilot() ~= ply then return end
			if IsValid(saucer:GetPilotSeat()) and ply:GetVehicle() == saucer:GetPilotSeat() then return end
			saucer:MountPilotManually(ply)
		end)
	end

	function ENT:ExitPilot(ply)
		if not IsValid(ply) then return end
		ply.RickSaucerUseUntil = CurTime() + 0.55
		local manual = ply:GetNWBool("RickSaucerManualPilot", false)
		local seat = self:GetPilotSeat()

		if not manual and IsValid(seat) and ply:GetVehicle() == seat then
			ply:ExitVehicle()
		end

		if manual then
			local exitPos = self:LocalToWorld(Vector(-76, 0, 8))
			local restore = ply.RickSaucerRestore or {}
			ply:SetParent(IsValid(restore.parent) and restore.parent or NULL)
			ply:SetMoveType(restore.moveType or MOVETYPE_WALK)
			ply:SetSolid(restore.solid or SOLID_BBOX)
			ply:SetCollisionGroup(restore.collisionGroup or COLLISION_GROUP_PLAYER)
			ply:SetPos(exitPos)
			ply:SetEyeAngles(Angle(0, self:GetAngles().y, 0))

			local idleSequence = ply:LookupSequence("idle_all")
			if idleSequence and idleSequence >= 0 then
				ply:SetSequence(idleSequence)
				ply:SetPlaybackRate(1)
			end
			ply.RickSaucerRestore = nil
			ply.RickSaucerAim = nil
		end

		ply:SetNWBool("RickSaucerManualPilot", false)
		ply:SetNWEntity("RickSaucerVehicle", NULL)
		if self:GetPilot() == ply then
			self:SetPilot(NULL)
		end
	end

	function ENT:Use(activator)
		self:EnterPilot(activator)
	end

	function ENT:Think()
		local now = CurTime()
		local dt = math.Clamp(now - (self.LastFlightThink or now), 0, 0.1)
		self.LastFlightThink = now

		local seat = self:GetPilotSeat()
		if IsValid(seat) then
			seat:SetPos(self:LocalToWorld(PILOT_OFFSET))
			seat:SetAngles(self:GetAngles())
		end

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			local driver = self:GetPilot()
			if not IsValid(driver) and IsValid(seat) then
				driver = seat:GetDriver()
			end

			local forwardInput, sideInput, liftInput = 0, 0, 0
			local currentAng = self:GetAngles()
			local targetYaw = currentAng.y

			if IsValid(driver) then
				if driver:KeyDown(IN_FORWARD) then forwardInput = forwardInput + 1 end
				if driver:KeyDown(IN_BACK) then forwardInput = forwardInput - 1 end
				if driver:KeyDown(IN_MOVERIGHT) then sideInput = sideInput + 1 end
				if driver:KeyDown(IN_MOVELEFT) then sideInput = sideInput - 1 end
				if driver:KeyDown(IN_JUMP) then liftInput = liftInput + 1 end
				if driver:KeyDown(IN_DUCK) then liftInput = liftInput - 1 end

				local aim = driver.RickSaucerAim or driver:EyeAngles()
				targetYaw = aim.y
			end

			local turnBlend = math.Clamp(dt * 3.5, 0, 1)
			local yaw = currentAng.y + math.AngleDifference(targetYaw, currentAng.y) * turnBlend
			local targetPitch = IsValid(driver) and (-forwardInput * 5) or 0
			local targetRoll  = IsValid(driver) and (-sideInput * 9) or 0
			local pitch = currentAng.p + (targetPitch - currentAng.p) * math.Clamp(dt * 2.5, 0, 1)
			local roll  = currentAng.r + (targetRoll - currentAng.r) * math.Clamp(dt * 3.0, 0, 1)
			self:SetAngles(Angle(pitch, yaw, roll))

			local boost = IsValid(driver) and driver:KeyDown(IN_SPEED) and BOOST_MULTIPLIER or 1
			local moveAng = Angle(0, yaw, 0)
			local desiredVelocity = moveAng:Forward() * (forwardInput * MAX_FORWARD_SPEED * boost)
			desiredVelocity = desiredVelocity + moveAng:Right() * (sideInput * MAX_STRAFE_SPEED * boost)
			desiredVelocity = desiredVelocity + Vector(0, 0, liftInput * MAX_LIFT_SPEED * boost)

			local currentVelocity = phys:GetVelocity()
			local response = math.Clamp(dt * (IsValid(driver) and 3.8 or 2.2), 0, 1)
			phys:SetVelocity(currentVelocity + (desiredVelocity - currentVelocity) * response)
			self:SetNWFloat("RickSaucer_Speed", phys:GetVelocity():Length())
		end

		self:NextThink(now)
		return true
	end

	function ENT:OnRemove()
		local pilot = self:GetPilot()
		if IsValid(pilot) then
			self:ExitPilot(pilot)
		end

		local seat = self:GetPilotSeat()
		if IsValid(seat) then
			local driver = seat:GetDriver()
			if IsValid(driver) then driver:ExitVehicle() end
			seat:Remove()
		end
	end

	hook.Add("KeyPress", "RickSaucer_UseKey", function(ply, key)
		if key ~= IN_USE or not IsValid(ply) or not ply:Alive() then return end
		if (ply.RickSaucerUseUntil or 0) > CurTime() then return end

		local current = ply:GetNWEntity("RickSaucerVehicle")
		if IsValid(current) then
			if ply:GetNWBool("RickSaucerManualPilot", false) then
				current:ExitPilot(ply)
			elseif ply:InVehicle() then
				ply:ExitVehicle()
			else
				current:ExitPilot(ply)
			end
			return
		end
		if ply:InVehicle() then return end

		-- Some gamemodes suppress SENT:Use. Prefer the looked-at saucer, then
		-- fall back to a nearby one when the trace misses its flat collision hull.
		local eyeTrace = ply:GetEyeTrace()
		local aimedEntity = eyeTrace and eyeTrace.Entity
		if IsValid(aimedEntity) and aimedEntity:GetClass() == "ent_rick_saucer" then
			aimedEntity:EnterPilot(ply)
			return
		end
		if IsValid(aimedEntity) and not aimedEntity:IsWorld() then return end

		local closest, closestDistance
		for _, saucer in ipairs(ents.FindByClass("ent_rick_saucer")) do
			if IsValid(saucer) then
				local distance = ply:GetShootPos():Distance(saucer:WorldSpaceCenter())
				if distance <= 150 and (not closestDistance or distance < closestDistance) then
					closest, closestDistance = saucer, distance
				end
			end
		end
		if IsValid(closest) then
			closest:EnterPilot(ply)
		end
	end)

	hook.Add("PlayerUse", "RickSaucer_UseFallback", function(ply, ent)
		if not IsValid(ent) or ent:GetClass() ~= "ent_rick_saucer" then return end
		if (ply.RickSaucerUseUntil or 0) > CurTime() then return false end
		ent:EnterPilot(ply)
		return false
	end)

	hook.Add("PlayerLeaveVehicle", "RickSaucer_ClearPilot", function(ply, vehicle)
		local saucer = ply:GetNWEntity("RickSaucerVehicle")
		if not IsValid(saucer) or saucer:GetPilotSeat() ~= vehicle then return end
		ply.RickSaucerUseUntil = CurTime() + 0.55
		if saucer:GetPilot() == ply then saucer:SetPilot(NULL) end
		ply:SetNWEntity("RickSaucerVehicle", NULL)
		ply:SetNWBool("RickSaucerManualPilot", false)
	end)

	hook.Add("StartCommand", "RickSaucer_TrackManualAim", function(ply, cmd)
		if ply:GetNWBool("RickSaucerManualPilot", false) then
			ply.RickSaucerAim = cmd:GetViewAngles()
		end
	end)

	hook.Add("PlayerDeath", "RickSaucer_ReleasePilotOnDeath", function(ply)
		local saucer = ply:GetNWEntity("RickSaucerVehicle")
		if IsValid(saucer) then saucer:ExitPilot(ply) end
	end)

	hook.Add("PlayerDisconnected", "RickSaucer_ReleasePilotOnDisconnect", function(ply)
		local saucer = ply:GetNWEntity("RickSaucerVehicle")
		if IsValid(saucer) and saucer:GetPilot() == ply then
			saucer:SetPilot(NULL)
		end
	end)
end

if CLIENT then
	language.Add("ent_rick_saucer", "Rick's Flying Saucer")

	local function GetSaucerFromPlayer(ply)
		local saucer = ply:GetNWEntity("RickSaucerVehicle")
		if IsValid(saucer) and saucer:GetClass() == "ent_rick_saucer" then
			return saucer
		end

		local seat = ply:GetVehicle()
		if IsValid(seat) then
			local owner = seat:GetNWEntity("RickSaucerOwner")
			if IsValid(owner) and owner:GetClass() == "ent_rick_saucer" then
				return owner
			end
		end
	end

	hook.Add("CalcView", "RickSaucer_ChaseCamera", function(ply, origin, angles, fov)
		local saucer = GetSaucerFromPlayer(ply)
		if not IsValid(saucer) then return end

		local target = saucer:GetPos() + Vector(0, 0, 17)
		local viewAng = Angle(math.Clamp(angles.p, -30, 35), angles.y, 0)
		local desiredOrigin = target - viewAng:Forward() * 255 + Vector(0, 0, 82)
		local filter = { ply, saucer }
		local seat = saucer:GetPilotSeat()
		if IsValid(seat) then filter[#filter + 1] = seat end
		local trace = util.TraceHull({
			start = target,
			endpos = desiredOrigin,
			mins = Vector(-6, -6, -6),
			maxs = Vector(6, 6, 6),
			filter = filter,
			mask = MASK_SOLID
		})

		local cameraOrigin = trace.Hit and (trace.HitPos + trace.HitNormal * 8) or desiredOrigin
		return {
			origin = cameraOrigin,
			angles = (target - cameraOrigin):Angle(),
			fov = fov,
			drawviewer = true
		}
	end)

	hook.Add("HUDPaint", "RickSaucer_FlightHUD", function()
		local ply = LocalPlayer()
		if not IsValid(ply) then return end

		local saucer = GetSaucerFromPlayer(ply)
		if not IsValid(saucer) then return end

		local width, height = 352, 118
		local x, y = 26, ScrH() - height - 28
		draw.RoundedBox(10, x, y, width, height, Color(9, 21, 30, 215))
		draw.RoundedBoxEx(10, x, y, width, 4, Color(77, 223, 206, 235), true, true, false, false)
		draw.SimpleText("ЛЕТАЮЩАЯ ТАРЕЛКА", "Trebuchet18", x + 16, y + 12, Color(192, 255, 238), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText("WASD — курс   •   SPACE / CTRL — высота", "DermaDefaultBold", x + 16, y + 42, Color(227, 237, 239), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText("SHIFT — форсаж   •   E — выйти", "DermaDefault", x + 16, y + 62, Color(160, 188, 195), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		local speed = math.floor((saucer:GetNWFloat("RickSaucer_Speed", saucer:GetVelocity():Length()) or 0) + 0.5)
		draw.SimpleText(string.format("СКОРОСТЬ  %03d u/s", speed), "DermaDefaultBold", x + 16, y + 88, Color(91, 231, 211), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end)

	function ENT:Draw()
		local renderer = RICK_PORTAL and RICK_PORTAL.SaucerRenderer
		if renderer then
			renderer:DrawOpaque(self)
		else
			self:DrawModel()
		end
	end

	function ENT:DrawTranslucent()
		local renderer = RICK_PORTAL and RICK_PORTAL.SaucerRenderer
		if renderer then
			renderer:DrawTranslucent(self)
		end
	end
end
