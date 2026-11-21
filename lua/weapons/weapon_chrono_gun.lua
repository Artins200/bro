AddCSLuaFile()

SWEP.PrintName          = "Chrono-Rewind Blaster (Пушка Времени)"
SWEP.Author             = "Rick Sanchez"
SWEP.Instructions       = "ЛКМ: Открыть временной разлом и откатиться назад во времени (увидите СЕБЯ ИЗ ПРОШЛОГО в действии!)\nПКМ: Вернуться обратно в своё настоящее время\nR (Перезарядка): Изменить глубину отката (-5 / -10 / -15 / -20 / -25 сек)\nВНИМАНИЕ: Если пробыть в прошлом больше 35 секунд — прилетит ПОЛИЦИЯ ВРЕМЕНИ!"
SWEP.Category           = "Rick and Morty"

SWEP.Spawnable          = true
SWEP.AdminOnly          = false

SWEP.ViewModel          = "models/weapons/c_pistol.mdl"
SWEP.WorldModel         = "models/weapons/w_pistol.mdl"
SWEP.ViewModelFOV       = 66
SWEP.UseHands           = true

SWEP.Slot               = 4
SWEP.SlotPos            = 2
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

SWEP.HoldType           = "revolver"

if CLIENT then
	SWEP.WepSelectIcon    = surface.GetTextureID("vgui/entities/weapon_chrono_gun")
	SWEP.BounceWeaponIcon = true
end

function SWEP:SetupDataTables()
	self:NetworkVar("Bool",  0, "InPast")
	self:NetworkVar("Float", 0, "PastDeadline")
	self:NetworkVar("Float", 1, "LastFireTime")
	self:NetworkVar("Int",   0, "RewindSeconds")
end

local ZeroVec = Vector(0.0001, 0.0001, 0.0001)
local PistolWeaponBonesToHide = {
	"ValveBiped.square",
	"ValveBiped.clip",
	"ValveBiped.hammer",
	"ValveBiped.trigger",
	"ValveBiped.muzzle"
}

local ChronoHandPose = {
	["ValveBiped.Bip01_L_Clavicle"]  = { pos = Vector(-20, -16, -32), angle = Angle(-30, -40, 0) },
	["ValveBiped.Bip01_L_UpperArm"]  = { pos = Vector(0, 0, -24),     angle = Angle(0, -55, 0) },

	["ValveBiped.Bip01_R_Forearm"]   = { pos = Vector(0, 0, 0),       angle = Angle(0, -2, 4) },
	["ValveBiped.Bip01_R_Hand"]      = { pos = Vector(0, 0, 0),       angle = Angle(-6, 6, -8) },

	["ValveBiped.Bip01_R_Finger0"]   = { angle = Angle(16, 22, 10) },
	["ValveBiped.Bip01_R_Finger01"]  = { angle = Angle(-4, 18, 0) },
	["ValveBiped.Bip01_R_Finger1"]   = { angle = Angle(-4, -34, 0) },
	["ValveBiped.Bip01_R_Finger11"]  = { angle = Angle(0, -50, 0) },
	["ValveBiped.Bip01_R_Finger2"]   = { angle = Angle(0, -42, 0) },
	["ValveBiped.Bip01_R_Finger21"]  = { angle = Angle(0, -58, 0) },
	["ValveBiped.Bip01_R_Finger3"]   = { angle = Angle(4, -46, 0) },
	["ValveBiped.Bip01_R_Finger31"]  = { angle = Angle(0, -58, 0) },
	["ValveBiped.Bip01_R_Finger4"]   = { angle = Angle(7, -48, 0) },
	["ValveBiped.Bip01_R_Finger41"]  = { angle = Angle(0, -56, 0) }
}

function SWEP:Initialize()
	self:SetHoldType("revolver")
	if SERVER and self:GetRewindSeconds() <= 0 then
		self:SetRewindSeconds(10)
	end

	if CLIENT then
		self.DeployAnimFrac = 0
		self.FireRecoil     = 0
		self.SwayAng        = Angle(0, 0, 0)
		self.LastEyeAng     = nil
	end
end

function SWEP:Deploy()
	self:SetHoldType("revolver")
	self:SendWeaponAnim(ACT_VM_DRAW)
	if CLIENT then
		self.DeployAnimFrac = 0
	end
	if SERVER and RICK_PORTAL and RICK_PORTAL.SyncWeaponTimeState then
		RICK_PORTAL.SyncWeaponTimeState(self:GetOwner(), self)
	end
	return true
end

function SWEP:Holster()
	if CLIENT then
		self:ResetViewModelBones()
	end
	return true
end

function SWEP:OnRemove()
	if CLIENT then
		self:ResetViewModelBones()
	end
