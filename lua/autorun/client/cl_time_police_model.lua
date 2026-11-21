-- ============================================================================
-- Custom 3D Model for 4th-Dimensional TIME POLICE (Shleemypants / images.png!)
--  * Giant wrinkled pinkish-crimson meatball/testicle brain head
--  * Huge gaping dark-purple mouth with sharp jagged yellow-white teeth & tongue
--  * Sparse wiry black hairs sticking out of the lumpy head
--  * Tattered beige-tan sleeveless tunic/robe + brown crossbody satchel strap & bag
--  * Thin reddish arms holding a glowing purple-pink Temporal Arrest Baton / Radio
--  * Floats leglessly above ground just like the 4th-dimensional Time Cops!
-- ============================================================================

if SERVER then
	AddCSLuaFile()
	return
end

RICK_PORTAL = RICK_PORTAL or {}
RICK_PORTAL.TimePoliceRenderer = RICK_PORTAL.TimePoliceRenderer or {}

local TP = RICK_PORTAL.TimePoliceRenderer
TP.Meshes = {}

local matFlesh = CreateMaterial("RickTP_Flesh_v1", "VertexLitGeneric", {
	["$basetexture"]        = "models/debug/debugwhite",
	["$halflambert"]        = "1",
	["$phong"]              = "1",
	["$phongboost"]         = "0.45",
	["$phongexponent"]      = "12",
	["$phongfresnelranges"] = "[0.2 0.5 1]"
})

local matUnlit = CreateMaterial("RickTP_Unlit_v1", "UnlitGeneric", {
	["$basetexture"] = "models/debug/debugwhite",
	["$vertexcolor"] = "1",
	["$vertexalpha"] = "1",
	["$translucent"] = "1",
	["$nocull"]      = "1"
})

local matGlow  = Material("sprites/light_glow02_add")
local matLaser = Material("Effects/laser1")

