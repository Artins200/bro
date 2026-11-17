-- Ночной гость: cooperative, asset-free horror encounter for Garry's Mod.
NightVisitor = NightVisitor or {}
NightVisitor.Version = "1.0.0"

local NET_MESSAGE = "night_visitor_message"

if SERVER then
    AddCSLuaFile()
    util.AddNetworkString(NET_MESSAGE)

    NightVisitor.Config = {
        FirstVisitDelay = 25,
        MinInterval = 65,
        MaxInterval = 105,
        EncounterLength = 42,
        SpawnDistance = 620,
        SanityDrain = 0.8,
        RepelTime = 2.6,
        MaxPlayersPerGhost = 1
    }

    local encounter
    local sanity = setmetatable({}, {__mode = "k"})
    local spookySounds = {
        "ambient/atmosphere/cave_hit1.wav",
        "ambient/atmosphere/cave_hit2.wav",
        "ambient/voices/citizen_beaten1.wav",
        "ambient/voices/citizen_beaten3.wav"
    }

    local function message(ply, text, kind)
        if not IsValid(ply) then return end
        net.Start(NET_MESSAGE)
        net.WriteString(string.sub(tostring(text), 1, 220))
        net.WriteUInt(kind or 0, 2)
        net.Send(ply)
    end
    NightVisitor.Message = message

    local function activePlayers()
        local result = {}
        for _, ply in ipairs(player.GetHumans()) do
            if IsValid(ply) and ply:Alive() and not ply:InVehicle() then
                result[#result + 1] = ply
            end
        end
        return result
    end

    local function findSpawn(ply)
        local back = -ply:GetForward():GetNormalized()
        for attempt = 1, 10 do
            local side = Vector(0, 0, 0)
            if attempt > 1 then side = ply:GetRight() * math.Rand(-220, 220) end
            local distance = NightVisitor.Config.SpawnDistance + math.Rand(-100, 100)
            local origin = ply:GetPos() + back * distance + side + Vector(0, 0, 500)
            local tr = util.TraceHull({
                start = origin,
                endpos = origin - Vector(0, 0, 1500),
                mins = Vector(-18, -18, 0),
                maxs = Vector(18, 18, 76),
                mask = MASK_SOLID,
                filter = ply
            })
            if tr.Hit and not tr.HitSky and not tr.StartSolid and tr.HitNormal.z > 0.65 then
                local pos = tr.HitPos + Vector(0, 0, 4)
                local clear = util.TraceHull({
                    start = pos,
                    endpos = pos + Vector(0, 0, 1),
                    mins = Vector(-18, -18, 0),
                    maxs = Vector(18, 18, 76),
                    mask = MASK_SOLID,
                    filter = ply
                })
                if not clear.Hit and not clear.StartSolid and pos:DistToSqr(ply:GetPos()) > 300 * 300 then return pos end
            end
        end
        return ply:GetPos() + back * 500 + Vector(0, 0, 8)
    end

    function NightVisitor.End(ghost, reason)
        if not encounter or (IsValid(ghost) and encounter.ghost ~= ghost) then return end
        local old = encounter
        encounter = nil
        if IsValid(old.target) then
            old.target:SetNWBool("NightVisitorHaunted", false)
            old.target:SetNWEntity("NightVisitorGhost", NULL)
            if reason == "repelled" then
                message(old.target, "ОН ОТСТУПИЛ. Не гаси фонарь.", 2)
                sanity[old.target] = math.min(100, (sanity[old.target] or 100) + 12)
                old.target:EmitSound("ambient/atmosphere/cave_hit2.wav", 65, 125)
            elseif reason == "attack" then
                message(old.target, "Он коснулся тебя. Вдохни. Пока что он ушёл.", 3)
            elseif reason == "escaped" then
                message(old.target, "Тишина вернулась. Но ненадолго.", 1)
            end
        end
        if IsValid(ghost) and not ghost.NightVisitorRemoving then
            ghost.NightVisitorRemoving = true
            ghost:Remove()
        end
    end

    function NightVisitor.Start(ply)
        if encounter then return false end
        if not IsValid(ply) then
            local choices = activePlayers()
            if #choices == 0 then return false end
            ply = table.Random(choices)
        end
        if not ply:IsPlayer() or not ply:Alive() then return false end

        encounter = {target = ply, started = CurTime(), ends = CurTime() + NightVisitor.Config.EncounterLength}
        sanity[ply] = sanity[ply] or 100
        ply:SetNWBool("NightVisitorHaunted", true)
        message(ply, "Тебе показалось, что кто-то позвал тебя по имени…", 1)
        ply:EmitSound(table.Random(spookySounds), 65, math.random(75, 95))
        ply:ScreenFade(SCREENFADE.IN, Color(18, 5, 24, 100), 0.8, 0.15)

        timer.Simple(3.5, function()
            if not encounter or encounter.target ~= ply or not IsValid(ply) or not ply:Alive() then
                if encounter and encounter.target == ply then NightVisitor.End(nil, "escaped") end
                return
            end
            local ghost = ents.Create("night_visitor_ghost")
            if not IsValid(ghost) then NightVisitor.End(nil, "escaped") return end
            ghost:SetPos(findSpawn(ply))
            ghost:SetTarget(ply)
            ghost:Spawn()
            ghost:Activate()
            encounter.ghost = ghost
            encounter.ends = CurTime() + NightVisitor.Config.EncounterLength
            ply:SetNWEntity("NightVisitorGhost", ghost)
            message(ply, "ФОНАРЬ ВКЛЮЧИ. ДЕРЖИ ЕГО В ПОЛЕ ЗРЕНИЯ.", 2)
        end)
        return true
    end

    concommand.Add("night_visitor_start", function(ply)
        if IsValid(ply) and not ply:IsAdmin() then return end
        if not NightVisitor.Start(IsValid(ply) and ply or nil) and IsValid(ply) then
            message(ply, "Гость уже здесь или нет подходящих игроков.", 0)
        end
    end)

    concommand.Add("night_visitor_help", function(ply)
        if IsValid(ply) then
            message(ply, "Выживание: замечай силуэт, включи фонарь клавишей F и непрерывно держи его в прицеле. Игроки могут помогать друг другу.", 1)
        end
    end)

    hook.Add("PlayerSay", "NightVisitor.ChatCommands", function(ply, text)
        local cmd = string.Trim(string.lower(text))
        if cmd == "/haunt" or cmd == "!haunt" then
            message(ply, "Выживание: замечай силуэт, включи фонарь клавишей F и непрерывно держи его в прицеле. Игроки могут помогать друг другу.", 1)
            return ""
        end
    end)

    hook.Add("PlayerInitialSpawn", "NightVisitor.PlayerSetup", function(ply)
        sanity[ply] = 100
        ply:SetNWFloat("NightVisitorSanity", 100)
        ply:SetNWBool("NightVisitorHaunted", false)
        timer.Simple(4, function()
            if IsValid(ply) then message(ply, "Ночной гость: /haunt — правила. Ты не один на этой карте.", 1) end
        end)
    end)

    hook.Add("PlayerDisconnected", "NightVisitor.Disconnect", function(ply)
        if encounter and encounter.target == ply then NightVisitor.End(encounter.ghost, "escaped") end
        sanity[ply] = nil
    end)

    hook.Add("PlayerDeath", "NightVisitor.Death", function(ply)
        if encounter and encounter.target == ply then NightVisitor.End(encounter.ghost, "escaped") end
    end)

    timer.Create("NightVisitor.Director", 1, 0, function()
        if encounter then
            if not IsValid(encounter.target) or not encounter.target:Alive() then
                NightVisitor.End(encounter.ghost, "escaped")
            elseif CurTime() > encounter.ends then
                NightVisitor.End(encounter.ghost, "escaped")
            end
        end
        for _, ply in ipairs(player.GetHumans()) do
            if IsValid(ply) then
                local value = sanity[ply] or 100
                if encounter and encounter.target == ply then
                    value = math.max(0, value - NightVisitor.Config.SanityDrain)
                else
                    value = math.min(100, value + 0.12)
                end
                sanity[ply] = value
                ply:SetNWFloat("NightVisitorSanity", value)
            end
        end
    end)

    local function scheduleVisit(delay)
        timer.Simple(delay, function()
            if not encounter then NightVisitor.Start(nil) end
            scheduleVisit(math.Rand(NightVisitor.Config.MinInterval, NightVisitor.Config.MaxInterval))
        end)
    end
    scheduleVisit(NightVisitor.Config.FirstVisitDelay)
else
    surface.CreateFont("NightVisitor.Title", {font = "Trebuchet24", size = 22, weight = 900, antialias = true})
    surface.CreateFont("NightVisitor.Body", {font = "Trebuchet18", size = 18, weight = 700, antialias = true})
    surface.CreateFont("NightVisitor.Small", {font = "Trebuchet18", size = 15, weight = 600, antialias = true})

    local messages = {}
    local colors = {
        [0] = Color(175, 190, 205), [1] = Color(184, 213, 224),
        [2] = Color(255, 204, 124), [3] = Color(255, 95, 110)
    }
    net.Receive(NET_MESSAGE, function()
        messages[#messages + 1] = {text = net.ReadString(), kind = net.ReadUInt(2), time = CurTime()}
        surface.PlaySound("buttons/button17.wav")
    end)

    hook.Add("HUDPaint", "NightVisitor.HUD", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        local haunted = ply:GetNWBool("NightVisitorHaunted", false)
        local sanity = math.Clamp(ply:GetNWFloat("NightVisitorSanity", 100), 0, 100)
        local strength = math.Clamp((100 - sanity) / 100, 0, 1)
        if haunted or strength > 0.05 then
            local pulse = 0.45 + math.sin(CurTime() * (haunted and 8 or 3)) * 0.2
            local alpha = math.floor(strength * pulse * 75 + (haunted and 12 or 0))
            surface.SetDrawColor(35, 5, 15, alpha)
            surface.DrawRect(0, 0, ScrW(), 32)
            surface.DrawRect(0, ScrH() - 32, ScrW(), 32)
            surface.DrawRect(0, 0, 30, ScrH())
            surface.DrawRect(ScrW() - 30, 0, 30, ScrH())

            local w, x, y = 190, ScrW() - 220, ScrH() - 50
            draw.RoundedBox(6, x, y, w, 22, Color(8, 9, 13, 205))
            local bar = sanity / 100
            draw.RoundedBox(4, x + 3, y + 3, (w - 6) * bar, 16, Color(100 + math.floor((1 - bar) * 130), 175 - math.floor((1 - bar) * 100), 190 - math.floor((1 - bar) * 110), 230))
            draw.SimpleText("РАССУДОК  " .. math.floor(sanity) .. "%", "NightVisitor.Small", x + w / 2, y + 11, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        if haunted then
            local text = "НЕ ДАЙ ЕМУ ПОДОЙТИ"
            local ghost = ply:GetNWEntity("NightVisitorGhost")
            if IsValid(ghost) then
                local dist = math.floor(ply:GetPos():Distance(ghost:GetPos()))
                text = "ОН РЯДОМ  •  " .. dist .. " u  •  СВЕТИ ФОНАРЁМ"
            else
                text = "КТО-ТО ЗДЕСЬ…"
            end
            draw.SimpleText(text, "NightVisitor.Body", ScrW() / 2, ScrH() * 0.18 + math.sin(CurTime() * 3) * 2, Color(255, 220, 205), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        for i = #messages, 1, -1 do
            local item = messages[i]
            local age = CurTime() - item.time
            if age > 5 then
                table.remove(messages, i)
            else
                local alpha = math.floor(math.min(255, (5 - age) * 180))
                local col = colors[item.kind] or colors[1]
                draw.SimpleTextOutlined(item.text, "NightVisitor.Body", ScrW() / 2, ScrH() * 0.73 + (#messages - i) * 28, Color(col.r, col.g, col.b, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, alpha))
            end
        end
    end)

    hook.Add("OnPlayerChat", "NightVisitor.HideCommands", function(ply, text)
        if ply == LocalPlayer() and string.lower(text) == "/haunt" then return true end
    end)
end
