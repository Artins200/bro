AddCSLuaFile()

SWEP.PrintName          = "The Omega Device"
SWEP.Author             = "Rick Prime"
SWEP.Instructions       = "ЛКМ: Навести луч Омега-оружия на цель — СТИРАЕТ ВСЕХ существ этого подвида из всех вселенных навсегда!\nПКМ: Разместить гигантскую установку Омега-устройства в мире\nR (Перезарядка): Восстановить стёртые подвиды (сбросить мультивселенную)"
SWEP.Category           = "Rick and Morty"

SWEP.Spawnable          = true
SWEP.AdminOnly          = false

SWEP.ViewModel          = "models/weapons/c_pistol.mdl"
SWEP.WorldModel         = "models/weapons/w_pistol.mdl"
SWEP.ViewModelFOV       = 68
SWEP.UseHands           = true

SWEP.Slot               = 4
SWEP.SlotPos            = 1
SWEP.DrawAmmo           = false
SWEP.DrawCrosshair      = true

SWEP.Primary.ClipSize       = -1
SWEP.Primary.DefaultClip    = -1
SWEP.Primary.Automatic      = false
SWEP.Primary.Ammo           = "none"

SWEP.Secondary.ClipSize     = -1
SWEP.Secondary.DefaultClip  = -1
SWEP.Secondary.Automatic    = false
SWEP.Secondary.Ammo         = "none"

SWEP.HoldType           = "magic"

if CLIENT then
	SWEP.WepSelectIcon    = surface.GetTextureID("vgui/entities/weapon_omega_device")
	SWEP.BounceWeaponIcon = true
end

function SWEP:SetupDataTables()
	self:NetworkVar("Float",  0, "ChargeStart")
	self:NetworkVar("Float",  1, "LastBlastTime")
	self:NetworkVar("Bool",   0, "IsCharging")
	self:NetworkVar("Entity", 0, "LockedTarget")
	self:NetworkVar("Vector", 0, "LastBlastPos")
end

local CHARGE_TIME = 1.05

local ZeroVec = Vector(0.0001, 0.0001, 0.0001)
local PistolWeaponBonesToHide = {
	"ValveBiped.square",
	"ValveBiped.clip",
	"ValveBiped.hammer",
	"ValveBiped.trigger",
	"ValveBiped.muzzle"
}

-- Open-palm telekinetic/gauntlet hand pose cradling the floating rotating Omega Core!
local OmegaHandPose = {
	["ValveBiped.Bip01_L_Clavicle"]  = { pos = Vector(-20, -16, -32), angle = Angle(-30, -40, 0) },
	["ValveBiped.Bip01_L_UpperArm"]  = { pos = Vector(0, 0, -24),     angle = Angle(0, -55, 0) },

	["ValveBiped.Bip01_R_Forearm"]   = { pos = Vector(0, 0, 0),       angle = Angle(0, -6, 25) },
	["ValveBiped.Bip01_R_Hand"]      = { pos = Vector(0, 0, 0),       angle = Angle(-18, 12, 35) },

	["ValveBiped.Bip01_R_Finger0"]   = { pos = Vector(0, 0, 0),       angle = Angle(15, 10, 0) },
	["ValveBiped.Bip01_R_Finger01"]  = { pos = Vector(0, 0, 0),       angle = Angle(0, -10, 0) },
	["ValveBiped.Bip01_R_Finger1"]   = { pos = Vector(0, 0, 0),       angle = Angle(-8, 12, 0) },
	["ValveBiped.Bip01_R_Finger11"]  = { pos = Vector(0, 0, 0),       angle = Angle(0, -18, 0) },
	["ValveBiped.Bip01_R_Finger2"]   = { pos = Vector(0, 0, 0),       angle = Angle(0, 14, 0) },
	["ValveBiped.Bip01_R_Finger21"]  = { pos = Vector(0, 0, 0),       angle = Angle(0, -18, 0) },
	["ValveBiped.Bip01_R_Finger3"]   = { pos = Vector(0, 0, 0),       angle = Angle(6, 12, 0) },
	["ValveBiped.Bip01_R_Finger31"]  = { pos = Vector(0, 0, 0),       angle = Angle(0, -20, 0) },
	["ValveBiped.Bip01_R_Finger4"]   = { pos = Vector(0, 0, 0),       angle = Angle(12, 10, 0) },
	["ValveBiped.Bip01_R_Finger41"]  = { pos = Vector(0, 0, 0),       angle = Angle(0, -22, 0) }
}

