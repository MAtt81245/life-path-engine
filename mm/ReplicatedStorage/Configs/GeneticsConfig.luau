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
	{ Id = "Mortal", Name = "Mortal", Weight = 58, Color = Color3.fromRGB(180, 176, 166),
		RomanceCharisma = 0, RomanceRealm = 1, ChancePenalty = 0, MutationBonus = 0, TraitChance = 0.5 },
	{ Id = "Uncommon", Name = "Uncommon", Weight = 26, Color = Color3.fromRGB(120, 210, 150),
		RomanceCharisma = 8, RomanceRealm = 1, ChancePenalty = 0.03, MutationBonus = 0.03, TraitChance = 0.575 },
	{ Id = "Rare", Name = "Rare", Weight = 11, Color = Color3.fromRGB(96, 170, 255),
		RomanceCharisma = 18, RomanceRealm = 2, ChancePenalty = 0.06, MutationBonus = 0.08, TraitChance = 0.65 },
	{ Id = "Genius", Name = "Genius", Weight = 4, Color = Color3.fromRGB(186, 120, 255),
		RomanceCharisma = 28, RomanceRealm = 3, ChancePenalty = 0.1, MutationBonus = 0.18, TraitChance = 0.725 },
	{ Id = "Peerless", Name = "Peerless", Weight = 1, Color = Color3.fromRGB(240, 196, 92),
		RomanceCharisma = 40, RomanceRealm = 4, ChancePenalty = 0.15, MutationBonus = 0.25, TraitChance = 0.8 },
}
GeneticsConfig.BaseMutation = 0.10 -- up to 0.35 with a Peerless spouse
GeneticsConfig.HigherParentShare = 0.6
-- Your own grade comes from your realm (index = realm, capped at the last entry).
GeneticsConfig.PlayerGradeByRealm = { 1, 2, 3, 4, 4, 5 }
GeneticsConfig.PotentialPerLevels = 10
-- Spirit roots extend natural life: old-age deaths start at 60 + LongevityPerGrade x grade
-- index (Mortal 85 ... Peerless 185), so well-bred heirs outlive their cultivator parent.
GeneticsConfig.LongevityPerGrade = 25

GeneticsConfig.Traits = {
	{ Id = "SwordHeart", Name = "Sword Heart", Description = "+25% Sword XP.", Buffs = { ProficiencyXp = { Sword = 1.25 } } },
	{ Id = "ScholarsMind", Name = "Scholar's Mind", Description = "+25% Intelligence XP.", Buffs = { StatXp = { Intelligence = 1.25 } } },
	{ Id = "MerchantBlood", Name = "Rich Merchant Blood", Description = "+20% salary.", Buffs = { SalaryMult = 1.2 } },
	{ Id = "QiAffinity", Name = "High Qi Affinity", Description = "+20% Qi.", Buffs = { QiMult = 1.2 } },
	{ Id = "IronBody", Name = "Iron Body", Description = "+30 max health.", Buffs = { MaxHealthBonus = 30 } },
	{ Id = "SilverTongue", Name = "Silver Tongue", Description = "+25% Charisma XP.", Buffs = { StatXp = { Charisma = 1.25 } } },
	-- Content expansion (2026-11-02): 6 more inheritable traits.
	{ Id = "SwiftFeet", Name = "Swift Feet", Description = "+25% Agility XP.", Buffs = { StatXp = { Agility = 1.25 } } },
	{ Id = "LongLived", Name = "Long-Lived Line", Description = "+10 years of lifespan.", Buffs = { LifespanBonus = 10 } },
	{ Id = "SpearArm", Name = "Spear Arm", Description = "+25% Spear XP.", Buffs = { ProficiencyXp = { Spear = 1.25 } } },
	{ Id = "WarmHeart", Name = "Warm Heart", Description = "+15% affection gains.", Buffs = { RelationshipMult = 1.15 } },
	{ Id = "ManaVein", Name = "Mana Vein", Description = "-10% mana costs.", Buffs = { ManaCostMult = 0.9 } },
	{ Id = "Fortunate", Name = "Born Fortunate", Description = "+20% Luck XP.", Buffs = { StatXp = { Luck = 1.2 } } },
}

-- Upbringing guidance for a child (once): starting levels if you are reborn as them.
GeneticsConfig.Upbringings = {
	Martial = { Name = "Martial", Stats = { Strength = 4, Vitality = 3 } },
	Scholarly = { Name = "Scholarly", Stats = { Intelligence = 5, Charisma = 2 } },
	Spiritual = { Name = "Spiritual", Stats = { QiControl = 5, Intelligence = 2 } },
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
