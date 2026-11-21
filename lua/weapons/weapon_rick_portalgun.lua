AddCSLuaFile()

SWEP.PrintName          = "Rick's Portal Gun"
SWEP.Author             = "Rick Sanchez"
SWEP.Instructions       = "ЛКМ: Выстрелить Порталом A (стена / земля / воздух)\nПКМ: Выстрелить Порталом B (связанный выход)\nR (Перезарядка): Закрыть открытые порталы\nВся информация отображается прямо на мини-экране пушки!"
SWEP.Category           = "Rick and Morty"

SWEP.Spawnable          = true
SWEP.AdminOnly          = false

-- Use c_pistol with UseHands = true AND scale only the pistol weapon bones to zero (NOT render.SetBlend(0)!),
-- so the player's actual c_hands / forearm / fingers are 100% OPAQUE and visibly gripping the handle!
SWEP.ViewModel          = "models/weapons/c_pistol.mdl"
SWEP.WorldModel         = "models/weapons/w_pistol.mdl"
SWEP.ViewModelFOV       = 68
SWEP.UseHands           = true

SWEP.Slot               = 0
SWEP.SlotPos            = 4
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

SWEP.HoldType           = "pistol"

if CLIENT then
	SWEP.WepSelectIcon    = surface.GetTextureID("vgui/entities/weapon_rick_portalgun")
	SWEP.BounceWeaponIcon = true
end

function SWEP:SetupDataTables()
	self:NetworkVar("Entity", 0, "PortalA")
	self:NetworkVar("Entity", 1, "PortalB")
	self:NetworkVar("Float",  0, "LastFireTime")
end

-- ============================================================================
-- Custom 1st-Person Hand & Finger Pose:
-- 1) Hides ONLY the HL2 pistol bones (`ValveBiped.square`, `ValveBiped.clip`, etc.) via zero scale
--    while keeping `c_hands` 100% visible!
-- 2) Brings the right forearm, wrist, thumb & fingers clearly into the viewport wrapping around
--    the teardrop grip, while tucking the left hand naturally out of the way (one-handed Rick grip).
-- ============================================================================
local ZeroVec = Vector(0.0001, 0.0001, 0.0001)

local PistolWeaponBonesToHide = {
	"ValveBiped.square",
	"ValveBiped.clip",
	"ValveBiped.hammer",
	"ValveBiped.trigger",
	"ValveBiped.muzzle"
}

local ViewModelHandPose = {
	-- Tuck left arm down cleanly so Rick holds the Portal Gun one-handed with full view of right hand!
	["ValveBiped.Bip01_L_Clavicle"]  = { pos = Vector(-20, -16, -32), angle = Angle(-30, -40, 0) },
	["ValveBiped.Bip01_L_UpperArm"]  = { pos = Vector(0, 0, -24),     angle = Angle(0, -55, 0) },

	-- Right wrist angled slightly inward & upward so the forearm, knuckles & thumb are clearly seen holding the handle!
	["ValveBiped.Bip01_R_Forearm"]   = { pos = Vector(0, 0, 0),       angle = Angle(2, -4, 8) },
	["ValveBiped.Bip01_R_Hand"]      = { pos = Vector(0, 0, 0),       angle = Angle(-10, 8, -12) },

	-- Thumb resting right up near the black rear-top trigger switch!
	["ValveBiped.Bip01_R_Finger0"]   = { pos = Vector(0, 0, 0),       angle = Angle(18, 24, 12) },
	["ValveBiped.Bip01_R_Finger01"]  = { pos = Vector(0, 0, 0),       angle = Angle(-4, 18, 0) },
	["ValveBiped.Bip01_R_Finger02"]  = { pos = Vector(0, 0, 0),       angle = Angle(0, 16, 0) },

	-- 4 fingers wrapped tightly around the rounded teardrop handle
	["ValveBiped.Bip01_R_Finger1"]   = { pos = Vector(0, 0, 0),       angle = Angle(-4, -36, 0) },
	["ValveBiped.Bip01_R_Finger11"]  = { pos = Vector(0, 0, 0),       angle = Angle(0, -52, 0) },
	["ValveBiped.Bip01_R_Finger12"]  = { pos = Vector(0, 0, 0),       angle = Angle(0, -34, 0) },

	["ValveBiped.Bip01_R_Finger2"]   = { pos = Vector(0, 0, 0),       angle = Angle(0, -42, 0) },
	["ValveBiped.Bip01_R_Finger21"]  = { pos = Vector(0, 0, 0),       angle = Angle(0, -58, 0) },
	["ValveBiped.Bip01_R_Finger22"]  = { pos = Vector(0, 0, 0),       angle = Angle(0, -38, 0) },

	["ValveBiped.Bip01_R_Finger3"]   = { pos = Vector(0, 0, 0),       angle = Angle(4, -46, 0) },
	["ValveBiped.Bip01_R_Finger31"]  = { pos = Vector(0, 0, 0),       angle = Angle(0, -58, 0) },
	["ValveBiped.Bip01_R_Finger32"]  = { pos = Vector(0, 0, 0),       angle = Angle(0, -40, 0) },

	["ValveBiped.Bip01_R_Finger4"]   = { pos = Vector(0, 0, 0),       angle = Angle(7, -48, 0) },
	["ValveBiped.Bip01_R_Finger41"]  = { pos = Vector(0, 0, 0),       angle = Angle(0, -56, 0) },
	["ValveBiped.Bip01_R_Finger42"]  = { pos = Vector(0, 0, 0),       angle = Angle(0, -38, 0) }
}

