-- ============================================================================
-- Custom 3D Renderer for Rick Prime's OMEGA DEVICE:
--  1) Sleek Rounded Sci-Fi Omega Control Tablet (with side grips & top Omega antenna)
--  2) Giant Rotating Omega Core + Fragmented Gyroscopic Containment Rings
--  3) Stationary Omega Chamber with Prisoner Stasis Capsule & Built-in 3D Monitor
-- ============================================================================

if SERVER then
	AddCSLuaFile()
	return
end

RICK_PORTAL = RICK_PORTAL or {}
RICK_PORTAL.OmegaRenderer = RICK_PORTAL.OmegaRenderer or {}

local Omega = RICK_PORTAL.OmegaRenderer
Omega.Meshes = {}

local matDarkMetal = CreateMaterial("RickOmega_Metal_v3", "VertexLitGeneric", {
	["$basetexture"]        = "models/debug/debugwhite",
	["$halflambert"]        = "1",
	["$phong"]              = "1",
	["$phongboost"]         = "1.35",
	["$phongexponent"]      = "32",
	["$phongfresnelranges"] = "[0.25 0.65 1]"
})

local matUnlit = CreateMaterial("RickOmega_Unlit_v3", "UnlitGeneric", {
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

local function BuildRoundedBox3D(lx, ly, lz, cornerR)
	local tris = {}
	local hx, hy, hz = lx * 0.5, ly * 0.5, lz * 0.5
	local ringSegs = 28
	local r = math.min(cornerR or 0.35, hy * 0.4, hz * 0.4)

	local function Pt(xVal, a)
		local ca, sa = math.cos(a), math.sin(a)
		local iy, iz = hy - r, hz - r
		local py = (ca >= 0 and iy or -iy) + ca * r
		local pz = (sa >= 0 and iz or -iz) + sa * r
		return Vector(xVal, py, pz), Vector(0, ca, sa):GetNormalized()
	end

	for i = 0, ringSegs - 1 do
		local a1 = (i / ringSegs) * math.pi * 2
		local a2 = ((i + 1) / ringSegs) * math.pi * 2
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

local function BuildCylinderZ(radius, height, segs, openEnds)
	local tris = {}
	segs = segs or 28
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

		AddSmoothQuad(tris, p1B, p2B, p2T, p1T, n1, n2, n2, n1)

		if not openEnds then
			tris[#tris + 1] = { pos = Vector(0, 0, hz),  normal = Vector(0, 0, 1),  u = 0.5, v = 0.5 }
			tris[#tris + 1] = { pos = p1T,               normal = Vector(0, 0, 1),  u = 0,   v = 0 }
			tris[#tris + 1] = { pos = p2T,               normal = Vector(0, 0, 1),  u = 1,   v = 0 }

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
	segs  = segs or 24
	rings = rings or 16

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

			AddSmoothQuad(tris, n11 * radius, n21 * radius, n22 * radius, n12 * radius, n11, n21, n22, n12)
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
		local steps = math.max(5, math.floor((degEnd - degStart) / 6))

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

			AddSmoothQuad(tris, pIn1T, pOut1T, pOut2T, pIn2T)
			AddSmoothQuad(tris, pIn2B, pOut2B, pOut1B, pIn1B)
			AddSmoothQuad(tris, pOut1B, pOut2B, pOut2T, pOut1T, Vector(c1,s1,0), Vector(c2,s2,0), Vector(c2,s2,0), Vector(c1,s1,0))
			AddSmoothQuad(tris, pIn2B,  pIn1B,  pIn1T,  pIn2T,  Vector(-c2,-s2,0), Vector(-c1,-s1,0), Vector(-c1,-s1,0), Vector(-c2,-s2,0))

			if s == 0 then AddSmoothQuad(tris, pIn1B, pOut1B, pOut1T, pIn1T) end
			if s == steps - 1 then AddSmoothQuad(tris, pOut2B, pIn2B, pIn2T, pOut2T) end
		end
	end

	local m = Mesh()
	m:BuildFromTriangles(tris)
	return m
end

function Omega:EnsureMeshes()
	if self.Meshes.Ready then return end

	self.Meshes.CoreSphere   = BuildSphereMesh(10.0, 24, 16)
	self.Meshes.OuterShell   = BuildSphereMesh(11.4, 22, 14)
	self.Meshes.NodeOrb      = BuildSphereMesh(1.3, 12, 8)

	self.Meshes.RingInner = BuildSegmentedArcRing(14.2, 2.2, 2.0, {
		{ 12, 118, true }, { 148, 242, false }, { 276, 344, true }
	})
	self.Meshes.RingMid = BuildSegmentedArcRing(18.0, 2.6, 2.4, {
		{ 0, 88, true }, { 112, 215, true }, { 245, 328, false }
	})
	self.Meshes.RingOuter = BuildSegmentedArcRing(22.2, 2.4, 1.9, {
		{ 25, 140, true }, { 175, 265, false }, { 292, 355, true }
	})

	-- Sleek Rounded Two-Handed Omega Control Tablet + Rubberized Side Grips!
	self.Meshes.TabletChassis = BuildRoundedBox3D(0.75, 11.8, 7.6, 0.55)
	self.Meshes.TabletGrip    = BuildRoundedBox3D(1.05, 1.15, 6.4, 0.35)

	-- Station Platform, Prisoner Stasis Capsule & Built-in Physical Control Monitor!
	self.Meshes.PlatformBase   = BuildCylinderZ(76, 8, 32, false)
	self.Meshes.CapsuleBase    = BuildCylinderZ(42, 6, 28, false)
	self.Meshes.CapsuleGlass   = BuildCylinderZ(39, 108, 28, true)
	self.Meshes.Pillar         = BuildRoundedBox3D(10, 10, 112, 1.5)
	self.Meshes.ConsoleStand   = BuildRoundedBox3D(8, 16, 48, 1.2)
	self.Meshes.MonitorHousing = BuildRoundedBox3D(5.5, 49, 35, 1.8)

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

-- Draws the sleek sci-fi Two-Handed Omega Tablet with glowing mini-core emitter on top!
function Omega:DrawOmegaTabletBody(origin, ang, scale, chargeLevel)
	self:EnsureMeshes()
	scale = scale or 1.0
	local sVec    = Vector(scale, scale, scale)
	local zeroAng = Angle(0, 0, 0)

	-- Main dark-titanium rounded tablet body
	self.DrawMesh(self.Meshes.TabletChassis, origin, ang, Vector(0, 0, 0), zeroAng, sVec, matDarkMetal, 42, 40, 58, 255)
	-- Left & Right ergonomic side bumper grips (where the hands hold it!)
	self.DrawMesh(self.Meshes.TabletGrip, origin, ang, Vector(-0.05 * scale,  5.65 * scale, 0), zeroAng, sVec, matDarkMetal, 64, 56, 88, 255)
	self.DrawMesh(self.Meshes.TabletGrip, origin, ang, Vector(-0.05 * scale, -5.65 * scale, 0), zeroAng, sVec, matDarkMetal, 64, 56, 88, 255)

	-- Miniature rotating Omega Core emitter perched right on top of the tablet bezel!
	local topEmitterWorld = LocalToWorld(Vector(0, 0, 4.95 * scale), zeroAng, origin, ang)
	self:DrawOmegaCore(topEmitterWorld, ang, 0.065 * scale, chargeLevel or 0, 0)
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

function Omega:DrawOmegaChamberStructure(origin, ang, chargeLevel, burstLevel, hasPrisoner)
	self:EnsureMeshes()
	local zeroAng  = Angle(0, 0, 0)
	local oneScale = Vector(1, 1, 1)

	self.DrawMesh(self.Meshes.PlatformBase, origin, ang, Vector(0, 0, 4), zeroAng, oneScale, matDarkMetal, 34, 32, 46, 255)
	self.DrawMesh(self.Meshes.CapsuleBase,  origin, ang, Vector(-10, 0, 10), zeroAng, oneScale, matDarkMetal, 54, 46, 76, 255)
	self.DrawMesh(self.Meshes.CapsuleBase,  origin, ang, Vector(-10, 0, 118), zeroAng, oneScale, matDarkMetal, 54, 46, 76, 255)

	self.DrawMesh(self.Meshes.Pillar, origin, ang, Vector(-10,  46, 64), zeroAng, oneScale, matDarkMetal, 42, 38, 58, 255)
	self.DrawMesh(self.Meshes.Pillar, origin, ang, Vector(-10, -46, 64), zeroAng, oneScale, matDarkMetal, 42, 38, 58, 255)

	self.DrawMesh(self.Meshes.ConsoleStand,   origin, ang, Vector(58, 0, 24), zeroAng, oneScale, matDarkMetal, 38, 36, 52, 255)
	self.DrawMesh(self.Meshes.MonitorHousing, origin, ang, Vector(62, 0, 52), Angle(-28, 0, 0), oneScale, matDarkMetal, 28, 28, 40, 255)

	local coreWorld = LocalToWorld(Vector(-10, 0, 178), zeroAng, origin, ang)
	self:DrawOmegaCore(coreWorld, ang, 2.35, chargeLevel, burstLevel)

	if chargeLevel > 0.02 or burstLevel > 0.02 then
		local capCenter = LocalToWorld(Vector(-10, 0, 62), zeroAng, origin, ang)
		render.SetMaterial(matLaser)
		local w = 18 * chargeLevel + 54 * burstLevel
		render.DrawBeam(coreWorld, capCenter, w,       0, 1, Color(75, 210, 255, 245))
		render.DrawBeam(coreWorld, capCenter, w * 0.5, 0, 1, Color(240, 252, 255, 255))
	end

	render.OverrideDepthEnable(true, false)
	local glassAlpha = hasPrisoner and (95 + math.sin(CurTime() * 7) * 20) or 52
	self.DrawMesh(self.Meshes.CapsuleGlass, origin, ang, Vector(-10, 0, 64), zeroAng, oneScale, matUnlit, 65, 210, 255, glassAlpha)
	render.OverrideDepthEnable(false, false)

	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)
end