local function AddQuad(tris, p1, p2, p3, p4)
	local n = (p4 - p1):Cross(p2 - p1):GetNormalized()
	tris[#tris + 1] = { pos = p1, normal = n, u = 0, v = 0 }
	tris[#tris + 1] = { pos = p2, normal = n, u = 1, v = 0 }
	tris[#tris + 1] = { pos = p3, normal = n, u = 1, v = 1 }

	tris[#tris + 1] = { pos = p1, normal = n, u = 0, v = 0 }
	tris[#tris + 1] = { pos = p3, normal = n, u = 1, v = 1 }
	tris[#tris + 1] = { pos = p4, normal = n, u = 0, v = 1 }
end

local function BuildLumpyBrainHead(rx, ry, rz, segs, rings)
	local tris = {}
	segs  = segs or 24
	rings = rings or 16

	local function Displace(nx, ny, nz)
		-- Lumpy organic brain/meatball wrinkles!
		local lump = 1.0
			+ 0.10 * math.sin(nx * 4.5 + ny * 3.2)
			+ 0.08 * math.cos(nz * 5.2 - nx * 3.8)
			+ 0.05 * math.sin((nx + ny + nz) * 7.0)
		-- Carve recessed mouth indentation on the front (+X, slightly below Z=0)
		if nx > 0.35 and math.abs(ny) < 0.72 and nz > -0.45 and nz < 0.22 then
			lump = lump * 0.62
		end
		return Vector(nx * rx * lump, ny * ry * lump, nz * rz * lump)
	end

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

			local p11 = Displace(n11.x, n11.y, n11.z)
			local p21 = Displace(n21.x, n21.y, n21.z)
			local p22 = Displace(n22.x, n22.y, n22.z)
			local p12 = Displace(n12.x, n12.y, n12.z)

			tris[#tris + 1] = { pos = p11, normal = n11, u = 0, v = 0 }
			tris[#tris + 1] = { pos = p21, normal = n21, u = 1, v = 0 }
			tris[#tris + 1] = { pos = p22, normal = n22, u = 1, v = 1 }

			tris[#tris + 1] = { pos = p11, normal = n11, u = 0, v = 0 }
			tris[#tris + 1] = { pos = p22, normal = n22, u = 1, v = 1 }
			tris[#tris + 1] = { pos = p12, normal = n12, u = 0, v = 1 }
		end
	end

	local m = Mesh()
	m:BuildFromTriangles(tris)
	return m
end

-- Tattered ragged beige robe cone (wider & jagged at the bottom hem, floating leglessly!)
local function BuildTatteredTunic(rTop, rBot, height, segs)
	local tris = {}
	segs = segs or 20
	for i = 0, segs - 1 do
		local a1 = (i / segs) * math.pi * 2
		local a2 = ((i + 1) / segs) * math.pi * 2
		local c1, s1 = math.cos(a1), math.sin(a1)
		local c2, s2 = math.cos(a2), math.sin(a2)

		-- Jagged torn hem at bottom of tunic!
		local tear1 = ((i % 3 == 0) and 4.5 or ((i % 2 == 0) and -3.0 or 1.0))
		local tear2 = (((i + 1) % 3 == 0) and 4.5 or (((i + 1) % 2 == 0) and -3.0 or 1.0))

		local p1T = Vector(c1 * rTop, s1 * rTop, height)
		local p2T = Vector(c2 * rTop, s2 * rTop, height)
		local p2B = Vector(c2 * rBot, s2 * rBot, tear2)
		local p1B = Vector(c1 * rBot, s1 * rBot, tear1)

		local n = Vector((c1 + c2) * 0.5, (s1 + s2) * 0.5, 0.2):GetNormalized()
		tris[#tris + 1] = { pos = p1B, normal = n, u = 0, v = 1 }
		tris[#tris + 1] = { pos = p2B, normal = n, u = 1, v = 1 }
		tris[#tris + 1] = { pos = p2T, normal = n, u = 1, v = 0 }

		tris[#tris + 1] = { pos = p1B, normal = n, u = 0, v = 1 }
		tris[#tris + 1] = { pos = p2T, normal = n, u = 1, v = 0 }
		tris[#tris + 1] = { pos = p1T, normal = n, u = 0, v = 0 }

		-- Double-sided inside hem
		tris[#tris + 1] = { pos = p2B, normal = -n, u = 1, v = 1 }
		tris[#tris + 1] = { pos = p1B, normal = -n, u = 0, v = 1 }
		tris[#tris + 1] = { pos = p2T, normal = -n, u = 1, v = 0 }
	end
	local m = Mesh()
	m:BuildFromTriangles(tris)
	return m
end

local function BuildSimpleBox(lx, ly, lz)
	local tris = {}
	local hx, hy, hz = lx * 0.5, ly * 0.5, lz * 0.5
	AddQuad(tris, Vector(hx,-hy,-hz), Vector(hx,hy,-hz), Vector(hx,hy,hz), Vector(hx,-hy,hz))
	AddQuad(tris, Vector(-hx,hy,-hz), Vector(-hx,-hy,-hz), Vector(-hx,-hy,hz), Vector(-hx,hy,hz))
	AddQuad(tris, Vector(hx,hy,-hz), Vector(-hx,hy,-hz), Vector(-hx,hy,hz), Vector(hx,hy,hz))
	AddQuad(tris, Vector(-hx,-hy,-hz), Vector(hx,-hy,-hz), Vector(hx,-hy,hz), Vector(-hx,-hy,hz))
	AddQuad(tris, Vector(-hx,-hy,hz), Vector(hx,-hy,hz), Vector(hx,hy,hz), Vector(-hx,hy,hz))
	AddQuad(tris, Vector(-hx,hy,-hz), Vector(hx,hy,-hz), Vector(hx,-hy,-hz), Vector(-hx,-hy,-hz))
	local m = Mesh()
	m:BuildFromTriangles(tris)
	return m
end

local function BuildConeTooth(radius, height, segs)
	local tris = {}
	segs = segs or 8
	local tip = Vector(0, 0, height)
	for i = 0, segs - 1 do
		local a1 = (i / segs) * math.pi * 2
		local a2 = ((i + 1) / segs) * math.pi * 2
		local p1 = Vector(math.cos(a1) * radius, math.sin(a1) * radius, 0)
		local p2 = Vector(math.cos(a2) * radius, math.sin(a2) * radius, 0)
		local n  = Vector(math.cos((a1+a2)*0.5), math.sin((a1+a2)*0.5), 0.4):GetNormalized()
		tris[#tris + 1] = { pos = p1,  normal = n, u = 0,   v = 1 }
		tris[#tris + 1] = { pos = p2,  normal = n, u = 1,   v = 1 }
		tris[#tris + 1] = { pos = tip, normal = n, u = 0.5, v = 0 }
	end
	local m = Mesh()
	m:BuildFromTriangles(tris)
	return m
end

function TP:EnsureMeshes()
	if self.Meshes.Ready then return end

	self.Meshes.Head       = BuildLumpyBrainHead(15.5, 16.5, 15.0, 24, 16)
	self.Meshes.MouthCav   = BuildLumpyBrainHead(7.5, 11.2, 6.2, 16, 10)
	self.Meshes.Tunic      = BuildTatteredTunic(7.2, 11.8, 34.0, 20)
	self.Meshes.Satchel    = BuildSimpleBox(5.5, 8.5, 9.5)
	self.Meshes.Strap      = BuildSimpleBox(2.2, 17.5, 32.0)
	self.Meshes.Limb       = BuildSimpleBox(2.6, 2.6, 15.0)
	self.Meshes.Tooth      = BuildConeTooth(1.65, 4.2, 8)
	self.Meshes.BatonBody  = BuildSimpleBox(3.4, 3.4, 11.5)
	self.Meshes.BatonCore  = BuildSimpleBox(2.4, 2.4, 8.0)

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

function TP:DrawTimeCop(origin, ang, isTalking, swingFrac)
	self:EnsureMeshes()

	local ct      = CurTime()
	local hoverZ  = 14 + math.sin(ct * 3.1) * 3.2
	local basePos = origin + Vector(0, 0, hoverZ)
	local zeroAng = Angle(0, 0, 0)
	local oneVec  = Vector(1, 1, 1)

	-- 1. Tattered Beige-Cream Sleeveless Robe / Tunic (matches images.png!)
	DrawPart(self.Meshes.Tunic, basePos, ang, Vector(0, 0, 0), zeroAng, oneVec, matFlesh, 224, 208, 176, 255)

	-- 2. Brown Crossbody Satchel Bag & Strap
	DrawPart(self.Meshes.Strap,   basePos, ang, Vector(0.5, 0, 18), Angle(0, 0, 26), Vector(4.2, 1.0, 1.0), matFlesh, 118, 98, 76, 255)
	DrawPart(self.Meshes.Satchel, basePos, ang, Vector(3.0, 9.8, 8.5), Angle(0, 12, -8), oneVec, matFlesh, 154, 132, 98, 255)

	-- 3. Giant Wrinkled Crimson-Pink Meatball/Testicle Head!
	local jawTalk = isTalking and (math.abs(math.sin(ct * 14)) * 8.5) or (math.sin(ct * 2.2) * 1.5)
	local headPos = Vector(1.5, 0, 44.5)
	local headAng = Angle(-jawTalk * 0.45, math.sin(ct * 1.9) * 4, 0)

	DrawPart(self.Meshes.Head, basePos, ang, headPos, headAng, oneVec, matFlesh, 198, 92, 98, 255)

	-- Specular wet pink brain highlight on top-front of head
	DrawPart(self.Meshes.MouthCav, basePos, ang, headPos + Vector(4.2, -2.5, 8.2), headAng, Vector(0.65, 0.55, 0.45), matFlesh, 232, 138, 144, 255)

	-- 4. Gaping Dark-Purple Mouth Cavity + Tongue + Jagged Yellowish Teeth!
	local mouthOpenScale = 1.0 + (jawTalk / 14.0)
	DrawPart(self.Meshes.MouthCav, basePos, ang, headPos + Vector(8.2, 0, -2.2), zeroAng, Vector(1.0, 1.05, 0.78 * mouthOpenScale), matUnlit, 78, 36, 68, 255)
	-- Purple-pink tongue inside mouth
	DrawPart(self.Meshes.MouthCav, basePos, ang, headPos + Vector(8.8, -1.8, -5.0), zeroAng, Vector(0.55, 0.48, 0.30), matUnlit, 182, 82, 168, 255)

	-- Upper & Lower Sharp Jagged Teeth (matching images.png!)
	for t = -2, 2 do
		local ty = t * 3.6
		-- Upper teeth pointing down
		DrawPart(self.Meshes.Tooth, basePos, ang, headPos + Vector(12.6 - math.abs(t) * 0.6, ty, 2.2 + jawTalk * 0.15), Angle(180, 0, 0), oneVec, matUnlit, 245, 242, 205, 255)
		-- Lower fangs pointing up
		if t == -2 or t == 0 or t == 2 then
			DrawPart(self.Meshes.Tooth, basePos, ang, headPos + Vector(12.2 - math.abs(t) * 0.5, ty, -6.2 - jawTalk * 0.20), zeroAng, oneVec, matUnlit, 245, 242, 205, 255)
		end
	end

	-- 5. Thin Reddish Arms + Glowing Purple-Violet 4th-Dimensional Time Baton / Walkie-Talkie!
	local swingAng = (swingFrac or 0) * 55
	-- Right arm raised holding the glowing violet temporal device (just like images.png!)
	DrawPart(self.Meshes.Limb, basePos, ang, Vector(5.5, -10.5, 23.5), Angle(-48 - swingAng, 18, -12), oneVec, matFlesh, 186, 78, 86, 255)
	DrawPart(self.Meshes.Limb, basePos, ang, Vector(12.5, -7.2, 28.5), Angle(-75 - swingAng, 28, 0),   Vector(0.85, 0.85, 0.9), matFlesh, 186, 78, 86, 255)

	-- Glowing Violet Time Baton / Radio in hand
	local batonLocal = Vector(16.8, -4.5, 33.5 - (swingFrac or 0) * 5)
	DrawPart(self.Meshes.BatonBody, basePos, ang, batonLocal, Angle(-20 - swingAng, 0, 12), oneVec, matFlesh, 48, 52, 62, 255)
	DrawPart(self.Meshes.BatonCore, basePos, ang, batonLocal + Vector(0.6, 0, -0.5), Angle(-20 - swingAng, 0, 12), oneVec, matUnlit, 228, 125, 255, 255)

	local batonWorld = LocalToWorld(batonLocal + Vector(0, 0, 6), zeroAng, basePos, ang)
	render.SetMaterial(matGlow)
	render.DrawSprite(batonWorld, 22, 22, Color(215, 95, 255, 210))

	-- Left thin reddish arm
	DrawPart(self.Meshes.Limb, basePos, ang, Vector(4.5, 10.8, 22.0), Angle(-32, -14, 15), oneVec, matFlesh, 186, 78, 86, 255)

	-- 6. Sparse Wiry Black Hairs Sticking Out of the Wrinkled Meatball Head!
	render.SetMaterial(matLaser)
	local hairSeeds = {
		Vector(-2, 8, 14), Vector(3, -7, 14.5), Vector(-6, -4, 13.5),
		Vector(6, 12, 8),  Vector(-4, 14, 4),   Vector(2, -15, 5),
		Vector(9, -11, -3), Vector(-8, 9, 10)
	}
	local headWorld = LocalToWorld(headPos, zeroAng, basePos, ang)
	for _, hOff in ipairs(hairSeeds) do
		local pStart = LocalToWorld(hOff, headAng, headWorld, ang)
		local pEnd   = pStart + (pStart - headWorld):GetNormalized() * 3.8 + Vector(0, 0, 1.5)
		render.DrawBeam(pStart, pEnd, 0.55, 0, 1, Color(25, 20, 22, 255))
	end

	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)
end