function SWEP:Initialize()
	self:SetHoldType("pistol")

	if CLIENT then
		self.DeployAnimFrac = 0
		self.FireRecoil     = 0
		self.DialKick       = 0
		self.SwayAng        = Angle(0, 0, 0)
		self.LastEyeAng     = nil
	end
end

function SWEP:Deploy()
	self:SetHoldType("pistol")
	self:SendWeaponAnim(ACT_VM_DRAW)
	if CLIENT then
		self.DeployAnimFrac = 0
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
	if SERVER then
		if IsValid(self:GetPortalA()) then self:GetPortalA():CloseSmoothly() end
		if IsValid(self:GetPortalB()) then self:GetPortalB():CloseSmoothly() end
	end
end

-- ============================================================================
-- Server Portal Linking & Fluid Projectile Firing (No Dimension Switching!)
-- ============================================================================

if SERVER then
	function SWEP:RegisterPortal(slot, newPortal)
		if not IsValid(newPortal) then return end

		if slot == 1 then
			local oldA = self:GetPortalA()
			if IsValid(oldA) and oldA ~= newPortal then
				oldA:CloseSmoothly()
			end
			self:SetPortalA(newPortal)
		else
			local oldB = self:GetPortalB()
			if IsValid(oldB) and oldB ~= newPortal then
				oldB:CloseSmoothly()
			end
			self:SetPortalB(newPortal)
		end

		local pA = self:GetPortalA()
		local pB = self:GetPortalB()
		if IsValid(pA) and not pA:GetIsClosing() and IsValid(pB) and not pB:GetIsClosing() then
			pA:SetLinkedPortal(pB)
			pB:SetLinkedPortal(pA)
		end
	end

	function SWEP:ShootPortalFluid(slot)
		local owner = self:GetOwner()
		if not IsValid(owner) then return end

		owner:SetAnimation(PLAYER_ATTACK1)
		self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
		self:EmitSound("RickPortal.Shoot")
		self:SetLastFireTime(CurTime())

		local eyePos = owner:GetShootPos()
		local aimDir = owner:GetAimVector()
		local right  = owner:EyeAngles():Right()
		local up     = owner:EyeAngles():Up()

		local muzzlePos = eyePos + aimDir * 20 + right * 8 - up * 4
		local trNear = util.TraceLine({
			start  = eyePos,
			endpos = muzzlePos,
			filter = owner,
			mask   = MASK_SOLID
		})
		if trNear.Hit then
			muzzlePos = eyePos + aimDir * 4
		end

		local maxDistCvar = GetConVar("sv_rickportal_maxdist")
		local freeAirDist = maxDistCvar and maxDistCvar:GetFloat() or 420

		local trAim = util.TraceLine({
			start  = eyePos,
			endpos = eyePos + aimDir * freeAirDist,
			filter = owner,
			mask   = MASK_SOLID
		})

		local targetPos  = trAim.Hit and trAim.HitPos or (eyePos + aimDir * freeAirDist)
		local launchDir  = (targetPos - muzzlePos):GetNormalized()
		local travelDist = muzzlePos:Distance(targetPos)

		local blob = ents.Create("ent_rick_portal_blob")
		if IsValid(blob) then
			blob:SetPos(muzzlePos)
			blob:SetAngles(launchDir:Angle())
			blob:SetOwner(owner)
			blob:SetStartPos(muzzlePos)
			blob:SetLaunchDir(launchDir)
			blob:SetMaxTravelDist(math.max(travelDist, 65))
			blob:SetPortalSlot(slot)
			blob.WeaponRef = self
			blob:Spawn()
			blob:Activate()
		end
	end
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + 0.42)
	self:SetNextSecondaryFire(CurTime() + 0.35)

	if CLIENT and IsFirstTimePredicted() then
		self.FireRecoil = 1.0
		self.DialKick   = 1.0
	end

	if SERVER then
		self:ShootPortalFluid(1)
	end
