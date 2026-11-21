AddCSLuaFile()

ENT.Type                  = "anim"
ENT.Base                  = "base_anim"
ENT.PrintName             = "Past Self (Temporal Echo)"
ENT.Author                = "Rick Sanchez"
ENT.Spawnable             = false
ENT.AutomaticFrameAdvance = true

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "TravelerName")
end

if SERVER then
	function ENT:Initialize()
		self:SetSolid(SOLID_BBOX)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetCollisionBounds(Vector(-16, -16, 0), Vector(16, 16, 72))
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)

		self.Frames    = self.Frames or {}
		self.StartTime = CurTime()
	end

	function ENT:SetTimelineFrames(frames, ownerPly)
		self.Frames    = frames or {}
		self.StartTime = CurTime()

		if IsValid(ownerPly) then
			self:SetModel(ownerPly:GetModel())
			self:SetSkin(ownerPly:GetSkin() or 0)
			self:SetPlayerColor(ownerPly:GetPlayerColor())
			self:SetTravelerName(ownerPly:Nick() .. " (ВЫ ИЗ ПРОШЛОГО)")
			for i = 0, ownerPly:GetNumBodyGroups() - 1 do
				self:SetBodygroup(i, ownerPly:GetBodygroup(i))
			end
		end
	end

	function ENT:SetPlayerColor(vec)
		self:SetNWVector("PlyColor", vec or Vector(0.24, 0.34, 0.41))
	end

	-- Smooth 33Hz interpolated timeline playback so your Past Self walks, turns & animates fluidly!
	function ENT:Think()
		local count = self.Frames and #self.Frames or 0
		if count == 0 then
			self:Remove()
			return
		end

		local elapsed   = CurTime() - (self.StartTime or CurTime())
		local totalDur  = math.max(0.08, (count - 1) * 0.08)
		local loopTime  = elapsed % totalDur
		local exactIdx  = (loopTime / 0.08) + 1
		local idxA      = math.Clamp(math.floor(exactIdx), 1, count)
		local idxB      = math.Clamp(idxA + 1, 1, count)
		local alpha     = exactIdx - idxA

		local fA = self.Frames[idxA]
		local fB = self.Frames[idxB] or fA

		if fA then
			local interpPos = LerpVector(alpha, fA.pos, fB.pos)
			local interpYaw = LerpAngle(alpha, Angle(0, fA.ang.y, 0), Angle(0, fB.ang.y, 0))
			self:SetPos(interpPos)
			self:SetAngles(interpYaw)

			-- Choose proper locomotion sequence based on recorded velocity or sequence
			local moveSpeed = (fB.pos - fA.pos):Length2D() / 0.08
			local targetSeq = fA.seq
			if not targetSeq or targetSeq <= 0 then
				targetSeq = self:LookupSequence(moveSpeed > 140 and "run_all_01" or (moveSpeed > 15 and "walk_all" or "idle_all_01"))
			end

			if targetSeq and targetSeq >= 0 and self:GetSequence() ~= targetSeq then
				self:ResetSequence(targetSeq)
			end
			self:SetPlaybackRate(1.0)
		end

		self:NextThink(CurTime())
		return true
	end
end

if CLIENT then
	local matGlow = Material("sprites/light_glow02_add")

	function ENT:Initialize()
		self.GetPlayerColor = function(s)
			return s:GetNWVector("PlyColor", Vector(0.24, 0.34, 0.41))
		end
	end

	function ENT:Draw()
		local ct  = CurTime()
		local pos = self:GetPos()

		-- Subtle temporal violet-cyan aura around your Past Self!
		render.SetMaterial(matGlow)
		render.DrawSprite(pos + Vector(0, 0, 38), 54, 76, Color(175, 105, 255, 65 + math.sin(ct * 6) * 20))

		render.SetColorModulation(0.92, 0.96, 1.0)
		self:DrawModel()
		render.SetColorModulation(1, 1, 1)

		local headTagPos = pos + Vector(0, 0, 78)
		local ply = LocalPlayer()
		if IsValid(ply) and ply:GetPos():Distance(headTagPos) < 950 then
			local ang = (ply:EyePos() - headTagPos):Angle()
			ang:RotateAroundAxis(ang:Up(), 90)
			ang:RotateAroundAxis(ang:Forward(), 90)

			cam.Start3D2D(headTagPos, ang, 0.11)
				draw.RoundedBox(6, -135, -18, 270, 36, Color(20, 14, 38, 215))
				surface.SetDrawColor(195, 115, 255, 220)
				surface.DrawOutlinedRect(-135, -18, 270, 36, 2)
				draw.SimpleText(self:GetTravelerName(), "DermaDefaultBold", 0, 0, Color(225, 185, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			cam.End3D2D()
		end
	end
end
