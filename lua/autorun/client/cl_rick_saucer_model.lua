-- Rick's Flying Saucer: a lightweight, procedural clientside model.
-- The glass canopy is deliberately translucent so the seated pilot remains visible.

if SERVER then
	AddCSLuaFile()
	return
end

RICK_PORTAL = RICK_PORTAL or {}
RICK_PORTAL.SaucerRenderer = RICK_PORTAL.SaucerRenderer or {}

local Renderer = RICK_PORTAL.SaucerRenderer
Renderer.Meshes = Renderer.Meshes or {}

local matHull = CreateMaterial("RickSaucer_Hull_v1", "VertexLitGeneric", {
	["$basetexture"]        = "models/debug/debugwhite",
	["$model"]              = "1",
	["$vertexcolor"]        = "1",
	["$halflambert"]        = "1",
	["$phong"]              = "1",
	["$phongboost"]         = "1.15",
	["$phongexponent"]      = "34",
	["$phongfresnelranges"] = "[0.2 0.55 1]",
	["$nocull"]             = "1"
})

local matDarkMetal = CreateMaterial("RickSaucer_DarkMetal_v1", "VertexLitGeneric", {
	["$basetexture"] = "models/debug/debugwhite",
	["$model"]       = "1",
	["$vertexcolor"] = "1",
	["$halflambert"] = "1",
	["$phong"]       = "1",
	["$phongboost"]  = "0.8",
	["$phongexponent"] = "24",
	["$nocull"]      = "1"
})

