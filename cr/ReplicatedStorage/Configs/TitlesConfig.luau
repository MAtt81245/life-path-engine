--[[
	Unlockable titles. Checked after every action and every year; once unlocked they
	stay for the life. Up to MaxEquipped titles grant their Buffs at the same time.
	`Requires` uses the Shared/Requirements spec.
]]

local TitlesConfig = {}

TitlesConfig.MaxEquipped = 2

TitlesConfig.List = {
	{ Id = "top_student", Name = "Top Student", Description = "+15% study performance, +10% INT XP.",
		Requires = { Honors = "HighSchool" }, Buffs = { StudyMult = 1.15, StatXp = { Intelligence = 1.1 } } },
	{ Id = "bookworm", Name = "Bookworm", Description = "+15% Intelligence XP.",
		Requires = { Counters = { Knowledge = 30 } }, Buffs = { StatXp = { Intelligence = 1.15 } } },
	{ Id = "street_brawler", Name = "Street Brawler", Description = "+15% Strength XP.",
		Requires = { Counters = { Fights = 3 }, Stats = { Strength = 12 } }, Buffs = { StatXp = { Strength = 1.15 } } },
	{ Id = "initiate", Name = "Initiate", Description = "+10% cursed energy gain.",
		Requires = { HasMaster = true }, Buffs = { QiMult = 1.1 } },
	{ Id = "prodigy", Name = "Prodigy", Description = "+10% all attribute XP.",
		Requires = { MaxAge = 16, Stats = { Intelligence = 25 } }, Buffs = { AllStatXp = 1.1 } },
	{ Id = "social_butterfly", Name = "Social Butterfly", Description = "+20% affection, +15% CHA XP.",
		Requires = { Friends = { Count = 5, Affection = 70 } }, Buffs = { RelationshipMult = 1.2, StatXp = { Charisma = 1.15 } } },
	{ Id = "iron_body", Name = "Iron Body", Description = "+50 max health.",
		Requires = { Stats = { Vitality = 30 } }, Buffs = { MaxHealthBonus = 50 } },
	{ Id = "learned_scholar", Name = "Learned Scholar", Description = "+20% study, +10% salary.",
		Requires = { Graduated = "University" }, Buffs = { StudyMult = 1.2, SalaryMult = 1.1 } },
	{ Id = "wealthy_merchant", Name = "Black Market Mogul", Description = "+15% salary.",
		Requires = { MinMoney = 100000 }, Buffs = { SalaryMult = 1.15 } },
	{ Id = "blade_master", Name = "Cursed Tool Master", Description = "+30% Cursed Tools XP, +10% cursed energy.",
		Requires = { Proficiency = { Sword = 25 } }, Buffs = { ProficiencyXp = { Sword = 1.3 }, QiMult = 1.1 } },
	{ Id = "chosen_one", Name = "Chosen One", Description = "+25% cursed energy, +3% Grade Promotion.",
		Requires = { MinRealm = 3 }, Buffs = { QiMult = 1.25, BreakthroughBonus = 0.03 } },
	{ Id = "sect_elder", Name = "Faction Elder", Description = "x1.3 passive cursed energy.",
		Requires = { MasterLoyalty = 100 }, Buffs = { PassiveQiMult = 1.3 } },
	{ Id = "saint", Name = "Saint", Description = "+25% Binding Vows earned.",
		Requires = { MinAlignment = 80 }, Buffs = { KarmaMult = 1.25 } },
	{ Id = "demon_path", Name = "Curse User", Description = "+30% cursed energy, -3 happiness/year.",
		Requires = { MaxAlignment = -70 }, Buffs = { QiMult = 1.3, HappinessPerYear = -3 } },
	-- Specialized runs: one life cannot do all three.
	{ Id = "demon_cult_blade", Name = "Curse User Blademaster", Description = "+30% Cursed Tools XP, +15% cursed energy.",
		Requires = { MaxAlignment = -50, Proficiency = { Sword = 40 } }, Buffs = { ProficiencyXp = { Sword = 1.3 }, QiMult = 1.15 } },
	{ Id = "scholarly_emperor", Name = "Higher-Up Strategist", Description = "+30% salary, +20% study.",
		Requires = { Stats = { Intelligence = 50, Charisma = 30 }, Graduated = "University", Employed = true }, Buffs = { SalaryMult = 1.3, StudyMult = 1.2 } },
	{ Id = "pure_qi_immortal", Name = "Special Grade Prodigy", Description = "x1.5 passive cursed energy, +5% Grade Promotion.",
		Requires = { MinRealm = 6, Stats = { QiControl = 45 } }, Buffs = { PassiveQiMult = 1.5, BreakthroughBonus = 0.05 } },
	{ Id = "centenarian", Name = "Centenarian", Description = "+10 years of lifespan.",
		Requires = { MinAge = 100 }, Buffs = { LifespanBonus = 10 } },
	-- Content expansion (2026-11-02): 19 more titles.
	{ Id = "grade4_exorcist", Name = "Curse Sweeper", Description = "+10% Strength XP.",
		Requires = { Counters = { Fights = 5 } }, Buffs = { StatXp = { Strength = 1.1 } } },
	{ Id = "brawler_king", Name = "King of Brawlers", Description = "+20% Strength XP.",
		Requires = { Counters = { Fights = 10 } }, Buffs = { StatXp = { Strength = 1.2 } } },
	{ Id = "veteran_exorcist", Name = "Veteran Exorcist", Description = "+40 max health.",
		Requires = { Counters = { Fights = 25 } }, Buffs = { MaxHealthBonus = 40 } },
	{ Id = "swift_foot", Name = "Swift Foot", Description = "+15% Agility XP.",
		Requires = { Stats = { Agility = 30 } }, Buffs = { StatXp = { Agility = 1.15 } } },
	{ Id = "golden_voice", Name = "Cursed Speech Charm", Description = "+15% Charisma XP.",
		Requires = { Stats = { Charisma = 35 } }, Buffs = { StatXp = { Charisma = 1.15 } } },
	{ Id = "qi_adept", Name = "Cursed Energy Adept", Description = "+5% cursed energy gain.",
		Requires = { Stats = { QiControl = 30 } }, Buffs = { QiMult = 1.05 } },
	{ Id = "tool_wielder", Name = "Cursed Tool Wielder", Description = "+15% Cursed Tools XP.",
		Requires = { Proficiency = { Sword = 25 } }, Buffs = { ProficiencyXp = { Sword = 1.15 } } },
	{ Id = "taijutsu_ace", Name = "Taijutsu Ace", Description = "+15% Taijutsu XP.",
		Requires = { Proficiency = { Spear = 25 } }, Buffs = { ProficiencyXp = { Spear = 1.15 } } },
	{ Id = "barrier_adept", Name = "Barrier Adept", Description = "+15% Barrier & Domain Arts XP.",
		Requires = { Proficiency = { QiArts = 25 } }, Buffs = { ProficiencyXp = { QiArts = 1.15 } } },
	{ Id = "domain_holder", Name = "Domain Holder", Description = "+4% Grade Promotion.",
		Requires = { Proficiency = { QiArts = 60 }, MinRealm = 5 }, Buffs = { BreakthroughBonus = 0.04 } },
	{ Id = "archivist", Name = "Window Archivist", Description = "+15% study.",
		Requires = { Counters = { Knowledge = 80 } }, Buffs = { StudyMult = 1.15 } },
	{ Id = "grade2_official", Name = "Grade 2 Officer", Description = "+10% salary.",
		Requires = { MinRealm = 5 }, Buffs = { SalaryMult = 1.1 } },
	{ Id = "special_grade_title", Name = "Special Grade", Description = "+4% Grade Promotion.",
		Requires = { MinRealm = 8 }, Buffs = { BreakthroughBonus = 0.04 } },
	{ Id = "family_head", Name = "Head of the Family", Description = "+5 happiness per year.",
		Requires = { Flag = "Married", HasRelationship = "Child" }, Buffs = { HappinessPerYear = 5 } },
	{ Id = "beloved", Name = "Beloved by All", Description = "+25% affection gains.",
		Requires = { Friends = { Count = 8, Affection = 70 } }, Buffs = { RelationshipMult = 1.25 } },
	{ Id = "righteous_sorcerer", Name = "Righteous Sorcerer", Description = "+15% Binding Vows earned.",
		Requires = { MinAlignment = 60 }, Buffs = { KarmaMult = 1.15 } },
	{ Id = "curse_user_title", Name = "Infamous Curse User", Description = "+8% cursed energy gain, -1 happiness a year.",
		Requires = { MaxAlignment = -60 }, Buffs = { QiMult = 1.08, HappinessPerYear = -1 } },
	{ Id = "millionaire", Name = "Millionaire", Description = "+20% salary.",
		Requires = { MinMoney = 1000000 }, Buffs = { SalaryMult = 1.2 } },
	{ Id = "elder_sage", Name = "Elder of the Jujutsu World", Description = "+20% study, -1 stress a year.",
		Requires = { MinAge = 150 }, Buffs = { StudyMult = 1.2, StressPerYear = -1 } },
	-- Earned by transcending at the peak grade 9 (Modules/AscensionSystem); every later life has it.
	{ Id = "heavenly_ascendant", Name = "Calamity of Legend", Description = "+5% Grade Promotion, +10 years of lifespan.",
		Requires = { Flag = "HeavenlyAscendant" }, Buffs = { BreakthroughBonus = 0.05, LifespanBonus = 10 } },
}

TitlesConfig.ById = {}
for _, title in TitlesConfig.List do
	TitlesConfig.ById[title.Id] = title
end

return TitlesConfig
