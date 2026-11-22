AddCSLuaFile()

ENT.Type                  = "anim"
ENT.Base                  = "base_anim"
ENT.PrintName             = "Rick's Flying Saucer (Летающая тарелка)"
ENT.Author                = "Rick Sanchez"
ENT.Category              = "Rick and Morty"
ENT.Spawnable             = true
ENT.AdminOnly             = false
ENT.RenderGroup           = RENDERGROUP_BOTH
ENT.AutomaticFrameAdvance = true

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "PilotSeat")
end

if SERVER then
	local MAX_FORWARD_SPEED = 620
	local MAX_STRAFE_SPEED  = 430
	local MAX_LIFT_SPEED    = 360
	local BOOST_MULTIPLIER  = 1.45

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
		-- The visible saucer is drawn from clientside meshes. This stock model is
		-- only a harmless fallback/collision reference and is never drawn normally.
		self:SetModel("models/props_junk/PopCan01a.mdl")
		self:DrawShadow(false)
		self:SetUseType(SIMPLE_USE)
		self:SetCollisionBounds(Vector(-104, -104, -25), Vector(104, 104, 62))
		self:SetRenderBounds(Vector(-132, -132, -82), Vector(132, 132, 92))

		self:PhysicsInitBox(Vector(-98, -98, -22), Vector(98, 98, 22))
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_VEHICLE)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetMass(900)
			phys:EnableGravity(false)
			phys:EnableDrag(true)
			phys:SetDamping(1.2, 4.0)
			phys:Wake()
		end

		local seat = ents.Create("prop_vehicle_prisoner_pod")
		if IsValid(seat) then
			seat:SetModel("models/nova/airboat_seat.mdl")
			seat:SetKeyValue("vehiclescript", "scripts/vehicles/prisoner_pod.txt")
			seat:SetKeyValue("limitview", "0")
			seat:SetPos(self:LocalToWorld(Vector(-13, 0, -12)))
			seat:SetAngles(self:GetAngles())
			seat:Spawn()
			seat:Activate()

			seat:SetParent(self)
			seat:SetLocalPos(Vector(-13, 0, -12))
			seat:SetLocalAngles(Angle(0, 0, 0))
			seat:SetNoDraw(true)
			seat:SetNWEntity("RickSaucerOwner", self)
			self:SetNWEntity("RickSaucerSeat", seat)
			self:SetPilotSeat(seat)
		end

		self.LastFlightThink = CurTime()
		self:SetNWFloat("RickSaucer_Speed", 0)
	end

	function ENT:Use(activator)
		if not IsValid(activator) or not activator:IsPlayer() or not activator:Alive() then return end
		if activator:InVehicle() then return end

		local seat = self:GetPilotSeat()
		if not IsValid(seat) then
			activator:ChatPrint("[ТАРЕЛКА] Кресло пилота недоступно.")
			return
		end

		local driver = seat:GetDriver()
		if IsValid(driver) and driver ~= activator then
			activator:ChatPrint("[ТАРЕЛКА] Место пилота уже занято.")
			return
		end

		activator:EnterVehicle(seat)
		activator:ChatPrint("[ТАРЕЛКА] WASD — полёт, ПРОБЕЛ/CTRL — высота, SHIFT — форсаж, E — выйти.")
	end

	function ENT:Think()
		local now = CurTime()
		local dt = math.Clamp(now - (self.LastFlightThink or now), 0, 0.1)
		self.LastFlightThink = now

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			local driver
			local seat = self:GetPilotSeat()
			if IsValid(seat) then
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
				targetYaw = driver:EyeAngles().y
			end

			local turnBlend = math.Clamp(dt * 3.5, 0, 1)
			local yaw = currentAng.y + math.AngleDifference(targetYaw, currentAng.y) * turnBlend
			local targetPitch = IsValid(driver) and (-forwardInput * 7) or 0
			local targetRoll  = IsValid(driver) and (-sideInput * 12) or 0
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
		local seat = self:GetPilotSeat()
		if not IsValid(seat) then return end

		local driver = seat:GetDriver()
		if IsValid(driver) then
			driver:ExitVehicle()
		end
		seat:Remove()
	end
end

if CLIENT then
	language.Add("ent_rick_saucer", "Rick's Flying Saucer")

	local function GetSaucerFromSeat(seat)
		if not IsValid(seat) then return nil end

		local parent = seat:GetParent()
		if IsValid(parent) and parent:GetClass() == "ent_rick_saucer" then
			return parent
		end

		local owner = seat:GetNWEntity("RickSaucerOwner")
		if IsValid(owner) and owner:GetClass() == "ent_rick_saucer" then
			return owner
		end
	end

	hook.Add("CalcView", "RickSaucer_ChaseCamera", function(ply, origin, angles, fov)
		local seat = ply:GetVehicle()
		local saucer = GetSaucerFromSeat(seat)
		if not IsValid(saucer) then return end

		local target = saucer:GetPos() + Vector(0, 0, 17)
		local viewAng = Angle(math.Clamp(angles.p, -30, 35), angles.y, 0)
		local desiredOrigin = target - viewAng:Forward() * 255 + Vector(0, 0, 82)
		local trace = util.TraceHull({
			start = target,
			endpos = desiredOrigin,
			mins = Vector(-6, -6, -6),
			maxs = Vector(6, 6, 6),
			filter = { ply, seat, saucer },
			mask = MASK_SOLID
		})

		local cameraOrigin = trace.Hit and (trace.HitPos + trace.HitNormal * 8) or desiredOrigin
		local cameraAngles = (target - cameraOrigin):Angle()
		return {
			origin = cameraOrigin,
			angles = cameraAngles,
			fov = fov,
			drawviewer = true
		}
	end)

	hook.Add("HUDPaint", "RickSaucer_FlightHUD", function()
		local ply = LocalPlayer()
		if not IsValid(ply) then return end

		local seat = ply:GetVehicle()
		local saucer = GetSaucerFromSeat(seat)
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
