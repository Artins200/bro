-- ============================================================================
-- Custom Clean 3D Model for Rick's Portal Gun (Exact Proportions & Clean Mesh!)
-- Reference: b8f20707ee38dd3ec3a4a7f1b2adaa4f.png
--  * Clean smooth light-gray rectangular chassis with subtle front taper
--  * Rounded rear cylinder drum + angled ergonomic club pistol grip
--  * Deep dark front emitter housing with 3 silver-ringed glowing green bulbs
--  * Tall lime-tinted glass capsule dome on stepped silver collar
--  * Spiky animated green plasma core + wavy tendrils + liquid base
--  * Recessed red LED mini-screen displaying Mode (DUAL / MAP), Portal A & B, Aim
-- ============================================================================

if SERVER then
	AddCSLuaFile()
	return
end

RICK_PORTAL = RICK_PORTAL or {}
RICK_PORTAL.GunRenderer = RICK_PORTAL.GunRenderer or {}

local Renderer = RICK_PORTAL.GunRenderer
Renderer.Meshes = {}

local matBody = CreateMaterial("RickPG_BodyClean_v4", "VertexLitGeneric", {
	["$basetexture"]        = "models/debug/debugwhite",
	["$halflambert"]        = "1",
	["$phong"]              = "1",
	["$phongboost"]         = "0.55",
	["$phongexponent"]      = "20",
	["$phongfresnelranges"] = "[0.15 0.5 1]"
})

local matUnlit = CreateMaterial("RickPG_UnlitClean_v4", "UnlitGeneric", {
	["$basetexture"] = "models/debug/debugwhite",
	["$vertexcolor"] = "1",
	["$vertexalpha"] = "1",
	["$translucent"] = "1",
	["$nocull"]      = "1"
})

local matGlowSprite = Material("sprites/light_glow02_add")

