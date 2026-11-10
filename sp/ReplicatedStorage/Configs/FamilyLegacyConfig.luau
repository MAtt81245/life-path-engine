--[[
	Spiritual Heritages (the engine's family legacies, Dynasty module): the house you are
	born into. Rolled with the free starter spins of Life 1 (Modules/CreationSystem) or on
	the Wheel of Souls for a full rebirth (WheelSystem SpinLegacy); inherited unchanged by
	a descendant you are reborn as.
	Fields: Money (Kan added at birth), Buffs (per-life buff source "Legacy"),
	FamilyAffection { min, max } for the parents, Item (a blade given at birth).
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
	{ Id = "humble_farmers", Name = "Karakura Clinic Family (Exiled Reaper Parent)", Rarity = "Common", Money = 100,
		Description = "A small-town clinic run by a parent who used to be a Soul Reaper. +10% Vitality XP.", Buffs = { StatXp = { Vitality = 1.1 } } },
	{ Id = "battlefield_orphan", Name = "Rukongai Street Orphans", Rarity = "Common", Money = 0, FamilyAffection = { 15, 35 },
		Description = "Raised by other orphans in the rough districts. +15% Strength, +10% Agility XP.", Buffs = { StatXp = { Strength = 1.15, Agility = 1.1 } } },
	{ Id = "sword_clan", Name = "Royal Smithing Clan", Rarity = "Rare", Money = 200, Item = "wooden_sword",
		Description = "Apprentice smiths of the royal forge. +20% Zanjutsu XP and a sealed asauchi.", Buffs = { ProficiencyXp = { Sword = 1.2 } } },
	{ Id = "merchant_dynasty", Name = "Exiled Research Shop Lineage", Rarity = "Rare", Money = 3000,
		Description = "A family of exiled scientists running a candy shop full of secrets. +Kan 3K at birth, +15% salary.", Buffs = { SalaryMult = 1.15 } },
	{ Id = "disgraced_noble", Name = "Execution Hill Guardian Blood", Rarity = "Epic", Money = 1500,
		Description = "Hereditary guardians of Sokyoku Hill, burdened with old executions. +20% Charisma, +10% Intelligence XP, -1 happiness a year.",
		Buffs = { StatXp = { Charisma = 1.2, Intelligence = 1.1 }, HappinessPerYear = -1 } },
	{ Id = "fallen_immortal", Name = "First Division Veteran House", Rarity = "Legendary", Money = 500,
		Description = "Your ancestors served the Head-Captain for a thousand years. +30% Reiatsu, +3% Soul Awakening.", Buffs = { QiMult = 1.3, BreakthroughBonus = 0.03 } },
	{ Id = "heavenly_heirs", Name = "Royal Guard House of the Reiokyu", Rarity = "Mythic", Money = 2000, FamilyAffection = { 80, 95 },
		Description = "A house sworn to the Soul King's palace. +50% Reiatsu, +30% passive Reiatsu.", Buffs = { QiMult = 1.5, PassiveQiMult = 1.3 } },
	-- Content expansion (2026-11-02): 7 more family legacies.
	{ Id = "river_ferrymen", Name = "Karakura Ferry Family", Rarity = "Common", Money = 150,
		Description = "Generations of river boatmen who see the dead. +10% Agility and Strength XP.", Buffs = { StatXp = { Agility = 1.1, Strength = 1.1 } } },
	{ Id = "village_healers", Name = "Clinic Nurses' Line", Rarity = "Common", Money = 120, Item = "healing_salve",
		Description = "Herb baskets and gentle hands. +20 max health and a healing salve.", Buffs = { MaxHealthBonus = 20 } },
	{ Id = "scholar_officials", Name = "Shin'o Instructor Family", Rarity = "Rare", Money = 800,
		Description = "Three generations taught at the Academy. +20% Intelligence XP, +10% study.", Buffs = { StatXp = { Intelligence = 1.2 }, StudyMult = 1.1 } },
	{ Id = "temple_keepers", Name = "Konso Shrine Keepers", Rarity = "Rare", Money = 300,
		Description = "Guardians of a mountain shrine. +25% Hogyoku Shards earned, -1 stress a year.", Buffs = { KarmaMult = 1.25, StressPerYear = -1 } },
	{ Id = "beast_tamers", Name = "Hollow Tamer Clan", Rarity = "Epic", Money = 700,
		Description = "Tamed Hollows guard the family estate. +15% Hollow-hunt rewards, +40 max health.", Buffs = { BattleRewardMult = 1.15, MaxHealthBonus = 40 } },
	{ Id = "alchemist_house", Name = "House of the Reishi Furnace", Rarity = "Legendary", Money = 4000, Item = "spirit_pill",
		Description = "Twelfth Division researchers for nine generations. +25% Reiatsu, +20% Intelligence XP.", Buffs = { QiMult = 1.25, StatXp = { Intelligence = 1.2 } } },
	{ Id = "dragon_guardians", Name = "Guardians of the Senkaimon", Rarity = "Mythic", Money = 2500, FamilyAffection = { 70, 90 },
		Description = "Sworn to guard the gates between worlds. +40% Reiatsu, +20 years, +60 max health.", Buffs = { QiMult = 1.4, LifespanBonus = 20, MaxHealthBonus = 60 } },
}

FamilyLegacyConfig.ById = {}
for _, legacy in FamilyLegacyConfig.List do
	FamilyLegacyConfig.ById[legacy.Id] = legacy
end

function FamilyLegacyConfig.Get(id: string?)
	return FamilyLegacyConfig.ById[id or ""] or FamilyLegacyConfig.ById[FamilyLegacyConfig.Default]
end

return FamilyLegacyConfig
