--[[
	Soul Origins (the engine's bloodlines). The first life is always the Default;
	afterwards the Wheel of Souls spins them for Hogyoku Shards (Shared/Gacha) when
	Lineages is enabled.
	- Rarity: spin tier key (see Spin.Rarities; Name is what players see).
	- BaseStats: starting attribute levels.
	- Buffs: permanent modifiers for the life (shared buff keys; QiMult = Reiatsu).
	- Badge: optional UI badge colour (Mythic origins get gold seals).
	Spin: cost per spin, rarity weights, pity rules and the cost of locking an
	origin so it carries over to every next life. Ids and weights are the template's.
]]

local RacesConfig = {}

RacesConfig.Default = "Human"

local JACKPOT = Color3.fromRGB(245, 158, 11)

RacesConfig.Spin = {
	Cost = 5,
	LockCost = 60,
	RarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythic" },
	Rarities = {
		Common = { Name = "Common", Weight = 65, Color = Color3.fromRGB(176, 170, 190) },
		Rare = { Name = "Uncommon", Weight = 24, Color = Color3.fromRGB(110, 220, 150) },
		Epic = { Name = "Rare", Weight = 8, Color = Color3.fromRGB(56, 189, 248) },
		Legendary = { Name = "Legendary", Weight = 2.5, Color = Color3.fromRGB(157, 78, 221) },
		Mythic = { Name = "Mythic", Weight = 0.5, Color = JACKPOT },
	},
	Pity = {
		{ Rarity = "Epic", Every = 15 },
		{ Rarity = "Legendary", Every = 60 },
	},
}

RacesConfig.List = {
	-- Common
	{
		Id = "Human", Name = "Karakura Aware Human", Rarity = "Common", Color = Color3.fromRGB(210, 220, 232),
		Description = "A living Karakura kid who started seeing ghosts one ordinary afternoon.",
		Passive = "Adaptable: +10% Intelligence and Charisma XP.",
		BaseStats = { Strength = 1, Agility = 1, Vitality = 1, Intelligence = 2, Charisma = 2, QiControl = 0 },
		Buffs = { StatXp = { Intelligence = 1.1, Charisma = 1.1 } },
	},
	{
		Id = "MortalBlood", Name = "Rukongai Wandering Soul", Rarity = "Common", Color = Color3.fromRGB(200, 180, 160),
		Description = "Reborn from a rough Rukongai district. Hungry, stubborn and hard to kill.",
		Passive = "Street Grit: +20 max HP, +10% Strength and Vitality XP.",
		BaseStats = { Strength = 2, Agility = 1, Vitality = 2, Intelligence = 1, Charisma = 1, QiControl = 0 },
		Buffs = { MaxHealthBonus = 20, StatXp = { Strength = 1.1, Vitality = 1.1 } },
	},
	-- Uncommon (spin key "Rare")
	{
		Id = "Mutant", Name = "Fullbring Object-Channeler", Rarity = "Rare", Color = Color3.fromRGB(150, 220, 120),
		Description = "Your mother was attacked by a Hollow before you were born. Objects bend to your soul.",
		Passive = "Fullbring: +30% Strength/Vitality XP, +30 HP, -20% Charisma XP.",
		BaseStats = { Strength = 4, Agility = 2, Vitality = 4, Intelligence = 0, Charisma = 0, QiControl = 1 },
		Buffs = { StatXp = { Strength = 1.3, Vitality = 1.3, Charisma = 0.8 }, MaxHealthBonus = 30 },
	},
	{
		Id = "Beastkin", Name = "Stealth Force (Onmitsukido) Blood", Rarity = "Rare", Color = Color3.fromRGB(120, 200, 230),
		Description = "Assassins of the Onmitsukido. Quick hands, cold eyes, short lives.",
		Passive = "Shadow Step: +40% Agility XP, -10 years lifespan.",
		BaseStats = { Strength = 2, Agility = 5, Vitality = 2, Intelligence = 0, Charisma = 1, QiControl = 0 },
		Buffs = { StatXp = { Agility = 1.4 }, LifespanBonus = -10 },
	},
	{
		Id = "ShikigamiTamer", Name = "Kido Corps Lineage", Rarity = "Rare", Color = Color3.fromRGB(110, 230, 190),
		Description = "Your family served the Kido Corps for generations. Incantations come naturally.",
		Passive = "Kido Heritage: +30% Kido & Cero Arts XP, +10% Intelligence XP.",
		BaseStats = { Strength = 1, Agility = 2, Vitality = 2, Intelligence = 3, Charisma = 1, QiControl = 2 },
		Buffs = { ProficiencyXp = { QiArts = 1.3 }, StatXp = { Intelligence = 1.1 } },
	},
	-- Rare (spin key "Epic")
	{
		Id = "SpiritTouched", Name = "Visored Hollow-Mask Hybrid", Rarity = "Epic", Color = Color3.fromRGB(249, 115, 22),
		Description = "A Hollow lives behind your eyes. The mask gives power; holding it costs you dearly.",
		Passive = "Hollowfication: x1.5 Reiatsu, +30% Reiatsu Control XP, -20 max HP.",
		BaseStats = { Strength = 0, Agility = 1, Vitality = 0, Intelligence = 3, Charisma = 1, QiControl = 4 },
		Buffs = { QiMult = 1.5, StatXp = { QiControl = 1.3 }, MaxHealthBonus = -20 },
	},
	{
		Id = "AncientClan", Name = "Four Noble Families Scion", Rarity = "Epic", Color = Color3.fromRGB(56, 189, 248),
		Description = "Heir of one of the great noble houses of Soul Society. Doors open, elders watch.",
		Passive = "Noble Blood: x1.5 Reiatsu, +Kan 2K at birth, unique event choices.",
		BaseStats = { Strength = 2, Agility = 2, Vitality = 2, Intelligence = 2, Charisma = 3, QiControl = 2 },
		Buffs = { QiMult = 1.5, StartingMoney = 2000 },
	},
	{
		Id = "ProjectionFrame", Name = "Mixed-Blood Gemischt Quincy", Rarity = "Epic", Color = Color3.fromRGB(150, 210, 255),
		Description = "Quincy blood thinned by a human parent. Your spirit bow is quick and precise.",
		Passive = "Hirenkyaku: x1.5 Reiatsu, +30% Agility XP.",
		BaseStats = { Strength = 1, Agility = 5, Vitality = 1, Intelligence = 2, Charisma = 1, QiControl = 3 },
		Buffs = { QiMult = 1.5, StatXp = { Agility = 1.3 } },
	},
	-- Legendary
	{
		Id = "AscendedBloodline", Name = "Echt Pureblood Quincy (Blut Vene)", Rarity = "Legendary", Color = Color3.fromRGB(165, 180, 252),
		Description = "Pure Quincy blood. Reishi hardens in your veins at the first sign of danger.",
		Passive = "Blut Vene: x2.5 Reiatsu, +60 years, +5% Soul Awakening.",
		BaseStats = { Strength = 3, Agility = 3, Vitality = 3, Intelligence = 3, Charisma = 2, QiControl = 5 },
		Buffs = { QiMult = 2.5, LifespanBonus = 60, BreakthroughBonus = 0.05 },
	},
	{
		Id = "DragonVein", Name = "Kenpachi Berserker Bloodline", Rarity = "Legendary", Color = Color3.fromRGB(240, 110, 100),
		Description = "You were born laughing at danger. Your spiritual pressure crushes the weak.",
		Passive = "Endless Battle: x2.5 Reiatsu, +60 years, +60 max HP.",
		BaseStats = { Strength = 5, Agility = 3, Vitality = 5, Intelligence = 2, Charisma = 2, QiControl = 4 },
		Buffs = { QiMult = 2.5, LifespanBonus = 60, MaxHealthBonus = 60 },
	},
	{
		Id = "IdleGamble", Name = "Vasto Lorde Arrancar Hybrid", Rarity = "Legendary", Color = Color3.fromRGB(226, 232, 240),
		Description = "A Vasto Lorde's power woven into a human soul. Lesser Hollows bow to you.",
		Passive = "Resurreccion: x2.5 Reiatsu, +60 years, +30% Charisma XP.",
		BaseStats = { Strength = 3, Agility = 3, Vitality = 4, Intelligence = 2, Charisma = 4, QiControl = 4 },
		Buffs = { QiMult = 2.5, LifespanBonus = 60, StatXp = { Charisma = 1.3 } },
	},
	-- Mythic
	{
		Id = "VoidWalker", Name = "Soul King Fragment Vessel", Rarity = "Mythic", Color = Color3.fromRGB(56, 189, 248), Badge = JACKPOT,
		Description = "A fragment of the Soul King's power sleeps in your soul. Every faction wants it.",
		Passive = "Royal Fragment: x5 Reiatsu, +150 years, +10% Soul Awakening.",
		BaseStats = { Strength = 3, Agility = 7, Vitality = 4, Intelligence = 6, Charisma = 3, QiControl = 7 },
		Buffs = { QiMult = 5, LifespanBonus = 150, BreakthroughBonus = 0.1 },
	},
	{
		Id = "HeavenlyDemon", Name = "Tri-World True Hybrid", Rarity = "Mythic", Color = Color3.fromRGB(249, 115, 22), Badge = JACKPOT,
		Description = "Human, Soul Reaper, Hollow and Quincy in one soul. Your power has no ceiling.",
		Passive = "True Hybrid: x5 Reiatsu, +150 years, +50% Strength XP.",
		BaseStats = { Strength = 7, Agility = 5, Vitality = 6, Intelligence = 4, Charisma = 2, QiControl = 6 },
		Buffs = { QiMult = 5, LifespanBonus = 150, StatXp = { Strength = 1.5 } },
	},
	{
		Id = "ChaosSovereign", Name = "Founding Reaper Ancestor", Rarity = "Mythic", Color = Color3.fromRGB(245, 158, 11), Badge = JACKPOT,
		Description = "The blood of the first Soul Reapers who founded the Gotei 13 runs in you.",
		Passive = "Founder's Flame: x5 Reiatsu, +150 years, +20% all attribute XP.",
		BaseStats = { Strength = 5, Agility = 5, Vitality = 5, Intelligence = 5, Charisma = 5, QiControl = 6 },
		Buffs = { QiMult = 5, LifespanBonus = 150, AllStatXp = 1.2 },
	},
	-- Content expansion (2026-11-02): 14 more bloodlines.
	{
		Id = "KarakuraMedium", Name = "Karakura Spirit Medium", Rarity = "Common", Color = Color3.fromRGB(200, 190, 220),
		Description = "A family of shrine mediums who have always heard the dead.",
		Passive = "Medium: +15% Charisma XP, +10% affection gains.",
		BaseStats = { Strength = 1, Agility = 1, Vitality = 1, Intelligence = 2, Charisma = 3, QiControl = 1 },
		Buffs = { StatXp = { Charisma = 1.15 }, RelationshipMult = 1.1 },
	},
	{
		Id = "DistrictFarmer", Name = "Inner District Farmer Soul", Rarity = "Common", Color = Color3.fromRGB(190, 170, 130),
		Description = "Rice paddies and quiet years in the first districts.",
		Passive = "Steady: +15% Vitality XP, +5 years lifespan.",
		BaseStats = { Strength = 2, Agility = 1, Vitality = 3, Intelligence = 1, Charisma = 1, QiControl = 0 },
		Buffs = { StatXp = { Vitality = 1.15 }, LifespanBonus = 5 },
	},
	{
		Id = "StreetBrawlerSoul", Name = "Karakura Street Brawler", Rarity = "Common", Color = Color3.fromRGB(230, 150, 110),
		Description = "You have been in more fights than you can count. You won most.",
		Passive = "Scrapper: +15% Strength XP, +15 max HP.",
		BaseStats = { Strength = 3, Agility = 2, Vitality = 2, Intelligence = 0, Charisma = 1, QiControl = 0 },
		Buffs = { StatXp = { Strength = 1.15 }, MaxHealthBonus = 15 },
	},
	{
		Id = "ShrineKeeperLine", Name = "Konso Shrine Keeper Line", Rarity = "Rare", Color = Color3.fromRGB(210, 220, 255),
		Description = "Generations of bell-ringers who guide lost souls home.",
		Passive = "Bellwarden: +30% Hogyoku Shards earned, +20% Intelligence XP.",
		BaseStats = { Strength = 1, Agility = 1, Vitality = 1, Intelligence = 4, Charisma = 2, QiControl = 2 },
		Buffs = { KarmaMult = 1.3, StatXp = { Intelligence = 1.2 } },
	},
	{
		Id = "ArtisanSoul", Name = "Soul Smith Apprentice Blood", Rarity = "Rare", Color = Color3.fromRGB(200, 160, 120),
		Description = "Your ancestors hammered asauchi blanks in the royal forges.",
		Passive = "Forgehand: +40% Zanjutsu XP, +10% gold.",
		BaseStats = { Strength = 3, Agility = 2, Vitality = 2, Intelligence = 2, Charisma = 1, QiControl = 1 },
		Buffs = { ProficiencyXp = { Sword = 1.4 }, GoldMult = 1.1 },
	},
	{
		Id = "CatShifter", Name = "Shapeshifter Cat Lineage", Rarity = "Rare", Color = Color3.fromRGB(120, 100, 160),
		Description = "Your grandmother could become a black cat. You can almost manage it.",
		Passive = "Nine Lives: +40% Agility XP, much easier escapes.",
		BaseStats = { Strength = 1, Agility = 5, Vitality = 1, Intelligence = 2, Charisma = 2, QiControl = 1 },
		Buffs = { StatXp = { Agility = 1.4 }, FleeBonus = 0.15 },
	},
	{
		Id = "ModSoulHost", Name = "Mod Soul Host", Rarity = "Rare", Color = Color3.fromRGB(160, 230, 140),
		Description = "An artificial soul sleeps in your body and wakes when you need it.",
		Passive = "Second Soul: +30 max HP, +20% Strength and Agility XP.",
		BaseStats = { Strength = 3, Agility = 3, Vitality = 2, Intelligence = 1, Charisma = 1, QiControl = 1 },
		Buffs = { MaxHealthBonus = 30, StatXp = { Strength = 1.2, Agility = 1.2 } },
	},
	{
		Id = "HealerClan", Name = "Fourth Division Healer Clan", Rarity = "Epic", Color = Color3.fromRGB(140, 230, 170),
		Description = "Your family has run the relief stations for three hundred years.",
		Passive = "Healing Hands: x1.4 Reiatsu, +60 max HP, -1 stress per year.",
		BaseStats = { Strength = 1, Agility = 2, Vitality = 3, Intelligence = 4, Charisma = 2, QiControl = 3 },
		Buffs = { QiMult = 1.4, MaxHealthBonus = 60, StressPerYear = -1 },
	},
	{
		Id = "ResearchClan", Name = "Twelfth Division Research Lineage", Rarity = "Epic", Color = Color3.fromRGB(180, 120, 230),
		Description = "Your family were the test subjects. And then the scientists.",
		Passive = "Modified: x1.5 Reiatsu, +30% Intelligence XP.",
		BaseStats = { Strength = 1, Agility = 2, Vitality = 1, Intelligence = 5, Charisma = 1, QiControl = 3 },
		Buffs = { QiMult = 1.5, StatXp = { Intelligence = 1.3 } },
	},
	{
		Id = "BountoBlood", Name = "Reishi-Eater Lineage", Rarity = "Epic", Color = Color3.fromRGB(150, 90, 110),
		Description = "Your blood remembers feeding on the spirits of others.",
		Passive = "Hunger: x1.7 Reiatsu, -10 years lifespan.",
		BaseStats = { Strength = 2, Agility = 3, Vitality = 2, Intelligence = 2, Charisma = 1, QiControl = 4 },
		Buffs = { QiMult = 1.7, LifespanBonus = -10 },
	},
	{
		Id = "RoyalGuardDescendant", Name = "Royal Guard Descendant", Rarity = "Legendary", Color = Color3.fromRGB(250, 210, 120),
		Description = "An ancestor served at the palace of the Soul King.",
		Passive = "Palace Blood: x2.5 Reiatsu, +60 years, +5% awakening.",
		BaseStats = { Strength = 3, Agility = 3, Vitality = 4, Intelligence = 4, Charisma = 3, QiControl = 5 },
		Buffs = { QiMult = 2.5, LifespanBonus = 60, BreakthroughBonus = 0.05 },
	},
	{
		Id = "AdjuchasHybrid", Name = "Adjuchas Hybrid", Rarity = "Legendary", Color = Color3.fromRGB(200, 200, 200),
		Description = "Half your soul evolved by devouring other Hollows.",
		Passive = "Evolved: x2.5 Reiatsu, +80 max HP, +30% Strength XP.",
		BaseStats = { Strength = 5, Agility = 4, Vitality = 5, Intelligence = 2, Charisma = 1, QiControl = 4 },
		Buffs = { QiMult = 2.5, MaxHealthBonus = 80, StatXp = { Strength = 1.3 } },
	},
	{
		Id = "OriginalCaptainHeir", Name = "Heir of a Founding Captain", Rarity = "Mythic", Color = Color3.fromRGB(255, 230, 150), Badge = Color3.fromRGB(255, 210, 90),
		Description = "One of the first thirteen captains is your direct ancestor.",
		Passive = "First Gotei: x5 Reiatsu, +150 years, +20% all attribute XP.",
		BaseStats = { Strength = 5, Agility = 5, Vitality = 5, Intelligence = 5, Charisma = 6, QiControl = 6 },
		Buffs = { QiMult = 5, LifespanBonus = 150, AllStatXp = 1.2 },
	},
	{
		Id = "DangaiBorn", Name = "Born in the Dangai", Rarity = "Mythic", Color = Color3.fromRGB(170, 110, 220), Badge = Color3.fromRGB(150, 90, 220),
		Description = "You were born in the precipice world where time runs wrong.",
		Passive = "Out of Time: x5 Reiatsu, +200 years, +5% awakening.",
		BaseStats = { Strength = 3, Agility = 6, Vitality = 4, Intelligence = 6, Charisma = 3, QiControl = 7 },
		Buffs = { QiMult = 5, LifespanBonus = 200, BreakthroughBonus = 0.05 },
	},
}

RacesConfig.ById = {}
for _, race in RacesConfig.List do
	RacesConfig.ById[race.Id] = race
end

function RacesConfig.Get(id: string)
	return RacesConfig.ById[id] or RacesConfig.ById[RacesConfig.Default]
end

-- What players see for a rarity key ("Epic" -> "Rare").
function RacesConfig.RarityName(key: string?): string
	local info = key and RacesConfig.Spin.Rarities[key]
	return if info then info.Name else tostring(key or "")
end

return RacesConfig
