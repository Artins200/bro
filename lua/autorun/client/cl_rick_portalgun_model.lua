-- ============================================================================
-- Custom 3D Procedural Model & Materials for Rick's Portal Gun (from Snippet)
-- Renders exact geometry:
--  * Angled ergonomic round pistol grip
--  * Matte light-gray rectangular chassis with beveled edges
--  * Front recessed dark cavity with 3 glowing green emitter bulbs
--  * Top transparent glass dome on silver collar with bubbling green plasma core
--  * Top & rear recessed glowing red LED screen ("C-137") + black thumb wheel
-- ============================================================================

if SERVER then
	AddCSLuaFile()
	return
end

RICK_PORTAL = RICK_PORTAL or {}
RICK_PORTAL.GunRenderer = RICK_PORTAL.GunRenderer or {}

local Renderer = RICK_PORTAL.GunRenderer

local matBody       = CreateMaterial("RickPG_BodyMat_v1", "VertexLitGeneric", {
	["$basetexture"] = "models/debug/debugwhite",
	["$halflambert"] = "1",
	["$phong"]       = "1",
	["$phongboost"]  = "0.8",
	["$phongexponent"] = "18",
	["$phongfresnelranges"] = "[0.2 0.6 1]"
})

local matUnlit      = CreateMaterial("RickPG_UnlitMat_v1", "UnlitGeneric", {
	["$basetexture"] = "models/debug/debugwhite",
	["$vertexcolor"] = "1",
	["$vertexalpha"] = "1",
	["$translucent"] = "1",
	["$nocull"]      = "1"
})

local matGlowSprite = Material("sprites/light_glow02_add")
local matBlobSprite = Material("rick_portal/liquid_blob.png", "smooth mips")
local matBeam       = Material("Effects/laser1")

-- Cached IMesh objects so rendering is zero-allocation and 300+ FPS friendly
Renderer.Meshes = Renderer.Meshes or {}

