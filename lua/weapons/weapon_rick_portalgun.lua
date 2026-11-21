AddCSLuaFile()

SWEP.PrintName          = "Rick's Portal Gun"
SWEP.Author             = "Rick Sanchez"
SWEP.Instructions       = "Режим 1 (DUAL): ЛКМ — Портал A, ПКМ — Портал B\nРежим 2 (MAP SKY): ЛКМ — вид сверху на всю карту и мгновенная пара порталов куда кликнешь!\nE + R: Переключить режим пушки (DUAL / MAP SKY)\nR: Закрыть открытые порталы"
SWEP.Category           = "Rick and Morty"

SWEP.Spawnable          = true
SWEP.AdminOnly          = false

SWEP.ViewModel          = "models/weapons/c_pistol.mdl"
SWEP.WorldModel         = "models/weapons/w_pistol.mdl"
SWEP.ViewModelFOV       = 66
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
	self:NetworkVar("Int",    0, "FireMode") -- 1 = Standard Dual Portals, 2 = Overhead Map Sky View
end

local ZeroVec = Vector(0.0001, 0.0001, 0.0001)

local PistolWeaponBonesToHide = {
	"ValveBiped.square",
	"ValveBiped.clip",
	"ValveBiped.hammer",
	"ValveBiped.trigger",
	"ValveBiped.muzzle"
}

