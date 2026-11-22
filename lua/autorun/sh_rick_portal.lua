-- ============================================================================
-- Rick and Morty Addon - Shared Config, Multiverse Extinction & Full Combat Time-Rewind Engine
-- ============================================================================

AddCSLuaFile()

RICK_PORTAL = RICK_PORTAL or {}
RICK_PORTAL.ErasedSubspecies = RICK_PORTAL.ErasedSubspecies or {}

function RICK_PORTAL.GetSubspeciesSignature(ent)
	if not IsValid(ent) then return nil, nil end
	local cls = ent:GetClass()
	local mdl = string.lower(ent:GetModel() or "")

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

	-- Resources for the portal gun, saucer, Omega station and supporting entities.
	resource.AddSingleFile("materials/rick_portal/portal_swirl.png")
	resource.AddSingleFile("materials/rick_portal/portal_inner_swirl.png")
	resource.AddSingleFile("materials/rick_portal/liquid_blob.png")
	resource.AddSingleFile("materials/entities/weapon_rick_portalgun.png")
	resource.AddSingleFile("materials/entities/ent_rick_portal.png")
	resource.AddSingleFile("materials/entities/ent_omega_device.png")
	resource.AddSingleFile("materials/entities/npc_time_police.png")
	resource.AddSingleFile("materials/vgui/entities/weapon_rick_portalgun.png")

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
				ply:ChatPrint("[OMEGA DEVICE] Ваш подвид стёрт из всех вселенных! Смените скин или восстановите вселенные на мониторе Омега-устройства.")
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
	-- 2. FULL COMBAT & NPC TIME-REWIND ENGINE:
	--    * Records rolling 30s history of Players AND all NPCs (positions, angles,
	--      combat sequences, gunfire tracers, and exact death timestamps!).
	--    * When rewinding N seconds back:
	--      1) Spawns your shootable/killable Past Self Clone replaying your battle
	--         (including shooting tracers at the NPCs!).
	--      2) REVIVES dead NPCs that were killed during those N seconds and spawns
	--         Temporal Echoes replaying your fight with them!
	--      3) Surviving live NPCs on the map are rewound to their past positions/HP
	--         and react in shock to seeing TWO of you (Future You + Past You)!
	--    * 35-second Time Police detention deadline (detains you in a cage, killable!).
	-- ========================================================================
	RICK_PORTAL.TimeHistory         = RICK_PORTAL.TimeHistory or {}
	RICK_PORTAL.NPCTimeHistory      = RICK_PORTAL.NPCTimeHistory or {}
	RICK_PORTAL.PendingFireEvents   = RICK_PORTAL.PendingFireEvents or {}
	RICK_PORTAL.ActiveTimeTravelers = RICK_PORTAL.ActiveTimeTravelers or {}

	local RECORD_INTERVAL = 0.08
	local WINDOW_SECONDS  = 32.0
	local NEXT_REC_AT     = 0
	local NEXT_NPC_ID     = 1

	-- Capture weapon gunfire events for both Players & NPCs so Past Self & Past NPCs shoot in the replay!
	hook.Add("EntityFireBullets", "RickTime_RecordBulletShots", function(ent, data)
		if not IsValid(ent) then return end
		local aimEnd = (data.Src or ent:WorldSpaceCenter()) + (data.Dir or ent:GetForward()) * 750
		RICK_PORTAL.PendingFireEvents[ent] = {
			aimPos  = aimEnd,
			fireSnd = ent:IsPlayer() and "Weapon_SMG1.Single" or "Weapon_AR2.NPC_Single"
		}
	end)

	hook.Add("OnNPCKilled", "RickTime_RecordNPCDeath", function(npc, attacker, inflictor)
		if not IsValid(npc) or not npc.RickTrackID then return end
		local rec = RICK_PORTAL.NPCTimeHistory[npc.RickTrackID]
		if rec then
			rec.deathTime = CurTime()
			rec.deathPos  = npc:GetPos()
			rec.deathAng  = npc:GetAngles()
		end
	end)

	local function BroadcastTimeRift(pos, isReturn)
		net.Start("RickTime_RiftFX")
			net.WriteVector(pos)
			net.WriteBool(isReturn and true or false)
		net.Broadcast()
	end

	function RICK_PORTAL.SummonTimePoliceForPlayer(ply, customLine)
		if not IsValid(ply) or not ply:Alive() then return end
		local st = RICK_PORTAL.ActiveTimeTravelers[ply]
		if st and st.policeSpawned then return end

		if st then
			st.policeSpawned = true
			st.cops = st.cops or {}
		end

		for i = 1, 2 do
			local angOff = math.rad(i * 180 - 35)
			local offset = Vector(math.cos(angOff) * 140, math.sin(angOff) * 140, 10)
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
				if customLine then
					cop:SetSpeechText(customLine)
				end
				if st then
					st.cops[#st.cops + 1] = cop
				end
			end
		end
	end

	function RICK_PORTAL.ClearPlayerTimeTravelState(ply, keepPolice)
		local st = RICK_PORTAL.ActiveTimeTravelers[ply]
		if not st then return end

		if IsValid(st.clone) then
			st.clone:Remove()
		end
		if st.echoNPCs then
			for _, e in ipairs(st.echoNPCs) do
				if IsValid(e) then e:Remove() end
			end
		end
		if not keepPolice and st.cops then
			for _, cop in ipairs(st.cops) do
				if IsValid(cop) then cop:Remove() end
			end
		end

		RICK_PORTAL.ActiveTimeTravelers[ply] = nil
	end

	function RICK_PORTAL.ForceReturnAfterSentence(ply)
		if not IsValid(ply) then return end
		local st = RICK_PORTAL.ActiveTimeTravelers[ply]
		if st and st.presentPos then
			BroadcastTimeRift(ply:GetPos() + Vector(0, 0, 36), true)
			ply:SetPos(st.presentPos)
			ply:SetEyeAngles(st.presentAng)
			ply:EmitSound("RickTime.Warp")
			ply:ScreenFade(SCREENFADE.IN, Color(85, 235, 255, 150), 0.5, 0.05)
		end
		RICK_PORTAL.ClearPlayerTimeTravelState(ply, false)
	end

	function RICK_PORTAL.StartTimeJumpBack(ply, secondsBack, wep)
		if not IsValid(ply) or not ply:Alive() then return end
		local stCurrent = RICK_PORTAL.ActiveTimeTravelers[ply]
		if stCurrent and stCurrent.inPast then return end

		secondsBack     = math.Clamp(secondsBack or 10, 5, 25)
		local now       = CurTime()
		local targetT   = now - secondsBack
		local plyHist   = RICK_PORTAL.TimeHistory[ply] or {}

		local presentPos = ply:GetPos()
		local presentAng = ply:EyeAngles()

		-- 1) Slice Player's recorded timeline from `targetT` .. `now`
		local replaySlice = {}
		for _, f in ipairs(plyHist) do
			if f.t >= targetT then
				replaySlice[#replaySlice + 1] = f
			end
		end

		local pastStartPos = (#replaySlice > 0) and replaySlice[1].pos or (presentPos - ply:GetForward() * 90)
		local pastStartAng = (#replaySlice > 0) and replaySlice[1].ang or presentAng

		local viewOffset = Angle(0, pastStartAng.y, 0):Forward() * -95 + Angle(0, pastStartAng.y, 0):Right() * 38
		local trSafe = util.TraceHull({
			start  = pastStartPos + Vector(0, 0, 16),
			endpos = pastStartPos + viewOffset + Vector(0, 0, 16),
			mins   = Vector(-16, -16, 0),
			maxs   = Vector(16, 16, 72),
			filter = ply,
			mask   = MASK_PLAYERSOLID_BRUSHONLY
		})
		local arrivePos = trSafe.HitPos

		-- 2) Spawn Shootable/Killable Past Self Clone replaying your battle & gunfire!
		local clone = ents.Create("ent_past_self_clone")
		if IsValid(clone) then
			clone:SetPos(pastStartPos)
			clone:SetAngles(Angle(0, pastStartAng.y, 0))
			if #replaySlice == 0 then
				replaySlice[1] = { t = now, pos = pastStartPos, ang = pastStartAng, seq = ply:GetSequence() }
			end
			clone:SetupPlayerEcho(replaySlice, ply)
			clone:Spawn()
			clone:Activate()
		end

		-- 3) Rewind & Revive NPCs!
		--    * Dead NPCs killed after `targetT` come back to life as Temporal Combat Echoes
		--      replaying their exact fight & gunfire against your Past Self (and if YOU save/kill them differently, reality reacts!).
		--    * Live NPCs rewind to their past position/HP and react in shock to the time-traveler!
		local echoNPCs     = {}
		local revivedCount = 0

		-- Remove fresh corpses of NPCs that weren't dead yet at `targetT`!
		for _, rag in ipairs(ents.FindByClass("prop_ragdoll")) do
			if IsValid(rag) and rag:GetCreationTime() >= targetT then
				rag:Remove()
			end
		end

		for trackID, rec in pairs(RICK_PORTAL.NPCTimeHistory) do
			local npcSlice = {}
			for _, nf in ipairs(rec.frames) do
				if nf.t >= targetT then
					npcSlice[#npcSlice + 1] = nf
				end
			end

			if #npcSlice > 0 then
				if IsValid(rec.ent) and rec.ent:Health() > 0 then
					-- Live NPC: rewind to its past position & HP and make it react to the time jump!
					local firstF = npcSlice[1]
					rec.ent:SetPos(firstF.pos)
					rec.ent:SetAngles(Angle(0, firstF.ang.y, 0))
					if firstF.hp and firstF.hp > rec.ent:Health() then
						rec.ent:SetHealth(firstF.hp)
					end
					BroadcastTimeRift(firstF.pos + Vector(0, 0, 36), false)

					-- NPC notices the temporal anomaly & alerts/reacts!
					if rec.ent:IsNPC() then
						rec.ent:SetSchedule(SCHED_ALERT_FACE)
						rec.ent:UpdateEnemyMemory(ply, arrivePos)
					end
				elseif rec.deathTime and rec.deathTime >= targetT then
					-- Dead NPC killed during the last N seconds -> REVIVE IN THE PAST to replay the fight!
					revivedCount = revivedCount + 1
					rec.diedInWindow = true
					rec.killedInPastIntervention = false

					local npcEcho = ents.Create("ent_past_self_clone")
					if IsValid(npcEcho) then
						npcEcho:SetPos(npcSlice[1].pos)
						npcEcho:SetAngles(Angle(0, npcSlice[1].ang.y, 0))
						npcEcho:SetupNPCEcho(npcSlice, rec)
						npcEcho:Spawn()
						npcEcho:Activate()
						echoNPCs[#echoNPCs + 1] = npcEcho
						BroadcastTimeRift(npcSlice[1].pos + Vector(0, 0, 36), false)
					end
				end
			end
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
			deadline      = deadline,
			policeSpawned = false,
			clone         = clone,
			echoNPCs      = echoNPCs,
			cops          = {}
		}

		ply:ChatPrint(string.format("[ВРЕМЕННАЯ ЛИНИЯ] Откат на %d сек. назад. Убитых NPC воскрешено: %d.", secondsBack, revivedCount))
	end

	function RICK_PORTAL.ReturnToPresentTimeline(ply, wep)
		if not IsValid(ply) then return end
		local st = RICK_PORTAL.ActiveTimeTravelers[ply]
		if not st or not st.inPast then return end

		-- Cannot escape while actively detained in handcuffs by living Time Police!
		if ply:GetNWBool("RickTime_Detained", false) then
			ply:ChatPrint("[ПОЛИЦИЯ ВРЕМЕНИ]: Куда собрался, уебок?! Ты в наручниках — отбывай срок или дерись с конвоем!")
			ply:EmitSound("buttons/button10.wav", 75, 85, 0.8)
			return
		end

		BroadcastTimeRift(ply:GetPos() + Vector(0, 0, 36), true)
		BroadcastTimeRift(st.presentPos + Vector(0, 0, 36), true)

		ply:SetPos(st.presentPos)
		ply:SetEyeAngles(st.presentAng)
		ply:EmitSound("RickTime.Warp")
		ply:ScreenFade(SCREENFADE.IN, Color(85, 235, 255, 160), 0.50, 0.05)
		ply:ChatPrint("[ПУШКА ВРЕМЕНИ] Вы вернулись в своё настоящее время!")

		RICK_PORTAL.ClearPlayerTimeTravelState(ply, false)
	end

	hook.Add("Think", "RickTime_RecorderAndPoliceDeadline", function()
		local ct = CurTime()

		if ct >= NEXT_REC_AT then
			NEXT_REC_AT = ct + RECORD_INTERVAL
			local cutoff = ct - WINDOW_SECONDS

			-- 1) Record Players (when not currently inside the past)
			for _, ply in ipairs(player.GetAll()) do
				if IsValid(ply) and ply:Alive() then
					local st = RICK_PORTAL.ActiveTimeTravelers[ply]
					if not (st and st.inPast) then
						local h = RICK_PORTAL.TimeHistory[ply]
						if not h then
							h = {}
							RICK_PORTAL.TimeHistory[ply] = h
						end

						local fireEv = RICK_PORTAL.PendingFireEvents[ply]
						RICK_PORTAL.PendingFireEvents[ply] = nil

						h[#h + 1] = {
							t       = ct,
							pos     = ply:GetPos(),
							ang     = ply:EyeAngles(),
							seq     = ply:GetSequence(),
							fired   = fireEv ~= nil,
							aimPos  = fireEv and fireEv.aimPos or nil,
							fireSnd = fireEv and fireEv.fireSnd or nil
						}

						while #h > 0 and h[1].t < cutoff do
							table.remove(h, 1)
						end
					end
				end
			end

			-- 2) Record all NPCs / NextBots on the map (for reviving dead NPCs & replaying battles!)
			for _, ent in ipairs(ents.GetAll()) do
				if IsValid(ent) and (ent:IsNPC() or ent:IsNextBot()) and ent:GetClass() ~= "npc_time_police" then
					if not ent.RickTrackID then
						ent.RickTrackID = NEXT_NPC_ID
						NEXT_NPC_ID = NEXT_NPC_ID + 1
						local _, pretty = RICK_PORTAL.GetSubspeciesSignature(ent)
						RICK_PORTAL.NPCTimeHistory[ent.RickTrackID] = {
							ent        = ent,
							class      = ent:GetClass(),
							model      = ent:GetModel(),
							skin       = ent:GetSkin() or 0,
							prettyName = pretty or ent:GetClass(),
							maxHP      = ent:GetMaxHealth() > 0 and ent:GetMaxHealth() or ent:Health(),
							frames     = {}
						}
					end

					local rec = RICK_PORTAL.NPCTimeHistory[ent.RickTrackID]
					if rec and ent:Health() > 0 then
						local fireEv = RICK_PORTAL.PendingFireEvents[ent]
						RICK_PORTAL.PendingFireEvents[ent] = nil

						rec.frames[#rec.frames + 1] = {
							t       = ct,
							pos     = ent:GetPos(),
							ang     = ent:GetAngles(),
							seq     = ent:GetSequence(),
							hp      = ent:Health(),
							fired   = fireEv ~= nil,
							aimPos  = fireEv and fireEv.aimPos or nil,
							fireSnd = fireEv and fireEv.fireSnd or nil
						}

						while #rec.frames > 0 and rec.frames[1].t < cutoff do
							table.remove(rec.frames, 1)
						end
					end
				end
			end

			-- Prune expired dead NPC histories older than 32s
			for trackID, rec in pairs(RICK_PORTAL.NPCTimeHistory) do
				if not IsValid(rec.ent) and rec.deathTime and rec.deathTime < cutoff then
					RICK_PORTAL.NPCTimeHistory[trackID] = nil
				end
			end
		end

		-- 3) Check 35-second Time Travel Deadline -> Summon Time Police to DETAIN the offender!
		for ply, st in pairs(RICK_PORTAL.ActiveTimeTravelers) do
			if not IsValid(ply) or not ply:Alive() then
				RICK_PORTAL.ClearPlayerTimeTravelState(ply, true)
			elseif st.inPast and not st.policeSpawned and ct >= st.deadline then
				RICK_PORTAL.SummonTimePoliceForPlayer(ply)
			end
		end
	end)

	hook.Add("PlayerDeath", "RickTime_CleanupOnDeath", function(ply)
		ply:SetNWBool("RickTime_Detained", false)
		ply:SetNWFloat("RickTime_SentenceEnd", 0)
		RICK_PORTAL.ClearPlayerTimeTravelState(ply, false)
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

	local matParticleGlow = CreateMaterial("RickOmega_ParticleGlow_v3", "UnlitGeneric", {
		["$basetexture"] = "sprites/light_glow02",
		["$additive"]    = "1",
		["$vertexcolor"] = "1",
		["$vertexalpha"] = "1"
	})

	RICK_PORTAL.ActiveVaporizeArcs = RICK_PORTAL.ActiveVaporizeArcs or {}
	RICK_PORTAL.ActiveTimeRifts    = RICK_PORTAL.ActiveTimeRifts or {}

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

	local matLaser = Material("Effects/laser1")
	local matGlow  = Material("sprites/light_glow02_add")

	hook.Add("PostDrawTranslucentRenderables", "RickOmega_DrawVaporizeArcs", function(bDepth, bSkybox)
		if bSkybox then return end
		local ct = CurTime()

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
