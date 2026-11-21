-- ============================================================================
-- Custom High-Detail 3D Model for Rick's CHRONO-REWIND BLASTER (Пушка Времени!)
--  * Sleek beveled gunmetal & titanium sci-fi receiver + ergonomic pistol grip
--  * Transparent glass containment chamber housing a floating, spinning faceted
--    pink-violet Snake Time-Crystal!
--  * Three counter-rotating cyan/gold temporal accelerator rings along the barrel
--  * Animated recoil barrel pistons + crackling violet-cyan temporal lightning arcs
--  * Built-in rear/top digital Chrono-Display showing Rewind Depth & 35s Police Timer!
-- ============================================================================

if SERVER then
	AddCSLuaFile()
	return
end

RICK_PORTAL = RICK_PORTAL or {}
RICK_PORTAL.ChronoGunRenderer = RICK_PORTAL.ChronoGunRenderer or {}

local Chrono = RICK_PORTAL.ChronoGunRenderer
Chrono.Meshes = {}

local matMetal = CreateMaterial("RickChrono_Metal_v1", "VertexLitGeneric", {
	["$basetexture"]        = "models/debug/debugwhite",
	["$halflambert"]        = "1",
	["$phong"]              = "1",
	["$phongboost"]         = "1.5",
	["$phongexponent"]      = "34",
	["$phongfresnelranges"] = "[0.25 0.65 1]"
})

local matUnlit = CreateMaterial("RickChrono_Unlit_v1", "UnlitGeneric", {
	["$basetexture"] = "models/debug/debugwhite",
	["$vertexcolor"] = "1",
	["$vertexalpha"] = "1",
	["$translucent"] = "1",
	["$nocull"]      = "1"
})

local matGlow  = Material("sprites/light_glow02_add")
local matLaser = Material("Effects/laser1")

