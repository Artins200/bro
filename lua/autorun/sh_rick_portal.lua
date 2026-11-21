-- ============================================================================
-- Rick and Morty Portal Gun Addon - Resource Registration & Shared Config
-- ============================================================================

AddCSLuaFile()

RICK_PORTAL = RICK_PORTAL or {}

-- Dimension codes shown on the red LED display (cycling with E + Reload or R)
RICK_PORTAL.Dimensions = {
	"C-137",
	"C-131",
	"J19Z7",
	"35-C",
	"K-83",
	"D-99",
	"B-716"
}

if SERVER then
	-- Ensure clients download custom textures and synthesized sound effects
	resource.AddSingleFile("materials/rick_portal/portal_swirl.png")
	resource.AddSingleFile("materials/rick_portal/portal_inner_swirl.png")
	resource.AddSingleFile("materials/rick_portal/liquid_blob.png")
	resource.AddSingleFile("materials/entities/weapon_rick_portalgun.png")
	resource.AddSingleFile("materials/entities/ent_rick_portal.png")
	resource.AddSingleFile("materials/vgui/entities/weapon_rick_portalgun.png")

	resource.AddSingleFile("sound/rick_portal/portal_shoot.wav")
	resource.AddSingleFile("sound/rick_portal/portal_open.wav")
	resource.AddSingleFile("sound/rick_portal/portal_enter.wav")
	resource.AddSingleFile("sound/rick_portal/portal_close.wav")

	CreateConVar("sv_rickportal_maxdist", "420", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Max free-air flight distance before liquid transforms into a portal mid-air")
	CreateConVar("sv_rickportal_lifetime", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Portal lifetime in seconds (0 = infinite until closed with Reload)")
else
	CreateClientConVar("cl_rickportal_dlight", "1", true, false, "Enable green dynamic lighting on portals and portal gun")
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
