-- ============================================================================
-- Rick and Morty Addon - Shared Config, Multiverse Extinction & Time Travel Engine
-- ============================================================================

AddCSLuaFile()

RICK_PORTAL = RICK_PORTAL or {}
RICK_PORTAL.ErasedSubspecies = RICK_PORTAL.ErasedSubspecies or {}

function RICK_PORTAL.GetSubspeciesSignature(ent)
	if not IsValid(ent) then return nil, nil end
	local cls = ent:GetClass()
	local mdl = string.lower(ent:GetModel() or "")

	-- NEVER erase worldspawn, internal controllers, or 4th-dimensional Time Police!
	if ent:IsWorld() then return nil, nil end
	if cls == "predicted_viewmodel" or cls == "gmod_hands" or cls == "ent_omega_device" or cls == "npc_time_police" or cls == "ent_past_self_clone" then
		return nil, nil
	end

	if ent:IsNPC() or ent:IsNextBot() then
		local pretty = ent.PrintName and ent.PrintName ~= "" and ent.PrintName or language.GetPhrase(cls)
		if pretty == cls then
			pretty = string.gsub(cls, "^npc_", "")
			pretty = string.upper(string.sub(pretty, 1, 1)) .. string.sub(pretty, 2)
		end
		return "class:" .. cls, pretty, mdl
	end

	if ent:IsPlayer() then
		local shortMdl = string.GetFileFromFilename(mdl) or mdl
		return "playermodel:" .. mdl, "Subspecies (" .. shortMdl .. ")", mdl
	end

	if string.StartWith(cls, "prop_") and mdl ~= "" then
		local shortMdl = string.StripExtension(string.GetFileFromFilename(mdl) or mdl)
		return "model:" .. mdl, "Object (" .. shortMdl .. ")", mdl
	end

	local pretty = (ent.PrintName and ent.PrintName ~= "" and ent.PrintName) or cls
	return "class:" .. cls, pretty, mdl
end

function RICK_PORTAL.MatchesErasedSubspecies(ent)
	if not IsValid(ent) then return false end
	if ent:GetClass() == "npc_time_police" then return false end
	local sig, _, mdl = RICK_PORTAL.GetSubspeciesSignature(ent)
	if not sig then return false end
	if RICK_PORTAL.ErasedSubspecies[sig] then return true, sig end
	if mdl and mdl ~= "" and RICK_PORTAL.ErasedSubspecies["model:" .. mdl] then
		return true, "model:" .. mdl
	end
	return false
end

