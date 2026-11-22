AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

local HULL_MINS = Vector(-13, -13, 0)
local HULL_MAXS = Vector(13, 13, 64)
local HOVER_HEIGHT = 7

local function endEncounter(ghost, reason)
    if NightVisitor and NightVisitor.End then NightVisitor.End(ghost, reason) end
end

local function groundZ(ghost, target)
    local base = ghost:GetPos()
    local tr = util.TraceHull({
        start = base + Vector(0, 0, 48),
        endpos = base - Vector(0, 0, 240),
        mins = HULL_MINS,
        maxs = HULL_MAXS,
        filter = {ghost, target},
        mask = MASK_SOLID_BRUSHONLY
    })
    if tr.Hit and not tr.StartSolid and tr.HitNormal.z > 0.35 then return tr.HitPos.z end
    return nil
end

-- Движение с обтеканием стен: сначала вперёд, при упоре — вбок.
local function slideMove(ghost, from, delta, filter)
    if delta:LengthSqr() < 0.0001 then return from, false end
    local tr = util.TraceHull({
        start = from,
        endpos = from + delta,
        mins = HULL_MINS,
        maxs = HULL_MAXS,
        filter = filter,
        mask = MASK_SOLID_BRUSHONLY
    })
    if tr.StartSolid then return from, true end
    if tr.Hit then return tr.HitPos - tr.HitNormal * 1.5, true end
    return from + delta, false
end

local function moveTowards(ghost, target, delta)
    local filter = {ghost, target}
    local pos, blocked = slideMove(ghost, ghost:GetPos(), delta, filter)
    if not blocked then return pos end
    local length = delta:Length()
    if length < 0.01 then return pos end
    local flat = Vector(delta.x, delta.y, 0)
    if flat:LengthSqr() < 0.0001 then return pos end
    local side = Vector(-flat.y, flat.x, 0):GetNormalized() * length
    local left = slideMove(ghost, ghost:GetPos(), side, filter)
    local right = slideMove(ghost, ghost:GetPos(), -side, filter)
    local choose = left:DistToSqr(ghost:GetPos()) >= right:DistToSqr(ghost:GetPos()) and left or right
    if choose:DistToSqr(ghost:GetPos()) > pos:DistToSqr(ghost:GetPos()) then return choose end
    return pos
end

function ENT:Initialize()
    self:SetModel(self.GhostModel or "models/player/charple.mdl")
    self:SetModelScale(self.GhostScale or 1.08, 0)
    -- SOLID_NONE: гость не толкает игроков и не застревает в них, но стены
    -- для него по-прежнему непроходимы — их проверяет TraceHull.
    self:SetSolid(SOLID_NONE)
    self:SetCollisionBounds(HULL_MINS, HULL_MAXS)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetUseType(NOT_USE)
    self:SetRenderMode(RENDERMODE_TRANSCOLOR)
    self:SetColor(Color(188, 208, 216, 215))
    self:SetHealth(9999)
    self:SetNWFloat("NightVisitorSpawned", CurTime())
    self.NextStep = CurTime() + 1
    self.NextWhisper = CurTime() + math.Rand(3, 6)
    self.GazeTime = 0
    self.LastThinkAt = CurTime()
    self.HoverZ = self:GetPos().z
    self.Sway = 0
    self.DodgeAt = 0

    -- Эффекты (ореол, шлейф, прах, глаза) выходят за габариты модели —
    -- расширяем границы, иначе они мигают при повороте камеры.
    self:SetRenderBounds(Vector(-90, -90, -48), Vector(90, 90, 190))

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end
end

local function flashlightWatching(ghost)
    local center = ghost:WorldSpaceCenter()
    for _, ply in ipairs(player.GetHumans()) do
        if IsValid(ply) and ply:Alive() and ply:FlashlightIsOn() then
            local delta = center - ply:EyePos()
            local distance = delta:Length()
            if distance < 1150 and distance > 1 then
                local dot = ply:EyeAngles():Forward():Dot(delta:GetNormalized())
                if dot > 0.94 then
                    local tr = util.TraceLine({start = ply:EyePos(), endpos = center, filter = {ply, ghost}, mask = MASK_SOLID_BRUSHONLY})
                    if not tr.Hit then return true, dot end
                end
            end
        end
    end
    return false, 0
end

