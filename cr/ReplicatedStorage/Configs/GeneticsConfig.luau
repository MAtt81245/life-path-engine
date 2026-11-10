--[[
	Genetics (Dynasty module; Modules/DynastySystem, Shared/GeneticsText).
	Friends, rivals and partners carry Genetics = { Race, Grade, Trait } (rolled when they
	enter your life). Children carry Genetics = { Race, Grade, Talents, Trait, Potential,
	Upbringing } computed from BOTH parents at birth:
		Race     60% the higher-rarity parent's bloodline, 40% the other's, then a mutation
		         chance (BaseMutation + the spouse grade's MutationBonus) raises it one tier
		Talents  1 of your innate talents (TalentsConfig) if you have any
		Trait    the spouse's hereditary trait with the spouse grade's TraitChance (50-80%)
		Grade    average of the spouse grade and your grade (from your realm), rounded up
		Potential +1 starting level per PotentialPerLevels of your peak stat levels
	Grades also gate romance: Charisma level and realm needed, and a chance penalty that
	also makes duels with high-grade rivals harder.
]]

local GeneticsConfig = {}

GeneticsConfig.Grades = {
	{ Id = "Mortal", Name = "Dormant Vessel", Weight = 58, Color = Color3.fromRGB(180, 176, 166),
		RomanceCharisma = 0, RomanceRealm = 1, ChancePenalty = 0, MutationBonus = 0, TraitChance = 0.5 },
	{ Id = "Uncommon", Name = "Standard Flow", Weight = 26, Color = Color3.fromRGB(120, 210, 150),
		RomanceCharisma = 8, RomanceRealm = 1, ChancePenalty = 0.03, MutationBonus = 0.03, TraitChance = 0.575 },
	{ Id = "Rare", Name = "Concussive Rough Energy", Weight = 11, Color = Color3.fromRGB(96, 170, 255),
		RomanceCharisma = 18, RomanceRealm = 2, ChancePenalty = 0.06, MutationBonus = 0.08, TraitChance = 0.65 },
	{ Id = "Genius", Name = "Reversed Flow Aptitude", Weight = 4, Color = Color3.fromRGB(186, 120, 255),
		RomanceCharisma = 28, RomanceRealm = 3, ChancePenalty = 0.1, MutationBonus = 0.18, TraitChance = 0.725 },
	{ Id = "Peerless", Name = "Six-Gaze Divine Resonance", Weight = 1, Color = Color3.fromRGB(240, 196, 92),
		RomanceCharisma = 40, RomanceRealm = 4, ChancePenalty = 0.15, MutationBonus = 0.25, TraitChance = 0.8 },
}
GeneticsConfig.BaseMutation = 0.10 -- up to 0.35 with a Peerless spouse
GeneticsConfig.HigherParentShare = 0.6
-- Your own grade comes from your realm (index = realm, capped at the last entry).
GeneticsConfig.PlayerGradeByRealm = { 1, 2, 3, 4, 4, 5 }
GeneticsConfig.PotentialPerLevels = 10
-- Cursed Energy Traits (the engine's genetics grades) extend natural life: old-age deaths
-- start at 60 + LongevityPerGrade x grade index (Dormant Vessel 85 ... Six-Gaze 185).
GeneticsConfig.LongevityPerGrade = 25

GeneticsConfig.Traits = {
	{ Id = "SwordHeart", Name = "Cursed Tool Prodigy", Description = "+25% Cursed Tools XP.", Buffs = { ProficiencyXp = { Sword = 1.25 } } },
	{ Id = "ScholarsMind", Name = "Analytical Eye", Description = "+25% Intelligence XP.", Buffs = { StatXp = { Intelligence = 1.25 } } },
	{ Id = "MerchantBlood", Name = "Black Market Blood", Description = "+20% salary.", Buffs = { SalaryMult = 1.2 } },
	{ Id = "QiAffinity", Name = "Dense Cursed Energy", Description = "+20% cursed energy.", Buffs = { QiMult = 1.2 } },
	{ Id = "IronBody", Name = "Tempered Vessel", Description = "+30 max health.", Buffs = { MaxHealthBonus = 30 } },
	{ Id = "SilverTongue", Name = "Commanding Presence", Description = "+25% Charisma XP.", Buffs = { StatXp = { Charisma = 1.25 } } },
	-- Content expansion (2026-11-02): 6 more hereditary traits.
	{ Id = "SwiftBlood", Name = "Quick-Draw Reflexes", Description = "+25% Agility XP.", Buffs = { StatXp = { Agility = 1.25 } } },
	{ Id = "BrawlerBlood", Name = "Born Brawler", Description = "+25% Taijutsu XP.", Buffs = { ProficiencyXp = { Spear = 1.25 } } },
	{ Id = "BarrierSense", Name = "Barrier Sense", Description = "+25% Barrier & Domain Arts XP.", Buffs = { ProficiencyXp = { QiArts = 1.25 } } },
	{ Id = "LongLived", Name = "Slow Ageing", Description = "+10 years of lifespan.", Buffs = { LifespanBonus = 10 } },
	{ Id = "WarmHeart", Name = "Warm Heart", Description = "+20% affection gains.", Buffs = { RelationshipMult = 1.2 } },
	{ Id = "StubbornWill", Name = "Stubborn Will", Description = "+20% Strength and Vitality XP.", Buffs = { StatXp = { Strength = 1.2, Vitality = 1.2 } } },
}

-- Upbringing guidance for a child (once): starting levels if you are reborn as them.
GeneticsConfig.Upbringings = {
	Martial = { Name = "Taijutsu", Stats = { Strength = 4, Vitality = 3 } },
	Scholarly = { Name = "Scholarly", Stats = { Intelligence = 5, Charisma = 2 } },
	Spiritual = { Name = "Cursed Energy", Stats = { QiControl = 5, Intelligence = 2 } },
	Agile = { Name = "Street Agility", Stats = { Agility = 5, Strength = 2 } },
	Courtly = { Name = "Clan Etiquette", Stats = { Charisma = 5, Intelligence = 2 } },
	Hardy = { Name = "Endurance", Stats = { Vitality = 5, Strength = 2 } },
}

GeneticsConfig.TryForChild = { Chance = 0.45, MarriedBonus = 0.2, MaxAge = 50, MaxChildren = 6 }

GeneticsConfig.GradeIndex, GeneticsConfig.TraitsById = {}, {}
for i, grade in GeneticsConfig.Grades do
	GeneticsConfig.GradeIndex[grade.Id] = i
end
for _, trait in GeneticsConfig.Traits do
	GeneticsConfig.TraitsById[trait.Id] = trait
end

return GeneticsConfig
