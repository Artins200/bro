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
end

-- ============================================================================
-- ABSOLUTE IMMUNITY: Time Police exist outside standard 3D timelines and
-- CANNOT be damaged, dissolved, or erased by the Omega Device!
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
		self:SetCollisionBounds(Vector(-18, -18, 0), Vector(18, 18, 72))
		self:SetCollisionGroup(COLLISION_GROUP_NPC)
		self:SetHealth(999999)

		self:SetSpeechText("НУ ВСЁ, УЕБОК, НА СРОК! ТЫ НАРУШИЛ ЗАКОНЫ ВРЕМЕНИ!")
		self:EmitSound("RickTime.PoliceArrive")

		self.SpawnTime   = CurTime()
		self.NextAttack  = CurTime() + 1.2
		self.ArrestDone  = false

		local target = self:GetTargetCriminal()
		if IsValid(target) and target:IsPlayer() then
			target:ChatPrint("[ПОЛИЦИЯ ВРЕМЕНИ]: Ну всё, уебок, на срок! Нехрен было торчать в прошлом дольше 35 секунд!")
		end
	end

	function ENT:OnTakeDamage(dmg)
		-- 100% Immune to bullets, explosions, dissolves, and Omega weapons!
		dmg:SetDamage(0)
		return 0
	end

	function ENT:Think()
		local ct     = CurTime()
		local target = self:GetTargetCriminal()

		-- Find nearest player if spawned manually without criminal
		if not IsValid(target) or (target:IsPlayer() and not target:Alive()) then
			if self.ArrestDone and (ct - self.SpawnTime) > 6 then
				self:Remove()
				return
			end
			for _, ply in ipairs(player.GetAll()) do
				if IsValid(ply) and ply:Alive() and ply:GetPos():Distance(self:GetPos()) < 1500 then
					target = ply
					self:SetTargetCriminal(ply)
					break
				end
			end
		end

		if IsValid(target) then
			local myPos = self:GetPos()
			local tPos  = target:GetPos()
			local diff  = tPos - myPos
			local dist  = diff:Length()

			-- Face the time criminal
			local faceAng = Angle(0, diff:Angle().y, 0)
			self:SetAngles(faceAng)

			-- Float swiftly straight toward the offender (even phasing over obstacles if needed!)
			if dist > 68 then
				local speed = math.Clamp(dist * 2.2, 240, 480)
				local moveDir = diff:GetNormalized()
				moveDir.z = (tPos.z - myPos.z) * 0.05
				self:SetVelocity(moveDir:GetNormalized() * speed)
			else
				self:SetVelocity(Vector(0, 0, 0))

				-- Beat & arrest the time offender with the 4th-dimensional Time Baton!
				if ct >= self.NextAttack then
					self.NextAttack = ct + 0.85
					self:SetLastSwingTime(ct)
					self:EmitSound("RickTime.BatonHit")

					if target:IsPlayer() then
						target:ScreenFade(SCREENFADE.IN, Color(195, 75, 255, 165), 0.35, 0.05)
						target:ViewPunch(Angle(math.Rand(-12, 12), math.Rand(-15, 15), 0))

						local dmg = DamageInfo()
						dmg:SetDamage(45)
						dmg:SetAttacker(self)
						dmg:SetInflictor(self)
						dmg:SetDamageType(DMG_SHOCK)
						target:TakeDamageInfo(dmg)

						if not target:Alive() then
							self.ArrestDone = true
							self:SetSpeechText("ДЕЛО ЗАКРЫТО. ПРЕСТУПНИК ОТПРАВЛЕН В ТЮРЬМУ ВРЕМЕНИ!")
							if RICK_PORTAL and RICK_PORTAL.ClearPlayerTimeTravelState then
								RICK_PORTAL.ClearPlayerTimeTravelState(target, true)
							end
							timer.Simple(3.2, function()
								if IsValid(self) then self:Remove() end
							end)
						end
					end
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
	local matGlow = Material("sprites/light_glow02_add")

	function ENT:Initialize()
		self:SetRenderBounds(Vector(-45, -45, -10), Vector(45, 45, 95))
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
		local txt       = self:GetSpeechText()

		-- Purple 4th-dimensional aura underneath floating Time Cop
		render.SetMaterial(matGlow)
		render.DrawSprite(pos + Vector(0, 0, 26), 65, 65, Color(195, 85, 255, 95))

		RICK_PORTAL.TimePoliceRenderer:DrawTimeCop(pos, ang, txt ~= "", swingFrac, speedFrac)

		-- Overhead comic speech bubble ("НУ ВСЁ, УЕБОК, НА СРОК!")
		if txt and txt ~= "" then
			local ply = LocalPlayer()
			if IsValid(ply) and ply:GetPos():Distance(pos) < 1200 then
				local bPos = pos + Vector(0, 0, 86 + math.sin(ct * 3.1) * 3.2)
				local bAng = (ply:EyePos() - bPos):Angle()
				bAng:RotateAroundAxis(bAng:Up(), 90)
				bAng:RotateAroundAxis(bAng:Forward(), 90)

				cam.Start3D2D(bPos, bAng, 0.11)
					draw.RoundedBox(8, -245, -24, 490, 48, Color(24, 12, 32, 230))
					surface.SetDrawColor(215, 105, 255, 245)
					surface.DrawOutlinedRect(-245, -24, 490, 48, 2)
					draw.SimpleText(txt, "DermaDefaultBold", 0, 0, Color(255, 225, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				cam.End3D2D()
			end
		end
	end
end
