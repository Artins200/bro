AddCSLuaFile("shared.lua")
include("shared.lua")

local MAT_GLOW = Material("sprites/light_glow02_add")
local MAT_SOFT = Material("sprites/glow04_noz")
local MAT_WHITE = Material("vgui/white")

local cvFX = CreateClientConVar("night_visitor_fx", "1", true, false, "Визуальные эффекты ночного гостя", 0, 1)

local function easeOut(t)
    return 1 - (1 - t) ^ 3
end

-- Для TRIANGLEFAN в mesh.Begin передаётся ОБЩЕЕ число вершин (центр + обод).
-- Если передать число секторов, движок обрежет последний — в диске появится вырез.
local function disc(center, radius, col, alpha)
    if radius <= 0.5 or alpha <= 0 then return end
    local segments = 26
    render.SetMaterial(MAT_WHITE)
    mesh.Begin(MATERIAL_TRIANGLEFAN, segments + 2)
    mesh.Color(col.r, col.g, col.b, 0)
    mesh.Position(center)
    for i = 0, segments do
        local a = ((i % segments) / segments) * math.pi * 2
        mesh.Color(col.r, col.g, col.b, alpha)
        mesh.Position(center + Vector(math.cos(a) * radius, math.sin(a) * radius, 0))
    end
    mesh.End()
end

-- MATERIAL_LINES: count — число ЛИНИЙ (по 2 вершины на каждую).
local function ring(center, radius, col, alpha, segments)
    if radius <= 0.5 or alpha <= 0 then return end
    segments = segments or 28
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

function ENT:InitFX()
    if self.FX then return end
    local motes = {}
    for i = 1, 24 do
        motes[i] = {
            angle = math.Rand(0, math.pi * 2),
            radius = math.Rand(7, 22),
            speed = math.Rand(0.22, 0.6),
            phase = math.Rand(0, 1)
        }
    end
    self.FX = {
        trail = {},
        motes = motes,
        nextTrail = 0
    }
end

-- Общие вычисления кадра — чтобы тело и эффекты не расходились по фазе.
function ENT:GetFXState()
    local now = CurTime()
    local spawnT = math.Clamp((now - self:GetNWFloat("NightVisitorSpawned", 0)) / 1.4, 0, 1)
    local target = self:GetTarget()
    local distance = 2000
    if IsValid(target) then distance = self:GetPos():Distance(target:GetPos()) end
    local proximity = math.Clamp(1 - (distance - 80) / 620, 0, 1)
    return now, easeOut(spawnT), distance, proximity
end

function ENT:Draw()
    -- Тело. Никаких SetMaterial с внешними материалами: работаем только с
    -- RENDERMODE_TRANSCOLOR (выставлен на сервере) и render.SetBlend — это
    -- штатный способ сделать модель полупрозрачной, и он не зависит от того,
    -- какие материалы есть в конкретной сборке игры.
    local _, fade = self:GetFXState()
    render.SetBlend(0.55 + fade * 0.4)
    self:DrawModel()
    render.SetBlend(1)
end