if SERVER then
	util.AddNetworkString("RickOmega_SyncErased")
	util.AddNetworkString("RickOmega_VaporizeFX")
	util.AddNetworkString("RickTime_RiftFX")

	-- Resources
	resource.AddSingleFile("materials/rick_portal/portal_swirl.png")
	resource.AddSingleFile("materials/rick_portal/portal_inner_swirl.png")
	resource.AddSingleFile("materials/rick_portal/liquid_blob.png")
	resource.AddSingleFile("materials/entities/weapon_rick_portalgun.png")
	resource.AddSingleFile("materials/entities/ent_rick_portal.png")
	resource.AddSingleFile("materials/entities/ent_omega_device.png")
	resource.AddSingleFile("materials/entities/weapon_omega_device.png")
	resource.AddSingleFile("materials/entities/weapon_chrono_gun.png")
	resource.AddSingleFile("materials/entities/npc_time_police.png")
	resource.AddSingleFile("materials/vgui/entities/weapon_rick_portalgun.png")
	resource.AddSingleFile("materials/vgui/entities/weapon_omega_device.png")
	resource.AddSingleFile("materials/vgui/entities/weapon_chrono_gun.png")

	resource.AddSingleFile("sound/rick_portal/portal_shoot.wav")
	resource.AddSingleFile("sound/rick_portal/portal_open.wav")
	resource.AddSingleFile("sound/rick_portal/portal_enter.wav")
	resource.AddSingleFile("sound/rick_portal/portal_close.wav")
	resource.AddSingleFile("sound/rick_portal/omega_charge.wav")
	resource.AddSingleFile("sound/rick_portal/omega_erase.wav")
	resource.AddSingleFile("sound/rick_portal/tablet_tap.wav")
	resource.AddSingleFile("sound/rick_portal/time_warp.wav")
	resource.AddSingleFile("sound/rick_portal/time_police_arrive.wav")
	resource.AddSingleFile("sound/rick_portal/time_baton_hit.wav")

	CreateConVar("sv_rickportal_maxdist", "420", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Max free-air flight distance before liquid transforms into a portal mid-air")
	CreateConVar("sv_rickportal_lifetime", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Portal lifetime in seconds (0 = infinite until closed with Reload)")

	-- ========================================================================
	-- 1. OMEGA DEVICE MULTIVERSE EXTINCTION LOGIC
	-- ========================================================================
	function RICK_PORTAL.SyncErasedToClients()
		net.Start("RickOmega_SyncErased")
		local count = table.Count(RICK_PORTAL.ErasedSubspecies)
		net.WriteUInt(math.min(count, 255), 8)
		local sent = 0
		for sig, info in pairs(RICK_PORTAL.ErasedSubspecies) do
			if sent >= 255 then break end
			net.WriteString(sig)
			net.WriteString(tostring(info.name or sig))
			sent = sent + 1
		end
		net.Broadcast()
	end

	function RICK_PORTAL.VaporizeSingleEntity(ent, attacker)
		if not IsValid(ent) then return end
		if ent:GetClass() == "npc_time_police" then return end

		local pos = ent:WorldSpaceCenter()
		local rad = math.Clamp(ent:BoundingRadius(), 14, 180)

		net.Start("RickOmega_VaporizeFX")
			net.WriteVector(pos)
			net.WriteFloat(rad)
		net.Broadcast()

		if ent:IsPlayer() then
			if ent:Alive() then
				ent:KillSilent()
				local rag = ent:GetRagdollEntity()
				if IsValid(rag) then rag:Remove() end
			end
		else
			ent:Remove()
		end
	end

	function RICK_PORTAL.EraseSubspeciesAcrossMultiverse(targetEnt, attacker)
		if not IsValid(targetEnt) or targetEnt:GetClass() == "npc_time_police" then return 0, nil end
		local sig, prettyName, mdl = RICK_PORTAL.GetSubspeciesSignature(targetEnt)
		if not sig then return 0, nil end

		RICK_PORTAL.ErasedSubspecies[sig] = { name = prettyName, time = CurTime() }
		if (targetEnt:IsNPC() or targetEnt:IsNextBot()) and mdl and mdl ~= "" then
			RICK_PORTAL.ErasedSubspecies["ragdoll_mdl:" .. mdl] = {
				name = prettyName .. " (Remains)",
				hidden = true,
				time = CurTime()
			}
		end

		local erasedCount = 0
		for _, ent in ipairs(ents.GetAll()) do
			if IsValid(ent) and ent ~= attacker and ent:GetClass() ~= "npc_time_police" then
				local match = RICK_PORTAL.MatchesErasedSubspecies(ent)
				if not match and ent:GetClass() == "prop_ragdoll" then
					local emdl = string.lower(ent:GetModel() or "")
					if RICK_PORTAL.ErasedSubspecies["ragdoll_mdl:" .. emdl] then
						match = true
					end
				end

				if match then
					erasedCount = erasedCount + 1
					RICK_PORTAL.VaporizeSingleEntity(ent, attacker)
				end
			end
		end

		RICK_PORTAL.SyncErasedToClients()
		return erasedCount, prettyName
	end

	function RICK_PORTAL.ResetErasedMultiverse()
		RICK_PORTAL.ErasedSubspecies = {}
		RICK_PORTAL.SyncErasedToClients()
	end

	hook.Add("OnEntityCreated", "RickOmega_PreventErasedSubspecies", function(ent)
		if table.IsEmpty(RICK_PORTAL.ErasedSubspecies) then return end
		timer.Simple(0, function()
			if not IsValid(ent) or ent:GetClass() == "npc_time_police" then return end
			local match = RICK_PORTAL.MatchesErasedSubspecies(ent)
			if not match and ent:GetClass() == "prop_ragdoll" then
				local emdl = string.lower(ent:GetModel() or "")
				if RICK_PORTAL.ErasedSubspecies["ragdoll_mdl:" .. emdl] then
					match = true
				end
			end
			if match then
				RICK_PORTAL.VaporizeSingleEntity(ent, nil)
			end
		end)
	end)

	hook.Add("PlayerSpawn", "RickOmega_CheckErasedPlayerSubspecies", function(ply)
		if table.IsEmpty(RICK_PORTAL.ErasedSubspecies) then return end
		timer.Simple(0.05, function()
			if IsValid(ply) and ply:Alive() and RICK_PORTAL.MatchesErasedSubspecies(ply) then
				ply:ChatPrint("[OMEGA DEVICE] Ваш подвид стёрт из всех вселенных! Смените скин или сбросьте Омега-устройство (R).")
				RICK_PORTAL.VaporizeSingleEntity(ply, nil)
			end
		end)
	end)

	concommand.Add("rick_omega_reset", function(ply)
		if IsValid(ply) and not ply:IsAdmin() then return end
		RICK_PORTAL.ResetErasedMultiverse()
		PrintMessage(HUD_PRINTTALK, "[OMEGA DEVICE] Временные линии восстановлены.")
	end)

	-- ========================================================================
	-- 2. TIME TRAVEL ENGINE:
	--    * Records rolling 30s history (12.5 Hz) of every player's movement & animations
	--    * Teleports player backward in time + spawns their living Past Self Clone
	--      replaying their exact movements from N seconds ago!
	--    * Starts a strict 35-SECOND DEADLINE: if not returned to present in 35s,
	--      4th-Dimensional TIME POLICE spawn around them shouting "НУ ВСЁ, УЕБОК, НА СРОК!"
	-- ========================================================================
	RICK_PORTAL.TimeHistory = RICK_PORTAL.TimeHistory or {}
	RICK_PORTAL.ActiveTimeTravelers = RICK_PORTAL.ActiveTimeTravelers or {}

	local RECORD_INTERVAL = 0.08
	local MAX_FRAMES      = 380 -- ~30.4 seconds of movement history
	local NEXT_REC_AT     = 0

	function RICK_PORTAL.SyncWeaponTimeState(ply, wep)
		if not IsValid(ply) then return end
		local st  = RICK_PORTAL.ActiveTimeTravelers[ply]
		local gun = IsValid(wep) and wep or ply:GetWeapon("weapon_chrono_gun")
		if IsValid(gun) and gun:GetClass() == "weapon_chrono_gun" then
			if st and st.inPast then
				gun:SetInPast(true)
				gun:SetPastDeadline(st.deadline)
			else
				gun:SetInPast(false)
				gun:SetPastDeadline(0)
			end
		end
	end

	local function BroadcastTimeRift(pos, isReturn)
		net.Start("RickTime_RiftFX")
			net.WriteVector(pos)
			net.WriteBool(isReturn and true or false)
		net.Broadcast()
	end

	function RICK_PORTAL.ClearPlayerTimeTravelState(ply, keepPolice)
		local st = RICK_PORTAL.ActiveTimeTravelers[ply]
		if not st then return end

		if IsValid(st.clone) then
			st.clone:Remove()
		end
		if not keepPolice and st.cops then
			for _, cop in ipairs(st.cops) do
				if IsValid(cop) then cop:Remove() end
			end
		end

		RICK_PORTAL.ActiveTimeTravelers[ply] = nil
		RICK_PORTAL.SyncWeaponTimeState(ply)
	end

	function RICK_PORTAL.StartTimeJumpBack(ply, secondsBack, wep)
		if not IsValid(ply) or not ply:Alive() then return end
		local stCurrent = RICK_PORTAL.ActiveTimeTravelers[ply]
		if stCurrent and stCurrent.inPast then return end

		secondsBack = math.Clamp(secondsBack or 10, 5, 25)
		local hist = RICK_PORTAL.TimeHistory[ply] or {}

		-- Save exact Present anchor so returning brings them right back to their timeline!
		local presentPos = ply:GetPos()
		local presentAng = ply:EyeAngles()
		local presentHP  = ply:Health()

		local framesNeeded = math.floor(secondsBack / RECORD_INTERVAL)
		local startIdx = math.max(1, #hist - framesNeeded)
		local replaySlice = {}
		for i = startIdx, #hist do
			replaySlice[#replaySlice + 1] = hist[i]
		end

		-- Determine where the player was N seconds ago (or nearby offset if freshly spawned)
		local pastStartPos = (#replaySlice > 0) and replaySlice[1].pos or (presentPos - ply:GetForward() * 90)
		local pastStartAng = (#replaySlice > 0) and replaySlice[1].ang or presentAng

		-- Place the player slightly behind/beside their Past Self so they IMMEDIATELY see themselves from the past!
		local viewOffset = Angle(0, pastStartAng.y, 0):Forward() * -95 + Angle(0, pastStartAng.y, 0):Right() * 35
		local trSafe = util.TraceHull({
			start  = pastStartPos + Vector(0, 0, 16),
			endpos = pastStartPos + viewOffset + Vector(0, 0, 16),
			mins   = Vector(-16, -16, 0),
			maxs   = Vector(16, 16, 72),
			filter = ply,
			mask   = MASK_PLAYERSOLID_BRUSHONLY
		})
		local arrivePos = trSafe.HitPos

		-- Spawn the living Past Self Clone replaying their exact recorded movements!
		local clone = ents.Create("ent_past_self_clone")
		if IsValid(clone) then
			clone:SetPos(pastStartPos)
			clone:SetAngles(Angle(0, pastStartAng.y, 0))
			if #replaySlice == 0 then
				replaySlice[1] = { pos = pastStartPos, ang = pastStartAng, seq = ply:GetSequence(), cycle = 0 }
			end
			clone:SetTimelineFrames(replaySlice, ply)
			clone:Spawn()
			clone:Activate()
		end

		BroadcastTimeRift(presentPos + Vector(0, 0, 36), false)
		BroadcastTimeRift(arrivePos  + Vector(0, 0, 36), false)

		ply:SetPos(arrivePos)
		ply:SetEyeAngles((pastStartPos + Vector(0, 0, 48) - (arrivePos + Vector(0, 0, 60))):Angle())
		ply:EmitSound("RickTime.Warp")
		ply:ScreenFade(SCREENFADE.IN, Color(175, 95, 255, 165), 0.55, 0.05)

		local deadline = CurTime() + 35.0
		RICK_PORTAL.ActiveTimeTravelers[ply] = {
			inPast        = true,
			presentPos    = presentPos,
			presentAng    = presentAng,
			presentHP     = presentHP,
			deadline      = deadline,
			policeSpawned = false,
			clone         = clone,
			cops          = {}
		}

		RICK_PORTAL.SyncWeaponTimeState(ply, wep)
		ply:ChatPrint(string.format("[ПУШКА ВРЕМЕНИ] Вы откатились на %d сек. в прошлое! Перед вами — ВЫ ИЗ ПРОШЛОГО! У вас ровно 35 сек., чтобы вернуться (ПКМ)!", secondsBack))
	end

	function RICK_PORTAL.ReturnToPresentTimeline(ply, wep)
		if not IsValid(ply) then return end
		local st = RICK_PORTAL.ActiveTimeTravelers[ply]
		if not st or not st.inPast then return end

		if st.policeSpawned then
			ply:ChatPrint("[ПОЛИЦИЯ ВРЕМЕНИ]: Поздно валить в настоящее, уебок! Время вышло — ты под арестом!")
			ply:EmitSound("buttons/button10.wav", 75, 85, 0.8)
			return
		end

		BroadcastTimeRift(ply:GetPos() + Vector(0, 0, 36), true)
		BroadcastTimeRift(st.presentPos + Vector(0, 0, 36), true)

		ply:SetPos(st.presentPos)
		ply:SetEyeAngles(st.presentAng)
		ply:EmitSound("RickTime.Warp")
		ply:ScreenFade(SCREENFADE.IN, Color(85, 235, 255, 160), 0.50, 0.05)
		ply:ChatPrint("[ПУШКА ВРЕМЕНИ] Вы вовремя вернулись в своё настоящее время! Полиция Времени не заметила пробоя.")

		RICK_PORTAL.ClearPlayerTimeTravelState(ply, false)
	end

	hook.Add("Think", "RickTime_RecorderAndPoliceDeadline", function()
		local ct = CurTime()

		-- 1) Record player history when NOT currently inside the past
		if ct >= NEXT_REC_AT then
			NEXT_REC_AT = ct + RECORD_INTERVAL
			for _, ply in ipairs(player.GetAll()) do
				if IsValid(ply) and ply:Alive() then
					local st = RICK_PORTAL.ActiveTimeTravelers[ply]
					if not (st and st.inPast) then
						local h = RICK_PORTAL.TimeHistory[ply]
						if not h then
							h = {}
							RICK_PORTAL.TimeHistory[ply] = h
						end
						h[#h + 1] = {
							pos   = ply:GetPos(),
							ang   = ply:EyeAngles(),
							seq   = ply:GetSequence(),
							cycle = ply:GetCycle()
						}
						if #h > MAX_FRAMES then
							table.remove(h, 1)
						end
					end
				end
			end
		end

		-- 2) Check 35-second Time Travel Deadline -> Spawn 4th-Dimensional Time Police Squad!
		for ply, st in pairs(RICK_PORTAL.ActiveTimeTravelers) do
			if not IsValid(ply) or not ply:Alive() then
				RICK_PORTAL.ClearPlayerTimeTravelState(ply, true)
			elseif st.inPast and not st.policeSpawned and ct >= st.deadline then
				st.policeSpawned = true
				st.cops = {}

				-- Spawn 2 Time Police officers around the player in purple temporal rifts!
				for i = 1, 2 do
					local angOff = math.rad(i * 180 - 35)
					local offset = Vector(math.cos(angOff) * 145, math.sin(angOff) * 145, 12)
					local trC = util.TraceLine({
						start  = ply:WorldSpaceCenter(),
						endpos = ply:GetPos() + offset,
						filter = ply,
						mask   = MASK_SOLID_BRUSHONLY
					})
					local copPos = trC.Hit and (trC.HitPos - offset:GetNormalized() * 24) or (ply:GetPos() + offset)

					local cop = ents.Create("npc_time_police")
					if IsValid(cop) then
						cop:SetPos(copPos)
						cop:SetAngles((ply:GetPos() - copPos):Angle())
						cop:SetTargetCriminal(ply)
						cop:Spawn()
						cop:Activate()
						st.cops[#st.cops + 1] = cop
					end
				end
			end
		end
	end)

	hook.Add("PlayerDeath", "RickTime_CleanupOnDeath", function(ply)
		RICK_PORTAL.ClearPlayerTimeTravelState(ply, true)
	end)
else
	CreateClientConVar("cl_rickportal_dlight", "1", true, false, "Enable dynamic lighting on portals, portal gun and Omega Device")

	net.Receive("RickOmega_SyncErased", function()
		local count = net.ReadUInt(8)
		RICK_PORTAL.ErasedSubspecies = {}
		for i = 1, count do
			local sig  = net.ReadString()
			local name = net.ReadString()
			RICK_PORTAL.ErasedSubspecies[sig] = { name = name }
		end
	end)

	local matParticleGlow = CreateMaterial("RickOmega_ParticleGlow_v2", "UnlitGeneric", {
		["$basetexture"] = "sprites/light_glow02",
		["$additive"]    = "1",
		["$vertexcolor"] = "1",
		["$vertexalpha"] = "1"
	})

	RICK_PORTAL.ActiveVaporizeArcs = RICK_PORTAL.ActiveVaporizeArcs or {}

	net.Receive("RickOmega_VaporizeFX", function()
		local pos = net.ReadVector()
		local rad = net.ReadFloat()

		table.insert(RICK_PORTAL.ActiveVaporizeArcs, {
			pos   = pos,
			rad   = rad,
			birth = CurTime(),
			dur   = 0.75,
			seed  = math.Rand(0, 100)
		})

		local em = ParticleEmitter(pos, false)
		if IsValid(em) then
			for i = 1, 32 do
				local dir = VectorRand():GetNormalized()
				local p   = em:Add(matParticleGlow, pos + dir * math.Rand(0, rad * 0.65))
				if p then
					p:SetVelocity(dir * math.Rand(60, 240) + Vector(0, 0, math.Rand(30, 110)))
					p:SetDieTime(math.Rand(0.45, 0.95))
					p:SetStartAlpha(255)
					p:SetEndAlpha(0)
					p:SetStartSize(math.Rand(8, 22))
					p:SetEndSize(0)
					if i % 3 == 0 then p:SetColor(225, 250, 255) else p:SetColor(55, 195, 255) end
					p:SetAirResistance(85)
				end
			end
			em:Finish()
		end
	end)

	local matLaser = Material("Effects/laser1")
	local matGlow  = Material("sprites/light_glow02_add")

	RICK_PORTAL.ActiveTimeRifts = RICK_PORTAL.ActiveTimeRifts or {}

	net.Receive("RickTime_RiftFX", function()
		local pos      = net.ReadVector()
		local isReturn = net.ReadBool()

		table.insert(RICK_PORTAL.ActiveTimeRifts, {
			pos      = pos,
			isReturn = isReturn,
			birth    = CurTime(),
			dur      = 0.95
		})

		local em = ParticleEmitter(pos, false)
		if IsValid(em) then
			for i = 1, 36 do
				local a   = (i / 36) * math.pi * 2
				local dir = Vector(math.cos(a), math.sin(a), math.Rand(-0.5, 0.5)):GetNormalized()
				local p   = em:Add(matParticleGlow, pos + dir * 8)
				if p then
					p:SetVelocity(dir * math.Rand(110, 260))
					p:SetDieTime(math.Rand(0.5, 0.9))
					p:SetStartAlpha(255)
					p:SetEndAlpha(0)
					p:SetStartSize(math.Rand(14, 26))
					p:SetEndSize(0)
					if isReturn then p:SetColor(95, 240, 255) else p:SetColor(225, 95, 255) end
					p:SetAirResistance(90)
				end
			end
			em:Finish()
		end
	end)

	hook.Add("PostDrawTranslucentRenderables", "RickOmega_DrawVaporizeArcs", function(bDepth, bSkybox)
		if bSkybox then return end
		local ct = CurTime()

		-- 1) Draw Chrono-Rewind Temporal Rifts (expanding clock-ring shockwaves!)
		local rifts = RICK_PORTAL.ActiveTimeRifts
		if rifts and #rifts > 0 then
			for i = #rifts, 1, -1 do
				local rf = rifts[i]
				local t  = (ct - rf.birth) / rf.dur
				if t >= 1 then
					table.remove(rifts, i)
				else
					local inv = 1.0 - t
					local col = rf.isReturn and Color(95, 240, 255, 240 * inv) or Color(225, 95, 255, 240 * inv)
					render.SetMaterial(matGlow)
					render.DrawSprite(rf.pos, 180 * (0.3 + t) * inv, 180 * (0.3 + t) * inv, col)

					render.SetMaterial(matLaser)
					local ringR = 15 + t * 115
					local segs  = 24
					for s = 0, segs - 1 do
						local a1 = (s / segs) * math.pi * 2 + ct * 6
						local a2 = ((s + 1) / segs) * math.pi * 2 + ct * 6
						local p1 = rf.pos + Vector(math.cos(a1) * ringR, math.sin(a1) * ringR, 0)
						local p2 = rf.pos + Vector(math.cos(a2) * ringR, math.sin(a2) * ringR, 0)
						render.DrawBeam(p1, p2, 10 * inv, 0, 1, col)
					end
				end
			end
		end

		-- 2) Draw Omega Vaporize Lightning Arcs
		local list = RICK_PORTAL.ActiveVaporizeArcs
		if not list or #list == 0 then return end

		for i = #list, 1, -1 do
			local fx = list[i]
			local t  = (ct - fx.birth) / fx.dur
			if t >= 1 then
				table.remove(list, i)
			else
				local inv = 1.0 - t
				render.SetMaterial(matGlow)
				render.DrawSprite(fx.pos, fx.rad * 3.8 * inv, fx.rad * 3.8 * inv, Color(85, 220, 255, 235 * inv))
				render.DrawSprite(fx.pos, fx.rad * 1.9 * inv, fx.rad * 1.9 * inv, Color(235, 252, 255, 255 * inv))

				render.SetMaterial(matLaser)
				for b = 1, 7 do
					local a1 = b * 0.9 + ct * 14 + fx.seed
					local dir = Vector(math.cos(a1), math.sin(a1), math.sin(a1 * 1.7)):GetNormalized()
					local pMid = fx.pos + dir * (fx.rad * (0.6 + t * 0.9)) + VectorRand() * 8
					local pEnd = fx.pos + dir * (fx.rad * (1.3 + t * 1.8))
					render.DrawBeam(fx.pos, pMid, 12 * inv, 0, 1, Color(120, 230, 255, 240 * inv))
					render.DrawBeam(pMid,   pEnd, 7 * inv,  0, 1, Color(230, 250, 255, 200 * inv))
				end
			end
		end
	end)
end

-- Sound Definitions
sound.Add({ name = "RickPortal.Shoot", channel = CHAN_WEAPON, volume = 0.9,  level = 75,  pitch = { 96, 105 }, sound = "rick_portal/portal_shoot.wav" })
sound.Add({ name = "RickPortal.Open",  channel = CHAN_STATIC, volume = 0.95, level = 80,  pitch = { 95, 104 }, sound = "rick_portal/portal_open.wav" })
sound.Add({ name = "RickPortal.Enter", channel = CHAN_ITEM,   volume = 0.95, level = 80,  pitch = { 96, 106 }, sound = "rick_portal/portal_enter.wav" })
sound.Add({ name = "RickPortal.Close", channel = CHAN_STATIC, volume = 0.85, level = 75,  pitch = { 95, 105 }, sound = "rick_portal/portal_close.wav" })

sound.Add({ name = "RickOmega.Charge", channel = CHAN_WEAPON, volume = 1.0,  level = 90,  pitch = { 98, 102 }, sound = "rick_portal/omega_charge.wav" })
sound.Add({ name = "RickOmega.Erase",  channel = CHAN_STATIC, volume = 1.0,  level = 105, pitch = { 96, 102 }, sound = "rick_portal/omega_erase.wav" })

sound.Add({ name = "RickTime.Warp",         channel = CHAN_STATIC, volume = 1.0, level = 85,  pitch = { 98, 102 }, sound = "rick_portal/time_warp.wav" })
sound.Add({ name = "RickTime.PoliceArrive", channel = CHAN_VOICE,  volume = 1.0, level = 100, pitch = { 95, 104 }, sound = "rick_portal/time_police_arrive.wav" })
sound.Add({ name = "RickTime.BatonHit",     channel = CHAN_WEAPON, volume = 1.0, level = 85,  pitch = { 95, 106 }, sound = "rick_portal/time_baton_hit.wav" })