end

-- LMB: Rewind Time (or if already in the past, pressing LMB can also return you immediately if desired, or RMB returns!)
function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + 0.65)
	self:SetNextSecondaryFire(CurTime() + 0.45)

	if CLIENT and IsFirstTimePredicted() then
		self.FireRecoil = 1.0
	end

	if SERVER then
		local owner = self:GetOwner()
		if not IsValid(owner) then return end

		owner:SetAnimation(PLAYER_ATTACK1)
		self:SetLastFireTime(CurTime())

		if self:GetInPast() then
			-- Convenient: shooting again while in the past returns you back to the present!
			if RICK_PORTAL and RICK_PORTAL.ReturnToPresentTimeline then
				RICK_PORTAL.ReturnToPresentTimeline(owner, self)
			end
		else
			if RICK_PORTAL and RICK_PORTAL.StartTimeJumpBack then
				RICK_PORTAL.StartTimeJumpBack(owner, self:GetRewindSeconds(), self)
			end
		end
	end
end

-- RMB: Return to Present Timeline!
function SWEP:SecondaryAttack()
	self:SetNextPrimaryFire(CurTime() + 0.45)
	self:SetNextSecondaryFire(CurTime() + 0.65)

	if CLIENT and IsFirstTimePredicted() then
		self.FireRecoil = 0.85
	end

	if SERVER then
		local owner = self:GetOwner()
		if not IsValid(owner) then return end
		self:SetLastFireTime(CurTime())

		if self:GetInPast() then
			if RICK_PORTAL and RICK_PORTAL.ReturnToPresentTimeline then
				RICK_PORTAL.ReturnToPresentTimeline(owner, self)
			end
		else
			-- Cycle rewind depth if not in past!
			local cur = self:GetRewindSeconds()
			local nxt = (cur >= 25) and 5 or (cur + 5)
			self:SetRewindSeconds(nxt)
			owner:EmitSound("buttons/button17.wav", 68, 105 + nxt, 0.7)
		end
	end
end

-- R: Cycle Rewind Seconds (-5s -> -10s -> -15s -> -20s -> -25s)
function SWEP:Reload()
	if (self.NextReload or 0) > CurTime() then return end
	self.NextReload = CurTime() + 0.40

	if SERVER then
		local owner = self:GetOwner()
		if not IsValid(owner) then return end

		if self:GetInPast() then
			if RICK_PORTAL and RICK_PORTAL.ReturnToPresentTimeline then
				RICK_PORTAL.ReturnToPresentTimeline(owner, self)
			end
		else
			local cur = self:GetRewindSeconds()
			local nxt = (cur >= 25) and 5 or (cur + 5)
			self:SetRewindSeconds(nxt)
			owner:EmitSound("buttons/button17.wav", 68, 105 + nxt, 0.7)
		end
	end
end