function SWEP:Initialize()
	self:SetHoldType("magic")
end

function SWEP:Deploy()
	self:SetHoldType("magic")
	self:SendWeaponAnim(ACT_VM_DRAW)
	return true
end

function SWEP:Holster()
	if CLIENT then
		self:ResetViewModelBones()
	end
	if SERVER then
		self:SetIsCharging(false)
		self:SetLockedTarget(NULL)
	end
	return true
end

function SWEP:OnRemove()
	if CLIENT then
		self:ResetViewModelBones()
	end
end

if SERVER then
	function SWEP:FindAimTarget()
		local owner = self:GetOwner()
		if not IsValid(owner) then return nil, nil end

		local eyePos = owner:GetShootPos()
		local aimDir = owner:GetAimVector()

		local tr = util.TraceHull({
			start  = eyePos,
			endpos = eyePos + aimDir * 4000,
			mins   = Vector(-10, -10, -10),
			maxs   = Vector(10, 10, 10),
			filter = owner,
			mask   = MASK_SHOT
		})

		if IsValid(tr.Entity) and not tr.Entity:IsWorld() then
			local sig = RICK_PORTAL.GetSubspeciesSignature(tr.Entity)
			if sig then
				return tr.Entity, tr.HitPos
			end
		end

		-- Fallback cone search near crosshair so locking onto moving NPCs is effortless!
		local bestEnt, bestDot = nil, 0.965
		for _, ent in ipairs(ents.GetAll()) do
			if IsValid(ent) and ent ~= owner and (ent:IsNPC() or ent:IsNextBot() or ent:IsPlayer() or string.StartWith(ent:GetClass(), "prop_")) then
				local sig = RICK_PORTAL.GetSubspeciesSignature(ent)
				if sig then
					local dir = (ent:WorldSpaceCenter() - eyePos)
					local dist = dir:Length()
					if dist < 3500 then
						dir:Normalize()
						local d = dir:Dot(aimDir)
						if d > bestDot then
							bestDot = d
							bestEnt = ent
						end
					end
				end
			end
		end

		if IsValid(bestEnt) then
			return bestEnt, bestEnt:WorldSpaceCenter()
		end

		return nil, tr.HitPos
	end

	function SWEP:Think()
		if not self:GetIsCharging() then return end

		local elapsed = CurTime() - self:GetChargeStart()
		if elapsed >= CHARGE_TIME then
			self:SetIsCharging(false)

			local owner  = self:GetOwner()
			local target = self:GetLockedTarget()
			if not IsValid(target) then
				target = self:FindAimTarget()
			end

			if IsValid(target) then
				local hitPos = target:WorldSpaceCenter()
				self:SetLastBlastPos(hitPos)
				self:SetLastBlastTime(CurTime())
				self:EmitSound("RickOmega.Erase")

				local erasedCount, subName = RICK_PORTAL.EraseSubspeciesAcrossMultiverse(target, owner)
				if IsValid(owner) and subName then
					owner:ChatPrint(string.format("[OMEGA DEVICE] Подвид «%s» СТЁРТ ИЗ ВСЕХ ВСЕЛЕННЫХ! (Уничтожено объектов: %d, повторное появление заблокировано)", subName, erasedCount))
					util.ScreenShake(owner:GetPos(), 10, 8, 1.1, 1500)
				end
			else
				if IsValid(owner) then
					owner:EmitSound("buttons/button10.wav", 70, 90, 0.7)
				end
			end

			self:SetLockedTarget(NULL)
		end
	end
