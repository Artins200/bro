AddCSLuaFile("shared.lua")
include("shared.lua")

-- Материалы только из базы игры, чтобы аддон оставался asset-free.
local MAT_GLOW = Material("sprites/light_glow02_add")
local MAT_SOFT = Material("sprites/glow04_noz")
local MAT_WHITE = Material("vgui/white")

local cvFX = CreateClientConVar("echo_archive_fx", "1", true, false, "Визуальные эффекты эхо-контейнеров", 0, 1)

-- Вся палитра и бюджет эффектов зависят от редкости: обычный контейнер почти
-- не светится, легендарный тянет за собой луч, орбиту и мощный свет.
local FX = {
    [1] = {col = Color(120, 208, 220), glow = 26, light = 44, beam = 34, motes = 6,  orbit = false},
    [2] = {col = Color(104, 222, 148), glow = 34, light = 58, beam = 52, motes = 9,  orbit = false},
    [3] = {col = Color(124, 152, 255), glow = 44, light = 78, beam = 74, motes = 13, orbit = true},
    [4] = {col = Color(255, 194, 84),  glow = 56, light = 104, beam = 98, motes = 17, orbit = true}
}

local function easeOut(t)
    return 1 - (1 - t) ^ 3
end

local function drawDisc(center, radius, col, alpha)
    if radius <= 0.5 then return end
    -- Для TRIANGLEFAN в mesh.Begin передаётся ОБЩЕЕ число вершин (центр + обод),
    -- иначе движок обрезает последний сектор и в диске остаётся вырез.
    local segments = 28
    render.SetMaterial(MAT_WHITE)
    mesh.Begin(MATERIAL_TRIANGLEFAN, segments + 2)
    mesh.Color(col.r, col.g, col.b, 0)
    mesh.Position(center)
    for i = 0, segments do
        -- Шов замыкаем точно: cos(2π) может дать 6e-17, из-за чего последний
        -- сегмент иногда даёт тонкую щель по стыку.
        local a = (i % segments / segments) * math.pi * 2
        mesh.Color(col.r, col.g, col.b, alpha)
        mesh.Position(center + Vector(math.cos(a) * radius, math.sin(a) * radius, 0))
    end
    mesh.End()
end

-- MATERIAL_LINES: count — число ЛИНИЙ, а не вершин (2 вершины на линию).
local function drawRing(center, radius, col, alpha, segments)
    if radius <= 0.5 then return end
    segments = segments or 24
    render.SetMaterial(MAT_WHITE)
    mesh.Begin(MATERIAL_LINES, segments)
    for i = 0, segments - 1 do
        local a1 = (i / segments) * math.pi * 2
        local a2 = (((i + 1) % segments) / segments) * math.pi * 2
        mesh.Color(col.r, col.g, col.b, alpha)
        mesh.Position(center + Vector(math.cos(a1) * radius, math.sin(a1) * radius, 0))
        mesh.Color(col.r, col.g, col.b, alpha)
        mesh.Position(center + Vector(math.cos(a2) * radius, math.sin(a2) * radius, 0))
    end
    mesh.End()
end

local function drawBeam(base, height, radius, col, alpha)
    if height <= 1 or alpha <= 0 then return end
    local sides = 12
    render.SetMaterial(MAT_WHITE)
    -- MATERIAL_TRIANGLES: count — число ТРЕУГОЛЬНИКОВ (2 на сектор).
    mesh.Begin(MATERIAL_TRIANGLES, sides * 2)
    for i = 0, sides - 1 do
        local a1 = (i / sides) * math.pi * 2
        local a2 = (((i + 1) % sides) / sides) * math.pi * 2
        local p1 = base + Vector(math.cos(a1) * radius, math.sin(a1) * radius, 0)
        local p2 = base + Vector(math.cos(a2) * radius, math.sin(a2) * radius, 0)
        local top = Vector(0, 0, height)
        mesh.Color(col.r, col.g, col.b, alpha)
        mesh.Position(p1)
        mesh.Color(col.r, col.g, col.b, 0)
        mesh.Position(p1 + top)
        mesh.Color(col.r, col.g, col.b, alpha)
        mesh.Position(p2)
        mesh.Color(col.r, col.g, col.b, alpha)
        mesh.Position(p2)
        mesh.Color(col.r, col.g, col.b, 0)
        mesh.Position(p2 + top)
        mesh.Color(col.r, col.g, col.b, 0)
        mesh.Position(p1 + top)
    end
    mesh.End()
end