end

function SWEP:SecondaryAttack()
	self:SetNextPrimaryFire(CurTime() + 0.35)
	self:SetNextSecondaryFire(CurTime() + 0.42)

	if CLIENT and IsFirstTimePredicted() then
		self.FireRecoil = 1.0
		self.DialKick   = 1.0
	end

	if SERVER then
		self:ShootPortalFluid(2)
	end
end

function SWEP:Reload()
	if (self.NextReloadTime or 0) > CurTime() then return end
	self.NextReloadTime = CurTime() + 0.55

	if SERVER then
		local closedAny = false
		if IsValid(self:GetPortalA()) and not self:GetPortalA():GetIsClosing() then
			self:GetPortalA():CloseSmoothly()
			closedAny = true
		end
		if IsValid(self:GetPortalB()) and not self:GetPortalB():GetIsClosing() then
			self:GetPortalB():CloseSmoothly()
			closedAny = true
		end

		if closedAny and IsValid(self:GetOwner()) then
			self:GetOwner():EmitSound("buttons/button15.wav", 65, 95, 0.55)
		end
	end

	if CLIENT and IsFirstTimePredicted() then
		self.DialKick = 0.85
	end
end

-- ============================================================================
-- Client Rendering: Visible Hand Grip + Full-Size Accurate Portal Gun +
-- Live Mini-Screen Telemetry Right on the Gun!
-- ============================================================================

