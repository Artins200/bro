AddCSLuaFile()

SWEP.PrintName          = "The Omega Device (Планшет)"
SWEP.Author             = "Rick Prime"
SWEP.Instructions       = "Омега-планшет берётся ДВУМЯ РУКАМИ близко к лицу — двигайте мышкой, и указательный палец правой руки сам ездит по экрану и ТЫКАЕТ в кнопки!\nЛКМ: Нажать пальцем кнопку на планшете (выбрать подвид, увидеть 3D-голограмму и СТЕРЕТЬ из всех вселенных)\nПКМ: Развернуть большую станцию Омега-устройства со стазис-капсулой"
SWEP.Category           = "Rick and Morty"

SWEP.Spawnable          = true
SWEP.AdminOnly          = false

-- CRITICAL FOR TWO VISIBLE HANDS:
-- `c_smg1.mdl` ALWAYS renders BOTH Left & Right `c_hands` directly in front of the camera!
-- And we ONLY hide `ValveBiped.base` (we NEVER touch `ValveBiped.Bip01_*` skeleton bones!).
SWEP.ViewModel          = "models/weapons/c_smg1.mdl"
SWEP.WorldModel         = "models/weapons/w_slam.mdl"
SWEP.ViewModelFOV       = 68
SWEP.UseHands           = true

SWEP.Slot               = 4
SWEP.SlotPos            = 1
SWEP.DrawAmmo           = false
SWEP.DrawCrosshair      = false

SWEP.Primary.ClipSize       = -1
SWEP.Primary.DefaultClip    = -1
SWEP.Primary.Automatic      = false
SWEP.Primary.Ammo           = "none"

SWEP.Secondary.ClipSize     = -1
SWEP.Secondary.DefaultClip  = -1
SWEP.Secondary.Automatic    = false
SWEP.Secondary.Ammo         = "none"

SWEP.HoldType           = "slam"

if CLIENT then
	SWEP.WepSelectIcon    = surface.GetTextureID("vgui/entities/weapon_omega_device")
	SWEP.BounceWeaponIcon = true
end

function SWEP:SetupDataTables()
	self:NetworkVar("Float",  0, "ChargeStart")
	self:NetworkVar("Float",  1, "LastBlastTime")
	self:NetworkVar("Bool",   0, "IsCharging")
	self:NetworkVar("String", 0, "SelectedSig")
	self:NetworkVar("String", 1, "SelectedName")
	self:NetworkVar("String", 2, "SelectedModel")
end

local CHARGE_TIME = 1.25
local ZeroVec     = Vector(0.0001, 0.0001, 0.0001)

-- ONLY hide actual SMG1 weapon mesh bones — NEVER scale ValveBiped_Bip01 or c_hands vanish!
local SMG1WeaponBonesToHide = {
	"ValveBiped.base",
	"ValveBiped.bolt",
	"ValveBiped.clip",
	"ValveBiped.muzzle"
}

if SERVER then
	util.AddNetworkString("RickOmega_TabletTapCmd")

	net.Receive("RickOmega_TabletTapCmd", function(_, ply)
		if not IsValid(ply) or not ply:Alive() then return end
		local wep = ply:GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() ~= "weapon_omega_device" then return end

		local cmd = net.ReadString()
		local sig = net.ReadString()

		if cmd == "select" then
			-- Find representative entity matching sig on server
			for _, ent in ipairs(ents.GetAll()) do
				if IsValid(ent) and ent ~= ply and ent:GetClass() ~= "npc_time_police" then
					local esig, pretty, mdl = RICK_PORTAL.GetSubspeciesSignature(ent)
					if esig == sig then
						wep:SetSelectedSig(esig)
						wep:SetSelectedName(pretty or esig)
						wep:SetSelectedModel((mdl and mdl ~= "") and mdl or (ent:GetModel() or "models/Kleiner.mdl"))
						break
					end
				end
			end
		elseif cmd == "erase" then
			if wep:GetIsCharging() then return end
			local targetSig = wep:GetSelectedSig()
			if not targetSig or targetSig == "" then return end

			-- Locate live specimen of this subspecies
			local victim = nil
			for _, ent in ipairs(ents.GetAll()) do
				if IsValid(ent) and ent ~= ply and ent:GetClass() ~= "npc_time_police" then
					local esig = RICK_PORTAL.GetSubspeciesSignature(ent)
					if esig == targetSig then
						victim = ent
						break
					end
				end
			end

			if IsValid(victim) then
				wep.PendingVictim = victim
				wep:SetChargeStart(CurTime())
				wep:SetIsCharging(true)
				wep:EmitSound("RickOmega.Charge")
			else
				ply:EmitSound("buttons/button10.wav", 68, 90, 0.7)
			end
		elseif cmd == "deploy_station" then
			wep:SpawnOmegaStation()
		elseif cmd == "reset" then
			RICK_PORTAL.ResetErasedMultiverse()
			ply:EmitSound("buttons/button19.wav", 75, 110, 0.8)
			ply:ChatPrint("[OMEGA DEVICE] Все стёртые подвиды возвращены во вселенные.")
		end
	end)