end

function SWEP:PrimaryAttack()
	if self:GetIsCharging() then return end
	self:SetNextPrimaryFire(CurTime() + 1.45)

	if SERVER then
		local target = self:FindAimTarget()
		if not IsValid(target) then
			local owner = self:GetOwner()
			if IsValid(owner) then
				owner:EmitSound("buttons/button10.wav", 65, 95, 0.6)
				owner:ChatPrint("[OMEGA DEVICE] Наведите прицел на существо, NPC, игрока или объект, чтобы стереть его подвид из всех вселенных!")
			end
			return
		end

		self:SetLockedTarget(target)
		self:SetChargeStart(CurTime())
		self:SetIsCharging(true)
		self:EmitSound("RickOmega.Charge")

		if IsValid(self:GetOwner()) then
			self:GetOwner():SetAnimation(PLAYER_ATTACK1)
		end
	end
end

-- RMB spawns the giant standalone Omega Device chamber in the world!
function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire(CurTime() + 1.2)
	if CLIENT then return end

	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	local tr = util.TraceLine({
		start  = owner:GetShootPos(),
		endpos = owner:GetShootPos() + owner:GetAimVector() * 450,
		filter = owner,
		mask   = MASK_SOLID_BRUSHONLY
	})

	local spawnPos = tr.HitPos + Vector(0, 0, 95)

	-- Keep max 1 personal deployed Omega Device per player so they don't clutter
	if IsValid(self.DeployedMachine) then
		self.DeployedMachine:Remove()
	end

	local mach = ents.Create("ent_omega_device")
	if IsValid(mach) then
		mach:SetPos(spawnPos)
		mach:SetAngles(Angle(0, owner:EyeAngles().y + 180, 0))
		mach:SetOwner(owner)
		mach:Spawn()
		mach:Activate()
		self.DeployedMachine = mach

		undo.Create("Omega Device")
			undo.AddEntity(mach)
			undo.SetPlayer(owner)
		undo.Finish()

		owner:EmitSound("RickOmega.Charge")
		owner:ChatPrint("[OMEGA DEVICE] Установка развёрнута! Бросьте в её синее ядро любое существо/предмет или нажмите E рядом с ней.")
	end
end

function SWEP:Reload()
	if (self.NextReload or 0) > CurTime() then return end
	self.NextReload = CurTime() + 0.8

	if SERVER then
		local count = table.Count(RICK_PORTAL.ErasedSubspecies or {})
		if count > 0 then
			RICK_PORTAL.ResetErasedMultiverse()
			if IsValid(self:GetOwner()) then
				self:GetOwner():EmitSound("buttons/button19.wav", 75, 110, 0.8)
				self:GetOwner():ChatPrint("[OMEGA DEVICE] Все стёртые подвиды возвращены во вселенные.")
			end
		end
	end
end

