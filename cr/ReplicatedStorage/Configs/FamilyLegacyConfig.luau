--[[
	Innate Origins (the engine's family legacies, Dynasty module): the house you are born
	into. Rolled with the free starter spins of Life 1 (Modules/CreationSystem) or on the
	Wheel of Curses for a full rebirth (WheelSystem SpinLegacy); inherited unchanged by a
	descendant you are reborn as.
	Fields: Money (yen added at birth), Buffs (per-life buff source "Legacy"),
	FamilyAffection { min, max } for the parents, Item (a cursed tool given at birth).
	Ids and numbers are the template's.
]]

local FamilyLegacyConfig = {}

FamilyLegacyConfig.Default = "humble_farmers"

FamilyLegacyConfig.Spin = {
	Cost = 20,
	RarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythic" },
	Rarities = {
		Common = { Name = "Common", Weight = 55, Color = Color3.fromRGB(176, 170, 190) },
		Rare = { Name = "Uncommon", Weight = 28, Color = Color3.fromRGB(110, 220, 150) },
		Epic = { Name = "Rare", Weight = 12, Color = Color3.fromRGB(56, 189, 248) },
		Legendary = { Name = "Legendary", Weight = 4, Color = Color3.fromRGB(157, 78, 221) },
		Mythic = { Name = "Mythic", Weight = 1, Color = Color3.fromRGB(245, 158, 11) },
	},
	Pity = { { Rarity = "Epic", Every = 10 } },
}

FamilyLegacyConfig.List = {
	{ Id = "humble_farmers", Name = "Window-Sight Townsfolk", Rarity = "Common", Money = 100,
		Description = "An ordinary family that can barely see curses. +10% Vitality XP.", Buffs = { StatXp = { Vitality = 1.1 } } },
	{ Id = "battlefield_orphan", Name = "Restless Gambler Fight-Club Heir", Rarity = "Common", Money = 0, FamilyAffection = { 15, 35 },
		Description = "Raised between underground bouts and bad bets. +15% Strength, +10% Agility XP.", Buffs = { StatXp = { Strength = 1.15, Agility = 1.1 } } },
	{ Id = "sword_clan", Name = "Cursed Toolsmith Lineage", Rarity = "Rare", Money = 200, Item = "wooden_sword",
		Description = "Forgers of minor cursed tools. +20% Cursed Tools XP and a training bokken.", Buffs = { ProficiencyXp = { Sword = 1.2 } } },
	{ Id = "merchant_dynasty", Name = "Black Market Curse Broker Family", Rarity = "Rare", Money = 3000,
		Description = "Dealers in cursed objects and secrets. +¥3K at birth, +15% salary.", Buffs = { SalaryMult = 1.15 } },
	{ Id = "disgraced_noble", Name = "Disgraced Big Three Branch", Rarity = "Epic", Money = 1500,
		Description = "A branch family cast out by one of the Big Three. +20% Charisma, +10% Intelligence XP, -1 happiness a year.",
		Buffs = { StatXp = { Charisma = 1.2, Intelligence = 1.1 }, HappinessPerYear = -1 } },
	{ Id = "fallen_immortal", Name = "Fallen Heian Aristocracy", Rarity = "Legendary", Money = 500,
		Description = "Your ancestors ruled sorcery in the Heian era. +30% cursed energy, +3% Grade Promotion.", Buffs = { QiMult = 1.3, BreakthroughBonus = 0.03 } },
	{ Id = "heavenly_heirs", Name = "Star Plasma Guardian House", Rarity = "Mythic", Money = 2000, FamilyAffection = { 80, 95 },
		Description = "Sworn guardians of the Star Plasma Vessel. +50% cursed energy, +30% passive cursed energy.", Buffs = { QiMult = 1.5, PassiveQiMult = 1.3 } },
	-- Content expansion (2026-11-02): 7 more innate origins.
	{ Id = "shrine_caretakers", Name = "Shrine Caretaker Family", Rarity = "Common", Money = 150,
		Description = "You grew up sweeping a small shrine and ringing its bell. +10% CE Manipulation XP, -1 stress a year.", Buffs = { StatXp = { QiControl = 1.1 }, StressPerYear = -1 } },
	{ Id = "ramen_family", Name = "Ramen Shop Family", Rarity = "Common", Money = 400, FamilyAffection = { 60, 85 },
		Description = "Warm kitchen, loud regulars, long hours. +10% Charisma and Vitality XP.", Buffs = { StatXp = { Charisma = 1.1, Vitality = 1.1 } } },
	{ Id = "auxiliary_parents", Name = "Auxiliary Staff Household", Rarity = "Rare", Money = 800, Item = "training_blindfold",
		Description = "Both parents raise curtains for a living. +15% Barrier & Domain Arts XP, +10% study and a training blindfold.", Buffs = { ProficiencyXp = { QiArts = 1.15 }, StudyMult = 1.1 } },
	{ Id = "dojo_lineage", Name = "Old Taijutsu Dojo", Rarity = "Rare", Money = 300, Item = "cursed_bat",
		Description = "A dojo that trained sorcerers for a century. +20% Taijutsu XP and a cursed baseball bat.", Buffs = { ProficiencyXp = { Spear = 1.2 } } },
	{ Id = "exiled_clan_heirs", Name = "Exiled Clan Heirs", Rarity = "Epic", Money = 2500, FamilyAffection = { 30, 60 },
		Description = "Thrown out of a great clan with their secrets intact. +15% cursed energy, +15% Intelligence XP.", Buffs = { QiMult = 1.15, StatXp = { Intelligence = 1.15 } } },
	{ Id = "special_grade_descendants", Name = "Special Grade Descendants", Rarity = "Legendary", Money = 3000, Item = "talisman_tanto",
		Description = "A Special Grade sorcerer is your great-grandparent. +25% cursed energy, +20 max health and a talisman tanto.", Buffs = { QiMult = 1.25, MaxHealthBonus = 20 } },
	{ Id = "thousand_year_house", Name = "Thousand-Year Barrier House", Rarity = "Mythic", Money = 5000, FamilyAffection = { 75, 95 },
		Description = "Keepers of a barrier older than the country. +40% cursed energy, +20% Barrier & Domain Arts XP, +20 years.", Buffs = { QiMult = 1.4, ProficiencyXp = { QiArts = 1.2 }, LifespanBonus = 20 } },
}

FamilyLegacyConfig.ById = {}
for _, legacy in FamilyLegacyConfig.List do
	FamilyLegacyConfig.ById[legacy.Id] = legacy
end

function FamilyLegacyConfig.Get(id: string?)
	return FamilyLegacyConfig.ById[id or ""] or FamilyLegacyConfig.ById[FamilyLegacyConfig.Default]
end

return FamilyLegacyConfig
