ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Эхо-контейнер"
ENT.Category = "Эхо-архив"
ENT.Spawnable = false
ENT.AdminOnly = true
-- RenderGroup не форсируем: движок сам вызывает и Draw (тело), и
-- DrawTranslucent (свечение). Принудительный RENDERGROUP_BOTH заставил бы
-- модель рисоваться дважды.

-- Общие данные редкости: один источник правды для сервера, клиента и HUD.
ENT.RarityNames = {
    [1] = "Обычный",
    [2] = "Необычный",
    [3] = "Редкий",
    [4] = "Легендарный"
}
ENT.RarityColors = {
    [1] = Color(115, 205, 215),
    [2] = Color(95, 215, 135),
    [3] = Color(110, 145, 255),
    [4] = Color(255, 190, 70)
}

function ENT:GetRarity()
    -- Серверное поле EchoRarity выставляется до Spawn(), поэтому Initialize()
    -- не зависит от того, успел ли NWInt разойтись по сети.
    local rarity = tonumber(self.EchoRarity) or self:GetNWInt("EchoRarity", 1)
    return math.Clamp(rarity or 1, 1, 4)
end

function ENT:SetRarity(rarity)
    rarity = math.Clamp(tonumber(rarity) or 1, 1, 4)
    self.EchoRarity = rarity
    self:SetNWInt("EchoRarity", rarity)
end
