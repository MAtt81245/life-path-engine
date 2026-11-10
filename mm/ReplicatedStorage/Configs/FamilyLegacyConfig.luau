--[[
	Family legacies / origins (Dynasty module): the house you are born into. Rolled with
	the free starter spins of Life 1 (Modules/CreationSystem) or on the Wheel for a full
	rebirth (WheelSystem SpinLegacy); inherited unchanged by a descendant you are reborn as.
	Fields: Money (added at birth), Buffs (per-life buff source "Legacy"),
	FamilyAffection { min, max } for the parents, Item (an heirloom hint given at birth).
]]

local FamilyLegacyConfig = {}

FamilyLegacyConfig.Default = "humble_farmers"

FamilyLegacyConfig.Spin = {
	Cost = 20,
	RarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythic" },
	Rarities = {
		Common = { Name = "Common", Weight = 55, Color = Color3.fromRGB(190, 186, 176) },
		Rare = { Name = "Rare", Weight = 28, Color = Color3.fromRGB(96, 170, 255) },
		Epic = { Name = "Epic", Weight = 12, Color = Color3.fromRGB(186, 120, 255) },
		Legendary = { Name = "Legendary", Weight = 4, Color = Color3.fromRGB(240, 196, 92) },
		Mythic = { Name = "Mythic", Weight = 1, Color = Color3.fromRGB(235, 70, 80) },
	},
	Pity = { { Rarity = "Epic", Every = 10 } },
}

FamilyLegacyConfig.List = {
	{ Id = "humble_farmers", Name = "Humble Spirit-Farmers", Rarity = "Common", Money = 100,
		Description = "Honest folk of the terraces. +10% Vitality XP.", Buffs = { StatXp = { Vitality = 1.1 } } },
	{ Id = "battlefield_orphan", Name = "Orphan of the Battlefield", Rarity = "Common", Money = 0, FamilyAffection = { 15, 35 },
		Description = "Raised by strangers in a war camp. +15% Strength, +10% Agility XP.", Buffs = { StatXp = { Strength = 1.15, Agility = 1.1 } } },
	{ Id = "sword_clan", Name = "Wandering Swordsman Clan", Rarity = "Rare", Money = 200, Item = "wooden_sword",
		Description = "A clan of drifting blades. +20% Sword XP and a family wooden sword.", Buffs = { ProficiencyXp = { Sword = 1.2 } } },
	{ Id = "merchant_dynasty", Name = "Merchant Dynasty", Rarity = "Rare", Money = 3000,
		Description = "Ledgers and caravans. +$3K at birth, +15% salary.", Buffs = { SalaryMult = 1.15 } },
	{ Id = "disgraced_noble", Name = "Disgraced Noble House", Rarity = "Epic", Money = 1500,
		Description = "Fallen from court favor. +20% Charisma, +10% Intelligence XP, -1 happiness a year.",
		Buffs = { StatXp = { Charisma = 1.2, Intelligence = 1.1 }, HappinessPerYear = -1 } },
	{ Id = "fallen_immortal", Name = "Fallen Immortal's Blood", Rarity = "Legendary", Money = 500,
		Description = "An ancestor fell from the heavens. +30% Qi, +3% breakthrough.", Buffs = { QiMult = 1.3, BreakthroughBonus = 0.03 } },
	{ Id = "heavenly_heirs", Name = "Heirs of a Heavenly Sect", Rarity = "Mythic", Money = 2000, FamilyAffection = { 80, 95 },
		Description = "The last bloodline of a vanished sect. +50% Qi, +30% passive Qi.", Buffs = { QiMult = 1.5, PassiveQiMult = 1.3 } },
	-- Content expansion (2026-11-02): 7 more family legacies.
	{ Id = "river_ferrymen", Name = "River Ferrymen", Rarity = "Common", Money = 150,
		Description = "Generations of boatmen. +10% Agility and Strength XP.", Buffs = { StatXp = { Agility = 1.1, Strength = 1.1 } } },
	{ Id = "village_healers", Name = "Village Healers", Rarity = "Common", Money = 120, Item = "healing_salve",
		Description = "Herb baskets and gentle hands. +20 max health and a healing salve.", Buffs = { MaxHealthBonus = 20 } },
	{ Id = "scholar_officials", Name = "Scholar-Official Family", Rarity = "Rare", Money = 800,
		Description = "Three passed the imperial exam. +20% Intelligence XP, +10% study.", Buffs = { StatXp = { Intelligence = 1.2 }, StudyMult = 1.1 } },
	{ Id = "temple_keepers", Name = "Temple Keepers", Rarity = "Rare", Money = 300,
		Description = "Guardians of a mountain shrine. +25% Karma earned, -1 stress a year.", Buffs = { KarmaMult = 1.25, StressPerYear = -1 } },
	{ Id = "beast_tamers", Name = "Beast Tamer Clan", Rarity = "Epic", Money = 700,
		Description = "Spirit beasts are family. +15% battle rewards, +40 max health.", Buffs = { BattleRewardMult = 1.15, MaxHealthBonus = 40 } },
	{ Id = "alchemist_house", Name = "House of the Golden Furnace", Rarity = "Legendary", Money = 4000, Item = "spirit_pill",
		Description = "Master alchemists for nine generations. +25% Qi, +20% Intelligence XP.", Buffs = { QiMult = 1.25, StatXp = { Intelligence = 1.2 } } },
	{ Id = "dragon_guardians", Name = "Guardians of the Dragon Gate", Rarity = "Mythic", Money = 2500, FamilyAffection = { 70, 90 },
		Description = "Sworn to a sleeping dragon. +40% Qi, +20 years, +60 max health.", Buffs = { QiMult = 1.4, LifespanBonus = 20, MaxHealthBonus = 60 } },
}

FamilyLegacyConfig.ById = {}
for _, legacy in FamilyLegacyConfig.List do
	FamilyLegacyConfig.ById[legacy.Id] = legacy
end

function FamilyLegacyConfig.Get(id: string?)
	return FamilyLegacyConfig.ById[id or ""] or FamilyLegacyConfig.ById[FamilyLegacyConfig.Default]
end

return FamilyLegacyConfig
