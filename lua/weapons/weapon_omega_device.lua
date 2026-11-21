AddCSLuaFile()

SWEP.PrintName          = "The Omega Device (Handheld)"
SWEP.Author             = "Rick Prime"
SWEP.Instructions       = "ЛКМ по существу: Захватить уменьшенную модель цели в поле Омега-сферы и СТЕРЕТЬ весь её подвид из всех вселенных!\nПКМ: Развернуть большую установку Омега-устройства со стазис-капсулой и встроенным 3D-монитором\nR: Сбросить стёртые подвиды"
SWEP.Category           = "Rick and Morty"

SWEP.Spawnable          = true
SWEP.AdminOnly          = false

SWEP.ViewModel          = "models/weapons/c_pistol.mdl"
SWEP.WorldModel         = "models/weapons/w_pistol.mdl"
SWEP.ViewModelFOV       = 66
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
	self:NetworkVar("String", 0, "LockedModel")
end

local CHARGE_TIME = 1.25

local ZeroVec = Vector(0.0001, 0.0001, 0.0001)
local PistolWeaponBonesToHide = {
	"ValveBiped.square",
	"ValveBiped.clip",
	"ValveBiped.hammer",
	"ValveBiped.trigger",
	"ValveBiped.muzzle"
}

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
		if IsValid(self.MiniHoloEnt) then
			self.MiniHoloEnt:Remove()
			self.MiniHoloEnt = nil
		end
	end
	if SERVER then
		self:SetIsCharging(false)
		self:SetLockedTarget(NULL)
		self:SetLockedModel("")
	end
	return true
end

function SWEP:OnRemove()
	if CLIENT then
		self:ResetViewModelBones()
		if IsValid(self.MiniHoloEnt) then
			self.MiniHoloEnt:Remove()
			self.MiniHoloEnt = nil
		end
	end
end

if SERVER then
	function SWEP:FindAimTarget()
		local owner = self:GetOwner()
		if not IsValid(owner) then return nil end

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
			if tr.Entity:GetClass() == "npc_time_police" then
				return tr.Entity, true
			end
			local sig = RICK_PORTAL.GetSubspeciesSignature(tr.Entity)
			if sig then return tr.Entity, false end
		end

		local bestEnt, bestDot = nil, 0.965
		for _, ent in ipairs(ents.GetAll()) do
			if IsValid(ent) and ent ~= owner then
				if ent:GetClass() == "npc_time_police" or ent:IsNPC() or ent:IsNextBot() or ent:IsPlayer() or string.StartWith(ent:GetClass(), "prop_") then
					local dir = (ent:WorldSpaceCenter() - eyePos)
					if dir:Length() < 3500 then
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
			return bestEnt, (bestEnt:GetClass() == "npc_time_police")
		end
		return nil, false
	end

	function SWEP:Think()
		if not self:GetIsCharging() then return end

		local elapsed = CurTime() - self:GetChargeStart()
		if elapsed >= CHARGE_TIME then
			self:SetIsCharging(false)

			local owner  = self:GetOwner()
			local target = self:GetLockedTarget()

			if IsValid(target) and target:GetClass() ~= "npc_time_police" then
				self:SetLastBlastTime(CurTime())
				self:EmitSound("RickOmega.Erase")

				local erasedCount, subName = RICK_PORTAL.EraseSubspeciesAcrossMultiverse(target, owner)
				if IsValid(owner) and subName then
					owner:ChatPrint(string.format("[OMEGA DEVICE] Подвид «%s» СТЁРТ ИЗ ВСЕХ ВСЕЛЕННЫХ! (Удалено: %d)", subName, erasedCount))
					util.ScreenShake(owner:GetPos(), 10, 8, 1.1, 1500)
				end
			end

			self:SetLockedTarget(NULL)
			self:SetLockedModel("")
		end
	end
end

function SWEP:PrimaryAttack()
	if self:GetIsCharging() then return end
	self:SetNextPrimaryFire(CurTime() + 1.55)

	if SERVER then
		local target, isTimePolice = self:FindAimTarget()
		local owner = self:GetOwner()

		if isTimePolice then
			if IsValid(owner) then
				owner:EmitSound("buttons/button10.wav", 75, 80, 0.9)
				owner:ChatPrint("[OMEGA DEVICE] НЕВОЗМОЖНО: Полиция Времени существует вне вселенных и НЕУЯЗВИМА к Омега-оружию!")
			end
			return
		end

		if not IsValid(target) then
			if IsValid(owner) then
				owner:EmitSound("buttons/button10.wav", 65, 95, 0.6)
			end
			return
		end

		self:SetLockedTarget(target)
		self:SetLockedModel(target:GetModel() or "models/Kleiner.mdl")
		self:SetChargeStart(CurTime())
		self:SetIsCharging(true)
		self:EmitSound("RickOmega.Charge")

		if IsValid(owner) then
			owner:SetAnimation(PLAYER_ATTACK1)
		end
	end
end