if CLIENT then
	local matGlow = Material("sprites/light_glow02_add")

	function SWEP:ApplyViewModelBones(vm)
		if not IsValid(vm) or not vm:GetBoneCount() or vm:GetBoneCount() <= 0 then return end

		-- 1) Collapse ONLY the HL2 9mm pistol mesh bones to 0.0001 so c_hands stay 100% visible!
		for _, bName in ipairs(PistolWeaponBonesToHide) do
			local bId = vm:LookupBone(bName)
			if bId then
				vm:ManipulateBoneScale(bId, ZeroVec)
			end
		end

		-- 2) Apply ergonomic right-hand finger wrap & tuck left arm cleanly
		for boneName, mod in pairs(ViewModelHandPose) do
			local boneId = vm:LookupBone(boneName)
			if boneId then
				if mod.pos then vm:ManipulateBonePosition(boneId, mod.pos) end
				if mod.angle then vm:ManipulateBoneAngles(boneId, mod.angle) end
			end
		end

		-- Animate thumb pressing the black rear-top switch when firing!
		local thumbBone = vm:LookupBone("ValveBiped.Bip01_R_Finger01")
		if thumbBone and (self.DialKick or 0) > 0.01 then
			vm:ManipulateBoneAngles(thumbBone, Angle(-4, 18 + self.DialKick * 22, 0))
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

	-- Computes live aim telemetry to display directly on the Portal Gun's red mini-screen
	function SWEP:GetLiveScreenState()
		local owner = self:GetOwner()
		local hasA  = IsValid(self:GetPortalA()) and not self:GetPortalA():GetIsClosing()
		local hasB  = IsValid(self:GetPortalB()) and not self:GetPortalB():GetIsClosing()
		local firePulse = math.Clamp(1.0 - (CurTime() - self:GetLastFireTime()) * 3.2, 0, 1)

		local distM    = 0
		local surfType = "AIR"

		if IsValid(owner) then
			local maxDistCvar = GetConVar("sv_rickportal_maxdist")
			local freeAirDist = maxDistCvar and maxDistCvar:GetFloat() or 420
			local eyePos = owner:EyePos()
			local tr = util.TraceLine({
				start  = eyePos,
				endpos = eyePos + owner:GetAimVector() * freeAirDist,
				filter = owner,
				mask   = MASK_SOLID
			})
			local dUnits = tr.Hit and eyePos:Distance(tr.HitPos) or freeAirDist
			distM = dUnits * 0.01905 -- Source units -> meters

			if tr.Hit then
				if tr.HitNormal.z > 0.65 then
					surfType = "FLOOR"
				elseif tr.HitNormal.z < -0.65 then
					surfType = "CEIL"
				else
					surfType = "WALL"
				end
			else
				surfType = "MID-AIR"
			end
		end

		return {
			firePulse   = firePulse,
			dialKick    = self.DialKick or 0,
			hasA        = hasA,
			hasB        = hasB,
			targetDistM = distM,
			surfType    = surfType
		}
	end

	-- Viewmodel framing: pulled slightly UP and CLOSER so:
	-- 1) The player's right forearm, wrist, thumb & curled fingers holding the teardrop grip are 100% in view!
	-- 2) The Portal Gun itself looks substantial, chunky & iconic (not tiny!).
	-- 3) The top red LED mini-screen is tilted comfortably toward your eyes so every stat is readable!
	function SWEP:CalcViewModelView(vm, oldPos, oldAng, pos, ang)
		local owner = self:GetOwner()
		if not IsValid(owner) then return pos, ang end

		local ft = FrameTime()
		local ct = CurTime()

		self.DeployAnimFrac = math.Approach(self.DeployAnimFrac or 0, 1, ft * 3.4)
		self.FireRecoil     = Lerp(math.Clamp(ft * 11, 0, 1), self.FireRecoil or 0, 0)
		self.DialKick       = Lerp(math.Clamp(ft * 9, 0, 1), self.DialKick or 0, 0)

		local eyeAng = owner:EyeAngles()
		if not self.LastEyeAng then self.LastEyeAng = eyeAng end
		local dYaw   = math.AngleDifference(eyeAng.y, self.LastEyeAng.y)
		local dPitch = math.AngleDifference(eyeAng.p, self.LastEyeAng.p)
		self.LastEyeAng = eyeAng

		self.SwayAng = self.SwayAng or Angle(0, 0, 0)
		self.SwayAng.y = Lerp(math.Clamp(ft * 10, 0, 1), self.SwayAng.y, math.Clamp(-dYaw * 0.42, -6, 6))
		self.SwayAng.p = Lerp(math.Clamp(ft * 10, 0, 1), self.SwayAng.p, math.Clamp(dPitch * 0.38, -5, 5))
		self.SwayAng.r = Lerp(math.Clamp(ft * 10, 0, 1), self.SwayAng.r, math.Clamp(dYaw * 0.32, -5, 5))

		local vel2D    = owner:GetVelocity():Length2D()
		local moveFrac = owner:IsOnGround() and math.Clamp(vel2D / 220, 0, 1.3) or 0.15

		local idlePitch = math.sin(ct * 1.9) * 0.55
		local idleRoll  = math.cos(ct * 1.4) * 0.45
		local bobX      = math.sin(ct * 8.5) * 0.50 * moveFrac
		local bobZ      = math.abs(math.cos(ct * 8.5)) * -0.50 * moveFrac
		local bobRoll   = math.sin(ct * 8.5) * 1.4 * moveFrac

		local dep        = 1.0 - math.pow(1.0 - (self.DeployAnimFrac or 1), 3)
		local deployDrop = (1.0 - dep) * -8.5
		local deployTilt = (1.0 - dep) * 22.0

		local recBack  = (self.FireRecoil or 0) * -2.4
		local recPitch = (self.FireRecoil or 0) * -6.0

		local fwd   = ang:Forward()
		local right = ang:Right()
		local up    = ang:Up()

		-- Raised & brought slightly inward so the hand holding the handle + big gun + mini-screen fill a great 1st-person silhouette!
		pos = pos
			+ fwd   * (-2.2 + recBack)
			+ right * (-1.4 + bobX)
			+ up    * (2.15 + bobZ + deployDrop)

		ang:RotateAroundAxis(ang:Right(),   -(idlePitch + recPitch + deployTilt + self.SwayAng.p - 6.5))
		ang:RotateAroundAxis(ang:Up(),      self.SwayAng.y + 7.5)
		ang:RotateAroundAxis(ang:Forward(), idleRoll + bobRoll + self.SwayAng.r - 6.0)

		return pos, ang
	end

	-- Apply bone pose BEFORE viewmodel draws — DO NOT call render.SetBlend(0), so c_hands render at 100% opacity!
	function SWEP:PreDrawViewModel(vm, wep, ply)
		self:ApplyViewModelBones(vm)
	end

	-- Draw our large, chunky, reference-accurate Portal Gun seated directly inside the visible right hand!
	function SWEP:PostDrawViewModel(vm, wep, ply)
		if not IsValid(vm) then return end
		if not RICK_PORTAL or not RICK_PORTAL.GunRenderer then return end

		vm:SetupBones()
		local handBone = vm:LookupBone("ValveBiped.Bip01_R_Hand")
		local origin, ang

		if handBone then
			local mtx = vm:GetBoneMatrix(handBone)
			if mtx then
				origin = mtx:GetTranslation()
				ang    = mtx:GetAngles()
			end
		end

		if not origin then
			origin = vm:GetPos()
			ang    = vm:GetAngles()
		end

		-- Seat the teardrop handle right inside the curled fingers of ValveBiped.Bip01_R_Hand,
		-- at a substantial 1.18 scale (almost 2x larger than before!) so it matches the show!
		local gunPos, gunAng = LocalToWorld(
			Vector(3.55, -1.65, -1.25),
			Angle(-12, 4, 180),
			origin,
			ang
		)

		local state = self:GetLiveScreenState()
		local scale = 1.18

		RICK_PORTAL.GunRenderer:DrawGun(gunPos, gunAng, scale, state)

		if state.firePulse > 0.05 then
			local muzWorld = LocalToWorld(Vector(8.9 * scale, 0, 2.25 * scale), Angle(0, 0, 0), gunPos, gunAng)
			render.SetMaterial(matGlow)
			render.DrawSprite(muzWorld, 26 * state.firePulse, 26 * state.firePulse, Color(125, 255, 80, 225 * state.firePulse))
		end
	end

	-- ========================================================================
	-- Third-Person & Dropped WorldModel (Substantial Scale 1.15!)
	-- ========================================================================
	function SWEP:DrawWorldModel()
		if not RICK_PORTAL or not RICK_PORTAL.GunRenderer then
			self:DrawModel()
			return
		end

		local owner = self:GetOwner()
		local state = self:GetLiveScreenState()
		local scale = 1.15

		if IsValid(owner) then
			local handBone = owner:LookupBone("ValveBiped.Bip01_R_Hand")
			if handBone then
				owner:SetupBones()
				local mtx = owner:GetBoneMatrix(handBone)
				if mtx then
					local hPos = mtx:GetTranslation()
					local hAng = mtx:GetAngles()

					local gunPos, gunAng = LocalToWorld(
						Vector(3.6, -1.6, -1.1),
						Angle(-10, 0, 180),
						hPos,
						hAng
					)

					RICK_PORTAL.GunRenderer:DrawGun(gunPos, gunAng, scale, state)

					local dlightConVar = GetConVar("cl_rickportal_dlight")
					if not dlightConVar or dlightConVar:GetBool() then
						local dl = DynamicLight(self:EntIndex())
						if dl then
							dl.pos        = gunPos + gunAng:Up() * 4
							dl.r          = 90
							dl.g          = 235
							dl.b          = 65
							dl.brightness = 1.3 + state.firePulse * 1.5
							dl.Decay      = 800
							dl.Size       = 110
							dl.DieTime    = CurTime() + 0.08
						end
					end
					return
				end
			end
		end

		RICK_PORTAL.GunRenderer:DrawGun(self:GetPos(), self:GetAngles(), 1.20, state)
	end

	function SWEP:DrawWorldModelTranslucent()
		self:DrawWorldModel()
	end

	-- Minimal clean center dot crosshair only — ALL weapon info lives on the Portal Gun's own mini-screen!
	function SWEP:DoDrawCrosshair(x, y)
		surface.SetDrawColor(145, 250, 82, 220)
		surface.DrawRect(x - 2, y - 2, 4, 4)
		return true
	end

	function SWEP:DrawHUD()
		-- Intentionally empty: all Portal Gun telemetry is displayed diegetically on the gun's mini-screen!
	end
end
