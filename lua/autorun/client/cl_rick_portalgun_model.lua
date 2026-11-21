-- ============================================================================
-- Custom 3D Model & Materials for Rick's Portal Gun (Exact Match to New Photo!)
-- Reference: b8f20707ee38dd3ec3a4a7f1b2adaa4f.png
--  * Large, chunky, clean light-gray wedge/boxy body (tapers slightly toward front)
--  * Rounded rear shoulder transitioning seamlessly into a teardrop/club pistol grip
--  * Deep dark front recessed cavity with 3 silver-ringed bright green emitter bulbs
--  * Tall prominent crystal-green glass capsule dome on a stepped silver collar
--  * Organic spiky green quantum plasma core with wavy tendrils + liquid puddle
--  * Recessed top & rear glowing red LED mini-screens displaying ALL live Portal Gun telemetry!
--  * Black notched thumb trigger lever on the rear-top curve
-- ============================================================================

if SERVER then
	AddCSLuaFile()
	return
end

RICK_PORTAL = RICK_PORTAL or {}
RICK_PORTAL.GunRenderer = RICK_PORTAL.GunRenderer or {}

local Renderer = RICK_PORTAL.GunRenderer

local matBody = CreateMaterial("RickPG_BodyMat_v3", "VertexLitGeneric", {
	["$basetexture"]        = "models/debug/debugwhite",
	["$halflambert"]        = "1",
	["$phong"]              = "1",
	["$phongboost"]         = "0.75",
	["$phongexponent"]      = "22",
	["$phongfresnelranges"] = "[0.15 0.55 1]"
})

local matUnlit = CreateMaterial("RickPG_UnlitMat_v3", "UnlitGeneric", {
	["$basetexture"] = "models/debug/debugwhite",
	["$vertexcolor"] = "1",
	["$vertexalpha"] = "1",
	["$translucent"] = "1",
	["$nocull"]      = "1"
})

local matGlowSprite = Material("sprites/light_glow02_add")

-- Reset meshes on reload so live updates work cleanly
Renderer.Meshes = {}

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

