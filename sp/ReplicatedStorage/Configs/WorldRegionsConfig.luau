--[[
	The world map (World engine module; Modules/RegionSystem, Shared/EngineModules/World/Page).
	Every life is born in a Starter region (StarterWeight; here only Karakura Town); travel moves between
	Neighbors for 1 action diamond + the destination's TravelFee and rolls a road
	encounter (TravelEventsConfig).

	Region fields:
		Name, Tagline (prologue), Lore, Safety (label), Icon, Color
		MapPosition    Vector2 in map scale (0-1) for the drawn cartography
		Neighbors      region ids connected by a road
		Starter / StarterWeight   birth region odds
		Requires       Shared/Requirements spec to travel there
		AltRequires / AltFee   alternative way in (e.g. pay a toll instead of the grade)
		Buffs          shared buff keys while living there (QiMult = the region's Reiatsu density)
		DemonicBuffs   extra buffs while Alignment <= DemonicAlignment (Hollow-touched souls)
		Hazard         { Health = -3, ImmuneMaxAlignment = -20 } yearly harm unless Hollow-touched enough
		GlimpseBonus   added to Past-Life Glimpse chance (Samsara)
		Features       labels for the map panel (Black Market, Jackpot arenas, ...)
]]

local WorldRegionsConfig = {}

WorldRegionsConfig.TravelMinAge = 12
WorldRegionsConfig.TravelSlots = 1
WorldRegionsConfig.DemonicAlignment = -20

WorldRegionsConfig.Regions = {
	{
		Id = "qinghe", Name = "Karakura Town — Residential Ward", Icon = "🏘", Color = Color3.fromRGB(125, 211, 252),
		Tagline = "a peaceful modern town by the river where living children grow up",
		Lore = "School, the riverbank, the karate dojo and a family clinic. Here kids first notice the Plus spirits drifting by, and the Hollows that hunt them.",
		Safety = "High", Starter = true, StarterWeight = 45, TravelFee = 50,
		MapPosition = Vector2.new(0.1, 0.37), Neighbors = { "crimson", "capital", "kunlun", "karakura_river" },
		Buffs = { StudyMult = 1.1, StatXp = { Intelligence = 1.1 } },
		Features = { "Elementary school", "Riverbank & karate dojo" },
	},
	{
		Id = "crimson", Name = "Urahara Underground Training Cavern", Icon = "🪨", Color = Color3.fromRGB(249, 115, 22),
		Tagline = "a vast rock canyon hidden beneath a candy shop",
		Lore = "Substitute Reapers shatter their soul chains, spar to exhaustion and awaken Shikai under extreme pressure. The shopkeeper also sells things he shouldn't.",
		-- Substitute Reaper (class 2) to be let downstairs.
		Safety = "Low", TravelFee = 30, Requires = { MinRealm = 2 },
		MapPosition = Vector2.new(0.3, 0.37), Neighbors = { "qinghe", "capital", "marsh", "naruki" },
		Buffs = { QiMult = 0.85, StatXp = { Strength = 1.25 }, ProficiencyXp = { Sword = 1.25, Spear = 1.25 } },
		Features = { "Back-room spirit goods", "Pressure sparring" },
	},
	{
		Id = "capital", Name = "Seireitei — 13 Court Guard Barracks", Icon = "🏯", Color = Color3.fromRGB(248, 250, 252),
		Tagline = "the white-walled fortress capital of the Gotei 13",
		Lore = "Division missions, squad sparring and lieutenant duties behind white walls. Noble houses and the Central 46 make and break careers.",
		-- Unseated Soul Reaper (class 3) to be posted to a division.
		Safety = "Medium", TravelFee = 120, Requires = { MinRealm = 3 },
		MapPosition = Vector2.new(0.9, 0.37), Neighbors = { "qinghe", "crimson", "kunlun", "marsh", "relief_gardens" },
		Buffs = { QiMult = 1.1, SalaryMult = 1.3, StatXp = { Charisma = 1.3 } },
		Features = { "Division promotion exams", "Noble house politics" },
	},
	{
		Id = "kunlun", Name = "Shin'o Spiritual Academy", Icon = "🎓", Color = Color3.fromRGB(56, 189, 248),
		Tagline = "the elite six-year academy of Soul Society",
		Lore = "Zanjutsu, Hakuda, Hoho and Kido drilled into aspiring officers. Rich families buy their children a seat; everyone else earns one.",
		-- Unseated Soul Reaper (class 3), or age 16 and the tuition (AltRequires / AltFee).
		Safety = "Medium", TravelFee = 300, Requires = { MinRealm = 3 }, AltRequires = { MinAge = 16 }, AltFee = 1500,
		MapPosition = Vector2.new(0.7, 0.37), Neighbors = { "qinghe", "capital", "ruins", "kido_hall" },
		Buffs = { QiMult = 1.5, ProficiencyXp = { Sword = 1.25, QiArts = 1.25 } },
		Features = { "Zanjutsu & Kido classes", "Academy tuition" },
	},
	{
		Id = "marsh", Name = "Outer Rukongai Districts", Icon = "🏚", Color = Color3.fromRGB(180, 140, 100),
		Tagline = "the rough frontier towns beyond the Senkaimon gate",
		Lore = "Thieves, hungry souls and stray Hollows. Early patrols learn fast here; those touched by a Hollow fit in a little too well.",
		Safety = "Dangerous", TravelFee = 200, Requires = { MinAge = 14 },
		MapPosition = Vector2.new(0.5, 0.37), Neighbors = { "crimson", "capital", "ruins", "inner_rukon" },
		Buffs = { QiMult = 1.6 }, DemonicBuffs = { QiMult = 1.4 },
		Hazard = { Health = -3, ImmuneMaxAlignment = -20 },
		Features = { "Hollow-touched Reiatsu (+40% if Alignment <= -20)", "Frontier danger: -3 HP/yr unless Hollow-touched" },
	},
	{
		Id = "ruins", Name = "Sokyoku Hill & Secret Bankai Cave", Icon = "⛰", Color = Color3.fromRGB(165, 180, 252),
		Tagline = "sacred execution cliffs above a hidden hot-spring training cave",
		Lore = "Tenshintai dolls force a Zanpakuto spirit into the world for three-day Bankai trials. Visions of other lives surface in the steam.",
		Safety = "Extreme", TravelFee = 1500, Requires = { MinRealm = 4 },
		MapPosition = Vector2.new(0.9, 0.62), Neighbors = { "kunlun", "marsh", "fake_karakura", "hollow_wastes" },
		Buffs = { QiMult = 2.5 }, Hazard = { Health = -6 }, GlimpseBonus = 0.1,
		Features = { "Tenshintai Bankai trials", "Past-life glimpses +10%", "Crushing pressure: -6 HP/yr" },
	},
	{
		Id = "fake_karakura", Name = "Karakura Fake Town — Visored Warehouse", Icon = "🎭", Color = Color3.fromRGB(226, 232, 240),
		Tagline = "a barrier-sealed copy of Karakura built as a battlefield",
		Lore = "Visored teach hollowfication in eleven-second inner-world duels while Arrancar invasions test the barrier.",
		-- Squad Lieutenant (class 6).
		Safety = "Extreme", TravelFee = 2500, Requires = { MinRealm = 6 },
		MapPosition = Vector2.new(0.7, 0.62), Neighbors = { "ruins", "hueco_mundo", "dangai" },
		Buffs = { QiMult = 3 }, DemonicBuffs = { QiMult = 1.3 },
		Hazard = { Health = -4, ImmuneMaxAlignment = -20 },
		Features = { "Hollow mask training (+30% if Alignment <= -20)", "Arrancar raids: -4 HP/yr unless Hollow-touched" },
	},
	{
		Id = "hueco_mundo", Name = "Hueco Mundo — Forest of Menos", Icon = "🌑", Color = Color3.fromRGB(148, 163, 184),
		Tagline = "an endless quartz-tree abyss beneath the white desert",
		Lore = "Gillian and Adjuchas Hollows swarm in the dark. The strong grow stronger by devouring; the weak are devoured.",
		-- Bankai Captain (class 7).
		Safety = "Extreme", TravelFee = 4000, Requires = { MinRealm = 7 },
		MapPosition = Vector2.new(0.5, 0.62), Neighbors = { "fake_karakura", "las_noches", "menos_sands" },
		Buffs = { QiMult = 4 }, DemonicBuffs = { QiMult = 1.3 },
		Hazard = { Health = -8 },
		Features = { "Menos swarms", "Hollow devouring (+30% if Alignment <= -20)", "Abyss: -8 HP/yr" },
	},
	{
		Id = "las_noches", Name = "Las Noches Dome & Wahrwelt Shadow Empire", Icon = "🏰", Color = Color3.fromRGB(56, 189, 248),
		Tagline = "the Espada's canopy fortress and the frozen Quincy shadow city",
		Lore = "Espada and Sternritter hold their thrones here. Every corridor is a duel with someone who has never lost.",
		-- Head-Captain / Vasto Lorde (class 8).
		Safety = "Extreme", TravelFee = 6000, Requires = { MinRealm = 8 },
		MapPosition = Vector2.new(0.3, 0.62), Neighbors = { "hueco_mundo", "reiokyu", "shadow_vault" },
		Buffs = { QiMult = 5, ProficiencyXp = { Sword = 1.2, Spear = 1.2, QiArts = 1.2 } },
		Hazard = { Health = -10 },
		Features = { "Espada & Sternritter duels", "All combat arts +20%", "Enemy fortress: -10 HP/yr" },
	},
	{
		Id = "reiokyu", Name = "Soul King Royal Palace — Reiokyu", Icon = "👑", Color = Color3.fromRGB(245, 158, 11),
		Tagline = "five floating divine cities in the heavens above Soul Society",
		Lore = "Squad Zero guards the Soul King's palace. Only transcendent souls are invited, and few return unchanged.",
		-- Schutzstaffel Royal Guard (class 9).
		Safety = "Divine", TravelFee = 10000, Requires = { MinRealm = 9 },
		MapPosition = Vector2.new(0.1, 0.62), Neighbors = { "las_noches", "frozen_garden" },
		Buffs = { QiMult = 7 }, GlimpseBonus = 0.15,
		Features = { "Squad Zero palaces", "Past-life glimpses +15%" },
	},
	-- Content expansion (2026-11-02): 10 more regions (a new top and bottom row).
	{
		Id = "karakura_river", Name = "Karakura Riverbank & Old Shrine", Icon = "🏮", Color = Color3.fromRGB(120, 200, 230),
		Tagline = "a quiet riverbank where the living walk past more ghosts than they know",
		Lore = "Lantern festivals, a crumbling shrine and a ghost on every bench. Hollows rarely bother to come this far.",
		Safety = "High", Starter = true, StarterWeight = 25, TravelFee = 40,
		MapPosition = Vector2.new(0.1, 0.12), Neighbors = { "qinghe", "naruki" },
		Buffs = { StatXp = { QiControl = 1.1 }, StressPerYear = -1 },
		Features = { "Lantern festival", "Friendly ghosts" },
	},
	{
		Id = "naruki", Name = "Naruki City Arcades", Icon = "🕹", Color = Color3.fromRGB(240, 120, 200),
		Tagline = "a neon neighbour city of arcades, shrines and side jobs",
		Lore = "Bright lights, part-time work everywhere and a surprising number of people with odd powers hiding in plain sight.",
		Safety = "Medium", Starter = true, StarterWeight = 15, TravelFee = 80,
		MapPosition = Vector2.new(0.3, 0.12), Neighbors = { "karakura_river", "inner_rukon", "crimson" },
		Buffs = { GoldMult = 1.15, StatXp = { Agility = 1.1 } },
		Features = { "Arcades", "Part-time jobs" },
	},
	{
		Id = "inner_rukon", Name = "Inner Rukongai Districts", Icon = "🏘", Color = Color3.fromRGB(200, 170, 120),
		Tagline = "the orderly first districts outside the Seireitei walls",
		Lore = "Tea houses, rice paddies and retired officers telling tall tales. The safest place a soul can land.",
		Safety = "High", Starter = true, StarterWeight = 20, TravelFee = 60,
		MapPosition = Vector2.new(0.5, 0.12), Neighbors = { "naruki", "kido_hall", "marsh" },
		Buffs = { RelationshipMult = 1.15, StatXp = { Charisma = 1.1 } },
		Features = { "District festivals", "Retired officers" },
	},
	{
		Id = "kido_hall", Name = "Kido Corps Archive Hall", Icon = "📜", Color = Color3.fromRGB(150, 160, 255),
		Tagline = "a silent hall of sealed incantations and very strict librarians",
		Lore = "Every Kido ever chanted is written here somewhere. Some of the scrolls chant back.",
		Safety = "Medium", TravelFee = 400, Requires = { MinRealm = 3 },
		MapPosition = Vector2.new(0.7, 0.12), Neighbors = { "inner_rukon", "relief_gardens", "kunlun" },
		Buffs = { QiMult = 1.4, StudyMult = 1.2, StatXp = { Intelligence = 1.2 } },
		Features = { "Kido archives", "Restricted shelf" },
	},
	{
		Id = "relief_gardens", Name = "Relief Station Gardens", Icon = "🌿", Color = Color3.fromRGB(130, 220, 160),
		Tagline = "the healing gardens behind the Fourth Division relief station",
		Lore = "Moon-herbs bloom at midnight and the wounded recover twice as fast. Nobody fights here; nobody dares.",
		Safety = "High", TravelFee = 200, Requires = { MinRealm = 2 },
		MapPosition = Vector2.new(0.9, 0.12), Neighbors = { "kido_hall", "capital" },
		Buffs = { QiMult = 1.2, MaxHealthBonus = 30, StressPerYear = -1 },
		Features = { "Healing herbs", "Fourth Division wards" },
	},
	{
		Id = "frozen_garden", Name = "Garden of Frozen Petals", Icon = "❄", Color = Color3.fromRGB(180, 220, 255),
		Tagline = "a garden of ice flowers between worlds where time barely moves",
		Lore = "A captain's Bankai froze this place mid-battle centuries ago. The petals still have not fallen.",
		Safety = "Extreme", TravelFee = 7000, Requires = { MinRealm = 8 },
		MapPosition = Vector2.new(0.1, 0.87), Neighbors = { "reiokyu", "shadow_vault" },
		Buffs = { QiMult = 4.5 }, Hazard = { Health = -6 },
		Features = { "Frozen Bankai", "Time-slowed meditation" },
	},
	{
		Id = "shadow_vault", Name = "Central 46 Underground Vault", Icon = "🗝", Color = Color3.fromRGB(120, 110, 150),
		Tagline = "a sealed vault beneath the Great Hall of the Central 46",
		Lore = "Forbidden records, confiscated zanpakuto and prisoners nobody admits exist.",
		Safety = "Extreme", TravelFee = 5000, Requires = { MinRealm = 7 },
		MapPosition = Vector2.new(0.3, 0.87), Neighbors = { "las_noches", "frozen_garden", "menos_sands" },
		Buffs = { QiMult = 3.5, StatXp = { Intelligence = 1.2 } }, Hazard = { Health = -5 },
		Features = { "Forbidden records", "Sealed blades" },
	},
	{
		Id = "menos_sands", Name = "Hueco Mundo White Dunes", Icon = "🏜", Color = Color3.fromRGB(230, 225, 210),
		Tagline = "endless white dunes under a moon that never sets",
		Lore = "Menos rise from the sand without warning. The air is thick with hunger and reishi.",
		Safety = "Extreme", TravelFee = 3000, Requires = { MinRealm = 6 },
		MapPosition = Vector2.new(0.5, 0.87), Neighbors = { "hueco_mundo", "shadow_vault", "dangai" },
		Buffs = { QiMult = 2.8 }, DemonicBuffs = { QiMult = 1.3 }, Hazard = { Health = -5 },
		Features = { "Menos hunts", "Endless dunes" },
	},
	{
		Id = "dangai", Name = "Dangai Precipice World", Icon = "🌀", Color = Color3.fromRGB(170, 110, 200),
		Tagline = "the warped corridor between worlds where time runs wrong",
		Lore = "One day here is weeks outside. The Cleaner sweeps the corridor and erases anything too slow.",
		Safety = "Deadly", TravelFee = 1800, Requires = { MinRealm = 5 },
		MapPosition = Vector2.new(0.7, 0.87), Neighbors = { "fake_karakura", "menos_sands", "hollow_wastes" },
		Buffs = { QiMult = 2.2 }, Hazard = { Health = -6 }, GlimpseBonus = 0.05,
		Features = { "Time drift", "The Cleaner: -6 HP/yr" },
	},
	{
		Id = "hollow_wastes", Name = "Rukongai Hollow Wastes", Icon = "💀", Color = Color3.fromRGB(160, 130, 110),
		Tagline = "the burned outer districts where Hollows hunt in packs",
		Lore = "Nothing grows and nobody stays. Bounty hunters and reckless trainees come for the fights.",
		Safety = "Dangerous", TravelFee = 900, Requires = { MinRealm = 3 },
		MapPosition = Vector2.new(0.9, 0.87), Neighbors = { "ruins", "dangai" },
		Buffs = { QiMult = 1.5, BattleRewardMult = 1.2 }, Hazard = { Health = -3 },
		Features = { "Hollow packs", "Bounty hunting" },
	},
}

WorldRegionsConfig.Default = "qinghe"

-- Reincarnation prologue shown at the start of every life (ReplicatedFirst/IntroAndLoadingUI).
-- {region} and {tagline} are filled from the birth region; <b>/<i> are rich text.
WorldRegionsConfig.Prologue = table.concat({
	"<i>Beyond a quiet death, your soul drifted through a Senkaimon of paper doors toward the Wheel of Souls. ",
	"'This was neither your first breath, nor shall it be your last,' a voice rang out like a struck blade, ",
	"binding you once more to the three worlds of the living, the dead and the hollow.</i>\n\n",
	"<i>Yet as the reishi dissolved around you, the words faded into static. When your eyes opened once more, ",
	"you were nothing more than an infant crying in <b>{region}</b> — {tagline}.</i>\n\n",
	"<i>Hollows already hunger for souls like yours—and with a blade in your hands, ",
	"the three worlds will either be protected or torn apart.</i>",
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