local ViewModelHandPose = {
	["ValveBiped.Bip01_L_Clavicle"]  = { pos = Vector(-20, -16, -32), angle = Angle(-30, -40, 0) },
	["ValveBiped.Bip01_L_UpperArm"]  = { pos = Vector(0, 0, -24),     angle = Angle(0, -55, 0) },

	["ValveBiped.Bip01_R_Forearm"]   = { pos = Vector(0, 0, 0),       angle = Angle(0, -2, 4) },
	["ValveBiped.Bip01_R_Hand"]      = { pos = Vector(0, 0, 0),       angle = Angle(-6, 6, -8) },

	["ValveBiped.Bip01_R_Finger0"]   = { pos = Vector(0, 0, 0),       angle = Angle(16, 22, 10) },
	["ValveBiped.Bip01_R_Finger01"]  = { pos = Vector(0, 0, 0),       angle = Angle(-4, 18, 0) },
	["ValveBiped.Bip01_R_Finger02"]  = { pos = Vector(0, 0, 0),       angle = Angle(0, 16, 0) },

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

if SERVER then
	util.AddNetworkString("RickPG_OpenSkyMap")
	util.AddNetworkString("RickPG_SelectSkyTarget")
end

function SWEP:Initialize()
	self:SetHoldType("pistol")
	if SERVER and self:GetFireMode() <= 0 then
		self:SetFireMode(1)
	end

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
		if RICK_PORTAL and RICK_PORTAL.CloseSkyMap then
			RICK_PORTAL.CloseSkyMap()
		end
	end
	return true
end

function SWEP:OnRemove()
	if CLIENT then
		self:ResetViewModelBones()
		if RICK_PORTAL and RICK_PORTAL.CloseSkyMap then
			RICK_PORTAL.CloseSkyMap()
		end
	end
	if SERVER then
		if IsValid(self:GetPortalA()) then self:GetPortalA():CloseSmoothly() end
		if IsValid(self:GetPortalB()) then self:GetPortalB():CloseSmoothly() end
	end
end

-- ============================================================================
-- Server Portal Linking, Standard Fluid Shot & Overhead Map Instant Pair
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

		local muzzlePos = eyePos + aimDir * 20 + right * 8 - up * 5
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

	-- Spawns Portal A right next to the player AND Portal B at the clicked map coordinates!
	function SWEP:OpenMapPortalPair(worldTargetPos)
		local owner = self:GetOwner()
		if not IsValid(owner) then return end

		owner:SetAnimation(PLAYER_ATTACK1)
		self:EmitSound("RickPortal.Shoot")
		self:SetLastFireTime(CurTime())

		-- 1) Entry Portal A right in front of the player (115 units ahead, upright & facing player so they step straight in!)
		local flatFwd = Angle(0, owner:EyeAngles().y, 0):Forward()
		local nearPos = owner:GetPos() + flatFwd * 115 + Vector(0, 0, 56)

		local trCheck = util.TraceLine({
			start  = owner:WorldSpaceCenter(),
			endpos = nearPos,
			filter = owner,
			mask   = MASK_SOLID_BRUSHONLY
		})
		if trCheck.Hit then
			nearPos = trCheck.HitPos - flatFwd * 26
			nearPos.z = math.max(nearPos.z, owner:GetPos().z + 55)
		end

		local pA = ents.Create("ent_rick_portal")
		if IsValid(pA) then
			pA:SetPos(nearPos)
			pA:SetAngles((-flatFwd):Angle())
			pA:SetOwner(owner)
			pA:SetIsFloorPortal(false)
			pA:SetIsMidAir(true)
			pA:Spawn()
			pA:Activate()
			self:RegisterPortal(1, pA)
		end

		-- 2) Exit Portal B at the exact clicked location on the map (find ground surface there & stand upright 56u above ground!)
		local trGround = util.TraceLine({
			start  = worldTargetPos + Vector(0, 0, 200),
			endpos = worldTargetPos - Vector(0, 0, 8000),
			mask   = MASK_SOLID_BRUSHONLY
		})
		local destPos = (trGround.Hit and trGround.HitPos or worldTargetPos) + Vector(0, 0, 56)

		local pB = ents.Create("ent_rick_portal")
		if IsValid(pB) then
			pB:SetPos(destPos)
			pB:SetAngles(flatFwd:Angle())
			pB:SetOwner(owner)
			pB:SetIsFloorPortal(false)
			pB:SetIsMidAir(true)
			pB:Spawn()
			pB:Activate()
			self:RegisterPortal(2, pB)
		end
	end

	net.Receive("RickPG_SelectSkyTarget", function(_, ply)
		if not IsValid(ply) then return end
		local wep = ply:GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() ~= "weapon_rick_portalgun" then return end
		local targetPos = net.ReadVector()
		wep:OpenMapPortalPair(targetPos)
	end)
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + 0.42)
	self:SetNextSecondaryFire(CurTime() + 0.35)

	local mode = self:GetFireMode()
	if mode <= 0 then mode = 1 end

	if mode == 2 then
		if SERVER then
			local owner = self:GetOwner()
			if IsValid(owner) then
				net.Start("RickPG_OpenSkyMap")
				net.Send(owner)
			end
		end
		return
	end

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
	self.NextReloadTime = CurTime() + 0.45

	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	if SERVER then
		-- E + R switches between Mode 1 (Dual Portal Gun) and Mode 2 (Overhead Map Sky View)!
		if owner:KeyDown(IN_USE) then
			local cur = self:GetFireMode()
			local nextMode = (cur == 2) and 1 or 2
			self:SetFireMode(nextMode)
			owner:EmitSound("buttons/button17.wav", 68, nextMode == 2 and 120 or 95, 0.7)
			return
		end

		local closedAny = false
		if IsValid(self:GetPortalA()) and not self:GetPortalA():GetIsClosing() then
			self:GetPortalA():CloseSmoothly()
			closedAny = true
		end
		if IsValid(self:GetPortalB()) and not self:GetPortalB():GetIsClosing() then
			self:GetPortalB():CloseSmoothly()
			closedAny = true
		end

		if closedAny then
			owner:EmitSound("buttons/button15.wav", 65, 95, 0.55)
		else
			-- Convenience: if no portals are open, pressing R also toggles mode!
			local nextMode = (self:GetFireMode() == 2) and 1 or 2
			self:SetFireMode(nextMode)
			owner:EmitSound("buttons/button17.wav", 68, nextMode == 2 and 120 or 95, 0.7)
		end
	end

	if CLIENT and IsFirstTimePredicted() then
		self.DialKick = 0.85
	end
end

-- ============================================================================
-- Client Rendering + Overhead Sky Map Camera System!
-- ============================================================================

