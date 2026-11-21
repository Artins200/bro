AddCSLuaFile()

ENT.Type        = "anim"
ENT.Base        = "base_anim"
ENT.PrintName   = "Omega Device (Chamber)"
ENT.Author      = "Rick Prime"
ENT.Category    = "Rick and Morty"
ENT.Spawnable   = true
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
	self:NetworkVar("Float",  0, "ChargeStart")
	self:NetworkVar("Float",  1, "LastBlastTime")
	self:NetworkVar("Bool",   0, "IsCharging")
	self:NetworkVar("Entity", 0, "CapturedSubject")
end

local CHARGE_DURATION = 1.6

if SERVER then
	util.AddNetworkString("RickOmega_ConsoleCmd")

	function ENT:SpawnFunction(ply, tr, className)
		if not tr.Hit then return end
		local ent = ents.Create(className)
		ent:SetPos(tr.HitPos)
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
		self:SetSolid(SOLID_BBOX)
		self:SetCollisionBounds(Vector(-55, -55, 0), Vector(75, 55, 130))

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then phys:EnableMotion(false) end
	end

	function ENT:ReleaseSubject()
		local subj = self:GetCapturedSubject()
		if IsValid(subj) then
			subj:SetMoveType(self.SavedSubjMoveType or MOVETYPE_STEP)
			local releasePos = self:LocalToWorld(Vector(105, 0, 16))
			subj:SetPos(releasePos)
			if subj:IsNPC() then
				subj:CapabilitiesAdd(CAP_MOVE_GROUND)
			end
			local phys = subj:GetPhysicsObject()
			if IsValid(phys) then phys:EnableMotion(true) end
		end
		self:SetCapturedSubject(NULL)
	end

	function ENT:CaptureSingleRepresentative(sigTarget, caller)
		if self:GetIsCharging() then return end

		-- Release any currently imprisoned creature first
		if IsValid(self:GetCapturedSubject()) then
			self:ReleaseSubject()
		end

		local found = nil
		for _, ent in ipairs(ents.GetAll()) do
			if IsValid(ent) and ent ~= self and ent ~= caller and ent:GetClass() ~= "npc_time_police" then
				local sig = RICK_PORTAL.GetSubspeciesSignature(ent)
				if sig == sigTarget then
					found = ent
					break
				end
			end
		end

		if not IsValid(found) then return end

		self.SavedSubjMoveType = found:GetMoveType()
		local capsuleCenter = self:LocalToWorld(Vector(-10, 0, 14))
		found:SetPos(capsuleCenter)
		found:SetAngles(self:GetAngles())

		if found:IsPlayer() then
			found:Freeze(true)
			timer.Simple(4.0, function()
				if IsValid(found) then found:Freeze(false) end
			end)
		else
			found:SetMoveType(MOVETYPE_NONE)
			local phys = found:GetPhysicsObject()
			if IsValid(phys) then phys:EnableMotion(false) end
		end

		self:SetCapturedSubject(found)
		self:EmitSound("RickPortal.Enter")
	end

	function ENT:StartOmegaExecution(caller)
		if self:GetIsCharging() then return end
		local subj = self:GetCapturedSubject()
		if not IsValid(subj) then return end

		if subj:GetClass() == "npc_time_police" then
			if IsValid(caller) then
				caller:ChatPrint("[OMEGA DEVICE] ОШИБКА: Полиция Времени 4-го измерения защищена от Омега-оружия!")
			end
			return
		end

		self.ExecCaller = caller
		self:SetChargeStart(CurTime())
		self:SetIsCharging(true)
		self:EmitSound("RickOmega.Charge")
	end

	function ENT:OnRemove()
		if IsValid(self:GetCapturedSubject()) then
			self:ReleaseSubject()
		end
	end

	function ENT:Think()
		local ct   = CurTime()
		local subj = self:GetCapturedSubject()

		-- Keep captured specimen floating & pinned right inside the glass stasis capsule!
		if IsValid(subj) then
			local hoverZ = 16 + math.sin(ct * 3.2) * 3.5
			local lockPos = self:LocalToWorld(Vector(-10, 0, hoverZ))
			subj:SetPos(lockPos)
			subj:SetLocalVelocity(Vector(0, 0, 0))
		end

		if self:GetIsCharging() then
			if (ct - self:GetChargeStart()) >= CHARGE_DURATION then
				self:SetIsCharging(false)
				self:SetLastBlastTime(ct)
				self:EmitSound("RickOmega.Erase")
				util.ScreenShake(self:GetPos(), 15, 10, 1.4, 2200)

				if IsValid(subj) then
					if subj:IsPlayer() then subj:Freeze(false) end
					local count, subName = RICK_PORTAL.EraseSubspeciesAcrossMultiverse(subj, self.ExecCaller or self:GetOwner())
					self:SetCapturedSubject(NULL)
					if subName then
						PrintMessage(HUD_PRINTTALK, string.format("[OMEGA DEVICE] Заточённый образец уничтожен — подвид «%s» СТЁРТ ИЗ ВСЕХ ВСЕЛЕННЫХ! (Удалено: %d)", subName, count))
					end
				end
			end
			self:NextThink(ct + 0.03)
			return true
		end

		self:NextThink(ct + 0.05)
		return true
	end

	net.Receive("RickOmega_ConsoleCmd", function(_, ply)
		if not IsValid(ply) then return end
		local mach = net.ReadEntity()
		local cmd  = net.ReadString()
		local arg  = net.ReadString()

		if not IsValid(mach) or mach:GetClass() ~= "ent_omega_device" then return end
		if ply:GetShootPos():Distance(mach:GetPos()) > 260 then return end

		if cmd == "capture" then
			mach:CaptureSingleRepresentative(arg, ply)
		elseif cmd == "erase" then
			mach:StartOmegaExecution(ply)
		elseif cmd == "release" then
			mach:ReleaseSubject()
			mach:EmitSound("buttons/button15.wav", 68, 100, 0.7)
		elseif cmd == "reset" then
			RICK_PORTAL.ResetErasedMultiverse()
			mach:EmitSound("buttons/button19.wav", 75, 110, 0.8)
		end
	end)
