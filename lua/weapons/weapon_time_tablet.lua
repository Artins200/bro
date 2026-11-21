AddCSLuaFile()

SWEP.PrintName          = "Time Travel Tablet (Планшет Времени)"
SWEP.Author             = "Rick Sanchez"
SWEP.Instructions       = "Планшет держится двумя руками близко к лицу — двигайте мышкой, и палец правой руки сам тянется и ТЫКАЕТ прямо по кнопкам экрана!\nЛКМ: Нажать пальцем выбранную кнопку на планшете\nВернитесь в своё время за 35 сек., иначе за вами прилетит ПОЛИЦИЯ ВРЕМЕНИ!"
SWEP.Category           = "Rick and Morty"

SWEP.Spawnable          = true
SWEP.AdminOnly          = false

-- Use c_slam so BOTH c_hands (Left & Right arms/fingers!) are present and active in 1st person!
SWEP.ViewModel          = "models/weapons/c_slam.mdl"
SWEP.WorldModel         = "models/weapons/w_slam.mdl"
SWEP.ViewModelFOV       = 68
SWEP.UseHands           = true

SWEP.Slot               = 4
SWEP.SlotPos            = 2
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
	SWEP.WepSelectIcon    = surface.GetTextureID("vgui/entities/weapon_time_tablet")
	SWEP.BounceWeaponIcon = true
end

function SWEP:SetupDataTables()
	self:NetworkVar("Bool",  0, "InPast")
	self:NetworkVar("Float", 0, "PastDeadline")
	self:NetworkVar("Int",   0, "RewindSeconds")
end

local ZeroVec = Vector(0.0001, 0.0001, 0.0001)

-- Hide all SLAM detonator/satchel weapon bones while keeping BOTH Left & Right c_hands 100% visible!
local SlamBonesToHide = {
	"Detonator_base",
	"Detonator_trigger",
	"Detonator_antenna",
	"Slam_base",
	"Slam_panel"
}

if SERVER then
	util.AddNetworkString("RickTime_TabletAction")

	net.Receive("RickTime_TabletAction", function(_, ply)
		if not IsValid(ply) or not ply:Alive() then return end
		local wep = ply:GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() ~= "weapon_time_tablet" then return end

		local action = net.ReadString()
		if action == "minus" then
			wep:SetRewindSeconds(math.Clamp(wep:GetRewindSeconds() - 5, 5, 25))
		elseif action == "plus" then
			wep:SetRewindSeconds(math.Clamp(wep:GetRewindSeconds() + 5, 5, 25))
		elseif action == "jump_past" then
			if RICK_PORTAL and RICK_PORTAL.StartTimeJumpBack then
				RICK_PORTAL.StartTimeJumpBack(ply, wep:GetRewindSeconds(), wep)
			end
		elseif action == "return_now" then
			if RICK_PORTAL and RICK_PORTAL.ReturnToPresentTimeline then
				RICK_PORTAL.ReturnToPresentTimeline(ply, wep)
			end
		end
	end)
end

function SWEP:Initialize()
	self:SetHoldType("slam")
	if SERVER and self:GetRewindSeconds() <= 0 then
		self:SetRewindSeconds(10)
	end

	if CLIENT then
		self.CursorX   = 0 -- -1..1 across tablet screen
		self.CursorY   = 0 -- -1..1 vertically across tablet screen
		self.TapFrac   = 0 -- 0..1 physical finger tap depth into screen!
		self.LastTapAt = 0
		self.RippleX   = 0
		self.RippleY   = 0
	end
end

function SWEP:Deploy()
	self:SetHoldType("slam")
	self:SendWeaponAnim(ACT_VM_DRAW)
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

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + 0.24)

	if CLIENT and IsFirstTimePredicted() then
		self:TriggerFingerTap()
	end
end

function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire(CurTime() + 0.24)
	if CLIENT and IsFirstTimePredicted() then
		self:TriggerFingerTap()
	end
end

-- ============================================================================
-- Client Rendering:
-- 1) Two-handed close-up tablet hold: Left hand grips the left bezel, Right hand
--    hovers over the touchscreen with ONLY the index finger extended!
-- 2) Moving your mouse moves the right hand & index finger across the screen,
--    and clicking LMB physically pokes the index fingertip onto the glass button!
-- ============================================================================

