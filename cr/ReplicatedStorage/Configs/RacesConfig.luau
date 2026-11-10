--[[
	Sorcerer Clans (the engine's bloodlines). The first life is always the Default;
	afterwards the Wheel of Curses spins them for Binding Vows (Shared/Gacha) when
	Lineages is enabled.
	- Rarity: spin tier key (see Spin.Rarities; Name is what players see).
	- BaseStats: starting attribute levels.
	- Buffs: permanent modifiers for the life (shared buff keys; QiMult = cursed energy).
	- Badge: optional UI badge colour (Mythic clans get jackpot-gold seals).
	Spin: cost per spin, rarity weights, pity rules and the cost of locking a
	clan so it carries over to every next life. Ids and weights are the template's.
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
		Id = "Human", Name = "Civilian Awakened", Rarity = "Common", Color = Color3.fromRGB(210, 205, 222),
		Description = "An ordinary family until your eyes opened to the curses around you.",
		Passive = "Adaptable: +10% Intelligence and Charisma XP.",
		BaseStats = { Strength = 1, Agility = 1, Vitality = 1, Intelligence = 2, Charisma = 2, QiControl = 0 },
		Buffs = { StatXp = { Intelligence = 1.1, Charisma = 1.1 } },
	},
	{
		Id = "MortalBlood", Name = "Minor Shrine Lineage", Rarity = "Common", Color = Color3.fromRGB(200, 170, 160),
		Description = "Keepers of a small shrine. Hardy, disciplined, unremarkable.",
		Passive = "Shrine Discipline: +20 max HP, +10% Strength and Vitality XP.",
		BaseStats = { Strength = 2, Agility = 1, Vitality = 2, Intelligence = 1, Charisma = 1, QiControl = 0 },
		Buffs = { MaxHealthBonus = 20, StatXp = { Strength = 1.1, Vitality = 1.1 } },
	},
	-- Uncommon (spin key "Rare")
	{
		Id = "Mutant", Name = "Cursed Corpse Crafter", Rarity = "Rare", Color = Color3.fromRGB(150, 220, 120),
		Description = "Your family stitches cursed corpses into loyal puppets. People keep their distance.",
		Passive = "Corpse Craft: +30% Strength/Vitality XP, +30 HP, -20% Charisma XP.",
		BaseStats = { Strength = 4, Agility = 2, Vitality = 4, Intelligence = 0, Charisma = 0, QiControl = 1 },
		Buffs = { StatXp = { Strength = 1.3, Vitality = 1.3, Charisma = 0.8 }, MaxHealthBonus = 30 },
	},
	{
		Id = "Beastkin", Name = "Kyoto Barrier Lineage", Rarity = "Rare", Color = Color3.fromRGB(120, 200, 230),
		Description = "Barrier wardens of the old capital. Quick hands, short tempers, short lives.",
		Passive = "Barrier Reflexes: +40% Agility XP, -10 years lifespan.",
		BaseStats = { Strength = 2, Agility = 5, Vitality = 2, Intelligence = 0, Charisma = 1, QiControl = 0 },
		Buffs = { StatXp = { Agility = 1.4 }, LifespanBonus = -10 },
	},
	{
		Id = "ShikigamiTamer", Name = "Shikigami Tamer Blood", Rarity = "Rare", Color = Color3.fromRGB(110, 230, 190),
		Description = "Paper spirits and summoned beasts answer your family's call.",
		Passive = "Summoner's Bond: +30% Barrier & Domain Arts XP, +10% Intelligence XP.",
		BaseStats = { Strength = 1, Agility = 2, Vitality = 2, Intelligence = 3, Charisma = 1, QiControl = 2 },
		Buffs = { ProficiencyXp = { QiArts = 1.3 }, StatXp = { Intelligence = 1.1 } },
	},
	-- Rare (spin key "Epic")
	{
		Id = "SpiritTouched", Name = "Crimson Blood Manipulator", Rarity = "Epic", Color = Color3.fromRGB(225, 29, 72),
		Description = "Your blood is your weapon: pierce, harden, flow. It costs you dearly.",
		Passive = "Blood Manipulation: x1.5 cursed energy, +30% CE Manipulation XP, -20 max HP.",
		BaseStats = { Strength = 0, Agility = 1, Vitality = 0, Intelligence = 3, Charisma = 1, QiControl = 4 },
		Buffs = { QiMult = 1.5, StatXp = { QiControl = 1.3 }, MaxHealthBonus = -20 },
	},
	{
		Id = "AncientClan", Name = "Cursed Speech Clan", Rarity = "Epic", Color = Color3.fromRGB(56, 189, 248),
		Description = "Your words carry curses. Elders of the old families open doors for you.",
		Passive = "Cursed Speech: x1.5 cursed energy, +¥2K at birth, unique event choices.",
		BaseStats = { Strength = 2, Agility = 2, Vitality = 2, Intelligence = 2, Charisma = 3, QiControl = 2 },
		Buffs = { QiMult = 1.5, StartingMoney = 2000 },
	},
	{
		Id = "ProjectionFrame", Name = "Projection Frame Clan", Rarity = "Epic", Color = Color3.fromRGB(150, 210, 255),
		Description = "You move in twenty-four frames a second; everything else waits for you.",
		Passive = "Projection Sorcery: x1.5 cursed energy, +30% Agility XP.",
		BaseStats = { Strength = 1, Agility = 5, Vitality = 1, Intelligence = 2, Charisma = 1, QiControl = 3 },
		Buffs = { QiMult = 1.5, StatXp = { Agility = 1.3 } },
	},
	-- Legendary
	{
		Id = "AscendedBloodline", Name = "Ten Shadows Heir", Rarity = "Legendary", Color = Color3.fromRGB(157, 78, 221),
		Description = "Ten shikigami sleep in your shadow. The great families covet you.",
		Passive = "Ten Shadows: x2.5 cursed energy, +60 years, +5% Grade Promotion.",
		BaseStats = { Strength = 3, Agility = 3, Vitality = 3, Intelligence = 3, Charisma = 2, QiControl = 5 },
		Buffs = { QiMult = 2.5, LifespanBonus = 60, BreakthroughBonus = 0.05 },
	},
	{
		Id = "DragonVein", Name = "Zero-Energy Heavenly Pact", Rarity = "Legendary", Color = Color3.fromRGB(200, 200, 210),
		Description = "Heaven took your cursed energy and gave you a physical god's body in return.",
		Passive = "Heavenly Restriction: x2.5 cursed energy, +60 years, +60 max HP.",
		BaseStats = { Strength = 5, Agility = 3, Vitality = 5, Intelligence = 2, Charisma = 2, QiControl = 4 },
		Buffs = { QiMult = 2.5, LifespanBonus = 60, MaxHealthBonus = 60 },
	},
	{
		Id = "IdleGamble", Name = "Idle Gamble Fever Lineage", Rarity = "Legendary", Color = Color3.fromRGB(245, 158, 11),
		Description = "Jackpot domain blood. When the reels line up, nothing can kill you.",
		Passive = "Jackpot Fever: x2.5 cursed energy, +60 years, +30% Charisma XP.",
		BaseStats = { Strength = 3, Agility = 3, Vitality = 4, Intelligence = 2, Charisma = 4, QiControl = 4 },
		Buffs = { QiMult = 2.5, LifespanBonus = 60, StatXp = { Charisma = 1.3 } },
	},
	-- Mythic
	{
		Id = "VoidWalker", Name = "Limitless Six-Gaze Clan", Rarity = "Mythic", Color = Color3.fromRGB(56, 189, 248), Badge = JACKPOT,
		Description = "Born with the Six Eyes and the Limitless. Throughout heaven and earth, you alone.",
		Passive = "Six Eyes: x5 cursed energy, +150 years, +10% Grade Promotion.",
		BaseStats = { Strength = 3, Agility = 7, Vitality = 4, Intelligence = 6, Charisma = 3, QiControl = 7 },
		Buffs = { QiMult = 5, LifespanBonus = 150, BreakthroughBonus = 0.1 },
	},
	{
		Id = "HeavenlyDemon", Name = "King of Curses Vessel", Rarity = "Mythic", Color = Color3.fromRGB(225, 29, 72), Badge = JACKPOT,
		Description = "A calamity sleeps inside you. Every sorcerer wants you sealed or dead.",
		Passive = "Vessel: x5 cursed energy, +150 years, +50% Strength XP.",
		BaseStats = { Strength = 7, Agility = 5, Vitality = 6, Intelligence = 4, Charisma = 2, QiControl = 6 },
		Buffs = { QiMult = 5, LifespanBonus = 150, StatXp = { Strength = 1.5 } },
	},
	{
		Id = "ChaosSovereign", Name = "Heian Reincarnate Lineage", Rarity = "Mythic", Color = Color3.fromRGB(245, 158, 11), Badge = JACKPOT,
		Description = "A sorcerer of the golden age of jujutsu has returned in your blood.",
		Passive = "Golden Age: x5 cursed energy, +150 years, +20% all attribute XP.",
		BaseStats = { Strength = 5, Agility = 5, Vitality = 5, Intelligence = 5, Charisma = 5, QiControl = 6 },
		Buffs = { QiMult = 5, LifespanBonus = 150, AllStatXp = 1.2 },
	},
	-- Content expansion (2026-11-02): 14 more clans, two or three per rarity.
	{
		Id = "StreetExorcist", Name = "Back-Alley Exorcist Family", Rarity = "Common", Color = Color3.fromRGB(190, 180, 170),
		Description = "Three generations of unlicensed exorcists working out of a noodle shop.",
		Passive = "Street Smarts: +10% Strength and Agility XP, +¥300 at birth.",
		BaseStats = { Strength = 2, Agility = 2, Vitality = 1, Intelligence = 1, Charisma = 1, QiControl = 0 },
		Buffs = { StatXp = { Strength = 1.1, Agility = 1.1 }, StartingMoney = 300 },
	},
	{
		Id = "TempleKeeper", Name = "Village Temple Lineage", Rarity = "Common", Color = Color3.fromRGB(220, 200, 150),
		Description = "Bell ringers of a mountain village temple. They live long and worry little.",
		Passive = "Temple Calm: +10% Vitality XP, +8 years of life.",
		BaseStats = { Strength = 1, Agility = 1, Vitality = 2, Intelligence = 2, Charisma = 1, QiControl = 0 },
		Buffs = { StatXp = { Vitality = 1.1 }, LifespanBonus = 8 },
	},
	{
		Id = "TalismanScribe", Name = "Talisman Scribe Line", Rarity = "Rare", Color = Color3.fromRGB(230, 210, 120),
		Description = "Your family brushes the seals every sorcerer depends on. Ink stains are a family crest.",
		Passive = "Brush Discipline: +30% Intelligence XP, +15% Barrier & Domain Arts XP, -20% Strength XP.",
		BaseStats = { Strength = 0, Agility = 1, Vitality = 1, Intelligence = 4, Charisma = 2, QiControl = 1 },
		Buffs = { StatXp = { Intelligence = 1.3, Strength = 0.8 }, ProficiencyXp = { QiArts = 1.15 } },
	},
	{
		Id = "ConstructionArt", Name = "Construction Technique Family", Rarity = "Rare", Color = Color3.fromRGB(160, 200, 240),
		Description = "Your family turns cursed energy into solid matter. Expensive, exhausting, brilliant.",
		Passive = "Built from Nothing: +25% Cursed Tools XP, +15% Intelligence XP, -20 max HP.",
		BaseStats = { Strength = 1, Agility = 1, Vitality = 1, Intelligence = 3, Charisma = 1, QiControl = 2 },
		Buffs = { ProficiencyXp = { Sword = 1.25 }, StatXp = { Intelligence = 1.15 }, MaxHealthBonus = -20 },
	},
	{
		Id = "ToolSmith", Name = "Cursed Tool Smiths", Rarity = "Rare", Color = Color3.fromRGB(200, 120, 80),
		Description = "Forgers of cursed blades for the great clans. Sorcerers wait years for one of your swords.",
		Passive = "Forge Blood: +25% Cursed Tools and Taijutsu XP, +10% salary.",
		BaseStats = { Strength = 3, Agility = 1, Vitality = 3, Intelligence = 1, Charisma = 1, QiControl = 1 },
		Buffs = { ProficiencyXp = { Sword = 1.25, Spear = 1.25 }, SalaryMult = 1.1 },
	},
	{
		Id = "StrawDoll", Name = "Straw Doll Resonance Line", Rarity = "Epic", Color = Color3.fromRGB(210, 170, 110),
		Description = "Nails, hammer and a straw doll. Your family hurts curses from across the room.",
		Passive = "Resonance: +50% cursed energy, +30% Barrier & Domain Arts XP.",
		BaseStats = { Strength = 1, Agility = 2, Vitality = 1, Intelligence = 2, Charisma = 2, QiControl = 4 },
		Buffs = { QiMult = 1.5, ProficiencyXp = { QiArts = 1.3 } },
	},
	{
		Id = "ClapSwap", Name = "Clap-Swap Lineage", Rarity = "Epic", Color = Color3.fromRGB(255, 130, 90),
		Description = "One clap and you trade places with anything carrying cursed energy. Your family loves a good brawl.",
		Passive = "Swap: +50% cursed energy, +30% Agility XP, +10% Charisma XP.",
		BaseStats = { Strength = 3, Agility = 4, Vitality = 2, Intelligence = 1, Charisma = 2, QiControl = 3 },
		Buffs = { QiMult = 1.5, StatXp = { Agility = 1.3, Charisma = 1.1 } },
	},
	{
		Id = "FrostBloom", Name = "Frost Bloom Clan", Rarity = "Epic", Color = Color3.fromRGB(170, 225, 255),
		Description = "Your ancestors froze rivers with a breath. The family home is always cold.",
		Passive = "Frost Bloom: +50% cursed energy, +20% CE Manipulation and +10% Vitality XP.",
		BaseStats = { Strength = 1, Agility = 2, Vitality = 3, Intelligence = 2, Charisma = 1, QiControl = 4 },
		Buffs = { QiMult = 1.5, StatXp = { QiControl = 1.2, Vitality = 1.1 } },
	},
	{
		Id = "RatioLine", Name = "Ratio Technique Lineage", Rarity = "Legendary", Color = Color3.fromRGB(215, 190, 140),
		Description = "Every target has a weak point at exactly seven-tenths of its length. Your family finds it every time.",
		Passive = "Overtime: +150% cursed energy, +60 years, +30% Intelligence and +20% Cursed Tools XP.",
		BaseStats = { Strength = 3, Agility = 3, Vitality = 3, Intelligence = 4, Charisma = 2, QiControl = 3 },
		Buffs = { QiMult = 2.5, LifespanBonus = 60, StatXp = { Intelligence = 1.3 }, ProficiencyXp = { Sword = 1.2 } },
	},
	{
		Id = "SoulShaper", Name = "Soul Reshaper Bloodline", Rarity = "Legendary", Color = Color3.fromRGB(120, 110, 170),
		Description = "Your family can touch the shape of a soul. Healers love you; everyone else is terrified.",
		Passive = "Reshape: +150% cursed energy, +60 years, +40 max HP, +30% Vitality XP.",
		BaseStats = { Strength = 3, Agility = 3, Vitality = 5, Intelligence = 3, Charisma = 1, QiControl = 4 },
		Buffs = { QiMult = 2.5, LifespanBonus = 60, MaxHealthBonus = 40, StatXp = { Vitality = 1.3 } },
	},
	{
		Id = "CometSword", Name = "Comet Sword Clan", Rarity = "Legendary", Color = Color3.fromRGB(250, 220, 130),
		Description = "A clan of ancient duelists whose sword strikes leave trails of light like falling stars.",
		Passive = "Comet Edge: +150% cursed energy, +60 years, +40% Cursed Tools and +20% Taijutsu XP.",
		BaseStats = { Strength = 5, Agility = 4, Vitality = 3, Intelligence = 2, Charisma = 2, QiControl = 3 },
		Buffs = { QiMult = 2.5, LifespanBonus = 60, ProficiencyXp = { Sword = 1.4, Spear = 1.2 } },
	},
	{
		Id = "ThunderGod", Name = "Thunder God Lineage", Rarity = "Mythic", Color = Color3.fromRGB(130, 200, 255), Badge = JACKPOT,
		Description = "Your cursed energy behaves like lightning. You have waited four hundred years for a worthy opponent.",
		Passive = "Mythic Thunder: +400% cursed energy, +150 years, +50% Agility XP.",
		BaseStats = { Strength = 5, Agility = 7, Vitality = 4, Intelligence = 3, Charisma = 3, QiControl = 6 },
		Buffs = { QiMult = 5, LifespanBonus = 150, StatXp = { Agility = 1.5 } },
	},
	{
		Id = "StarPlasma", Name = "Star Plasma Barrier Line", Rarity = "Mythic", Color = Color3.fromRGB(240, 240, 200), Badge = JACKPOT,
		Description = "Your blood holds the barriers that protect the whole country. Everyone wants you, alive or not.",
		Passive = "Mythic Barrier: +400% cursed energy, +150 years, +80 max HP, +40% Barrier & Domain Arts XP.",
		BaseStats = { Strength = 3, Agility = 3, Vitality = 6, Intelligence = 6, Charisma = 3, QiControl = 6 },
		Buffs = { QiMult = 5, LifespanBonus = 150, MaxHealthBonus = 80, ProficiencyXp = { QiArts = 1.4 } },
	},
	{
		Id = "VowWeaver", Name = "Binding Vow Weavers", Rarity = "Mythic", Color = Color3.fromRGB(200, 160, 255), Badge = JACKPOT,
		Description = "No one in your family has ever broken a vow. Reality bends to keep their promises.",
		Passive = "Mythic Vows: +400% cursed energy, +150 years, +30% Binding Vows earned.",
		BaseStats = { Strength = 4, Agility = 4, Vitality = 4, Intelligence = 5, Charisma = 5, QiControl = 6 },
		Buffs = { QiMult = 5, LifespanBonus = 150, KarmaMult = 1.3 },
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
