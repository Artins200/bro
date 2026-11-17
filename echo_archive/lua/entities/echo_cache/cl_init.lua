include("shared.lua")

local rarityColors = {
    [1] = Color(100, 220, 225), [2] = Color(100, 230, 145),
    [3] = Color(125, 155, 255), [4] = Color(255, 195, 75)
}
local glow = Material("sprites/light_glow02_add")

function ENT:Draw()
    self:DrawModel()
    local rarity = math.Clamp(self:GetNWInt("EchoRarity", 1), 1, 4)
    local col = rarityColors[rarity]
    local scale = 26 + math.sin(CurTime() * 2.5 + self:EntIndex()) * 3
    render.SetMaterial(glow)
    render.DrawSprite(self:GetPos() + Vector(0, 0, 26), scale, scale, Color(col.r, col.g, col.b, 145))
end

function ENT:DrawTranslucent()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local dist = ply:GetPos():DistToSqr(self:GetPos())
    if dist > 280 * 280 then return end
    local names = {[1] = "ОБЫЧНЫЙ", [2] = "НЕОБЫЧНЫЙ", [3] = "РЕДКИЙ", [4] = "ЛЕГЕНДАРНЫЙ"}
    local rarity = math.Clamp(self:GetNWInt("EchoRarity", 1), 1, 4)
    local col = rarityColors[rarity]
    local pos = self:GetPos() + Vector(0, 0, 38)
    local ang = (EyePos() - pos):Angle()
    ang:RotateAroundAxis(ang:Right(), 90)
    ang:RotateAroundAxis(ang:Up(), -90)
    cam.Start3D2D(pos, ang, 0.08)
        draw.SimpleTextOutlined("ЭХО-КОНТЕЙНЕР", "EchoArchive.Body", 0, 0, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(5, 8, 12, 230))
        draw.SimpleTextOutlined(names[rarity] .. "  •  [E] ИЗВЛЕЧЬ", "EchoArchive.Small", 0, 20, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(5, 8, 12, 230))
    cam.End3D2D()
end