local function AddQuad(tris, p1, p2, p3, p4, n, u1, v1, u2, v2)
	u1, v1, u2, v2 = u1 or 0, v1 or 0, u2 or 1, v2 or 1
	tris[#tris + 1] = { pos = p1, normal = n, u = u1, v = v1 }
	tris[#tris + 1] = { pos = p2, normal = n, u = u2, v = v1 }
	tris[#tris + 1] = { pos = p3, normal = n, u = u2, v = v2 }

	tris[#tris + 1] = { pos = p1, normal = n, u = u1, v = v1 }
	tris[#tris + 1] = { pos = p3, normal = n, u = u2, v = v2 }
	tris[#tris + 1] = { pos = p4, normal = n, u = u1, v = v2 }
end

local function BuildChamferBox(lx, ly, lz, bevel)
	local tris = {}
	local hx, hy, hz = lx * 0.5, ly * 0.5, lz * 0.5
	local b = math.min(bevel or 0.15, hx * 0.35, hy * 0.35, hz * 0.35)
	local ix, iy, iz = hx - b, hy - b, hz - b

	-- 6 primary faces
	-- +X (Front)
	AddQuad(tris, Vector(hx, -iy, -iz), Vector(hx, iy, -iz), Vector(hx, iy, iz), Vector(hx, -iy, iz), Vector(1, 0, 0))
	-- -X (Back)
	AddQuad(tris, Vector(-hx, iy, -iz), Vector(-hx, -iy, -iz), Vector(-hx, -iy, iz), Vector(-hx, iy, iz), Vector(-1, 0, 0))
	-- +Y (Left)
	AddQuad(tris, Vector(ix, hy, -iz), Vector(-ix, hy, -iz), Vector(-ix, hy, iz), Vector(ix, hy, iz), Vector(0, 1, 0))
	-- -Y (Right)
	AddQuad(tris, Vector(-ix, -hy, -iz), Vector(ix, -hy, -iz), Vector(ix, -hy, iz), Vector(-ix, -hy, iz), Vector(0, -1, 0))
	-- +Z (Top)
	AddQuad(tris, Vector(-ix, -iy, hz), Vector(ix, -iy, hz), Vector(ix, iy, hz), Vector(-ix, iy, hz), Vector(0, 0, 1))
	-- -Z (Bottom)
	AddQuad(tris, Vector(-ix, iy, -hz), Vector(ix, iy, -hz), Vector(ix, -iy, -hz), Vector(-ix, -iy, -hz), Vector(0, 0, -1))

	-- Top/Bottom long bevels along X
	AddQuad(tris, Vector(-ix, iy, hz), Vector(ix, iy, hz), Vector(ix, hy, iz), Vector(-ix, hy, iz), Vector(0, 0.707, 0.707))
	AddQuad(tris, Vector(ix, -iy, hz), Vector(-ix, -iy, hz), Vector(-ix, -hy, iz), Vector(ix, -hy, iz), Vector(0, -0.707, 0.707))
	AddQuad(tris, Vector(ix, iy, -hz), Vector(-ix, iy, -hz), Vector(-ix, hy, -iz), Vector(ix, hy, -iz), Vector(0, 0.707, -0.707))
	AddQuad(tris, Vector(-ix, -iy, -hz), Vector(ix, -iy, -hz), Vector(ix, -hy, -iz), Vector(-ix, -hy, -iz), Vector(0, -0.707, -0.707))

	-- Front/Back horizontal bevels along Y
	AddQuad(tris, Vector(ix, -iy, hz), Vector(hx, -iy, iz), Vector(hx, iy, iz), Vector(ix, iy, hz), Vector(0.707, 0, 0.707))
	AddQuad(tris, Vector(hx, -iy, -iz), Vector(ix, -iy, -hz), Vector(ix, iy, -hz), Vector(hx, iy, -iz), Vector(0.707, 0, -0.707))
	AddQuad(tris, Vector(-hx, -iy, iz), Vector(-ix, -iy, hz), Vector(-ix, iy, hz), Vector(-hx, iy, iz), Vector(-0.707, 0, 0.707))
	AddQuad(tris, Vector(-ix, -iy, -hz), Vector(-hx, -iy, -iz), Vector(-hx, iy, -iz), Vector(-ix, iy, -hz), Vector(-0.707, 0, -0.707))

	-- Vertical corner bevels along Z
	AddQuad(tris, Vector(hx, iy, -iz), Vector(ix, hy, -iz), Vector(ix, hy, iz), Vector(hx, iy, iz), Vector(0.707, 0.707, 0))
	AddQuad(tris, Vector(ix, -hy, -iz), Vector(hx, -iy, -iz), Vector(hx, -iy, iz), Vector(ix, -hy, iz), Vector(0.707, -0.707, 0))
	AddQuad(tris, Vector(-ix, hy, -iz), Vector(-hx, iy, -iz), Vector(-hx, iy, iz), Vector(-ix, hy, iz), Vector(-0.707, 0.707, 0))
	AddQuad(tris, Vector(-hx, -iy, -iz), Vector(-ix, -hy, -iz), Vector(-ix, -hy, iz), Vector(-hx, -iy, iz), Vector(-0.707, -0.707, 0))

	local m = Mesh()
	m:BuildFromTriangles(tris)
	return m
end

local function BuildCapsuleDome(radius, cylHeight, segs, rings, includeBottomCap)
	local tris = {}
	segs = segs or 20
	rings = rings or 8

	-- Cylinder wall from z = 0 to z = cylHeight
	for i = 0, segs - 1 do
		local a1 = (i / segs) * math.pi * 2
		local a2 = ((i + 1) / segs) * math.pi * 2
		local c1, s1 = math.cos(a1), math.sin(a1)
		local c2, s2 = math.cos(a2), math.sin(a2)
		local n1 = Vector(c1, s1, 0)
		local n2 = Vector(c2, s2, 0)
		local p1 = Vector(c1 * radius, s1 * radius, 0)
		local p2 = Vector(c2 * radius, s2 * radius, 0)
		local p3 = Vector(c2 * radius, s2 * radius, cylHeight)
		local p4 = Vector(c1 * radius, s1 * radius, cylHeight)

		tris[#tris + 1] = { pos = p1, normal = n1, u = i / segs, v = 1 }
		tris[#tris + 1] = { pos = p2, normal = n2, u = (i + 1) / segs, v = 1 }
		tris[#tris + 1] = { pos = p3, normal = n2, u = (i + 1) / segs, v = 0.4 }

		tris[#tris + 1] = { pos = p1, normal = n1, u = i / segs, v = 1 }
		tris[#tris + 1] = { pos = p3, normal = n2, u = (i + 1) / segs, v = 0.4 }
		tris[#tris + 1] = { pos = p4, normal = n1, u = i / segs, v = 0.4 }
	end

	-- Top hemisphere cap from z = cylHeight
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

			local p11 = Vector(n11.x * radius, n11.y * radius, cylHeight + n11.z * radius)
			local p21 = Vector(n21.x * radius, n21.y * radius, cylHeight + n21.z * radius)
			local p22 = Vector(n22.x * radius, n22.y * radius, cylHeight + n22.z * radius)
			local p12 = Vector(n12.x * radius, n12.y * radius, cylHeight + n12.z * radius)

			tris[#tris + 1] = { pos = p11, normal = n11, u = 0, v = 0 }
			tris[#tris + 1] = { pos = p21, normal = n21, u = 1, v = 0 }
			tris[#tris + 1] = { pos = p22, normal = n22, u = 1, v = 1 }

			tris[#tris + 1] = { pos = p11, normal = n11, u = 0, v = 0 }
			tris[#tris + 1] = { pos = p22, normal = n22, u = 1, v = 1 }
			tris[#tris + 1] = { pos = p12, normal = n12, u = 0, v = 1 }
		end
	end

	-- Optional bottom hemisphere cap (for ergonomic pistol grip)
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

	-- Dimensions carefully proportioned to match the 8-view Rick & Morty Portal Gun reference sheet:
	-- X = Forward (+muzzle / -rear), Y = Left/Right, Z = Up/Down
	self.Meshes.Chassis     = BuildChamferBox(8.8, 4.5, 2.0, 0.24)
	self.Meshes.RearHousing = BuildChamferBox(2.2, 3.2, 2.25, 0.28)
	self.Meshes.FrontCavity = BuildChamferBox(0.7, 3.85, 1.32, 0.06)
	self.Meshes.TopWindow   = BuildChamferBox(2.35, 1.45, 0.16, 0.04)
	self.Meshes.RearScreen  = BuildChamferBox(0.18, 2.15, 1.22, 0.04)
	self.Meshes.ThumbWheel  = BuildCapsuleDome(0.52, 0.36, 16, 4, true)
	self.Meshes.DomeCollar  = BuildCapsuleDome(1.48, 0.42, 22, 4, false)
	self.Meshes.DomeFluid   = BuildCapsuleDome(1.22, 0.22, 20, 4, false)
	self.Meshes.GlassDome   = BuildCapsuleDome(1.36, 2.15, 24, 10, false)
	self.Meshes.GlassInner  = BuildCapsuleDome(1.25, 2.02, 20, 8, false)
	self.Meshes.Grip        = BuildCapsuleDome(0.76, 4.45, 18, 8, true)
	self.Meshes.BulbBezel   = BuildCapsuleDome(0.52, 0.32, 16, 4, false)
	self.Meshes.BulbLens    = BuildSphere(0.42, 14, 7)
	self.Meshes.PlasmaCore  = BuildSphere(0.68, 16, 8)
	self.Meshes.PlasmaTendril = BuildSphere(0.24, 10, 5)

	self.Meshes.Ready = true
end

local function DrawMeshPart(im, origin, ang, localPos, localAng, scaleVec, mat, r, g, b, a)
	local worldPos, worldAng = LocalToWorld(localPos, localAng, origin, ang)
	local mtx = Matrix()
	mtx:SetTranslation(worldPos)
	mtx:SetAngles(worldAng)
	if scaleVec then
		mtx:SetScale(scaleVec)
	end

	render.SetMaterial(mat)
	render.SetColorModulation(r / 255, g / 255, b / 255)
	render.SetBlend((a or 255) / 255)

	cam.PushModelMatrix(mtx)
	im:Draw()
	cam.PopModelMatrix()
end

-- Renders the complete high-detail Rick & Morty Portal Gun at (origin, ang) with uniform scale
function Renderer:DrawGun(origin, ang, scale, state)
	self:EnsureMeshes()

	scale = scale or 1.0
	state = state or {}
	local ct = CurTime()
	local firePulse = state.firePulse or 0
	local dimCode = state.dimCode or "C-137"

	local sVec = Vector(scale, scale, scale)
	local zeroAng = Angle(0, 0, 0)

	-- 1. Ergonomic Angled Pistol Grip (swept back ~20 degrees exactly like reference)
	--    Origin (0,0,0) is positioned right at the grip palm center so hand bones hold it naturally!
	DrawMeshPart(
		self.Meshes.Grip,
		origin, ang,
		Vector(-1.15 * scale, 0, -2.85 * scale),
		Angle(-20, 0, 0),
		Vector(scale * 1.08, scale * 0.92, scale),
		matBody, 164, 167, 171, 255
	)

	-- 2. Rear Rounded Display Housing (back view from snippet)
	DrawMeshPart(
		self.Meshes.RearHousing,
		origin, ang,
		Vector(-0.55 * scale, 0, 1.95 * scale),
		zeroAng,
		sVec,
		matBody, 172, 175, 179, 255
	)

	-- 3. Main Rectangular Sleek Matte-Gray Chassis
	DrawMeshPart(
		self.Meshes.Chassis,
		origin, ang,
		Vector(3.45 * scale, 0, 2.05 * scale),
		zeroAng,
		sVec,
		matBody, 186, 189, 194, 255
	)

	-- 4. Black Rotary Thumb-Wheel / Trigger Dial on top-rear
	DrawMeshPart(
		self.Meshes.ThumbWheel,
		origin, ang,
		Vector(-0.35 * scale, -0.18 * scale, 3.05 * scale),
		Angle(0, 0, 90),
		sVec,
		matBody, 34, 36, 40, 255
	)

	-- 5. Recessed Dark Front Emitter Cavity
	DrawMeshPart(
		self.Meshes.FrontCavity,
		origin, ang,
		Vector(7.62 * scale, 0, 2.05 * scale),
		zeroAng,
		sVec,
		matBody, 52, 55, 59, 255
	)

	-- 6. Three Front Green Emitter Bezels + Glowing Green Lenses
	local greenBoost = math.min(255, 225 + firePulse * 30)
	for i = -1, 1 do
		local yOff = i * 1.22 * scale
		DrawMeshPart(
			self.Meshes.BulbBezel,
			origin, ang,
			Vector(7.60 * scale, yOff, 2.05 * scale),
			Angle(90, 0, 0),
			sVec,
			matBody, 152, 156, 160, 255
		)
		DrawMeshPart(
			self.Meshes.BulbLens,
			origin, ang,
			Vector(7.92 * scale, yOff, 2.05 * scale),
			zeroAng,
			Vector(scale * 0.65, scale, scale),
			matUnlit, 88, greenBoost, 68, 255
		)
	end

	-- 7. Top Recessed Red LED Strip + Rear Red Display Panel (seen in BACK & ISOMETRIC views)
	DrawMeshPart(
		self.Meshes.TopWindow,
		origin, ang,
		Vector(1.05 * scale, 0, 3.02 * scale),
		zeroAng,
		sVec,
		matBody, 75, 25, 25, 255
	)
	DrawMeshPart(
		self.Meshes.TopWindow,
		origin, ang,
		Vector(1.05 * scale, 0, 3.05 * scale),
		zeroAng,
		Vector(scale * 0.92, scale * 0.86, scale * 0.8),
		matUnlit, 232, 42, 38, 255
	)

	-- Rear Red LED Frame + Glowing Screen
	DrawMeshPart(
		self.Meshes.RearScreen,
		origin, ang,
		Vector(-1.62 * scale, 0, 2.05 * scale),
		zeroAng,
		sVec,
		matBody, 68, 22, 22, 255
	)
	DrawMeshPart(
		self.Meshes.RearScreen,
		origin, ang,
		Vector(-1.66 * scale, 0, 2.05 * scale),
		zeroAng,
		Vector(scale * 0.9, scale * 0.90, scale * 0.88),
		matUnlit, 225, 34, 30, 255
	)

	-- Crisp 3D2D Dimension Readout ("C-137") on the rear red LED screen!
	local scrPos, scrAng = LocalToWorld(Vector(-1.77 * scale, 0, 2.05 * scale), Angle(0, -90, 90), origin, ang)
	cam.Start3D2D(scrPos, scrAng, 0.022 * scale)
		draw.SimpleText(dimCode, "DermaDefaultBold", 0, 0, Color(255, 210, 195, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	cam.End3D2D()

	-- 8. Silver Cylindrical Collar Base for the Quantum Fluid Chamber
	local domeBaseLocal = Vector(4.25 * scale, 0, 3.00 * scale)
	DrawMeshPart(
		self.Meshes.DomeCollar,
		origin, ang,
		domeBaseLocal,
		zeroAng,
		sVec,
		matBody, 166, 170, 176, 255
	)

	-- Glowing green liquid pool at bottom of the glass tube
	DrawMeshPart(
		self.Meshes.DomeFluid,
		origin, ang,
		Vector(4.25 * scale, 0, 3.32 * scale),
		zeroAng,
		sVec,
		matUnlit, 78, 225, 65, 245
	)

	-- 9. Animated Floating Green Portal Plasma / Virus-like Core inside the Glass Dome!
	--    Matches the spiky/bubbling green core suspended inside the glass dome in the reference image
	local bobZ = math.sin(ct * 4.2) * 0.14 * scale
	local corePulse = 1.0 + math.sin(ct * 7.5) * 0.08 + firePulse * 0.28
	local coreLocal = Vector(4.25 * scale, 0, (4.72 * scale) + bobZ)

	DrawMeshPart(
		self.Meshes.PlasmaCore,
		origin, ang,
		coreLocal,
		Angle(ct * 55, ct * 82, 0),
		Vector(scale * corePulse, scale * corePulse, scale * (corePulse * 1.12)),
		matUnlit, 95, 245, 72, 255
	)

	-- Orbiting/spiky green plasma tendrils & filaments inside the dome (like the 3D render!)
	for i = 1, 7 do
		local a = (i / 7) * math.pi * 2 + ct * (1.8 + (i % 2) * 0.7)
		local elev = math.sin(ct * 3.1 + i * 1.7) * 0.58
		local rad = (0.64 + math.sin(ct * 5.0 + i) * 0.12) * scale * corePulse
		local tLocal = coreLocal + Vector(math.cos(a) * rad, math.sin(a) * rad, elev * scale)
		DrawMeshPart(
			self.Meshes.PlasmaTendril,
			origin, ang,
			tLocal,
			zeroAng,
			Vector(scale * 0.9, scale * 0.9, scale * 1.25),
			matUnlit, 148, 255, 92, 250
		)
	end

	-- Bottom energy stem connecting fluid pool to floating plasma core
	DrawMeshPart(
		self.Meshes.PlasmaTendril,
		origin, ang,
		Vector(4.25 * scale, 0, 3.92 * scale),
		zeroAng,
		Vector(scale * 0.55, scale * 0.55, scale * 2.4),
		matUnlit, 120, 250, 82, 230
	)

	-- Additive inner green glow inside chamber + 3 front bulbs
	local coreWorld = LocalToWorld(coreLocal, zeroAng, origin, ang)
	render.SetMaterial(matGlowSprite)
	render.DrawSprite(coreWorld, 3.8 * scale * corePulse, 4.4 * scale * corePulse, Color(110, 255, 80, 175))

	for i = -1, 1 do
		local bulbWorld = LocalToWorld(Vector(8.05 * scale, i * 1.22 * scale, 2.05 * scale), zeroAng, origin, ang)
		render.DrawSprite(bulbWorld, (1.45 + firePulse * 1.8) * scale, (1.45 + firePulse * 1.8) * scale, Color(115, 255, 85, 190))
	end

	-- 10. Translucent Tinted Glass Capsule Dome (drawn last for proper alpha blending)
	render.OverrideDepthEnable(true, false)
	DrawMeshPart(
		self.Meshes.GlassInner,
		origin, ang,
		Vector(4.25 * scale, 0, 3.38 * scale),
		zeroAng,
		sVec,
		matUnlit, 165, 255, 155, 38
	)
	DrawMeshPart(
		self.Meshes.GlassDome,
		origin, ang,
		Vector(4.25 * scale, 0, 3.35 * scale),
		zeroAng,
		sVec,
		matBody, 225, 255, 228, 78
	)
	render.OverrideDepthEnable(false, false)

	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)
end
