-- Clean, smooth clientside model for Rick's flying saucer.
-- A transparent canopy keeps the actual seated player visible.

if SERVER then
	AddCSLuaFile()
	return
end

RICK_PORTAL = RICK_PORTAL or {}
RICK_PORTAL.SaucerRenderer = RICK_PORTAL.SaucerRenderer or {}

local Renderer = RICK_PORTAL.SaucerRenderer
Renderer.Meshes = Renderer.Meshes or {}

local matHull = CreateMaterial("RickSaucer_Hull_v2", "VertexLitGeneric", {
	["$basetexture"]        = "models/debug/debugwhite",
	["$model"]              = "1",
	["$vertexcolor"]        = "1",
	["$halflambert"]        = "1",
	["$phong"]              = "1",
	["$phongboost"]         = "1.1",
	["$phongexponent"]      = "38",
	["$phongfresnelranges"] = "[0.18 0.5 1]",
	["$nocull"]             = "1"
})

local matDarkMetal = CreateMaterial("RickSaucer_DarkMetal_v2", "VertexLitGeneric", {
	["$basetexture"]  = "models/debug/debugwhite",
	["$model"]        = "1",
	["$vertexcolor"]  = "1",
	["$halflambert"]  = "1",
	["$phong"]        = "1",
	["$phongboost"]   = "0.85",
	["$phongexponent"] = "28",
	["$nocull"]       = "1"
})

local matGlass = CreateMaterial("RickSaucer_Glass_v2", "VertexLitGeneric", {
	["$basetexture"]  = "models/debug/debugwhite",
	["$model"]        = "1",
	["$vertexcolor"]  = "1",
	["$vertexalpha"]  = "1",
	["$translucent"]  = "1",
	["$halflambert"]  = "1",
	["$phong"]        = "1",
	["$phongboost"]   = "0.4",
	["$phongexponent"] = "52",
	["$nocull"]       = "1"
})

local matGlow = Material("sprites/light_glow02_add")
local matBeam = Material("Effects/laser1")
local zeroAng = Angle(0, 0, 0)

