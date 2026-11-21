-- ============================================================================
-- Rick and Morty Addon - Shared Config, Sounds & Multiverse Subspecies Ban List
-- ============================================================================

AddCSLuaFile()

RICK_PORTAL = RICK_PORTAL or {}

-- Stores subspecies erased across ALL universes in the current session!
-- Keys are subspecies identifiers (exact model path for props/NPCs/ragdolls + class fallback).
RICK_PORTAL.ErasedSubspecies = RICK_PORTAL.ErasedSubspecies or {}

function RICK_PORTAL.GetSubspeciesSignature(ent)
	if not IsValid(ent) then return nil, nil end
	local cls = ent:GetClass()
	local mdl = string.lower(ent:GetModel() or "")

	-- Never erase worldspawn or essential internal controllers
	if ent:IsWorld() then return nil, nil end
	if cls == "predicted_viewmodel" or cls == "gmod_hands" or cls == "ent_omega_device" then
		return nil, nil
	end

	-- Identify subspecies:
	-- 1) For NPCs & NextBots: combine class + model if specific, AND also ban the NPC class so ALL variants of that creature subspecies vanish!
	if ent:IsNPC() or ent:IsNextBot() then
		local pretty = ent.PrintName and ent.PrintName ~= "" and ent.PrintName or language.GetPhrase(cls)
		if pretty == cls then
			pretty = string.gsub(cls, "^npc_", "")
			pretty = string.upper(string.sub(pretty, 1, 1)) .. string.sub(pretty, 2)
		end
		return "class:" .. cls, pretty, mdl
	end

	-- 2) For Players: subspecies is their playermodel (or player class) — kills all players using that playermodel and vaporizes if respawned with it
	if ent:IsPlayer() then
		local shortMdl = string.GetFileFromFilename(mdl) or mdl
		return "playermodel:" .. mdl, "Subspecies (" .. shortMdl .. ")", mdl
	end

	-- 3) For Props / Ragdolls / Vehicles / Entities: match exact 3D model (or class for scripted entities)
	if string.StartWith(cls, "prop_") and mdl ~= "" then
		local shortMdl = string.StripExtension(string.GetFileFromFilename(mdl) or mdl)
		return "model:" .. mdl, "Object (" .. shortMdl .. ")", mdl
	end

	local pretty = (ent.PrintName and ent.PrintName ~= "" and ent.PrintName) or cls
	return "class:" .. cls, pretty, mdl
end