end

if CLIENT then
	function ENT:Initialize()
		self:SetRenderBounds(Vector(-140, -140, -10), Vector(140, 140, 260))
		self.ScrollOffset = 0
		self.LastClickTime = 0
	end

	-- Ray-Plane intersection so the player looks directly at the physical 3D monitor and clicks E or LMB!
	function ENT:GetMonitorCursor(scrOrigin, scrAng, scale)
		local ply = LocalPlayer()
		if not IsValid(ply) then return nil, nil, false end

		local eyePos = ply:EyePos()
		local aimVec = ply:GetAimVector()
		if eyePos:Distance(scrOrigin) > 165 then return nil, nil, false end

		-- In cam.Start3D2D(pos, ang, scale):
		-- +X on canvas = ang:Forward(), +Y on canvas = ang:Right(), Plane normal facing viewer = ang:Up()
		local planeNormal = scrAng:Up()
		local denom = aimVec:Dot(planeNormal)
		if denom >= -0.05 then return nil, nil, false end -- Looking from behind or parallel

		local t = (scrOrigin - eyePos):Dot(planeNormal) / denom
		if t < 0 or t > 175 then return nil, nil, false end

		local hitWorld = eyePos + aimVec * t
		local delta    = hitWorld - scrOrigin
		local uiX      = delta:Dot(scrAng:Forward()) / scale
		local uiY      = delta:Dot(scrAng:Right()) / scale

		if math.abs(uiX) <= 220 and math.abs(uiY) <= 150 then
			return uiX, uiY, true
		end
		return nil, nil, false
	end

	function ENT:GatherMapSubspecies()
		local mapList = {}
		local bySig   = {}
		local ply     = LocalPlayer()

		for _, ent in ipairs(ents.GetAll()) do
			if IsValid(ent) and ent ~= self and ent ~= ply and ent:GetClass() ~= "npc_time_police" then
				if ent:IsNPC() or ent:IsNextBot() or ent:IsPlayer() or string.StartWith(ent:GetClass(), "prop_") then
					local sig, pretty = RICK_PORTAL.GetSubspeciesSignature(ent)
					if sig then
						if not bySig[sig] then
							bySig[sig] = { sig = sig, name = pretty, count = 1 }
							mapList[#mapList + 1] = bySig[sig]
						else
							bySig[sig].count = bySig[sig].count + 1
						end
					end
				end
			end
		end
		return mapList
	end

	function ENT:Think()
		local dlightConVar = GetConVar("cl_rickportal_dlight")
		if not dlightConVar or dlightConVar:GetBool() then
			local ct    = CurTime()
			local burst = math.Clamp(1.0 - (ct - self:GetLastBlastTime()) * 1.5, 0, 1)
			local dl    = DynamicLight(self:EntIndex())
			if dl then
				dl.pos        = self:LocalToWorld(Vector(-10, 0, 150))
				dl.r          = 65
				dl.g          = 205
				dl.b          = 255
				dl.brightness = 3.5 + burst * 3.5
				dl.Decay      = 1000
				dl.Size       = 360 + burst * 260
				dl.DieTime    = ct + 0.08
			end
		end
	end

	function ENT:Draw()
		-- Drawn cleanly in DrawTranslucent
	end

	function ENT:DrawTranslucent()
		if not RICK_PORTAL or not RICK_PORTAL.OmegaRenderer then return end

		local ct     = CurTime()
		local pos    = self:GetPos()
		local ang    = self:GetAngles()
		local subj   = self:GetCapturedSubject()
		local charge = self:GetIsCharging() and math.Clamp((ct - self:GetChargeStart()) / CHARGE_DURATION, 0, 1) or 0
		local burst  = math.Clamp(1.0 - (ct - self:GetLastBlastTime()) * 1.5, 0, 1)

		-- 1) Draw Full 3D Omega Chamber Structure + Capsule + Monitor Stand
		RICK_PORTAL.OmegaRenderer:DrawOmegaChamberStructure(pos, ang, charge, burst, IsValid(subj))

		-- 2) Draw Interactive Diegetic 3D2D Monitor Screen RIGHT INSIDE THE MONITOR MODEL!
		--    Monitor housing is at Local(62, 0, 52) tilted -28°; front screen surface sits at Local(65.2, 0, 53.6)
		local scrOrigin, scrAng = LocalToWorld(Vector(65.2, 0, 53.6), Angle(0, 90, 62), pos, ang)
		local uiScale = 0.105

		local curX, curY, onScreen = self:GetMonitorCursor(scrOrigin, scrAng, uiScale)
		local clicked = false
		if onScreen and (CurTime() - (self.LastClickTime or 0)) > 0.28 then
			if input.IsKeyDown(KEY_E) or input.IsMouseDown(MOUSE_LEFT) then
				self.LastClickTime = CurTime()
				clicked = true
				surface.PlaySound("rick_portal/tablet_tap.wav")
			end
		end

		local function DrawBtn(bx, by, bw, bh, label, bgCol, hoverCol)
			local hovered = onScreen and curX >= bx and curX <= (bx + bw) and curY >= by and curY <= (by + bh)
			draw.RoundedBox(6, bx, by, bw, bh, hovered and hoverCol or bgCol)
			surface.SetDrawColor(115, 225, 255, hovered and 255 or 120)
			surface.DrawOutlinedRect(bx, by, bw, bh, 1)
			draw.SimpleText(label, "DermaDefaultBold", bx + bw * 0.5, by + bh * 0.5, Color(235, 250, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			return hovered and clicked
		end

		cam.Start3D2D(scrOrigin, scrAng, uiScale)
			-- Screen CRT Background
			draw.RoundedBox(8, -215, -145, 430, 290, Color(10, 16, 28, 248))
			surface.SetDrawColor(75, 210, 255, 230)
			surface.DrawOutlinedRect(-215, -145, 430, 290, 2)

			draw.SimpleText("ТЕРМИНАЛ ОМЕГА-УСТРОЙСТВА [НАВЕДИ И НАЖМИ E]", "DermaDefaultBold", 0, -126, Color(95, 225, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			surface.SetDrawColor(65, 180, 235, 120)
			surface.DrawRect(-200, -112, 400, 2)

			-- Left Column: Available Subspecies on Map -> Click to Teleport 1 Specimen into Stasis Capsule!
			draw.SimpleText("ПОДВИДЫ В РЕАЛЬНОСТИ (В КАПСУЛУ):", "DermaDefaultBold", -105, -96, Color(185, 235, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			local list = self:GatherMapSubspecies()
			if #list == 0 then
				draw.SimpleText("Нет доступных целей", "DermaDefault", -105, -20, Color(140, 165, 185), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			else
				local maxRows = 5
				local startIdx = math.Clamp(self.ScrollOffset + 1, 1, math.max(1, #list - maxRows + 1))
				for row = 0, math.min(maxRows - 1, #list - startIdx) do
					local item = list[startIdx + row]
					local ry = -78 + row * 34
					local txt = string.sub(item.name, 1, 20) .. " (" .. item.count .. ")"
					if DrawBtn(-202, ry, 195, 28, txt, Color(20, 38, 62, 235), Color(42, 88, 138, 255)) then
						net.Start("RickOmega_ConsoleCmd")
							net.WriteEntity(self)
							net.WriteString("capture")
							net.WriteString(item.sig)
						net.SendToServer()
					end
				end

				if #list > maxRows then
					if DrawBtn(-202, 96, 92, 24, "▲ ВВЕРХ", Color(22, 34, 52), Color(45, 75, 115)) then
						self.ScrollOffset = math.max(0, self.ScrollOffset - 1)
					end
					if DrawBtn(-100, 96, 93, 24, "▼ ВНИЗ", Color(22, 34, 52), Color(45, 75, 115)) then
						self.ScrollOffset = math.min(#list - maxRows, self.ScrollOffset + 1)
					end
				end
			end

			-- Right Column: Stasis Capsule Status + ERASE ALL ACROSS MULTIVERSE Button!
			surface.SetDrawColor(65, 180, 235, 90)
			surface.DrawRect(4, -104, 2, 235)

			draw.SimpleText("КАПСУЛА ЗАТОЧЕНИЯ:", "DermaDefaultBold", 108, -96, Color(255, 195, 115), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			if IsValid(subj) then
				local _, sName = RICK_PORTAL.GetSubspeciesSignature(subj)
				draw.RoundedBox(6, 16, -76, 186, 46, Color(24, 48, 72, 235))
				draw.SimpleText("ОБРАЗЕЦ В КАПСУЛЕ:", "DermaDefault", 109, -63, Color(145, 225, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText(string.sub(tostring(sName), 1, 22), "DermaDefaultBold", 109, -44, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

				if self:GetIsCharging() then
					draw.RoundedBox(6, 16, -18, 186, 48, Color(65, 165, 255, 240))
					draw.SimpleText("СТИРАНИЕ...", "DermaDefaultBold", 109, 6, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				else
					if DrawBtn(16, -18, 186, 48, "⚡ СТЕРЕТЬ НАВСЕГДА", Color(155, 28, 42, 245), Color(225, 48, 65, 255)) then
						net.Start("RickOmega_ConsoleCmd")
							net.WriteEntity(self)
							net.WriteString("erase")
							net.WriteString("")
						net.SendToServer()
					end

					if DrawBtn(16, 38, 186, 28, "ОТПУСТИТЬ ИЗ КАПСУЛЫ", Color(32, 52, 72, 235), Color(55, 95, 130, 255)) then
						net.Start("RickOmega_ConsoleCmd")
							net.WriteEntity(self)
							net.WriteString("release")
							net.WriteString("")
						net.SendToServer()
					end
				end
			else
				draw.RoundedBox(6, 16, -76, 186, 84, Color(18, 26, 40, 220))
				draw.SimpleText("КАПСУЛА ПУСТА", "DermaDefaultBold", 109, -46, Color(150, 175, 195), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText("Выберите подвид слева", "DermaDefault", 109, -22, Color(120, 150, 175), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			-- Bottom Reset Multiverse Button
			local erasedCount = table.Count(RICK_PORTAL.ErasedSubspecies or {})
			if DrawBtn(16, 94, 186, 32, string.format("ВОССТАНОВИТЬ ВСЕЛЕННЫЕ (%d)", erasedCount), Color(26, 62, 58, 235), Color(42, 115, 102, 255)) then
				net.Start("RickOmega_ConsoleCmd")
					net.WriteEntity(self)
					net.WriteString("reset")
					net.WriteString("")
				net.SendToServer()
			end

			-- Draw glowing cyan cursor dot right on the 3D monitor surface!
			if onScreen and curX and curY then
				surface.DrawCircle(curX, curY, 5, 125, 245, 255, 255)
				surface.SetDrawColor(255, 255, 255, 255)
				surface.DrawRect(curX - 2, curY - 2, 4, 4)
			end
		cam.End3D2D()
	end
end
