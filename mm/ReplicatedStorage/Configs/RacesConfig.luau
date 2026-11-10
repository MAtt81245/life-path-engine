--[[
	Bloodlines. The first life is always the Default; afterwards the Wheel of
	Reincarnation spins them for Karma (Shared/Gacha) when Lineages is enabled.
	- Rarity: spin tier (see Spin.Rarities).
	- BaseStats: starting attribute levels.
	- Buffs: permanent modifiers for the life (shared buff keys).
	- Badge: optional UI badge color (Mythic bloodlines get gold / crimson seals).
	Spin: cost per spin, rarity weights, pity rules and the cost of locking a
	bloodline so it carries over to every next life.
]]

local RacesConfig = {}

RacesConfig.Default = "Human"

RacesConfig.Spin = {
	Cost = 5,
	LockCost = 60,
	RarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythic" },
	Rarities = {
		Common = { Name = "Common", Weight = 65, Color = Color3.fromRGB(190, 186, 176) },
		Rare = { Name = "Rare", Weight = 24, Color = Color3.fromRGB(96, 170, 255) },
		Epic = { Name = "Epic", Weight = 8, Color = Color3.fromRGB(186, 120, 255) },
		Legendary = { Name = "Legendary", Weight = 2.5, Color = Color3.fromRGB(240, 196, 92) },
		Mythic = { Name = "Mythic", Weight = 0.5, Color = Color3.fromRGB(235, 70, 80) },
	},
	Pity = {
		{ Rarity = "Epic", Every = 15 },
		{ Rarity = "Legendary", Every = 60 },
	},
}