function ENT:DrawTranslucent()
    local _, fade, distance, proximity = self:GetFXState()
    local additive = cvFX:GetBool()

    if additive and fade > 0.02 then
        -- Спектральный аддитивный слой поверх силуэта.
        render.SetBlend(fade * (0.06 + proximity * 0.10))
        render.SetColorModulation(0.40, 0.78, 1)
        self:DrawModel()
        render.SetBlend(1)
        render.SetColorModulation(1, 1, 1)
    end

    if not additive then return end

    local now = CurTime()
    local pos = self:GetPos()
    local pulse = 0.62 + math.sin(now * 2.1) * 0.38
    local presence = fade * (0.55 + proximity * 0.45)
    if presence <= 0.01 then return end

    local chest = pos + Vector(0, 0, 40)
    local cool = Color(150, 200, 225)
    local pale = Color(196, 222, 232)

    -- Туман под гостем и медленное расходящееся кольцо-эхо.
    disc(pos - Vector(0, 0, 6), 30 + math.sin(now * 1.2) * 5, Color(120, 150, 162), math.floor(26 * presence))
    local wave = (now * 0.5) % 1
    ring(pos - Vector(0, 0, 5), 22 + wave * 26, pale, math.floor((1 - wave) * 90 * presence), 28)

    -- Ореол вокруг силуэта.
    render.SetMaterial(MAT_GLOW)
    render.DrawSprite(chest, 120 * presence + 20, 150 * presence + 20,
        Color(120, 190, 215, math.floor(26 * presence * pulse)))

    -- Шлейф: призрачные сгустки позади. Точки живут 0.9 с и удаляются с конца,
    -- поэтому таблица не растёт и не «залипает» на одном кадре.
    if now > (self.FX.nextTrail or 0) then
        self.FX.nextTrail = now + 0.06
        table.insert(self.FX.trail, 1, {pos = pos, t = now})
        if #self.FX.trail > 10 then table.remove(self.FX.trail) end
    end
    render.SetMaterial(MAT_SOFT)
    for i = #self.FX.trail, 1, -1 do
        local point = self.FX.trail[i]
        local life = math.Clamp(1 - (now - point.t) / 0.9, 0, 1)
        if life <= 0 then
            table.remove(self.FX.trail, i)
        else
            local size = (22 + (i - 1) * 3) * (0.4 + life * 0.6)
            render.DrawSprite(point.pos + Vector(0, 0, 38), size, size * 1.5,
                Color(130, 185, 210, math.floor(life * 34 * presence)))
        end
    end

    -- Вихрь «праха» вокруг тела.
    for i = 1, #self.FX.motes do
        local mote = self.FX.motes[i]
        local life = (now * mote.speed + mote.phase) % 1
        local a = mote.angle + life * 4.2
        local radius = mote.radius + math.sin(life * math.pi) * 8
        local motePos = pos + Vector(math.cos(a) * radius, math.sin(a) * radius, 6 + life * 70)
        local size = (3.6 - life * 2.6) * (0.7 + math.sin(now * 4 + i) * 0.3)
        render.DrawSprite(motePos, size, size, Color(cool.r, cool.g, cool.b, math.floor((1 - life) * 150 * presence)))
    end

    -- Глаза: привязаны к кости/аттачменту головы, а не к центру модели.
    local eyePos, eyeAng = self:GetEyeData()
    if not eyePos or not eyeAng then return end

    local blinkCycle = (now + self:EntIndex() * 1.7) % 6.5
    local blink = blinkCycle > 6.18 and 0.12 or 1
    local right, forward = eyeAng:Right(), eyeAng:Forward()
    local eyeAlpha = fade * (200 + proximity * 55)

    for side = -1, 1, 2 do
        local p = eyePos + right * (3.05 * side) + forward * 0.9
        render.SetMaterial(MAT_GLOW)
        render.DrawSprite(p, 30 + proximity * 14, 30 + proximity * 14,
            Color(255, 26, 34, math.floor(eyeAlpha * 0.32 * blink * pulse)))
        render.DrawSprite(p, 12, 12, Color(255, 78, 64, math.floor(eyeAlpha * 0.8 * blink)))
        render.SetMaterial(MAT_SOFT)
        render.DrawSprite(p, 5.4, 5.4, Color(255, 246, 242, math.floor(eyeAlpha * blink)))
        -- Вертикальный «блик»: короткий след за зрачком.
        render.DrawSprite(p, 1.8, 24, Color(255, 58, 48, math.floor(eyeAlpha * 0.26 * blink)))
    end

    if distance < 780 then
        local dlight = DynamicLight(self:EntIndex())
        if dlight then
            dlight.pos = eyePos + forward * 6
            dlight.r, dlight.g, dlight.b = 255, 42, 40
            dlight.brightness = 1.4 + proximity * 1.6
            dlight.Decay = 420
            dlight.Size = 90 + proximity * 60
            dlight.DieTime = now + 0.05
        end
    end
end