function ENT:Think()
    local target = self:GetTarget()
    if not IsValid(target) or not target:Alive() then
        endEncounter(self, "escaped")
        return
    end

    local now = CurTime()
    local dt = math.Clamp(now - (self.LastThinkAt or now), 0, 0.1)
    self.LastThinkAt = now
    self.Sway = (self.Sway or 0) + dt

    -- Фонарь: луч считается «пойманным» только если он действительно бьёт в
    -- гостя, а не просто проходит рядом. Поэтому доля перекрытия замера
    -- накапливается как прогресс, а не как мгновенное «да/нет».
    local watched = flashlightWatching(self)
    local pos = self:GetPos()
    local targetPos = target:GetPos()
    local delta = targetPos - pos
    delta.z = 0
    local distance = delta:Length()

    -- Кулдаун касания: если гость каким-то образом остался рядом после удара,
    -- он не должен бить каждую секунду.
    local canAttack = (self.NextAttack == nil) or now >= self.NextAttack

    if watched then
        self.GazeTime = self.GazeTime + dt
        if self.GazeTime >= (NightVisitor and NightVisitor.Config.RepelTime or 2.6) then
            endEncounter(self, "repelled")
            return
        end
        -- Под светом гость не стоит статуей: мелко смещается вбок, но не
        -- приближается — иначе фонарь ничего не даёт.
        if now > (self.DodgeAt or 0) and distance > 40 then
            self.DodgeAt = now + math.Rand(0.7, 1.5)
            local side = Vector(-delta.y, delta.x, 0)
            if side:LengthSqr() > 1 then
                side:Normalize()
                side = side * math.Rand(-26, 26)
                self:SetPos(moveTowards(self, target, side))
            end
        end
    else
        self.GazeTime = math.max(0, self.GazeTime - dt * 0.8)
        if distance > 34 then
            local away = (pos - targetPos):GetNormalized()
            local staring = target:EyeAngles():Forward():Dot(away) > 0.62
            local speed = staring and 88 or 150
            local step = math.min(distance - 30, speed * dt)
            if step > 0 then
                local forward = Vector(delta.x, delta.y, 0)
                if forward:LengthSqr() > 1 then forward:Normalize() end
                -- Лёгкий синусоидальный дрейф, чтобы движение не было «рельсовым».
                local drift = Vector(-forward.y, forward.x, 0) * math.sin(self.Sway * 0.9) * step * 0.35
                self:SetPos(moveTowards(self, target, forward * step + drift))
            end
        end
    end

    -- Парение: высота считается от пола, а не от текущей позиции.
    local floor = groundZ(self, target)
    if floor then
        local bob = math.sin(self.Sway * 1.7) * 2.5
        local wanted = floor + HOVER_HEIGHT + bob
        self.HoverZ = Lerp(1 - math.exp(-dt * 5), self.HoverZ or wanted, wanted)
    end
    if self.HoverZ then
        -- Небольшой «удар» по вертикали, чтобы шаг не выглядел лифтом.
        self.HoverZ = self.HoverZ + math.sin(self.Sway * 3.1) * dt * 4
        self:SetPos(Vector(self:GetPos().x, self:GetPos().y, self.HoverZ))
    end
    -- Страховка от вылета за пределы карты: молча вернуть в центр мира лучше,
    -- чем оставить гостя навсегда под полом. Обычно срабатывает только на
    -- сломанных картах.
    local ghostPos = self:GetPos()
    if not ghostPos:IsZero() and (ghostPos.z < -6000 or ghostPos.z > 12000) then
        local fallback = targetPos + Vector(0, 0, 8)
        self:SetPos(fallback)
        self.HoverZ = fallback.z
    end

    -- Плавный поворот к цели.
    if distance > 4 then
        local cur = self:GetAngles().y
        local want = delta:Angle().y
        local diff = math.AngleDifference(want, cur)
        self:SetAngles(Angle(0, cur + diff * math.Clamp(dt * 7, 0, 1), 0))
    end

    if (self:GetPos() - targetPos):LengthSqr() < 74 * 74 and canAttack then
        self.NextAttack = now + 8
        local dmg = DamageInfo()
        dmg:SetDamage(24)
        dmg:SetDamageType(DMG_DROWN)
        dmg:SetAttacker(self)
        dmg:SetInflictor(self)
        target:TakeDamageInfo(dmg)
        target:ViewPunch(Angle(-7, math.Rand(-5, 5), 0))
        self:EmitSound("ambient/voices/citizen_beaten2.wav", 85, 82)
        endEncounter(self, "attack")
        return
    end

    -- Позиционные звуки: шаги-скрипы идут от самого гостя, а не от игрока.
    if now >= (self.NextStep or 0) and distance > 150 then
        self.NextStep = now + math.Rand(2.4, 4.6)
        self:EmitSound("ambient/atmosphere/cave_hit1.wav", 62, math.random(72, 96), 0.5)
    end
    if now >= (self.NextWhisper or 0) and distance < 950 then
        self.NextWhisper = now + math.Rand(4.5, 8.5)
        self:EmitSound("ambient/voices/citizen_beaten" .. math.random(1, 3) .. ".wav", 55, math.random(72, 88), 0.45)
    end

    self:NextThink(now)
    return true
end

function ENT:OnTakeDamage()
    -- Обычное оружие гость не берёт: его отгоняет только свет.
end
