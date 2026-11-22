ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Ночной гость"
ENT.Category = "Ночной гость"
ENT.Spawnable = false
ENT.AdminOnly = true
-- RenderGroup намеренно НЕ задаём. Движок сам подберёт группу по модели и всё
-- равно вызовет DrawTranslucent для эффектов — это штатный и предпочтительный
-- путь (см. структуру ENT на вики). Если форсировать RENDERGROUP_BOTH, модель
-- начнёт рисоваться в обоих проходах и «двоится».
--
-- Draw рисует тело, DrawTranslucent — только свечение, шлейф и глаза.

-- Модель и «якоря» для глаз. Общие данные, чтобы клиент и сервер не расходились.
ENT.GhostModel = "models/player/charple.mdl"
ENT.GhostScale = 1.08
ENT.EyeAttachment = "eyes"

function ENT:SetTarget(ply)
    self:SetNWEntity("NightVisitorTarget", ply)
end

function ENT:GetTarget()
    return self:GetNWEntity("NightVisitorTarget")
end

function ENT:GetEyeData()
    local attachment = self:LookupAttachment(self.EyeAttachment or "eyes")
    if attachment and attachment > 0 then
        local data = self:GetAttachment(attachment)
        if data and data.Pos then return data.Pos, data.Ang end
    end
    local bone = self:LookupBone("ValveBiped.Bip01_Head1")
    if bone then
        local pos = self:GetBonePosition(bone)
        if pos then
            return pos + self:GetForward() * 4.5 + self:GetUp() * 3.5, self:GetAngles()
        end
    end
    return self:GetPos() + Vector(0, 0, 64), self:GetAngles()
end
