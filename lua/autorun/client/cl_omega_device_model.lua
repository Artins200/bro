-- ============================================================================
-- Custom 3D Renderer for Rick Prime's OMEGA DEVICE ("The Weapon Too Cool For A Name")
-- Reference: gvg7my5o86tf1.png
--  * Intense glowing cyan-blue crackling plasma energy core sphere
--  * Multiple segmented dark purple-gunmetal concentric gyroscopic containment arcs
--    with glowing crimson/cyan tech nodes
--  * Radial crackling blue-white lightning beams erupting outward in 360°
-- ============================================================================

if SERVER then
	AddCSLuaFile()
	return
end

RICK_PORTAL = RICK_PORTAL or {}
RICK_PORTAL.OmegaRenderer = RICK_PORTAL.OmegaRenderer or {}

local Omega = RICK_PORTAL.OmegaRenderer
Omega.Meshes = {}

local matDarkMetal = CreateMaterial("RickOmega_Metal_v1", "VertexLitGeneric", {
	["$basetexture"]        = "models/debug/debugwhite",
	["$halflambert"]        = "1",
	["$phong"]              = "1",
	["$phongboost"]         = "1.4",
	["$phongexponent"]      = "30",
	["$phongfresnelranges"] = "[0.2 0.6 1]"
})

local matUnlit = CreateMaterial("RickOmega_Unlit_v1", "UnlitGeneric", {
	["$basetexture"] = "models/debug/debugwhite",
	["$vertexcolor"] = "1",
	["$vertexalpha"] = "1",
	["$translucent"] = "1",
	["$nocull"]      = "1"
})

local matGlow  = Material("sprites/light_glow02_add")
local matLaser = Material("Effects/laser1")