function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire(CurTime() + 1.2)
	if CLIENT then return end

	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	local tr = util.TraceLine({
		start  = owner:GetShootPos(),
		endpos = owner:GetShootPos() + owner:GetAimVector() * 260,
		filter = owner,
		mask   = MASK_SOLID_BRUSHONLY
	})

	if IsValid(self.DeployedMachine) then
		self.DeployedMachine:Remove()
	end

	local mach = ents.Create("ent_omega_device")
	if IsValid(mach) then
		mach:SetPos(tr.HitPos)
		mach:SetAngles(Angle(0, owner:EyeAngles().y + 180, 0))
		mach:SetOwner(owner)
		mach:Spawn()
		mach:Activate()
		self.DeployedMachine = mach

		undo.Create("Omega Device Chamber")
			undo.AddEntity(mach)
			undo.SetPlayer(owner)
		undo.Finish()

		owner:EmitSound("RickOmega.Charge")
		owner:ChatPrint("[OMEGA DEVICE] Станция развёрнута! Подойдите к её 3D-монитору и нажимайте E прямо по кнопкам на экране.")
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
		local shake  = charge * 0.40

		pos = pos
			+ ang:Forward() * 0.2
			+ ang:Right()   * (0.6 + math.sin(ct * 42) * shake)
			+ ang:Up()      * (-2.2 + math.cos(ct * 37) * shake)

		ang:RotateAroundAxis(ang:Right(), 2 + math.sin(ct * 1.8) * 0.6)
		ang:RotateAroundAxis(ang:Up(),    4)
		return pos, ang
	end

	function SWEP:PreDrawViewModel(vm, wep, ply)
		self:ApplyViewModelBones(vm)
	end

	-- Renders the Omega Core AND pulls out a spinning miniature 3D hologram model of the victim right inside the core before erasing it!
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

		local ct     = CurTime()
		local charge = self:GetIsCharging() and math.Clamp((ct - self:GetChargeStart()) / CHARGE_TIME, 0, 1) or 0
		local burst  = math.Clamp(1.0 - (ct - self:GetLastBlastTime()) * 1.8, 0, 1)

		local hoverZ = math.sin(ct * 3.4) * 0.30
		local corePos, coreAng = LocalToWorld(Vector(4.8, -3.2, 2.2 + hoverZ), Angle(0, 0, 0), origin, ang)

		-- Draw captured miniature 3D model of the creature spinning & shrinking inside the Omega Core!
		local lockedMdl = self:GetLockedModel()
		if self:GetIsCharging() and lockedMdl and lockedMdl ~= "" then
			if not IsValid(self.MiniHoloEnt) or self.MiniHoloEnt:GetModel() ~= lockedMdl then
				if IsValid(self.MiniHoloEnt) then self.MiniHoloEnt:Remove() end
				self.MiniHoloEnt = ClientsideModel(lockedMdl, RENDERGROUP_TRANSLUCENT)
				if IsValid(self.MiniHoloEnt) then
					self.MiniHoloEnt:SetNoDraw(true)
				end
			end

			if IsValid(self.MiniHoloEnt) then
				local rad = math.max(self.MiniHoloEnt:BoundingRadius(), 12)
				local fitScale = (4.8 / rad) * (1.0 - charge * 0.72) -- shrinks as Omega energy erases it!
				self.MiniHoloEnt:SetPos(corePos - Vector(0, 0, 1.8 * fitScale))
				self.MiniHoloEnt:SetAngles(Angle(0, ct * 240, math.sin(ct * 18) * 15))
				self.MiniHoloEnt:SetModelScale(fitScale, 0)
				self.MiniHoloEnt:SetupBones()

				render.SetColorModulation(0.45 + charge * 0.55, 0.90, 1.0)
				render.SetBlend(0.92)
				self.MiniHoloEnt:DrawModel()
				render.SetBlend(1)
				render.SetColorModulation(1, 1, 1)
			end
		elseif IsValid(self.MiniHoloEnt) then
			self.MiniHoloEnt:Remove()
			self.MiniHoloEnt = nil
		end

		RICK_PORTAL.OmegaRenderer:DrawOmegaCore(corePos, coreAng, 0.24, charge, burst)

		local target = self:GetLockedTarget()
		if self:GetIsCharging() and IsValid(target) then
			local tPos = target:WorldSpaceCenter()
			render.SetMaterial(matLaser)
			render.DrawBeam(corePos, tPos, 5 + charge * 15, 0, 1, Color(85, 215, 255, 235))
			render.DrawBeam(corePos, tPos, 2 + charge * 6,  0, 1, Color(235, 252, 255, 255))
		end
	end

	function SWEP:DrawWorldModel()
		if not RICK_PORTAL or not RICK_PORTAL.OmegaRenderer then
			self:DrawModel()
			return
		end

		local ct     = CurTime()
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
					RICK_PORTAL.OmegaRenderer:DrawOmegaCore(corePos, coreAng, 0.28, charge, burst)
					return
				end
			end
		end

		RICK_PORTAL.OmegaRenderer:DrawOmegaCore(self:GetPos() + Vector(0, 0, 10), self:GetAngles(), 0.36, 0, 0)
	end

	function SWEP:DrawWorldModelTranslucent()
		self:DrawWorldModel()
	end

	function SWEP:DoDrawCrosshair(x, y)
		local charge = self:GetIsCharging() and math.Clamp((CurTime() - self:GetChargeStart()) / CHARGE_TIME, 0, 1) or 0
		surface.DrawCircle(x, y, math.floor(12 - charge * 6), 85, 215, 255, 220)
		surface.SetDrawColor(230, 250, 255, 255)
		surface.DrawRect(x - 2, y - 2, 4, 4)
		return true
	end

	function SWEP:DrawHUD()
		-- Clean screen (no popup GUI!)
	end
end