if CLIENT then
	local matGlow  = Material("sprites/light_glow02_add")
	local matLaser = Material("Effects/laser1")

	function SWEP:ApplyViewModelBones(vm)
		if not IsValid(vm) or not vm:GetBoneCount() or vm:GetBoneCount() <= 0 then return end
		for _, bName in ipairs(PistolWeaponBonesToHide) do
			local bId = vm:LookupBone(bName)
			if bId then vm:ManipulateBoneScale(bId, ZeroVec) end
		end
		for boneName, mod in pairs(ChronoHandPose) do
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
		local owner = self:GetOwner()
		if not IsValid(owner) then return pos, ang end

		local ft = FrameTime()
		local ct = CurTime()

		self.DeployAnimFrac = math.Approach(self.DeployAnimFrac or 0, 1, ft * 3.4)
		self.FireRecoil     = Lerp(math.Clamp(ft * 10, 0, 1), self.FireRecoil or 0, 0)

		local eyeAng = owner:EyeAngles()
		if not self.LastEyeAng then self.LastEyeAng = eyeAng end
		local dYaw   = math.AngleDifference(eyeAng.y, self.LastEyeAng.y)
		local dPitch = math.AngleDifference(eyeAng.p, self.LastEyeAng.p)
		self.LastEyeAng = eyeAng

		self.SwayAng = self.SwayAng or Angle(0, 0, 0)
		self.SwayAng.y = Lerp(math.Clamp(ft * 10, 0, 1), self.SwayAng.y, math.Clamp(-dYaw * 0.38, -5, 5))
		self.SwayAng.p = Lerp(math.Clamp(ft * 10, 0, 1), self.SwayAng.p, math.Clamp(dPitch * 0.35, -4, 4))
		self.SwayAng.r = Lerp(math.Clamp(ft * 10, 0, 1), self.SwayAng.r, math.Clamp(dYaw * 0.28, -4, 4))

		local vel2D    = owner:GetVelocity():Length2D()
		local moveFrac = owner:IsOnGround() and math.Clamp(vel2D / 220, 0, 1.25) or 0.15

		local bobX    = math.sin(ct * 8.5) * 0.45 * moveFrac
		local bobZ    = math.abs(math.cos(ct * 8.5)) * -0.45 * moveFrac
		local bobRoll = math.sin(ct * 8.5) * 1.2 * moveFrac

		local dep        = 1.0 - math.pow(1.0 - (self.DeployAnimFrac or 1), 3)
		local deployDrop = (1.0 - dep) * -7.5
		local deployTilt = (1.0 - dep) * 20.0

		local recBack  = (self.FireRecoil or 0) * -2.6
		local recPitch = (self.FireRecoil or 0) * -7.5

		pos = pos
			+ ang:Forward() * (0.8 + recBack)
			+ ang:Right()   * (0.9 + bobX)
			+ ang:Up()      * (-2.35 + bobZ + deployDrop)

		ang:RotateAroundAxis(ang:Right(),   -(recPitch + deployTilt + self.SwayAng.p - 3.5))
		ang:RotateAroundAxis(ang:Up(),      self.SwayAng.y + 4.0)
		ang:RotateAroundAxis(ang:Forward(), bobRoll + self.SwayAng.r - 3.0)

		return pos, ang
	end

	function SWEP:PreDrawViewModel(vm, wep, ply)
		self:ApplyViewModelBones(vm)
	end

	function SWEP:PostDrawViewModel(vm, wep, ply)
		if not IsValid(vm) or not RICK_PORTAL or not RICK_PORTAL.ChronoGunRenderer then return end
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

		local gunPos, gunAng = LocalToWorld(
			Vector(3.45, -1.55, -1.10),
			Angle(-8, 2, 180),
			origin,
			ang
		)

		local ct        = CurTime()
		local firePulse = math.Clamp(1.0 - (ct - self:GetLastFireTime()) * 2.5, 0, 1)
		local remain    = math.max(0, self:GetPastDeadline() - ct)

		RICK_PORTAL.ChronoGunRenderer:DrawChronoBlaster(gunPos, gunAng, 0.92, {
			firePulse = firePulse,
			inPast    = self:GetInPast(),
			remain    = remain,
			rewindSec = self:GetRewindSeconds()
		})

		-- Expanding Temporal Shockwave Beam out of muzzle on fire!
		if firePulse > 0.05 then
			local muzWorld = LocalToWorld(Vector(10.8 * 0.92, 0, 1.95 * 0.92), Angle(0, 0, 0), gunPos, gunAng)
			render.SetMaterial(matGlow)
			render.DrawSprite(muzWorld, 36 * firePulse, 36 * firePulse, Color(225, 95, 255, 235 * firePulse))
		end
	end

	function SWEP:DrawWorldModel()
		if not RICK_PORTAL or not RICK_PORTAL.ChronoGunRenderer then
			self:DrawModel()
			return
		end

		local ct        = CurTime()
		local firePulse = math.Clamp(1.0 - (ct - self:GetLastFireTime()) * 2.5, 0, 1)
		local owner     = self:GetOwner()
		local state     = {
			firePulse = firePulse,
			inPast    = self:GetInPast(),
			remain    = math.max(0, self:GetPastDeadline() - ct),
			rewindSec = self:GetRewindSeconds()
		}

		if IsValid(owner) then
			local handBone = owner:LookupBone("ValveBiped.Bip01_R_Hand")
			if handBone then
				owner:SetupBones()
				local mtx = owner:GetBoneMatrix(handBone)
				if mtx then
					local gunPos, gunAng = LocalToWorld(Vector(3.5, -1.5, -1.0), Angle(-8, 0, 180), mtx:GetTranslation(), mtx:GetAngles())
					RICK_PORTAL.ChronoGunRenderer:DrawChronoBlaster(gunPos, gunAng, 0.95, state)
					return
				end
			end
		end

		RICK_PORTAL.ChronoGunRenderer:DrawChronoBlaster(self:GetPos(), self:GetAngles(), 1.05, state)
	end

	function SWEP:DrawWorldModelTranslucent()
		self:DrawWorldModel()
	end

	function SWEP:DoDrawCrosshair(x, y)
		local inPast = self:GetInPast()
		surface.DrawCircle(x, y, 8, inPast and 235 or 95, inPast and 95 or 230, 255, 220)
		surface.SetDrawColor(255, 255, 255, 240)
		surface.DrawRect(x - 1, y - 1, 3, 3)
		return true
	end
end
