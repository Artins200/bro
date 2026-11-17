-- Эхо-архив: standalone scavenging addon for Garry's Mod.
EchoArchive = EchoArchive or {}
EchoArchive.Version = "1.0.0"

local NET_PING = "echo_archive_ping"
local NET_NOTIFY = "echo_archive_notify"
local NET_STATS = "echo_archive_stats"
local NET_STORM = "echo_archive_storm"

if SERVER then
    AddCSLuaFile()
    util.AddNetworkString(NET_PING)
    util.AddNetworkString(NET_NOTIFY)
    util.AddNetworkString(NET_STATS)
    util.AddNetworkString(NET_STORM)

    EchoArchive.Config = {
        MaxCaches = 12,
        SpawnInterval = 35,
        ScanRange = 4000,
        ScanCooldown = 10,
        StormDuration = 150,
        StormCooldown = 600,
        StartCaches = 5
    }

    local profiles = {}
    local scanTimes = {}
    local stormEnds = 0
    local stormNext = 0

    sql.Query("CREATE TABLE IF NOT EXISTS echo_archive_profiles (steamid TEXT PRIMARY KEY, level INTEGER NOT NULL, xp INTEGER NOT NULL, credits INTEGER NOT NULL, finds INTEGER NOT NULL)")

    local function xpForLevel(level)
        return 100 + math.max(0, level - 1) * 50
    end

    local function sendStats(ply)
        local data = profiles[ply]
        if not IsValid(ply) or not data then return end
        net.Start(NET_STATS)
        net.WriteUInt(data.level, 16)
        net.WriteUInt(data.xp, 24)
        net.WriteUInt(xpForLevel(data.level), 24)
        net.WriteUInt(data.credits, 32)
        net.WriteUInt(data.finds, 24)
        net.Send(ply)
    end

    local function notify(ply, text, kind)
        if not IsValid(ply) then return end
        net.Start(NET_NOTIFY)
        net.WriteString(string.sub(tostring(text), 1, 220))
        net.WriteUInt(kind or 0, 2)
        net.Send(ply)
    end

    local function saveProfile(ply)
        local data = profiles[ply]
        if not data or not IsValid(ply) then return end
        local id = sql.SQLStr(ply:SteamID64())
        sql.Query("REPLACE INTO echo_archive_profiles (steamid, level, xp, credits, finds) VALUES (" .. id .. ", " .. data.level .. ", " .. data.xp .. ", " .. data.credits .. ", " .. data.finds .. ")")
    end

    hook.Add("PlayerInitialSpawn", "EchoArchive.LoadProfile", function(ply)
        timer.Simple(1, function()
            if not IsValid(ply) then return end
            local rows = sql.Query("SELECT level, xp, credits, finds FROM echo_archive_profiles WHERE steamid = " .. sql.SQLStr(ply:SteamID64()))
            local row = istable(rows) and rows[1] or nil
            profiles[ply] = {
                level = row and math.max(1, tonumber(row.level) or 1) or 1,
                xp = row and math.max(0, tonumber(row.xp) or 0) or 0,
                credits = row and math.max(0, tonumber(row.credits) or 0) or 0,
                finds = row and math.max(0, tonumber(row.finds) or 0) or 0
            }
            sendStats(ply)
            if not row then saveProfile(ply) end
        end)
    end)

    hook.Add("PlayerDisconnected", "EchoArchive.SaveProfile", function(ply)
        saveProfile(ply)
        profiles[ply] = nil
        scanTimes[ply] = nil
    end)

    hook.Add("ShutDown", "EchoArchive.SaveAll", function()
        for ply in pairs(profiles) do saveProfile(ply) end
    end)

    local function giveLoot(ply, rarity)
        local data = profiles[ply]
        if not data then return end
        local rewards = {
            [1] = {xp = 20, credits = 15, label = "Пыльный контейнер"},
            [2] = {xp = 35, credits = 30, label = "Стабильный сигнал"},
            [3] = {xp = 60, credits = 65, label = "Редкий архив"},
            [4] = {xp = 100, credits = 150, label = "Золотой фрагмент"}
        }
        local reward = rewards[rarity] or rewards[1]
        data.xp = data.xp + reward.xp
        data.credits = data.credits + reward.credits
        data.finds = data.finds + 1
        local levels = 0
        while data.xp >= xpForLevel(data.level) do
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
        saveProfile(ply)
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
        for _ = 1, 12 do
            local angle = math.Rand(0, math.pi * 2)
            local distance = math.Rand(650, 1800)
            local start = center + Vector(math.cos(angle) * distance, math.sin(angle) * distance, 1400)
            local tr = util.TraceHull({
                start = start,
                endpos = start - Vector(0, 0, 3200),
                mins = Vector(-18, -18, 0),
                maxs = Vector(18, 18, 50),
                mask = MASK_SOLID,
                filter = ply
            })
            if tr.Hit and not tr.HitSky and tr.HitNormal.z > 0.65 and not tr.StartSolid then
                local pos = tr.HitPos + Vector(0, 0, 8)
                local clear = util.TraceHull({
                    start = pos,
                    endpos = pos + Vector(0, 0, 2),
                    mins = Vector(-20, -20, 0),
                    maxs = Vector(20, 20, 52),
                    mask = MASK_SOLID,
                    filter = ply
                })
                if not clear.Hit and not clear.StartSolid then return pos end
            end
        end
    end

    local function spawnCache(pos, rarity)
        if cacheCount() >= EchoArchive.Config.MaxCaches then return nil end
        local ent = ents.Create("echo_cache")
        if not IsValid(ent) then return nil end
        ent:SetPos(pos)
        ent:SetAngles(Angle(0, math.Rand(0, 360), 0))
        ent:SetRarity(rarity or chooseRarity())
        ent:Spawn()
        ent:Activate()
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
        end
        net.Start(NET_STORM)
        net.WriteFloat(stormEnds)
        net.Broadcast()
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
            if tr.Hit and not tr.HitSky then pos = tr.HitPos + tr.HitNormal * 12 end
        else
            local humans = player.GetHumans()
            if IsValid(humans[1]) then pos = humans[1]:GetPos() + Vector(0, 0, 48) end
        end
        if pos then spawnCache(pos) end
    end)

    local function scan(ply)
        if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
        local now = CurTime()
        local ready = scanTimes[ply] or 0
        if now < ready then
            notify(ply, "Сканер перезаряжается: " .. math.ceil(ready - now) .. " сек.", 0)
            return
        end
        scanTimes[ply] = now + EchoArchive.Config.ScanCooldown
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
            notify(ply, "Сигнал пойман. Направление отмечено на сканере.", 1)
        else
            notify(ply, "В радиусе " .. math.floor(EchoArchive.Config.ScanRange / 100) / 10 .. " км сигналов нет.", 0)
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
        if ent:GetClass() == "echo_cache" and ply:GetPos():DistToSqr(ent:GetPos()) > 150 * 150 then return false end
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

    timer.Create("EchoArchive.AutoStorm", 600, 0, function()
        if CurTime() >= stormNext and #player.GetHumans() > 0 then startStorm(nil) end
    end)

    timer.Create("EchoArchive.StormBroadcast", 2, 0, function()
        if CurTime() >= stormEnds then return end
        net.Start(NET_STORM)
        net.WriteFloat(stormEnds)
        net.Broadcast()
    end)

    hook.Add("PlayerInitialSpawn", "EchoArchive.StormState", function(ply)
        timer.Simple(2, function()
            if not IsValid(ply) then return end
            net.Start(NET_STORM)
            net.WriteFloat(stormEnds)
            net.Send(ply)
        end)
    end)
