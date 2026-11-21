AddCSLuaFile()

ENT.Type                  = "anim"
ENT.Base                  = "base_anim"
ENT.PrintName             = "Temporal Echo (Клон из прошлого)"
ENT.Author                = "Rick Sanchez"
ENT.Spawnable             = false
ENT.AutomaticFrameAdvance = true

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "EchoLabel")
	self:NetworkVar("Bool",   0, "IsPlayerEcho")
	self:NetworkVar("Entity", 0, "OriginPlayer")
	self:NetworkVar("Float",  0, "CurHP")
	self:NetworkVar("Float",  1, "MaxHP")
end

if SERVER then
	function ENT:Initialize()
		self:SetSolid(SOLID_BBOX)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetCollisionBounds(Vector(-16, -16, 0), Vector(16, 16, 72))
		self:SetCollisionGroup(COLLISION_GROUP_NONE) -- Shootable & killable!

		self.Frames    = self.Frames or {}
		self.StartTime = CurTime()
		self.LastFiredFrame = -1
	end

	function ENT:SetupPlayerEcho(frames, ownerPly)
		self.Frames    = frames or {}
		self.StartTime = CurTime()
		self:SetIsPlayerEcho(true)
		self:SetOriginPlayer(ownerPly)

		if IsValid(ownerPly) then
			self:SetModel(ownerPly:GetModel())
			self:SetSkin(ownerPly:GetSkin() or 0)
			self:SetNWVector("PlyColor", ownerPly:GetPlayerColor())
			self:SetEchoLabel(ownerPly:Nick() .. " (ВЫ ИЗ ПРОШЛОГО)")
			for i = 0, ownerPly:GetNumBodyGroups() - 1 do
				self:SetBodygroup(i, ownerPly:GetBodygroup(i))
			end
			local hp = math.max(100, ownerPly:GetMaxHealth())
			self:SetMaxHealth(hp)
			self:SetHealth(hp)
			self:SetMaxHP(hp)
			self:SetCurHP(hp)
		end
	end

	function ENT:SetupNPCEcho(frames, npcRecord)
		self.Frames    = frames or {}
		self.StartTime = CurTime()
		self:SetIsPlayerEcho(false)
		self.NPCRecord = npcRecord

		self:SetModel(npcRecord.model or "models/Combine_Soldier.mdl")
		self:SetSkin(npcRecord.skin or 0)
		self:SetEchoLabel((npcRecord.prettyName or "NPC") .. " (В ПРОШЛОМ)")
		local hp = math.max(60, npcRecord.maxHP or 80)
		self:SetMaxHealth(hp)
		self:SetHealth(hp)
		self:SetMaxHP(hp)
		self:SetCurHP(hp)
	end

	-- ========================================================================
	-- KILLABLE PAST SELF & GRANDFATHER PARADOX!
	-- If you kill your own Past Self, you trigger a Temporal Paradox (and summon
	-- Time Police / suffer paradox shock)! If you kill a revived Past NPC early,
	-- it alters the battle in the past!
	-- ========================================================================
	function ENT:OnTakeDamage(dmg)
		local amt = dmg:GetDamage()
		if amt <= 0 or self.Dead then return 0 end

		local newHp = math.max(0, self:Health() - amt)
		self:SetHealth(newHp)
		self:SetCurHP(newHp)

		local ed = EffectData()
		ed:SetOrigin(dmg:GetDamagePosition() ~= Vector(0,0,0) and dmg:GetDamagePosition() or self:WorldSpaceCenter())
		util.Effect("BloodImpact", ed, true, true)

		if newHp <= 0 then
			self.Dead = true
			self:SpawnDeathRagdoll()

			if self:GetIsPlayerEcho() then
				local origPly = self:GetOriginPlayer()
				if IsValid(origPly) and origPly:Alive() then
					origPly:ChatPrint("[ВРЕМЕННОЙ ПАРАДОКС!]: ВЫ ТОЛЬКО ЧТО УБИЛИ САМОГО СЕБЯ ИЗ ПРОШЛОГО! Континуум разорван — за вами выехала Полиция Времени!")
					origPly:ScreenFade(SCREENFADE.IN, Color(255, 45, 110, 195), 0.75, 0.1)
					util.ScreenShake(origPly:GetPos(), 16, 12, 1.4, 1500)

					-- Grandfather paradox shock + immediate Time Police arrival!
					local pDmg = DamageInfo()
					pDmg:SetDamage(math.min(origPly:Health() - 15, 45))
					pDmg:SetAttacker(origPly)
					pDmg:SetDamageType(DMG_SHOCK)
					if pDmg:GetDamage() > 0 then
						origPly:TakeDamageInfo(pDmg)
					end

					if RICK_PORTAL and RICK_PORTAL.SummonTimePoliceForPlayer then
						RICK_PORTAL.SummonTimePoliceForPlayer(origPly, "ТЫ УБИЛ СЕБЯ ИЗ ПРОШЛОГО?! НУ ВСЁ, УЕБОК, НА ПОЖИЗНЕННЫЙ СРОК!")
					end
				end
			else
				-- Player intervened and killed the Past NPC themselves!
				if self.NPCRecord then
					self.NPCRecord.killedInPastIntervention = true
				end
			end

			self:Remove()
		end
		return amt
	end

	function ENT:SpawnDeathRagdoll()
		local rag = ents.Create("prop_ragdoll")
		if IsValid(rag) then
			rag:SetModel(self:GetModel())
			rag:SetSkin(self:GetSkin() or 0)
			rag:SetPos(self:GetPos())
			rag:SetAngles(self:GetAngles())
			rag:Spawn()
			rag:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
			SafeRemoveEntityDelayed(rag, 12)
		end
	end

	-- Replays recorded movement, combat animations, weapon muzzle flashes, AND recorded death!
	function ENT:Think()
		if self.Dead then return end
		local count = self.Frames and #self.Frames or 0
		if count == 0 then
			self:Remove()
			return
		end

		local elapsed  = CurTime() - (self.StartTime or CurTime())
		local exactIdx = (elapsed / 0.08) + 1

		-- If this is a revived NPC that originally died during this recorded battle window,
		-- replay its exact death moment when the timeline reaches its final recorded frame!
		if not self:GetIsPlayerEcho() and exactIdx >= count then
			if self.NPCRecord and self.NPCRecord.diedInWindow then
				self.Dead = true
				self:EmitSound("npc/combine_soldier/die" .. math.random(1, 3) .. ".wav", 75, 100, 0.8)
				self:SpawnDeathRagdoll()
				self:Remove()
				return
			else
				-- Otherwise loop or hold final frame
				exactIdx = count
			end
		end

		local loopIdx = self:GetIsPlayerEcho() and (((elapsed % math.max(0.08, (count - 1) * 0.08)) / 0.08) + 1) or math.Clamp(exactIdx, 1, count)
		local idxA    = math.Clamp(math.floor(loopIdx), 1, count)
		local idxB    = math.Clamp(idxA + 1, 1, count)
		local alpha   = loopIdx - idxA

		local fA = self.Frames[idxA]
		local fB = self.Frames[idxB] or fA

		if fA then
			local interpPos = LerpVector(alpha, fA.pos, fB.pos)
			local interpYaw = LerpAngle(alpha, Angle(0, fA.ang.y, 0), Angle(0, fB.ang.y, 0))
			self:SetPos(interpPos)
			self:SetAngles(interpYaw)

			-- Replay weapon firing tracer & gunshot sound when your Past Self or Past NPC was shooting!
			if fA.fired and self.LastFiredFrame ~= idxA then
				self.LastFiredFrame = idxA
				self:EmitSound(fA.fireSnd or "Weapon_SMG1.Single", 75, 102, 0.75)

				local muzPos = interpPos + Vector(0, 0, 52) + interpYaw:Forward() * 22
				local aimEnd = fA.aimPos or (muzPos + fA.ang:Forward() * 600)
				local ed = EffectData()
				ed:SetStart(muzPos)
				ed:SetOrigin(aimEnd)
				ed:SetScale(5000)
				util.Effect("Tracer", ed, true, true)
			end

			local targetSeq = fA.seq
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
		local isPlyEcho = self:GetIsPlayerEcho()

		render.SetMaterial(matGlow)
		render.DrawSprite(
			pos + Vector(0, 0, 38),
			50, 72,
			isPlyEcho and Color(185, 105, 255, 60 + math.sin(ct * 6) * 18) or Color(95, 215, 255, 50)
		)

		self:DrawModel()

		local headTagPos = pos + Vector(0, 0, 78)
		local ply = LocalPlayer()
		if IsValid(ply) and ply:GetPos():Distance(headTagPos) < 950 then
			local ang = (ply:EyePos() - headTagPos):Angle()
			ang:RotateAroundAxis(ang:Up(), 90)
			ang:RotateAroundAxis(ang:Forward(), 90)

			local hpFrac = math.Clamp(self:GetCurHP() / math.max(1, self:GetMaxHP()), 0, 1)

			cam.Start3D2D(headTagPos, ang, 0.105)
				draw.RoundedBox(6, -145, -24, 290, 44, Color(18, 14, 34, 215))
				surface.SetDrawColor(isPlyEcho and 205 or 95, 125, 255, 220)
				surface.DrawOutlinedRect(-145, -24, 290, 44, 2)
				draw.SimpleText(self:GetEchoLabel(), "DermaDefaultBold", 0, -10, Color(235, 215, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

				-- HP bar showing you can attack/intervene with your Past Self or Past NPCs!
				draw.RoundedBox(3, -90, 6, 180, 8, Color(30, 20, 40, 220))
				draw.RoundedBox(3, -89, 7, math.floor(178 * hpFrac), 6, isPlyEcho and Color(235, 85, 255) or Color(95, 225, 255))
			cam.End3D2D()
		end
	end
end
