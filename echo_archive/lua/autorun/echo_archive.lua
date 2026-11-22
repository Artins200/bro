-- Эхо-архив: standalone scavenging addon for Garry's Mod.
EchoArchive = EchoArchive or {}
EchoArchive.Version = "2.0.0"

local NET_PING = "echo_archive_ping"
local NET_NOTIFY = "echo_archive_notify"
local NET_STATS = "echo_archive_stats"
local NET_STORM = "echo_archive_storm"
local NET_SCAN = "echo_archive_scanstate"

-- Конфиг общий для клиента и сервера: HUD показывает те же цифры, что и логика.
EchoArchive.Config = EchoArchive.Config or {
    MaxCaches = 12,
    SpawnInterval = 35,
    ScanRange = 4000,
    ScanCooldown = 10,
    StormDuration = 150,
    StormCooldown = 600,
    StartCaches = 5
}

if SERVER then
    AddCSLuaFile()
    util.AddNetworkString(NET_PING)
    util.AddNetworkString(NET_NOTIFY)
    util.AddNetworkString(NET_STATS)
    util.AddNetworkString(NET_STORM)
    util.AddNetworkString(NET_SCAN)

    local profiles = {}   -- [steamid64] = данные; не привязаны к энтити и не текут
    local dirty = {}      -- [steamid64] = true, сбрасывается пачкой
    local scanReady = {}  -- [steamid64] = CurTime(), когда сканер снова готов
    local stormEnds, stormNext = 0, 0

    sql.Query("CREATE TABLE IF NOT EXISTS echo_archive_profiles (steamid TEXT PRIMARY KEY, level INTEGER NOT NULL, xp INTEGER NOT NULL, credits INTEGER NOT NULL, finds INTEGER NOT NULL)")

    local function xpForLevel(level)
        return 100 + math.max(0, level - 1) * 50
    end

    local function profile(ply)
        if not IsValid(ply) then return nil end
        local id = ply:SteamID64()
        local data = profiles[id]
        if not data then
            data = {level = 1, xp = 0, credits = 0, finds = 0}
            profiles[id] = data
        end
        return data, id
    end

    local function saveProfile(id)
        local data = profiles[id]
        if not data then return end
        sql.Query("REPLACE INTO echo_archive_profiles (steamid, level, xp, credits, finds) VALUES (" ..
            sql.SQLStr(id) .. ", " .. data.level .. ", " .. data.xp .. ", " .. data.credits .. ", " .. data.finds .. ")")
        dirty[id] = nil
    end

    local function markDirty(id)
        dirty[id] = true
    end

    local function sendStats(ply)
        local data = profile(ply)
        if not data then return end
        net.Start(NET_STATS)
        net.WriteUInt(math.Clamp(data.level, 1, 65535), 16)
        net.WriteUInt(math.Clamp(data.xp, 0, 16777215), 24)
        net.WriteUInt(math.Clamp(xpForLevel(data.level), 1, 16777215), 24)
        net.WriteUInt(math.Clamp(data.credits, 0, 4294967295), 32)
        net.WriteUInt(math.Clamp(data.finds, 0, 16777215), 24)
        net.Send(ply)
    end

    local function notify(ply, text, kind)
        if not IsValid(ply) then return end
        net.Start(NET_NOTIFY)
        net.WriteString(string.sub(tostring(text), 1, 220))
        net.WriteUInt(math.Clamp(kind or 0, 0, 3), 2)
        net.Send(ply)
    end

    local function sendScanState(ply, readyAt)
        if not IsValid(ply) then return end
        net.Start(NET_SCAN)
        net.WriteFloat(math.max(0, readyAt - CurTime()))
        net.Send(ply)
    end

    local function sendStorm(ply)
        net.Start(NET_STORM)
        net.WriteFloat(stormEnds)
        net.WriteFloat(stormNext)
        if IsValid(ply) then net.Send(ply) else net.Broadcast() end
    end

    hook.Add("PlayerInitialSpawn", "EchoArchive.LoadProfile", function(ply)
        -- Профиль создаётся сразу: находка в первую секунду больше не теряется.
        profile(ply)
        sendScanState(ply, 0)
        timer.Simple(1, function()
            if not IsValid(ply) then return end
            local data, id = profile(ply)
            if not data then return end
            local rows = sql.Query("SELECT level, xp, credits, finds FROM echo_archive_profiles WHERE steamid = " .. sql.SQLStr(id))
            local row = istable(rows) and rows[1] or nil
            if row then
                data.level = math.max(1, tonumber(row.level) or 1)
                data.xp = math.max(0, tonumber(row.xp) or 0)
                data.credits = math.max(0, tonumber(row.credits) or 0)
                data.finds = math.max(0, tonumber(row.finds) or 0)
            else
                markDirty(id)
            end
            sendStats(ply)
        end)
    end)

    hook.Add("PlayerInitialSpawn", "EchoArchive.StormState", function(ply)
        timer.Simple(2, function()
            if IsValid(ply) then sendStorm(ply) end
        end)
    end)

    hook.Add("PlayerDisconnected", "EchoArchive.SaveProfile", function(ply)
        local id = ply:SteamID64()
        saveProfile(id)
        profiles[id] = nil
        dirty[id] = nil
        scanReady[id] = nil
    end)

    hook.Add("ShutDown", "EchoArchive.SaveAll", function()
        for id in pairs(profiles) do saveProfile(id) end
    end)

    -- Пачка сохранений вместо запроса на каждую находку.
    timer.Create("EchoArchive.Flush", 8, 0, function()
        for id in pairs(dirty) do saveProfile(id) end
    end)

    -- Смерть/смена карты: не теряем до 8 секунд прогресса и не оставляем
    -- призрачные контейнеры после респавна на арене.
    hook.Add("PlayerDeath", "EchoArchive.FlushOnDeath", function(ply)
        local id = ply:SteamID64()
        if dirty[id] then saveProfile(id) end
    end)

    hook.Add("PreCleanupMap", "EchoArchive.FlushOnCleanup", function()
        for id in pairs(dirty) do saveProfile(id) end
        for _, ent in ipairs(ents.FindByClass("echo_cache")) do
            if IsValid(ent) then ent:Remove() end
        end
    end)

    local REWARDS = {
        [1] = {xp = 20, credits = 15, label = "Пыльный контейнер"},
        [2] = {xp = 35, credits = 30, label = "Стабильный сигнал"},
        [3] = {xp = 60, credits = 65, label = "Редкий архив"},
        [4] = {xp = 100, credits = 150, label = "Золотой фрагмент"}
    }

    local function giveLoot(ply, rarity)
        local data, id = profile(ply)
        if not data then return end
        rarity = math.Clamp(tonumber(rarity) or 1, 1, 4)
        local reward = REWARDS[rarity] or REWARDS[1]
        data.xp = data.xp + reward.xp
        data.credits = data.credits + reward.credits
        data.finds = data.finds + 1
        local levels = 0
        while data.xp >= xpForLevel(data.level) and data.level < 65535 do
            data.xp = data.xp - xpForLevel(data.level)
            data.level = data.level + 1
            levels = levels + 1
        end
        notify(ply, reward.label .. ": +" .. reward.xp .. " опыта, +" .. reward.credits .. " эхо-кредитов.", rarity >= 3 and 2 or 1)
        if levels > 0 then
            notify(ply, "Новый уровень архивиста: " .. data.level .. "!", 2)
            ply:EmitSound("garrysmod/content_downloaded.wav", 70, 105)
        else
            ply:EmitSound("items/ammo_pickup.wav", 65, 105)
        end
        markDirty(id)
        sendStats(ply)
    end

    EchoArchive.GiveLoot = giveLoot

    local function cacheCount()
        return #ents.FindByClass("echo_cache")
    end

    local function chooseRarity()
        local roll = math.Rand(0, 100)
        if CurTime() < stormEnds then
            if roll < 10 then return 4 end
            if roll < 35 then return 3 end
            if roll < 67 then return 2 end
            return 1
        end
        if roll < 4 then return 4 end
        if roll < 17 then return 3 end
        if roll < 45 then return 2 end
        return 1
    end

    local function randomGroundPosition(ply)
        local center = ply:GetPos()
        for _ = 1, 14 do
            local angle = math.Rand(0, math.pi * 2)
            local distance = math.Rand(650, 1800)
            local start = center + Vector(math.cos(angle) * distance, math.sin(angle) * distance, 1400)
            local tr = util.TraceHull({
                start = start,
                endpos = start - Vector(0, 0, 3200),
                mins = Vector(-19, -19, 0),
                maxs = Vector(19, 19, 52),
                mask = MASK_SOLID,
                filter = ply
            })
            if tr.Hit and not tr.HitSky and tr.HitNormal.z > 0.7 and not tr.StartSolid then
                local pos = tr.HitPos + Vector(0, 0, 2)
                local clear = util.TraceHull({
                    start = pos,
                    endpos = pos + Vector(0, 0, 50),
                    mins = Vector(-21, -21, 0),
                    maxs = Vector(21, 21, 52),
                    mask = MASK_SOLID,
                    filter = ply
                })
                if not clear.Hit and not clear.StartSolid then return pos end
            end
        end
    end

    local function spawnCache(pos, rarity)
        if not pos or cacheCount() >= EchoArchive.Config.MaxCaches then return nil end
        local ent = ents.Create("echo_cache")
        if not IsValid(ent) then return nil end
        ent:SetPos(pos)
        ent:SetAngles(Angle(0, math.Rand(0, 360), 0))
        ent:SetRarity(rarity or chooseRarity())
        ent:Spawn()
        ent:Activate()
        if ent:GetRarity() >= 3 then
            ent:EmitSound("ambient/energy/spark3.wav", 55, math.random(95, 112))
        end
        return ent
    end

    EchoArchive.SpawnCache = spawnCache

    local function startStorm(byPlayer)
        if CurTime() < stormNext then
            if IsValid(byPlayer) then
                notify(byPlayer, "Резонанс ещё остывает. Попробуй позже.", 0)
            end
            return false
        end
        stormEnds = CurTime() + EchoArchive.Config.StormDuration
        stormNext = CurTime() + EchoArchive.Config.StormCooldown
        for _, ply in ipairs(player.GetAll()) do
            notify(ply, "РЕЗОНАНСНАЯ БУРЯ! Редкие архивы чаще, новые сигналы появляются быстрее.", 2)
            ply:EmitSound("ambient/energy/force_field_loop1.wav", 60, 100)
        end
        sendStorm(nil)
        return true
    end

    concommand.Add("echo_archive_event", function(ply)
        if IsValid(ply) and not ply:IsAdmin() then return end
        startStorm(ply)
    end)

    concommand.Add("echo_archive_spawn", function(ply)
        if IsValid(ply) and not ply:IsAdmin() then return end
        local pos
        if IsValid(ply) then
            local tr = ply:GetEyeTrace()
            if tr.Hit and not tr.HitSky then pos = tr.HitPos + tr.HitNormal * 14 end
        else
            local humans = player.GetHumans()
            if IsValid(humans[1]) then pos = humans[1]:GetPos() + Vector(0, 0, 48) end
        end
        if pos then spawnCache(pos) end
    end)

    local function scan(ply)
        if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
        local id = ply:SteamID64()
        local now = CurTime()
        local ready = scanReady[id] or 0
        if now < ready then
            notify(ply, "Сканер перезаряжается: " .. math.ceil(ready - now) .. " сек.", 0)
            sendScanState(ply, ready)
            return
        end
        scanReady[id] = now + EchoArchive.Config.ScanCooldown
        sendScanState(ply, scanReady[id])
        ply:EmitSound("buttons/blip1.wav", 65, 90)

        local nearest, best
        for _, ent in ipairs(ents.FindByClass("echo_cache")) do
            local dist = ply:GetPos():Distance(ent:GetPos())
            if dist <= EchoArchive.Config.ScanRange and (not best or dist < best) then
                nearest, best = ent, dist
            end
        end

        net.Start(NET_PING)
        net.WriteEntity(IsValid(nearest) and nearest or NULL)
        net.WriteFloat(best or 0)
        net.Send(ply)

        if IsValid(nearest) then
            notify(ply, "Сигнал пойман: " .. math.floor((best or 0) / 52.49) .. " м. Направление на сканере.", 1)
        else
            notify(ply, "В радиусе " .. math.floor(EchoArchive.Config.ScanRange / 52.49) .. " м сигналов нет.", 0)
        end
    end

    concommand.Add("echo_scan", scan)

    hook.Add("PlayerSay", "EchoArchive.ChatCommands", function(ply, text)
        local command = string.Trim(string.lower(text))
        if command == "/echo" or command == "!echo" or command == "/echo scan" or command == "!echo scan" then
            scan(ply)
            return ""
        elseif command == "/echo help" or command == "!echo help" then
            notify(ply, "/echo — сканировать; найди контейнер и нажми E. Прогресс сохраняется между заходами.", 1)
            return ""
        end
    end)

    hook.Add("PlayerUse", "EchoArchive.UseDistance", function(ply, ent)
        if IsValid(ent) and ent:GetClass() == "echo_cache" and ply:GetPos():DistToSqr(ent:GetPos()) > 168 * 168 then
            return false
        end
    end)

    timer.Create("EchoArchive.SpawnCaches", EchoArchive.Config.SpawnInterval, 0, function()
        if cacheCount() >= EchoArchive.Config.MaxCaches then return end
        local eligible = {}
        for _, ply in ipairs(player.GetHumans()) do
            if IsValid(ply) and ply:Alive() and not ply:InVehicle() then eligible[#eligible + 1] = ply end
        end
        if #eligible == 0 then return end
        local ply = table.Random(eligible)
        local pos = randomGroundPosition(ply)
        if pos then spawnCache(pos) end
        if CurTime() < stormEnds and math.random(1, 100) <= 35 then
            local second = randomGroundPosition(ply)
            if second then spawnCache(second, chooseRarity()) end
        end
    end)

    timer.Simple(8, function()
        for _ = 1, math.min(EchoArchive.Config.StartCaches, EchoArchive.Config.MaxCaches) do
            local humans = player.GetHumans()
            local ply = #humans > 0 and table.Random(humans) or nil
            if IsValid(ply) and ply:Alive() then
                local pos = randomGroundPosition(ply)
                if pos then spawnCache(pos) end
            end
        end
    end)

    timer.Simple(180, function()
        if #player.GetHumans() > 0 then startStorm(nil) end
    end)

    timer.Create("EchoArchive.AutoStorm", 60, 0, function()
        if CurTime() >= stormNext and #player.GetHumans() > 0 then startStorm(nil) end
    end)

    timer.Create("EchoArchive.StormBroadcast", 2, 0, function()
        if CurTime() >= stormEnds then return end
        sendStorm(nil)
    end)
else
    ---------------------------------------------------------------------------
    -- Клиент: шрифты, сеть и HUD
    ---------------------------------------------------------------------------
    local FONT = "Roboto"

    surface.CreateFont("EchoArchive.Title", {font = FONT, size = 20, weight = 800, antialias = true, extended = true})
    surface.CreateFont("EchoArchive.Body", {font = FONT, size = 17, weight = 600, antialias = true, extended = true})
    surface.CreateFont("EchoArchive.Small", {font = FONT, size = 14, weight = 500, antialias = true, extended = true})
    surface.CreateFont("EchoArchive.Tiny", {font = FONT, size = 12, weight = 700, antialias = true, extended = true})
    surface.CreateFont("EchoArchive.Label", {font = FONT, size = 15, weight = 800, antialias = true, extended = true})
    surface.CreateFont("EchoArchive.Num", {font = FONT, size = 27, weight = 900, antialias = true, extended = true})
    surface.CreateFont("EchoArchive.Credits", {font = FONT, size = 18, weight = 700, antialias = true, extended = true})

    local stats = {level = 1, xp = 0, next = 100, credits = 0, finds = 0}
    local shown = {xp = 0, level = 1, credits = 0, finds = 0}
    local pingTarget, pingDistance, pingUntil
    local stormEnds, stormNext = 0, 0
    local scanCooldown = 0
    local notices = {}
    local levelFlash = 0
    local lastNoticeSound = 0
    local nearestCache, nearestDist, nearestCheck = nil, 99999, 0

    local rarityColors = {
        [1] = Color(122, 208, 220), [2] = Color(104, 222, 148),
        [3] = Color(126, 154, 255), [4] = Color(255, 196, 86)
    }

    net.Receive(NET_STATS, function()
        local oldLevel = stats.level
        stats.level = net.ReadUInt(16)
        stats.xp = net.ReadUInt(24)
        stats.next = math.max(1, net.ReadUInt(24))
        stats.credits = net.ReadUInt(32)
        stats.finds = net.ReadUInt(24)
        if stats.level > oldLevel then levelFlash = CurTime() + 2.4 end
    end)

    net.Receive(NET_PING, function()
        pingTarget = net.ReadEntity()
        pingDistance = net.ReadFloat()
        pingUntil = CurTime() + 12
        if IsValid(pingTarget) then pingTarget.EchoDiscoveredUntil = CurTime() + 12 end
    end)

    net.Receive(NET_NOTIFY, function()
        notices[#notices + 1] = {text = net.ReadString(), kind = net.ReadUInt(2), at = CurTime()}
        if #notices > 4 then table.remove(notices, 1) end
        if CurTime() - lastNoticeSound > 0.35 then
            lastNoticeSound = CurTime()
            surface.PlaySound("buttons/button15.wav")
        end
    end)

    net.Receive(NET_STORM, function()
        stormEnds = net.ReadFloat()
        stormNext = net.ReadFloat()
    end)

    net.Receive(NET_SCAN, function()
        scanCooldown = CurTime() + net.ReadFloat()
    end)

    local function lerp(a, b, t) return a + (b - a) * t end

    local function panel(x, y, w, h, accent, alpha)
        alpha = alpha or 232
        draw.RoundedBox(11, x - 1, y - 1, w + 2, h + 2, Color(accent.r, accent.g, accent.b, math.floor(alpha * 0.18)))
        draw.RoundedBox(10, x, y, w, h, Color(9, 15, 24, alpha))
        draw.RoundedBox(10, x, y, w, math.floor(h * 0.55), Color(16, 26, 38, math.floor(alpha * 0.35)))
        render.SetScissorRect(x + 1, y + 1, x + w - 1, y + h - 1, true)
        for i = 0, 20 do
            local t = i / 20
            surface.SetDrawColor(accent.r, accent.g, accent.b, math.floor(lerp(26, 0, t)))
            surface.DrawRect(x, y + math.floor(h * t), w, math.ceil(h / 20) + 1)
        end
        render.SetScissorRect(0, 0, 0, 0, false)
        surface.SetDrawColor(accent.r, accent.g, accent.b, 90)
        surface.DrawRect(x + 12, y, w - 24, 1)
    end

    local function hexagon(cx, cy, radius, col)
        local points = {}
        for i = 0, 5 do
            local a = math.rad(60 * i - 30)
            points[#points + 1] = {x = cx + math.cos(a) * radius, y = cy + math.sin(a) * radius}
        end
        draw.NoTexture()
        surface.SetDrawColor(col.r, col.g, col.b, col.a)
        surface.DrawPoly(points)
        return points
    end

    local function coin(cx, cy, radius, col)
        draw.NoTexture()
        surface.SetDrawColor(col.r, col.g, col.b, col.a)
        surface.DrawCircle(cx, cy, radius, col.r, col.g, col.b, col.a)
        surface.SetDrawColor(9, 15, 24, 200)
        surface.DrawCircle(cx, cy, radius * 0.55, 9, 15, 24, 210)
    end

    local function diamondIcon(cx, cy, size, col)
        draw.NoTexture()
        surface.SetDrawColor(col.r, col.g, col.b, col.a)
        surface.DrawPoly({
            {x = cx, y = cy - size},
            {x = cx + size * 0.75, y = cy},
            {x = cx, y = cy + size},
            {x = cx - size * 0.75, y = cy}
        })
    end

    -- Мягкая радиальная виньетка. mesh в HUDPaint рисовать нельзя: он зависит
    -- от текущей проекции, поэтому здесь — концентрические окружности через
    -- draw.NoTexture. Ступенек не видно, а стоимость та же.
    local function vignette(col, strength)
        strength = math.Clamp(strength, 0, 1)
        if strength <= 0.005 then return end
        local w, h = ScrW(), ScrH()
        local cx, cy = w * 0.5, h * 0.5
        local outer = math.sqrt(w * w + h * h) * 0.5
        local steps = 7
        draw.NoTexture()
        for i = 0, steps - 1 do
            local t = i / steps
            local radius = outer * (0.62 + t * 0.62)
            local a = math.floor(255 * strength * (t ^ 2.1) / steps * 2.6)
            if a > 0 then
                surface.SetDrawColor(col.r, col.g, col.b, a)
                surface.DrawCircle(cx, cy, radius, col.r, col.g, col.b, a)
            end
        end
    end

    local function drawStormBanner()
        local remaining = math.max(0, stormEnds - CurTime())
        local t = CurTime()
        local urgent = remaining <= 12
        local accent = urgent and Color(255, 132, 84) or Color(255, 196, 96)
        local pulse = 0.6 + math.sin(t * (urgent and 8 or 2.4)) * 0.4
        local w, h = 386, 54
        local x, y = ScrW() * 0.5 - w * 0.5, 22
        panel(x, y, w, h, accent, 228)

        -- Бегущая полоса энергии вдоль нижней кромки.
        local sweep = (t * 0.55) % 1
        local sx = x + 12 + (w - 24) * sweep
        surface.SetDrawColor(accent.r, accent.g, accent.b, math.floor(150 * pulse))
        surface.DrawRect(sx - 26, y + h - 3, 52, 2)
        surface.SetDrawColor(accent.r, accent.g, accent.b, 40)
        surface.DrawRect(x + 12, y + h - 3, w - 24, 1)

        draw.SimpleText("РЕЗОНАНСНАЯ БУРЯ", "EchoArchive.Title", x + 18, y + 8, Color(accent.r, accent.g, accent.b, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("редкие архивы • сигналы чаще", "EchoArchive.Small", x + 18, y + 31, Color(196, 208, 218, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        local clock = string.format("%d:%02d", math.floor(remaining / 60), math.floor(remaining % 60))
        draw.SimpleText(clock, "EchoArchive.Num", x + w - 18, y + 10, Color(accent.r, accent.g, accent.b, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        draw.SimpleText("ДО КОНЦА", "EchoArchive.Tiny", x + w - 18, y + 39, Color(accent.r, accent.g, accent.b, math.floor(170 * pulse)), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

        -- Искры, стекающие по краям баннера.
        for i = 1, 9 do
            local life = ((t * 0.35) + i * 0.17) % 1
            local px = x + 14 + ((i * 41) % (w - 28))
            local py = y + h * life
            surface.SetDrawColor(accent.r, accent.g, accent.b, math.floor((1 - life) * 130))
            surface.DrawRect(px, py, 1, 3)
        end
    end

    local function drawExperienceBar(x, y, w, accent)
        local ratio = math.Clamp(stats.xp / math.max(1, stats.next), 0, 1)
        local shownRatio = math.Clamp(shown.xp / math.max(1, stats.next), 0, 1)
        draw.RoundedBox(5, x, y, w, 10, Color(32, 43, 55, 235))
        if shownRatio > 0.001 then
            draw.RoundedBox(5, x, y, math.max(6, w * shownRatio), 10, Color(accent.r, accent.g, accent.b, 245))
            draw.RoundedBox(5, x, y, math.max(6, w * shownRatio), 4, Color(255, 255, 255, 55))
            -- Блик, бегущий по заполненной части.
            local sweep = (CurTime() * 0.45) % 1
            render.SetScissorRect(x, y, x + w * shownRatio, y + 10, true)
            surface.SetDrawColor(255, 255, 255, 42)
            surface.DrawRect(x + w * sweep - 16, y, 32, 10)
            render.SetScissorRect(0, 0, 0, 0, false)
        end
        for i = 1, 3 do
            local tx = x + w * (i / 4)
            surface.SetDrawColor(9, 15, 24, 140)
            surface.DrawRect(tx, y + 1, 1, 8)
        end
        return ratio
    end

    local function drawPingMarker(ply)
        if not IsValid(pingTarget) or CurTime() > (pingUntil or 0) then return end
        local target = pingTarget:WorldSpaceCenter()
        local remain = math.Clamp((pingUntil - CurTime()) / 12, 0, 1)
        local alpha = math.Clamp(remain * 4, 0, 1) * 255
        local col = rarityColors[pingTarget:GetNWInt("EchoRarity", 1)] or rarityColors[1]
        local t = CurTime()
        local pulse = 0.65 + math.sin(t * 5) * 0.35

        local w, h = ScrW(), ScrH()
        local scr = target:ToScreen()
        local marginX, marginY = 96, 104
        local onScreen = scr.visible and scr.x > marginX and scr.x < w - marginX and scr.y > marginY and scr.y < h - marginY
        local x, y, angle

        if onScreen then
            x, y = scr.x, scr.y
        else
            local ang = (target - ply:EyePos()):Angle()
            local dYaw = math.AngleDifference(ang.y, ply:EyeAngles().y)
            local dPitch = math.AngleDifference(ang.p, ply:EyeAngles().p)
            local dx = math.sin(math.rad(dYaw))
            local dy = -math.sin(math.rad(dPitch))
            local len = math.sqrt(dx * dx + dy * dy)
            if len < 0.001 then dx, dy, len = 0, -1, 1 end
            dx, dy = dx / len, dy / len
            local cx, cy = w * 0.5, h * 0.5
            local limitX, limitY = w * 0.5 - marginX - 18, h * 0.5 - marginY - 18
            local edge = math.min(limitX / math.max(math.abs(dx), 0.0001), limitY / math.max(math.abs(dy), 0.0001))
            x, y = cx + dx * edge, cy + dy * edge
            angle = math.deg(math.atan2(dy, dx))
        end

        -- Расходящиеся круги «сонара».
        for i = 0, 1 do
            local wave = ((t * 0.9) + i * 0.5) % 1
            local radius = 10 + wave * 34
            draw.NoTexture()
            surface.SetDrawColor(col.r, col.g, col.b, math.floor((1 - wave) * alpha * 0.35 * pulse))
            surface.DrawCircle(x, y, radius, col.r, col.g, col.b, math.floor((1 - wave) * alpha * 0.35 * pulse))
        end

        surface.SetDrawColor(col.r, col.g, col.b, math.floor(alpha * 0.22))
        draw.RoundedBox(18, x - 18, y - 18, 36, 36, Color(col.r, col.g, col.b, math.floor(alpha * 0.16)))
        diamondIcon(x, y, 8 + pulse * 2, Color(col.r, col.g, col.b, alpha))
        diamondIcon(x, y, 4, Color(255, 255, 255, alpha))

        if angle then
            local size = 11
            local rad = math.rad(angle)
            local fx, fy = math.cos(rad), math.sin(rad)
            local px, py = -fy, fx
            local bx, by = x + fx * 24, y + fy * 24
            draw.NoTexture()
            surface.SetDrawColor(col.r, col.g, col.b, alpha)
            surface.DrawPoly({
                {x = bx + fx * size, y = by + fy * size},
                {x = bx - fx * 4 + px * size * 0.8, y = by - fy * 4 + py * size * 0.8},
                {x = bx - fx * 4 - px * size * 0.8, y = by - fy * 4 - py * size * 0.8}
            })
        end

        local meters = math.floor((pingDistance or 0) / 52.49)
        local label = onScreen and ("СИГНАЛ • " .. meters .. " м") or (meters .. " м")
        draw.SimpleText(label, "EchoArchive.Small", x, y + 24, Color(238, 246, 250, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    local function drawNotices()
        local baseY = ScrH() - 190
        local font = "EchoArchive.Body"
        surface.SetFont(font)
        for i = #notices, 1, -1 do
            local item = notices[i]
            local age = CurTime() - item.at
            local life = 5
            if age > life then
                table.remove(notices, i)
            else
                local enter = math.Clamp(age / 0.28, 0, 1)
                local exit = math.Clamp((life - age) / 0.55, 0, 1)
                local ease = 1 - (1 - enter) ^ 3
                local alpha = math.floor(math.min(1, ease, exit) * 255)
                local tw = surface.GetTextSize(item.text)
                local w = tw + 46
                local slot = (#notices - i)
                local x = ScrW() * 0.5 - w * 0.5 + (1 - ease) * 26
                local y = baseY - slot * 42 - (1 - ease) * 14
                local accent = item.kind == 2 and Color(255, 200, 108) or (item.kind == 3 and Color(255, 120, 120) or Color(126, 220, 232))
                draw.RoundedBox(9, x, y, w, 34, Color(8, 13, 20, math.floor(alpha * 0.86)))
                draw.RoundedBox(9, x, y, 3, 34, Color(accent.r, accent.g, accent.b, alpha))
                draw.NoTexture()
                surface.SetDrawColor(accent.r, accent.g, accent.b, alpha)
                surface.DrawCircle(x + 19, y + 17, 4, accent.r, accent.g, accent.b, alpha)
                draw.SimpleText(item.text, font, x + 32, y + 17, Color(236, 244, 249, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end
    end

    local function drawScannerPill(x, y)
        local ready = CurTime() >= scanCooldown
        local accent = ready and Color(126, 226, 196) or Color(255, 190, 96)
        local w, h = 188, 28
        draw.RoundedBox(7, x, y, w, h, Color(8, 14, 22, 214))
        draw.RoundedBox(7, x, y, 3, h, Color(accent.r, accent.g, accent.b, 200))
        draw.NoTexture()
        surface.SetDrawColor(accent.r, accent.g, accent.b, 235)
        surface.DrawCircle(x + 17, y + h * 0.5, 3.5, accent.r, accent.g, accent.b, 235)
        if ready then
            draw.SimpleText("СКАНЕР ГОТОВ  •  /echo", "EchoArchive.Tiny", x + 28, y + h * 0.5, Color(216, 238, 236, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        else
            local remain = math.max(0, scanCooldown - CurTime())
            draw.SimpleText("ПЕРЕЗАРЯДКА  " .. string.format("%.1f", remain) .. " c", "EchoArchive.Tiny", x + 28, y + h * 0.5 - 5, Color(226, 214, 196, 225), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            local frac = 1 - math.Clamp(remain / EchoArchive.Config.ScanCooldown, 0, 1)
            draw.RoundedBox(2, x + 28, y + h - 9, w - 40, 3, Color(40, 48, 58, 220))
            draw.RoundedBox(2, x + 28, y + h - 9, (w - 40) * frac, 3, Color(accent.r, accent.g, accent.b, 235))
        end
    end

    hook.Add("HUDPaint", "EchoArchive.HUD", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then return end

        -- Плавная интерполяция чисел HUD, чтобы опыт не «прыгал».
        local ft = math.min(FrameTime(), 0.1)
        shown.xp = lerp(shown.xp, stats.xp, math.min(1, ft * 8))
        shown.credits = lerp(shown.credits, stats.credits, math.min(1, ft * 6))
        shown.finds = lerp(shown.finds, stats.finds, math.min(1, ft * 6))

        local accent = Color(96, 216, 230)
        local x, y, w, h = 22, ScrH() - 152, 316, 128
        local storm = CurTime() < stormEnds

        if storm then
            vignette(Color(255, 140, 60), 0.10 + math.sin(CurTime() * 3) * 0.03)
        end

        panel(x, y, w, h, accent)

        -- Значок уровня.
        local badgeX, badgeY = x + 34, y + 38
        hexagon(badgeX, badgeY, 23, Color(accent.r, accent.g, accent.b, 70))
        hexagon(badgeX, badgeY, 20, Color(12, 22, 33, 255))
        hexagon(badgeX, badgeY, 16, Color(accent.r, accent.g, accent.b, 26))
        draw.SimpleText(tostring(stats.level), "EchoArchive.Num", badgeX, badgeY + 1, Color(226, 250, 252, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("УР.", "EchoArchive.Tiny", badgeX, badgeY + 19, Color(accent.r, accent.g, accent.b, 190), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        draw.SimpleText("ЭХО-АРХИВ", "EchoArchive.Title", x + 68, y + 14, Color(232, 250, 252, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        local subtitle = storm and "режим: резонанс" or "пассивное сканирование"
        draw.SimpleText(subtitle, "EchoArchive.Small", x + 68, y + 37, Color(accent.r, accent.g, accent.b, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        -- Кредиты и находки.
        coin(x + 72, y + 67, 7, Color(240, 208, 132, 235))
        local creditText = tostring(math.floor(shown.credits + 0.5))
        draw.SimpleText(creditText, "EchoArchive.Credits", x + 84, y + 66, Color(242, 226, 180, 245), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetFont("EchoArchive.Credits")
        local creditWidth = surface.GetTextSize(creditText)
        draw.SimpleText("эхо-кредитов", "EchoArchive.Tiny", x + 90 + creditWidth, y + 67, Color(160, 176, 188, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        diamondIcon(x + w - 74, y + 67, 6, Color(accent.r, accent.g, accent.b, 220))
        draw.SimpleText(math.floor(shown.finds + 0.5) .. " находок", "EchoArchive.Small", x + w - 62, y + 67, Color(200, 214, 224, 230), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        drawExperienceBar(x + 20, y + h - 30, w - 40, accent)
        draw.SimpleText(stats.xp .. " / " .. stats.next .. " XP", "EchoArchive.Tiny", x + w - 20, y + h - 47, Color(172, 196, 206, 225), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

        -- Вспышка при новом уровне.
        if CurTime() < levelFlash then
            local t = math.Clamp((levelFlash - CurTime()) / 2.4, 0, 1)
            local glow = math.sin((1 - t) * math.pi)
            draw.RoundedBox(10, x, y, w, h, Color(accent.r, accent.g, accent.b, math.floor(glow * 46)))
            draw.SimpleText("НОВЫЙ УРОВЕНЬ", "EchoArchive.Title", x + w * 0.5, y - 26, Color(accent.r, accent.g, accent.b, math.floor(glow * 255)), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end

        drawScannerPill(x, y - 36)

        -- Ближайший известный сигнал подсказываем только вблизи.
        if CurTime() > nearestCheck then
            nearestCheck = CurTime() + 0.4
            local best, bestDist
            for _, ent in ipairs(ents.FindByClass("echo_cache")) do
                local d = ply:GetPos():Distance(ent:GetPos())
                if not bestDist or d < bestDist then best, bestDist = ent, d end
            end
            nearestCache, nearestDist = best, bestDist or 99999
        end
        if IsValid(nearestCache) and nearestDist < 900 then
            local nearAlpha = math.Clamp((900 - nearestDist) / 300, 0, 1) * 190
            local ncol = rarityColors[nearestCache:GetNWInt("EchoRarity", 1)] or accent
            draw.SimpleText("ЭХО-СИГНАЛ РЯДОМ  •  " .. math.floor(nearestDist / 52.49) .. " м", "EchoArchive.Small",
                ScrW() * 0.5, ScrH() - 62, Color(ncol.r, ncol.g, ncol.b, nearAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end

        if storm then drawStormBanner() end

        drawPingMarker(ply)
        drawNotices()

        -- Лёгкая рамка-виньетка при буре, чтобы край экрана жил.
        if storm then vignette(Color(255, 120, 40), 0.06) end
    end)

    hook.Add("OnPlayerChat", "EchoArchive.ChatHint", function(ply, text)
        if ply == LocalPlayer() and string.lower(text) == "/echo" then return true end
    end)

    -- Диагностическая команда: не ломает игру, но помогает проверить эффекты.
    -- Конвар объявлен в cl_init контейнера, поэтому здесь не полагаемся на то,
    -- что он уже существует, и читаем состояние после переключения.
    concommand.Add("echo_archive_fx_toggle", function()
        local cv = GetConVar("echo_archive_fx")
        local newValue = (cv and cv:GetBool()) and "0" or "1"
        RunConsoleCommand("echo_archive_fx", newValue)
        chat.AddText(Color(120, 220, 230), "[Эхо-архив] ", color_white,
            "эффекты: " .. (newValue == "1" and "включены" or "выключены"))
    end)
end
