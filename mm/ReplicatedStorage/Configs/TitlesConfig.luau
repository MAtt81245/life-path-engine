--[[
	Unlockable titles. Checked after every action and every year; once unlocked they
	stay for the life. Up to MaxEquipped titles grant their Buffs at the same time.
	`Requires` uses the Shared/Requirements spec.
]]

local TitlesConfig = {}

TitlesConfig.MaxEquipped = 2

TitlesConfig.List = {
	-- 3.0 Title Book additions (journal counters, life skills, the guild).
	{ Id = "monster_hunter", Name = "Monster Hunter", Description = "+10% battle rewards.", Requires = { Counters = { Battles = 10 } }, Buffs = { BattleRewardMult = 1.1 } },
	{ Id = "dragon_slayer", Name = "Slayer of Giants", Description = "+10% sword damage.", Requires = { Counters = { Bosses = 1 } }, Buffs = { SwordDamageMult = 1.1 } },
	{ Id = "arcanist", Name = "Arcanist", Description = "+10% magic damage.", Requires = { MinSkill = { Magic = 30 } }, Buffs = { MagicDamageMult = 1.1 } },
	{ Id = "blade_saint", Name = "Blade Saint", Description = "+15% sword damage.", Requires = { MinSkill = { Swordsmanship = 45 } }, Buffs = { SwordDamageMult = 1.15 } },
	{ Id = "spellwright", Name = "Spellwright", Description = "-10% mana costs.", Requires = { Counters = { Forged = 1 } }, Buffs = { ManaCostMult = 0.9 } },
	{ Id = "chantless_one", Name = "The Chantless", Description = "-8% mana costs.", Requires = { Counters = { Spells = 50 } }, Buffs = { ManaCostMult = 0.92 } },
	{ Id = "merchant_prince", Name = "Merchant Prince", Description = "+10% gold.", Requires = { MinSkill = { Trade = 30 } }, Buffs = { GoldMult = 1.1 } },
	{ Id = "healer", Name = "Healer", Description = "+30 max health.", Requires = { MinSkill = { Medicine = 30 } }, Buffs = { MaxHealthBonus = 30 } },
	{ Id = "shadow", Name = "The Shadow", Description = "Easier escapes.", Requires = { MinSkill = { Stealth = 30 } }, Buffs = { FleeBonus = 0.15 } },
	{ Id = "explorer", Name = "Explorer", Description = "+10% battle rewards.", Requires = { MinSkill = { Exploration = 30 } }, Buffs = { BattleRewardMult = 1.1 } },
	{ Id = "faithful", Name = "The Faithful", Description = "+5 years of lifespan.", Requires = { MinSkill = { Faith = 30 } }, Buffs = { LifespanBonus = 5 } },
	{ Id = "survivor", Name = "Survivor", Description = "-1 stress a year.", Requires = { MinSkill = { Survival = 30 } }, Buffs = { StressPerYear = -1 } },
	{ Id = "artisan", Name = "Artisan", Description = "+5% gold.", Requires = { MinSkill = { Crafting = 30 } }, Buffs = { GoldMult = 1.05 } },
	{ Id = "orator", Name = "Orator", Description = "+5% social success.", Requires = { MinSkill = { Charisma = 30 } }, Buffs = { SocialBonus = 0.05 } },
	{ Id = "athlete", Name = "Athlete", Description = "+25 max health.", Requires = { MinSkill = { Fitness = 30 } }, Buffs = { MaxHealthBonus = 25 } },
	{ Id = "sage", Name = "Sage", Description = "+15% study.", Requires = { MinSkill = { Knowledge = 45 } }, Buffs = { StudyMult = 1.15 } },
	{ Id = "raider", Name = "Raider", Description = "+10% battle rewards.", Requires = { Counters = { Raids = 1 } }, Buffs = { BattleRewardMult = 1.1 } },
	{ Id = "throne_holder", Name = "Throne Holder", Description = "+10% sword and magic damage.", Requires = { Counters = { Thrones = 1 } }, Buffs = { SwordDamageMult = 1.1, MagicDamageMult = 1.1 } },
	{ Id = "guild_member", Name = "Guild Member", Description = "+5% affection gains.", Requires = { Flag = "GuildMember" }, Buffs = { RelationshipMult = 1.05 } },
	{ Id = "top_student", Name = "Top Student", Description = "+15% study performance, +10% INT XP.",
		Requires = { Honors = "HighSchool" }, Buffs = { StudyMult = 1.15, StatXp = { Intelligence = 1.1 } } },
	{ Id = "bookworm", Name = "Bookworm", Description = "+15% Intelligence XP.",
		Requires = { Counters = { Knowledge = 30 } }, Buffs = { StatXp = { Intelligence = 1.15 } } },
	{ Id = "street_brawler", Name = "Street Brawler", Description = "+15% Strength XP.",
		Requires = { Counters = { Fights = 3 }, Stats = { Strength = 12 } }, Buffs = { StatXp = { Strength = 1.15 } } },
	{ Id = "initiate", Name = "Initiate", Description = "+10% Qi gain.",
		Requires = { HasMaster = true }, Buffs = { QiMult = 1.1 } },
	{ Id = "prodigy", Name = "Prodigy", Description = "+10% all attribute XP.",
		Requires = { MaxAge = 16, Stats = { Intelligence = 25 } }, Buffs = { AllStatXp = 1.1 } },
	{ Id = "social_butterfly", Name = "Social Butterfly", Description = "+20% affection, +15% CHA XP.",
		Requires = { Friends = { Count = 5, Affection = 70 } }, Buffs = { RelationshipMult = 1.2, StatXp = { Charisma = 1.15 } } },
	{ Id = "iron_body", Name = "Iron Body", Description = "+50 max health.",
		Requires = { Stats = { Vitality = 30 } }, Buffs = { MaxHealthBonus = 50 } },
	{ Id = "learned_scholar", Name = "Learned Scholar", Description = "+20% study, +10% salary.",
		Requires = { Graduated = "University" }, Buffs = { StudyMult = 1.2, SalaryMult = 1.1 } },
	{ Id = "wealthy_merchant", Name = "Wealthy Merchant", Description = "+15% salary.",
		Requires = { MinMoney = 100000 }, Buffs = { SalaryMult = 1.15 } },
	{ Id = "blade_master", Name = "Blade Master", Description = "+30% Sword XP, +10% Qi.",
		Requires = { Proficiency = { Sword = 25 } }, Buffs = { ProficiencyXp = { Sword = 1.3 }, QiMult = 1.1 } },
	{ Id = "chosen_one", Name = "Chosen One", Description = "+25% Qi, +3% breakthrough.",
		Requires = { MinRealm = 3 }, Buffs = { QiMult = 1.25, BreakthroughBonus = 0.03 } },
	{ Id = "sect_elder", Name = "Sect Elder", Description = "x1.3 passive Qi.",
		Requires = { MasterLoyalty = 100 }, Buffs = { PassiveQiMult = 1.3 } },
	{ Id = "saint", Name = "Saint", Description = "+25% Karma earned.",
		Requires = { MinAlignment = 80 }, Buffs = { KarmaMult = 1.25 } },
	{ Id = "demon_path", Name = "Demon Path Walker", Description = "+30% Qi, -3 happiness/year.",
		Requires = { MaxAlignment = -70 }, Buffs = { QiMult = 1.3, HappinessPerYear = -3 } },
	-- Specialized runs: one life cannot do all three.
	{ Id = "demon_cult_blade", Name = "Demon Cult Blademaster", Description = "+30% Sword XP, +15% Qi.",
		Requires = { MaxAlignment = -50, Proficiency = { Sword = 40 } }, Buffs = { ProficiencyXp = { Sword = 1.3 }, QiMult = 1.15 } },
	{ Id = "scholarly_emperor", Name = "Scholarly Emperor", Description = "+30% salary, +20% study.",
		Requires = { Stats = { Intelligence = 50, Charisma = 30 }, Graduated = "University", Employed = true }, Buffs = { SalaryMult = 1.3, StudyMult = 1.2 } },
	{ Id = "pure_qi_immortal", Name = "Pure Qi Immortal", Description = "x1.5 passive Qi, +5% breakthrough.",
		Requires = { MinRealm = 6, Stats = { QiControl = 45 } }, Buffs = { PassiveQiMult = 1.5, BreakthroughBonus = 0.05 } },
	{ Id = "centenarian", Name = "Centenarian", Description = "+10 years of lifespan.",
		Requires = { MinAge = 100 }, Buffs = { LifespanBonus = 10 } },
	-- Earned by ascending at True Immortal 9 (Modules/AscensionSystem); every later life has it.
	{ Id = "heavenly_ascendant", Name = "Heavenly Ascendant", Description = "+5% breakthrough, +10 years of lifespan.",
		Requires = { Flag = "HeavenlyAscendant" }, Buffs = { BreakthroughBonus = 0.05, LifespanBonus = 10 } },
	-- Content expansion (2026-11-02): 38 more titles.
	{ Id = "veteran", Name = "Veteran", Description = "+15% battle rewards.", Requires = { Counters = { Battles = 25 } }, Buffs = { BattleRewardMult = 1.15 } },
	{ Id = "warlord", Name = "Warlord", Description = "+20% battle rewards.", Requires = { Counters = { Battles = 50 } }, Buffs = { BattleRewardMult = 1.2 } },
	{ Id = "giant_bane", Name = "Bane of Giants", Description = "+10% sword and magic damage.", Requires = { Counters = { Bosses = 3 } }, Buffs = { SwordDamageMult = 1.1, MagicDamageMult = 1.1 } },
	{ Id = "archmage", Name = "Archmage", Description = "+15% magic damage.", Requires = { MinSkill = { Magic = 45 } }, Buffs = { MagicDamageMult = 1.15 } },
	{ Id = "duelist", Name = "Duelist", Description = "+8% sword damage.", Requires = { MinSkill = { Swordsmanship = 30 } }, Buffs = { SwordDamageMult = 1.08 } },
	{ Id = "spell_forger", Name = "Master Spellforger", Description = "-12% mana costs.", Requires = { Counters = { Forged = 3 } }, Buffs = { ManaCostMult = 0.88 } },
	{ Id = "trade_magnate", Name = "Trade Magnate", Description = "+15% gold.", Requires = { MinSkill = { Trade = 45 } }, Buffs = { GoldMult = 1.15 } },
	{ Id = "divine_physician", Name = "Divine Physician", Description = "+50 max health.", Requires = { MinSkill = { Medicine = 45 } }, Buffs = { MaxHealthBonus = 50 } },
	{ Id = "phantom", Name = "Phantom", Description = "Much easier escapes.", Requires = { MinSkill = { Stealth = 45 } }, Buffs = { FleeBonus = 0.25 } },
	{ Id = "pathfinder", Name = "Pathfinder", Description = "+15% battle rewards.", Requires = { MinSkill = { Exploration = 45 } }, Buffs = { BattleRewardMult = 1.15 } },
	{ Id = "high_priest", Name = "High Priest", Description = "+10 years of lifespan.", Requires = { MinSkill = { Faith = 45 } }, Buffs = { LifespanBonus = 10 } },
	{ Id = "unbreakable", Name = "Unbreakable", Description = "-2 stress a year.", Requires = { MinSkill = { Survival = 45 } }, Buffs = { StressPerYear = -2 } },
	{ Id = "grand_artisan", Name = "Grand Artisan", Description = "+10% gold.", Requires = { MinSkill = { Crafting = 45 } }, Buffs = { GoldMult = 1.1 } },
	{ Id = "honeyed_tongue", Name = "Honeyed Tongue", Description = "+10% social success.", Requires = { MinSkill = { Charisma = 45 } }, Buffs = { SocialBonus = 0.1 } },
	{ Id = "iron_athlete", Name = "Iron Athlete", Description = "+40 max health.", Requires = { MinSkill = { Fitness = 45 } }, Buffs = { MaxHealthBonus = 40 } },
	{ Id = "raid_captain", Name = "Raid Captain", Description = "+15% battle rewards.", Requires = { Counters = { Raids = 3 } }, Buffs = { BattleRewardMult = 1.15 } },
	{ Id = "relic_hunter", Name = "Relic Hunter", Description = "+10% gold.", Requires = { Counters = { Leads = 3 } }, Buffs = { GoldMult = 1.1 } },
	{ Id = "omen_reader", Name = "Omen Reader", Description = "+10% Karma earned.", Requires = { Counters = { Omens = 10 } }, Buffs = { KarmaMult = 1.1 } },
	{ Id = "game_master", Name = "Game Master", Description = "+10% Agility XP.", Requires = { Counters = { Minigames = 10 } }, Buffs = { StatXp = { Agility = 1.1 } } },
	{ Id = "dedicated", Name = "The Dedicated", Description = "+10% all attribute XP.", Requires = { Counters = { SkillActions = 15 } }, Buffs = { AllStatXp = 1.1 } },
	{ Id = "trait_alchemist", Name = "Trait Alchemist", Description = "+10% Qi gain.", Requires = { Counters = { Fusions = 3 } }, Buffs = { QiMult = 1.1 } },
	{ Id = "devoted_heart", Name = "Devoted Heart", Description = "+15% affection gains.", Requires = { Counters = { BondLevels = 5 } }, Buffs = { RelationshipMult = 1.15 } },
	{ Id = "brawler_king", Name = "King of Brawlers", Description = "+20% Strength XP.", Requires = { Counters = { Fights = 10 } }, Buffs = { StatXp = { Strength = 1.2 } } },
	{ Id = "swift_foot", Name = "Swift Foot", Description = "+15% Agility XP.", Requires = { Stats = { Agility = 30 } }, Buffs = { StatXp = { Agility = 1.15 } } },
	{ Id = "golden_voice", Name = "Golden Voice", Description = "+15% Charisma XP.", Requires = { Stats = { Charisma = 35 } }, Buffs = { StatXp = { Charisma = 1.15 } } },
	{ Id = "star_blessed", Name = "Star-Blessed", Description = "+5% gold, +5% battle rewards.", Requires = { Stats = { Luck = 25 } }, Buffs = { GoldMult = 1.05, BattleRewardMult = 1.05 } },
	{ Id = "qi_adept", Name = "Qi Adept", Description = "+5% Qi gain.", Requires = { Stats = { QiControl = 30 } }, Buffs = { QiMult = 1.05 } },
	{ Id = "core_former", Name = "Core Former", Description = "+10% study.", Requires = { MinRealm = 4 }, Buffs = { StudyMult = 1.1 } },
	{ Id = "realm_lord", Name = "Realm Lord", Description = "+4% breakthrough.", Requires = { MinRealm = 8 }, Buffs = { BreakthroughBonus = 0.04 } },
	{ Id = "graduate_master", Name = "Master of Letters", Description = "+20% salary.", Requires = { Graduated = "Graduate" }, Buffs = { SalaryMult = 1.2 } },
	{ Id = "family_head", Name = "Head of the Family", Description = "+5 happiness per year.", Requires = { Flag = "Married", HasRelationship = "Child" }, Buffs = { HappinessPerYear = 5 } },
	{ Id = "beloved", Name = "Beloved by All", Description = "+25% affection gains.", Requires = { Friends = { Count = 8, Affection = 70 } }, Buffs = { RelationshipMult = 1.25 } },
	{ Id = "honest_soul", Name = "Honest Soul", Description = "+15% Karma earned.", Requires = { Personality = { Honesty = 60 } }, Buffs = { KarmaMult = 1.15 } },
	{ Id = "fearless", Name = "The Fearless", Description = "+10% sword damage.", Requires = { Personality = { Bravery = 60 } }, Buffs = { SwordDamageMult = 1.1 } },
	{ Id = "still_water", Name = "Still Water", Description = "-2 stress a year.", Requires = { Personality = { Patience = 60 } }, Buffs = { StressPerYear = -2 } },
	{ Id = "millionaire", Name = "Millionaire", Description = "+20% gold.", Requires = { MinMoney = 1000000 }, Buffs = { GoldMult = 1.2 } },
	{ Id = "elder_sage", Name = "Elder Sage", Description = "+20% study.", Requires = { MinAge = 150 }, Buffs = { StudyMult = 1.2 } },
	{ Id = "dragon_blood", Name = "Dragon-Blooded", Description = "+40 max health, +10% Qi.", Requires = { Race = "DragonVein" }, Buffs = { MaxHealthBonus = 40, QiMult = 1.1 } },
}

TitlesConfig.ById = {}
for _, title in TitlesConfig.List do
	TitlesConfig.ById[title.Id] = title
end

return TitlesConfig