RacesConfig.List = {
	-- Common
	{
		Id = "Human", Name = "Human", Rarity = "Common", Color = Color3.fromRGB(220, 210, 190),
		Description = "Adaptable and ambitious. Thrives in schools and cities.",
		Passive = "Adaptable: +10% Intelligence and Charisma XP.",
		BaseStats = { Strength = 1, Agility = 1, Vitality = 1, Intelligence = 2, Charisma = 2, QiControl = 0 },
		Buffs = { StatXp = { Intelligence = 1.1, Charisma = 1.1 } },
	},
	{
		Id = "MortalBlood", Name = "Mortal Blood", Rarity = "Common", Color = Color3.fromRGB(200, 170, 150),
		Description = "Farmers and soldiers. Hardy, if unremarkable.",
		Passive = "Hardy: +20 max HP, +10% Strength and Vitality XP.",
		BaseStats = { Strength = 2, Agility = 1, Vitality = 2, Intelligence = 1, Charisma = 1, QiControl = 0 },
		Buffs = { MaxHealthBonus = 20, StatXp = { Strength = 1.1, Vitality = 1.1 } },
	},
	-- Rare
	{
		Id = "Mutant", Name = "Mutant", Rarity = "Rare", Color = Color3.fromRGB(150, 230, 110),
		Description = "Unstable genes grant raw power at a social cost.",
		Passive = "Unstable Genes: +30% Strength/Vitality XP, +30 HP, -20% Charisma XP.",
		BaseStats = { Strength = 4, Agility = 2, Vitality = 4, Intelligence = 0, Charisma = 0, QiControl = 1 },
		Buffs = { StatXp = { Strength = 1.3, Vitality = 1.3, Charisma = 0.8 }, MaxHealthBonus = 30 },
	},
	{
		Id = "Beastkin", Name = "Beastkin", Rarity = "Rare", Color = Color3.fromRGB(230, 160, 90),
		Description = "Fast, keen and wild. Burns bright, burns short.",
		Passive = "Feral Instinct: +40% Agility XP, -10 years lifespan.",
		BaseStats = { Strength = 2, Agility = 5, Vitality = 2, Intelligence = 0, Charisma = 1, QiControl = 0 },
		Buffs = { StatXp = { Agility = 1.4 }, LifespanBonus = -10 },
	},
	-- Epic
	{
		Id = "SpiritTouched", Name = "Spirit-Touched", Rarity = "Epic", Color = Color3.fromRGB(140, 200, 255),
		Description = "Born with a thin veil between body and Qi.",
		Passive = "Ethereal: x1.5 Qi, +30% Qi Control XP, -20 max HP.",
		BaseStats = { Strength = 0, Agility = 1, Vitality = 0, Intelligence = 3, Charisma = 1, QiControl = 4 },
		Buffs = { QiMult = 1.5, StatXp = { QiControl = 1.3 }, MaxHealthBonus = -20 },
	},
	{
		Id = "AncientClan", Name = "Ancient Clan", Rarity = "Epic", Color = Color3.fromRGB(120, 210, 170),
		Description = "Heir of a clan older than the empire. Elders open doors for you.",
		Passive = "Clan Legacy: x1.5 Qi, +$2K at birth, unique event choices.",
		BaseStats = { Strength = 2, Agility = 2, Vitality = 2, Intelligence = 2, Charisma = 3, QiControl = 2 },
		Buffs = { QiMult = 1.5, StartingMoney = 2000 },
	},
	-- Legendary
	{
		Id = "AscendedBloodline", Name = "Ascended Bloodline", Rarity = "Legendary", Color = Color3.fromRGB(255, 200, 90),
		Description = "Descendant of fallen immortals. Others envy you.",
		Passive = "Heavenly Heritage: x2.5 Qi, +60 years, +5% breakthrough.",
		BaseStats = { Strength = 3, Agility = 3, Vitality = 3, Intelligence = 3, Charisma = 2, QiControl = 5 },
		Buffs = { QiMult = 2.5, LifespanBonus = 60, BreakthroughBonus = 0.05 },
	},
	{
		Id = "DragonVein", Name = "Dragon-Vein", Rarity = "Legendary", Color = Color3.fromRGB(240, 150, 70),
		Description = "A sleeping dragon's blood stirs in your veins.",
		Passive = "Dragon Blood: x2.5 Qi, +60 years, +60 max HP.",
		BaseStats = { Strength = 5, Agility = 3, Vitality = 5, Intelligence = 2, Charisma = 2, QiControl = 4 },
		Buffs = { QiMult = 2.5, LifespanBonus = 60, MaxHealthBonus = 60 },
	},
	-- Mythic
	{
		Id = "ChaosSovereign", Name = "Chaos Sovereign", Rarity = "Mythic", Color = Color3.fromRGB(255, 215, 110), Badge = Color3.fromRGB(255, 200, 60),
		Description = "Primordial chaos made flesh. Heaven itself takes notice.",
		Passive = "Primordial: x5 Qi, +150 years, +20% all attribute XP.",
		BaseStats = { Strength = 5, Agility = 5, Vitality = 5, Intelligence = 5, Charisma = 5, QiControl = 6 },
		Buffs = { QiMult = 5, LifespanBonus = 150, AllStatXp = 1.2 },
	},
	{
		Id = "VoidWalker", Name = "Void Walker", Rarity = "Mythic", Color = Color3.fromRGB(170, 140, 255), Badge = Color3.fromRGB(150, 110, 255),
		Description = "You step between worlds as others step between rooms.",
		Passive = "Void Body: x5 Qi, +150 years, +10% breakthrough.",
		BaseStats = { Strength = 3, Agility = 7, Vitality = 4, Intelligence = 6, Charisma = 3, QiControl = 7 },
		Buffs = { QiMult = 5, LifespanBonus = 150, BreakthroughBonus = 0.1 },
	},
	{
		Id = "HeavenlyDemon", Name = "Heavenly Demon", Rarity = "Mythic", Color = Color3.fromRGB(240, 70, 90), Badge = Color3.fromRGB(220, 40, 60),
		Description = "Feared by every righteous sect. The demon path bends to you.",
		Passive = "Demon Heart: x5 Qi, +150 years, +50% Strength XP.",
		BaseStats = { Strength = 7, Agility = 5, Vitality = 6, Intelligence = 4, Charisma = 2, QiControl = 6 },
		Buffs = { QiMult = 5, LifespanBonus = 150, StatXp = { Strength = 1.5 } },
	},
	-- Content expansion (2026-11-02): 11 more bloodlines.
	{
		Id = "MountainFolk", Name = "Mountain Folk", Rarity = "Common", Color = Color3.fromRGB(170, 160, 140),
		Description = "Raised on thin air and steep paths. Slow to tire.",
		Passive = "Thin Air: +15% Vitality XP, +5 years lifespan.",
		BaseStats = { Strength = 2, Agility = 1, Vitality = 3, Intelligence = 1, Charisma = 1, QiControl = 0 },
		Buffs = { StatXp = { Vitality = 1.15 }, LifespanBonus = 5 },
	},
	{
		Id = "RiverFolk", Name = "River Folk", Rarity = "Common", Color = Color3.fromRGB(140, 180, 200),
		Description = "Boat people and traders. Every bargain is a current to ride.",
		Passive = "Easy Current: +10% Agility XP, +5% gold.",
		BaseStats = { Strength = 1, Agility = 2, Vitality = 1, Intelligence = 1, Charisma = 2, QiControl = 0 },
		Buffs = { StatXp = { Agility = 1.1 }, GoldMult = 1.05 },
	},
	{
		Id = "FoxBlood", Name = "Fox Blood", Rarity = "Rare", Color = Color3.fromRGB(240, 140, 90),
		Description = "A fox spirit sits somewhere in your family tree. People find you hard to refuse.",
		Passive = "Fox Charm: +40% Charisma XP, +10% social success.",
		BaseStats = { Strength = 0, Agility = 3, Vitality = 1, Intelligence = 2, Charisma = 4, QiControl = 1 },
		Buffs = { StatXp = { Charisma = 1.4 }, SocialBonus = 0.1 },
	},
	{
		Id = "IronSkin", Name = "Iron Skin", Rarity = "Rare", Color = Color3.fromRGB(150, 150, 165),
		Description = "Your skin turns blades like old bronze. Your mind is slower to sharpen.",
		Passive = "Bronze Hide: +60 max HP, +20% Strength XP, -10% Intelligence XP.",
		BaseStats = { Strength = 4, Agility = 1, Vitality = 4, Intelligence = 0, Charisma = 1, QiControl = 0 },
		Buffs = { MaxHealthBonus = 60, StatXp = { Strength = 1.2, Intelligence = 0.9 } },
	},
	{
		Id = "ScholarLine", Name = "Scholar Lineage", Rarity = "Rare", Color = Color3.fromRGB(200, 190, 150),
		Description = "Seven generations of imperial examiners. Ink runs in your veins.",
		Passive = "Inkblood: +40% Intelligence XP, +15% study.",
		BaseStats = { Strength = 0, Agility = 1, Vitality = 1, Intelligence = 5, Charisma = 2, QiControl = 1 },
		Buffs = { StatXp = { Intelligence = 1.4 }, StudyMult = 1.15 },
	},
	{
		Id = "MoonTouched", Name = "Moon-Touched", Rarity = "Epic", Color = Color3.fromRGB(200, 210, 255),
		Description = "Born under a lunar eclipse. Your Qi waxes with the moon.",
		Passive = "Lunar Tide: x1.6 Qi, +5% breakthrough.",
		BaseStats = { Strength = 1, Agility = 2, Vitality = 1, Intelligence = 3, Charisma = 2, QiControl = 4 },
		Buffs = { QiMult = 1.6, BreakthroughBonus = 0.05 },
	},
	{
		Id = "SwordClan", Name = "Sword Clan", Rarity = "Epic", Color = Color3.fromRGB(180, 220, 230),
		Description = "Your family has held the same sword style for a thousand years.",
		Passive = "Clan Style: x1.4 Qi, +40% Sword XP, +10% sword damage.",
		BaseStats = { Strength = 3, Agility = 3, Vitality = 2, Intelligence = 1, Charisma = 1, QiControl = 2 },
		Buffs = { QiMult = 1.4, ProficiencyXp = { Sword = 1.4 }, SwordDamageMult = 1.1 },
	},
	{
		Id = "PhoenixBorn", Name = "Phoenix-Born", Rarity = "Legendary", Color = Color3.fromRGB(255, 120, 60),
		Description = "Your ancestor was reborn from flame. So, perhaps, will you be.",
		Passive = "Rebirth Flame: x2.5 Qi, +80 years, -2 stress per year.",
		BaseStats = { Strength = 3, Agility = 4, Vitality = 4, Intelligence = 3, Charisma = 3, QiControl = 4 },
		Buffs = { QiMult = 2.5, LifespanBonus = 80, StressPerYear = -2 },
	},
	{
		Id = "StarChild", Name = "Star Child", Rarity = "Legendary", Color = Color3.fromRGB(160, 190, 255),
		Description = "You fell from the night sky as a falling star, or so your parents say.",
		Passive = "Starlight: x2.5 Qi, +40 years, +20% Intelligence XP, +5% breakthrough.",
		BaseStats = { Strength = 2, Agility = 3, Vitality = 3, Intelligence = 5, Charisma = 2, QiControl = 5 },
		Buffs = { QiMult = 2.5, LifespanBonus = 40, StatXp = { Intelligence = 1.2 }, BreakthroughBonus = 0.05 },
	},
	{
		Id = "JadeEmperorHeir", Name = "Jade Emperor's Heir", Rarity = "Mythic", Color = Color3.fromRGB(120, 230, 170), Badge = Color3.fromRGB(80, 210, 140),
		Description = "A celestial bloodline exiled to the mortal world. Heaven owes you a throne.",
		Passive = "Celestial Mandate: x5 Qi, +150 years, +30% gold.",
		BaseStats = { Strength = 4, Agility = 4, Vitality = 5, Intelligence = 6, Charisma = 7, QiControl = 6 },
		Buffs = { QiMult = 5, LifespanBonus = 150, GoldMult = 1.3 },
	},
	{
		Id = "AbyssalSovereign", Name = "Abyssal Sovereign", Rarity = "Mythic", Color = Color3.fromRGB(90, 110, 200), Badge = Color3.fromRGB(60, 80, 200),
		Description = "The deep places of the world remember your blood and kneel.",
		Passive = "Abyss Heart: x5 Qi, +150 years, +100 max HP.",
		BaseStats = { Strength = 6, Agility = 4, Vitality = 7, Intelligence = 4, Charisma = 2, QiControl = 7 },
		Buffs = { QiMult = 5, LifespanBonus = 150, MaxHealthBonus = 100 },
	},
}

RacesConfig.ById = {}
for _, race in RacesConfig.List do
	RacesConfig.ById[race.Id] = race
end

function RacesConfig.Get(id: string)
	return RacesConfig.ById[id] or RacesConfig.ById[RacesConfig.Default]
end

return RacesConfig
