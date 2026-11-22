-- Ночной гость: cooperative, asset-free horror encounter for Garry's Mod.
NightVisitor = NightVisitor or {}
NightVisitor.Version = "1.1.0"

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

    hook.Add("PlayerSpawn", "NightVisitor.Respawn", function(ply)
        sanity[ply] = 100
        ply:SetNWFloat("NightVisitorSanity", 100)
    end)

    hook.Add("PlayerDisconnected", "NightVisitor.Disconnect", function(ply)
        if encounter and encounter.target == ply then NightVisitor.End(encounter.ghost, "escaped") end
        sanity[ply] = nil
    end)

    hook.Add("PlayerDeath", "NightVisitor.Death", function(ply)
        if encounter and encounter.target == ply then NightVisitor.End(encounter.ghost, "escaped") end
    end)

    -- Карта меняется / чистится: гость не должен пережить смену раунда.
    hook.Add("PreCleanupMap", "NightVisitor.Cleanup", function()
        if encounter then NightVisitor.End(encounter.ghost, "escaped") end
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
    ---------------------------------------------------------------------
    -- CLIENT
    ---------------------------------------------------------------------

    local cvFX
    do
        cvFX = GetConVar("night_visitor_fx")
        if not cvFX then
            cvFX = CreateClientConVar("night_visitor_fx", "1", true, false, "Эффекты ночного гостя", 0, 1)
        end
    end

    surface.CreateFont("NV.Title", {font = "Roboto", size = 27, weight = 900, antialias = true, extended = true})
    surface.CreateFont("NV.Body", {font = "Roboto", size = 18, weight = 700, antialias = true, extended = true})
    surface.CreateFont("NV.Small", {font = "Roboto", size = 14, weight = 600, antialias = true, extended = true})
    surface.CreateFont("NV.Tiny", {font = "Roboto", size = 12, weight = 700, antialias = true, extended = true})
    surface.CreateFont("NV.Number", {font = "Roboto", size = 20, weight = 900, antialias = true, extended = true})

    local WHITE = Material("vgui/white")
    local NOTICE_LIFETIME = 6.5

    local noticeColors = {
        [0] = Color(160, 176, 190),
        [1] = Color(150, 206, 228),
        [2] = Color(255, 198, 112),
        [3] = Color(255, 96, 108)
    }

    local state = {
        sanity = 100,
        sanityTarget = 100,
        prox = 0,
        proxTarget = 0,
        notices = {},
        lastNotice = 0,
        shakeSeed = 0
    }

    local function clampColor(tbl)
        return Color(
            math.Clamp(math.floor(tbl[1] or 0), 0, 255),
            math.Clamp(math.floor(tbl[2] or 0), 0, 255),
            math.Clamp(math.floor(tbl[3] or 0), 0, 255),
            math.Clamp(math.floor(tbl[4] or 255), 0, 255)
        )
    end

    local function mix(a, b, t)
        t = math.Clamp(t, 0, 1)
        return clampColor({
            a.r + (b.r - a.r) * t,
            a.g + (b.g - a.g) * t,
            a.b + (b.b - a.b) * t,
            (a.a or 255) + ((b.a or 255) - (a.a or 255)) * t
        })
    end

    local CALM = Color(126, 208, 226)
    local WARN = Color(255, 196, 96)
    local PANIC = Color(255, 74, 86)

    local function sanityColor(ratio)
        if ratio > 0.55 then
            return mix(WARN, CALM, (ratio - 0.55) / 0.45)
        end
        return mix(PANIC, WARN, math.Clamp(ratio / 0.55, 0, 1))
    end

    net.Receive(NET_MESSAGE, function()
        local text = net.ReadString()
        local kind = net.ReadUInt(2)
        local now = CurTime()
        table.insert(state.notices, 1, {text = text, kind = kind, time = now})
        state.lastNotice = now
        for i = #state.notices, 6, -1 do
            table.remove(state.notices, i)
        end
        surface.PlaySound(kind == 3 and "buttons/button11.wav" or "buttons/button17.wav")
    end)

    local function drawVignette(strength, baseColor)
        strength = math.Clamp(strength, 0, 1)
        if strength <= 0.012 then return end

        local w, h = ScrW(), ScrH()
        local cx, cy = w * 0.5, h * 0.5
        local outer = math.sqrt(cx * cx + cy * cy)
        local inner = outer * 0.52
        local rings = strength > 0.6 and 6 or 4
        local segments = strength > 0.6 and 32 or 22

        surface.SetMaterial(WHITE)
        for ring = 0, rings - 1 do
            local t0 = ring / rings
            local t1 = (ring + 1) / rings
            local r0 = inner + (outer - inner) * t0
            local r1 = inner + (outer - inner) * t1
            local col0 = clampColor({baseColor.r, baseColor.g, baseColor.b, 255 * strength * t0 ^ 1.7})
            local col1 = clampColor({baseColor.r, baseColor.g, baseColor.b, 255 * strength * t1 ^ 1.7})
            for i = 0, segments - 1 do
                local a0 = (i / segments) * math.pi * 2
                local a1 = ((i + 1) / segments) * math.pi * 2
                local x0, y0 = math.cos(a0), math.sin(a0)
                local x1, y1 = math.cos(a1), math.sin(a1)
                surface.DrawPoly({
                    {x = cx + x0 * r0, y = cy + y0 * r0, color = col0},
                    {x = cx + x1 * r0, y = cy + y1 * r0, color = col0},
                    {x = cx + x1 * r1, y = cy + y1 * r1, color = col1},
                    {x = cx + x0 * r1, y = cy + y0 * r1, color = col1}
                })
            end
        end
    end

    local function drawSanityPanel(ply, haunted, x, y, alphaMul)
        local w, h = 238, 46
        local ratio = math.Clamp(state.sanity / 100, 0, 1)
        local accent = sanityColor(ratio)
        local pulse = 0.5 + 0.5 * math.sin(CurTime() * (haunted and 7.5 or 2.4))

        -- Подложка и тонкая цветная кромка.
        draw.RoundedBox(9, x, y, w, h, Color(9, 10, 15, 214 * alphaMul))
        surface.SetDrawColor(accent.r, accent.g, accent.b, (34 + pulse * 46) * alphaMul)
        surface.DrawRect(x + 1, y, w - 2, 2)
        surface.SetDrawColor(0, 0, 0, 90 * alphaMul)
        surface.DrawOutlinedRect(x + 0.5, y + 0.5, w - 1, h - 1, 1)

        draw.SimpleText("РАССУДОК", "NV.Tiny", x + 13, y + 12, Color(168, 182, 196, 235 * alphaMul), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(math.floor(state.sanity + 0.5) .. "%", "NV.Number", x + w - 13, y + 13, mix(accent, Color(255, 255, 255), 0.25), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

        local barX, barY, barW, barH = x + 13, y + 27, w - 26, 7
        draw.RoundedBox(4, barX, barY, barW, barH, Color(28, 32, 40, 220 * alphaMul))

        local fillW = barW * ratio
        if fillW > 2 then
            local glow = Color(accent.r, accent.g, accent.b, 52 * alphaMul)
            draw.RoundedBox(4, barX - 2, barY - 2, fillW + 4, barH + 4, glow)
            draw.RoundedBox(3, barX, barY, fillW, barH, Color(accent.r, accent.g, accent.b, 240 * alphaMul))
            draw.RoundedBox(3, barX, barY, fillW, math.max(2, math.floor(barH * 0.45)), Color(255, 255, 255, 34 * alphaMul))
        end

        -- Деления каждые 10%: визуальная шкала без растягивания текста.
        surface.SetDrawColor(0, 0, 0, 110 * alphaMul)
        for i = 1, 9 do
            local tickX = math.floor(barX + barW * (i / 10))
            surface.DrawRect(tickX, barY, 1, barH)
        end

        if ratio < 0.3 then
            local danger = 0.35 + 0.65 * pulse
            draw.SimpleText("ОН В ГОЛОВЕ", "NV.Tiny", x + w * 0.5, y + h + 11, Color(255, 96, 104, 210 * danger * alphaMul), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- Указатель на гостя, когда он вне экрана. Направление считается по
    -- разнице углов взгляда (yaw/pitch), поэтому работает и когда гость
    -- позади игрока — старый вариант через скалярное произведение вблизи
    -- «за спиной» показывал неверную сторону.
    local function drawGhostCompass(ghost, ply, alphaMul)
        local center = ghost:WorldSpaceCenter()
        local screen = center:ToScreen()
        if screen.visible then return end

        local eye = ply:EyePos()
        local delta = center - eye
        local ang = ply:EyeAngles()
        local yaw = math.AngleDifference(delta:Angle().y, ang.y)
        local pitch = math.AngleDifference(delta:Angle().p, ang.p)

        local dx = math.sin(math.rad(yaw))
        local dy = -math.sin(math.rad(pitch))
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 0.02 then
            dx, dy, len = (yaw >= 0 and 1 or -1), 0, 1
        end
        dx, dy = dx / len, dy / len

        local w, h = ScrW(), ScrH()
        local cx, cy = w * 0.5, h * 0.5
        local rx, ry = cx - 96, cy - 96
        local px = math.Clamp(cx + dx * rx, 70, w - 70)
        local py = math.Clamp(cy + dy * ry, 70, h - 70)

        local dist = math.floor(eye:Distance(center))
        local pulse = 0.55 + 0.45 * math.sin(CurTime() * 5)
        local size = 7 + pulse * 3
        local dirAngle = math.atan2(dy, dx)

        local ca = math.floor(150 * alphaMul)
        local col = Color(255, 108, 112, ca)
        surface.SetMaterial(WHITE)
        local tip = {x = px + math.cos(dirAngle) * size * 1.5, y = py + math.sin(dirAngle) * size * 1.5}
        local left = {x = px + math.cos(dirAngle + 2.4) * size, y = py + math.sin(dirAngle + 2.4) * size}
        local right = {x = px + math.cos(dirAngle - 2.4) * size, y = py + math.sin(dirAngle - 2.4) * size}
        surface.DrawPoly({
            {x = tip.x, y = tip.y, color = col},
            {x = left.x, y = left.y, color = col},
            {x = right.x, y = right.y, color = col}
        })
        draw.SimpleText(dist .. " u", "NV.Tiny", px, py + 17,
            Color(255, 150, 150, math.floor(175 * alphaMul)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local function drawNotice(notice, slot, now, alphaMul)
        local age = now - notice.time
        local alphaIn = math.Clamp(age / 0.22, 0, 1)
        local alphaOut = math.Clamp((NOTICE_LIFETIME - age) / 0.6, 0, 1)
        local alpha = math.min(alphaIn, alphaOut) * alphaMul
        if alpha <= 0.01 then return end

        local col = noticeColors[notice.kind] or noticeColors[1]
        local text = notice.text
        surface.SetFont("NV.Body")
        local tw = surface.GetTextSize(text)
        local boxW = math.min(ScrW() - 160, tw + 46)
        local boxH = 38
        local cx = ScrW() * 0.5
        local baseY = ScrH() * 0.76 + slot * (boxH + 7)
        local slide = (1 - alphaIn) * 16

        local x = cx - boxW * 0.5
        local y = baseY + slide
        draw.RoundedBox(6, x, y, boxW, boxH, Color(8, 10, 14, 208 * alpha))
        surface.SetDrawColor(col.r, col.g, col.b, 220 * alpha)
        surface.DrawRect(x, y, 3, boxH)
        surface.SetDrawColor(col.r, col.g, col.b, 26 * alpha)
        surface.DrawRect(x + 3, y, boxW - 3, boxH)

        draw.SimpleText(text, "NV.Body", cx + 4, y + boxH * 0.5 - 1, Color(col.r, col.g, col.b, 245 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    hook.Add("HUDPaint", "NightVisitor.HUD", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then return end

        local dt = math.Clamp(FrameTime() or 0, 0, 0.1)
        local haunted = ply:GetNWBool("NightVisitorHaunted", false)
        local sanityTarget = math.Clamp(ply:GetNWFloat("NightVisitorSanity", 100), 0, 100)
        local ghost = ply:GetNWEntity("NightVisitorGhost")

        local proxTarget = 0
        if haunted and IsValid(ghost) then
            local dist = ply:GetPos():Distance(ghost:GetPos())
            proxTarget = math.Clamp(1 - (dist - 90) / 700, 0, 1)
        end

        state.sanityTarget = sanityTarget
        state.proxTarget = proxTarget
        state.sanity = Lerp(math.min(1, 1 - math.exp(-dt * 9)), state.sanity, state.sanityTarget)
        state.prox = Lerp(math.min(1, 1 - math.exp(-dt * 4.5)), state.prox, state.proxTarget)

        local now = CurTime()
        local strength = math.Clamp((100 - state.sanity) / 100, 0, 1)
        local fxOn = cvFX and cvFX:GetBool()

        -- Виньетка: мягкая рамка при потере рассудка, плюс «дыхание» рядом с гостем.
        if fxOn then
            local pulse = 0.55 + 0.45 * math.sin(now * (haunted and 6.2 or 2.1))
            local vig = strength * 0.55 + state.prox * 0.5 * pulse + (haunted and 0.08 or 0)
            local tint = mix(Color(8, 6, 12), Color(58, 3, 10), math.Clamp(state.prox * 0.85 + strength * 0.25, 0, 1))
            drawVignette(math.Clamp(vig, 0, 0.92), tint)
        end

        drawSanityPanel(ply, haunted, ScrW() - 258, ScrH() - 74, 1)

        -- Подсказка про фонарь, пока он выключен.
        if haunted and not ply:FlashlightIsOn() and (now % 1.6) < 1.15 then
            local hintAlpha = 0.7 + 0.3 * math.sin(now * 6)
            draw.SimpleText("[F]  ВКЛЮЧИ ФОНАРЬ", "NV.Body", ScrW() * 0.5, ScrH() * 0.88, Color(255, 214, 190, 225 * hintAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        if haunted then
            local text, sub = "КТО-ТО ЗДЕСЬ…", ""
            if IsValid(ghost) then
                local dist = math.floor(ply:GetPos():Distance(ghost:GetPos()))
                text = "ОН РЯДОМ"
                sub = dist .. " u  •  ДЕРЖИ СВЕТ НА НЁМ"
                drawGhostCompass(ghost, ply, 1)
            end
            local bob = math.sin(now * 2.4) * 2
            local alpha = 200 + math.sin(now * 7) * 45
            draw.SimpleText(text, "NV.Title", ScrW() * 0.5 + 1, ScrH() * 0.15 + bob, Color(120, 0, 8, 120 * (alpha / 255)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(text, "NV.Title", ScrW() * 0.5, ScrH() * 0.15 + bob, Color(255, 222, 210, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            if sub ~= "" then
                draw.SimpleText(sub, "NV.Small", ScrW() * 0.5, ScrH() * 0.15 + 26 + bob, Color(248, 172, 158, 190), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        local slot = 0
        for i = #state.notices, 1, -1 do
            local notice = state.notices[i]
            local age = now - notice.time
            if age > NOTICE_LIFETIME then
                table.remove(state.notices, i)
            else
                drawNotice(notice, slot, now, 1)
                slot = slot + 1
            end
        end
    end)

    -- Пост-эффект: обесцвечивание и красная «плёнка», когда гость близко.
    hook.Add("RenderScreenspaceEffects", "NightVisitor.FX", function()
        if not cvFX or not cvFX:GetBool() then return end
        local haunted = LocalPlayer() and LocalPlayer():GetNWBool("NightVisitorHaunted", false)
        local prox = state.prox
        if not haunted and prox < 0.02 then return end

        local saturation = math.Clamp(1 - prox * 0.55 - (haunted and 0.08 or 0), 0.3, 1)
        DrawColorModify({
            ["$pp_colour_addr"] = prox * 0.06 + (haunted and 0.01 or 0),
            ["$pp_colour_addg"] = 0,
            ["$pp_colour_addb"] = 0,
            ["$pp_colour_brightness"] = -prox * 0.02,
            ["$pp_colour_contrast"] = 1 + prox * 0.12,
            ["$pp_colour_colour"] = saturation,
            ["$pp_colour_mulr"] = 1 + prox * 0.04,
            ["$pp_colour_mulg"] = 1 - prox * 0.03,
            ["$pp_colour_mulb"] = 1 - prox * 0.04
        })
    end)

    hook.Add("OnPlayerChat", "NightVisitor.HideCommands", function(ply, text)
        if ply == LocalPlayer() and string.lower(text) == "/haunt" then return true end
    end)
end