if CLIENT then
	local matGlow = Material("sprites/light_glow02_add")

	RICK_PORTAL.SkyMapActive = false
	RICK_PORTAL.SkyCamCenter = Vector(0, 0, 0)
	RICK_PORTAL.SkyCamHeight = 3200
	local skyPanel = nil

	function RICK_PORTAL.CloseSkyMap()
		RICK_PORTAL.SkyMapActive = false
		if IsValid(skyPanel) then
			skyPanel:Remove()
			skyPanel = nil
		end
		gui.EnableScreenClicker(false)
	end

	local function FindRoofFreeSkyHeight(originPos)
		local trUp = util.TraceLine({
			start  = originPos + Vector(0, 0, 32),
			endpos = originPos + Vector(0, 0, 14000),
			mask   = MASK_SOLID_BRUSHONLY
		})
		if trUp.HitSky then
			return math.max(originPos.z + 2800, trUp.HitPos.z - 250)
		elseif trUp.Hit then
			-- Indoor ceiling or skybox roof: stay slightly below roof (or high up if open)
			local clearance = trUp.HitPos.z - originPos.z
			if clearance > 500 then
				return trUp.HitPos.z - 80
			end
		end
		return originPos.z + 2800
	end

	net.Receive("RickPG_OpenSkyMap", function()
		local ply = LocalPlayer()
		if not IsValid(ply) then return end

		if RICK_PORTAL.SkyMapActive then
			RICK_PORTAL.CloseSkyMap()
			return
		end

		RICK_PORTAL.SkyMapActive = true
		RICK_PORTAL.SkyCamCenter = Vector(ply:GetPos().x, ply:GetPos().y, ply:GetPos().z)
		RICK_PORTAL.SkyCamHeight = FindRoofFreeSkyHeight(ply:GetPos())
		gui.EnableScreenClicker(true)

		if IsValid(skyPanel) then skyPanel:Remove() end
		skyPanel = vgui.Create("DPanel")
		skyPanel:SetPos(0, 0)
		skyPanel:SetSize(ScrW(), ScrH())
		skyPanel:SetCursor("crosshair")

		function skyPanel:Paint(w, h)
			-- Sci-fi Rick green tactical satellite border
			surface.SetDrawColor(95, 245, 80, 180)
			surface.DrawOutlinedRect(16, 16, w - 32, h - 32, 2)

			draw.RoundedBox(8, w * 0.5 - 290, 28, 580, 62, Color(10, 22, 14, 215))
			draw.SimpleText("ОРБИТАЛЬНЫЙ РЕЖИМ ПОРТАЛЬНОЙ ПУШКИ", "Trebuchet24", w * 0.5, 46, Color(135, 255, 95), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText("ЛКМ: Открыть портал в точке клика + рядом с вами  |  WASD / Колёсико: Камера  |  ПКМ: Отмена", "DermaDefaultBold", w * 0.5, 72, Color(220, 255, 215), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			-- Draw pulsing green marker over LocalPlayer's position on screen
			local pScr = LocalPlayer():GetPos():ToScreen()
			if pScr.visible then
				surface.DrawCircle(pScr.x, pScr.y, 12 + math.sin(CurTime() * 8) * 3, 125, 255, 85, 255)
				draw.SimpleText("ВЫ", "DermaDefaultBold", pScr.x, pScr.y - 20, Color(145, 255, 95), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end

		function skyPanel:Think()
			if not IsValid(LocalPlayer()) or not LocalPlayer():Alive() then
				RICK_PORTAL.CloseSkyMap()
				return
			end
			local ft = RealFrameTime()
			local panSpeed = math.max(1200, RICK_PORTAL.SkyCamHeight * 0.75) * ft
			if input.IsKeyDown(KEY_W) then RICK_PORTAL.SkyCamCenter.x = RICK_PORTAL.SkyCamCenter.x + panSpeed end
			if input.IsKeyDown(KEY_S) then RICK_PORTAL.SkyCamCenter.x = RICK_PORTAL.SkyCamCenter.x - panSpeed end
			if input.IsKeyDown(KEY_A) then RICK_PORTAL.SkyCamCenter.y = RICK_PORTAL.SkyCamCenter.y + panSpeed end
			if input.IsKeyDown(KEY_D) then RICK_PORTAL.SkyCamCenter.y = RICK_PORTAL.SkyCamCenter.y - panSpeed end
		end

		function skyPanel:OnMouseWheeled(delta)
			RICK_PORTAL.SkyCamHeight = math.Clamp(RICK_PORTAL.SkyCamHeight - delta * 380, LocalPlayer():GetPos().z + 400, LocalPlayer():GetPos().z + 12000)
		end

		function skyPanel:OnMousePressed(mc)
			if mc == MOUSE_RIGHT then
				RICK_PORTAL.CloseSkyMap()
				return
			end
			if mc == MOUSE_LEFT then
				local mx, my = gui.MousePos()
				local aimVec = gui.ScreenToVector(mx, my)
				local camOrigin = Vector(RICK_PORTAL.SkyCamCenter.x, RICK_PORTAL.SkyCamCenter.y, RICK_PORTAL.SkyCamHeight)

				local tr = util.TraceLine({
					start  = camOrigin,
					endpos = camOrigin + aimVec * 32000,
					filter = LocalPlayer(),
					mask   = MASK_SOLID_BRUSHONLY
				})

				local hitPos = tr.Hit and tr.HitPos or (camOrigin + aimVec * 3000)
				net.Start("RickPG_SelectSkyTarget")
					net.WriteVector(hitPos)
				net.SendToServer()

				surface.PlaySound("rick_portal/portal_shoot.wav")
				RICK_PORTAL.CloseSkyMap()
			end
		end
	end)

	hook.Add("CalcView", "RickPG_OverheadMapCalcView", function(ply, pos, angles, fov)
		if not RICK_PORTAL.SkyMapActive then return end
		return {
			origin       = Vector(RICK_PORTAL.SkyCamCenter.x, RICK_PORTAL.SkyCamCenter.y, RICK_PORTAL.SkyCamHeight),
			angles       = Angle(89, 0, 0),
			fov          = 75,
			drawviewer   = true
		}
	end)

	function SWEP:ApplyViewModelBones(vm)
		if not IsValid(vm) or not vm:GetBoneCount() or vm:GetBoneCount() <= 0 then return end

		for _, bName in ipairs(PistolWeaponBonesToHide) do
			local bId = vm:LookupBone(bName)
			if bId then vm:ManipulateBoneScale(bId, ZeroVec) end
		end

		for boneName, mod in pairs(ViewModelHandPose) do
			local boneId = vm:LookupBone(boneName)
			if boneId then
				if mod.pos then vm:ManipulateBonePosition(boneId, mod.pos) end
				if mod.angle then vm:ManipulateBoneAngles(boneId, mod.angle) end
			end
		end

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
			distM = dUnits * 0.01905

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

		local mode = self:GetFireMode()
		if mode <= 0 then mode = 1 end

		return {
			firePulse   = firePulse,
			dialKick    = self.DialKick or 0,
			hasA        = hasA,
			hasB        = hasB,
			targetDistM = distM,
			surfType    = surfType,
			fireMode    = mode
		}
	end

	-- Lower, natural, comfortable hip/chest-level hand position (NOT raised high!)
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
		self.SwayAng.y = Lerp(math.Clamp(ft * 10, 0, 1), self.SwayAng.y, math.Clamp(-dYaw * 0.38, -5, 5))
		self.SwayAng.p = Lerp(math.Clamp(ft * 10, 0, 1), self.SwayAng.p, math.Clamp(dPitch * 0.35, -4, 4))
		self.SwayAng.r = Lerp(math.Clamp(ft * 10, 0, 1), self.SwayAng.r, math.Clamp(dYaw * 0.28, -4, 4))

		local vel2D    = owner:GetVelocity():Length2D()
		local moveFrac = owner:IsOnGround() and math.Clamp(vel2D / 220, 0, 1.25) or 0.15

		local idlePitch = math.sin(ct * 1.9) * 0.45
		local idleRoll  = math.cos(ct * 1.4) * 0.35
		local bobX      = math.sin(ct * 8.5) * 0.45 * moveFrac
		local bobZ      = math.abs(math.cos(ct * 8.5)) * -0.45 * moveFrac
		local bobRoll   = math.sin(ct * 8.5) * 1.2 * moveFrac

		local dep        = 1.0 - math.pow(1.0 - (self.DeployAnimFrac or 1), 3)
		local deployDrop = (1.0 - dep) * -7.5
		local deployTilt = (1.0 - dep) * 18.0

		local recBack  = (self.FireRecoil or 0) * -2.0
		local recPitch = (self.FireRecoil or 0) * -5.0

		local fwd   = ang:Forward()
		local right = ang:Right()
		local up    = ang:Up()

		-- Lowered comfortably (-2.45 up, +0.85 right, +0.6 fwd) so hand sits naturally in lower-right!
		pos = pos
			+ fwd   * (0.6 + recBack)
			+ right * (0.85 + bobX)
			+ up    * (-2.45 + bobZ + deployDrop)

		ang:RotateAroundAxis(ang:Right(),   -(idlePitch + recPitch + deployTilt + self.SwayAng.p - 4.0))
		ang:RotateAroundAxis(ang:Up(),      self.SwayAng.y + 4.0)
		ang:RotateAroundAxis(ang:Forward(), idleRoll + bobRoll + self.SwayAng.r - 3.0)

		return pos, ang
	end

	function SWEP:PreDrawViewModel(vm, wep, ply)
		self:ApplyViewModelBones(vm)
	end

	function SWEP:PostDrawViewModel(vm, wep, ply)
		if RICK_PORTAL.SkyMapActive then return end
		if not IsValid(vm) or not RICK_PORTAL or not RICK_PORTAL.GunRenderer then return end

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

		local gunPos, gunAng = LocalToWorld(
			Vector(3.45, -1.55, -1.15),
			Angle(-8, 2, 180),
			origin,
			ang
		)

		local state = self:GetLiveScreenState()
		local scale = 1.05

		RICK_PORTAL.GunRenderer:DrawGun(gunPos, gunAng, scale, state)

		if state.firePulse > 0.05 then
			local muzWorld = LocalToWorld(Vector(9.5 * scale, 0, 2.20 * scale), Angle(0, 0, 0), gunPos, gunAng)
			render.SetMaterial(matGlow)
			render.DrawSprite(muzWorld, 24 * state.firePulse, 24 * state.firePulse, Color(125, 255, 80, 225 * state.firePulse))
		end
	end

	function SWEP:DrawWorldModel()
		if not RICK_PORTAL or not RICK_PORTAL.GunRenderer then
			self:DrawModel()
			return
		end

		local owner = self:GetOwner()
		local state = self:GetLiveScreenState()
		local scale = 1.05

		if IsValid(owner) then
			local handBone = owner:LookupBone("ValveBiped.Bip01_R_Hand")
			if handBone then
				owner:SetupBones()
				local mtx = owner:GetBoneMatrix(handBone)
				if mtx then
					local gunPos, gunAng = LocalToWorld(
						Vector(3.5, -1.55, -1.05),
						Angle(-8, 0, 180),
						mtx:GetTranslation(),
						mtx:GetAngles()
					)
					RICK_PORTAL.GunRenderer:DrawGun(gunPos, gunAng, scale, state)
					return
				end
			end
		end

		RICK_PORTAL.GunRenderer:DrawGun(self:GetPos(), self:GetAngles(), 1.12, state)
	end

	function SWEP:DrawWorldModelTranslucent()
		self:DrawWorldModel()
	end

	function SWEP:DoDrawCrosshair(x, y)
		if RICK_PORTAL.SkyMapActive then return true end
		surface.SetDrawColor(145, 250, 82, 220)
		surface.DrawRect(x - 2, y - 2, 4, 4)
		return true
	end

	function SWEP:DrawHUD()
		-- All Portal Gun info is displayed right on the Portal Gun's own mini-screen!
	end
end