local matGlass = CreateMaterial("RickSaucer_Glass_v1", "VertexLitGeneric", {
	["$basetexture"] = "models/debug/debugwhite",
	["$model"]       = "1",
	["$vertexcolor"] = "1",
	["$vertexalpha"] = "1",
	["$translucent"] = "1",
	["$halflambert"] = "1",
	["$phong"]       = "1",
	["$phongboost"]  = "0.55",
	["$phongexponent"] = "48",
	["$nocull"]      = "1"
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

local function BuildSaucerHull()
	local tris = {}
	local segments = 64
	local profile = {
		{ 0.00, 17.0 },
		{ 0.26, 18.0 },
		{ 0.48, 17.0 },
		{ 0.68, 14.0 },
		{ 0.86,  8.5 },
		{ 0.96,  3.5 },
		{ 1.00,  0.0 },
		{ 0.95, -4.0 },
		{ 0.80, -9.0 },
		{ 0.57, -13.5 },
		{ 0.30, -16.5 },
		{ 0.00, -17.0 }
	}

	local function Point(radius, z, theta)
		return Vector(math.cos(theta) * radius * 100, math.sin(theta) * radius * 91, z)
	end

	local function Normal(profileIndex, theta)
		local radial, vertical
		if profileIndex <= 3 then
			radial, vertical = 0.32, 0.95
		elseif profileIndex <= 5 then
			radial, vertical = 0.78, 0.62
		elseif profileIndex == 6 or profileIndex == 7 then
			radial, vertical = 1.0, 0.0
		else
			radial, vertical = 0.78, -0.62
		end
		return Vector(math.cos(theta) * radial, math.sin(theta) * radial, vertical):GetNormalized()
	end

	for ring = 1, #profile - 1 do
		local r1, z1 = profile[ring][1], profile[ring][2]
		local r2, z2 = profile[ring + 1][1], profile[ring + 1][2]

		for i = 0, segments - 1 do
			local a1 = (i / segments) * math.pi * 2
			local a2 = ((i + 1) / segments) * math.pi * 2
			local n11 = Normal(ring, a1)
			local n12 = Normal(ring, a2)
			local n21 = Normal(ring + 1, a1)
			local n22 = Normal(ring + 1, a2)

			if r1 == 0 then
				local center = Vector(0, 0, z1)
				AddTriangle(tris, center, Point(r2, z2, a1), Point(r2, z2, a2), Vector(0, 0, 1), n21, n22)
			elseif r2 == 0 then
				local center = Vector(0, 0, z2)
				AddTriangle(tris, Point(r1, z1, a1), center, Point(r1, z1, a2), n11, Vector(0, 0, -1), n12)
			else
				AddQuad(
					tris,
					Point(r1, z1, a1), Point(r2, z2, a1),
					Point(r2, z2, a2), Point(r1, z1, a2),
					n11, n21, n22, n12
				)
			end
		end
	end

	local model = Mesh()
	model:BuildFromTriangles(tris)
	return model
end

local function BuildHemisphere(radiusX, radiusY, height, segments, rings)
	local tris = {}
	segments = segments or 48
	rings = rings or 18

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
				local apex = Vector(0, 0, height)
				AddTriangle(tris, p11, p12, apex, n11, n12, Vector(0, 0, 1))
			else
				AddQuad(tris, p11, p12, p22, p21, n11, n12, n22, n21)
			end
		end
	end

	local model = Mesh()
	model:BuildFromTriangles(tris)
	return model
end

local function BuildEllipsoid(radiusX, radiusY, radiusZ, segments, rings)
	local tris = {}
	segments = segments or 24
	rings = rings or 12

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
				local pole = Vector(0, 0, -radiusZ)
				AddTriangle(tris, pole, p22, p21, Vector(0, 0, -1), n22, n21)
			elseif ring == rings - 1 then
				local pole = Vector(0, 0, radiusZ)
				AddTriangle(tris, p11, p12, pole, n11, n12, Vector(0, 0, 1))
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
	tubeSegments = tubeSegments or 12

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

	self.Meshes.Hull          = BuildSaucerHull()
	self.Meshes.OuterRim      = BuildTorus(96, 3.3, 2.4, 72, 12)
	self.Meshes.LowerRim      = BuildTorus(75, 4.0, 3.1, 64, 12)
	self.Meshes.EngineRing    = BuildTorus(38, 3.2, 2.3, 56, 12)
	self.Meshes.CanopyCollar  = BuildTorus(45, 2.7, 2.4, 56, 12)
	self.Meshes.GlassDome     = BuildHemisphere(43, 41, 47, 48, 18)
	self.Meshes.EngineCore    = BuildEllipsoid(28, 28, 6, 28, 14)
	self.Meshes.ThrusterPod   = BuildEllipsoid(10, 10, 4.5, 20, 10)
	self.Meshes.Ready = true
end

local function DrawMeshPart(model, ent, localPos, localAng, scale, material, color, alpha)
	if not model then return end

	local worldPos, worldAng = LocalToWorld(localPos or vector_origin, localAng or zeroAng, ent:GetPos(), ent:GetAngles())
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

local function DrawLocalBox(ent, pos, ang, mins, maxs, color)
	local worldPos, worldAng = LocalToWorld(pos, ang or zeroAng, ent:GetPos(), ent:GetAngles())
	render.DrawBox(worldPos, worldAng, mins, maxs, color)
end

local function ToWorld(ent, localPos)
	return LocalToWorld(localPos, zeroAng, ent:GetPos(), ent:GetAngles())
end

local function DrawPanelSeams(ent)
	for i = 0, 11 do
		local theta = (i / 12) * math.pi * 2
		local startLocal = Vector(math.cos(theta) * 49, math.sin(theta) * 45, 16.2)
		local endLocal   = Vector(math.cos(theta) * 88, math.sin(theta) * 80, 7.1)
		local startPos = ToWorld(ent, startLocal)
		local endPos = ToWorld(ent, endLocal)
		render.DrawLine(startPos, endPos, Color(76, 86, 89, 210), false)
	end
end

function Renderer:DrawOpaque(ent)
	self:EnsureMeshes()

	DrawMeshPart(self.Meshes.Hull, ent, vector_origin, zeroAng, Vector(1, 1, 1), matHull, Color(157, 166, 170), 255)
	DrawMeshPart(self.Meshes.OuterRim, ent, Vector(0, 0, 1), zeroAng, Vector(1, 1, 1), matHull, Color(215, 216, 209), 255)
	DrawMeshPart(self.Meshes.LowerRim, ent, Vector(0, 0, -8), zeroAng, Vector(1, 1, 1), matDarkMetal, Color(61, 69, 72), 255)
	DrawMeshPart(self.Meshes.EngineCore, ent, Vector(0, 0, -13), zeroAng, Vector(1, 1, 0.75), matDarkMetal, Color(43, 53, 58), 255)
	DrawMeshPart(self.Meshes.EngineRing, ent, Vector(0, 0, -14), zeroAng, Vector(1, 1, 1), matHull, Color(127, 150, 154), 255)
	DrawMeshPart(self.Meshes.CanopyCollar, ent, Vector(0, 0, 15), zeroAng, Vector(1, 1, 1), matHull, Color(194, 203, 198), 255)

	-- Tiny, swept engine housings on the underside make the ship silhouette read
	-- clearly from below, while the centre remains open for the blue hover glow.
	for i = 0, 3 do
		local angle = math.rad(45 + i * 90)
		local x = math.cos(angle) * 55
		local y = math.sin(angle) * 51
		DrawMeshPart(self.Meshes.ThrusterPod, ent, Vector(x, y, -11), zeroAng, Vector(1.35, 1.15, 0.72), matDarkMetal, Color(72, 82, 86), 255)
	end

	-- Dashboard and pilot chair are inside the canopy; the real player occupies
	-- the hidden prisoner-pod seat at the same spot.
	DrawLocalBox(ent, Vector(-17, 0, 0), zeroAng, Vector(-12, -17, -10), Vector(13, 17, -5), Color(35, 47, 53))
	DrawLocalBox(ent, Vector(-25, 0, 8), zeroAng, Vector(-5, -14, -13), Vector(4, 14, 12), Color(47, 58, 62))
	DrawLocalBox(ent, Vector(27, 0, 5), zeroAng, Vector(-10, -18, -5), Vector(10, 18, 5), Color(48, 62, 66))
	DrawLocalBox(ent, Vector(30, 0, 11), Angle(0, 0, 0), Vector(-1, -14, -1), Vector(1, 14, 1), Color(66, 207, 189))

	DrawPanelSeams(ent)
end

function Renderer:DrawTranslucent(ent)
	self:EnsureMeshes()

	local seat = ent.GetPilotSeat and ent:GetPilotSeat() or nil
	if not IsValid(seat) then
		seat = ent:GetNWEntity("RickSaucerSeat")
	end
	local driver = IsValid(seat) and seat:GetDriver() or nil
	local active = IsValid(driver)
	local now = CurTime()
	local pulse = 0.78 + math.sin(now * 5.1) * 0.12

	-- Keep the dome see-through from every angle so the pilot's seated pose can
	-- be seen both by the driver and by everyone else on the server.
	DrawMeshPart(self.Meshes.GlassDome, ent, Vector(0, 0, 15), zeroAng, Vector(1, 1, 1), matGlass, Color(95, 213, 211), active and 70 or 57)

	-- Canopy glints / thin structural ribs.
	for _, theta in ipairs({ math.rad(35), math.rad(145), math.rad(215), math.rad(325) }) do
		local previous
		for step = 0, 12 do
			local phi = (step / 12) * (math.pi * 0.5)
			local radius = math.cos(phi)
			local localPos = Vector(43 * radius * math.cos(theta), 41 * radius * math.sin(theta), 15 + 47 * math.sin(phi))
			local worldPos = ToWorld(ent, localPos)
			if previous then
				render.DrawLine(previous, worldPos, Color(174, 248, 235, 145), false)
			end
			previous = worldPos
		end
	end

	-- Ring lights around the saucer: warm landing lamps plus a few cyan status LEDs.
	render.SetMaterial(matGlow)
	for i = 0, 11 do
		local theta = (i / 12) * math.pi * 2
		local localPos = Vector(math.cos(theta) * 88, math.sin(theta) * 80, -1 + math.sin(now * 3 + i) * 0.35)
		local worldPos = ToWorld(ent, localPos)
		local isCyan = (i % 3 == 0)
		local color = isCyan and Color(83, 238, 222, 220) or Color(255, 193, 96, 220)
		local size = isCyan and 12 or 10
		render.DrawSprite(worldPos, size * pulse, size * pulse, color)
	end

	-- Underbody ion glow and four softly pulsing lift beams.
	for i = 0, 3 do
		local angle = math.rad(45 + i * 90)
		local jet = Vector(math.cos(angle) * 55, math.sin(angle) * 51, -15)
		local startPos = ToWorld(ent, jet)
		local endPos = ToWorld(ent, jet - Vector(0, 0, active and (34 + math.sin(now * 8 + i) * 7) or 13))
		local beamWidth = (active and 13 or 7) * (0.85 + pulse * 0.15)
		render.SetMaterial(matBeam)
		render.DrawBeam(startPos, endPos, beamWidth, 0, 1, Color(82, 218, 255, active and 125 or 55))
		render.SetMaterial(matGlow)
		render.DrawSprite(startPos, (active and 20 or 13) * pulse, (active and 20 or 13) * pulse, Color(95, 235, 255, active and 210 or 125))
	end

	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)
end
