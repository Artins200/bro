AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/player/charple.mdl")
    self:SetModelScale(1.08, 0)
    self:SetSolid(SOLID_BBOX)
    self:SetCollisionBounds(Vector(-16, -16, 0), Vector(16, 16, 74))
    self:SetMoveType(MOVETYPE_NONE)
    self:SetUseType(NOT_USE)
    self:SetRenderMode(RENDERMODE_TRANSCOLOR)
    self:SetColor(Color(185, 198, 205, 225))
    self:SetHealth(9999)
    self.NextStep = CurTime()
    self.GazeTime = 0
    self.LastThinkAt = CurTime()
end

local function flashlightWatching(ghost)
    for _, ply in ipairs(player.GetHumans()) do
        if IsValid(ply) and ply:Alive() and ply:FlashlightIsOn() then
            local delta = ghost:WorldSpaceCenter() - ply:EyePos()
            local distance = delta:Length()
            if distance < 1050 and ply:EyeAngles():Forward():Dot(delta:GetNormalized()) > 0.955 then
                local tr = util.TraceLine({start = ply:EyePos(), endpos = ghost:WorldSpaceCenter(), filter = {ply, ghost}, mask = MASK_VISIBLE})
                if not tr.Hit then return true end
            end
        end
    end
    return false
end

function ENT:Think()
    local target = self:GetNWEntity("NightVisitorTarget")
    if not IsValid(target) or not target:Alive() then
        if NightVisitor then NightVisitor.End(self, "escaped") end
        return
    end

    local now = CurTime()
    local dt = math.Clamp(now - (self.LastThinkAt or now), 0, 0.1)
    self.LastThinkAt = now
    local isWatched = flashlightWatching(self)
    if isWatched then
        self.GazeTime = self.GazeTime + dt
        if self.GazeTime >= NightVisitor.Config.RepelTime then
            NightVisitor.End(self, "repelled")
            return
        end
    else
        self.GazeTime = math.max(0, self.GazeTime - dt * 0.8)
        local delta = target:GetPos() - self:GetPos()
        delta.z = 0
        local distance = delta:Length()
        if distance > 1 then
            local speed = target:EyeAngles():Forward():Dot((self:GetPos() - target:GetPos()):GetNormalized()) > 0.6 and 92 or 156
            local nextPos = self:GetPos() + delta:GetNormalized() * math.min(distance, speed * dt)
            local tr = util.TraceHull({
                start = self:GetPos(), endpos = nextPos,
                mins = Vector(-13, -13, 0), maxs = Vector(13, 13, 68),
                filter = {self, target}, mask = MASK_SOLID
            })
            if not tr.StartSolid then self:SetPos(tr.Hit and tr.HitPos or nextPos) end
            if delta:LengthSqr() > 1 then self:SetAngles(Angle(0, delta:Angle().y, 0)) end
        end
    end

    if self:GetPos():DistToSqr(target:GetPos()) < 68 * 68 and not self.Attacked then
        self.Attacked = true
        local dmg = DamageInfo()
        dmg:SetDamage(24)
        dmg:SetDamageType(DMG_DROWN)
        dmg:SetAttacker(self)
        dmg:SetInflictor(self)
        target:TakeDamageInfo(dmg)
        target:ViewPunch(Angle(-7, math.Rand(-5, 5), 0))
        target:EmitSound("ambient/voices/citizen_beaten2.wav", 80, 85)
        NightVisitor.End(self, "attack")
        return
    end

    if now >= (self.NextStep or 0) and not isWatched and self:GetPos():DistToSqr(target:GetPos()) > 220 * 220 then
        self.NextStep = now + math.Rand(2.8, 4.8)
        target:EmitSound("ambient/atmosphere/cave_hit1.wav", 48, math.random(75, 110), 0.42)
    end

    self:NextThink(now)
    return true
end

function ENT:OnTakeDamage()
    -- Ordinary weapons can't kill the apparition; keep your light on it.
end
