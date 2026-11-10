--[[
	The world map (World engine module; Modules/RegionSystem, Shared/EngineModules/World/Page).
	Every life is born in a Starter region (StarterWeight; here only the Suburban Ward); travel moves between
	Neighbors for 1 action diamond + the destination's TravelFee and rolls a road
	encounter (TravelEventsConfig).

	Region fields:
		Name, Tagline (prologue), Lore, Safety (label), Icon, Color
		MapPosition    Vector2 in map scale (0-1) for the drawn cartography
		Neighbors      region ids connected by a road
		Starter / StarterWeight   birth region odds
		Requires       Shared/Requirements spec to travel there
		AltRequires / AltFee   alternative way in (e.g. pay a toll instead of the grade)
		Buffs          shared buff keys while living there (QiMult = the region's cursed energy density)
		DemonicBuffs   extra buffs while Alignment <= DemonicAlignment (curse users)
		Hazard         { Health = -3, ImmuneMaxAlignment = -20 } yearly harm unless curse-aligned enough
		GlimpseBonus   added to Past-Life Glimpse chance (Samsara)
		Features       labels for the map panel (Black Market, Jackpot arenas, ...)
]]

local WorldRegionsConfig = {}

WorldRegionsConfig.TravelMinAge = 12
WorldRegionsConfig.TravelSlots = 1
WorldRegionsConfig.DemonicAlignment = -20

WorldRegionsConfig.Regions = {
	{
		Id = "qinghe", Name = "Tokyo Suburban Ward & Clan Estates", Icon = "🏘", Color = Color3.fromRGB(110, 200, 140),
		Tagline = "a quiet residential ward of narrow streets and old clan compounds on the edge of Tokyo",
		Lore = "Parks, elementary schools and family dojos. Children here first notice the shapes nobody else can see, long before any academy calls.",
		Safety = "High", Starter = true, StarterWeight = 45, TravelFee = 50,
		MapPosition = Vector2.new(0.22, 0.47), Neighbors = { "crimson", "capital", "kunlun", "hills", "arcade" },
		Buffs = { StudyMult = 1.1, StatXp = { Intelligence = 1.1 } },
		Features = { "Elementary school", "Family shrine & dojo" },
	},
	{
		Id = "crimson", Name = "Tokyo Jujutsu High Campus", Icon = "⛩", Color = Color3.fromRGB(220, 80, 70),
		Tagline = "the hidden mountain academy on the edge of Tokyo",
		Lore = "Training grounds, dormitories and cursed corpse sparring. Students run supervised exorcisms; upperclassmen run a quiet trade in cursed goods.",
		-- Grade 4 Sorcerer to enroll (no longer a birthplace).
		Safety = "Low", TravelFee = 30, Requires = { MinRealm = 2 },
		MapPosition = Vector2.new(0.13, 0.84), Neighbors = { "qinghe", "capital", "marsh", "coast" },
		Buffs = { QiMult = 0.85, StatXp = { Strength = 1.25 }, ProficiencyXp = { Sword = 1.25, Spear = 1.25 } },
		Features = { "Dorm black market", "Cursed corpse sparring" },
	},
	{
		Id = "capital", Name = "Kyoto Sister-School Grounds", Icon = "🏯", Color = Color3.fromRGB(230, 200, 110),
		Tagline = "the temple estates of the Kyoto sister school",
		Lore = "Bloodline etiquette, cursed tool forms and barrier techniques are taught behind paper walls. The yearly Exchange Event makes and breaks families.",
		-- Grade 3 Sorcerer to be received by the Kyoto school (no longer a birthplace).
		Safety = "Medium", TravelFee = 120, Requires = { MinRealm = 3 },
		MapPosition = Vector2.new(0.5, 0.72), Neighbors = { "qinghe", "crimson", "kunlun", "marsh", "arcade", "window_office", "coast" },
		Buffs = { QiMult = 1.1, SalaryMult = 1.3, StatXp = { Charisma = 1.3 } },
		Features = { "Exchange Event", "Clan etiquette" },
	},
	{
		Id = "kunlun", Name = "Star Corridor & Cursed Warehouse", Icon = "🗝", Color = Color3.fromRGB(140, 200, 255),
		Tagline = "the labyrinth of vaults beneath Jujutsu High where sealed cursed tools sleep",
		Lore = "Special Grade cursed tools and ancient scrolls wait behind shifting barriers. Sorcerers forge and study here; few students are allowed below.",
		-- Grade 3 Sorcerer, or age 16 and the faction toll (AltRequires / AltFee).
		Safety = "Medium", TravelFee = 300, Requires = { MinRealm = 3 }, AltRequires = { MinAge = 16 }, AltFee = 1500,
		MapPosition = Vector2.new(0.42, 0.16), Neighbors = { "qinghe", "capital", "ruins", "hills", "window_office", "hiei" },
		Buffs = { QiMult = 1.5, ProficiencyXp = { Sword = 1.25, QiArts = 1.25 } },
		Features = { "Sealed cursed tools", "Ancient technique scrolls" },
	},
	{
		Id = "marsh", Name = "Shibuya Veil District", Icon = "🌃", Color = Color3.fromRGB(170, 50, 90),
		Tagline = "neon-lit downtown Tokyo trapped beneath a dense night curtain",
		Lore = "High-grade cursed spirits crawl through the stations and ambushes come from every alley. Cursed energy runs thick, and curse users thrive.",
		Safety = "Deadly", TravelFee = 200, Requires = { MinAge = 14 },
		MapPosition = Vector2.new(0.84, 0.84), Neighbors = { "crimson", "capital", "ruins", "colony", "coast" },
		Buffs = { QiMult = 1.6 }, DemonicBuffs = { QiMult = 1.4 },
		Hazard = { Health = -3, ImmuneMaxAlignment = -20 },
		Features = { "Curse-user CE (+40% if Alignment <= -20)", "Veil miasma: -3 HP/yr unless curse-aligned" },
	},
	{
		Id = "ruins", Name = "Shinjuku Showdown Ruins", Icon = "👹", Color = Color3.fromRGB(190, 150, 255),
		Tagline = "the evacuated heart of Tokyo, scarred by clashing Domain Expansions",
		Lore = "Transcendent sorcerers and the King of Curses fought here. Relics of the battle, and memories of other lives, still hum in the rubble.",
		Safety = "Extreme", TravelFee = 1500, Requires = { MinRealm = 4 },
		MapPosition = Vector2.new(0.82, 0.3), Neighbors = { "kunlun", "marsh", "window_office", "hiei", "colony" },
		Buffs = { QiMult = 2.5 }, Hazard = { Health = -6 }, GlimpseBonus = 0.1,
		Features = { "Domain Expansion scars", "Past-life glimpses +10%", "Residual cursed energy: -6 HP/yr" },
	},
	-- Content expansion (2026-11-02): six more regions. Each one's cursed energy density
	-- stays below the existing region with the same gate, so grades do not come faster.
	{
		Id = "hills", Name = "Cemetery Hills", Icon = "⚰", Color = Color3.fromRGB(150, 160, 180),
		Tagline = "a hillside town of old cemeteries where the dead are never quite quiet",
		Lore = "Fog, temple bells and rows of moss-covered graves. Weak curses gather here every Obon, and local kids learn to fight them with sticks.",
		Safety = "Medium", TravelFee = 80, Requires = { MinAge = 12 },
		MapPosition = Vector2.new(0.11, 0.2), Neighbors = { "qinghe", "kunlun" },
		Buffs = { QiMult = 1.1, StatXp = { Vitality = 1.15 } },
		Features = { "Obon curse swarms", "Temple graveyards" },
	},
	{
		Id = "arcade", Name = "Ikebukuro Arcade Streets", Icon = "🎮", Color = Color3.fromRGB(240, 140, 200),
		Tagline = "a loud maze of arcades, karaoke bars and pawn shops",
		Lore = "Brokers sell cursed trinkets beside claw machines. Freelance sorcerers find paid work here, and nobody asks where the money comes from.",
		Safety = "Medium", TravelFee = 60, Requires = { MinAge = 12 },
		MapPosition = Vector2.new(0.35, 0.62), Neighbors = { "qinghe", "capital" },
		Buffs = { SalaryMult = 1.2, StatXp = { Charisma = 1.15, Agility = 1.1 } },
		Features = { "Freelance contracts", "Cursed trinket brokers" },
	},
	{
		Id = "window_office", Name = "Window Liaison Office", Icon = "🏢", Color = Color3.fromRGB(120, 150, 200),
		Tagline = "a grey office building where the jujutsu world files its paperwork",
		Lore = "Window agents, auxiliary managers and curtain specialists run the world's quietest war from here. The coffee is terrible; the archives are not.",
		Safety = "High", TravelFee = 150, Requires = { MinRealm = 2 },
		MapPosition = Vector2.new(0.63, 0.47), Neighbors = { "capital", "kunlun", "ruins" },
		Buffs = { QiMult = 0.8, StudyMult = 1.2, StatXp = { Intelligence = 1.2 }, ProficiencyXp = { QiArts = 1.15 } },
		Features = { "Mission archives", "Curtain training" },
	},
	{
		Id = "hiei", Name = "Mountain Barrier Temple", Icon = "⛰", Color = Color3.fromRGB(110, 210, 200),
		Tagline = "a mountain temple whose monks have held the same barrier for a thousand years",
		Lore = "Sutras on every pillar, barriers inside barriers. The monks teach barrier arts to anyone who survives the climb and the silence.",
		Safety = "Medium", TravelFee = 400, Requires = { MinRealm = 3 },
		MapPosition = Vector2.new(0.63, 0.14), Neighbors = { "kunlun", "ruins" },
		Buffs = { QiMult = 1.3, ProficiencyXp = { QiArts = 1.3 } },
		Features = { "Thousand-year barrier", "Silent meditation halls" },
	},
	{
		Id = "colony", Name = "Sealed Colony Barrier", Icon = "🌀", Color = Color3.fromRGB(200, 90, 230),
		Tagline = "a city swallowed by a killing-game barrier, where points are paid in blood",
		Lore = "Once you cross the barrier you cannot leave without the rules allowing it. Ancient sorcerers in borrowed bodies hunt everyone else.",
		Safety = "Extreme", TravelFee = 1200, Requires = { MinRealm = 4 },
		MapPosition = Vector2.new(0.93, 0.57), Neighbors = { "marsh", "ruins" },
		Buffs = { QiMult = 2.0, StatXp = { Strength = 1.2 } }, Hazard = { Health = -4 },
		Features = { "Killing-game rules", "Colony fights: -4 HP/yr" },
	},
	{
		Id = "coast", Name = "Southern Coast Station", Icon = "🌊", Color = Color3.fromRGB(90, 180, 240),
		Tagline = "a sleepy seaside town where retired sorcerers go to rest",
		Lore = "Sea wind, cheap fish and a beach where curses born from drowned sailors wash up every winter. A good place to heal, and to hide.",
		Safety = "High", TravelFee = 250, Requires = { MinAge = 14 },
		MapPosition = Vector2.new(0.67, 0.84), Neighbors = { "crimson", "capital", "marsh" },
		Buffs = { StatXp = { Agility = 1.2, Vitality = 1.1 } },
		Features = { "Retired sorcerers", "Winter sea curses" },
	},
}

WorldRegionsConfig.Default = "qinghe"

-- Reincarnation prologue shown at the start of every life (ReplicatedFirst/IntroAndLoadingUI).
-- {region} and {tagline} are filled from the birth region; <b>/<i> are rich text.
WorldRegionsConfig.Prologue = table.concat({
	"<i>Beyond the veil of a quiet death, your drifting soul stood before the Wheel of Curses, turning in the dark. ",
	"'This was neither your first breath, nor shall it be your last,' a voice whispered from every shadow, ",
	"binding you once more to a world where fear itself takes shape.</i>\n\n",
	"<i>Yet as oblivion washed over you, the words dissolved into cursed static. When your eyes opened once more, ",
	"you were nothing more than an infant crying in <b>{region}</b> — {tagline}.</i>\n\n",
	"<i>Curses already feed on this world's fear—and through your hands, ",
	"it will either be cleansed by a legendary sorcerer or devoured by a calamity.</i>",
})

WorldRegionsConfig.ById = {}
for _, region in WorldRegionsConfig.Regions do
	WorldRegionsConfig.ById[region.Id] = region
end

function WorldRegionsConfig.Get(id: string?)
	return WorldRegionsConfig.ById[id or ""] or WorldRegionsConfig.ById[WorldRegionsConfig.Default]
end

function WorldRegionsConfig.AreNeighbors(a: string, b: string): boolean
	local region = WorldRegionsConfig.ById[a]
	return region ~= nil and table.find(region.Neighbors, b) ~= nil
end

return WorldRegionsConfig