local function AddTriangle(tris, p1, p2, p3, n1, n2, n3)
	tris[#tris + 1] = { pos = p1, normal = n1, u = 0, v = 0 }
	tris[#tris + 1] = { pos = p2, normal = n2, u = 1, v = 0 }
	tris[#tris + 1] = { pos = p3, normal = n3, u = 0.5, v = 1 }
end

local function AddQuad(tris, p1, p2, p3, p4, n1, n2, n3, n4)
	tris[#tris + 1] = { pos = p1, normal = n1, u = 0, v = 0 }
	tris[#tris + 1] = { pos = p2, normal = n2, u = 1, v = 0 }
	tris[#tris + 1] = { pos = p3, normal = n3, u = 1, v = 1 }
	tris[#tris + 1] = { pos = p1, normal = n1, u = 0, v = 0 }
	tris[#tris + 1] = { pos = p3, normal = n3, u = 1, v = 1 }
	tris[#tris + 1] = { pos = p4, normal = n4, u = 0, v = 1 }
end

local function BuildEllipsoid(radiusX, radiusY, radiusZ, segments, rings)
	local tris = {}
	segments = segments or 48
	rings = rings or 20

	local function Point(latitude, theta)
		local c = math.cos(latitude)
		return Vector(radiusX * c * math.cos(theta), radiusY * c * math.sin(theta), radiusZ * math.sin(latitude))
	end

	local function Normal(latitude, theta)
		local p = Point(latitude, theta)
		return Vector(p.x / (radiusX * radiusX), p.y / (radiusY * radiusY), p.z / (radiusZ * radiusZ)):GetNormalized()
	end

	for ring = 0, rings - 1 do
		local lat1 = -math.pi * 0.5 + (ring / rings) * math.pi
		local lat2 = -math.pi * 0.5 + ((ring + 1) / rings) * math.pi
		for i = 0, segments - 1 do
			local a1 = (i / segments) * math.pi * 2
			local a2 = ((i + 1) / segments) * math.pi * 2
			local p11, p12 = Point(lat1, a1), Point(lat1, a2)
			local p21, p22 = Point(lat2, a1), Point(lat2, a2)
			local n11, n12 = Normal(lat1, a1), Normal(lat1, a2)
			local n21, n22 = Normal(lat2, a1), Normal(lat2, a2)

			if ring == 0 then
				AddTriangle(tris, Vector(0, 0, -radiusZ), p22, p21, Vector(0, 0, -1), n22, n21)
			elseif ring == rings - 1 then
				AddTriangle(tris, p11, p12, Vector(0, 0, radiusZ), n11, n12, Vector(0, 0, 1))
			else
				AddQuad(tris, p11, p12, p22, p21, n11, n12, n22, n21)
			end
		end
	end

	local model = Mesh()
	model:BuildFromTriangles(tris)
	return model
end

local function BuildHemisphere(radiusX, radiusY, height, segments, rings)
	local tris = {}
	segments = segments or 56
	rings = rings or 22

	local function Point(phi, theta)
		local c = math.cos(phi)
		return Vector(radiusX * c * math.cos(theta), radiusY * c * math.sin(theta), height * math.sin(phi))
	end

	local function Normal(phi, theta)
		local p = Point(phi, theta)
		return Vector(p.x / (radiusX * radiusX), p.y / (radiusY * radiusY), p.z / (height * height)):GetNormalized()
	end

	for ring = 0, rings - 1 do
		local phi1 = (ring / rings) * (math.pi * 0.5)
		local phi2 = ((ring + 1) / rings) * (math.pi * 0.5)
		for i = 0, segments - 1 do
			local a1 = (i / segments) * math.pi * 2
			local a2 = ((i + 1) / segments) * math.pi * 2
			local p11, p12 = Point(phi1, a1), Point(phi1, a2)
			local p21, p22 = Point(phi2, a1), Point(phi2, a2)
			local n11, n12 = Normal(phi1, a1), Normal(phi1, a2)
			local n21, n22 = Normal(phi2, a1), Normal(phi2, a2)

			if ring == rings - 1 then
				AddTriangle(tris, p11, p12, Vector(0, 0, height), n11, n12, Vector(0, 0, 1))
			else
				AddQuad(tris, p11, p12, p22, p21, n11, n12, n22, n21)
			end
		end
	end

	local model = Mesh()
	model:BuildFromTriangles(tris)
	return model
end

local function BuildTorus(majorRadius, tubeRadius, tubeHeight, majorSegments, tubeSegments)
	local tris = {}
	majorSegments = majorSegments or 64
	tubeSegments = tubeSegments or 14

	local function Point(majorAngle, tubeAngle)
		local ring = majorRadius + math.cos(tubeAngle) * tubeRadius
		return Vector(math.cos(majorAngle) * ring, math.sin(majorAngle) * ring, math.sin(tubeAngle) * tubeHeight)
	end

	local function Normal(majorAngle, tubeAngle)
		return Vector(
			math.cos(majorAngle) * math.cos(tubeAngle),
			math.sin(majorAngle) * math.cos(tubeAngle),
			math.sin(tubeAngle)
		):GetNormalized()
	end

	for i = 0, majorSegments - 1 do
		local u1 = (i / majorSegments) * math.pi * 2
		local u2 = ((i + 1) / majorSegments) * math.pi * 2
		for j = 0, tubeSegments - 1 do
			local v1 = (j / tubeSegments) * math.pi * 2
			local v2 = ((j + 1) / tubeSegments) * math.pi * 2
			AddQuad(
				tris,
				Point(u1, v1), Point(u2, v1), Point(u2, v2), Point(u1, v2),
				Normal(u1, v1), Normal(u2, v1), Normal(u2, v2), Normal(u1, v2)
			)
		end
	end

	local model = Mesh()
	model:BuildFromTriangles(tris)
	return model
end

function Renderer:EnsureMeshes()
	if self.Meshes.Ready then return end

	-- Smooth, shallow metal saucer with a domed cockpit, rather than a stepped
	-- low-poly shell. All dimensions are local Source units; +X is the nose.
	self.Meshes.MainHull      = BuildEllipsoid(101, 91, 17.5, 64, 24)
	self.Meshes.BottomHull    = BuildEllipsoid(82, 74, 12, 64, 22)
	self.Meshes.WingPanel     = BuildEllipsoid(29, 12, 3.3, 32, 14)
	self.Meshes.SeatCushion   = BuildEllipsoid(16, 18, 4, 28, 14)
	self.Meshes.SeatBack      = BuildEllipsoid(6, 17, 17, 24, 14)
	self.Meshes.Dashboard     = BuildEllipsoid(13, 22, 4.5, 28, 14)
	self.Meshes.EngineCore    = BuildEllipsoid(27, 27, 5.5, 32, 16)
	self.Meshes.ThrusterPod   = BuildEllipsoid(11, 10, 4.5, 24, 12)
	self.Meshes.OuterRim      = BuildTorus(96, 3.1, 2.6, 72, 14)
	self.Meshes.LowerRim      = BuildTorus(76, 3.4, 2.8, 64, 14)
	self.Meshes.CanopyCollar  = BuildTorus(44, 2.8, 2.2, 64, 14)
	self.Meshes.EngineRing    = BuildTorus(36, 3.0, 2.4, 56, 14)
	self.Meshes.GlassDome     = BuildHemisphere(42.5, 41, 45, 56, 22)
	self.Meshes.Ready = true
end

local function DrawMeshPart(model, ent, localPos, scale, material, color, alpha)
	if not model then return end

	local worldPos, worldAng = LocalToWorld(localPos or vector_origin, zeroAng, ent:GetPos(), ent:GetAngles())
	local matrix = Matrix()
	matrix:SetTranslation(worldPos)
	matrix:SetAngles(worldAng)
	matrix:SetScale(scale or Vector(1, 1, 1))

	render.SetMaterial(material)
	render.SetColorModulation(color.r / 255, color.g / 255, color.b / 255)
	render.SetBlend((alpha == nil and color.a or alpha or 255) / 255)
	cam.PushModelMatrix(matrix)
	model:Draw()
	cam.PopModelMatrix()
	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)
end

local function WorldPos(ent, localPos)
	local pos = LocalToWorld(localPos, zeroAng, ent:GetPos(), ent:GetAngles())
	return pos
end

local function DrawSeams(ent)
	for i = 0, 9 do
		local theta = (i / 10) * math.pi * 2
		local function SurfacePoint(radius)
			local z = 17.5 * math.sqrt(math.max(0, 1 - radius * radius)) + 0.3
			return Vector(math.cos(theta) * radius * 101, math.sin(theta) * radius * 91, z)
		end
		render.DrawLine(WorldPos(ent, SurfacePoint(0.52)), WorldPos(ent, SurfacePoint(0.93)), Color(81, 91, 94, 190), false)
	end
end

local function DrawPilotInterior(ent)
	-- Rounded cushions and a compact console. Their upper halves sit above the
	-- hull so they read through the transparent canopy without cluttering it.
	DrawMeshPart(Renderer.Meshes.SeatCushion, ent, Vector(-13, 0, 19), Vector(1, 1, 1), matDarkMetal, Color(36, 48, 53), 255)
	DrawMeshPart(Renderer.Meshes.SeatBack, ent, Vector(-25, 0, 25), Vector(1, 1, 1), matDarkMetal, Color(48, 61, 65), 255)
	DrawMeshPart(Renderer.Meshes.Dashboard, ent, Vector(29, 0, 20), Vector(1, 1, 1), matDarkMetal, Color(40, 54, 58), 255)
	DrawMeshPart(Renderer.Meshes.Dashboard, ent, Vector(32, 0, 23), Vector(0.62, 0.76, 0.28), matHull, Color(68, 220, 193), 255)
end

function Renderer:DrawOpaque(ent)
	self:EnsureMeshes()

	DrawMeshPart(self.Meshes.MainHull, ent, vector_origin, Vector(1, 1, 1), matHull, Color(164, 171, 173), 255)
	DrawMeshPart(self.Meshes.BottomHull, ent, Vector(0, 0, -8.5), Vector(1, 1, 1), matDarkMetal, Color(69, 78, 81), 255)
	DrawMeshPart(self.Meshes.OuterRim, ent, Vector(0, 0, 0), Vector(1, 1, 1), matHull, Color(222, 215, 187), 255)
	DrawMeshPart(self.Meshes.LowerRim, ent, Vector(0, 0, -11), Vector(1, 1, 1), matDarkMetal, Color(57, 65, 69), 255)
	DrawMeshPart(self.Meshes.CanopyCollar, ent, Vector(0, 0, 15.2), Vector(1, 1, 1), matHull, Color(211, 215, 203), 255)
	DrawMeshPart(self.Meshes.EngineCore, ent, Vector(0, 0, -18.5), Vector(1, 1, 0.76), matDarkMetal, Color(42, 51, 55), 255)
	DrawMeshPart(self.Meshes.EngineRing, ent, Vector(0, 0, -15.5), Vector(1, 1, 1), matHull, Color(131, 151, 153), 255)

	-- A pair of tapered side fins echo the wing-like ends of Rick's ship.
	for side = -1, 1, 2 do
		DrawMeshPart(self.Meshes.WingPanel, ent, Vector(34, side * 65, 11.5), Vector(1.22, 1.05, 0.48), matHull, Color(180, 188, 187), 255)
	end

	-- Four compact lift pods on the underside.
	for i = 0, 3 do
		local angle = math.rad(45 + i * 90)
		local x, y = math.cos(angle) * 54, math.sin(angle) * 50
		DrawMeshPart(self.Meshes.ThrusterPod, ent, Vector(x, y, -11), Vector(1.15, 1.05, 0.7), matDarkMetal, Color(69, 78, 82), 255)
	end

	DrawPilotInterior(ent)
	DrawSeams(ent)
end

function Renderer:DrawTranslucent(ent)
	self:EnsureMeshes()

	local pilot = ent.GetPilot and ent:GetPilot() or NULL
	local seat = ent.GetPilotSeat and ent:GetPilotSeat() or NULL
	if not IsValid(seat) then
		seat = ent:GetNWEntity("RickSaucerSeat")
	end
	local active = IsValid(pilot) or (IsValid(seat) and IsValid(seat:GetDriver()))
	local now = CurTime()
	local pulse = 0.8 + math.sin(now * 4.8) * 0.12

	-- Blue-green glass, light enough for the player's head and shoulders to be
	-- clearly visible from outside and from the chase camera.
	DrawMeshPart(self.Meshes.GlassDome, ent, Vector(0, 0, 15.5), Vector(1, 1, 1), matGlass, Color(103, 220, 216), active and 58 or 46)

	-- Fine canopy ribs, positioned directly on the dome surface.
	for _, theta in ipairs({ math.rad(42), math.rad(138), math.rad(222), math.rad(318) }) do
		local previous
		for step = 0, 14 do
			local phi = (step / 14) * (math.pi * 0.5)
			local radius = math.cos(phi)
			local localPos = Vector(42.6 * radius * math.cos(theta), 41.1 * radius * math.sin(theta), 15.5 + 45 * math.sin(phi))
			local world = WorldPos(ent, localPos)
			if previous then
				render.DrawLine(previous, world, Color(187, 255, 238, 150), false)
			end
			previous = world
		end
	end

	-- Alternating warm landing lights and cyan status lamps around the rim.
	render.SetMaterial(matGlow)
	for i = 0, 11 do
		local theta = (i / 12) * math.pi * 2
		local localPos = Vector(math.cos(theta) * 91, math.sin(theta) * 82, 0)
		local world = WorldPos(ent, localPos)
		local cyan = i % 3 == 0
		local color = cyan and Color(81, 239, 223, 220) or Color(255, 194, 95, 220)
		local size = cyan and 11 or 9
		render.DrawSprite(world, size * pulse, size * pulse, color)
	end

	-- Soft ion lift beams become brighter while somebody is piloting.
	for i = 0, 3 do
		local angle = math.rad(45 + i * 90)
		local jet = Vector(math.cos(angle) * 54, math.sin(angle) * 50, -15)
		local startPos = WorldPos(ent, jet)
		local length = active and (34 + math.sin(now * 8 + i) * 5) or 12
		local endPos = WorldPos(ent, jet - Vector(0, 0, length))
		render.SetMaterial(matBeam)
		render.DrawBeam(startPos, endPos, active and 10 or 6, 0, 1, Color(82, 215, 255, active and 100 or 38))
		render.SetMaterial(matGlow)
		render.DrawSprite(startPos, (active and 18 or 12) * pulse, (active and 18 or 12) * pulse, Color(95, 235, 255, active and 190 or 100))
	end

	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)
end
