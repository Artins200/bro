-- ============================================================================
-- Custom High-Poly 3D Model for Rick's Portal Gun (Smooth Bevels & Rich Animations!)
--  * High-resolution smooth beveled light-gray wedge chassis (zero sharp flat boxes)
--  * Smooth rounded rear drum + ergonomic anatomical club pistol grip
--  * Animated black thumb lever + animated recoil stabilizer fins
--  * Deep dark front recessed housing with 3 pulsing silver-ringed emerald bulbs
--  * Tall crystal-lime glass dome with churning green fluid vortex, rising bubbles,
--    and animated multi-tendril plasma core
--  * Built-in glowing red LED mini-screen displaying live gun telemetry
-- ============================================================================

if SERVER then
	AddCSLuaFile()
	return
end

RICK_PORTAL = RICK_PORTAL or {}
RICK_PORTAL.GunRenderer = RICK_PORTAL.GunRenderer or {}

local Renderer = RICK_PORTAL.GunRenderer
Renderer.Meshes = {}

local matBody = CreateMaterial("RickPG_BodySmooth_v5", "VertexLitGeneric", {
	["$basetexture"]        = "models/debug/debugwhite",
	["$halflambert"]        = "1",
	["$phong"]              = "1",
	["$phongboost"]         = "0.85",
	["$phongexponent"]      = "26",
	["$phongfresnelranges"] = "[0.2 0.6 1]"
})

local matMetal = CreateMaterial("RickPG_Metal_v5", "VertexLitGeneric", {
	["$basetexture"]        = "models/debug/debugwhite",
	["$halflambert"]        = "1",
	["$phong"]              = "1",
	["$phongboost"]         = "1.6",
	["$phongexponent"]      = "40",
	["$phongfresnelranges"] = "[0.3 0.7 1]"
})

local matUnlit = CreateMaterial("RickPG_Unlit_v5", "UnlitGeneric", {
	["$basetexture"] = "models/debug/debugwhite",
	["$vertexcolor"] = "1",
	["$vertexalpha"] = "1",
	["$translucent"] = "1",
	["$nocull"]      = "1"
})

local matGlowSprite = Material("sprites/light_glow02_add")
local matLaser      = Material("Effects/laser1")

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