local function AddQuad(tris, p1, p2, p3, p4)
	-- Compute exact outward face normal from cross product of edges
	local e1 = p2 - p1
	local e2 = p4 - p1
	local n  = e2:Cross(e1):GetNormalized()
	tris[#tris + 1] = { pos = p1, normal = n, u = 0, v = 0 }
	tris[#tris + 1] = { pos = p2, normal = n, u = 1, v = 0 }
	tris[#tris + 1] = { pos = p3, normal = n, u = 1, v = 1 }

	tris[#tris + 1] = { pos = p1, normal = n, u = 0, v = 0 }
	tris[#tris + 1] = { pos = p3, normal = n, u = 1, v = 1 }
	tris[#tris + 1] = { pos = p4, normal = n, u = 0, v = 1 }
end

-- Watertight, artifact-free tapered rectangular box (front slightly slimmer than rear, matching photo!)
local function BuildCleanTaperedBox(xRear, xFront, hyR, hzR, hyF, hzF)
	local tris = {}

	local rTL = Vector(xRear,  hyR,  hzR)
	local rTR = Vector(xRear, -hyR,  hzR)
	local rBL = Vector(xRear,  hyR, -hzR)
	local rBR = Vector(xRear, -hyR, -hzR)

	local fTL = Vector(xFront,  hyF,  hzF)
	local fTR = Vector(xFront, -hyF,  hzF)
	local fBL = Vector(xFront,  hyF, -hzF)
	local fBR = Vector(xFront, -hyF, -hzF)

	-- Top (+Z)
	AddQuad(tris, rTR, fTR, fTL, rTL)
	-- Bottom (-Z)
	AddQuad(tris, rBL, fBL, fBR, rBR)
	-- Left (+Y)
	AddQuad(tris, rTL, fTL, fBL, rBL)
	-- Right (-Y)
	AddQuad(tris, fTR, rTR, rBR, fBR)
	-- Rear (-X)
	AddQuad(tris, rTL, rBL, rBR, rTR)
	-- Front (+X)
	AddQuad(tris, fTR, fBR, fBL, fTL)

	local m = Mesh()
	m:BuildFromTriangles(tris)
	return m
end

-- Horizontal cylinder along Y axis (for smooth rounded rear shoulder of the chassis!)
local function BuildHorizontalDrumY(radius, fullWidthY, segs)
	local tris = {}
	segs = segs or 20
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

		tris[#tris + 1] = { pos = p1L, normal = n1, u = 0, v = 0 }
		tris[#tris + 1] = { pos = p1R, normal = n1, u = 1, v = 0 }
		tris[#tris + 1] = { pos = p2R, normal = n2, u = 1, v = 1 }

		tris[#tris + 1] = { pos = p1L, normal = n1, u = 0, v = 0 }
		tris[#tris + 1] = { pos = p2R, normal = n2, u = 1, v = 1 }
		tris[#tris + 1] = { pos = p2L, normal = n2, u = 0, v = 1 }

		-- Left cap (+Y)
		tris[#tris + 1] = { pos = Vector(0, hy, 0), normal = Vector(0, 1, 0), u = 0.5, v = 0.5 }
		tris[#tris + 1] = { pos = p1L,              normal = Vector(0, 1, 0), u = 0,   v = 1 }
		tris[#tris + 1] = { pos = p2L,              normal = Vector(0, 1, 0), u = 1,   v = 1 }

		-- Right cap (-Y)
		tris[#tris + 1] = { pos = Vector(0, -hy, 0), normal = Vector(0, -1, 0), u = 0.5, v = 0.5 }
		tris[#tris + 1] = { pos = p2R,               normal = Vector(0, -1, 0), u = 1,   v = 1 }
		tris[#tris + 1] = { pos = p1R,               normal = Vector(0, -1, 0), u = 0,   v = 1 }
	end

	local m = Mesh()
	m:BuildFromTriangles(tris)
	return m
end

-- Smooth ergonomic club/teardrop pistol grip matching photo!
local function BuildTeardropGrip()
	local tris = {}
	local rings  = 14
	local segs   = 20
	local length = 5.6

	local function Profile(t)
		local z = -t * length
		local x = -t * 2.05
		local rx, ry
		if t < 0.78 then
			local swell = math.sin((t / 0.78) * (math.pi * 0.60))
			rx = 0.72 + swell * 0.36
			ry = 0.64 + swell * 0.32
		else
			local capT = (t - 0.78) / 0.22
			local c = math.cos(capT * math.pi * 0.5)
			rx = (0.72 + math.sin(0.60 * math.pi) * 0.36) * c
			ry = (0.64 + math.sin(0.60 * math.pi) * 0.32) * c
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

			tris[#tris + 1] = { pos = p11, normal = n1, u = 0, v = 0 }
			tris[#tris + 1] = { pos = p21, normal = n2, u = 1, v = 0 }
			tris[#tris + 1] = { pos = p22, normal = n2, u = 1, v = 1 }

			tris[#tris + 1] = { pos = p11, normal = n1, u = 0, v = 0 }
			tris[#tris + 1] = { pos = p22, normal = n2, u = 1, v = 1 }
			tris[#tris + 1] = { pos = p12, normal = n1, u = 0, v = 1 }
		end
	end

	local m = Mesh()
	m:BuildFromTriangles(tris)
	return m
end

local function BuildCapsuleDome(radius, cylHeight, segs, rings, includeBottomCap, taperTop)
	local tris = {}
	segs  = segs or 24
	rings = rings or 10
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

		tris[#tris + 1] = { pos = p1, normal = n1, u = 0, v = 1 }
		tris[#tris + 1] = { pos = p2, normal = n2, u = 1, v = 1 }
		tris[#tris + 1] = { pos = p3, normal = n2, u = 1, v = 0 }

		tris[#tris + 1] = { pos = p1, normal = n1, u = 0, v = 1 }
		tris[#tris + 1] = { pos = p3, normal = n2, u = 1, v = 0 }
		tris[#tris + 1] = { pos = p4, normal = n1, u = 0, v = 0 }
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

			tris[#tris + 1] = { pos = p11, normal = n11, u = 0, v = 0 }
			tris[#tris + 1] = { pos = p21, normal = n21, u = 1, v = 0 }
			tris[#tris + 1] = { pos = p22, normal = n22, u = 1, v = 1 }

			tris[#tris + 1] = { pos = p11, normal = n11, u = 0, v = 0 }
			tris[#tris + 1] = { pos = p22, normal = n22, u = 1, v = 1 }
			tris[#tris + 1] = { pos = p12, normal = n12, u = 0, v = 1 }
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

				tris[#tris + 1] = { pos = p11, normal = n11, u = 0, v = 0 }
				tris[#tris + 1] = { pos = p22, normal = n22, u = 1, v = 1 }
				tris[#tris + 1] = { pos = p21, normal = n21, u = 1, v = 0 }

				tris[#tris + 1] = { pos = p11, normal = n11, u = 0, v = 0 }
				tris[#tris + 1] = { pos = p12, normal = n12, u = 0, v = 1 }
				tris[#tris + 1] = { pos = p22, normal = n22, u = 1, v = 1 }
			end
		end
	end

	local m = Mesh()
	m:BuildFromTriangles(tris)
	return m
end

local function BuildSphere(radius, segs, rings)
	return BuildCapsuleDome(radius, 0.001, segs or 16, rings or 8, true)
end

function Renderer:EnsureMeshes()
	if self.Meshes.Ready then return end

	self.Meshes.Chassis       = BuildCleanTaperedBox(-1.6, 8.2, 2.55, 1.15, 2.30, 0.98)
	self.Meshes.RearDrum      = BuildHorizontalDrumY(1.15, 5.10, 20)
	self.Meshes.Grip          = BuildTeardropGrip()
	self.Meshes.FrontCavity   = BuildCleanTaperedBox(-0.25, 0.25, 2.02, 0.72, 2.02, 0.72)
	self.Meshes.TopRecess     = BuildCleanTaperedBox(-1.35, 1.35, 0.92, 0.12, 0.92, 0.12)
	self.Meshes.ThumbSwitch   = BuildCleanTaperedBox(-0.62, 0.62, 0.34, 0.28, 0.34, 0.28)
	self.Meshes.DomeCollar    = BuildCapsuleDome(1.80, 0.48, 26, 5, false, 0.90)
	self.Meshes.DomeFluid     = BuildCapsuleDome(1.48, 0.20, 22, 4, false)
	self.Meshes.GlassDome     = BuildCapsuleDome(1.62, 2.95, 28, 12, false)
	self.Meshes.GlassInner    = BuildCapsuleDome(1.50, 2.78, 22, 9, false)
	self.Meshes.BulbBezel     = BuildCapsuleDome(0.56, 0.38, 18, 4, false)
	self.Meshes.BulbLens      = BuildSphere(0.46, 14, 7)
	self.Meshes.PlasmaCore    = BuildSphere(0.90, 18, 10)
	self.Meshes.PlasmaTendril = BuildSphere(0.24, 10, 5)

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
	local fireMode  = state.fireMode or 1 -- 1 = DUAL PORTAL, 2 = OVERHEAD MAP TELEPORT

	local sVec    = Vector(scale, scale, scale)
	local zeroAng = Angle(0, 0, 0)

	-- 1. Teardrop Ergonomic Club Grip
	DrawMeshPart(self.Meshes.Grip, origin, ang, Vector(-1.35 * scale, 0, 1.30 * scale), zeroAng, sVec, matBody, 168, 171, 175, 255)

	-- 2. Rounded Rear Shoulder Drum + Clean Tapered Matte-Gray Body
	DrawMeshPart(self.Meshes.RearDrum, origin, ang, Vector(-0.60 * scale, 0, 2.20 * scale), zeroAng, sVec, matBody, 196, 199, 203, 255)
	DrawMeshPart(self.Meshes.Chassis,  origin, ang, Vector(1.00 * scale, 0, 2.20 * scale), zeroAng, sVec, matBody, 202, 205, 209, 255)

	-- 3. Black Angled Thumb Lever on Rear-Top Curve
	DrawMeshPart(
		self.Meshes.ThumbSwitch,
		origin, ang,
		Vector((-1.15 + dialKick * 0.10) * scale, 0, (3.35 - dialKick * 0.12) * scale),
		Angle(-26 - dialKick * 12, 0, 0),
		sVec,
		matBody, 38, 40, 44, 255
	)

	-- 4. Dark Recessed Front Emitter Cavity + 3 Silver-Ringed Bright Green Bulbs
	DrawMeshPart(self.Meshes.FrontCavity, origin, ang, Vector(9.05 * scale, 0, 2.20 * scale), zeroAng, sVec, matBody, 42, 45, 48, 255)

	local greenBoost = math.min(255, 232 + firePulse * 23)
	for i = -1, 1 do
		local yOff = i * 1.30 * scale
		DrawMeshPart(self.Meshes.BulbBezel, origin, ang, Vector(8.92 * scale, yOff, 2.20 * scale), Angle(90, 0, 0), sVec, matBody, 165, 169, 173, 255)
		DrawMeshPart(self.Meshes.BulbLens,  origin, ang, Vector(9.26 * scale, yOff, 2.20 * scale), zeroAng, Vector(scale * 0.65, scale, scale), matUnlit, 82, greenBoost, 58, 255)
	end

	-- 5. Recessed Top Red Mini-Screen + Live Telemetry (Mode, Portals A & B, Aim, Fluid)
	DrawMeshPart(self.Meshes.TopRecess, origin, ang, Vector(1.45 * scale, 0, 3.30 * scale), zeroAng, sVec, matBody, 68, 24, 24, 255)
	DrawMeshPart(self.Meshes.TopRecess, origin, ang, Vector(1.45 * scale, 0, 3.34 * scale), zeroAng, Vector(scale * 0.92, scale * 0.90, scale * 0.85), matUnlit, 195, 26, 24, 255)

	local scrPos, scrAng = LocalToWorld(Vector(1.45 * scale, 0, 3.44 * scale), Angle(0, -90, 0), origin, ang)
	cam.Start3D2D(scrPos, scrAng, 0.0145 * scale)
		draw.RoundedBox(6, -56, -84, 112, 168, Color(42, 6, 8, 190))
		surface.SetDrawColor(255, 85, 75, 220)
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

		local fluidFrac = math.Clamp(1.0 - firePulse * 0.35, 0.2, 1.0)
		surface.SetDrawColor(90, 18, 18, 220)
		surface.DrawRect(-46, 62, 92, 12)
		surface.SetDrawColor(125, 250, 80, 240)
		surface.DrawRect(-44, 64, math.floor(88 * fluidFrac), 8)
	cam.End3D2D()

	-- 6. Stepped Silver Collar + Tall Lime-Green Glass Dome + Spiky Plasma Core
	local domeX = 5.15 * scale
	local domeZ = 3.22 * scale
	DrawMeshPart(self.Meshes.DomeCollar, origin, ang, Vector(domeX, 0, domeZ), zeroAng, sVec, matBody, 174, 178, 184, 255)
	DrawMeshPart(self.Meshes.DomeFluid,  origin, ang, Vector(domeX, 0, domeZ + 0.38 * scale), zeroAng, sVec, matUnlit, 62, 215, 52, 248)

	local bobZ      = math.sin(ct * 3.8) * 0.15 * scale
	local corePulse = 1.0 + math.sin(ct * 6.8) * 0.07 + firePulse * 0.25
	local coreLocal = Vector(domeX, 0, domeZ + 2.08 * scale + bobZ)

	DrawMeshPart(
		self.Meshes.PlasmaCore,
		origin, ang,
		coreLocal,
		Angle(ct * 42, ct * 64, 0),
		Vector(scale * corePulse * 0.95, scale * corePulse * 0.95, scale * corePulse * 1.12),
		matUnlit, 68, 238, 48, 255
	)

	for i = 1, 8 do
		local baseA  = (i / 8) * math.pi * 2 + ct * 0.9
		local pitchA = ((i % 3) - 1) * 0.65 + math.sin(ct * 2.7 + i) * 0.25
		local dir    = Vector(math.cos(baseA) * math.cos(pitchA), math.sin(baseA) * math.cos(pitchA), math.sin(pitchA) + 0.25):GetNormalized()
		for seg = 1, 3 do
			local dist   = (0.68 + seg * 0.26) * scale * corePulse
			local wiggle = Vector(math.sin(ct * 6 + i * 2 + seg) * 0.09 * scale, math.cos(ct * 6 + i * 2 + seg) * 0.09 * scale, math.sin(ct * 5 + seg) * 0.07 * scale)
			local segSz  = (1.10 - seg * 0.24) * scale
			DrawMeshPart(self.Meshes.PlasmaTendril, origin, ang, coreLocal + dir * dist + wiggle, zeroAng, Vector(segSz, segSz, segSz), matUnlit, 95 + seg * 20, 252, 65, 255)
		end
	end

	for s = 1, 3 do
		local zFrac = s / 4
		local stemPos = Vector(domeX + math.sin(ct * 7 + s * 1.5) * 0.10 * scale, math.cos(ct * 7 + s * 1.5) * 0.10 * scale, domeZ + (0.50 + zFrac * 1.35) * scale)
		DrawMeshPart(self.Meshes.PlasmaTendril, origin, ang, stemPos, zeroAng, Vector(scale * 0.80, scale * 0.80, scale * 1.30), matUnlit, 85, 245, 58, 245)
	end

	local coreWorld = LocalToWorld(coreLocal, zeroAng, origin, ang)
	render.SetMaterial(matGlowSprite)
	render.DrawSprite(coreWorld, 4.4 * scale * corePulse, 5.4 * scale * corePulse, Color(95, 255, 70, 155))

	for i = -1, 1 do
		local bulbWorld = LocalToWorld(Vector(9.45 * scale, i * 1.30 * scale, 2.20 * scale), zeroAng, origin, ang)
		render.DrawSprite(bulbWorld, (1.55 + firePulse * 2.0) * scale, (1.55 + firePulse * 2.0) * scale, Color(105, 255, 75, 195))
	end

	render.OverrideDepthEnable(true, false)
	DrawMeshPart(self.Meshes.GlassInner, origin, ang, Vector(domeX, 0, domeZ + 0.44 * scale), zeroAng, sVec, matUnlit, 155, 255, 142, 46)
	DrawMeshPart(self.Meshes.GlassDome,  origin, ang, Vector(domeX, 0, domeZ + 0.40 * scale), zeroAng, sVec, matBody, 215, 255, 212, 86)
	render.OverrideDepthEnable(false, false)

	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)
end
