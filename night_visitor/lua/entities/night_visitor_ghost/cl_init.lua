include("shared.lua")

local eyeGlow = Material("sprites/light_glow02_add")

function ENT:Draw()
    self:DrawModel()
    local eye = self:GetPos() + Vector(0, 0, 61)
    render.SetMaterial(eyeGlow)
    render.DrawSprite(eye + self:GetForward() * 8 - self:GetRight() * 5, 5, 5, Color(255, 30, 38, 220))
    render.DrawSprite(eye + self:GetForward() * 8 + self:GetRight() * 5, 5, 5, Color(255, 30, 38, 220))
end

function ENT:DrawTranslucent()
    self:Draw()
end
