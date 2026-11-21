AddCSLuaFile()

ENT.Type            = "anim"
ENT.Base            = "base_anim"
ENT.PrintName       = "Past Self (Temporal Echo)"
ENT.Author          = "Rick Sanchez"
ENT.Spawnable       = false
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

		self.Frames     = self.Frames or {}
		self.FrameIndex = 1
	end

	function ENT:SetTimelineFrames(frames, ownerPly)
		self.Frames = frames or {}
		self.FrameIndex = 1
		if IsValid(ownerPly) then
			self:SetModel(ownerPly:GetModel())
			self:SetSkin(ownerPly:GetSkin() or 0)
			self:SetPlayerColor(ownerPly:GetPlayerColor())
			self:SetTravelerName(ownerPly:Nick() .. " (ИЗ ПРОШЛОГО)")
			for i = 0, ownerPly:GetNumBodyGroups() - 1 do
				self:SetBodygroup(i, ownerPly:GetBodygroup(i))
			end
		end
	end

	function ENT:SetPlayerColor(vec)
		self:SetNWVector("PlyColor", vec or Vector(0.24, 0.34, 0.41))
	end

	function ENT:Think()
		if not self.Frames or #self.Frames == 0 then
			self:Remove()
			return
		end

		local f = self.Frames[self.FrameIndex]
		if f then
			self:SetPos(f.pos)
			self:SetAngles(Angle(0, f.ang.y, 0))
			if f.seq then
				self:ResetSequence(f.seq)
				self:SetCycle(f.cycle or ((CurTime() * 1.2) % 1))
			end
		end

		self.FrameIndex = self.FrameIndex + 1
		if self.FrameIndex > #self.Frames then
			-- Loop or finish smoothly
			self.FrameIndex = 1
		end

		self:NextThink(CurTime() + 0.08)
		return true
	end
end

if CLIENT then
	function ENT:Initialize()
		self.GetPlayerColor = function(s)
			return s:GetNWVector("PlyColor", Vector(0.24, 0.34, 0.41))
		end
	end

	function ENT:Draw()
		-- Slight temporal shimmer so you recognize it's literally YOU in the past!
		render.SetColorModulation(0.88, 0.96, 1.0)
		self:DrawModel()
		render.SetColorModulation(1, 1, 1)

		local pos = self:GetPos() + Vector(0, 0, 78)
		local ply = LocalPlayer()
		if IsValid(ply) and ply:GetPos():Distance(pos) < 850 then
			local ang = (ply:EyePos() - pos):Angle()
			ang:RotateAroundAxis(ang:Up(), 90)
			ang:RotateAroundAxis(ang:Forward(), 90)

			cam.Start3D2D(pos, ang, 0.12)
				draw.RoundedBox(6, -130, -18, 260, 36, Color(14, 28, 48, 200))
				draw.SimpleText(self:GetTravelerName(), "DermaDefaultBold", 0, 0, Color(125, 235, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			cam.End3D2D()
		end
	end
end
