-- ============================================================================
-- Custom 3D Renderer for Rick Prime's OMEGA DEVICE + Containment Capsule +
-- Physical Built-In 3D Control Console Monitor!
-- ============================================================================

if SERVER then
	AddCSLuaFile()
	return
end

RICK_PORTAL = RICK_PORTAL or {}
RICK_PORTAL.OmegaRenderer = RICK_PORTAL.OmegaRenderer or {}

local Omega = RICK_PORTAL.OmegaRenderer
Omega.Meshes = {}

local matDarkMetal = CreateMaterial("RickOmega_Metal_v2", "VertexLitGeneric", {
	["$basetexture"]        = "models/debug/debugwhite",
	["$halflambert"]        = "1",
	["$phong"]              = "1",
	["$phongboost"]         = "1.2",
	["$phongexponent"]      = "28",
	["$phongfresnelranges"] = "[0.2 0.6 1]"
})

local matUnlit = CreateMaterial("RickOmega_Unlit_v2", "UnlitGeneric", {
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
		n = (p4 - p1):Cross(p2 - p1):GetNormalized()
	end
	tris[#tris + 1] = { pos = p1, normal = n, u = 0, v = 0 }
	tris[#tris + 1] = { pos = p2, normal = n, u = 1, v = 0 }
	tris[#tris + 1] = { pos = p3, normal = n, u = 1, v = 1 }

	tris[#tris + 1] = { pos = p1, normal = n, u = 0, v = 0 }
	tris[#tris + 1] = { pos = p3, normal = n, u = 1, v = 1 }
	tris[#tris + 1] = { pos = p4, normal = n, u = 0, v = 1 }
end

local function BuildSimpleBox(lx, ly, lz)
	local tris = {}
	local hx, hy, hz = lx * 0.5, ly * 0.5, lz * 0.5
	AddQuad(tris, Vector(hx,-hy,-hz), Vector(hx,hy,-hz), Vector(hx,hy,hz), Vector(hx,-hy,hz), Vector(1,0,0))
	AddQuad(tris, Vector(-hx,hy,-hz), Vector(-hx,-hy,-hz), Vector(-hx,-hy,hz), Vector(-hx,hy,hz), Vector(-1,0,0))
	AddQuad(tris, Vector(hx,hy,-hz), Vector(-hx,hy,-hz), Vector(-hx,hy,hz), Vector(hx,hy,hz), Vector(0,1,0))
	AddQuad(tris, Vector(-hx,-hy,-hz), Vector(hx,-hy,-hz), Vector(hx,-hy,hz), Vector(-hx,-hy,hz), Vector(0,-1,0))
	AddQuad(tris, Vector(-hx,-hy,hz), Vector(hx,-hy,hz), Vector(hx,hy,hz), Vector(-hx,hy,hz), Vector(0,0,1))
	AddQuad(tris, Vector(-hx,hy,-hz), Vector(hx,hy,-hz), Vector(hx,-hy,-hz), Vector(-hx,-hy,-hz), Vector(0,0,-1))
	local m = Mesh()
	m:BuildFromTriangles(tris)
	return m
end

local function BuildCylinderZ(radius, height, segs, openEnds)
	local tris = {}
	segs = segs or 24
	local hz = height * 0.5
	for i = 0, segs - 1 do
		local a1 = (i / segs) * math.pi * 2
		local a2 = ((i + 1) / segs) * math.pi * 2
		local c1, s1 = math.cos(a1), math.sin(a1)
		local c2, s2 = math.cos(a2), math.sin(a2)
		local n1 = Vector(c1, s1, 0)
		local n2 = Vector(c2, s2, 0)

		local p1B = Vector(c1 * radius, s1 * radius, -hz)
		local p2B = Vector(c2 * radius, s2 * radius, -hz)
		local p2T = Vector(c2 * radius, s2 * radius,  hz)
		local p1T = Vector(c1 * radius, s1 * radius,  hz)

		tris[#tris + 1] = { pos = p1B, normal = n1, u = 0, v = 1 }
		tris[#tris + 1] = { pos = p2B, normal = n2, u = 1, v = 1 }
		tris[#tris + 1] = { pos = p2T, normal = n2, u = 1, v = 0 }

		tris[#tris + 1] = { pos = p1B, normal = n1, u = 0, v = 1 }
		tris[#tris + 1] = { pos = p2T, normal = n2, u = 1, v = 0 }
		tris[#tris + 1] = { pos = p1T, normal = n1, u = 0, v = 0 }

		if not openEnds then
			tris[#tris + 1] = { pos = Vector(0, 0, hz), normal = Vector(0, 0, 1), u = 0.5, v = 0.5 }
			tris[#tris + 1] = { pos = p1T,              normal = Vector(0, 0, 1), u = 0,   v = 0 }
			tris[#tris + 1] = { pos = p2T,              normal = Vector(0, 0, 1), u = 1,   v = 0 }

			tris[#tris + 1] = { pos = Vector(0, 0, -hz), normal = Vector(0, 0, -1), u = 0.5, v = 0.5 }
			tris[#tris + 1] = { pos = p2B,               normal = Vector(0, 0, -1), u = 1,   v = 0 }
			tris[#tris + 1] = { pos = p1B,               normal = Vector(0, 0, -1), u = 0,   v = 0 }
		end
	end
	local m = Mesh()
	m:BuildFromTriangles(tris)
	return m
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

			AddQuad(tris, pIn1T, pOut1T, pOut2T, pIn2T, Vector(0, 0, 1))
			AddQuad(tris, pIn2B, pOut2B, pOut1B, pIn1B, Vector(0, 0, -1))
			AddQuad(tris, pOut1B, pOut2B, pOut2T, pOut1T, Vector((c1+c2)*0.5, (s1+s2)*0.5, 0):GetNormalized())
			AddQuad(tris, pIn2B,  pIn1B,  pIn1T,  pIn2T,  Vector(-(c1+c2)*0.5, -(s1+s2)*0.5, 0):GetNormalized())

			if s == 0 then AddQuad(tris, pIn1B, pOut1B, pOut1T, pIn1T) end
			if s == steps - 1 then AddQuad(tris, pOut2B, pIn2B, pIn2T, pOut2T) end
		end
	end

	local m = Mesh()
	m:BuildFromTriangles(tris)
	return m
end

function Omega:EnsureMeshes()
	if self.Meshes.Ready then return end

	self.Meshes.CoreSphere   = BuildSphereMesh(10.0, 22, 14)
	self.Meshes.OuterShell   = BuildSphereMesh(11.4, 20, 12)
	self.Meshes.NodeOrb      = BuildSphereMesh(1.3, 10, 6)

	self.Meshes.RingInner = BuildSegmentedArcRing(14.2, 2.2, 2.0, {
		{ 12, 118, true }, { 148, 242, false }, { 276, 344, true }
	})
	self.Meshes.RingMid = BuildSegmentedArcRing(18.0, 2.6, 2.4, {
		{ 0, 88, true }, { 112, 215, true }, { 245, 328, false }
	})
	self.Meshes.RingOuter = BuildSegmentedArcRing(22.2, 2.4, 1.9, {
		{ 25, 140, true }, { 175, 265, false }, { 292, 355, true }
	})

	-- Station Platform, Prisoner Stasis Capsule & Built-in Physical Control Monitor!
	self.Meshes.PlatformBase  = BuildCylinderZ(76, 8, 32, false)
	self.Meshes.CapsuleBase   = BuildCylinderZ(42, 6, 28, false)
	self.Meshes.CapsuleGlass  = BuildCylinderZ(39, 108, 28, true)
	self.Meshes.Pillar        = BuildSimpleBox(10, 10, 112)
	self.Meshes.ConsoleStand  = BuildSimpleBox(8, 16, 48)
	self.Meshes.MonitorHousing = BuildSimpleBox(5, 48, 34)

	self.Meshes.Ready = true
end

Omega.DrawMesh = function(im, origin, ang, localPos, localAng, scaleVec, mat, r, g, b, a)
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

function Omega:DrawOmegaCore(origin, ang, scale, chargeLevel, burstLevel)
	self:EnsureMeshes()

	scale       = scale or 1.0
	chargeLevel = chargeLevel or 0
	burstLevel  = burstLevel or 0
	local ct    = CurTime()

	local speedMult = 1.0 + chargeLevel * 3.8 + burstLevel * 6.0
	local corePulse = 1.0 + math.sin(ct * 8.5) * 0.06 + chargeLevel * 0.18 + burstLevel * 0.45
	local sVec      = Vector(scale, scale, scale)
	local coreScale = Vector(scale * corePulse, scale * corePulse, scale * corePulse)
	local zeroVec   = Vector(0, 0, 0)
	local zeroAng   = Angle(0, 0, 0)

	self.DrawMesh(self.Meshes.CoreSphere, origin, ang, zeroVec, Angle(ct * 35, ct * 52, 0), coreScale * 0.86, matUnlit, 220, 250, 255, 255)

	render.OverrideDepthEnable(true, false)
	self.DrawMesh(self.Meshes.OuterShell, origin, ang, zeroVec, Angle(-ct * 64, ct * 41, ct * 25), coreScale, matUnlit, 45, 195, 255, 145)
	render.OverrideDepthEnable(false, false)

	local aInner = Angle(ct * 38 * speedMult, ct * 54 * speedMult, 24)
	local aMid   = Angle(-ct * 29 * speedMult, -ct * 42 * speedMult, -38)
	local aOuter = Angle(ct * 21 * speedMult, -ct * 31 * speedMult, 62)

	self.DrawMesh(self.Meshes.RingInner, origin, ang, zeroVec, aInner, sVec, matDarkMetal, 56, 44, 78, 255)
	self.DrawMesh(self.Meshes.RingMid,   origin, ang, zeroVec, aMid,   sVec, matDarkMetal, 46, 38, 68, 255)
	self.DrawMesh(self.Meshes.RingOuter, origin, ang, zeroVec, aOuter, sVec, matDarkMetal, 64, 58, 88, 255)

	for i = 1, 3 do
		local nodeA = math.rad(i * 120 + 45)
		local nLocal = Vector(math.cos(nodeA) * 18.2 * scale, math.sin(nodeA) * 18.2 * scale, 0)
		nLocal:Rotate(aMid)
		self.DrawMesh(self.Meshes.NodeOrb, origin, ang, nLocal, zeroAng, sVec, matUnlit, 245, 42, 58, 255)
	end

	render.SetMaterial(matGlow)
	local glowSz = (46 + chargeLevel * 28 + burstLevel * 65) * scale
	render.DrawSprite(origin, glowSz, glowSz, Color(55, 190, 255, 215))
	render.DrawSprite(origin, glowSz * 0.52, glowSz * 0.52, Color(235, 252, 255, 245))

	local numBeams = 10 + math.floor(chargeLevel * 6)
	local beamLen  = (24 + chargeLevel * 18 + burstLevel * 55) * scale
	local beamWid  = (2.6 + chargeLevel * 2.2 + burstLevel * 4.5) * scale

	render.SetMaterial(matLaser)
	for i = 1, numBeams do
		local theta = (i / numBeams) * math.pi * 2 + ct * (1.2 + (i % 3) * 0.4)
		local phi   = math.sin(ct * 2.1 + i * 1.9) * 1.05
		local dir   = Vector(math.cos(theta) * math.cos(phi), math.sin(theta) * math.cos(phi), math.sin(phi)):GetNormalized()

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

	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)
end

-- Draws the full floor-standing Omega Device Chamber + Glass Containment Capsule + Built-in 3D Monitor Housing!
function Omega:DrawOmegaChamberStructure(origin, ang, chargeLevel, burstLevel, hasPrisoner)
	self:EnsureMeshes()
	local zeroAng = Angle(0, 0, 0)
	local oneScale = Vector(1, 1, 1)

	-- 1. Heavy Dark-Indigo Base Platform & Capsule Pedestal on ground
	self.DrawMesh(self.Meshes.PlatformBase, origin, ang, Vector(0, 0, 4), zeroAng, oneScale, matDarkMetal, 34, 32, 46, 255)
	self.DrawMesh(self.Meshes.CapsuleBase,  origin, ang, Vector(-10, 0, 10), zeroAng, oneScale, matDarkMetal, 54, 46, 76, 255)
	self.DrawMesh(self.Meshes.CapsuleBase,  origin, ang, Vector(-10, 0, 118), zeroAng, oneScale, matDarkMetal, 54, 46, 76, 255)

	-- 2. Two Structural Support Pylons flanking the capsule up to the overhead Omega Core
	self.DrawMesh(self.Meshes.Pillar, origin, ang, Vector(-10,  46, 64), zeroAng, oneScale, matDarkMetal, 42, 38, 58, 255)
	self.DrawMesh(self.Meshes.Pillar, origin, ang, Vector(-10, -46, 64), zeroAng, oneScale, matDarkMetal, 42, 38, 58, 255)

	-- 3. Physical Angled Control Pedestal & Wide Monitor Housing in front (+X = 64)
	self.DrawMesh(self.Meshes.ConsoleStand,   origin, ang, Vector(58, 0, 24), zeroAng, oneScale, matDarkMetal, 38, 36, 52, 255)
	self.DrawMesh(self.Meshes.MonitorHousing, origin, ang, Vector(62, 0, 52), Angle(-28, 0, 0), oneScale, matDarkMetal, 28, 28, 40, 255)

	-- 4. Overhead Giant Rotating Omega Core (suspended right above the prisoner stasis capsule at Z = 178!)
	local coreWorld = LocalToWorld(Vector(-10, 0, 178), zeroAng, origin, ang)
	self:DrawOmegaCore(coreWorld, ang, 2.35, chargeLevel, burstLevel)

	-- If firing/charging, blast a massive vertical blue Omega beam straight down into the prisoner capsule!
	if chargeLevel > 0.02 or burstLevel > 0.02 then
		local capCenter = LocalToWorld(Vector(-10, 0, 62), zeroAng, origin, ang)
		render.SetMaterial(matLaser)
		local w = 18 * chargeLevel + 54 * burstLevel
		render.DrawBeam(coreWorld, capCenter, w,       0, 1, Color(75, 210, 255, 245))
		render.DrawBeam(coreWorld, capCenter, w * 0.5, 0, 1, Color(240, 252, 255, 255))
	end

	-- 5. Translucent Cyan Forcefield Stasis Capsule Cylinder (drawn last so prisoner inside is clearly visible!)
	render.OverrideDepthEnable(true, false)
	local glassAlpha = hasPrisoner and (95 + math.sin(CurTime() * 7) * 20) or 52
	self.DrawMesh(self.Meshes.CapsuleGlass, origin, ang, Vector(-10, 0, 64), zeroAng, oneScale, matUnlit, 65, 210, 255, glassAlpha)
	render.OverrideDepthEnable(false, false)

	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)
end