-- Builds a super-smooth rounded-rectangle lofted chassis (rounded corners via superellipse!)
local function BuildRoundedLoftChassis(xRear, xFront, hyR, hzR, hyF, hzF, cornerR, slicesX, ringSegs)
	local tris = {}
	slicesX  = slicesX or 8
	ringSegs = ringSegs or 32

	local function GetCrossSectionPoint(fracX, angleRad)
		local x  = Lerp(fracX, xRear, xFront)
		local hy = Lerp(fracX, hyR, hyF)
		local hz = Lerp(fracX, hzR, hzF)
		local r  = math.min(cornerR, hy * 0.45, hz * 0.45)

		local ca, sa = math.cos(angleRad), math.sin(angleRad)
		local iy = hy - r
		local iz = hz - r

		local py = (ca >= 0 and iy or -iy) + ca * r
		local pz = (sa >= 0 and iz or -iz) + sa * r
		local n  = Vector(0.03, ca, sa):GetNormalized()
		return Vector(x, py, pz), n
	end

	for s = 0, slicesX - 1 do
		local f1 = s / slicesX
		local f2 = (s + 1) / slicesX
		for i = 0, ringSegs - 1 do
			local a1 = (i / ringSegs) * math.pi * 2
			local a2 = ((i + 1) / ringSegs) * math.pi * 2

			local p11, n11 = GetCrossSectionPoint(f1, a1)
			local p21, n21 = GetCrossSectionPoint(f2, a1)
			local p22, n22 = GetCrossSectionPoint(f2, a2)
			local p12, n12 = GetCrossSectionPoint(f1, a2)

			AddSmoothQuad(tris, p11, p21, p22, p12, n11, n21, n22, n12)
		end
	end

	-- Front face cap (+X) & Rear face cap (-X)
	local frontCenter = Vector(xFront, 0, 0)
	local rearCenter  = Vector(xRear, 0, 0)
	for i = 0, ringSegs - 1 do
		local a1 = (i / ringSegs) * math.pi * 2
		local a2 = ((i + 1) / ringSegs) * math.pi * 2
		local pf1 = GetCrossSectionPoint(1, a1)
		local pf2 = GetCrossSectionPoint(1, a2)
		tris[#tris + 1] = { pos = frontCenter, normal = Vector(1, 0, 0), u = 0.5, v = 0.5 }
		tris[#tris + 1] = { pos = pf2,         normal = Vector(1, 0, 0), u = 1,   v = 1 }
		tris[#tris + 1] = { pos = pf1,         normal = Vector(1, 0, 0), u = 0,   v = 1 }

		local pr1 = GetCrossSectionPoint(0, a1)
		local pr2 = GetCrossSectionPoint(0, a2)
		tris[#tris + 1] = { pos = rearCenter,  normal = Vector(-1, 0, 0), u = 0.5, v = 0.5 }
		tris[#tris + 1] = { pos = pr1,         normal = Vector(-1, 0, 0), u = 0,   v = 1 }
		tris[#tris + 1] = { pos = pr2,         normal = Vector(-1, 0, 0), u = 1,   v = 1 }
	end

	local m = Mesh()
	m:BuildFromTriangles(tris)
	return m
end

local function BuildHorizontalDrumY(radius, fullWidthY, segs)
	local tris = {}
	segs = segs or 28
	local hy = fullWidthY * 0.5

	for i = 0, segs - 1 do
		local a1 = (i / segs) * math.pi * 2
		local a2 = ((i + 1) / segs) * math.pi * 2
		local x1, z1 = math.cos(a1) * radius, math.sin(a1) * radius
		local x2, z2 = math.cos(a2) * radius, math.sin(a2) * radius
		local n1 = Vector(math.cos(a1), 0, math.sin(a1))
		local n2 = Vector(math.cos(a2), 0, math.sin(a2))

		local p1L = Vector(x1,  hy, z1)
		local p2L = Vector(x2,  hy, z2)
		local p2R = Vector(x2, -hy, z2)
		local p1R = Vector(x1, -hy, z1)

		AddSmoothQuad(tris, p1L, p1R, p2R, p2L, n1, n1, n2, n2)

		tris[#tris + 1] = { pos = Vector(0, hy, 0), normal = Vector(0, 1, 0), u = 0.5, v = 0.5 }
		tris[#tris + 1] = { pos = p1L,              normal = Vector(0, 1, 0), u = 0,   v = 1 }
		tris[#tris + 1] = { pos = p2L,              normal = Vector(0, 1, 0), u = 1,   v = 1 }

		tris[#tris + 1] = { pos = Vector(0, -hy, 0), normal = Vector(0, -1, 0), u = 0.5, v = 0.5 }
		tris[#tris + 1] = { pos = p2R,               normal = Vector(0, -1, 0), u = 1,   v = 1 }
		tris[#tris + 1] = { pos = p1R,               normal = Vector(0, -1, 0), u = 0,   v = 1 }
	end

	local m = Mesh()
	m:BuildFromTriangles(tris)
	return m
end

local function BuildTeardropGrip()
	local tris   = {}
	local rings  = 18
	local segs   = 24
	local length = 5.65

	local function Profile(t)
		local z = -t * length
		local x = -t * 2.10
		local rx, ry
		if t < 0.78 then
			local swell = math.sin((t / 0.78) * (math.pi * 0.62))
			rx = 0.72 + swell * 0.38
			ry = 0.64 + swell * 0.33
		else
			local capT = (t - 0.78) / 0.22
			local c = math.cos(capT * math.pi * 0.5)
			rx = (0.72 + math.sin(0.62 * math.pi) * 0.38) * c
			ry = (0.64 + math.sin(0.62 * math.pi) * 0.33) * c
		end
		return x, z, math.max(rx, 0.01), math.max(ry, 0.01)
	end

	for r = 0, rings - 1 do
		local x1, z1, rx1, ry1 = Profile(r / rings)
		local x2, z2, rx2, ry2 = Profile((r + 1) / rings)

		for i = 0, segs - 1 do
			local a1 = (i / segs) * math.pi * 2
			local a2 = ((i + 1) / segs) * math.pi * 2
			local c1, s1 = math.cos(a1), math.sin(a1)
			local c2, s2 = math.cos(a2), math.sin(a2)

			local p11 = Vector(x1 + c1 * rx1, s1 * ry1, z1)
			local p21 = Vector(x1 + c2 * rx1, s2 * ry1, z1)
			local p22 = Vector(x2 + c2 * rx2, s2 * ry2, z2)
			local p12 = Vector(x2 + c1 * rx2, s1 * ry2, z2)

			local n1 = Vector(c1, s1, -0.15):GetNormalized()
			local n2 = Vector(c2, s2, -0.15):GetNormalized()

			AddSmoothQuad(tris, p11, p21, p22, p12, n1, n2, n2, n1)
		end
	end

	local m = Mesh()
	m:BuildFromTriangles(tris)
	return m
end

local function BuildCapsuleDome(radius, cylHeight, segs, rings, includeBottomCap, taperTop)
	local tris = {}
	segs  = segs or 32
	rings = rings or 14
	local topR = radius * (taperTop or 1.0)

	for i = 0, segs - 1 do
		local a1 = (i / segs) * math.pi * 2
		local a2 = ((i + 1) / segs) * math.pi * 2
		local c1, s1 = math.cos(a1), math.sin(a1)
		local c2, s2 = math.cos(a2), math.sin(a2)
		local n1 = Vector(c1, s1, 0)
		local n2 = Vector(c2, s2, 0)
		local p1 = Vector(c1 * radius, s1 * radius, 0)
		local p2 = Vector(c2 * radius, s2 * radius, 0)
		local p3 = Vector(c2 * topR,   s2 * topR,   cylHeight)
		local p4 = Vector(c1 * topR,   s1 * topR,   cylHeight)

		AddSmoothQuad(tris, p1, p2, p3, p4, n1, n2, n2, n1)
	end

	for r = 0, rings - 1 do
		local phi1 = (r / rings) * (math.pi * 0.5)
		local phi2 = ((r + 1) / rings) * (math.pi * 0.5)
		local cp1, sp1 = math.cos(phi1), math.sin(phi1)
		local cp2, sp2 = math.cos(phi2), math.sin(phi2)

		for i = 0, segs - 1 do
			local a1 = (i / segs) * math.pi * 2
			local a2 = ((i + 1) / segs) * math.pi * 2
			local c1, s1 = math.cos(a1), math.sin(a1)
			local c2, s2 = math.cos(a2), math.sin(a2)

			local n11 = Vector(c1 * cp1, s1 * cp1, sp1)
			local n21 = Vector(c2 * cp1, s2 * cp1, sp1)
			local n22 = Vector(c2 * cp2, s2 * cp2, sp2)
			local n12 = Vector(c1 * cp2, s1 * cp2, sp2)

			local p11 = Vector(n11.x * topR, n11.y * topR, cylHeight + n11.z * topR)
			local p21 = Vector(n21.x * topR, n21.y * topR, cylHeight + n21.z * topR)
			local p22 = Vector(n22.x * topR, n22.y * topR, cylHeight + n22.z * topR)
			local p12 = Vector(n12.x * topR, n12.y * topR, cylHeight + n12.z * topR)

			AddSmoothQuad(tris, p11, p21, p22, p12, n11, n21, n22, n12)
		end
	end

	if includeBottomCap then
		for r = 0, rings - 1 do
			local phi1 = (r / rings) * (math.pi * 0.5)
			local phi2 = ((r + 1) / rings) * (math.pi * 0.5)
			local cp1, sp1 = math.cos(phi1), math.sin(phi1)
			local cp2, sp2 = math.cos(phi2), math.sin(phi2)

			for i = 0, segs - 1 do
				local a1 = (i / segs) * math.pi * 2
				local a2 = ((i + 1) / segs) * math.pi * 2
				local c1, s1 = math.cos(a1), math.sin(a1)
				local c2, s2 = math.cos(a2), math.sin(a2)

				local n11 = Vector(c1 * cp1, s1 * cp1, -sp1)
				local n21 = Vector(c2 * cp1, s2 * cp1, -sp1)
				local n22 = Vector(c2 * cp2, s2 * cp2, -sp2)
				local n12 = Vector(c1 * cp2, s1 * cp2, -sp2)

				local p11 = Vector(n11.x * radius, n11.y * radius, n11.z * radius)
				local p21 = Vector(n21.x * radius, n21.y * radius, n21.z * radius)
				local p22 = Vector(n22.x * radius, n22.y * radius, n22.z * radius)
				local p12 = Vector(n12.x * radius, n12.y * radius, n12.z * radius)

				AddSmoothQuad(tris, p11, p12, p22, p21, n11, n12, n22, n21)
			end
		end
	end

	local m = Mesh()
	m:BuildFromTriangles(tris)
	return m
end

local function BuildSphere(radius, segs, rings)
	return BuildCapsuleDome(radius, 0.001, segs or 20, rings or 10, true)
end

function Renderer:EnsureMeshes()
	if self.Meshes.Ready then return end

	self.Meshes.Chassis       = BuildRoundedLoftChassis(-1.5, 8.3, 2.52, 1.14, 2.26, 0.96, 0.28, 8, 32)
	self.Meshes.RearDrum      = BuildHorizontalDrumY(1.13, 4.95, 28)
	self.Meshes.Grip          = BuildTeardropGrip()
	self.Meshes.FrontCavity   = BuildRoundedLoftChassis(-0.30, 0.30, 1.96, 0.68, 1.96, 0.68, 0.08, 2, 20)
	self.Meshes.TopRecess     = BuildRoundedLoftChassis(-1.35, 1.35, 0.90, 0.12, 0.90, 0.12, 0.06, 2, 16)
	self.Meshes.ThumbSwitch   = BuildRoundedLoftChassis(-0.62, 0.62, 0.34, 0.28, 0.30, 0.22, 0.08, 2, 16)
	self.Meshes.DomeCollar    = BuildCapsuleDome(1.82, 0.44, 32, 6, false, 0.90)
	self.Meshes.DomeCollarRim = BuildCapsuleDome(1.66, 0.18, 32, 4, false, 0.96)
	self.Meshes.DomeFluid     = BuildCapsuleDome(1.48, 0.22, 28, 4, false)
	self.Meshes.GlassDome     = BuildCapsuleDome(1.62, 2.98, 32, 14, false)
	self.Meshes.GlassInner    = BuildCapsuleDome(1.50, 2.82, 26, 10, false)
	self.Meshes.BulbBezel     = BuildCapsuleDome(0.56, 0.42, 22, 5, false, 0.92)
	self.Meshes.BulbLens      = BuildSphere(0.46, 18, 9)
	self.Meshes.PlasmaCore    = BuildSphere(0.90, 22, 12)
	self.Meshes.PlasmaTendril = BuildSphere(0.22, 12, 6)

	self.Meshes.Ready = true
end

local function DrawMeshPart(im, origin, ang, localPos, localAng, scaleVec, mat, r, g, b, a)
	local worldPos, worldAng = LocalToWorld(localPos, localAng, origin, ang)
	local mtx = Matrix()
	mtx:SetTranslation(worldPos)
	mtx:SetAngles(worldAng)
	if scaleVec then mtx:SetScale(scaleVec) end

	render.SetMaterial(mat)
	render.SetColorModulation(r / 255, g / 255, b / 255)
	render.SetBlend((a or 255) / 255)

	cam.PushModelMatrix(mtx)
	im:Draw()
	cam.PopModelMatrix()
end

function Renderer:DrawGun(origin, ang, scale, state)
	self:EnsureMeshes()

	scale = scale or 1.0
	state = state or {}
	local ct        = CurTime()
	local firePulse = state.firePulse or 0
	local dialKick  = state.dialKick or 0
	local hasA      = state.hasA or false
	local hasB      = state.hasB or false
	local distM     = state.targetDistM or 0
	local surfType  = state.surfType or "AIR"
	local fireMode  = state.fireMode or 1

	local sVec    = Vector(scale, scale, scale)
	local zeroAng = Angle(0, 0, 0)

	-- 1. Smooth Anatomical Teardrop Club Grip
	DrawMeshPart(self.Meshes.Grip, origin, ang, Vector(-1.35 * scale, 0, 1.30 * scale), zeroAng, sVec, matBody, 166, 170, 175, 255)

	-- 2. Smooth Rounded Rear Drum + Beveled Tapered Matte-Gray Chassis
	DrawMeshPart(self.Meshes.RearDrum, origin, ang, Vector(-0.55 * scale, 0, 2.20 * scale), zeroAng, sVec, matBody, 196, 200, 205, 255)
	DrawMeshPart(self.Meshes.Chassis,  origin, ang, Vector(1.00 * scale, 0, 2.20 * scale), zeroAng, sVec, matBody, 204, 208, 213, 255)

	-- 3. Animated Black Notched Thumb Lever (rocks smoothly when firing or toggling modes!)
	DrawMeshPart(
		self.Meshes.ThumbSwitch,
		origin, ang,
		Vector((-1.15 + dialKick * 0.16) * scale, 0, (3.34 - dialKick * 0.16) * scale),
		Angle(-26 - dialKick * 18, 0, 0),
		sVec,
		matMetal, 34, 36, 42, 255
	)

	-- 4. Front Emitter Cavity + 3 Animated Pulsing/Extending Silver-Ringed Green Bulbs!
	DrawMeshPart(self.Meshes.FrontCavity, origin, ang, Vector(9.12 * scale, 0, 2.20 * scale), zeroAng, sVec, matBody, 38, 41, 45, 255)

	for i = -1, 1 do
		local yOff = i * 1.28 * scale
		-- Sequential wave animation across the 3 bulbs + recoil Piston kick!
		local bulbWave = math.sin(ct * 6.5 + i * 1.4) * 0.04
		local pistonX  = (8.98 - firePulse * 0.22 + bulbWave) * scale
		local lensX    = (9.34 - firePulse * 0.18 + bulbWave) * scale
		local gBright  = math.Clamp(225 + math.sin(ct * 8 + i * 1.8) * 20 + firePulse * 30, 180, 255)

		DrawMeshPart(self.Meshes.BulbBezel, origin, ang, Vector(pistonX, yOff, 2.20 * scale), Angle(90, 0, 0), sVec, matMetal, 168, 174, 180, 255)
		DrawMeshPart(self.Meshes.BulbLens,  origin, ang, Vector(lensX,   yOff, 2.20 * scale), zeroAng, Vector(scale * 0.68, scale, scale), matUnlit, 78, gBright, 56, 255)
	end

	-- 5. Recessed Top Red Mini-Screen + Live Telemetry
	DrawMeshPart(self.Meshes.TopRecess, origin, ang, Vector(1.45 * scale, 0, 3.30 * scale), zeroAng, sVec, matMetal, 64, 22, 24, 255)
	DrawMeshPart(self.Meshes.TopRecess, origin, ang, Vector(1.45 * scale, 0, 3.34 * scale), zeroAng, Vector(scale * 0.92, scale * 0.90, scale * 0.85), matUnlit, 198, 26, 24, 255)

	local scrPos, scrAng = LocalToWorld(Vector(1.45 * scale, 0, 3.44 * scale), Angle(0, -90, 0), origin, ang)
	cam.Start3D2D(scrPos, scrAng, 0.0145 * scale)
		draw.RoundedBox(6, -56, -84, 112, 168, Color(42, 6, 8, 195))
		surface.SetDrawColor(255, 85, 75, 225)
		surface.DrawOutlinedRect(-56, -84, 112, 168, 2)

		local modeTxt = (fireMode == 2) and "MODE: MAP SKY" or "MODE: DUAL"
		local modeCol = (fireMode == 2) and Color(120, 235, 255, 255) or Color(150, 255, 110, 255)
		draw.SimpleText(modeTxt, "DermaDefaultBold", 0, -68, modeCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		surface.SetDrawColor(255, 75, 65, 130)
		surface.DrawRect(-48, -54, 96, 2)

		local colOn  = Color(145, 255, 95, 255)
		local colOff = Color(255, 135, 125, 180)
		draw.SimpleText("A: " .. (hasA and "OPEN" or "OFF"), "DermaDefaultBold", 0, -36, hasA and colOn or colOff, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("B: " .. (hasB and "OPEN" or "OFF"), "DermaDefaultBold", 0, -16, hasB and colOn or colOff, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		draw.SimpleText("AIM: " .. surfType, "DermaDefault", 0, 10, Color(255, 225, 210, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(string.format("RNG: %.1fm", distM), "DermaDefault", 0, 28, Color(255, 200, 185, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("[E+R] MODE", "DermaDefault", 0, 48, Color(255, 180, 160, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		local fluidFrac = math.Clamp(1.0 - firePulse * 0.38, 0.2, 1.0)
		surface.SetDrawColor(90, 18, 18, 220)
		surface.DrawRect(-46, 62, 92, 12)
		surface.SetDrawColor(125, 250, 80, 240)
		surface.DrawRect(-44, 64, math.floor(88 * fluidFrac), 8)
	cam.End3D2D()

	-- 6. Stepped Silver Collar + Churning Fluid + Rising Bubbles + Spiky Plasma Core + Lightning Arcs!
	local domeX = 5.15 * scale
	local domeZ = 3.20 * scale
	DrawMeshPart(self.Meshes.DomeCollar,    origin, ang, Vector(domeX, 0, domeZ), zeroAng, sVec, matMetal, 172, 178, 186, 255)
	DrawMeshPart(self.Meshes.DomeCollarRim, origin, ang, Vector(domeX, 0, domeZ + 0.36 * scale), zeroAng, sVec, matMetal, 195, 202, 210, 255)
	DrawMeshPart(self.Meshes.DomeFluid,     origin, ang, Vector(domeX, 0, domeZ + 0.44 * scale), Angle(0, ct * 90, 0), sVec, matUnlit, 62, 222, 52, 250)

	-- Animated rising green bubbles inside the glass dome!
	for b = 1, 5 do
		local bCycle = (ct * (0.9 + b * 0.18) + b * 0.37) % 1.0
		local bAng   = b * 2.1 + ct * 2.5
		local bRad   = 0.85 * (1.0 - bCycle * 0.4) * scale
		local bPos   = Vector(domeX + math.cos(bAng) * bRad, math.sin(bAng) * bRad, domeZ + (0.55 + bCycle * 2.55) * scale)
		local bSz    = (0.42 - bCycle * 0.22) * scale
		DrawMeshPart(self.Meshes.PlasmaTendril, origin, ang, bPos, zeroAng, Vector(bSz, bSz, bSz), matUnlit, 175, 255, 125, 230)
	end

	local bobZ      = math.sin(ct * 4.2) * 0.18 * scale
	local spinSpeed = 48 + firePulse * 240
	local corePulse = 1.0 + math.sin(ct * 7.2) * 0.08 + firePulse * 0.32
	local coreLocal = Vector(domeX, 0, domeZ + 2.12 * scale + bobZ)

	DrawMeshPart(
		self.Meshes.PlasmaCore,
		origin, ang,
		coreLocal,
		Angle(ct * spinSpeed * 0.8, ct * spinSpeed, 0),
		Vector(scale * corePulse * 0.94, scale * corePulse * 0.94, scale * corePulse * 1.14),
		matUnlit, 68, 242, 48, 255
	)

	-- Animated undulating wavy tendrils reaching out from core
	for i = 1, 8 do
		local baseA  = (i / 8) * math.pi * 2 + ct * (1.2 + firePulse * 3.0)
		local pitchA = ((i % 3) - 1) * 0.65 + math.sin(ct * 3.4 + i) * 0.30
		local dir    = Vector(math.cos(baseA) * math.cos(pitchA), math.sin(baseA) * math.cos(pitchA), math.sin(pitchA) + 0.25):GetNormalized()
		for seg = 1, 3 do
			local dist   = (0.68 + seg * 0.26) * scale * corePulse
			local wiggle = Vector(math.sin(ct * 7.5 + i * 2 + seg) * 0.10 * scale, math.cos(ct * 7.5 + i * 2 + seg) * 0.10 * scale, math.sin(ct * 6 + seg) * 0.08 * scale)
			local segSz  = (1.12 - seg * 0.24) * scale
			DrawMeshPart(self.Meshes.PlasmaTendril, origin, ang, coreLocal + dir * dist + wiggle, zeroAng, Vector(segSz, segSz, segSz), matUnlit, 95 + seg * 22, 255, 68, 255)
		end
	end

	-- Mini green plasma lightning arcs inside the glass tube when firing or idling!
	local coreWorld = LocalToWorld(coreLocal, zeroAng, origin, ang)
	render.SetMaterial(matLaser)
	local numArcs = firePulse > 0.1 and 4 or 2
	for a = 1, numArcs do
		local angArc = ct * 11 + a * 2.4
		local rimLocal = coreLocal + Vector(math.cos(angArc) * 1.35 * scale, math.sin(angArc) * 1.35 * scale, math.sin(ct * 9 + a) * 0.8 * scale)
		local rimWorld = LocalToWorld(rimLocal, zeroAng, origin, ang)
		render.DrawBeam(coreWorld, rimWorld, (0.45 + firePulse * 0.8) * scale, 0, 1, Color(165, 255, 110, 215))
	end

	render.SetMaterial(matGlowSprite)
	render.DrawSprite(coreWorld, 4.6 * scale * corePulse, 5.6 * scale * corePulse, Color(95, 255, 70, 165))

	for i = -1, 1 do
		local bulbWorld = LocalToWorld(Vector(9.50 * scale, i * 1.28 * scale, 2.20 * scale), zeroAng, origin, ang)
		render.DrawSprite(bulbWorld, (1.6 + firePulse * 2.4) * scale, (1.6 + firePulse * 2.4) * scale, Color(105, 255, 75, 205))
	end

	-- 7. Smooth Tall Lime-Green Glass Capsule Dome
	render.OverrideDepthEnable(true, false)
	DrawMeshPart(self.Meshes.GlassInner, origin, ang, Vector(domeX, 0, domeZ + 0.46 * scale), zeroAng, sVec, matUnlit, 155, 255, 142, 44)
	DrawMeshPart(self.Meshes.GlassDome,  origin, ang, Vector(domeX, 0, domeZ + 0.42 * scale), zeroAng, sVec, matBody,  218, 255, 215, 86)
	render.OverrideDepthEnable(false, false)

	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)
end