if CLIENT then
	local matTabBody = CreateMaterial("RickTime_TabBody_v1", "VertexLitGeneric", {
		["$basetexture"] = "models/debug/debugwhite",
		["$halflambert"] = "1",
		["$phong"]       = "1",
		["$phongboost"]  = "0.9",
		["$phongexponent"] = "24",
		["$phongfresnelranges"] = "[0.2 0.6 1]"
	})

	local TabletMesh = nil
	local function GetTabletMesh()
		if TabletMesh then return TabletMesh end
		local tris = {}
		local hx, hy, hz = 0.42, 6.2, 4.1 -- Thin sleek wide sci-fi tablet!
		local function Quad(p1, p2, p3, p4)
			local n = (p4 - p1):Cross(p2 - p1):GetNormalized()
			tris[#tris + 1] = { pos = p1, normal = n, u = 0, v = 0 }
			tris[#tris + 1] = { pos = p2, normal = n, u = 1, v = 0 }
			tris[#tris + 1] = { pos = p3, normal = n, u = 1, v = 1 }
			tris[#tris + 1] = { pos = p1, normal = n, u = 0, v = 0 }
			tris[#tris + 1] = { pos = p3, normal = n, u = 1, v = 1 }
			tris[#tris + 1] = { pos = p4, normal = n, u = 0, v = 1 }
		end
		Quad(Vector(hx,-hy,-hz), Vector(hx,hy,-hz), Vector(hx,hy,hz), Vector(hx,-hy,hz))
		Quad(Vector(-hx,hy,-hz), Vector(-hx,-hy,-hz), Vector(-hx,-hy,hz), Vector(-hx,hy,hz))
		Quad(Vector(hx,hy,-hz), Vector(-hx,hy,-hz), Vector(-hx,hy,hz), Vector(hx,hy,hz))
		Quad(Vector(-hx,-hy,-hz), Vector(hx,-hy,-hz), Vector(hx,-hy,hz), Vector(-hx,-hy,hz))
		Quad(Vector(-hx,-hy,hz), Vector(hx,-hy,hz), Vector(hx,hy,hz), Vector(-hx,hy,hz))
		Quad(Vector(-hx,hy,-hz), Vector(hx,hy,-hz), Vector(hx,-hy,-hz), Vector(-hx,-hy,-hz))
		TabletMesh = Mesh()
		TabletMesh:BuildFromTriangles(tris)
		return TabletMesh
	end

	-- Button layout in Tablet UI coordinates (-220..+220 X, -135..+135 Y)
	function SWEP:GetTabletButtons()
		local inPast = self:GetInPast()
		if inPast then
			return {
				{ id = "return_now", x = -165, y = 22, w = 330, h = 76, label = "⏪ ВЕРНУТЬСЯ В СВОЁ ВРЕМЯ СЕЙЧАС!", col = Color(28, 145, 95, 245), hcol = Color(45, 205, 135, 255) }
			}
		else
			return {
				{ id = "minus",     x = -175, y = -28, w = 78,  h = 52, label = "- 5 СЕК", col = Color(28, 52, 86, 240),  hcol = Color(52, 96, 155, 255) },
				{ id = "plus",      x = 97,   y = -28, w = 78,  h = 52, label = "+ 5 СЕК", col = Color(28, 52, 86, 240),  hcol = Color(52, 96, 155, 255) },
				{ id = "jump_past", x = -175, y = 40,  w = 350, h = 68, label = "⚡ ПЕРЕМЕСТИТЬСЯ В ПРОШЛОЕ", col = Color(138, 38, 185, 245), hcol = Color(185, 62, 245, 255) }
			}
		end
	end

	function SWEP:TriggerFingerTap()
		self.TapFrac   = 1.0
		self.LastTapAt = CurTime()
		surface.PlaySound("rick_portal/tablet_tap.wav")

		local uiX = (self.CursorX or 0) * 205
		local uiY = (self.CursorY or 0) * 125
		self.RippleX = uiX
		self.RippleY = uiY

		for _, btn in ipairs(self:GetTabletButtons()) do
			if uiX >= btn.x and uiX <= (btn.x + btn.w) and uiY >= btn.y and uiY <= (btn.y + btn.h) then
				net.Start("RickTime_TabletAction")
					net.WriteString(btn.id)
				net.SendToServer()
				break
			end
		end
	end

	-- Intercept subtle mouse deltas to glide the right index finger across the tablet screen!
	hook.Add("InputMouseApply", "RickTimeTablet_FingerControl", function(cmd, x, y, ang)
		local ply = LocalPlayer()
		if not IsValid(ply) then return end
		local wep = ply:GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() ~= "weapon_time_tablet" then return end

		-- Smoothly move finger cursor on tablet while allowing gentle camera turn at edges
		wep.CursorX = math.Clamp((wep.CursorX or 0) + x * 0.00085, -0.95, 0.95)
		wep.CursorY = math.Clamp((wep.CursorY or 0) + y * 0.00095, -0.92, 0.92)
	end)

	function SWEP:ApplyTwoHandedTabletPose(vm)
		if not IsValid(vm) or not vm:GetBoneCount() or vm:GetBoneCount() <= 0 then return end

		-- Hide underlying SLAM meshes while keeping BOTH Left & Right c_hands 100% visible!
		for _, bName in ipairs(SlamBonesToHide) do
			local bId = vm:LookupBone(bName)
			if bId then vm:ManipulateBoneScale(bId, ZeroVec) end
		end
		-- Also hide any non-ValveBiped weapon mesh bones inside c_slam
		for i = 0, vm:GetBoneCount() - 1 do
			local name = vm:GetBoneName(i)
			if name and not string.StartWith(name, "ValveBiped.") then
				vm:ManipulateBoneScale(i, ZeroVec)
			end
		end

		local cx  = self.CursorX or 0
		local cy  = self.CursorY or 0
		local tap = self.TapFrac or 0

		-- LEFT HAND: Holds the left edge of the tablet firmly close to the chest/face!
		local leftPose = {
			["ValveBiped.Bip01_L_UpperArm"] = { pos = Vector(2, 4, 2),   angle = Angle(8, 18, -10) },
			["ValveBiped.Bip01_L_Forearm"]  = { pos = Vector(0, 0, 0),   angle = Angle(-6, 15, 22) },
			["ValveBiped.Bip01_L_Hand"]     = { pos = Vector(0, 0, 0),   angle = Angle(12, 8, -28) },
			["ValveBiped.Bip01_L_Finger0"]  = { pos = Vector(0, 0, 0),   angle = Angle(16, 22, 0) },
			["ValveBiped.Bip01_L_Finger1"]  = { pos = Vector(0, 0, 0),   angle = Angle(0, -35, 0) },
			["ValveBiped.Bip01_L_Finger2"]  = { pos = Vector(0, 0, 0),   angle = Angle(0, -38, 0) },
			["ValveBiped.Bip01_L_Finger3"]  = { pos = Vector(0, 0, 0),   angle = Angle(0, -40, 0) },
			["ValveBiped.Bip01_L_Finger4"]  = { pos = Vector(0, 0, 0),   angle = Angle(0, -42, 0) }
		}

		-- RIGHT HAND: Positioned right in front of the tablet screen, moving live with CursorX/CursorY,
		-- with ONLY the Index Finger (`Finger1`) extended straight out and physically pressing forward (`tap`) onto the glass!
		local rightPose = {
			["ValveBiped.Bip01_R_UpperArm"] = { pos = Vector(-1, -3, 2), angle = Angle(-8, -14, 12) },
			["ValveBiped.Bip01_R_Forearm"]  = {
				pos   = Vector(-2.2 + tap * 1.65, -cx * 3.4, -cy * 2.5),
				angle = Angle(-8 + cx * 10, 18 - cy * 12, -26)
			},
			["ValveBiped.Bip01_R_Hand"]     = {
				pos   = Vector(0, 0, 0),
				angle = Angle(-15 + cx * 8, 16 + tap * 10, 28)
			},

			-- Thumb tucked neatly
			["ValveBiped.Bip01_R_Finger0"]   = { angle = Angle(-12, -18, 0) },
			["ValveBiped.Bip01_R_Finger01"]  = { angle = Angle(0, -25, 0) },

			-- INDEX FINGER EXTENDED STRAIGHT TO POKE THE TOUCHSCREEN!
			["ValveBiped.Bip01_R_Finger1"]   = { angle = Angle(0, 14 + tap * 14, 0) },
			["ValveBiped.Bip01_R_Finger11"]  = { angle = Angle(0, 4 - tap * 8, 0) },
			["ValveBiped.Bip01_R_Finger12"]  = { angle = Angle(0, 2, 0) },

			-- Middle, Ring, Pinky curled into palm so it's unmistakably a single index-finger poke!
			["ValveBiped.Bip01_R_Finger2"]   = { angle = Angle(0, -58, 0) },
			["ValveBiped.Bip01_R_Finger21"]  = { angle = Angle(0, -78, 0) },
			["ValveBiped.Bip01_R_Finger22"]  = { angle = Angle(0, -55, 0) },

			["ValveBiped.Bip01_R_Finger3"]   = { angle = Angle(4, -64, 0) },
			["ValveBiped.Bip01_R_Finger31"]  = { angle = Angle(0, -82, 0) },
			["ValveBiped.Bip01_R_Finger32"]  = { angle = Angle(0, -58, 0) },

			["ValveBiped.Bip01_R_Finger4"]   = { angle = Angle(8, -68, 0) },
			["ValveBiped.Bip01_R_Finger41"]  = { angle = Angle(0, -82, 0) },
			["ValveBiped.Bip01_R_Finger42"]  = { angle = Angle(0, -58, 0) }
		}

		for bName, mod in pairs(leftPose) do
			local id = vm:LookupBone(bName)
			if id then
				if mod.pos then vm:ManipulateBonePosition(id, mod.pos) end
				if mod.angle then vm:ManipulateBoneAngles(id, mod.angle) end
			end
		end

		for bName, mod in pairs(rightPose) do
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

	-- Bring both hands & tablet close and centered in front of the player's eyes!
	function SWEP:CalcViewModelView(vm, oldPos, oldAng, pos, ang)
		local ft = FrameTime()
		local ct = CurTime()

		self.TapFrac = Lerp(math.Clamp(ft * 16, 0, 1), self.TapFrac or 0, 0)

		pos = pos
			+ ang:Forward() * -3.6
			+ ang:Right()   * -0.4
			+ ang:Up()      * 1.35 + ang:Up() * (math.sin(ct * 2.0) * 0.12)

		ang:RotateAroundAxis(ang:Right(), -6)
		return pos, ang
	end

	function SWEP:PreDrawViewModel(vm, wep, ply)
		self:ApplyTwoHandedTabletPose(vm)
	end

	function SWEP:PostDrawViewModel(vm, wep, ply)
		if not IsValid(vm) then return end
		vm:SetupBones()

		-- Anchor tablet cleanly in front of camera, cradled between the Left hand bezel grip & Right poking finger!
		local camPos = EyePos()
		local camAng = EyeAngles()
		local ct     = CurTime()

		local tabOrigin = camPos
			+ camAng:Forward() * 13.2
			+ camAng:Right()   * -0.2
			+ camAng:Up()      * (-2.6 + math.sin(ct * 2.0) * 0.08)

		local tabAng = Angle(camAng.p, camAng.y, camAng.r)
		tabAng:RotateAroundAxis(tabAng:Up(), 180)
		tabAng:RotateAroundAxis(tabAng:Right(), -14)

		-- If right index finger tip bone exists, align the UI cursor visually with the fingertip & vice versa!
		local rTipBone = vm:LookupBone("ValveBiped.Bip01_R_Finger12")
		local fingerWorld = nil
		if rTipBone then
			local fm = vm:GetBoneMatrix(rTipBone)
			if fm then
				fingerWorld = fm:GetTranslation()
			end
		end

		-- 1) Draw Sleek Metallic Tablet Body
		local mtx = Matrix()
		mtx:SetTranslation(tabOrigin)
		mtx:SetAngles(tabAng)
		render.SetMaterial(matTabBody)
		render.SetColorModulation(0.18, 0.20, 0.25)
		cam.PushModelMatrix(mtx)
			GetTabletMesh():Draw()
		cam.PopModelMatrix()
		render.SetColorModulation(1, 1, 1)

		-- 2) Draw High-Res Interactive 3D2D Touchscreen on front face (+X of tablet = toward player!)
		local scrPos, scrAng = LocalToWorld(Vector(0.45, 0, 0), Angle(0, 90, 90), tabOrigin, tabAng)
		local uiScale = 0.0265

		local uiX = (self.CursorX or 0) * 205
		local uiY = (self.CursorY or 0) * 125
		local inPast = self:GetInPast()
		local remain = math.max(0, self:GetPastDeadline() - ct)

		cam.Start3D2D(scrPos, scrAng, uiScale)
			-- Screen Glass Background
			draw.RoundedBox(12, -222, -142, 444, 284, inPast and Color(26, 12, 38, 252) or Color(10, 20, 34, 252))
			surface.SetDrawColor(inPast and 225 or 75, inPast and 95 or 215, 255, 240)
			surface.DrawOutlinedRect(-222, -142, 444, 284, 3)

			-- Status Header Bar
			draw.RoundedBoxEx(10, -219, -139, 438, 36, Color(20, 38, 62, 230), true, true, false, false)
			draw.SimpleText("RICK CHRONO-PAD v4.2  |  ТЕМПОРАЛЬНЫЙ ПЛАНШЕТ", "DermaDefaultBold", 0, -121, Color(125, 235, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			if inPast then
				local urgentCol = (remain < 10) and Color(255, 65, 65) or Color(255, 205, 85)
				draw.SimpleText("⚠ ВЫ В ПРОШЛОМ! РЯДОМ ВАША ПРОШЛАЯ ВЕРСИЯ!", "DermaDefaultBold", 0, -78, Color(235, 165, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText(string.format("ДО ПРИБЫТИЯ ПОЛИЦИИ ВРЕМЕНИ: %.1f СЕК.", remain), "Trebuchet24", 0, -42, urgentCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

				-- Progress bar of remaining safe seconds (out of 35s)
				surface.SetDrawColor(45, 22, 55, 230)
				surface.DrawRect(-165, -14, 330, 18)
				surface.SetDrawColor(urgentCol.r, urgentCol.g, urgentCol.b, 245)
				surface.DrawRect(-163, -12, math.floor(326 * math.Clamp(remain / 35.0, 0, 1)), 14)
			else
				draw.SimpleText("ВЫБЕРИТЕ ГЛУБИНУ ПРЫЖКА НАЗАД ВО ВРЕМЕНИ:", "DermaDefaultBold", 0, -76, Color(190, 230, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.RoundedBox(8, -82, -32, 164, 60, Color(16, 34, 56, 240))
				draw.SimpleText("-" .. tostring(self:GetRewindSeconds()) .. " СЕК", "Trebuchet24", 0, -2, Color(115, 245, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			-- Draw Interactive Buttons
			for _, btn in ipairs(self:GetTabletButtons()) do
				local hov = (uiX >= btn.x and uiX <= (btn.x + btn.w) and uiY >= btn.y and uiY <= (btn.y + btn.h))
				draw.RoundedBox(8, btn.x, btn.y, btn.w, btn.h, hov and btn.hcol or btn.col)
				surface.SetDrawColor(215, 248, 255, hov and 255 or 130)
				surface.DrawOutlinedRect(btn.x, btn.y, btn.w, btn.h, 2)
				draw.SimpleText(btn.label, "DermaDefaultBold", btn.x + btn.w * 0.5, btn.y + btn.h * 0.5, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			-- Capacitive Touch Ripple where the index finger poked the glass!
			local tapAge = ct - (self.LastTapAt or 0)
			if tapAge < 0.38 then
				local rFrac = tapAge / 0.38
				surface.DrawCircle(self.RippleX or 0, self.RippleY or 0, math.floor(6 + rFrac * 34), 135, 245, 255, math.floor(255 * (1 - rFrac)))
			end

			-- Live Finger Target Reticle under the poking index finger!
			surface.DrawCircle(uiX, uiY, 8, 125, 245, 255, 235)
			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawRect(uiX - 2, uiY - 2, 4, 4)
		cam.End3D2D()
	end

	function SWEP:DrawWorldModel()
		local owner = self:GetOwner()
		local pos, ang = self:GetPos(), self:GetAngles()
		if IsValid(owner) then
			local bId = owner:LookupBone("ValveBiped.Bip01_R_Hand")
			if bId then
				owner:SetupBones()
				local m = owner:GetBoneMatrix(bId)
				if m then
					pos, ang = LocalToWorld(Vector(4, -3, 0), Angle(0, 0, 0), m:GetTranslation(), m:GetAngles())
				end
			end
		end

		local mtx = Matrix()
		mtx:SetTranslation(pos)
		mtx:SetAngles(ang)
		render.SetMaterial(matTabBody)
		render.SetColorModulation(0.20, 0.24, 0.30)
		cam.PushModelMatrix(mtx)
			GetTabletMesh():Draw()
		cam.PopModelMatrix()
		render.SetColorModulation(1, 1, 1)
	end
end
