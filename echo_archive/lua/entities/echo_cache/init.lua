AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

local rarityNames = {[1] = "Обычный", [2] = "Необычный", [3] = "Редкий", [4] = "Легендарный"}
local rarityColors = {
    [1] = Color(115, 200, 210), [2] = Color(90, 205, 130),
    [3] = Color(95, 130, 255), [4] = Color(255, 185, 65)
}

function ENT:Initialize()
    self:SetModel("models/props_junk/wood_crate001a.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    self:SetHealth(1)
    local rarity = math.Clamp(self:GetNWInt("EchoRarity", 1), 1, 4)
    self:SetColor(rarityColors[rarity])
    self:SetMaterial("models/shiny")
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:SetMass(60)
        phys:EnableMotion(false)
    end
    self:SetNWString("EchoRarityName", rarityNames[rarity])
    self:SetNWFloat("EchoSpawned", CurTime())
end

function ENT:Use(activator)
    if self.EchoClaimed or not IsValid(activator) or not activator:IsPlayer() or not activator:Alive() then return end
    self.EchoClaimed = true
    local rarity = self:GetNWInt("EchoRarity", 1)
    if EchoArchive and EchoArchive.GiveLoot then EchoArchive.GiveLoot(activator, rarity) end
    self:EmitSound("items/itempickup.wav", 75, 90 + rarity * 5)
    local effect = EffectData()
    effect:SetOrigin(self:WorldSpaceCenter())
    effect:SetScale(0.8 + rarity * 0.2)
    util.Effect("cball_explode", effect, true, true)
    self:Remove()
end

function ENT:OnTakeDamage(dmg)
    -- The archive is collected, not destroyed by stray bullets or physics damage.
    if dmg:GetDamage() > 0 then self:SetHealth(1) end
end
