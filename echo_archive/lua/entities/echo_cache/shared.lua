ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Эхо-контейнер"
ENT.Category = "Эхо-архив"
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetRarity(rarity)
    self:SetNWInt("EchoRarity", math.Clamp(tonumber(rarity) or 1, 1, 4))
end