local function drawDiamond(center, size, spin, col, alpha)
    local top = center + Vector(0, 0, size)
    local bottom = center - Vector(0, 0, size * 1.55)
    local ring = {}
    for i = 0, 3 do
        local a = spin + i * (math.pi * 0.5)
        ring[i + 1] = center + Vector(math.cos(a) * size * 0.62, math.sin(a) * size * 0.62, 0)
    end
    render.SetMaterial(MAT_WHITE)
    mesh.Begin(MATERIAL_TRIANGLES, 8)
    for i = 1, 4 do
        local a = ring[i]
        local b = ring[i % 4 + 1]
        mesh.Color(col.r, col.g, col.b, alpha)
        mesh.Position(top)
        mesh.Color(col.r, col.g, col.b, math.floor(alpha * 0.35))
        mesh.Position(a)
        mesh.Color(col.r, col.g, col.b, math.floor(alpha * 0.55))
        mesh.Position(b)
        mesh.Color(col.r, col.g, col.b, alpha)
        mesh.Position(bottom)
        mesh.Color(col.r, col.g, col.b, math.floor(alpha * 0.55))
        mesh.Position(b)
        mesh.Color(col.r, col.g, col.b, math.floor(alpha * 0.35))
        mesh.Position(a)
    end
    mesh.End()
end

function ENT:InitFX()
    if self.EchoFX then return end
    local motes = {}
    for i = 1, 18 do
        motes[i] = {
            t = math.Rand(0, 1),
            angle = math.Rand(0, math.pi * 2),
            radius = math.Rand(5, 23),
            speed = math.Rand(0.16, 0.34)
        }
    end
    self.EchoFX = {
        motes = motes,
        occluded = false,
        nextOcclusion = 0
    }
end

function ENT:IsOccluded(eye, center)
    local fxState = self.EchoFX
    local now = CurTime()
    if now >= fxState.nextOcclusion then
        fxState.nextOcclusion = now + 0.1
        local tr = util.TraceLine({
            start = eye,
            endpos = center,
            mask = MASK_SOLID_BRUSHONLY,
            filter = {self, LocalPlayer()}
        })
        fxState.occluded = tr.Hit
    end
    return fxState.occluded
end