else
    surface.CreateFont("EchoArchive.Title", {font = "Trebuchet24", size = 22, weight = 900, antialias = true})
    surface.CreateFont("EchoArchive.Body", {font = "Trebuchet18", size = 17, weight = 600, antialias = true})
    surface.CreateFont("EchoArchive.Small", {font = "Trebuchet18", size = 14, weight = 500, antialias = true})

    local stats = {level = 1, xp = 0, next = 100, credits = 0, finds = 0}
    local pingTarget, pingDistance, pingUntil
    local stormEnds = 0
    local notices = {}
    local rarityColors = {
        [1] = Color(140, 210, 220), [2] = Color(100, 210, 145),
        [3] = Color(120, 155, 255), [4] = Color(255, 195, 80)
    }

    net.Receive(NET_STATS, function()
        stats.level = net.ReadUInt(16)
        stats.xp = net.ReadUInt(24)
        stats.next = math.max(1, net.ReadUInt(24))
        stats.credits = net.ReadUInt(32)
        stats.finds = net.ReadUInt(24)
    end)

    net.Receive(NET_PING, function()
        pingTarget = net.ReadEntity()
        pingDistance = net.ReadFloat()
        pingUntil = CurTime() + 12
        if IsValid(pingTarget) then pingTarget.EchoDiscoveredUntil = CurTime() + 12 end
    end)

    net.Receive(NET_NOTIFY, function()
        notices[#notices + 1] = {text = net.ReadString(), kind = net.ReadUInt(2), at = CurTime()}
        surface.PlaySound("buttons/button15.wav")
    end)

    net.Receive(NET_STORM, function() stormEnds = net.ReadFloat() end)

    local function roundedBox(x, y, w, h, color)
        draw.RoundedBox(8, x, y, w, h, color)
    end

    hook.Add("HUDPaint", "EchoArchive.HUD", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        local x, y, w, h = 24, ScrH() - 146, 300, 116
        roundedBox(x, y, w, h, Color(9, 16, 25, 225))
        surface.SetDrawColor(54, 192, 211, 200)
        surface.DrawRect(x, y, 3, h)
        draw.SimpleText("ЭХО-АРХИВ", "EchoArchive.Title", x + 17, y + 11, Color(101, 225, 232), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("Архивист • ур. " .. stats.level .. "     Находок: " .. stats.finds, "EchoArchive.Small", x + 18, y + 41, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(stats.credits .. " эхо-кредитов", "EchoArchive.Body", x + 18, y + 62, Color(238, 215, 145), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        local barX, barY, barW = x + 18, y + 91, w - 36
        draw.RoundedBox(3, barX, barY, barW, 8, Color(45, 56, 66, 240))
        draw.RoundedBox(3, barX, barY, barW * math.Clamp(stats.xp / stats.next, 0, 1), 8, Color(54, 190, 208))
        draw.SimpleText(stats.xp .. " / " .. stats.next .. " XP", "EchoArchive.Small", x + w - 18, y + 78, Color(190, 205, 215), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

        if CurTime() < stormEnds then
            local remain = math.max(0, math.ceil(stormEnds - CurTime()))
            local label = "РЕЗОНАНСНАЯ БУРЯ  •  " .. math.floor(remain / 60) .. ":" .. string.format("%02d", remain % 60)
            local tw = 360
            roundedBox(ScrW() / 2 - tw / 2, 24, tw, 38, Color(62, 34, 21, 225))
            draw.SimpleText(label, "EchoArchive.Body", ScrW() / 2, 33, Color(255, 199, 105), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end

        if pingTarget and IsValid(pingTarget) and CurTime() < (pingUntil or 0) then
            local targetPos = pingTarget:WorldSpaceCenter()
            local delta = math.AngleDifference((targetPos - ply:EyePos()):Angle().y, ply:EyeAngles().y)
            local cx = ScrW() / 2 + math.Clamp(delta / 75, -1, 1) * ScrW() * 0.39
            local cy = ScrH() * 0.28
            local a = math.Clamp((pingUntil - CurTime()) * 100, 0, 255)
            local col = rarityColors[pingTarget:GetNWInt("EchoRarity", 1)] or Color(100, 220, 225)
            surface.SetDrawColor(col.r, col.g, col.b, a)
            draw.NoTexture()
            surface.DrawPoly({{x = cx, y = cy - 10}, {x = cx - 8, y = cy + 7}, {x = cx + 8, y = cy + 7}})
            draw.SimpleText("СИГНАЛ • " .. math.floor(pingDistance) .. " u", "EchoArchive.Body", cx, cy + 11, Color(col.r, col.g, col.b, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end

        for i = #notices, 1, -1 do
            local item = notices[i]
            local age = CurTime() - item.at
            if age > 4.5 then
                table.remove(notices, i)
            else
                local alpha = math.min(255, (4.5 - age) * 170)
                local col = item.kind == 2 and Color(255, 202, 106, alpha) or Color(113, 225, 232, alpha)
                local ny = ScrH() * 0.68 + (#notices - i) * 29
                draw.SimpleText(item.text, "EchoArchive.Body", ScrW() / 2, ny, Color(8, 13, 19, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText(item.text, "EchoArchive.Body", ScrW() / 2, ny - 1, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
    end)

    hook.Add("PostDrawTranslucentRenderables", "EchoArchive.DiscoveredGlow", function()
        local list = {}
        for _, ent in ipairs(ents.FindByClass("echo_cache")) do
            if (ent.EchoDiscoveredUntil or 0) > CurTime() then list[#list + 1] = ent end
        end
        if #list > 0 then halo.Add(list, Color(90, 220, 235), 2, 2, 1, true, true) end
    end)

    hook.Add("OnPlayerChat", "EchoArchive.ChatHint", function(ply, text)
        if ply == LocalPlayer() and string.lower(text) == "/echo" then return true end
    end)
end