local function AddQuad(tris, p1, p2, p3, p4, n)
	if not n then
		n = (p2 - p1):Cross(p4 - p1):GetNormalized()
	end
	tris[#tris + 1] = { pos = p1, normal = n, u = 0, v = 0 }
	tris[#tris + 1] = { pos = p2, normal = n, u = 1, v = 0 }
	tris[#tris + 1] = { pos = p3, normal = n, u = 1, v = 1 }

	tris[#tris + 1] = { pos = p1, normal = n, u = 0, v = 0 }
	tris[#tris + 1] = { pos = p3, normal = n, u = 1, v = 1 }
	tris[#tris + 1] = { pos = p4, normal = n, u = 0, v = 1 }
end

local function BuildSphereMesh(radius, segs, rings)
	local tris = {}
	segs  = segs or 20
	rings = rings or 14

	for r = 0, rings - 1 do
		local phi1 = -math.pi * 0.5 + (r / rings) * math.pi
		local phi2 = -math.pi * 0.5 + ((r + 1) / rings) * math.pi
		local cp1, sp1 = math.cos(phi1), math.sin(phi1)
		local cp2, sp2 = math.cos(phi2), math.sin(phi2)

		for i = 0, segs - 1 do
			local a1 = (i / segs) * math.pi * 2
			local a2 = ((i + 1) / segs) * math.pi * 2
			local n11 = Vector(math.cos(a1) * cp1, math.sin(a1) * cp1, sp1)
			local n21 = Vector(math.cos(a2) * cp1, math.sin(a2) * cp1, sp1)
			local n22 = Vector(math.cos(a2) * cp2, math.sin(a2) * cp2, sp2)
			local n12 = Vector(math.cos(a1) * cp2, math.sin(a1) * cp2, sp2)

			tris[#tris + 1] = { pos = n11 * radius, normal = n11, u = 0, v = 0 }
			tris[#tris + 1] = { pos = n21 * radius, normal = n21, u = 1, v = 0 }
			tris[#tris + 1] = { pos = n22 * radius, normal = n22, u = 1, v = 1 }

			tris[#tris + 1] = { pos = n11 * radius, normal = n11, u = 0, v = 0 }
			tris[#tris + 1] = { pos = n22 * radius, normal = n22, u = 1, v = 1 }
			tris[#tris + 1] = { pos = n12 * radius, normal = n12, u = 0, v = 1 }
		end
	end

	local m = Mesh()
	m:BuildFromTriangles(tris)
	return m
end

-- Builds a broken/segmented dark sci-fi containment ring arc (like the fragmented purple-steel rings in the reference!)
local function BuildSegmentedArcRing(radius, thickness, width, arcCoverageTable)
	local tris = {}
	local rIn  = radius - thickness * 0.5
	local rOut = radius + thickness * 0.5
	local hz   = width * 0.5

	for _, segRange in ipairs(arcCoverageTable) do
		local degStart, degEnd, extraFin = segRange[1], segRange[2], segRange[3]
		local steps = math.max(4, math.floor((degEnd - degStart) / 7))

		for s = 0, steps - 1 do
			local a1 = math.rad(degStart + (s / steps) * (degEnd - degStart))
			local a2 = math.rad(degStart + ((s + 1) / steps) * (degEnd - degStart))
			local c1, s1 = math.cos(a1), math.sin(a1)
			local c2, s2 = math.cos(a2), math.sin(a2)

			local curOut = rOut + ((extraFin and s == math.floor(steps * 0.5)) and thickness * 0.85 or 0)

			local pIn1T  = Vector(c1 * rIn,    s1 * rIn,     hz)
			local pIn2T  = Vector(c2 * rIn,    s2 * rIn,     hz)
			local pOut2T = Vector(c2 * curOut, s2 * curOut,  hz)
			local pOut1T = Vector(c1 * curOut, s1 * curOut,  hz)

			local pIn1B  = Vector(c1 * rIn,    s1 * rIn,    -hz)
			local pIn2B  = Vector(c2 * rIn,    s2 * rIn,    -hz)
			local pOut2B = Vector(c2 * curOut, s2 * curOut, -hz)
			local pOut1B = Vector(c1 * curOut, s1 * curOut, -hz)

			-- Top & Bottom faces
			AddQuad(tris, pIn1T, pOut1T, pOut2T, pIn2T, Vector(0, 0, 1))
			AddQuad(tris, pIn2B, pOut2B, pOut1B, pIn1B, Vector(0, 0, -1))
			-- Outer & Inner curved walls
			AddQuad(tris, pOut1B, pOut2B, pOut2T, pOut1T, Vector((c1+c2)*0.5, (s1+s2)*0.5, 0):GetNormalized())
			AddQuad(tris, pIn2B,  pIn1B,  pIn1T,  pIn2T,  Vector(-(c1+c2)*0.5, -(s1+s2)*0.5, 0):GetNormalized())

			-- End caps
			if s == 0 then
				AddQuad(tris, pIn1B, pOut1B, pOut1T, pIn1T)
			end
			if s == steps - 1 then
				AddQuad(tris, pOut2B, pIn2B, pIn2T, pOut2T)
			end
		end
	end

	local m = Mesh()
	m:BuildFromTriangles(tris)
	return m
end

function Omega:EnsureMeshes()
	if self.Meshes.Ready then return end

	self.Meshes.CoreSphere  = BuildSphereMesh(10.0, 22, 14)
	self.Meshes.OuterShell  = BuildSphereMesh(11.4, 20, 12)
	self.Meshes.NodeOrb     = BuildSphereMesh(1.3, 10, 6)

	-- 3 Fragmented Gyroscopic Dark-Purple/Gunmetal Containment Rings matching gvg7my5o86tf1.png!
	self.Meshes.RingInner = BuildSegmentedArcRing(14.2, 2.2, 2.0, {
		{ 12, 118, true },
		{ 148, 242, false },
		{ 276, 344, true }
	})

	self.Meshes.RingMid = BuildSegmentedArcRing(18.0, 2.6, 2.4, {
		{ 0, 88, true },
		{ 112, 215, true },
		{ 245, 328, false }
	})

	self.Meshes.RingOuter = BuildSegmentedArcRing(22.2, 2.4, 1.9, {
		{ 25, 140, true },
		{ 175, 265, false },
		{ 292, 355, true }
	})

	self.Meshes.Ready = true
end

local function DrawMesh(im, origin, ang, localPos, localAng, scaleVec, mat, r, g, b, a)
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

-- Renders the complete Omega Device at any scale (handheld projector scale ~0.28, giant world machine scale ~3.2!)
function Omega:DrawOmegaCore(origin, ang, scale, chargeLevel, burstLevel)
	self:EnsureMeshes()

	scale       = scale or 1.0
	chargeLevel = chargeLevel or 0 -- 0..1
	burstLevel  = burstLevel or 0  -- 0..1
	local ct    = CurTime()

	local speedMult = 1.0 + chargeLevel * 3.8 + burstLevel * 6.0
	local corePulse = 1.0 + math.sin(ct * 8.5) * 0.06 + chargeLevel * 0.18 + burstLevel * 0.45
	local sVec      = Vector(scale, scale, scale)
	local coreScale = Vector(scale * corePulse, scale * corePulse, scale * corePulse)
	local zeroVec   = Vector(0, 0, 0)
	local zeroAng   = Angle(0, 0, 0)

	-- 1. Bright White-Cyan Inner Singularity Core
	DrawMesh(self.Meshes.CoreSphere, origin, ang, zeroVec, Angle(ct * 35, ct * 52, 0), coreScale * 0.86, matUnlit, 220, 250, 255, 255)

	-- 2. Crackling Electric-Blue Energy Shell
	render.OverrideDepthEnable(true, false)
	DrawMesh(self.Meshes.OuterShell, origin, ang, zeroVec, Angle(-ct * 64, ct * 41, ct * 25), coreScale, matUnlit, 45, 195, 255, 145)
	render.OverrideDepthEnable(false, false)

	-- 3. Three Counter-Rotating Fragmented Dark-Purple/Indigo Containment Rings (from reference image!)
	local aInner = Angle(ct * 38 * speedMult, ct * 54 * speedMult, 24)
	local aMid   = Angle(-ct * 29 * speedMult, -ct * 42 * speedMult, -38)
	local aOuter = Angle(ct * 21 * speedMult, -ct * 31 * speedMult, 62)

	DrawMesh(self.Meshes.RingInner, origin, ang, zeroVec, aInner, sVec, matDarkMetal, 56, 44, 78, 255)
	DrawMesh(self.Meshes.RingMid,   origin, ang, zeroVec, aMid,   sVec, matDarkMetal, 46, 38, 68, 255)
	DrawMesh(self.Meshes.RingOuter, origin, ang, zeroVec, aOuter, sVec, matDarkMetal, 64, 58, 88, 255)

	-- Red & Cyan sensor indicator nodes on the containment rings (visible in reference!)
	for i = 1, 3 do
		local nodeA = math.rad(i * 120 + 45)
		local nLocal = Vector(math.cos(nodeA) * 18.2 * scale, math.sin(nodeA) * 18.2 * scale, 0)
		nLocal:Rotate(aMid)
		DrawMesh(self.Meshes.NodeOrb, origin, ang, nLocal, zeroAng, sVec, matUnlit, 245, 42, 58, 255)
	end

	-- 4. Intense Volumetric Cyan-White Core Glow
	render.SetMaterial(matGlow)
	local glowSz = (46 + chargeLevel * 28 + burstLevel * 65) * scale
	render.DrawSprite(origin, glowSz, glowSz, Color(55, 190, 255, 215))
	render.DrawSprite(origin, glowSz * 0.52, glowSz * 0.52, Color(235, 252, 255, 245))

	-- 5. Radial Crackling Blue-White Lightning Beams Erupting Outward (iconic feature in gvg7my5o86tf1.png!)
	local numBeams = 10 + math.floor(chargeLevel * 6)
	local beamLen  = (24 + chargeLevel * 18 + burstLevel * 55) * scale
	local beamWid  = (2.6 + chargeLevel * 2.2 + burstLevel * 4.5) * scale

	render.SetMaterial(matLaser)
	for i = 1, numBeams do
		local theta = (i / numBeams) * math.pi * 2 + ct * (1.2 + (i % 3) * 0.4)
		local phi   = math.sin(ct * 2.1 + i * 1.9) * 1.05
		local dir   = Vector(math.cos(theta) * math.cos(phi), math.sin(theta) * math.cos(phi), math.sin(phi)):GetNormalized()

		-- Multi-segment jagged electric bolt from core surface outward through the rings
		local p0 = origin + dir * (8.5 * scale)
		local jitter1 = Vector(math.sin(ct * 33 + i * 5), math.cos(ct * 29 + i * 3), math.sin(ct * 37 + i)) * (1.8 * scale)
		local jitter2 = Vector(math.cos(ct * 31 + i * 7), math.sin(ct * 27 + i * 4), math.cos(ct * 41 + i)) * (2.6 * scale)
		local p1 = origin + dir * (beamLen * 0.48) + jitter1
		local p2 = origin + dir * (beamLen * 0.82) + jitter2
		local p3 = origin + dir * beamLen

		render.DrawBeam(p0, p1, beamWid,       0, 1, Color(195, 242, 255, 245))
		render.DrawBeam(p1, p2, beamWid * 0.8, 0, 1, Color(85,  205, 255, 225))
		render.DrawBeam(p2, p3, beamWid * 0.4, 0, 1, Color(165, 235, 255, 165))
	end

	-- Web of surface plasma arcs dancing across the cyan sphere
	for k = 1, 6 do
		local a1 = ct * 9 + k * 2.1
		local a2 = a1 + 1.15
		local s1 = origin + Vector(math.cos(a1), math.sin(a1), math.sin(a1 * 1.7)):GetNormalized() * (10.6 * scale * corePulse)
		local s2 = origin + Vector(math.cos(a2), math.sin(a2), math.cos(a2 * 1.3)):GetNormalized() * (10.6 * scale * corePulse)
		render.DrawBeam(s1, s2, 1.8 * scale, 0, 1, Color(230, 252, 255, 230))
	end

	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)
end
