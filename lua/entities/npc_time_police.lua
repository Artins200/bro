AddCSLuaFile()

ENT.Type        = "anim"
ENT.Base        = "base_anim"
ENT.PrintName   = "Полиция Времени (Time Cop)"
ENT.Author      = "4th Dimension Authority"
ENT.Category    = "Rick and Morty"
ENT.Spawnable   = true
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "TargetCriminal")
	self:NetworkVar("String", 0, "SpeechText")
	self:NetworkVar("Float",  0, "LastSwingTime")
	self:NetworkVar("Float",  1, "CurHP")
	self:NetworkVar("Float",  2, "MaxHP")
	self:NetworkVar("Float",  3, "HurtFlashAt")
end

-- ============================================================================
-- TIME POLICE:
--  1) Protected ONLY against the Omega Device (cannot be erased across timelines),
--     but CAN BE SHOT & KILLED with regular guns, explosives, RPG, crowbar, etc.!
--  2) DETAINS / ARRESTS the player (does NOT insta-kill!): hits with stun baton,
--     locks the player inside a glowing Violet 4th-Dimensional Detention Cage
--     for a sentence ("НА СРОК!"). If you kill the Time Police, the arrest ends!
-- ============================================================================

if SERVER then
	function ENT:SpawnFunction(ply, tr, className)
		if not tr.Hit then return end
		local ent = ents.Create(className)
		ent:SetPos(tr.HitPos + Vector(0, 0, 4))
		ent:SetAngles(Angle(0, (ply:GetPos() - tr.HitPos):Angle().y, 0))
		ent:SetTargetCriminal(ply)
		ent:Spawn()
		ent:Activate()
		return ent
	end

	function ENT:Initialize()
		self:SetModel("models/Combine_Helicopter/helicopter_bomb01.mdl")
		self:DrawShadow(false)

		self:SetMoveType(MOVETYPE_FLY)
		self:SetSolid(SOLID_BBOX)
		self:SetCollisionBounds(Vector(-20, -20, 0), Vector(20, 20, 74))
		self:SetCollisionGroup(COLLISION_GROUP_NONE) -- Hits bullets, rockets, melee cleanly!

		local maxHp = 260
		self:SetMaxHealth(maxHp)
		self:SetHealth(maxHp)
		self:SetMaxHP(maxHp)
		self:SetCurHP(maxHp)

		self:SetSpeechText("НУ ВСЁ, УЕБОК, НА СРОК! ТЫ ЗАДЕРЖАН ПОЛИЦИЕЙ ВРЕМЕНИ!")
		self:EmitSound("RickTime.PoliceArrive")

		self.SpawnTime   = CurTime()
		self.NextAttack  = CurTime() + 0.9
		self.DetainedAt  = nil

		local target = self:GetTargetCriminal()
		if IsValid(target) and target:IsPlayer() then
			target:ChatPrint("[ПОЛИЦИЯ ВРЕМЕНИ]: Ну всё, уебок, на срок! Бросай оружие — ты задержан за игры со временем!")
		end
	end

	function ENT:ReleaseDetainedTarget()
		local target = self:GetTargetCriminal()
		if IsValid(target) and target:IsPlayer() and target:GetNWBool("RickTime_Detained", false) then
			-- Check if any OTHER living Time Cop is still detaining this player
			for _, other in ipairs(ents.FindByClass("npc_time_police")) do
				if IsValid(other) and other ~= self and other:Health() > 0 and other:GetTargetCriminal() == target and other.DetainedAt then
					return
				end
			end

			target:SetNWBool("RickTime_Detained", false)
			target:SetNWFloat("RickTime_SentenceEnd", 0)
			target:SetMoveType(MOVETYPE_WALK)
		end
	end

	function ENT:OnTakeDamage(dmg)
		local amt = dmg:GetDamage()
		if amt <= 0 then return 0 end

		local newHp = math.max(0, self:Health() - amt)
		self:SetHealth(newHp)
		self:SetCurHP(newHp)
		self:SetHurtFlashAt(CurTime())

		-- Angry reaction lines when shot by the player!
		local attacker = dmg:GetAttacker()
		if IsValid(attacker) and attacker:IsPlayer() then
			self:SetTargetCriminal(attacker)
			if newHp > 0 and math.random(1, 3) == 1 then
				self:SetSpeechText("СОПРОТИВЛЕНИЕ ПРИ АРЕСТЕ?! ДОБАВЛЮ ЕЩЁ 1000 ЛЕТ СРОКА!")
			end
		end

		if newHp <= 0 and not self.Dead then
			self.Dead = true
			self:EmitSound("npc/antlion_grub/squashed.wav", 85, 85, 1.0)

			local ed = EffectData()
			ed:SetOrigin(self:WorldSpaceCenter())
			util.Effect("BloodImpact", ed, true, true)

			self:ReleaseDetainedTarget()
			if IsValid(attacker) and attacker:IsPlayer() then
				attacker:ChatPrint("[ПОЛИЦИЯ ВРЕМЕНИ]: Офицер Полиции Времени убит!")
			end

			self:Remove()
		end

		return amt
	end

	function ENT:OnRemove()
		self:ReleaseDetainedTarget()
	end

	function ENT:DetainPlayer(ply)
		if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end

		if not ply:GetNWBool("RickTime_Detained", false) then
			local sentenceDur = 14.0 -- 14-second detention sentence!
			ply:SetNWBool("RickTime_Detained", true)
			ply:SetNWFloat("RickTime_SentenceEnd", CurTime() + sentenceDur)
			ply:SetNWVector("RickTime_CagePos", ply:GetPos())
			ply:SetLocalVelocity(Vector(0, 0, 0))
			ply:ScreenFade(SCREENFADE.IN, Color(195, 75, 255, 140), 0.4, 0.05)
			ply:ChatPrint("[ПОЛИЦИЯ ВРЕМЕНИ]: ВЫ ЗАДЕРЖАНЫ В ТЕМПОРАЛЬНЫХ НАРУЧНИКАХ (14 сек)! Вы всё ещё можете стрелять в полицейских, чтобы вырваться!")
		end

		self.DetainedAt = self.DetainedAt or CurTime()
		self:SetSpeechText("СИДИ В КАМЕРЕ ВРЕМЕНИ И ОТБЫВАЙ СРОК, НАРУШИТЕЛЬ!")
	end

	function ENT:Think()
		local ct     = CurTime()
		local target = self:GetTargetCriminal()

		if not IsValid(target) or (target:IsPlayer() and not target:Alive()) then
			for _, ply in ipairs(player.GetAll()) do
				if IsValid(ply) and ply:Alive() and ply:GetPos():Distance(self:GetPos()) < 1400 then
					target = ply
					self:SetTargetCriminal(ply)
					break
				end
			end
		end

		if IsValid(target) and target:IsPlayer() and target:Alive() then
			-- Check if player finished serving their detention sentence!
			if target:GetNWBool("RickTime_Detained", false) then
				local cagePos = target:GetNWVector("RickTime_CagePos", target:GetPos())
				-- Keep detained criminal inside the glowing 4th-dimensional cage (they can aim & shoot to fight back, but cannot run away!)
				if target:GetPos():Distance(cagePos) > 18 then
					target:SetPos(cagePos)
					target:SetLocalVelocity(Vector(0, 0, 0))
				end

				if ct >= target:GetNWFloat("RickTime_SentenceEnd", 0) then
					target:SetNWBool("RickTime_Detained", false)
					target:SetNWFloat("RickTime_SentenceEnd", 0)
					target:ChatPrint("[ПОЛИЦИЯ ВРЕМЕНИ]: Срок отбыт! Возвращаем тебя в твоё настоящее время — и больше не шали с континуумом!")

					if RICK_PORTAL and RICK_PORTAL.ForceReturnAfterSentence then
						RICK_PORTAL.ForceReturnAfterSentence(target)
					end
					self:Remove()
					return
				end
			end

			local myPos = self:GetPos()
			local tPos  = target:GetPos()
			local diff  = tPos - myPos
			local dist  = diff:Length()

			self:SetAngles(Angle(0, diff:Angle().y, 0))

			-- Approach criminal; once detained, hover right outside the detention cage guarding them!
			local desiredDist = target:GetNWBool("RickTime_Detained", false) and 115 or 72
			if dist > desiredDist then
				local speed   = math.Clamp(dist * 2.2, 220, 440)
				local moveDir = diff:GetNormalized()
				moveDir.z     = (tPos.z - myPos.z) * 0.05
				self:SetVelocity(moveDir:GetNormalized() * speed)
			elseif dist < (desiredDist - 25) then
				self:SetVelocity((-diff:GetNormalized()) * 140)
			else
				self:SetVelocity(Vector(0, 0, 0))

				-- Swing stun baton & detain criminal (light non-lethal 5 HP shock, NO killing!)
				if not target:GetNWBool("RickTime_Detained", false) and ct >= self.NextAttack then
					self.NextAttack = ct + 1.0
					self:SetLastSwingTime(ct)
					self:EmitSound("RickTime.BatonHit")
					target:ViewPunch(Angle(6, math.Rand(-8, 8), 0))
					self:DetainPlayer(target)
				end
			end
		else
			self:SetVelocity(Vector(0, 0, 0))
		end

		self:NextThink(ct + 0.05)
		return true
	end