if CLIENT then
	local matLaser = Material("Effects/laser1")
	local matGlow  = Material("sprites/light_glow02_add")

	function SWEP:ApplyViewModelBones(vm)
		if not IsValid(vm) or not vm:GetBoneCount() or vm:GetBoneCount() <= 0 then return end
		for _, bName in ipairs(PistolWeaponBonesToHide) do
			local bId = vm:LookupBone(bName)
			if bId then vm:ManipulateBoneScale(bId, ZeroVec) end
		end
		for boneName, mod in pairs(OmegaHandPose) do
			local boneId = vm:LookupBone(boneName)
			if boneId then
				if mod.pos then vm:ManipulateBonePosition(boneId, mod.pos) end
				if mod.angle then vm:ManipulateBoneAngles(boneId, mod.angle) end
			end
		end
	end

	function SWEP:ResetViewModelBones()
		local owner = self:GetOwner()
		if not IsValid(owner) or not owner:IsPlayer() then return end
		local vm = owner:GetViewModel()
		if not IsValid(vm) or not vm:GetBoneCount() then return end
		for i = 0, vm:GetBoneCount() - 1 do
			vm:ManipulateBoneScale(i, Vector(1, 1, 1))
			vm:ManipulateBoneAngles(i, Angle(0, 0, 0))
			vm:ManipulateBonePosition(i, Vector(0, 0, 0))
		end
	end

	function SWEP:CalcViewModelView(vm, oldPos, oldAng, pos, ang)
		local ct = CurTime()
		local charge = self:GetIsCharging() and math.Clamp((ct - self:GetChargeStart()) / CHARGE_TIME, 0, 1) or 0
		local shake = charge * 0.45

		pos = pos
			+ ang:Forward() * -1.5
			+ ang:Right()   * (-1.2 + math.sin(ct * 42) * shake)
			+ ang:Up()      * (1.8  + math.cos(ct * 37) * shake)

		ang:RotateAroundAxis(ang:Right(), 4 + math.sin(ct * 1.8) * 0.7)
		ang:RotateAroundAxis(ang:Up(),    6)
		return pos, ang
	end

	function SWEP:PreDrawViewModel(vm, wep, ply)
		self:ApplyViewModelBones(vm)
	end

	function SWEP:PostDrawViewModel(vm, wep, ply)
		if not IsValid(vm) or not RICK_PORTAL or not RICK_PORTAL.OmegaRenderer then return end

		vm:SetupBones()
		local handBone = vm:LookupBone("ValveBiped.Bip01_R_Hand")
		local origin, ang = vm:GetPos(), vm:GetAngles()
		if handBone then
			local mtx = vm:GetBoneMatrix(handBone)
			if mtx then
				origin = mtx:GetTranslation()
				ang    = mtx:GetAngles()
			end
		end

		local ct = CurTime()
		local charge = self:GetIsCharging() and math.Clamp((ct - self:GetChargeStart()) / CHARGE_TIME, 0, 1) or 0
		local burst  = math.Clamp(1.0 - (ct - self:GetLastBlastTime()) * 1.8, 0, 1)

		local hoverZ = math.sin(ct * 3.4) * 0.35
		local corePos, coreAng = LocalToWorld(Vector(4.8, -3.2, 2.2 + hoverZ), Angle(0, 0, 0), origin, ang)

		RICK_PORTAL.OmegaRenderer:DrawOmegaCore(corePos, coreAng, 0.25, charge, burst)

		-- Draw intense locking/erasure beam toward locked target!
		local target = self:GetLockedTarget()
		if self:GetIsCharging() and IsValid(target) then
			local tPos = target:WorldSpaceCenter()
			render.SetMaterial(matLaser)
			render.DrawBeam(corePos, tPos, 6 + charge * 18, 0, 1, Color(85, 215, 255, 235))
			render.DrawBeam(corePos, tPos, 2 + charge * 8,  0, 1, Color(235, 252, 255, 255))
		elseif burst > 0.05 then
			local bPos = self:GetLastBlastPos()
			if bPos and bPos:LengthSqr() > 1 then
				render.SetMaterial(matLaser)
				render.DrawBeam(corePos, bPos, 34 * burst, 0, 1, Color(95, 220, 255, 255 * burst))
				render.DrawBeam(corePos, bPos, 16 * burst, 0, 1, Color(245, 255, 255, 255 * burst))
			end
		end
	end

	function SWEP:DrawWorldModel()
		if not RICK_PORTAL or not RICK_PORTAL.OmegaRenderer then
			self:DrawModel()
			return
		end

		local ct = CurTime()
		local charge = self:GetIsCharging() and math.Clamp((ct - self:GetChargeStart()) / CHARGE_TIME, 0, 1) or 0
		local burst  = math.Clamp(1.0 - (ct - self:GetLastBlastTime()) * 1.8, 0, 1)
		local owner  = self:GetOwner()

		if IsValid(owner) then
			local handBone = owner:LookupBone("ValveBiped.Bip01_R_Hand")
			if handBone then
				owner:SetupBones()
				local mtx = owner:GetBoneMatrix(handBone)
				if mtx then
					local corePos, coreAng = LocalToWorld(Vector(5.5, -2.5, 2.0), Angle(0, 0, 0), mtx:GetTranslation(), mtx:GetAngles())
					RICK_PORTAL.OmegaRenderer:DrawOmegaCore(corePos, coreAng, 0.30, charge, burst)

					if self:GetIsCharging() and IsValid(self:GetLockedTarget()) then
						render.SetMaterial(matLaser)
						render.DrawBeam(corePos, self:GetLockedTarget():WorldSpaceCenter(), 10 + charge * 20, 0, 1, Color(95, 220, 255, 245))
					end
					return
				end
			end
		end

		RICK_PORTAL.OmegaRenderer:DrawOmegaCore(self:GetPos() + Vector(0, 0, 10), self:GetAngles(), 0.38, 0, 0)
	end

	function SWEP:DrawWorldModelTranslucent()
		self:DrawWorldModel()
	end

	function SWEP:DoDrawCrosshair(x, y)
		local charge = self:GetIsCharging() and math.Clamp((CurTime() - self:GetChargeStart()) / CHARGE_TIME, 0, 1) or 0
		local rad = math.floor(14 - charge * 8)
		surface.DrawCircle(x, y, rad, 85, 215, 255, 230)
		surface.SetDrawColor(230, 250, 255, 255)
		surface.DrawRect(x - 2, y - 2, 4, 4)
		return true
	end

	function SWEP:DrawHUD()
		local owner = self:GetOwner()
		if not IsValid(owner) then return end

		-- Show target subspecies scanner & count of permanently erased subspecies
		local tr = util.TraceLine({
			start  = owner:EyePos(),
			endpos = owner:EyePos() + owner:GetAimVector() * 3500,
			filter = owner,
			mask   = MASK_SHOT
		})

		local cx, cy = ScrW() * 0.5, ScrH() * 0.5
		if IsValid(tr.Entity) and not tr.Entity:IsWorld() then
			local sig, prettyName = RICK_PORTAL.GetSubspeciesSignature(tr.Entity)
			if sig then
				draw.SimpleText("ЦЕЛЬ ОМЕГА-ЛУЧА: " .. tostring(prettyName), "DermaDefaultBold", cx, cy + 28, Color(115, 230, 255, 245), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end

		if self:GetIsCharging() then
			local frac = math.Clamp((CurTime() - self:GetChargeStart()) / CHARGE_TIME, 0, 1)
			draw.RoundedBox(6, cx - 110, cy + 48, 220, 16, Color(10, 20, 32, 210))
			draw.RoundedBox(4, cx - 108, cy + 50, math.floor(216 * frac), 12, Color(85, 220, 255, 250))
			draw.SimpleText("СТИРАНИЕ ИЗ ВСЕХ ВСЕЛЕННЫХ...", "DermaDefaultBold", cx, cy + 74, Color(220, 250, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		-- List of currently erased subspecies in bottom-right corner
		local erased = RICK_PORTAL.ErasedSubspecies or {}
		local visibleList = {}
		for sig, info in pairs(erased) do
			if not string.StartWith(sig, "ragdoll_mdl:") then
				visibleList[#visibleList + 1] = info.name or sig
			end
		end

		if #visibleList > 0 then
			local boxH = 34 + math.min(#visibleList, 6) * 18
			local bx, by = ScrW() - 285, ScrH() - boxH - 22
			draw.RoundedBox(8, bx, by, 265, boxH, Color(12, 18, 30, 210))
			draw.SimpleText("СТЁРТО ИЗ ВСЕХ ВСЕЛЕННЫХ (R - сброс):", "DermaDefaultBold", bx + 132, by + 14, Color(95, 215, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			for i = 1, math.min(#visibleList, 6) do
				draw.SimpleText("✕ " .. visibleList[i], "DermaDefault", bx + 14, by + 18 + i * 18, Color(225, 245, 255, 230), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
		end
	end
end
