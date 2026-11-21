-- ============================================================================
-- Custom Smooth Articulated 3D Model for 4th-Dimensional TIME POLICE (Shleemypants!)
--  * High-poly lumpy wrinkled brain/meatball head with wet specular lobe highlights
--  * Animated chomping gaping purple mouth + wagging tongue + sharp conical fangs
--  * Smooth rounded upper/lower arm segments + elbow/wrist joints + flapping tattered robe
--  * Animated floating bob, torso lean during chase, and multi-jointed baton strike!
-- ============================================================================

if SERVER then
	AddCSLuaFile()
	return
end

RICK_PORTAL = RICK_PORTAL or {}
RICK_PORTAL.TimePoliceRenderer = RICK_PORTAL.TimePoliceRenderer or {}

local TP = RICK_PORTAL.TimePoliceRenderer
TP.Meshes = {}

local matFlesh = CreateMaterial("RickTP_Flesh_v2", "VertexLitGeneric", {
	["$basetexture"]        = "models/debug/debugwhite",
	["$halflambert"]        = "1",
	["$phong"]              = "1",
	["$phongboost"]         = "0.65",
	["$phongexponent"]      = "16",
	["$phongfresnelranges"] = "[0.2 0.55 1]"
})

local matUnlit = CreateMaterial("RickTP_Unlit_v2", "UnlitGeneric", {
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

local function BuildLumpyBrainHead(rx, ry, rz, segs, rings)
	local tris = {}
	segs  = segs or 30
	rings = rings or 20

	local function Displace(nx, ny, nz)
		local lump = 1.0
			+ 0.11 * math.sin(nx * 4.5 + ny * 3.2)
			+ 0.08 * math.cos(nz * 5.2 - nx * 3.8)
			+ 0.05 * math.sin((nx + ny + nz) * 7.2)
		if nx > 0.35 and math.abs(ny) < 0.72 and nz > -0.45 and nz < 0.22 then
			lump = lump * 0.60
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

			AddSmoothQuad(tris, Displace(n11.x,n11.y,n11.z), Displace(n21.x,n21.y,n21.z), Displace(n22.x,n22.y,n22.z), Displace(n12.x,n12.y,n12.z), n11, n21, n22, n12)
		end
	end

	local m = Mesh()
	m:BuildFromTriangles(tris)
	return m
end

local function BuildCapsuleLimb(radius, length, segs)
	local tris = {}
	segs = segs or 16
	for i = 0, segs - 1 do
		local a1 = (i / segs) * math.pi * 2
		local a2 = ((i + 1) / segs) * math.pi * 2
		local c1, s1 = math.cos(a1), math.sin(a1)
		local c2, s2 = math.cos(a2), math.sin(a2)
		local n1 = Vector(c1, s1, 0)
		local n2 = Vector(c2, s2, 0)

		local p1B = Vector(c1 * radius, s1 * radius, 0)
		local p2B = Vector(c2 * radius, s2 * radius, 0)
		local p2T = Vector(c2 * radius * 0.88, s2 * radius * 0.88, length)
		local p1T = Vector(c1 * radius * 0.88, s1 * radius * 0.88, length)
		AddSmoothQuad(tris, p1B, p2B, p2T, p1T, n1, n2, n2, n1)
	end
	local m = Mesh()
	m:BuildFromTriangles(tris)
	return m
end

local function BuildTatteredTunic(rTop, rBot, height, segs)
	local tris = {}
	segs = segs or 26
	for i = 0, segs - 1 do
		local a1 = (i / segs) * math.pi * 2
		local a2 = ((i + 1) / segs) * math.pi * 2
		local c1, s1 = math.cos(a1), math.sin(a1)
		local c2, s2 = math.cos(a2), math.sin(a2)

		local tear1 = ((i % 3 == 0) and 4.8 or ((i % 2 == 0) and -3.2 or 1.2))
		local tear2 = (((i + 1) % 3 == 0) and 4.8 or (((i + 1) % 2 == 0) and -3.2 or 1.2))

		local p1T = Vector(c1 * rTop, s1 * rTop, height)
		local p2T = Vector(c2 * rTop, s2 * rTop, height)
		local p2B = Vector(c2 * rBot, s2 * rBot, tear2)
		local p1B = Vector(c1 * rBot, s1 * rBot, tear1)

		local n1 = Vector(c1, s1, 0.2):GetNormalized()
		local n2 = Vector(c2, s2, 0.2):GetNormalized()
		AddSmoothQuad(tris, p1B, p2B, p2T, p1T, n1, n2, n2, n1)
		AddSmoothQuad(tris, p2B, p1B, p1T, p2T, -n2, -n1, -n1, -n2)
	end
	local m = Mesh()
	m:BuildFromTriangles(tris)
	return m
end

local function BuildConeTooth(radius, height, segs)
	local tris = {}
	segs = segs or 10
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

	self.Meshes.Head      = BuildLumpyBrainHead(15.5, 16.5, 15.0, 30, 20)
	self.Meshes.MouthCav  = BuildLumpyBrainHead(7.6, 11.4, 6.2, 18, 12)
	self.Meshes.Tunic     = BuildTatteredTunic(7.2, 12.2, 34.0, 26)
	self.Meshes.ArmSeg    = BuildCapsuleLimb(1.55, 13.5, 16)
	self.Meshes.Satchel   = BuildLumpyBrainHead(3.4, 5.2, 5.6, 14, 10)
	self.Meshes.Strap     = BuildCapsuleLimb(1.2, 33.0, 12)
	self.Meshes.Tooth     = BuildConeTooth(1.65, 4.3, 10)
	self.Meshes.BatonBody = BuildCapsuleLimb(2.0, 12.0, 16)
	self.Meshes.BatonCore = BuildCapsuleLimb(1.45, 8.5, 14)

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

function TP:DrawTimeCop(origin, ang, isTalking, swingFrac, speedFrac)
	self:EnsureMeshes()

	local ct      = CurTime()
	speedFrac     = speedFrac or 0
	local hoverZ  = 14 + math.sin(ct * 3.6) * 3.8
	local basePos = origin + Vector(0, 0, hoverZ)

	-- Dynamic forward chase tilt & breathing sway!
	local bodyAng = Angle(ang.p + speedFrac * 14 + math.sin(ct * 2.5) * 2.5, ang.y, ang.r + math.cos(ct * 2.2) * 3.0)
	local zeroAng = Angle(0, 0, 0)
	local oneVec  = Vector(1, 1, 1)

	-- 1. Animated Billowing Tattered Tunic Robe
	local robeScale = Vector(1.0 + math.sin(ct * 5.2) * 0.04, 1.0 + math.cos(ct * 4.8) * 0.04, 1.0)
	DrawPart(self.Meshes.Tunic, basePos, bodyAng, Vector(0, 0, 0), zeroAng, robeScale, matFlesh, 224, 208, 176, 255)

	-- 2. Crossbody Leather Satchel & Strap
	DrawPart(self.Meshes.Strap,   basePos, bodyAng, Vector(2.0, -7.5, 4.0), Angle(0, 0, -28), oneVec, matFlesh, 118, 98, 76, 255)
	DrawPart(self.Meshes.Satchel, basePos, bodyAng, Vector(3.2, 9.8, 9.5 + math.sin(ct * 6) * 0.8), Angle(0, 12, -8), oneVec, matFlesh, 154, 132, 98, 255)

	-- 3. Giant Wrinkled Meatball Brain Head with Animated Chomping & Head Bob!
	local jawTalk = isTalking and (math.abs(math.sin(ct * 15)) * 9.5) or (math.sin(ct * 2.4) * 1.5)
	local headPos = Vector(1.5, 0, 44.5 + math.sin(ct * 4.2) * 0.8)
	local headAng = Angle(-jawTalk * 0.5 - speedFrac * 8, math.sin(ct * 2.1) * 6, math.cos(ct * 1.8) * 3)

	DrawPart(self.Meshes.Head,     basePos, bodyAng, headPos, headAng, oneVec, matFlesh, 198, 92, 98, 255)
	DrawPart(self.Meshes.MouthCav, basePos, bodyAng, headPos + Vector(4.2, -2.5, 8.2), headAng, Vector(0.65, 0.55, 0.45), matFlesh, 234, 140, 146, 255)

	-- 4. Animated Gaping Mouth, Wagging Tongue & Sharp Conical Fangs!
	local mouthOpenScale = 1.0 + (jawTalk / 13.0)
	DrawPart(self.Meshes.MouthCav, basePos, bodyAng, headPos + Vector(8.2, 0, -2.2), zeroAng, Vector(1.0, 1.05, 0.78 * mouthOpenScale), matUnlit, 76, 34, 68, 255)
	DrawPart(self.Meshes.MouthCav, basePos, bodyAng, headPos + Vector(8.8, -1.5 + math.sin(ct * 11) * 1.2, -5.0), zeroAng, Vector(0.55, 0.48, 0.30), matUnlit, 186, 84, 172, 255)

	for t = -2, 2 do
		local ty = t * 3.6
		DrawPart(self.Meshes.Tooth, basePos, bodyAng, headPos + Vector(12.6 - math.abs(t) * 0.6, ty, 2.2 + jawTalk * 0.16), Angle(180, 0, 0), oneVec, matUnlit, 246, 243, 208, 255)
		if t == -2 or t == 0 or t == 2 then
			DrawPart(self.Meshes.Tooth, basePos, bodyAng, headPos + Vector(12.2 - math.abs(t) * 0.5, ty, -6.2 - jawTalk * 0.22), zeroAng, oneVec, matUnlit, 246, 243, 208, 255)
		end
	end

	-- 5. Articulated Multi-Segment Arms + Animated Baton Swing Strike!
	local swing = (swingFrac or 0)
	local rShoulder = Vector(2.5, -8.5, 27.5)
	local rUpperAng = Angle(-55 + swing * 75 + math.sin(ct * 4) * 5, 16, -15)
	DrawPart(self.Meshes.ArmSeg, basePos, bodyAng, rShoulder, rUpperAng, oneVec, matFlesh, 186, 78, 86, 255)

	local rElbowLocal = rShoulder + rUpperAng:Up() * 12.5
	local rForeAng    = Angle(-85 + swing * 95, 22, 0)
	DrawPart(self.Meshes.ArmSeg, basePos, bodyAng, rElbowLocal, rForeAng, Vector(0.88, 0.88, 0.92), matFlesh, 186, 78, 86, 255)

	local rHandLocal = rElbowLocal + rForeAng:Up() * 11.5
	local batonAng   = Angle(-25 + swing * 85, 0, 10)
	DrawPart(self.Meshes.BatonBody, basePos, bodyAng, rHandLocal, batonAng, oneVec, matFlesh, 46, 50, 62, 255)
	DrawPart(self.Meshes.BatonCore, basePos, bodyAng, rHandLocal + batonAng:Up() * 2.2, batonAng, oneVec, matUnlit, 232, 120, 255, 255)

	local batonTipWorld = LocalToWorld(rHandLocal + batonAng:Up() * 11.5, zeroAng, basePos, bodyAng)
	render.SetMaterial(matGlow)
	render.DrawSprite(batonTipWorld, 24 + swing * 24, 24 + swing * 24, Color(218, 95, 255, 225))

	-- Left Articulated Arm swaying naturally
	local lShoulder = Vector(2.5, 8.5, 27.0)
	local lUpperAng = Angle(135 + math.sin(ct * 3.5) * 12, -18, 22)
	DrawPart(self.Meshes.ArmSeg, basePos, bodyAng, lShoulder, lUpperAng, oneVec, matFlesh, 186, 78, 86, 255)
	local lElbowLocal = lShoulder + lUpperAng:Up() * 12.0
	DrawPart(self.Meshes.ArmSeg, basePos, bodyAng, lElbowLocal, Angle(75 + math.cos(ct * 3.5) * 10, -10, 0), Vector(0.85, 0.85, 0.9), matFlesh, 186, 78, 86, 255)

	-- 6. Sparse Wiry Black Hairs Sticking Out of the Wrinkled Meatball Head
	render.SetMaterial(matLaser)
	local hairSeeds = {
		Vector(-2, 8, 14), Vector(3, -7, 14.5), Vector(-6, -4, 13.5),
		Vector(6, 12, 8),  Vector(-4, 14, 4),   Vector(2, -15, 5),
		Vector(9, -11, -3), Vector(-8, 9, 10)
	}
	local headWorld = LocalToWorld(headPos, zeroAng, basePos, bodyAng)
	for _, hOff in ipairs(hairSeeds) do
		local pStart = LocalToWorld(hOff, headAng, headWorld, bodyAng)
		local pEnd   = pStart + (pStart - headWorld):GetNormalized() * 4.0 + Vector(0, 0, 1.6)
		render.DrawBeam(pStart, pEnd, 0.55, 0, 1, Color(25, 20, 22, 255))
	end

	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)
end