end

if CLIENT then
	local matGlow  = Material("sprites/light_glow02_add")
	local matLaser = Material("Effects/laser1")

	function ENT:Initialize()
		self:SetRenderBounds(Vector(-50, -50, -10), Vector(50, 50, 100))
	end

	function ENT:Draw()
		-- Drawn in DrawTranslucent
	end

	function ENT:DrawTranslucent()
		if not RICK_PORTAL or not RICK_PORTAL.TimePoliceRenderer then return end

		local ct        = CurTime()
		local pos       = self:GetPos()
		local ang       = self:GetAngles()
		local swingFrac = math.Clamp(1.0 - (ct - self:GetLastSwingTime()) * 3.2, 0, 1)
		local speedFrac = math.Clamp(self:GetVelocity():Length2D() / 380, 0, 1)
		local hurtFrac  = math.Clamp(1.0 - (ct - self:GetHurtFlashAt()) * 5.0, 0, 1)
		local txt       = self:GetSpeechText()

		render.SetMaterial(matGlow)
		render.DrawSprite(pos + Vector(0, 0, 26), 65, 65, hurtFrac > 0.1 and Color(255, 65, 65, 160) or Color(195, 85, 255, 95))

		RICK_PORTAL.TimePoliceRenderer:DrawTimeCop(pos, ang, txt ~= "", swingFrac, speedFrac)

		-- Overhead Speech Bubble + Killable HP Bar!
		local ply = LocalPlayer()
		if IsValid(ply) and ply:GetPos():Distance(pos) < 1300 then
			local bPos = pos + Vector(0, 0, 88 + math.sin(ct * 3.6) * 3.5)
			local bAng = (ply:EyePos() - bPos):Angle()
			bAng:RotateAroundAxis(bAng:Up(), 90)
			bAng:RotateAroundAxis(bAng:Forward(), 90)

			local hpFrac = math.Clamp(self:GetCurHP() / math.max(1, self:GetMaxHP()), 0, 1)

			cam.Start3D2D(bPos, bAng, 0.11)
				if txt and txt ~= "" then
					draw.RoundedBox(8, -255, -36, 510, 44, Color(24, 12, 32, 232))
					surface.SetDrawColor(215, 105, 255, 245)
					surface.DrawOutlinedRect(-255, -36, 510, 44, 2)
					draw.SimpleText(txt, "DermaDefaultBold", 0, -14, Color(255, 225, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end

				-- Health Bar so player clearly sees they can shoot & kill the Time Police!
				draw.RoundedBox(4, -95, 16, 190, 14, Color(20, 10, 25, 220))
				draw.RoundedBox(3, -93, 18, math.floor(186 * hpFrac), 10, Color(235, 65, 115, 250))
				draw.SimpleText(string.format("HP: %d / %d", math.ceil(self:GetCurHP()), math.ceil(self:GetMaxHP())), "DermaDefault", 0, 23, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			cam.End3D2D()
		end
	end

	-- Draw glowing 4th-Dimensional Violet Detention Cage around any detained player!
	hook.Add("PostDrawTranslucentRenderables", "RickTime_DrawDetentionCage", function(bDepth, bSkybox)
		if bSkybox then return end
		local ct = CurTime()

		for _, ply in ipairs(player.GetAll()) do
			if IsValid(ply) and ply:Alive() and ply:GetNWBool("RickTime_Detained", false) then
				local cPos = ply:GetNWVector("RickTime_CagePos", ply:GetPos())
				render.SetMaterial(matLaser)

				local rad  = 34
				local segs = 12
				-- Top & Bottom containment rings + vertical laser bars!
				for s = 0, segs - 1 do
					local a1 = (s / segs) * math.pi * 2 + ct * 1.5
					local a2 = ((s + 1) / segs) * math.pi * 2 + ct * 1.5
					local b1 = cPos + Vector(math.cos(a1) * rad, math.sin(a1) * rad, 2)
					local b2 = cPos + Vector(math.cos(a2) * rad, math.sin(a2) * rad, 2)
					local t1 = b1 + Vector(0, 0, 78)
					local t2 = b2 + Vector(0, 0, 78)

					render.DrawBeam(b1, b2, 4, 0, 1, Color(215, 95, 255, 235))
					render.DrawBeam(t1, t2, 4, 0, 1, Color(215, 95, 255, 235))
					if s % 2 == 0 then
						render.DrawBeam(b1, t1, 5, 0, 1, Color(145, 220, 255, 220))
					end
				end
			end
		end
	end)

	hook.Add("HUDPaint", "RickTime_DetainedHUD", function()
		local ply = LocalPlayer()
		if not IsValid(ply) or not ply:Alive() or not ply:GetNWBool("RickTime_Detained", false) then return end

		local rem = math.max(0, ply:GetNWFloat("RickTime_SentenceEnd", 0) - CurTime())
		local cx  = ScrW() * 0.5
		draw.RoundedBox(8, cx - 260, 95, 520, 64, Color(28, 10, 42, 225))
		surface.SetDrawColor(215, 95, 255, 255)
		surface.DrawOutlinedRect(cx - 260, 95, 520, 64, 2)
		draw.SimpleText(string.format("⛓ ВЫ ЗАДЕРЖАНЫ ПОЛИЦИЕЙ ВРЕМЕНИ! СРОК: %.1f СЕК.", rem), "Trebuchet24", cx, 115, Color(245, 165, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("Убейте офицеров Полиции Времени, чтобы освободиться досрочно!", "DermaDefaultBold", cx, 142, Color(255, 235, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end)
end