local function AddSmoothQuad(tris, p1, p2, p3, p4, n1, n2, n3, n4)
	if not n1 then
		local fn = (p4 - p1):Cross(p2 - p1):GetNormalized()
		n1, n2, n3, n4 = fn, fn, fn, fn
	end
	tris[#tris + 1] = { pos = p1, normal = n1, u = 0, v = 0 }
	tris[#tris + 1] = { pos = p2, normal = n2, u = 1, v = 0 }
	tris[#tris + 1] = { pos = p3, normal = n3, u = 1, v = 1 }

	tris[#tris + 1] = { pos = p1, normal = n1, u = 0, v = 0 }
	tris[#tris + 1] = { pos = p3, normal = n3, u = 1, v = 1 }
	tris[#tris + 1] = { pos = p4, normal = n4, u = 0, v = 1 }
end

local function BuildRoundedBoxX(lx, ly, lz, cornerR)
	local tris = {}
	local hx, hy, hz = lx * 0.5, ly * 0.5, lz * 0.5
	local segs = 24
	local r = math.min(cornerR or 0.25, hy * 0.42, hz * 0.42)

	local function Pt(xVal, a)
		local ca, sa = math.cos(a), math.sin(a)
		local iy, iz = hy - r, hz - r
		return Vector(xVal, (ca >= 0 and iy or -iy) + ca * r, (sa >= 0 and iz or -iz) + sa * r), Vector(0, ca, sa):GetNormalized()
	end

	for i = 0, segs - 1 do
		local a1 = (i / segs) * math.pi * 2
		local a2 = ((i + 1) / segs) * math.pi * 2
		local p1B, n1 = Pt(-hx, a1)
		local p1F, _  = Pt( hx, a1)
		local p2F, n2 = Pt( hx, a2)
		local p2B, _  = Pt(-hx, a2)
		AddSmoothQuad(tris, p1B, p1F, p2F, p2B, n1, n1, n2, n2)

		tris[#tris + 1] = { pos = Vector(hx, 0, 0),  normal = Vector(1, 0, 0),  u = 0.5, v = 0.5 }
		tris[#tris + 1] = { pos = p2F,               normal = Vector(1, 0, 0),  u = 1,   v = 1 }
		tris[#tris + 1] = { pos = p1F,               normal = Vector(1, 0, 0),  u = 0,   v = 1 }

		tris[#tris + 1] = { pos = Vector(-hx, 0, 0), normal = Vector(-1, 0, 0), u = 0.5, v = 0.5 }
		tris[#tris + 1] = { pos = p1B,               normal = Vector(-1, 0, 0), u = 0,   v = 1 }
		tris[#tris + 1] = { pos = p2B,               normal = Vector(-1, 0, 0), u = 1,   v = 1 }
	end

	local m = Mesh()
	m:BuildFromTriangles(tris)
	return m
end

-- Cylinder along X axis (for sleek sci-fi barrel & spinning temporal accelerator rings!)
local function BuildTubeX(rIn, rOut, lengthX, segs)
	local tris = {}
	segs = segs or 24
	local hx = lengthX * 0.5

	for i = 0, segs - 1 do
		local a1 = (i / segs) * math.pi * 2
		local a2 = ((i + 1) / segs) * math.pi * 2
		local c1, s1 = math.cos(a1), math.sin(a1)
		local c2, s2 = math.cos(a2), math.sin(a2)
		local n1 = Vector(0, c1, s1)
		local n2 = Vector(0, c2, s2)

		-- Outer wall
		local o1B = Vector(-hx, c1 * rOut, s1 * rOut)
		local o1F = Vector( hx, c1 * rOut, s1 * rOut)
		local o2F = Vector( hx, c2 * rOut, s2 * rOut)
		local o2B = Vector(-hx, c2 * rOut, s2 * rOut)
		AddSmoothQuad(tris, o1B, o1F, o2F, o2B, n1, n1, n2, n2)

		if rIn > 0.01 then
			local i1B = Vector(-hx, c1 * rIn, s1 * rIn)
			local i1F = Vector( hx, c1 * rIn, s1 * rIn)
			local i2F = Vector( hx, c2 * rIn, s2 * rIn)
			local i2B = Vector(-hx, c2 * rIn, s2 * rIn)
			AddSmoothQuad(tris, i2B, i2F, i1F, i1B, -n2, -n2, -n1, -n1)
			-- Front & Back ring faces
			AddSmoothQuad(tris, i1F, o1F, o2F, i2F, Vector(1,0,0), Vector(1,0,0), Vector(1,0,0), Vector(1,0,0))
			AddSmoothQuad(tris, o1B, i1B, i2B, o2B, Vector(-1,0,0), Vector(-1,0,0), Vector(-1,0,0), Vector(-1,0,0))
		else
			tris[#tris + 1] = { pos = Vector(hx, 0, 0),  normal = Vector(1, 0, 0),  u = 0.5, v = 0.5 }
			tris[#tris + 1] = { pos = o2F,               normal = Vector(1, 0, 0),  u = 1,   v = 1 }
			tris[#tris + 1] = { pos = o1F,               normal = Vector(1, 0, 0),  u = 0,   v = 1 }

			tris[#tris + 1] = { pos = Vector(-hx, 0, 0), normal = Vector(-1, 0, 0), u = 0.5, v = 0.5 }
			tris[#tris + 1] = { pos = o1B,               normal = Vector(-1, 0, 0), u = 0,   v = 1 }
			tris[#tris + 1] = { pos = o2B,               normal = Vector(-1, 0, 0), u = 1,   v = 1 }
		end
	end

	local m = Mesh()
	m:BuildFromTriangles(tris)
	return m
end

-- Faceted Double-Pyramid Diamond Time-Crystal!
local function BuildTimeCrystal(radius, halfHeight, sides)
	local tris = {}
	sides = sides or 6
	local top = Vector(0, 0, halfHeight)
	local bot = Vector(0, 0, -halfHeight)

	for i = 0, sides - 1 do
		local a1 = (i / sides) * math.pi * 2
		local a2 = ((i + 1) / sides) * math.pi * 2
		local p1 = Vector(math.cos(a1) * radius, math.sin(a1) * radius, 0)
		local p2 = Vector(math.cos(a2) * radius, math.sin(a2) * radius, 0)

		local nTop = (p2 - top):Cross(p1 - top):GetNormalized()
		tris[#tris + 1] = { pos = top, normal = nTop, u = 0.5, v = 0 }
		tris[#tris + 1] = { pos = p1,  normal = nTop, u = 0,   v = 1 }
		tris[#tris + 1] = { pos = p2,  normal = nTop, u = 1,   v = 1 }

		local nBot = (p1 - bot):Cross(p2 - bot):GetNormalized()
		tris[#tris + 1] = { pos = bot, normal = nBot, u = 0.5, v = 0 }
		tris[#tris + 1] = { pos = p2,  normal = nBot, u = 1,   v = 1 }
		tris[#tris + 1] = { pos = p1,  normal = nBot, u = 0,   v = 1 }
	end

	local m = Mesh()
	m:BuildFromTriangles(tris)
	return m
end

function Chrono:EnsureMeshes()
	if self.Meshes.Ready then return end

	self.Meshes.Grip         = BuildRoundedBoxX(1.55, 1.25, 5.4, 0.45)
	self.Meshes.Receiver     = BuildRoundedBoxX(6.8, 2.75, 2.35, 0.45)
	self.Meshes.ScreenFrame  = BuildRoundedBoxX(2.4, 2.25, 0.35, 0.12)
	self.Meshes.BarrelCore   = BuildTubeX(0, 0.58, 6.2, 22)
	self.Meshes.MuzzleCrown  = BuildTubeX(0.45, 0.96, 1.15, 24)
	self.Meshes.CoilRing     = BuildTubeX(0.95, 1.48, 0.42, 24)
	self.Meshes.CrystalGlass = BuildRoundedBoxX(2.8, 2.1, 2.6, 0.85)
	self.Meshes.Crystal      = BuildTimeCrystal(0.76, 1.35, 6)

	self.Meshes.Ready = true
end

local function DrawPart(im, origin, ang, localPos, localAng, scaleVec, mat, r, g, b, a)
	local wPos, wAng = LocalToWorld(localPos, localAng, origin, ang)
	local mtx = Matrix()
	mtx:SetTranslation(wPos)
	mtx:SetAngles(wAng)
	if scaleVec then mtx:SetScale(scaleVec) end

	render.SetMaterial(mat)
	render.SetColorModulation(r / 255, g / 255, b / 255)
	render.SetBlend((a or 255) / 255)

	cam.PushModelMatrix(mtx)
	im:Draw()
	cam.PopModelMatrix()
end

function Chrono:DrawChronoBlaster(origin, ang, scale, state)
	self:EnsureMeshes()

	scale = scale or 1.0
	state = state or {}
	local ct        = CurTime()
	local firePulse = state.firePulse or 0
	local inPast    = state.inPast or false
	local remain    = state.remain or 35.0
	local rewindSec = state.rewindSec or 10

	local sVec    = Vector(scale, scale, scale)
	local zeroAng = Angle(0, 0, 0)

	-- 1. Angled Ergonomic Titanium Grip
	DrawPart(self.Meshes.Grip, origin, ang, Vector(-1.25 * scale, 0, -1.35 * scale), Angle(-20, 0, 0), sVec, matMetal, 64, 68, 82, 255)

	-- 2. Brushed Silver-Blue Sci-Fi Receiver Body
	DrawPart(self.Meshes.Receiver, origin, ang, Vector(1.65 * scale, 0, 1.95 * scale), zeroAng, sVec, matMetal, 156, 164, 182, 255)

	-- 3. Recoiling Heavy Temporal Barrel + Muzzle Crown!
	local barrelSlide = -firePulse * 1.15
	DrawPart(self.Meshes.BarrelCore,  origin, ang, Vector((7.6 + barrelSlide) * scale, 0, 1.95 * scale), zeroAng, sVec, matMetal, 52, 58, 72, 255)
	DrawPart(self.Meshes.MuzzleCrown, origin, ang, Vector((10.6 + barrelSlide) * scale, 0, 1.95 * scale), zeroAng, sVec, matMetal, 95, 108, 130, 255)

	-- 4. Three Counter-Rotating Glowing Cyan/Violet Temporal Accelerator Coils along the barrel!
	local spinMult = (inPast and 2.6 or 1.0) + firePulse * 5.0
	for c = 1, 3 do
		local cx = (6.1 + (c - 1) * 1.45 + barrelSlide * 0.6) * scale
		local dir = (c % 2 == 0) and -1 or 1
		local ringRoll = ct * (140 + c * 45) * dir * spinMult
		local tiltWobble = math.sin(ct * 4 + c) * 9

		DrawPart(
			self.Meshes.CoilRing,
			origin, ang,
			Vector(cx, 0, 1.95 * scale),
			Angle(tiltWobble, 0, ringRoll),
			sVec,
			matUnlit,
			inPast and 225 or 85,
			inPast and 95  or 225,
			255,
			245
		)
	end

	-- 5. Floating Spinning Pink-Violet Faceted Time-Crystal inside Top Glass Chamber!
	local crysBase = Vector(2.35 * scale, 0, 4.15 * scale)
	local crysBob  = Vector(0, 0, math.sin(ct * 4.5) * 0.16 * scale)
	local crysScale = 1.0 + firePulse * 0.35 + math.sin(ct * 8) * 0.06

	DrawPart(
		self.Meshes.Crystal,
		origin, ang,
		crysBase + crysBob,
		Angle(math.sin(ct * 3) * 14, ct * (120 + firePulse * 380), 0),
		Vector(scale * crysScale, scale * crysScale, scale * crysScale),
		matUnlit, 242, 82, 255, 255
	)

	-- Crackling temporal lightning arcs from Time-Crystal down to the barrel coils!
	local crysWorld = LocalToWorld(crysBase + crysBob, zeroAng, origin, ang)
	local muzWorld  = LocalToWorld(Vector((11.1 + barrelSlide) * scale, 0, 1.95 * scale), zeroAng, origin, ang)

	render.SetMaterial(matGlow)
	render.DrawSprite(crysWorld, (3.8 + firePulse * 2.5) * scale, (3.8 + firePulse * 2.5) * scale, Color(235, 90, 255, 200))
	render.DrawSprite(muzWorld,  (2.8 + firePulse * 4.2) * scale, (2.8 + firePulse * 4.2) * scale, Color(95, 230, 255, 215))

	render.SetMaterial(matLaser)
	for k = 1, 3 do
		local coilW = LocalToWorld(Vector((6.1 + (k - 1) * 1.45) * scale, math.sin(ct * 15 + k) * 0.8 * scale, 2.65 * scale), zeroAng, origin, ang)
		render.DrawBeam(crysWorld, coilW, (0.45 + firePulse * 0.9) * scale, 0, 1, Color(195, 125, 255, 215))
	end

	-- Translucent Glass Chamber around Time-Crystal
	render.OverrideDepthEnable(true, false)
	DrawPart(self.Meshes.CrystalGlass, origin, ang, crysBase, zeroAng, sVec, matMetal, 225, 195, 255, 76)
	render.OverrideDepthEnable(false, false)

	-- 6. Built-In Digital Chrono-Display on Rear-Top of Receiver!
	DrawPart(self.Meshes.ScreenFrame, origin, ang, Vector(-0.45 * scale, 0, 3.18 * scale), Angle(-18, 0, 0), sVec, matMetal, 34, 36, 48, 255)

	local scrPos, scrAng = LocalToWorld(Vector(-0.45 * scale, 0, 3.38 * scale), Angle(0, -90, 18), origin, ang)
	cam.Start3D2D(scrPos, scrAng, 0.014 * scale)
		draw.RoundedBox(6, -72, -52, 144, 104, inPast and Color(36, 10, 48, 240) or Color(10, 22, 38, 240))
		surface.SetDrawColor(inPast and 235 or 85, inPast and 95 or 225, 255, 235)
		surface.DrawOutlinedRect(-72, -52, 144, 104, 2)

		if inPast then
			local warnCol = (remain < 10) and Color(255, 65, 65) or Color(255, 205, 85)
			draw.SimpleText("В ПРОШЛОМ!", "DermaDefaultBold", 0, -32, Color(240, 145, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(string.format("%.1f СЕК", remain), "Trebuchet24", 0, -4, warnCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText("[ПКМ] ВЕРНУТЬСЯ", "DermaDefaultBold", 0, 28, Color(125, 255, 175), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		else
			draw.SimpleText("CHRONO BLASTER", "DermaDefaultBold", 0, -32, Color(115, 235, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText("-" .. tostring(rewindSec) .. " СЕК", "Trebuchet24", 0, -2, Color(235, 135, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText("[R] ШАГ  |  [ЛКМ] ПРЫЖОК", "DermaDefault", 0, 30, Color(195, 230, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	cam.End3D2D()

	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)
end
