--[[
	The world map (World engine module; Modules/RegionSystem, Shared/EngineModules/World/Page).
	Every life is born in a Starter region (StarterWeight); travel moves between
	Neighbors for 1 action diamond + the destination's TravelFee and rolls a road
	encounter (TravelEventsConfig).

	Region fields:
		Name, Tagline (prologue), Lore, Safety (label), Icon, Color
		MapPosition    Vector2 in map scale (0-1) for the drawn cartography
		Neighbors      region ids connected by a road
		Starter / StarterWeight   birth region odds
		Requires       Shared/Requirements spec to travel there
		AltRequires / AltFee   alternative way in (e.g. pay a toll instead of the realm)
		Buffs          shared buff keys while living there (QiMult = the region's Qi density)
		DemonicBuffs   extra buffs while Alignment <= DemonicAlignment
		Hazard         { Health = -3, ImmuneMaxAlignment = -20 } yearly harm unless demonic enough
		GlimpseBonus   added to Past-Life Glimpse chance (Samsara)
		Features       labels for the map panel (Black Market, Imperial Exams, ...)
]]

local WorldRegionsConfig = {}

WorldRegionsConfig.TravelMinAge = 12
WorldRegionsConfig.TravelSlots = 1
WorldRegionsConfig.DemonicAlignment = -20

WorldRegionsConfig.Regions = {
	{
		Id = "qinghe", Name = "Qinghe Bamboo Valley", Icon = "🎋", Color = Color3.fromRGB(110, 200, 140),
		Tagline = "a peaceful valley of spirit-rice terraces and whispering bamboo",
		Lore = "Farmers sing to the spirit-rice and scholars read beneath the bamboo. Few dangers, fewer legends.",
		Safety = "High", Starter = true, StarterWeight = 45, TravelFee = 50,
		MapPosition = Vector2.new(0.22, 0.47), Neighbors = { "crimson", "capital", "kunlun", "lotus_lake", "frost_tundra" },
		Buffs = { StudyMult = 1.1, StatXp = { Intelligence = 1.1 } },
		Features = { "Village school", "Spirit-rice terraces" },
	},
	{
		Id = "crimson", Name = "Crimson Reach Slums", Icon = "🦴", Color = Color3.fromRGB(220, 80, 70),
		Tagline = "a syndicate fortress built inside the ribs of a slain Leviathan",
		Lore = "The bone-city never sleeps. Syndicates rule its alleys and anything can be bought below the ribs.",
		Safety = "Low", Starter = true, StarterWeight = 40, TravelFee = 30,
		MapPosition = Vector2.new(0.13, 0.84), Neighbors = { "qinghe", "capital", "marsh" },
		Buffs = { QiMult = 0.85, StatXp = { Strength = 1.25 }, ProficiencyXp = { Sword = 1.25, Spear = 1.25 } },
		Features = { "Black Market", "Pit fights" },
	},
	{
		Id = "capital", Name = "Imperial Jade Capital", Icon = "🏯", Color = Color3.fromRGB(230, 200, 110),
		Tagline = "the jade-walled heart of the mortal dynasty",
		Lore = "Ministers, merchants and eunuchs scheme beneath golden roofs. The Imperial Exams make and break families.",
		Safety = "Medium", Starter = true, StarterWeight = 15, TravelFee = 120,
		MapPosition = Vector2.new(0.5, 0.72), Neighbors = { "qinghe", "crimson", "kunlun", "marsh", "beast_forest", "pearl_coast" },
		Buffs = { QiMult = 1.1, SalaryMult = 1.3, StatXp = { Charisma = 1.3 } },
		Features = { "Imperial Exams", "Court politics" },
	},
	{
		Id = "kunlun", Name = "Mount Kunlun Cloud Peaks", Icon = "🏔", Color = Color3.fromRGB(140, 200, 255),
		Tagline = "floating sword-sect peaks above a sea of clouds",
		Lore = "Orthodox sects train on islands of stone that drift between the clouds. Mortals rarely climb this high.",
		-- Foundation Establishment, or age 16 and the sect toll (AltRequires / AltFee).
		Safety = "Medium", TravelFee = 300, Requires = { MinRealm = 3 }, AltRequires = { MinAge = 16 }, AltFee = 1500,
		MapPosition = Vector2.new(0.42, 0.16), Neighbors = { "qinghe", "capital", "ruins", "lotus_lake", "beast_forest", "thunder_plateau" },
		Buffs = { QiMult = 1.5, ProficiencyXp = { Sword = 1.25, QiArts = 1.25 } },
		Features = { "Orthodox sword sects", "Cloud-sea meditation" },
	},
	{
		Id = "marsh", Name = "Wailing Blood Marsh", Icon = "🩸", Color = Color3.fromRGB(170, 50, 90),
		Tagline = "a cursed swamp where the resentment of the dead never drains away",
		Lore = "Every pool remembers a massacre. Demonic cultivators thrive on the resentment; the righteous wither.",
		Safety = "Deadly", TravelFee = 200, Requires = { MinAge = 14 },
		MapPosition = Vector2.new(0.84, 0.84), Neighbors = { "crimson", "capital", "ruins", "pearl_coast", "bone_desert" },
		Buffs = { QiMult = 1.6 }, DemonicBuffs = { QiMult = 1.4 },
		Hazard = { Health = -3, ImmuneMaxAlignment = -20 },
		Features = { "Demonic Qi (+40% if Alignment <= -20)", "Resentment: -3 HP/yr unless demonic" },
	},
	{
		Id = "ruins", Name = "Shattered Star Ruins", Icon = "☄", Color = Color3.fromRGB(190, 150, 255),
		Tagline = "the crater where a fallen god struck the earth",
		Lore = "Shards of divinity still hum in the crater. Relics, madness and memories of other lives wait in the dust.",
		Safety = "Extreme", TravelFee = 1500, Requires = { MinRealm = 4 },
		MapPosition = Vector2.new(0.82, 0.3), Neighbors = { "kunlun", "marsh", "beast_forest", "bone_desert", "thunder_plateau" },
		Buffs = { QiMult = 2.5 }, Hazard = { Health = -6 }, GlimpseBonus = 0.1,
		Features = { "Ancient relics", "Past-life glimpses +10%", "Divine radiation: -6 HP/yr" },
	},
	-- Content expansion (2026-11-02): 6 more regions.
	{
		Id = "lotus_lake", Name = "Misty Lotus Lake", Icon = "🪷", Color = Color3.fromRGB(240, 170, 200),
		Tagline = "a lake of floating pavilions hidden in eternal morning mist",
		Lore = "Poets, courtesans and retired sect masters drift between pavilions on lotus barges. Secrets travel by boat.",
		Safety = "High", Starter = true, StarterWeight = 20, TravelFee = 80,
		MapPosition = Vector2.new(0.28, 0.13), Neighbors = { "qinghe", "kunlun", "frost_tundra" },
		Buffs = { RelationshipMult = 1.15, StatXp = { Charisma = 1.15 } },
		Features = { "Floating pavilions", "Poetry contests" },
	},
	{
		Id = "frost_tundra", Name = "Frostfang Tundra", Icon = "🐺", Color = Color3.fromRGB(190, 220, 240),
		Tagline = "an endless white plain where wolves outnumber people",
		Lore = "Nomad clans follow the great herds across the ice. The cold kills the weak and forges the rest.",
		Safety = "Low", TravelFee = 150, Requires = { MinAge = 14 },
		MapPosition = Vector2.new(0.09, 0.16), Neighbors = { "lotus_lake", "qinghe" },
		Buffs = { QiMult = 1.15, StatXp = { Vitality = 1.3, Strength = 1.1 } }, Hazard = { Health = -2 },
		Features = { "Nomad clans", "Bitter cold: -2 HP/yr" },
	},
	{
		Id = "beast_forest", Name = "Ten Thousand Beast Forest", Icon = "🌲", Color = Color3.fromRGB(90, 160, 90),
		Tagline = "a primeval forest ruled by spirit beasts older than the empire",
		Lore = "Hunters enter in groups and leave alone, if at all. Beast cores fetch fortunes in the capital.",
		Safety = "Low", TravelFee = 250, Requires = { MinAge = 15 },
		MapPosition = Vector2.new(0.64, 0.48), Neighbors = { "capital", "kunlun", "ruins", "thunder_plateau", "bone_desert" },
		Buffs = { QiMult = 1.3, BattleRewardMult = 1.15, StatXp = { Agility = 1.15 } },
		Features = { "Spirit beast hunts", "Beast core trade" },
	},
	{
		Id = "pearl_coast", Name = "Southern Pearl Coast", Icon = "🐚", Color = Color3.fromRGB(110, 210, 220),
		Tagline = "a sunlit coast of pearl divers, pirates and spice ships",
		Lore = "Fortunes are made at sea and lost at the dice tables of the harbour. The Sea Dragon King watches from below.",
		Safety = "Medium", Starter = true, StarterWeight = 15, TravelFee = 100,
		MapPosition = Vector2.new(0.62, 0.92), Neighbors = { "capital", "marsh" },
		Buffs = { GoldMult = 1.15, SalaryMult = 1.1 },
		Features = { "Pearl diving", "Harbour markets" },
	},
	{
		Id = "bone_desert", Name = "Desert of Bleached Bones", Icon = "🏜", Color = Color3.fromRGB(230, 200, 140),
		Tagline = "a desert of giant skeletons from a war between gods",
		Lore = "Caravans cross by night between the ribs of dead titans. Sandstorms uncover a new tomb every year.",
		Safety = "Deadly", TravelFee = 600, Requires = { MinRealm = 3 },
		MapPosition = Vector2.new(0.93, 0.58), Neighbors = { "ruins", "marsh", "beast_forest" },
		Buffs = { QiMult = 1.5 }, Hazard = { Health = -4 }, GlimpseBonus = 0.05,
		Features = { "Titan tombs", "Sandstorms: -4 HP/yr" },
	},
	{
		Id = "thunder_plateau", Name = "Heavenly Thunder Plateau", Icon = "⛈", Color = Color3.fromRGB(170, 170, 255),
		Tagline = "a plateau where lightning never stops falling",
		Lore = "Cultivators come here to temper themselves against heaven's wrath. Most leave as ash; a few leave as legends.",
		Safety = "Extreme", TravelFee = 2000, Requires = { MinRealm = 5 },
		MapPosition = Vector2.new(0.65, 0.1), Neighbors = { "kunlun", "ruins", "beast_forest" },
		Buffs = { QiMult = 2, BreakthroughBonus = 0.03 }, Hazard = { Health = -8 },
		Features = { "Tribulation lightning: +3% breakthrough", "Lightning strikes: -8 HP/yr" },
	},
}

WorldRegionsConfig.Default = "qinghe"

-- Reincarnation prologue shown at the start of every life (ReplicatedFirst/IntroAndLoadingUI).
-- {region} and {tagline} are filled from the birth region; <b>/<i> are rich text.
WorldRegionsConfig.Prologue = table.concat({
	"<i>Beyond the veil of a quiet death, your drifting soul stood before an ancient deity of the Endless Wheel. ",
	"'This was neither your first mortal breath, nor shall it be your last,' the voice echoed across eternity, ",
	"granting you passage into a realm of steel, spirit, and fate.</i>\n\n",
	"<i>Yet as the waters of oblivion washed over you, the divine words faded into mist. When your eyes opened once more, ",
	"you were nothing more than a helpless infant crying beneath the skies of <b>{region}</b> — {tagline}.</i>\n\n",
	"<i>This world already marches to the beat of its own ancient history—and through your hands, ",
	"its destiny shall either ascend into legend or drown in blood.</i>",
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