end

function SWEP:Initialize()
	self:SetHoldType("slam")
	if CLIENT then
		self.CursorX      = 0.25
		self.CursorY      = 0.0
		self.TapFrac      = 0
		self.LastTapAt    = 0
		self.RippleX      = 0
		self.RippleY      = 0
		self.DeployAnim   = 0
		self.ScrollOffset = 0
	end
end

function SWEP:Deploy()
	self:SetHoldType("slam")
	self:SendWeaponAnim(ACT_VM_IDLE)
	if CLIENT then
		self.DeployAnim = 0
	end
	return true
end

function SWEP:Holster()
	if CLIENT then
		self:ResetViewModelBones()
		if IsValid(self.HoloPreviewEnt) then
			self.HoloPreviewEnt:Remove()
			self.HoloPreviewEnt = nil
		end
	end
	if SERVER then
		self:SetIsCharging(false)
	end
	return true
end

function SWEP:OnRemove()
	if CLIENT then
		self:ResetViewModelBones()
		if IsValid(self.HoloPreviewEnt) then
			self.HoloPreviewEnt:Remove()
			self.HoloPreviewEnt = nil
		end
	end
end

if SERVER then
	function SWEP:SpawnOmegaStation()
		local owner = self:GetOwner()
		if not IsValid(owner) then return end

		local tr = util.TraceLine({
			start  = owner:GetShootPos(),
			endpos = owner:GetShootPos() + owner:GetAimVector() * 240,
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
			owner:ChatPrint("[OMEGA DEVICE] Станция Омега-устройства со стазис-капсулой развёрнута!")
		end
	end

	function SWEP:Think()
		if not self:GetIsCharging() then return end

		if (CurTime() - self:GetChargeStart()) >= CHARGE_TIME then
			self:SetIsCharging(false)
			local owner  = self:GetOwner()
			local victim = self.PendingVictim

			if IsValid(victim) and victim:GetClass() ~= "npc_time_police" then
				self:SetLastBlastTime(CurTime())
				self:EmitSound("RickOmega.Erase")
				local erasedCount, subName = RICK_PORTAL.EraseSubspeciesAcrossMultiverse(victim, owner)
				if IsValid(owner) and subName then
					owner:ChatPrint(string.format("[OMEGA TABLET] Подвид «%s» СТЁРТ ИЗ ВСЕХ ВСЕЛЕННЫХ! (Удалено: %d)", subName, erasedCount))
					util.ScreenShake(owner:GetPos(), 11, 8, 1.2, 1600)
				end
			end

			self.PendingVictim = nil
			self:SetSelectedSig("")
			self:SetSelectedName("")
			self:SetSelectedModel("")
		end
	end
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + 0.22)
	if CLIENT and IsFirstTimePredicted() then
		self:TriggerFingerTap()
	end
end

function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire(CurTime() + 0.9)
	if SERVER then
		self:SpawnOmegaStation()
	end
	if CLIENT and IsFirstTimePredicted() then
		self.TapFrac = 0.8
	end
end

function SWEP:Reload()
	if (self.NextReload or 0) > CurTime() then return end
	self.NextReload = CurTime() + 0.7
	if SERVER then
		RICK_PORTAL.ResetErasedMultiverse()
		if IsValid(self:GetOwner()) then
			self:GetOwner():EmitSound("buttons/button19.wav", 75, 110, 0.8)
			self:GetOwner():ChatPrint("[OMEGA TABLET] Все стёртые подвиды возвращены во вселенные.")
		end
	end
end

-- ============================================================================
-- Client Rendering:
--  * BOTH Hands (`c_hands` on `c_smg1.mdl`) 100% VISIBLE holding the Omega Tablet close!
--  * Left Hand grips the left rubberized bezel of the tablet.
--  * Right Hand hovers in front of the glass screen with its INDEX FINGER (`Finger1`)
--    extended straight out — gliding smoothly with mouse input and PHYSICALLY POKING
--    forward into the touchscreen buttons on click!
--  * 3D Hologram of the selected creature floats & spins right out of the tablet screen!
-- ============================================================================

if CLIENT then
	function SWEP:GatherSubspeciesList()
		local list  = {}
		local bySig = {}
		local ply   = LocalPlayer()

		for _, ent in ipairs(ents.GetAll()) do
			if IsValid(ent) and ent ~= ply and ent:GetClass() ~= "npc_time_police" then
				if ent:IsNPC() or ent:IsNextBot() or ent:IsPlayer() or string.StartWith(ent:GetClass(), "prop_") then
					local sig, pretty = RICK_PORTAL.GetSubspeciesSignature(ent)
					if sig then
						if not bySig[sig] then
							bySig[sig] = { sig = sig, name = pretty, count = 1 }
							list[#list + 1] = bySig[sig]
						else
							bySig[sig].count = bySig[sig].count + 1
						end
					end
				end
			end
		end
		return list
	end

	function SWEP:BuildButtons(subList)
		local btns = {}
		local maxRows = 5
		local startIdx = math.Clamp((self.ScrollOffset or 0) + 1, 1, math.max(1, #subList - maxRows + 1))

		for row = 0, math.min(maxRows - 1, #subList - startIdx) do
			local item = subList[startIdx + row]
			if item then
				btns[#btns + 1] = {
					cmd   = "select",
					sig   = item.sig,
					x     = -205,
					y     = -82 + row * 34,
					w     = 196,
					h     = 29,
					label = string.sub(item.name, 1, 19) .. " (" .. item.count .. ")",
					active = (self:GetSelectedSig() == item.sig),
					col   = Color(20, 38, 64, 240),
					hcol  = Color(45, 92, 148, 255)
				}
			end
		end

		if #subList > maxRows then
			btns[#btns + 1] = { cmd = "scroll_up",   x = -205, y = 92, w = 94, h = 26, label = "▲ ВВЕРХ", col = Color(24, 36, 56), hcol = Color(50, 80, 120) }
			btns[#btns + 1] = { cmd = "scroll_down", x = -103, y = 92, w = 94, h = 26, label = "▼ ВНИЗ",  col = Color(24, 36, 56), hcol = Color(50, 80, 120) }
		end

		-- Right side action buttons
		if self:GetSelectedSig() ~= "" and not self:GetIsCharging() then
			btns[#btns + 1] = {
				cmd   = "erase",
				sig   = "",
				x     = 14,
				y     = 14,
				w     = 192,
				h     = 44,
				label = "⚡ СТЕРЕТЬ ПОДВИД",
				col   = Color(165, 28, 46, 248),
				hcol  = Color(235, 48, 68, 255)
			}
		end

		btns[#btns + 1] = {
			cmd   = "deploy_station",
			sig   = "",
			x     = 14,
			y     = 64,
			w     = 192,
			h     = 28,
			label = "РАЗВЕРНУТЬ КАПСУЛУ",
			col   = Color(32, 62, 98, 240),
			hcol  = Color(58, 108, 168, 255)
		}

		local erasedCnt = table.Count(RICK_PORTAL.ErasedSubspecies or {})
		btns[#btns + 1] = {
			cmd   = "reset",
			sig   = "",
			x     = 14,
			y     = 98,
			w     = 192,
			h     = 26,
			label = string.format("СБРОС ВСЕЛЕННЫХ (%d)", erasedCnt),
			col   = Color(24, 64, 58, 240),
			hcol  = Color(42, 118, 104, 255)
		}

		return btns, #subList, maxRows
	end

	function SWEP:TriggerFingerTap()
		self.TapFrac   = 1.0
		self.LastTapAt = CurTime()
		surface.PlaySound("rick_portal/tablet_tap.wav")

		local uiX = (self.CursorX or 0) * 208
		local uiY = (self.CursorY or 0) * 124
		self.RippleX = uiX
		self.RippleY = uiY

		local subList = self:GatherSubspeciesList()
		local btns, totalCnt, maxRows = self:BuildButtons(subList)

		for _, b in ipairs(btns) do
			if uiX >= b.x and uiX <= (b.x + b.w) and uiY >= b.y and uiY <= (b.y + b.h) then
				if b.cmd == "scroll_up" then
					self.ScrollOffset = math.max(0, (self.ScrollOffset or 0) - 1)
				elseif b.cmd == "scroll_down" then
					self.ScrollOffset = math.min(math.max(0, totalCnt - maxRows), (self.ScrollOffset or 0) + 1)
				else
					net.Start("RickOmega_TabletTapCmd")
						net.WriteString(b.cmd)
						net.WriteString(b.sig or "")
					net.SendToServer()
				end
				break
			end
		end
	end

	-- Smoothly glide the right hand & extended index finger across the Omega Tablet screen with mouse movement!
	hook.Add("InputMouseApply", "RickOmegaTablet_FingerControl", function(cmd, x, y, ang)
		local ply = LocalPlayer()
		if not IsValid(ply) then return end
		local wep = ply:GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() ~= "weapon_omega_device" then return end

		wep.CursorX = math.Clamp((wep.CursorX or 0) + x * 0.00085, -0.96, 0.96)
		wep.CursorY = math.Clamp((wep.CursorY or 0) + y * 0.00095, -0.94, 0.94)
	end)

	function SWEP:ApplyTwoHandedTabletBones(vm)
		if not IsValid(vm) or not vm:GetBoneCount() or vm:GetBoneCount() <= 0 then return end

		-- ONLY shrink SMG1 weapon parts — keep ALL ValveBiped.* hand/arm bones at scale (1,1,1)!
		for _, bName in ipairs(SMG1WeaponBonesToHide) do
			local bId = vm:LookupBone(bName)
			if bId then vm:ManipulateBoneScale(bId, ZeroVec) end
		end

		local cx  = self.CursorX or 0
		local cy  = self.CursorY or 0
		local tap = self.TapFrac or 0

		-- In `c_smg1.mdl` idle pose:
		-- Left hand is already forward gripping the forend -> adjust slightly left & upright to grip the Left Tablet Bezel!
		-- Right hand is near the pistol grip -> bring slightly up & forward with Index Finger (`Finger1`) extended straight
		-- toward the tablet glass, translating live with (cx, cy) and poking forward on `tap`!
		local boneMods = {
			-- LEFT HAND gripping left side bumper of Omega Tablet
			["ValveBiped.Bip01_L_Forearm"]  = { pos = Vector(-2.5, -2.2, 1.8), angle = Angle(6, -8, 18) },
			["ValveBiped.Bip01_L_Hand"]     = { pos = Vector(0, 0, 0),         angle = Angle(14, 12, -22) },
			["ValveBiped.Bip01_L_Finger0"]  = { angle = Angle(18, 24, 6) },
			["ValveBiped.Bip01_L_Finger1"]  = { angle = Angle(0, -32, 0) },
			["ValveBiped.Bip01_L_Finger2"]  = { angle = Angle(0, -36, 0) },
			["ValveBiped.Bip01_L_Finger3"]  = { angle = Angle(0, -40, 0) },
			["ValveBiped.Bip01_L_Finger4"]  = { angle = Angle(0, -42, 0) },

			-- RIGHT HAND & EXTENDED INDEX FINGER hovering right over the screen & poking buttons!
			["ValveBiped.Bip01_R_Forearm"]  = {
				pos   = Vector(3.8 + tap * 1.65, -2.4 - cx * 4.2, 3.2 - cy * 2.8),
				angle = Angle(-10 + cx * 12, 24 - cy * 12, -28)
			},
			["ValveBiped.Bip01_R_Hand"]     = {
				pos   = Vector(0, 0, 0),
				angle = Angle(-14 + cx * 8, 18 + tap * 14, 24)
			},

			-- Thumb tucked
			["ValveBiped.Bip01_R_Finger0"]   = { angle = Angle(-12, -20, 0) },
			["ValveBiped.Bip01_R_Finger01"]  = { angle = Angle(0, -25, 0) },

			-- EXTENDED INDEX FINGER (`Finger1`) pointing straight at the button & pressing in!
			["ValveBiped.Bip01_R_Finger1"]   = { angle = Angle(-2, 28 + tap * 14, 0) },
			["ValveBiped.Bip01_R_Finger11"]  = { angle = Angle(0, 22 - tap * 8, 0) },
			["ValveBiped.Bip01_R_Finger12"]  = { angle = Angle(0, 12, 0) },

			-- Other 3 fingers curled cleanly into palm so only the index finger pokes!
			["ValveBiped.Bip01_R_Finger2"]   = { angle = Angle(0, -48, 0) },
			["ValveBiped.Bip01_R_Finger21"]  = { angle = Angle(0, -68, 0) },
			["ValveBiped.Bip01_R_Finger22"]  = { angle = Angle(0, -45, 0) },

			["ValveBiped.Bip01_R_Finger3"]   = { angle = Angle(4, -54, 0) },
			["ValveBiped.Bip01_R_Finger31"]  = { angle = Angle(0, -72, 0) },
			["ValveBiped.Bip01_R_Finger32"]  = { angle = Angle(0, -50, 0) },

			["ValveBiped.Bip01_R_Finger4"]   = { angle = Angle(8, -58, 0) },
			["ValveBiped.Bip01_R_Finger41"]  = { angle = Angle(0, -72, 0) },
			["ValveBiped.Bip01_R_Finger42"]  = { angle = Angle(0, -50, 0) }
		}

		for bName, mod in pairs(boneMods) do
			local id = vm:LookupBone(bName)
			if id then
				if mod.pos then vm:ManipulateBonePosition(id, mod.pos) end
				if mod.angle then vm:ManipulateBoneAngles(id, mod.angle) end
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

	-- Position c_smg1 hands close & centered so BOTH Left & Right hands are unmistakably in frame!
	function SWEP:CalcViewModelView(vm, oldPos, oldAng, pos, ang)
		local ft = FrameTime()
		local ct = CurTime()

		self.DeployAnim = math.Approach(self.DeployAnim or 0, 1, ft * 3.5)
		self.TapFrac    = Lerp(math.Clamp(ft * 16, 0, 1), self.TapFrac or 0, 0)

		local dep  = 1.0 - math.pow(1.0 - self.DeployAnim, 3)
		local drop = (1.0 - dep) * -8.0

		pos = pos
			+ ang:Forward() * -4.8
			+ ang:Right()   * -3.4
			+ ang:Up()      * (2.1 + drop + math.sin(ct * 2.1) * 0.12)

		ang:RotateAroundAxis(ang:Right(), -5 + (1.0 - dep) * 18)
		ang:RotateAroundAxis(ang:Up(),    3)
		return pos, ang
	end

	function SWEP:PreDrawViewModel(vm, wep, ply)
		self:ApplyTwoHandedTabletBones(vm)
	end

	function SWEP:PostDrawViewModel(vm, wep, ply)
		if not IsValid(vm) or not RICK_PORTAL or not RICK_PORTAL.OmegaRenderer then return end
		vm:SetupBones()

		local ct     = CurTime()
		local charge = self:GetIsCharging() and math.Clamp((ct - self:GetChargeStart()) / CHARGE_TIME, 0, 1) or 0
		local dep    = 1.0 - math.pow(1.0 - (self.DeployAnim or 1), 3)

		-- Position the Tablet right between Left Hand (`ValveBiped.Bip01_L_Hand`) and Right Poking Finger (`ValveBiped.Bip01_R_Finger12`)!
		local camPos = EyePos()
		local camAng = EyeAngles()

		local lHandPos = nil
		local lBone = vm:LookupBone("ValveBiped.Bip01_L_Hand")
		if lBone then
			local lm = vm:GetBoneMatrix(lBone)
			if lm then lHandPos = lm:GetTranslation() end
		end

		-- Anchor tablet so Left Hand sits right on its left grip (-5.65u) and screen faces player closely!
		local tabOrigin = camPos
			+ camAng:Forward() * 13.8
			+ camAng:Right()   * 0.2
			+ camAng:Up()      * (-2.2 - (1.0 - dep) * 6.0 + math.sin(ct * 2.1) * 0.10)

		if lHandPos then
			-- Blend gently with actual Left Hand Z/Forward so the left fingers visibly wrap the left edge of the tablet!
			tabOrigin = LerpVector(0.35, tabOrigin, lHandPos + camAng:Right() * 5.4 + camAng:Up() * 1.4 + camAng:Forward() * 1.2)
		end

		local tabAng = Angle(camAng.p, camAng.y, camAng.r)
		tabAng:RotateAroundAxis(tabAng:Up(), 180)
		tabAng:RotateAroundAxis(tabAng:Right(), -14)

		-- 1) Draw Sleek 3D Omega Tablet Body + Top Mini-Omega Emitter
		RICK_PORTAL.OmegaRenderer:DrawOmegaTabletBody(tabOrigin, tabAng, 1.0, charge)

		-- 2) Draw Interactive Touchscreen UI right on the glass face (+X = 0.40)
		local scrPos, scrAng = LocalToWorld(Vector(0.41, 0, 0), Angle(0, 90, 90), tabOrigin, tabAng)
		local uiScale = 0.0245

		local uiX = (self.CursorX or 0) * 208
		local uiY = (self.CursorY or 0) * 124
		local subList = self:GatherSubspeciesList()
		local btns    = self:BuildButtons(subList)

		cam.Start3D2D(scrPos, scrAng, uiScale)
			draw.RoundedBox(10, -220, -140, 440, 280, Color(10, 16, 28, 252))
			surface.SetDrawColor(75, 215, 255, 240)
			surface.DrawOutlinedRect(-220, -140, 440, 280, 3)

			-- Header
			draw.RoundedBoxEx(8, -217, -137, 434, 32, Color(24, 42, 72, 235), true, true, false, false)
			draw.SimpleText("OMEGA DEVICE PAD  |  СТИРАНИЕ ПОДВИДОВ ИЗ ВСЕЛЕННЫХ", "DermaDefaultBold", 0, -121, Color(115, 235, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			-- Left Column Header
			draw.SimpleText("ВЫБЕРИТЕ ПОДВИД НА КАРТЕ:", "DermaDefaultBold", -107, -95, Color(185, 230, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			if #subList == 0 then
				draw.SimpleText("Нет существ рядом", "DermaDefault", -107, -20, Color(135, 160, 185), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			-- Divider
			surface.SetDrawColor(65, 185, 240, 95)
			surface.DrawRect(2, -102, 2, 232)

			-- Right Column: Selected Target Info
			draw.SimpleText("ЦЕЛЬ ОМЕГА-ЯДРА:", "DermaDefaultBold", 110, -95, Color(255, 200, 115), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			local selName = self:GetSelectedName()
			if selName and selName ~= "" then
				draw.RoundedBox(6, 14, -80, 192, 86, Color(18, 34, 56, 225))
				draw.SimpleText(string.sub(selName, 1, 22), "DermaDefaultBold", 110, -64, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				if self:GetIsCharging() then
					draw.SimpleText("⚡ СТИРАНИЕ ВСЕХ КОПИЙ...", "DermaDefaultBold", 110, 34, Color(125, 240, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					surface.SetDrawColor(30, 50, 80, 240)
					surface.DrawRect(18, 46, 184, 12)
					surface.SetDrawColor(95, 230, 255, 255)
					surface.DrawRect(20, 48, math.floor(180 * charge), 8)
				else
					draw.SimpleText("(3D-образец захвачен)", "DermaDefault", 110, -8, Color(135, 225, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
			else
				draw.RoundedBox(6, 14, -80, 192, 86, Color(16, 24, 38, 210))
				draw.SimpleText("ЦЕЛЬ НЕ ВЫБРАНА", "DermaDefaultBold", 110, -45, Color(145, 170, 195), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText("Ткните пальцем слева", "DermaDefault", 110, -24, Color(115, 145, 170), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			-- Render all buttons
			for _, b in ipairs(btns) do
				local hov = (uiX >= b.x and uiX <= (b.x + b.w) and uiY >= b.y and uiY <= (b.y + b.h))
				local bg  = b.active and Color(55, 125, 195, 255) or (hov and b.hcol or b.col)
				draw.RoundedBox(6, b.x, b.y, b.w, b.h, bg)
				surface.SetDrawColor(195, 245, 255, (hov or b.active) and 255 or 115)
				surface.DrawOutlinedRect(b.x, b.y, b.w, b.h, 1)
				draw.SimpleText(b.label, "DermaDefaultBold", b.x + b.w * 0.5, b.y + b.h * 0.5, Color(245, 252, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			-- Touch ripple wave where index finger poked the glass!
			local tapAge = ct - (self.LastTapAt or 0)
			if tapAge < 0.36 then
				local rf = tapAge / 0.36
				surface.DrawCircle(self.RippleX or 0, self.RippleY or 0, math.floor(6 + rf * 32), 125, 245, 255, math.floor(255 * (1 - rf)))
			end

			-- Finger cursor reticle right under the poking index fingertip!
			surface.DrawCircle(uiX, uiY, 7, 125, 245, 255, 240)
			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawRect(uiX - 2, uiY - 2, 4, 4)
		cam.End3D2D()

		-- 3) 3D Miniature Hologram Specimen spinning right out of the right panel of the Omega Tablet!
		local selMdl = self:GetSelectedModel()
		if selMdl and selMdl ~= "" then
			if not IsValid(self.HoloPreviewEnt) or self.HoloPreviewEnt:GetModel() ~= selMdl then
				if IsValid(self.HoloPreviewEnt) then self.HoloPreviewEnt:Remove() end
				self.HoloPreviewEnt = ClientsideModel(selMdl, RENDERGROUP_TRANSLUCENT)
				if IsValid(self.HoloPreviewEnt) then self.HoloPreviewEnt:SetNoDraw(true) end
			end

			if IsValid(self.HoloPreviewEnt) then
				local holoWorld = LocalToWorld(Vector(1.4, -2.7, 0.9), Angle(0, ct * 140, 0), tabOrigin, tabAng)
				local rad = math.max(self.HoloPreviewEnt:BoundingRadius(), 12)
				local shrink = self:GetIsCharging() and (1.0 - charge * 0.85) or 1.0
				local fitS = (1.65 / rad) * shrink

				self.HoloPreviewEnt:SetPos(holoWorld)
				self.HoloPreviewEnt:SetAngles(Angle(0, ct * 140, 0))
				self.HoloPreviewEnt:SetModelScale(fitS, 0)
				self.HoloPreviewEnt:SetupBones()

				render.SetColorModulation(0.45, 0.92, 1.0)
				render.SetBlend(0.88)
				self.HoloPreviewEnt:DrawModel()
				render.SetBlend(1)
				render.SetColorModulation(1, 1, 1)
			end
		elseif IsValid(self.HoloPreviewEnt) then
			self.HoloPreviewEnt:Remove()
			self.HoloPreviewEnt = nil
		end
	end

	function SWEP:DrawWorldModel()
		if not RICK_PORTAL or not RICK_PORTAL.OmegaRenderer then
			self:DrawModel()
			return
		end

		local owner = self:GetOwner()
		local pos, ang = self:GetPos(), self:GetAngles()
		if IsValid(owner) then
			local bId = owner:LookupBone("ValveBiped.Bip01_R_Hand")
			if bId then
				owner:SetupBones()
				local m = owner:GetBoneMatrix(bId)
				if m then
					pos, ang = LocalToWorld(Vector(4.5, -3.5, 0), Angle(0, 0, 180), m:GetTranslation(), m:GetAngles())
				end
			end
		end

		RICK_PORTAL.OmegaRenderer:DrawOmegaTabletBody(pos, ang, 0.95, self:GetIsCharging() and 1 or 0)
	end

	function SWEP:DrawWorldModelTranslucent()
		self:DrawWorldModel()
	end
end
