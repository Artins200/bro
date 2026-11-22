AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/props_junk/wood_crate001a.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    self:SetHealth(1)
    self:DrawShadow(true)

    -- Никакого models/shiny и тонировки на всю модель: дерево остаётся
    -- деревом, а редкость показывает свечение и голограмма на клиенте.
    local rarity = self:GetRarity()
    self:SetNWInt("EchoRarity", rarity)
    self:SetNWFloat("EchoSpawned", CurTime())

    -- Без расширенных границ луч, ромб и подпись пропадают, как только сама
    -- модель выходит из пирамиды видимости (движок отсекает всю сущность).
    self:SetRenderBounds(Vector(-80, -80, -32), Vector(80, 80, 200))

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:SetMass(60)
        phys:SetBuoyancyRatio(0)
        phys:EnableMotion(false)
    end
end

function ENT:Use(activator)
    if self.EchoClaimed or not IsValid(activator) or not activator:IsPlayer() or not activator:Alive() then return end
    -- Страховочная проверка дистанции: PlayerUse-хук в autorun тоже блокирует
    -- дальний доступ, но Use не должен полагаться только на него.
    if activator:GetPos():DistToSqr(self:GetPos()) > 170 * 170 then return end
    self.EchoClaimed = true
    local rarity = self:GetRarity()
    if EchoArchive and EchoArchive.GiveLoot then EchoArchive.GiveLoot(activator, rarity) end
    self:EmitSound("items/itempickup.wav", 75, 90 + rarity * 5)
    local effect = EffectData()
    effect:SetOrigin(self:WorldSpaceCenter())
    effect:SetScale(0.8 + rarity * 0.2)
    util.Effect("cball_explode", effect, true, true)
    self:Remove()
end

function ENT:OnTakeDamage(dmg)
    -- Архив собирают, а не разбивают пулями и физикой.
    if dmg:GetDamage() > 0 then self:SetHealth(1) end
end
