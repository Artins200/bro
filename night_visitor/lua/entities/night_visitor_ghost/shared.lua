ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Ночной гость"
ENT.Category = "Ночной гость"
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

function ENT:SetTarget(ply)
    self:SetNWEntity("NightVisitorTarget", ply)
end