-- Builds the exact tapered rectangular chassis with rounded rear shoulder from the photo!
local function BuildPortalGunBody()
	local tris = {}

	-- X from -3.2 (rear) to +7.8 (front muzzle), total length = 11.0 units
	-- Rear width = 5.4 (hy=2.70), Front width = 4.9 (hy=2.45)
	-- Rear height = 2.45 (hz=1.225), Front height = 2.05 (hz=1.025)
	local xRear, xMid, xFront = -2.4, 2.5, 7.8
	local hyR, hzR = 2.72, 1.22
	local hyF, hzF = 2.46, 1.04
	local bev = 0.18

	-- Main tapered body section (xRear .. xFront)
	local pRT_L = Vector(xRear,  hyR - bev,  hzR)
	local pRT_R = Vector(xRear, -hyR + bev,  hzR)
	local pFT_L = Vector(xFront, hyF - bev,  hzF)
	local pFT_R = Vector(xFront,-hyF + bev,  hzF)

	local pRB_L = Vector(xRear,  hyR - bev, -hzR)
	local pRB_R = Vector(xRear, -hyR + bev, -hzR)
	local pFB_L = Vector(xFront, hyF - bev, -hzF)
	local pFB_R = Vector(xFront,-hyF + bev, -hzF)

	local pRS_LT = Vector(xRear,  hyR,  hzR - bev)
	local pRS_LB = Vector(xRear,  hyR, -hzR + bev)
	local pFS_LT = Vector(xFront, hyF,  hzF - bev)
	local pFS_LB = Vector(xFront, hyF, -hzF + bev)

	local pRS_RT = Vector(xRear, -hyR,  hzR - bev)
	local pRS_RB = Vector(xRear, -hyR, -hzR + bev)
	local pFS_RT = Vector(xFront,-hyF,  hzF - bev)
	local pFS_RB = Vector(xFront,-hyF, -hzF + bev)

	-- Top, Bottom, Left, Right faces
	AddQuad(tris, pRT_R, pFT_R, pFT_L, pRT_L, Vector(0.02, 0, 1))
	AddQuad(tris, pRB_L, pFB_L, pFB_R, pRB_R, Vector(0.02, 0, -1))
	AddQuad(tris, pFS_LB, pRS_LB, pRS_LT, pFS_LT, Vector(0.02, 1, 0))
	AddQuad(tris, pRS_RB, pFS_RB, pFS_RT, pRS_RT, Vector(0.02, -1, 0))

	-- 4 Long Chamfer Bevels
	AddQuad(tris, pRT_L, pFT_L, pFS_LT, pRS_LT, Vector(0, 0.707, 0.707))
	AddQuad(tris, pFT_R, pRT_R, pRS_RT, pFS_RT, Vector(0, -0.707, 0.707))
	AddQuad(tris, pFS_LB, pRS_LB, pRB_L, pFB_L, Vector(0, 0.707, -0.707))
	AddQuad(tris, pRS_RB, pFS_RB, pFB_R, pRB_R, Vector(0, -0.707, -0.707))

	-- Front frame border around recessed dark emitter cavity
	local cavY, cavZ = 2.12, 0.76
	-- Top lip
	AddQuad(tris, Vector(xFront, -hyF + bev, cavZ), Vector(xFront, hyF - bev, cavZ), pFT_L, pFT_R, Vector(1, 0, 0))
	-- Bottom lip
	AddQuad(tris, pFB_R, pFB_L, Vector(xFront, hyF - bev, -cavZ), Vector(xFront, -hyF + bev, -cavZ), Vector(1, 0, 0))
	-- Left lip
	AddQuad(tris, Vector(xFront, cavY, -hzF + bev), pFS_LB, pFS_LT, Vector(xFront, cavY, hzF - bev), Vector(1, 0, 0))
	-- Right lip
	AddQuad(tris, pFS_RB, Vector(xFront, -cavY, -hzF + bev), Vector(xFront, -cavY, hzF - bev), pFS_RT, Vector(1, 0, 0))

	-- Smooth Rounded Rear Shoulder Drum (matches the curved back of the body in the photo!)
	local segs = 14
	for i = 0, segs - 1 do
		local a1 = -math.pi * 0.5 + (i / segs) * math.pi
		local a2 = -math.pi * 0.5 + ((i + 1) / segs) * math.pi
		local z1, x1 = math.sin(a1) * hzR, xRear - math.cos(a1) * 1.15
		local z2, x2 = math.sin(a2) * hzR, xRear - math.cos(a2) * 1.15
		local n1 = Vector(-math.cos(a1), 0, math.sin(a1)):GetNormalized()
		local n2 = Vector(-math.cos(a2), 0, math.sin(a2)):GetNormalized()
		local nAvg = ((n1 + n2) * 0.5):GetNormalized()

		AddQuad(tris,
			Vector(x1,  hyR - bev, z1),
			Vector(x2,  hyR - bev, z2),
			Vector(x2, -hyR + bev, z2),
			Vector(x1, -hyR + bev, z1),
			nAvg
		)
		-- Side caps for the rear drum
		tris[#tris + 1] = { pos = Vector(xRear, hyR - bev, 0), normal = Vector(0, 1, 0), u = 0.5, v = 0.5 }
		tris[#tris + 1] = { pos = Vector(x2, hyR - bev, z2),   normal = Vector(0, 1, 0), u = 1, v = 1 }
		tris[#tris + 1] = { pos = Vector(x1, hyR - bev, z1),   normal = Vector(0, 1, 0), u = 0, v = 1 }

		tris[#tris + 1] = { pos = Vector(xRear, -hyR + bev, 0), normal = Vector(0, -1, 0), u = 0.5, v = 0.5 }
		tris[#tris + 1] = { pos = Vector(x1, -hyR + bev, z1),   normal = Vector(0, -1, 0), u = 0, v = 1 }
		tris[#tris + 1] = { pos = Vector(x2, -hyR + bev, z2),   normal = Vector(0, -1, 0), u = 1, v = 1 }
	end

	local m = Mesh()
	m:BuildFromTriangles(tris)
	return m
end

-- Builds the exact Teardrop / Club-shaped Ergonomic Pistol Grip from the photo
-- Narrower neck at the top, swelling smoothly toward the rounded bulb at the bottom!
local function BuildTeardropGrip()
	local tris = {}
	local rings = 14
	local segs  = 18
	local length = 6.2

	local function Profile(t)
		-- t=0 is top neck (attached to rear housing), t=1 is bottom rounded tip
		-- Swept backward along -X as it goes down (-Z)
		local z = -t * length
		local x = -t * 2.35 -- ~21 deg backward rake matching photo!
		local rx, ry
		if t < 0.78 then
			local swell = math.sin((t / 0.78) * (math.pi * 0.62))
			rx = 0.76 + swell * 0.42
			ry = 0.68 + swell * 0.36
		else
			-- Smooth spherical bottom cap closure
			local capT = (t - 0.78) / 0.22
			local c = math.cos(capT * math.pi * 0.5)
			rx = (0.76 + math.sin(0.62 * math.pi) * 0.42) * c
			ry = (0.68 + math.sin(0.62 * math.pi) * 0.36) * c
		end
		return x, z, math.max(rx, 0.01), math.max(ry, 0.01)
	end

	for r = 0, rings - 1 do
		local t1 = r / rings
		local t2 = (r + 1) / rings
		local x1, z1, rx1, ry1 = Profile(t1)
		local x2, z2, rx2, ry2 = Profile(t2)

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
			tris[#tris + 1] = { pos = p22, normal = n2, u = 1, v = 1 }
			tris[#tris + 1] = { pos = p21, normal = n2, u = 1, v = 0 }

			tris[#tris + 1] = { pos = p11, normal = n1, u = 0, v = 0 }
			tris[#tris + 1] = { pos = p12, normal = n1, u = 0, v = 1 }
			tris[#tris + 1] = { pos = p22, normal = n2, u = 1, v = 1 }
		end
	end

	local m = Mesh()
	m:BuildFromTriangles(tris)
	return m
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

local function BuildCapsuleDome(radius, cylHeight, segs, rings, includeBottomCap, taperTop)
	local tris = {}
	segs = segs or 24
	rings = rings or 10
	local topR = radius * (taperTop or 1.0)

	for i = 0, segs - 1 do
		local a1 = (i / segs) * math.pi * 2
		local a2 = ((i + 1) / segs) * math.pi * 2
		local c1, s1 = math.cos(a1), math.sin(a1)
		local c2, s2 = math.cos(a2), math.sin(a2)
		local n1 = Vector(c1, s1, 0.05):GetNormalized()
		local n2 = Vector(c2, s2, 0.05):GetNormalized()
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

	self.Meshes.Body          = BuildPortalGunBody()
	self.Meshes.Grip          = BuildTeardropGrip()
	self.Meshes.FrontCavity   = BuildSimpleBox(0.95, 4.35, 1.56)
	self.Meshes.TopRecess     = BuildSimpleBox(2.85, 1.88, 0.22)
	self.Meshes.ThumbSwitch   = BuildSimpleBox(1.35, 0.72, 0.58)
	self.Meshes.DomeCollar    = BuildCapsuleDome(1.92, 0.54, 26, 5, false, 0.90)
	self.Meshes.DomeFluid     = BuildCapsuleDome(1.58, 0.22, 22, 4, false)
	self.Meshes.GlassDome     = BuildCapsuleDome(1.72, 3.15, 28, 12, false)
	self.Meshes.GlassInner    = BuildCapsuleDome(1.60, 2.98, 22, 9, false)
	self.Meshes.BulbBezel     = BuildCapsuleDome(0.62, 0.44, 18, 4, false)
	self.Meshes.BulbLens      = BuildSphere(0.50, 14, 7)
	self.Meshes.PlasmaCore    = BuildSphere(0.96, 18, 10)
	self.Meshes.PlasmaTendril = BuildSphere(0.26, 10, 5)

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

-- Renders the complete Rick & Morty Portal Gun with full live telemetry on its built-in mini-screen!
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

	local sVec    = Vector(scale, scale, scale)
	local zeroAng = Angle(0, 0, 0)

	-- Origin (0,0,0) is right at the upper grip palm saddle so the hand visibly wraps around the teardrop handle!
	-- 1. Teardrop Ergonomic Club Grip (matching new photo!)
	DrawMeshPart(
		self.Meshes.Grip,
		origin, ang,
		Vector(-1.45 * scale, 0, 1.35 * scale),
		zeroAng,
		sVec,
		matBody, 166, 169, 173, 255
	)

	-- 2. Tapered Sleek Light-Gray Body with Rounded Rear Shoulder
	DrawMeshPart(
		self.Meshes.Body,
		origin, ang,
		Vector(1.0 * scale, 0, 2.25 * scale),
		zeroAng,
		sVec,
		matBody, 198, 201, 205, 255
	)

	-- 3. Black Angled Notched Thumb Trigger Switch on Rear-Top Curve
	DrawMeshPart(
		self.Meshes.ThumbSwitch,
		origin, ang,
		Vector((-1.55 + dialKick * 0.12) * scale, 0, (3.48 - dialKick * 0.14) * scale),
		Angle(-26 - dialKick * 12, 0, 0),
		sVec,
		matBody, 38, 40, 44, 255
	)

	-- 4. Deep Dark Front Emitter Cavity
	DrawMeshPart(
		self.Meshes.FrontCavity,
		origin, ang,
		Vector(8.38 * scale, 0, 2.25 * scale),
		zeroAng,
		sVec,
		matBody, 44, 47, 50, 255
	)

	-- 5. Three Front Silver Cylindrical Bezels + Bright Lime-Green Emitter Bulbs
	local greenBoost = math.min(255, 232 + firePulse * 23)
	for i = -1, 1 do
		local yOff = i * 1.38 * scale
		DrawMeshPart(
			self.Meshes.BulbBezel,
			origin, ang,
			Vector(8.22 * scale, yOff, 2.25 * scale),
			Angle(90, 0, 0),
			sVec,
			matBody, 164, 168, 172, 255
		)
		DrawMeshPart(
			self.Meshes.BulbLens,
			origin, ang,
			Vector(8.62 * scale, yOff, 2.25 * scale),
			zeroAng,
			Vector(scale * 0.68, scale, scale),
			matUnlit, 82, greenBoost, 58, 255
		)
	end

	-- 6. Recessed Top Mini-Screen Bezel + Glowing Red/Telemetry Display!
	--    In first-person view, this angled/top recessed screen faces directly toward the player's eyes
	--    so ALL Portal Gun telemetry is clearly readable right on the gun itself (zero clutter HUD needed)!
	DrawMeshPart(
		self.Meshes.TopRecess,
		origin, ang,
		Vector(1.15 * scale, 0, 3.42 * scale),
		zeroAng,
		sVec,
		matBody, 68, 24, 24, 255
	)
	DrawMeshPart(
		self.Meshes.TopRecess,
		origin, ang,
		Vector(1.15 * scale, 0, 3.46 * scale),
		zeroAng,
		Vector(scale * 0.92, scale * 0.90, scale * 0.8),
		matUnlit, 195, 26, 24, 255
	)

	-- Live 3D2D Mini-Screen Telemetry right on the Portal Gun's red display!
	-- Shows: Portal A status | Portal B status | Link state | Target Surface & Distance | Fluid Charge
	local scrPos, scrAng = LocalToWorld(
		Vector(1.15 * scale, 0, 3.59 * scale),
		Angle(0, -90, 0),
		origin, ang
	)
	cam.Start3D2D(scrPos, scrAng, 0.0155 * scale)
		-- Crisp dark-red CRT scanline backing for contrast
		draw.RoundedBox(6, -54, -80, 108, 160, Color(42, 6, 8, 185))
		surface.SetDrawColor(255, 85, 75, 220)
		surface.DrawOutlinedRect(-54, -80, 108, 160, 2)

		-- Header
		local linkStr = (hasA and hasB) and "LINK: ACTIVE" or ((hasA or hasB) and "LINK: WAIT" or "PORTAL IDLE")
		local linkCol = (hasA and hasB) and Color(150, 255, 110, 255) or Color(255, 215, 195, 255)
		draw.SimpleText(linkStr, "DermaDefaultBold", 0, -64, linkCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		-- Divider line
		surface.SetDrawColor(255, 75, 65, 130)
		surface.DrawRect(-46, -50, 92, 2)

		-- Portal A & Portal B indicators
		local colOn  = Color(145, 255, 95, 255)
		local colOff = Color(255, 130, 120, 175)
		draw.SimpleText("A [ЛКМ]: " .. (hasA and "ON" or "OFF"), "DermaDefaultBold", 0, -32, hasA and colOn or colOff, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("B [ПКМ]: " .. (hasB and "ON" or "OFF"), "DermaDefaultBold", 0, -10, hasB and colOn or colOff, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		-- Target Surface & Range
		draw.SimpleText("AIM: " .. surfType, "DermaDefault", 0, 16, Color(255, 225, 210, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(string.format("RNG: %.1fm", distM), "DermaDefault", 0, 34, Color(255, 200, 185, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		-- Fluid tank bar at bottom of mini-screen
		local fluidFrac = math.Clamp(1.0 - firePulse * 0.35, 0.2, 1.0)
		surface.SetDrawColor(90, 18, 18, 220)
		surface.DrawRect(-44, 52, 88, 14)
		surface.SetDrawColor(125, 250, 80, 240)
		surface.DrawRect(-42, 54, math.floor(84 * fluidFrac), 10)
	cam.End3D2D()

	-- 7. Stepped Silver Collar Base for the Tall Glass Quantum Dome
	local domeX = 4.65 * scale
	local domeZ = 3.42 * scale
	DrawMeshPart(
		self.Meshes.DomeCollar,
		origin, ang,
		Vector(domeX, 0, domeZ),
		zeroAng,
		sVec,
		matBody, 174, 178, 184, 255
	)

	-- Rich green fluid puddle at bottom of the glass dome
	DrawMeshPart(
		self.Meshes.DomeFluid,
		origin, ang,
		Vector(domeX, 0, domeZ + 0.42 * scale),
		zeroAng,
		sVec,
		matUnlit, 62, 215, 52, 248
	)

	-- 8. Prominent Floating Green Spiky Plasma / Virus-like Core with Wavy Tendrils!
	--    Matches the exact spiky organic green mass suspended inside the tall dome in your new photo!
	local bobZ      = math.sin(ct * 3.8) * 0.16 * scale
	local corePulse = 1.0 + math.sin(ct * 6.8) * 0.07 + firePulse * 0.25
	local coreLocal = Vector(domeX, 0, domeZ + 2.25 * scale + bobZ)

	DrawMeshPart(
		self.Meshes.PlasmaCore,
		origin, ang,
		coreLocal,
		Angle(ct * 42, ct * 64, 0),
		Vector(scale * corePulse * 0.96, scale * corePulse * 0.96, scale * corePulse * 1.15),
		matUnlit, 68, 238, 48, 255
	)

	-- Multi-jointed wavy plasma tendrils reaching outward & upward like the photo!
	for i = 1, 8 do
		local baseA = (i / 8) * math.pi * 2 + ct * 0.9
		local pitchA = ((i % 3) - 1) * 0.65 + math.sin(ct * 2.7 + i) * 0.25
		local dir = Vector(math.cos(baseA) * math.cos(pitchA), math.sin(baseA) * math.cos(pitchA), math.sin(pitchA) + 0.25):GetNormalized()
		for seg = 1, 3 do
			local dist = (0.72 + seg * 0.28) * scale * corePulse
			local wiggle = Vector(
				math.sin(ct * 6 + i * 2 + seg) * 0.10 * scale,
				math.cos(ct * 6 + i * 2 + seg) * 0.10 * scale,
				math.sin(ct * 5 + seg) * 0.08 * scale
			)
			local segSize = (1.15 - seg * 0.25) * scale
			DrawMeshPart(
				self.Meshes.PlasmaTendril,
				origin, ang,
				coreLocal + dir * dist + wiggle,
				zeroAng,
				Vector(segSize, segSize, segSize),
				matUnlit, 95 + seg * 20, 252, 65, 255
			)
		end
	end

	-- Vertical twisting plasma stem connecting bottom puddle to the floating core
	for s = 1, 3 do
		local zFrac = s / 4
		local stemPos = Vector(
			domeX + math.sin(ct * 7 + s * 1.5) * 0.12 * scale,
			math.cos(ct * 7 + s * 1.5) * 0.12 * scale,
			domeZ + (0.55 + zFrac * 1.45) * scale
		)
		DrawMeshPart(
			self.Meshes.PlasmaTendril,
			origin, ang,
			stemPos,
			zeroAng,
			Vector(scale * 0.85, scale * 0.85, scale * 1.35),
			matUnlit, 85, 245, 58, 245
		)
	end

	-- Additive green glow inside dome & front emitters
	local coreWorld = LocalToWorld(coreLocal, zeroAng, origin, ang)
	render.SetMaterial(matGlowSprite)
	render.DrawSprite(coreWorld, 4.8 * scale * corePulse, 5.8 * scale * corePulse, Color(95, 255, 70, 155))

	for i = -1, 1 do
		local bulbWorld = LocalToWorld(Vector(8.85 * scale, i * 1.38 * scale, 2.25 * scale), zeroAng, origin, ang)
		render.DrawSprite(bulbWorld, (1.65 + firePulse * 2.1) * scale, (1.65 + firePulse * 2.1) * scale, Color(105, 255, 75, 195))
	end

	-- 9. Tall Tinted Lime-Green Translucent Glass Capsule Dome (exact match to photo!)
	render.OverrideDepthEnable(true, false)
	DrawMeshPart(
		self.Meshes.GlassInner,
		origin, ang,
		Vector(domeX, 0, domeZ + 0.48 * scale),
		zeroAng,
		sVec,
		matUnlit, 155, 255, 142, 46
	)
	DrawMeshPart(
		self.Meshes.GlassDome,
		origin, ang,
		Vector(domeX, 0, domeZ + 0.45 * scale),
		zeroAng,
		sVec,
		matBody, 215, 255, 212, 88
	)
	render.OverrideDepthEnable(false, false)

	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)
end