function RICK_PORTAL.MatchesErasedSubspecies(ent)
	if not IsValid(ent) then return false end
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

	resource.AddSingleFile("materials/rick_portal/portal_swirl.png")
	resource.AddSingleFile("materials/rick_portal/portal_inner_swirl.png")
	resource.AddSingleFile("materials/rick_portal/liquid_blob.png")
	resource.AddSingleFile("materials/entities/weapon_rick_portalgun.png")
	resource.AddSingleFile("materials/entities/ent_rick_portal.png")
	resource.AddSingleFile("materials/entities/ent_omega_device.png")
	resource.AddSingleFile("materials/entities/weapon_omega_device.png")
	resource.AddSingleFile("materials/vgui/entities/weapon_rick_portalgun.png")
	resource.AddSingleFile("materials/vgui/entities/weapon_omega_device.png")

	resource.AddSingleFile("sound/rick_portal/portal_shoot.wav")
	resource.AddSingleFile("sound/rick_portal/portal_open.wav")
	resource.AddSingleFile("sound/rick_portal/portal_enter.wav")
	resource.AddSingleFile("sound/rick_portal/portal_close.wav")
	resource.AddSingleFile("sound/rick_portal/omega_charge.wav")
	resource.AddSingleFile("sound/rick_portal/omega_erase.wav")

	CreateConVar("sv_rickportal_maxdist", "420", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Max free-air flight distance before liquid transforms into a portal mid-air")
	CreateConVar("sv_rickportal_lifetime", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Portal lifetime in seconds (0 = infinite until closed with Reload)")

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
			-- Dissolve & erase immediately from reality
			ent:Remove()
		end
	end

	function RICK_PORTAL.EraseSubspeciesAcrossMultiverse(targetEnt, attacker)
		if not IsValid(targetEnt) then return 0, nil end
		local sig, prettyName, mdl = RICK_PORTAL.GetSubspeciesSignature(targetEnt)
		if not sig then return 0, nil end

		RICK_PORTAL.ErasedSubspecies[sig] = {
			name = prettyName,
			time = CurTime()
		}
		-- If an NPC also has a specific model (like citizen/combine ragdoll), block ragdolls of that model too!
		if (targetEnt:IsNPC() or targetEnt:IsNextBot()) and mdl and mdl ~= "" then
			RICK_PORTAL.ErasedSubspecies["ragdoll_mdl:" .. mdl] = {
				name = prettyName .. " (Remains)",
				hidden = true,
				time = CurTime()
			}
		end

		local erasedCount = 0
		for _, ent in ipairs(ents.GetAll()) do
			if IsValid(ent) and ent ~= attacker then
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

	-- PERMANENT MULTIVERSAL EXTINCTION HOOK:
	-- Any attempt to spawn this creature/subspecies again in this universe is instantaneously erased!
	hook.Add("OnEntityCreated", "RickOmega_PreventErasedSubspecies", function(ent)
		if table.IsEmpty(RICK_PORTAL.ErasedSubspecies) then return end
		timer.Simple(0, function()
			if not IsValid(ent) then return end
			local match = RICK_PORTAL.MatchesErasedSubspecies(ent)
			if not match and (ent:GetClass() == "prop_ragdoll" or ent:GetClass() == "class C_ClientRagdoll") then
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
		PrintMessage(HUD_PRINTTALK, "[OMEGA DEVICE] Временные линии восстановлены — стёртые подвиды возвращены в реальность.")
	end)
else
	CreateClientConVar("cl_rickportal_dlight", "1", true, false, "Enable dynamic lighting on portals, portal gun and Omega Device")

	net.Receive("RickOmega_SyncErased", function()
		local count = net.ReadUInt(8)
		RICK_PORTAL.ErasedSubspecies = {}
		for i = 1, count do
			local sig = net.ReadString()
			local name = net.ReadString()
			RICK_PORTAL.ErasedSubspecies[sig] = { name = name }
		end
	end)

	-- Client-side blue-cyan lightning disintegration burst whenever an entity is erased!
	local matParticleGlow = CreateMaterial("RickOmega_ParticleGlow_v1", "UnlitGeneric", {
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
			pos = pos,
			rad = rad,
			birth = CurTime(),
			dur = 0.75,
			seed = math.Rand(0, 100)
		})

		local em = ParticleEmitter(pos, false)
		if IsValid(em) then
			for i = 1, 32 do
				local dir = VectorRand():GetNormalized()
				local p = em:Add(matParticleGlow, pos + dir * math.Rand(0, rad * 0.65))
				if p then
					p:SetVelocity(dir * math.Rand(60, 240) + Vector(0, 0, math.Rand(30, 110)))
					p:SetDieTime(math.Rand(0.45, 0.95))
					p:SetStartAlpha(255)
					p:SetEndAlpha(0)
					p:SetStartSize(math.Rand(8, 22))
					p:SetEndSize(0)
					if i % 3 == 0 then
						p:SetColor(225, 250, 255)
					else
						p:SetColor(55, 195, 255)
					end
					p:SetAirResistance(85)
				end
			end
			em:Finish()
		end

		local dlightConVar = GetConVar("cl_rickportal_dlight")
		if not dlightConVar or dlightConVar:GetBool() then
			local dl = DynamicLight(math.random(20000, 29999))
			if dl then
				dl.pos = pos
				dl.r = 65
				dl.g = 205
				dl.b = 255
				dl.brightness = 4.5
				dl.Decay = 1200
				dl.Size = math.max(240, rad * 4)
				dl.DieTime = CurTime() + 0.65
			end
		end
	end)

	local matLaser = Material("Effects/laser1")
	local matGlow  = Material("sprites/light_glow02_add")

	hook.Add("PostDrawTranslucentRenderables", "RickOmega_DrawVaporizeArcs", function(bDepth, bSkybox)
		if bSkybox then return end
		local list = RICK_PORTAL.ActiveVaporizeArcs
		if not list or #list == 0 then return end

		local ct = CurTime()
		for i = #list, 1, -1 do
			local fx = list[i]
			local t = (ct - fx.birth) / fx.dur
			if t >= 1 then
				table.remove(list, i)
			else
				local inv = 1.0 - t
				render.SetMaterial(matGlow)
				render.DrawSprite(fx.pos, fx.rad * 3.8 * inv, fx.rad * 3.8 * inv, Color(85, 220, 255, 235 * inv))
				render.DrawSprite(fx.pos, fx.rad * 1.9 * inv, fx.rad * 1.9 * inv, Color(235, 252, 255, 255 * inv))

				-- Jagged blue-white Omega energy bolts tearing the target out of all timelines
				render.SetMaterial(matLaser)
				for b = 1, 7 do
					local a1 = b * 0.9 + ct * 14 + fx.seed
					local dir = Vector(math.cos(a1), math.sin(a1), math.sin(a1 * 1.7)):GetNormalized()
					local pStart = fx.pos
					local pMid   = fx.pos + dir * (fx.rad * (0.6 + t * 0.9)) + VectorRand() * 8
					local pEnd   = fx.pos + dir * (fx.rad * (1.3 + t * 1.8))
					render.DrawBeam(pStart, pMid, 12 * inv, 0, 1, Color(120, 230, 255, 240 * inv))
					render.DrawBeam(pMid, pEnd, 7 * inv, 0, 1, Color(230, 250, 255, 200 * inv))
				end
			end
		end
	end)
end

sound.Add({
	name = "RickPortal.Shoot",
	channel = CHAN_WEAPON,
	volume = 0.9,
	level = 75,
	pitch = { 96, 105 },
	sound = "rick_portal/portal_shoot.wav"
})

sound.Add({
	name = "RickPortal.Open",
	channel = CHAN_STATIC,
	volume = 0.95,
	level = 80,
	pitch = { 95, 104 },
	sound = "rick_portal/portal_open.wav"
})

sound.Add({
	name = "RickPortal.Enter",
	channel = CHAN_ITEM,
	volume = 0.95,
	level = 80,
	pitch = { 96, 106 },
	sound = "rick_portal/portal_enter.wav"
})

sound.Add({
	name = "RickPortal.Close",
	channel = CHAN_STATIC,
	volume = 0.85,
	level = 75,
	pitch = { 95, 105 },
	sound = "rick_portal/portal_close.wav"
})

sound.Add({
	name = "RickOmega.Charge",
	channel = CHAN_WEAPON,
	volume = 1.0,
	level = 90,
	pitch = { 98, 102 },
	sound = "rick_portal/omega_charge.wav"
})

sound.Add({
	name = "RickOmega.Erase",
	channel = CHAN_STATIC,
	volume = 1.0,
	level = 105,
	pitch = { 96, 102 },
	sound = "rick_portal/omega_erase.wav"
})
