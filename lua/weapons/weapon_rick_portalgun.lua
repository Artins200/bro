AddCSLuaFile()

SWEP.PrintName          = "Rick's Portal Gun"
SWEP.Author             = "Rick Sanchez (C-137)"
SWEP.Instructions       = "ЛКМ: Открыть Портал A (стена / земля / воздух)\nПКМ: Открыть Портал B (связанный выход)\nR (Перезарядка): Закрыть открытые порталы\nE + R: Сменить код измерения на дисплее"
SWEP.Category           = "Rick and Morty"

SWEP.Spawnable          = true
SWEP.AdminOnly          = false

-- Use c_pistol with UseHands = true so Garry's Mod renders the player's actual playermodel c_hands
-- gripping the handle cleanly in first-person!
SWEP.ViewModel          = "models/weapons/c_pistol.mdl"
SWEP.WorldModel         = "models/weapons/w_pistol.mdl"
SWEP.ViewModelFOV       = 62
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
	SWEP.WepSelectIcon = surface.GetTextureID("vgui/entities/weapon_rick_portalgun")
	SWEP.BounceWeaponIcon = true
end

function SWEP:SetupDataTables()
	self:NetworkVar("Entity", 0, "PortalA")
	self:NetworkVar("Entity", 1, "PortalB")
	self:NetworkVar("Int",    0, "DimIndex")
	self:NetworkVar("Float",  0, "LastFireTime")
end

-- ============================================================================
-- Custom 1st-Person Hand Finger Pose & 3rd-Person Arm/Hand Hold Pose
-- Ensures the player visibly & naturally grips the angled round handle of the Portal Gun!
-- ============================================================================

