--[[
	Masters and sects. A master must first be discovered ("Seek a Master" action),
	then accepts you only if `Requires` is met (see Shared/Requirements for the spec).

	While you are a disciple:
		- Loyalty grows +3 per year and through loyalty quests.
		- At `TechniqueLoyalty` you learn the master's Legendary Technique (permanent this life).
	Quests: `Requires` must be met to complete; `PayMoney` is spent on completion.
]]

local MastersConfig = {}

MastersConfig.LoyaltyPerYear = 3
MastersConfig.MaxLoyalty = 100
MastersConfig.JoinLoyalty = 10
MastersConfig.SeekChance = 0.55 -- + 0.5% per Charisma level

MastersConfig.List = {
	{
		Id = "elder_mo", Name = "Elder Mo", Title = "Sword Elder", Sect = "Azure Cloud Sect", Discipline = "Sword",
		Color = Color3.fromRGB(120, 200, 255),
		Description = "A stern elder whose blade is said to split clouds.",
		Requires = { MinAge = 12, Stats = { Strength = 15, Intelligence = 30 }, MinAlignment = 0 },
		TechniqueLoyalty = 60,
		Technique = { Name = "Azure Cloud Sword Sutra", Description = "x1.5 Qi, x1.5 passive Qi, x2 Sword XP.",
			Buffs = { QiMult = 1.5, PassiveQiMult = 1.5, ProficiencyXp = { Sword = 2 } } },
		Quests = {
			{ Name = "Clear the Bandit Pass", Description = "Prove your blade.", Requires = { Proficiency = { Sword = 8 } }, Loyalty = 20 },
			{ Name = "Copy the Sect Scriptures", Description = "Study the founding texts.", Requires = { Counters = { Knowledge = 25 } }, Loyalty = 20 },
			{ Name = "Tithe to the Sect", Description = "Donate $2K to the treasury.", Requires = { MinMoney = 2000 }, PayMoney = 2000, Loyalty = 25 },
		},
	},
	{
		Id = "iron_fist_han", Name = "Iron Fist Han", Title = "Body Saint", Sect = "Iron Mountain Monastery", Discipline = "Body",
		Color = Color3.fromRGB(250, 160, 100),
		Description = "A monk who once stopped an avalanche with his bare hands.",
		Requires = { MinAge = 14, Stats = { Strength = 25, Vitality = 20 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Diamond Body Scripture", Description = "x1.5 Strength & Vitality XP, +100 HP, x1.3 passive Qi.",
			Buffs = { StatXp = { Strength = 1.5, Vitality = 1.5 }, MaxHealthBonus = 100, PassiveQiMult = 1.3 } },
		Quests = {
			{ Name = "Carry the Temple Bell", Description = "Haul the great bell up the mountain.", Requires = { Stats = { Strength = 35 } }, Loyalty = 20 },
			{ Name = "Survive the Ice Trial", Description = "Meditate seven nights in the snow.", Requires = { Stats = { Vitality = 30 } }, Loyalty = 20 },
			{ Name = "Tame the Mountain Bear", Description = "Win three real fights first.", Requires = { Counters = { Fights = 3 } }, Loyalty = 25 },
		},
	},
	{
		Id = "scholar_bai", Name = "Scholar Bai", Title = "Keeper of Scrolls", Sect = "Hall of Ten Thousand Scrolls", Discipline = "Intellect",
		Color = Color3.fromRGB(130, 220, 200),
		Description = "He has read every book in the empire. Twice.",
		Requires = { Graduated = "HighSchool", Stats = { Intelligence = 40, Charisma = 10 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Heavenly Archive Mind", Description = "x2 Intelligence XP, x1.5 study gains, x1.5 passive Qi.",
			Buffs = { StatXp = { Intelligence = 2 }, StudyMult = 1.5, PassiveQiMult = 1.5 } },
		Quests = {
			{ Name = "Catalogue the Archive", Description = "Accumulate deep knowledge.", Requires = { Counters = { Knowledge = 60 } }, Loyalty = 20 },
			{ Name = "Earn a Degree", Description = "Graduate from university.", Requires = { Graduated = "University" }, Loyalty = 20 },
			{ Name = "Debate the Grand Tutor", Description = "Out-think the emperor's tutor.", Requires = { Stats = { Intelligence = 55 } }, Loyalty = 25 },
		},
	},
	{
		Id = "madame_su", Name = "Madame Su", Title = "Moonlit Mistress", Sect = "Moonlit Pavilion", Discipline = "Social",
		Color = Color3.fromRGB(240, 140, 210),
		Description = "Kings bow to her smile. Spies fear her tea parties.",
		Requires = { MinAge = 16, Stats = { Charisma = 30, Agility = 15 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Moonlit Charm Art", Description = "x2 Charisma XP, x1.5 affection, +10% social, x1.4 passive Qi.",
			Buffs = { StatXp = { Charisma = 2 }, RelationshipMult = 1.5, SocialBonus = 0.1, PassiveQiMult = 1.4 } },
		Quests = {
			{ Name = "Weave a Web of Friends", Description = "Have 4 friends with 60+ affection.", Requires = { Friends = { Count = 4, Affection = 60 } }, Loyalty = 20 },
			{ Name = "Charm the Governor", Description = "Become irresistible.", Requires = { Stats = { Charisma = 45 } }, Loyalty = 20 },
			{ Name = "Fund the Pavilion", Description = "Donate $5K.", Requires = { MinMoney = 5000 }, PayMoney = 5000, Loyalty = 25 },
		},
	},
	{
		Id = "blood_lotus", Name = "The Blood Lotus Patriarch", Title = "Demonic Cultivator", Sect = "Blood Lotus Sect", Discipline = "Demonic Qi",
		Color = Color3.fromRGB(230, 70, 90),
		Description = "Power at any price. The price is usually someone else.",
		Requires = { Stats = { QiControl = 25 }, MaxAlignment = -30 },
		TechniqueLoyalty = 60,
		Technique = { Name = "Crimson Lotus Devouring Art", Description = "x3 Qi, x2 passive Qi, -30 years, -5 happiness per year.",
			Buffs = { QiMult = 3, PassiveQiMult = 2, LifespanBonus = -30, HappinessPerYear = -5 } },
		Quests = {
			{ Name = "Embrace the Darkness", Description = "Reach -60 alignment.", Requires = { MaxAlignment = -60 }, Loyalty = 20 },
			{ Name = "Master Blood Qi", Description = "Qi Arts proficiency 15.", Requires = { Proficiency = { QiArts = 15 } }, Loyalty = 20 },
			{ Name = "Form a Golden Core", Description = "Reach Foundation Establishment.", Requires = { MinRealm = 3 }, Loyalty = 25 },
		},
	},
	{
		Id = "spear_saint_long", Name = "Long the Wanderer", Title = "Spear Saint", Sect = "No Sect", Discipline = "Spear",
		Color = Color3.fromRGB(255, 200, 110),
		Description = "A drunk who sleeps under bridges. His spear has never missed.",
		Requires = { MinRealm = 2, Stats = { Agility = 30, Strength = 30 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Seven Stars Spear", Description = "x2 Spear XP, x1.5 Agility XP, x1.3 Qi, x1.5 passive Qi.",
			Buffs = { ProficiencyXp = { Spear = 2 }, StatXp = { Agility = 1.5 }, QiMult = 1.3, PassiveQiMult = 1.5 } },
		Quests = {
			{ Name = "One Thousand Thrusts", Description = "Spear proficiency 20.", Requires = { Proficiency = { Spear = 20 } }, Loyalty = 20 },
			{ Name = "Tavern Brawls", Description = "Win eight fights.", Requires = { Counters = { Fights = 8 } }, Loyalty = 20 },
			{ Name = "Pierce the Heavens", Description = "Reach Foundation Establishment.", Requires = { MinRealm = 3 }, Loyalty = 25 },
		},
	},
	{
		Id = "sage_ye", Name = "Celestial Sage Ye", Title = "Dao Sovereign", Sect = "Heavenly Dao Palace", Discipline = "Dao",
		Color = Color3.fromRGB(255, 245, 200),
		Description = "Some say she is a legend. Those who meet her never say anything again.",
		Requires = { MinRealm = 3, Stats = { QiControl = 50, Intelligence = 50 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Primordial Dao Breathing", Description = "x4 Qi, x2 passive Qi, +10% breakthrough.",
			Buffs = { QiMult = 4, PassiveQiMult = 2, BreakthroughBonus = 0.1 } },
		Quests = {
			{ Name = "Condense a Golden Core", Description = "Reach Core Formation.", Requires = { MinRealm = 4 }, Loyalty = 20 },
			{ Name = "Weave the Heavens", Description = "Qi Arts proficiency 30.", Requires = { Proficiency = { QiArts = 30 } }, Loyalty = 20 },
			{ Name = "Read the Celestial Archive", Description = "Knowledge 120.", Requires = { Counters = { Knowledge = 120 } }, Loyalty = 25 },
		},
	},
	-- Content expansion (2026-11-02): 7 more masters.
	{
		Id = "poet_lian", Name = "Lady Lian", Title = "Lotus Poetess", Sect = "Pavilion of Drifting Verses", Discipline = "Social",
		Color = Color3.fromRGB(240, 170, 200), Regions = { "lotus_lake" },
		Description = "Her verses have toppled two ministers and married off three princes.",
		Requires = { MinAge = 14, Stats = { Charisma = 20, Intelligence = 20 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Drifting Verse Heart", Description = "x1.6 Charisma and Intelligence XP, x1.3 passive Qi.",
			Buffs = { StatXp = { Charisma = 1.6, Intelligence = 1.6 }, PassiveQiMult = 1.3 } },
		Quests = {
			{ Name = "Win a Poetry Contest", Description = "Charisma 35.", Requires = { Stats = { Charisma = 35 } }, Loyalty = 20 },
			{ Name = "Gather Admirers", Description = "Have 3 friends with 60+ affection.", Requires = { Friends = { Count = 3, Affection = 60 } }, Loyalty = 20 },
			{ Name = "Publish a Collection", Description = "Pay $3K to the printers.", Requires = { MinMoney = 3000 }, PayMoney = 3000, Loyalty = 25 },
		},
	},
	{
		Id = "wolf_khan", Name = "Khan Borte", Title = "Wolf Khan", Sect = "Frostfang Horde", Discipline = "Body",
		Color = Color3.fromRGB(190, 220, 240), Regions = { "frost_tundra" },
		Description = "Raised by wolves, crowned by wolves. Speaks to them still.",
		Requires = { MinAge = 15, Stats = { Vitality = 25, Strength = 20 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Howl of the Endless Steppe", Description = "x1.6 Vitality XP, +80 HP, +15% battle rewards.",
			Buffs = { StatXp = { Vitality = 1.6 }, MaxHealthBonus = 80, BattleRewardMult = 1.15 } },
		Quests = {
			{ Name = "Hunt with the Pack", Description = "Win five battles.", Requires = { Counters = { Battles = 5 } }, Loyalty = 20 },
			{ Name = "Endure the Long Night", Description = "Vitality 40.", Requires = { Stats = { Vitality = 40 } }, Loyalty = 20 },
			{ Name = "Fell a Giant", Description = "Slay a boss.", Requires = { Counters = { Bosses = 1 } }, Loyalty = 25 },
		},
	},
	{
		Id = "beast_mother", Name = "Granny Thorn", Title = "Mother of Beasts", Sect = "Hidden Grove", Discipline = "Nature",
		Color = Color3.fromRGB(90, 160, 90), Regions = { "beast_forest" },
		Description = "A tiny old woman. The tigers of the forest bring her firewood.",
		Requires = { MinAge = 14, Stats = { Agility = 20 }, MinAlignment = 10 },
		TechniqueLoyalty = 60,
		Technique = { Name = "Ten Thousand Beasts Communion", Description = "x2 Qi, x1.5 Agility XP, +20 years.",
			Buffs = { QiMult = 2, StatXp = { Agility = 1.5 }, LifespanBonus = 20 } },
		Quests = {
			{ Name = "Heal a Wounded Beast", Description = "Medicine skill 15.", Requires = { MinSkill = { Medicine = 15 } }, Loyalty = 20 },
			{ Name = "Walk the Deep Forest", Description = "Exploration skill 15.", Requires = { MinSkill = { Exploration = 15 } }, Loyalty = 20 },
			{ Name = "Prove a Gentle Heart", Description = "Reach 40 alignment.", Requires = { MinAlignment = 40 }, Loyalty = 25 },
		},
	},
	{
		Id = "pirate_queen", Name = "Captain Jin Hai", Title = "Pirate Queen", Sect = "Black Sail Fleet", Discipline = "Spear",
		Color = Color3.fromRGB(110, 210, 220), Regions = { "pearl_coast" },
		Description = "Every navy in the south has a price on her head. She collects them.",
		Requires = { MinAge = 16, Stats = { Agility = 25, Charisma = 15 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Tidebreaker Harpoon Art", Description = "x1.8 Spear XP, +20% gold, x1.3 passive Qi.",
			Buffs = { ProficiencyXp = { Spear = 1.8 }, GoldMult = 1.2, PassiveQiMult = 1.3 } },
		Quests = {
			{ Name = "Raid a Merchant Ship", Description = "Spear proficiency 15.", Requires = { Proficiency = { Spear = 15 } }, Loyalty = 20 },
			{ Name = "Bury the Treasure", Description = "Hold $8K.", Requires = { MinMoney = 8000 }, Loyalty = 20 },
			{ Name = "Brawl on Every Deck", Description = "Win ten fights.", Requires = { Counters = { Fights = 10 } }, Loyalty = 25 },
		},
	},
	{
		Id = "tomb_keeper", Name = "The Nameless Tomb Keeper", Title = "Warden of the Dead", Sect = "Order of the Last Lantern", Discipline = "Spirit",
		Color = Color3.fromRGB(230, 200, 140), Regions = { "bone_desert" },
		Description = "He has guarded the titans' graves for six hundred years. He is tired.",
		Requires = { MinRealm = 3, Stats = { QiControl = 35 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Lantern of the Underworld", Description = "x2.5 Qi, +60 years, x1.4 passive Qi.",
			Buffs = { QiMult = 2.5, LifespanBonus = 60, PassiveQiMult = 1.4 } },
		Quests = {
			{ Name = "Light the Hundred Lanterns", Description = "Faith skill 30.", Requires = { MinSkill = { Faith = 30 } }, Loyalty = 20 },
			{ Name = "Unearth a Relic", Description = "Find a relic lead.", Requires = { Counters = { Leads = 1 } }, Loyalty = 20 },
			{ Name = "Grow Ancient", Description = "Reach age 100.", Requires = { MinAge = 100 }, Loyalty = 25 },
		},
	},
	{
		Id = "thunder_emperor", Name = "Thunder Emperor Lei", Title = "Lord of Tribulation", Sect = "Palace of Nine Heavens", Discipline = "Lightning",
		Color = Color3.fromRGB(170, 170, 255), Regions = { "thunder_plateau" },
		Description = "He has survived ninety-nine tribulations. Heaven gave up on the hundredth.",
		Requires = { MinRealm = 5, Stats = { QiControl = 60, Vitality = 40 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Nine Heavens Thunder Body", Description = "x4 Qi, +15% breakthrough, +20% magic damage.",
			Buffs = { QiMult = 4, BreakthroughBonus = 0.15, MagicDamageMult = 1.2 } },
		Quests = {
			{ Name = "Bathe in Lightning", Description = "Vitality 60.", Requires = { Stats = { Vitality = 60 } }, Loyalty = 20 },
			{ Name = "Reach the Sixth Realm", Description = "Break through to realm 6.", Requires = { MinRealm = 6 }, Loyalty = 20 },
			{ Name = "Command the Storm", Description = "Magic skill 45.", Requires = { MinSkill = { Magic = 45 } }, Loyalty = 25 },
		},
	},
	{
		Id = "alchemist_gu", Name = "Old Gu of the Golden Furnace", Title = "Pill Sage", Sect = "Golden Furnace Valley", Discipline = "Alchemy",
		Color = Color3.fromRGB(255, 190, 90), Regions = { "capital", "qinghe" },
		Description = "Missing both eyebrows and one finger. Best pills in the empire.",
		Requires = { MinAge = 16, Stats = { Intelligence = 30, QiControl = 15 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Golden Furnace Refinement", Description = "x1.8 Qi, x1.5 passive Qi, +60 max health.",
			Buffs = { QiMult = 1.8, PassiveQiMult = 1.5, MaxHealthBonus = 60 } },
		Quests = {
			{ Name = "Gather Rare Herbs", Description = "Medicine skill 20.", Requires = { MinSkill = { Medicine = 20 } }, Loyalty = 20 },
			{ Name = "Buy a Furnace", Description = "Pay $6K.", Requires = { MinMoney = 6000 }, PayMoney = 6000, Loyalty = 20 },
			{ Name = "Survive an Explosion", Description = "Vitality 30.", Requires = { Stats = { Vitality = 30 } }, Loyalty = 25 },
		},
	},
}

-- Where each master can be found (World module): "Seek a Master" only finds masters
-- of the current region. Masters without an entry wander everywhere.
MastersConfig.Regions = {
	iron_fist_han = { "qinghe" },
	spear_saint_long = { "qinghe", "crimson", "capital" }, -- a wanderer
	scholar_bai = { "capital" },
	madame_su = { "capital" },
	elder_mo = { "kunlun" },
	sage_ye = { "kunlun" },
	blood_lotus = { "marsh", "crimson" },
}

-- Sect hierarchy while you follow a master (MasterSystem): a yearly stipend per rank;
-- a promotion trial costs 1 action diamond and needs Requires (incl. MasterLoyalty).
-- Chance + 0.5% per level of TrialStat.
MastersConfig.SectRanks = {
	{ Id = "Outer", Name = "Outer Disciple", Stipend = 100 },
	{ Id = "Inner", Name = "Inner Disciple", Stipend = 400, Requires = { MasterLoyalty = 30, MinAge = 14 }, TrialChance = 0.6, TrialStat = "Strength" },
	{ Id = "Core", Name = "Core Disciple", Stipend = 1500, Requires = { MasterLoyalty = 60, MinRealm = 2 }, TrialChance = 0.5, TrialStat = "QiControl" },
	{ Id = "Elder", Name = "Sect Elder", Stipend = 5000, Requires = { MasterLoyalty = 90, MinRealm = 3, MinAge = 30 }, TrialChance = 0.4, TrialStat = "QiControl" },
	{ Id = "Patriarch", Name = "Grand Patriarch", Stipend = 15000, Requires = { MasterLoyalty = 100, MinRealm = 4, MinAge = 50 }, TrialChance = 0.3, TrialStat = "Charisma" },
}
MastersConfig.TrialFailHealth = -15

MastersConfig.ById = {}
for _, master in MastersConfig.List do
	MastersConfig.ById[master.Id] = master
	master.Regions = master.Regions or MastersConfig.Regions[master.Id]
end

return MastersConfig