function ENT:DrawLabel(pos, rarity, col, alpha, discovered, distance)
    local labelPos = pos + Vector(0, 0, 62 + math.sin(CurTime() * 1.7) * 2)
    local ang = Angle(0, (EyePos() - labelPos):Angle().y, 90)
    local scale = 0.085
    cam.Start3D2D(labelPos, ang, scale)
        local w, h = 196, 46
        draw.RoundedBox(5, -w / 2, 0, w, h, Color(7, 13, 20, math.floor(alpha * 0.82)))
        draw.RoundedBox(5, -w / 2, 0, 3, h, Color(col.r, col.g, col.b, alpha))
        draw.RoundedBox(2, -w / 2 + 12, 12, 7, 7, Color(col.r, col.g, col.b, alpha))
        draw.SimpleText(string.upper(self.RarityNames[rarity] or ""), "EchoArchive.Label", -w / 2 + 26, 11, Color(236, 246, 250, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(discovered and "СИГНАЛ ПОДТВЕРЖДЁН" or "ЭХО-КОНТЕЙНЕР", "EchoArchive.Tiny", -w / 2 + 26, 27, Color(col.r, col.g, col.b, math.floor(alpha * 0.9)), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        if distance < 220 then
            local hintAlpha = math.min(255, alpha * 1.1)
            draw.RoundedBox(4, w / 2 - 46, 13, 36, 20, Color(col.r * 0.24, col.g * 0.24, col.b * 0.24, math.floor(hintAlpha * 0.75)))
            draw.SimpleText("E", "EchoArchive.Tiny", w / 2 - 28, 22, Color(255, 255, 255, hintAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    cam.End3D2D()
end

function ENT:Draw()
    local pos = self:GetPos()
    local distSqr = pos:DistToSqr(EyePos())
    local now = CurTime()
    local rarity = self:GetRarity()
    local fx = FX[rarity] or FX[1]

    self:DrawModel()

    if not cvFX:GetBool() then return end
    if distSqr > 1800 * 1800 then return end

    self:InitFX()

    -- Появление: контейнер «собирается» из энергии — сначала призрачная
    -- голограмма (аддитивный проход по модели), затем обычная модель.
    local spawnT = math.Clamp((now - self:GetNWFloat("EchoSpawned", 0)) / 0.9, 0, 1)
    if spawnT < 1 then
        local pop = easeOut(spawnT)
        render.SetBlend(pop)
        render.SetColorModulation(fx.col.r / 255, fx.col.g / 255, fx.col.b / 255)
        self:DrawModel()
        render.SetBlend(1)
        render.SetColorModulation(1, 1, 1)
    end
end

-- Всё светящееся — в прозрачном проходе: так спрайты и mesh-геометрия не
-- конфликтуют с сортировкой моделей и не «мигают» сквозь другие сущности.
function ENT:DrawTranslucent()
    if not cvFX:GetBool() then return end
    local pos = self:GetPos()
    local eye = EyePos()
    local distSqr = pos:DistToSqr(eye)
    if distSqr > 1800 * 1800 then return end
    self:InitFX()

    local now = CurTime()
    local rarity = self:GetRarity()
    local fx = FX[rarity] or FX[1]
    local spawnT = math.Clamp((now - self:GetNWFloat("EchoSpawned", 0)) / 0.9, 0, 1)
    local pop = easeOut(spawnT)
    local pulse = 0.7 + math.sin(now * 2.3 + self:EntIndex() * 0.7) * 0.3
    local alpha = pop * 255
    local col = fx.col
    local discovered = (self.EchoDiscoveredUntil or 0) > now
    local boost = discovered and 1.4 or 1
    local distance = math.sqrt(distSqr)

    -- Появление: мягкая ударная волна по земле.
    if spawnT < 1 then
        drawRing(pos + Vector(0, 0, 2), 12 + easeOut(spawnT) * 78, col, (1 - spawnT) * 150, 32)
    end

    -- Основание: светящийся диск и пульсирующие кольца.
    drawDisc(pos + Vector(0, 0, 1.4), 30 * pop, col, alpha * 0.22 * pulse * boost)
    drawRing(pos + Vector(0, 0, 2.2), 33 * pop, col, alpha * 0.5 * boost, 26)
    if fx.orbit then
        local spinRadius = 38 + math.sin(now * 1.1) * 3
        drawRing(pos + Vector(0, 0, 20 + math.sin(now * 1.5) * 3), spinRadius, col, alpha * 0.35, 30)
    end

    if discovered then
        local wave = (now * 0.7) % 1
        drawRing(pos + Vector(0, 0, 2.4), 34 + wave * 40, col, (1 - wave) * 110, 30)
    end

    -- Луч над контейнером.
    local beamBase = pos + Vector(0, 0, 44)
    drawBeam(beamBase, fx.beam * pop, 9 + math.sin(now * 2.6) * 1.5, col, alpha * 0.13 * pulse * boost)
    drawBeam(beamBase, fx.beam * pop * 0.85, 4.5, col, alpha * 0.16 * pulse * boost)

    -- Парящий ромб-маркер: виден даже сквозь мелкий мусор, но не сквозь стены.
    local bubble = math.sin(now * 1.8 + self:EntIndex()) * 3
    local diamondPos = pos + Vector(0, 0, 50 + fx.beam * 0.62 + bubble)
    local diamondSize = 5.5 + rarity * 0.7 + (discovered and 1.4 or 0)
    render.SetMaterial(MAT_GLOW)
    render.DrawSprite(diamondPos, fx.glow * 1.6, fx.glow * 1.6, Color(col.r, col.g, col.b, alpha * 0.5 * pulse))
    drawDiamond(diamondPos, diamondSize, now * 1.5, col, alpha * 0.95)

    -- Орбитальные спутники у редких контейнеров.
    if fx.orbit then
        for i = 0, 2 do
            local a = now * 1.15 + i * (math.pi * 2 / 3)
            local orbitPos = pos + Vector(math.cos(a) * 26, math.sin(a) * 26, 30 + math.sin(now * 2 + i) * 8)
            render.SetMaterial(MAT_SOFT)
            render.DrawSprite(orbitPos, 7, 7, Color(col.r, col.g, col.b, alpha * 0.9))
        end
    end

    -- Пылинки, поднимающиеся в луче.
    render.SetMaterial(MAT_SOFT)
    for i = 1, fx.motes do
        local mote = self.EchoFX.motes[i]
        local life = (now * mote.speed + mote.t) % 1
        local a = mote.angle + life * 3.4
        local radius = mote.radius + life * 9
        local motePos = pos + Vector(math.cos(a) * radius, math.sin(a) * radius, 6 + life * (fx.beam + 42))
        local size = (4 - life * 2.8) * (0.7 + math.sin(now * 3.4 + i) * 0.3)
        render.DrawSprite(motePos, size, size, Color(col.r, col.g, col.b, (1 - life) * alpha * 0.8))
    end

    -- Динамический свет: дорого, поэтому только вблизи.
    if distance < 780 and pop > 0.35 then
        local dlight = DynamicLight(self:EntIndex())
        if dlight then
            dlight.pos = pos + Vector(0, 0, 34)
            dlight.r = col.r
            dlight.g = col.g
            dlight.b = col.b
            dlight.brightness = (discovered and 5.5 or 2.4) * pulse * pop
            dlight.Decay = 780
            dlight.Size = fx.light * (0.92 + math.sin(now * 3.1) * 0.08)
            dlight.DieTime = now + 0.05
        end
    end

    -- Подпись рисуем последней и только когда её реально видно.
    if pop > 0.55 and distance < 1050 and not self:IsOccluded(eye, pos + Vector(0, 0, 30)) then
        local fade = 1 - math.Clamp((distance - 620) / 430, 0, 1)
        local labelAlpha = alpha * fade
        if labelAlpha > 8 then
            self:DrawLabel(pos, rarity, col, labelAlpha, discovered, distance)
        end
    end
end