-- Left arm tucked naturally at the player's side in first-person (one-handed Rick style!),
-- Right hand fingers wrapped smoothly around the rounded ergonomic grip without touching an invisible trigger guard.
local ViewModelBoneMods = {
	-- Tuck left arm cleanly out of view so player holds the Portal Gun single-handed like Rick Sanchez!
	["ValveBiped.Bip01_L_Clavicle"]  = { pos = Vector(-16, -12, -28), angle = Angle(-25, -35, 0) },
	["ValveBiped.Bip01_L_UpperArm"]  = { pos = Vector(0, 0, -18),     angle = Angle(0, -45, 0) },

	-- Right wrist & palm ergonomics aligned with our 20-degree swept cylindrical grip
	["ValveBiped.Bip01_R_Hand"]      = { pos = Vector(0, 0, 0),       angle = Angle(-4, 6, -4) },
	["ValveBiped.Bip01_R_Finger0"]   = { pos = Vector(0, 0, 0),       angle = Angle(14, 18, 8) },
	["ValveBiped.Bip01_R_Finger01"]  = { pos = Vector(0, 0, 0),       angle = Angle(0, 22, 0) },
	["ValveBiped.Bip01_R_Finger02"]  = { pos = Vector(0, 0, 0),       angle = Angle(0, 18, 0) },

	-- Index finger curled comfortably around upper grip neck (since Rick's gun has no trigger guard, thumb operates top dial)
	["ValveBiped.Bip01_R_Finger1"]   = { pos = Vector(0, 0, 0),       angle = Angle(-4, -32, 0) },
	["ValveBiped.Bip01_R_Finger11"]  = { pos = Vector(0, 0, 0),       angle = Angle(0, -48, 0) },
	["ValveBiped.Bip01_R_Finger12"]  = { pos = Vector(0, 0, 0),       angle = Angle(0, -32, 0) },

	-- Middle, Ring, Pinky wrapped snugly around the cylindrical handle
	["ValveBiped.Bip01_R_Finger2"]   = { pos = Vector(0, 0, 0),       angle = Angle(0, -38, 0) },
	["ValveBiped.Bip01_R_Finger21"]  = { pos = Vector(0, 0, 0),       angle = Angle(0, -55, 0) },
	["ValveBiped.Bip01_R_Finger22"]  = { pos = Vector(0, 0, 0),       angle = Angle(0, -36, 0) },

	["ValveBiped.Bip01_R_Finger3"]   = { pos = Vector(0, 0, 0),       angle = Angle(3, -42, 0) },
	["ValveBiped.Bip01_R_Finger31"]  = { pos = Vector(0, 0, 0),       angle = Angle(0, -56, 0) },
	["ValveBiped.Bip01_R_Finger32"]  = { pos = Vector(0, 0, 0),       angle = Angle(0, -38, 0) },

	["ValveBiped.Bip01_R_Finger4"]   = { pos = Vector(0, 0, 0),       angle = Angle(6, -44, 0) },
	["ValveBiped.Bip01_R_Finger41"]  = { pos = Vector(0, 0, 0),       angle = Angle(0, -54, 0) },
	["ValveBiped.Bip01_R_Finger42"]  = { pos = Vector(0, 0, 0),       angle = Angle(0, -36, 0) }
}

function SWEP:Initialize()
	self:SetHoldType("pistol")
	if self:GetDimIndex() <= 0 then
		self:SetDimIndex(1)
	end

	if CLIENT then
		self.DeployAnimFrac = 0
		self.FireRecoil     = 0
		self.DialKick       = 0
		self.SwayPos        = Vector(0, 0, 0)
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
-- Server Portal Linking & Fluid Projectile Firing
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

		-- Link Portal A <-> Portal B bi-directionally!
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

		-- Spawn green fluid slightly forward & to the right (matching muzzle of the hand-held Portal Gun)
		local muzzlePos = eyePos + aimDir * 18 + right * 7 - up * 4
		-- Check if player is standing super close to a wall/ground so muzzle doesn't clip behind wall
		local trNear = util.TraceLine({
			start = eyePos,
			endpos = muzzlePos,
			filter = owner,
			mask = MASK_SOLID
		})
		if trNear.Hit then
			muzzlePos = eyePos + aimDir * 4
		end

		-- Aim convergence: aim toward exact crosshair target (or max free-air distance if aiming into open sky/air!)
		local maxDistCvar = GetConVar("sv_rickportal_maxdist")
		local freeAirDist = maxDistCvar and maxDistCvar:GetFloat() or 420

		local trAim = util.TraceLine({
			start = eyePos,
			endpos = eyePos + aimDir * freeAirDist,
			filter = owner,
			mask = MASK_SOLID
		})

		local targetPos = trAim.Hit and trAim.HitPos or (eyePos + aimDir * freeAirDist)
		local launchDir = (targetPos - muzzlePos):GetNormalized()
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

	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	if SERVER then
		-- E + Reload: Cycle Dimension Code on the Red LED Display ("C-137" -> "C-131" -> ...)
		if owner:KeyDown(IN_USE) then
			local dims = RICK_PORTAL.Dimensions or { "C-137" }
			local nextIdx = (self:GetDimIndex() % #dims) + 1
			self:SetDimIndex(nextIdx)
			owner:EmitSound("buttons/button15.wav", 65, 115, 0.6)
			return
		end

		-- Standard Reload: Smoothly close active portals!
		local closedAny = false
		if IsValid(self:GetPortalA()) and not self:GetPortalA():GetIsClosing() then
			self:GetPortalA():CloseSmoothly()
			closedAny = true
		end
		if IsValid(self:GetPortalB()) and not self:GetPortalB():GetIsClosing() then
			self:GetPortalB():CloseSmoothly()
			closedAny = true
		end

		if not closedAny then
			-- Also allow cycling dimension if no portals are open so R always feels interactive!
			local dims = RICK_PORTAL.Dimensions or { "C-137" }
			local nextIdx = (self:GetDimIndex() % #dims) + 1
			self:SetDimIndex(nextIdx)
			owner:EmitSound("buttons/button15.wav", 65, 118, 0.55)
		end
	end

	if CLIENT and IsFirstTimePredicted() then
		self.DialKick = 0.85
	end
end

-- ============================================================================
-- Client Rendering: Polished First-Person Hold, Idle Breathing, Walk Bob,
-- Recoil, Finger Grip Pose & Third-Person WorldModel Grip!
-- ============================================================================

if CLIENT then
	local matGlow = Material("sprites/light_glow02_add")

	function SWEP:GetDimensionString()
		local dims = (RICK_PORTAL and RICK_PORTAL.Dimensions) or { "C-137" }
		local idx = math.Clamp(self:GetDimIndex(), 1, #dims)
		return dims[idx] or "C-137"
	end

	function SWEP:ApplyViewModelBones(vm)
		if not IsValid(vm) or not vm:GetBoneCount() or vm:GetBoneCount() <= 0 then return end
		for boneName, mod in pairs(ViewModelBoneMods) do
			local boneId = vm:LookupBone(boneName)
			if boneId then
				if mod.pos then vm:ManipulateBonePosition(boneId, mod.pos) end
				if mod.angle then vm:ManipulateBoneAngles(boneId, mod.angle) end
			end
		end

		-- Subtle thumb press animation on top black rotary wheel when firing/switching dimensions!
		local thumbBone = vm:LookupBone("ValveBiped.Bip01_R_Finger01")
		if thumbBone and (self.DialKick or 0) > 0.01 then
			vm:ManipulateBoneAngles(thumbBone, Angle(0, 22 + self.DialKick * 18, 0))
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

	-- Smooth procedural viewmodel camera sway, breathing, walk bob & comfortable lower-right hold angle
	-- so you clearly see the hand gripping the handle + the red LED screen + the bubbling green dome!
	function SWEP:CalcViewModelView(vm, oldPos, oldAng, pos, ang)
		local owner = self:GetOwner()
		if not IsValid(owner) then return pos, ang end

		local ft = FrameTime()
		local ct = CurTime()

		-- Decay recoil & deploy spring
		self.DeployAnimFrac = math.Approach(self.DeployAnimFrac or 0, 1, ft * 3.4)
		self.FireRecoil     = Lerp(math.Clamp(ft * 11, 0, 1), self.FireRecoil or 0, 0)
		self.DialKick       = Lerp(math.Clamp(ft * 9, 0, 1), self.DialKick or 0, 0)

		-- Smooth mouse look lag / inertia sway
		local eyeAng = owner:EyeAngles()
		if not self.LastEyeAng then self.LastEyeAng = eyeAng end
		local dYaw   = math.AngleDifference(eyeAng.y, self.LastEyeAng.y)
		local dPitch = math.AngleDifference(eyeAng.p, self.LastEyeAng.p)
		self.LastEyeAng = eyeAng

		self.SwayAng = self.SwayAng or Angle(0, 0, 0)
		self.SwayAng.y = Lerp(math.Clamp(ft * 10, 0, 1), self.SwayAng.y, math.Clamp(-dYaw * 0.45, -7, 7))
		self.SwayAng.p = Lerp(math.Clamp(ft * 10, 0, 1), self.SwayAng.p, math.Clamp(dPitch * 0.40, -6, 6))
		self.SwayAng.r = Lerp(math.Clamp(ft * 10, 0, 1), self.SwayAng.r, math.Clamp(dYaw * 0.35, -6, 6))

		-- Walk / sprint bobbing + idle Rick breathing
		local vel2D = owner:GetVelocity():Length2D()
		local onGround = owner:IsOnGround()
		local moveFrac = onGround and math.Clamp(vel2D / 220, 0, 1.35) or 0.15

		local idlePitch = math.sin(ct * 1.9) * 0.65
		local idleRoll  = math.cos(ct * 1.4) * 0.55
		local bobX      = math.sin(ct * 8.5) * 0.55 * moveFrac
		local bobZ      = math.abs(math.cos(ct * 8.5)) * -0.55 * moveFrac
		local bobRoll   = math.sin(ct * 8.5) * 1.6 * moveFrac

		-- Deploy smooth raise-into-hand curve
		local dep = 1.0 - math.pow(1.0 - (self.DeployAnimFrac or 1), 3)
		local deployDrop = (1.0 - dep) * -9.0
		local deployTilt = (1.0 - dep) * 24.0

		-- Recoil kick when shooting green fluid
		local recBack  = (self.FireRecoil or 0) * -2.2
		local recPitch = (self.FireRecoil or 0) * -5.5

		local fwd   = ang:Forward()
		local right = ang:Right()
		local up    = ang:Up()

		-- Position tuned so the player's right hand & wrist, the angled grip, the red "C-137" display,
		-- the glass plasma chamber, and the 3 front bulbs are all clearly framed & comfortable!
		pos = pos
			+ fwd   * (2.2 + recBack)
			+ right * (1.8 + bobX)
			+ up    * (-1.35 + bobZ + deployDrop)

		ang:RotateAroundAxis(ang:Right(),   -(idlePitch + recPitch + deployTilt + self.SwayAng.p))
		ang:RotateAroundAxis(ang:Up(),      self.SwayAng.y - 3.5)
		ang:RotateAroundAxis(ang:Forward(), idleRoll + bobRoll + self.SwayAng.r + 3.0)

		return pos, ang
	end

	-- Hide the underlying HL2 pistol mesh while keeping c_hands 100% visible!
	function SWEP:PreDrawViewModel(vm, wep, ply)
		self:ApplyViewModelBones(vm)
		render.SetBlend(0)
	end

	-- Restore blend so Garry's Mod draws c_hands cleanly, then render our custom 3D Rick Portal Gun
	-- anchored directly to the right hand bone (`ValveBiped.Bip01_R_Hand`)!
	function SWEP:PostDrawViewModel(vm, wep, ply)
		render.SetBlend(1)

		if not IsValid(vm) then return end
		if not RICK_PORTAL or not RICK_PORTAL.GunRenderer then return end

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

		-- Transform from ValveBiped.Bip01_R_Hand bone space into our Portal Gun grip space:
		-- In ValveBiped_R_Hand: Forward points from wrist toward knuckles, Right points out of palm, Up points along thumb.
		-- Placing grip origin at (3.25, -1.45, -0.35) seats the cylindrical handle right inside the curled fingers & palm!
		local gunPos, gunAng = LocalToWorld(
			Vector(3.35, -1.52, -0.45),
			Angle(-8, 2, 180),
			origin,
			ang
		)

		local firePulse = math.Clamp(1.0 - (CurTime() - self:GetLastFireTime()) * 3.2, 0, 1)

		RICK_PORTAL.GunRenderer:DrawGun(gunPos, gunAng, 0.68, {
			firePulse = firePulse,
			dimCode   = self:GetDimensionString()
		})

		-- Muzzle flash burst when firing green fluid
		if firePulse > 0.05 then
			local muzWorld = LocalToWorld(Vector(8.2 * 0.68, 0, 2.05 * 0.68), Angle(0, 0, 0), gunPos, gunAng)
			render.SetMaterial(matGlow)
			render.DrawSprite(muzWorld, 18 * firePulse, 18 * firePulse, Color(125, 255, 80, 220 * firePulse))
		end
	end

	-- ========================================================================
	-- Third-Person & Dropped WorldModel Rendering + Natural Player Grip Pose!
	-- ========================================================================
	function SWEP:DrawWorldModel()
		if not RICK_PORTAL or not RICK_PORTAL.GunRenderer then
			self:DrawModel()
			return
		end

		local owner = self:GetOwner()
		local firePulse = math.Clamp(1.0 - (CurTime() - self:GetLastFireTime()) * 3.2, 0, 1)

		if IsValid(owner) then
			-- Ensure 3rd-person player holds it cleanly in one hand (pistol/revolver stance)
			local handBone = owner:LookupBone("ValveBiped.Bip01_R_Hand")
			if handBone then
				owner:SetupBones()
				local mtx = owner:GetBoneMatrix(handBone)
				if mtx then
					local hPos = mtx:GetTranslation()
					local hAng = mtx:GetAngles()

					local gunPos, gunAng = LocalToWorld(
						Vector(3.4, -1.5, -0.4),
						Angle(-8, 0, 180),
						hPos,
						hAng
					)

					RICK_PORTAL.GunRenderer:DrawGun(gunPos, gunAng, 0.72, {
						firePulse = firePulse,
						dimCode   = self:GetDimensionString()
					})

					-- Subtle green illumination on the player in dark rooms
					local dlightConVar = GetConVar("cl_rickportal_dlight")
					if not dlightConVar or dlightConVar:GetBool() then
						local dl = DynamicLight(self:EntIndex())
						if dl then
							dl.pos = gunPos + gunAng:Up() * 3
							dl.r = 90
							dl.g = 235
							dl.b = 65
							dl.brightness = 1.1 + firePulse * 1.4
							dl.Decay = 800
							dl.Size = 95
							dl.DieTime = CurTime() + 0.08
						end
					end
					return
				end
			end
		end

		-- Dropped on the ground as an item
		RICK_PORTAL.GunRenderer:DrawGun(self:GetPos(), self:GetAngles(), 0.78, {
			firePulse = 0,
			dimCode   = self:GetDimensionString()
		})
	end

	function SWEP:DrawWorldModelTranslucent()
		self:DrawWorldModel()
	end

	-- Subtle Green-and-White Rick & Morty Crosshair + Portal Status Arcs
	function SWEP:DoDrawCrosshair(x, y)
		local hasA = IsValid(self:GetPortalA()) and not self:GetPortalA():GetIsClosing()
		local hasB = IsValid(self:GetPortalB()) and not self:GetPortalB():GetIsClosing()

		surface.SetDrawColor(145, 250, 82, 230)
		surface.DrawRect(x - 2, y - 2, 4, 4)

		local colActive   = Color(138, 245, 76, 240)
		local colInactive = Color(110, 145, 110, 95)

		draw.SimpleText("(", "Trebuchet24", x - 16, y - 1, hasA and colActive or colInactive, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(")", "Trebuchet24", x + 16, y - 1, hasB and colActive or colInactive, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		return true
	end

	-- Minimalist, clean Rick & Morty HUD indicator showing Portal A / Portal B status & current Dimension
	function SWEP:DrawHUD()
		local hasA = IsValid(self:GetPortalA()) and not self:GetPortalA():GetIsClosing()
		local hasB = IsValid(self:GetPortalB()) and not self:GetPortalB():GetIsClosing()
		local colActive = Color(138, 245, 76, 235)

		-- Compact bottom-right dimension badge
		local bx, by = ScrW() - 175, ScrH() - 68
		draw.RoundedBox(8, bx, by, 148, 44, Color(16, 24, 18, 195))
		draw.SimpleText("DIM: " .. self:GetDimensionString(), "DermaDefaultBold", bx + 74, by + 15, Color(255, 82, 72, 245), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		local statusTxt = (hasA and hasB) and "PORTALS LINKED" or ((hasA or hasB) and "1 PORTAL OPEN" or "READY")
		draw.SimpleText(statusTxt, "DermaDefault", bx + 74, by + 32, (hasA and hasB) and colActive or Color(175, 215, 165, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end
