--[[
	Mentors and divisions / factions. A mentor must first be discovered ("Seek a Mentor" action),
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
		Id = "elder_mo", Name = "The Old Man of the Inner World", Title = "Zanpakuto Spirit", Sect = "Your Inner World", Discipline = "Zanjutsu",
		Color = Color3.fromRGB(120, 200, 255),
		Description = "A gruff man in a black coat who stands on the side of a skyscraper inside your soul.",
		Requires = { MinAge = 12, Stats = { Strength = 15, Intelligence = 30 }, MinAlignment = 0 },
		TechniqueLoyalty = 60,
		Technique = { Name = "Crescent Getsuga Wave", Description = "x1.5 SP, x1.5 passive SP, x2 Zanjutsu XP.",
			Buffs = { QiMult = 1.5, PassiveQiMult = 1.5, ProficiencyXp = { Sword = 2 } } },
		Quests = {
			{ Name = "Hear the Blade's Name", Description = "Prove your swordwork until he speaks his name.", Requires = { Proficiency = { Sword = 8 } }, Loyalty = 20 },
			{ Name = "Understand Your Soul", Description = "Study what your blade is trying to tell you.", Requires = { Counters = { Knowledge = 25 } }, Loyalty = 20 },
			{ Name = "Buy a Training Gigai", Description = "Spend Kan 2K on a spare body for your training.", Requires = { MinMoney = 2000 }, PayMoney = 2000, Loyalty = 25 },
		},
	},
	{
		Id = "iron_fist_han", Name = "The One-Eyed Eleventh Captain", Title = "Squad Eleven Captain", Sect = "Squad Eleven", Discipline = "Unbridled Zanjutsu",
		Color = Color3.fromRGB(250, 160, 100),
		Description = "He wears an eyepatch to hold back his spiritual pressure and fights only for the joy of it.",
		Requires = { MinAge = 14, Stats = { Strength = 25, Vitality = 20 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Crushing Spiritual Pressure", Description = "x1.5 Strength & Vitality XP, +100 HP, x1.3 passive SP.",
			Buffs = { StatXp = { Strength = 1.5, Vitality = 1.5 }, MaxHealthBonus = 100, PassiveQiMult = 1.3 } },
		Quests = {
			{ Name = "Survive His Pressure", Description = "Stand upright while he removes the eyepatch.", Requires = { Stats = { Strength = 35 } }, Loyalty = 20 },
			{ Name = "Endure the Squad Eleven Gauntlet", Description = "Meditate seven nights between brawls in the barracks.", Requires = { Stats = { Vitality = 30 } }, Loyalty = 20 },
			{ Name = "Earn a Bell", Description = "Win three real fights first.", Requires = { Counters = { Fights = 3 } }, Loyalty = 25 },
		},
	},
	{
		Id = "scholar_bai", Name = "The Hat-and-Clogs Shopkeeper", Title = "Exiled Genius", Sect = "Urahara Shop", Discipline = "Shikai & Kido Strategy",
		Color = Color3.fromRGB(130, 220, 200),
		Description = "A cheerful candy-shop owner with a cane, a fan and a secret training cavern beneath the floor.",
		Requires = { Graduated = "HighSchool", Stats = { Intelligence = 40, Charisma = 10 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Shikai Awakening Trial", Description = "x2 Intelligence XP, x1.5 study gains, x1.5 passive SP.",
			Buffs = { StatXp = { Intelligence = 2 }, StudyMult = 1.5, PassiveQiMult = 1.5 } },
		Quests = {
			{ Name = "Break the Soul Chain", Description = "Accumulate deep knowledge.", Requires = { Counters = { Knowledge = 60 } }, Loyalty = 20 },
			{ Name = "Earn a Degree", Description = "Graduate from university.", Requires = { Graduated = "University" }, Loyalty = 20 },
			{ Name = "Knock the Hat Off", Description = "Out-think the shopkeeper once.", Requires = { Stats = { Intelligence = 55 } }, Loyalty = 25 },
		},
	},
	{
		Id = "madame_su", Name = "The Flower-Loving Eighth Captain", Title = "Squad Eight Captain", Sect = "Squad Eight", Discipline = "Charm & Twin Blades",
		Color = Color3.fromRGB(240, 140, 210),
		Description = "A lazy captain in a pink kimono and straw hat. He wins by making everyone like him first.",
		Requires = { MinAge = 16, Stats = { Charisma = 30, Agility = 15 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Children's Game Rules", Description = "x2 Charisma XP, x1.5 affection, +10% social, x1.4 passive SP.",
			Buffs = { StatXp = { Charisma = 2 }, RelationshipMult = 1.5, SocialBonus = 0.1, PassiveQiMult = 1.4 } },
		Quests = {
			{ Name = "Make Best Friends", Description = "Have 4 friends with 60+ affection.", Requires = { Friends = { Count = 4, Affection = 60 } }, Loyalty = 20 },
			{ Name = "Share a Drink", Description = "Keep up with him at the tea house.", Requires = { Stats = { Charisma = 45 } }, Loyalty = 20 },
			{ Name = "Buy Sake for the Squad", Description = "Spend Kan 5K on a squad celebration.", Requires = { MinMoney = 5000 }, PayMoney = 5000, Loyalty = 25 },
		},
	},
	{
		Id = "blood_lotus", Name = "The Mad Scientist Twelfth Captain", Title = "Research Director", Sect = "Research & Development Institute", Discipline = "Forbidden Experiments",
		Color = Color3.fromRGB(230, 70, 90),
		Description = "Painted face, cold eyes, endless experiments. Power at any price, and the price is usually someone else.",
		Requires = { Stats = { QiControl = 25 }, MaxAlignment = -30 },
		TechniqueLoyalty = 60,
		Technique = { Name = "Hollowfication Serum", Description = "x3 SP, x2 passive SP, -30 years, -5 happiness per year.",
			Buffs = { QiMult = 3, PassiveQiMult = 2, LifespanBonus = -30, HappinessPerYear = -5 } },
		Quests = {
			{ Name = "Accept the Experiment", Description = "Reach -60 alignment.", Requires = { MaxAlignment = -60 }, Loyalty = 20 },
			{ Name = "Absorb a Hollow", Description = "Kido & Cero Arts 15.", Requires = { Proficiency = { QiArts = 15 } }, Loyalty = 20 },
			{ Name = "Prove Your Class", Description = "Reach Unseated Soul Reaper.", Requires = { MinRealm = 3 }, Loyalty = 25 },
		},
	},
	{
		Id = "spear_saint_long", Name = "The Flash-Step Goddess", Title = "Former Stealth Force Commander", Sect = "Stealth Force", Discipline = "Hakuda & Hoho",
		Color = Color3.fromRGB(255, 200, 110),
		Description = "She is gone before you finish blinking, and she laughs about it from behind you.",
		Requires = { MinRealm = 2, Stats = { Agility = 30, Strength = 30 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Shunko Lightning-Wind", Description = "x2 Hakuda & Hoho XP, x1.5 Agility XP, x1.3 SP, x1.5 passive SP.",
			Buffs = { ProficiencyXp = { Spear = 2 }, StatXp = { Agility = 1.5 }, QiMult = 1.3, PassiveQiMult = 1.5 } },
		Quests = {
			{ Name = "Catch the Goddess", Description = "Hakuda & Hoho 20.", Requires = { Proficiency = { Spear = 20 } }, Loyalty = 20 },
			{ Name = "Sparring Rounds", Description = "Win eight fights.", Requires = { Counters = { Fights = 8 } }, Loyalty = 20 },
			{ Name = "Earn Her Respect", Description = "Reach Unseated Soul Reaper.", Requires = { MinRealm = 3 }, Loyalty = 25 },
		},
	},
	{
		Id = "sage_ye", Name = "The Monk of Squad Zero", Title = "Royal Guard", Sect = "Squad Zero", Discipline = "True Names",
		Color = Color3.fromRGB(255, 245, 200),
		Description = "A towering monk who knows the true name of everything in Soul Society, including yours.",
		Requires = { MinRealm = 3, Stats = { QiControl = 50, Intelligence = 50 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "True Name Mastery", Description = "x4 SP, x2 passive SP, +10% Soul Awakening.",
			Buffs = { QiMult = 4, PassiveQiMult = 2, BreakthroughBonus = 0.1 } },
		Quests = {
			{ Name = "Earn a Seat", Description = "Reach Seated Squad Officer.", Requires = { MinRealm = 4 }, Loyalty = 20 },
			{ Name = "Speak in True Names", Description = "Kido & Cero Arts 30.", Requires = { Proficiency = { QiArts = 30 } }, Loyalty = 20 },
			{ Name = "Read the Book of Names", Description = "Knowledge 120.", Requires = { Counters = { Knowledge = 120 } }, Loyalty = 25 },
		},
	},
	-- Content expansion (2026-11-02): 7 more mentors.
	{
		Id = "river_medium", Name = "The Old Lantern Medium", Title = "Riverbank Spirit Medium", Sect = "Karakura Lantern Society", Discipline = "Spirit",
		Color = Color3.fromRGB(120, 200, 230), Regions = { "karakura_river" },
		Description = "A tiny woman who has talked with the dead every evening for sixty years.",
		Requires = { MinAge = 10, Stats = { Charisma = 15 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Lantern Communion", Description = "x1.5 Charisma XP, x1.3 Reiatsu, +20% affection.",
			Buffs = { StatXp = { Charisma = 1.5 }, QiMult = 1.3, RelationshipMult = 1.2 } },
		Quests = {
			{ Name = "Guide Ten Souls", Description = "Reach 20 alignment.", Requires = { MinAlignment = 20 }, Loyalty = 20 },
			{ Name = "Float a Thousand Lanterns", Description = "Pay $1K for lanterns.", Requires = { MinMoney = 1000 }, PayMoney = 1000, Loyalty = 20 },
			{ Name = "Hear the Quiet Ones", Description = "Intelligence 30.", Requires = { Stats = { Intelligence = 30 } }, Loyalty = 25 },
		},
	},
	{
		Id = "arcade_sensei", Name = "The Arcade Sensei", Title = "Retired Substitute", Sect = "No Division", Discipline = "Speed",
		Color = Color3.fromRGB(240, 120, 200), Regions = { "naruki" },
		Description = "Always on the same arcade cabinet. Never loses. Moves faster than the screen.",
		Requires = { MinAge = 12, Stats = { Agility = 18 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Frame-Perfect Shunpo", Description = "x1.6 Agility XP, much easier escapes, x1.3 passive Reiatsu.",
			Buffs = { StatXp = { Agility = 1.6 }, FleeBonus = 0.15, PassiveQiMult = 1.3 } },
		Quests = {
			{ Name = "Beat the High Score", Description = "Agility 30.", Requires = { Stats = { Agility = 30 } }, Loyalty = 20 },
			{ Name = "Win Street Fights", Description = "Win five fights.", Requires = { Counters = { Fights = 5 } }, Loyalty = 20 },
			{ Name = "Play Every Game", Description = "Play 5 minigames.", Requires = { Counters = { Minigames = 5 } }, Loyalty = 25 },
		},
	},
	{
		Id = "retired_lieutenant", Name = "The Retired Lieutenant", Title = "Tea House Owner", Sect = "Former Gotei Officer", Discipline = "Sword",
		Color = Color3.fromRGB(200, 170, 120), Regions = { "inner_rukon" },
		Description = "Runs a tea house in the first district. Keeps a sword under the counter.",
		Requires = { MinAge = 14, Stats = { Strength = 18 }, MinAlignment = 0 },
		TechniqueLoyalty = 60,
		Technique = { Name = "Tea House Kendo", Description = "x1.6 Zanjutsu XP, x1.4 Reiatsu.",
			Buffs = { ProficiencyXp = { Sword = 1.6 }, QiMult = 1.4 } },
		Quests = {
			{ Name = "Clean the Tea House", Description = "Win the regulars' respect.", Requires = { Friends = { Count = 2, Affection = 50 } }, Loyalty = 20 },
			{ Name = "Spar at Dawn", Description = "Zanjutsu proficiency 15.", Requires = { Proficiency = { Sword = 15 } }, Loyalty = 20 },
			{ Name = "Protect the District", Description = "Purify five Hollows.", Requires = { Counters = { Battles = 5 } }, Loyalty = 25 },
		},
	},
	{
		Id = "archive_keeper", Name = "The Blind Archivist", Title = "Keeper of Forbidden Scrolls", Sect = "Kido Corps Archive", Discipline = "Kido",
		Color = Color3.fromRGB(150, 160, 255), Regions = { "kido_hall" },
		Description = "Cannot see a single page. Knows every incantation by heart.",
		Requires = { MinRealm = 3, Stats = { Intelligence = 35 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Thousand-Scroll Memory", Description = "x1.8 Intelligence XP, +15% Kido damage, x1.4 passive Reiatsu.",
			Buffs = { StatXp = { Intelligence = 1.8 }, MagicDamageMult = 1.15, PassiveQiMult = 1.4 } },
		Quests = {
			{ Name = "Catalogue the Restricted Shelf", Description = "Knowledge 60.", Requires = { Counters = { Knowledge = 60 } }, Loyalty = 20 },
			{ Name = "Chant Without Words", Description = "Kido skill 30.", Requires = { MinSkill = { Magic = 30 } }, Loyalty = 20 },
			{ Name = "Forge a New Incantation", Description = "Forge a Kido.", Requires = { Counters = { Forged = 1 } }, Loyalty = 25 },
		},
	},
	{
		Id = "garden_healer", Name = "The Head Gardener", Title = "Relief Station Elder", Sect = "Fourth Division Gardens", Discipline = "Healing",
		Color = Color3.fromRGB(130, 220, 160), Regions = { "relief_gardens" },
		Description = "Grows the herbs, heals the captains and scolds both.",
		Requires = { MinRealm = 2, Stats = { Intelligence = 25 }, MinAlignment = 10 },
		TechniqueLoyalty = 60,
		Technique = { Name = "Moon-Herb Kaido", Description = "+80 max health, +20 years, x1.5 Reiatsu.",
			Buffs = { MaxHealthBonus = 80, LifespanBonus = 20, QiMult = 1.5 } },
		Quests = {
			{ Name = "Tend the Midnight Garden", Description = "Kaido skill 20.", Requires = { MinSkill = { Medicine = 20 } }, Loyalty = 20 },
			{ Name = "Heal a Captain", Description = "Reach 40 alignment.", Requires = { MinAlignment = 40 }, Loyalty = 20 },
			{ Name = "Fund the Station", Description = "Donate $4K.", Requires = { MinMoney = 4000 }, PayMoney = 4000, Loyalty = 25 },
		},
	},
	{
		Id = "dune_hunter", Name = "The Dune Stalker", Title = "Hollow Bounty Hunter", Sect = "No Division", Discipline = "Hunt",
		Color = Color3.fromRGB(230, 225, 210), Regions = { "menos_sands", "hollow_wastes" },
		Description = "Has hunted Menos in Hueco Mundo for two hundred years. Talks to nobody.",
		Requires = { MinRealm = 4, Stats = { Strength = 30, Vitality = 25 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Menos Hunter's Instinct", Description = "x2 Reiatsu, +20% Hollow-hunt rewards, +60 max HP.",
			Buffs = { QiMult = 2, BattleRewardMult = 1.2, MaxHealthBonus = 60 } },
		Quests = {
			{ Name = "Hunt the Pack", Description = "Win ten Hollow hunts.", Requires = { Counters = { Battles = 10 } }, Loyalty = 20 },
			{ Name = "Fell a Giant", Description = "Slay a Menos.", Requires = { Counters = { Bosses = 1 } }, Loyalty = 20 },
			{ Name = "Survive the Dunes", Description = "Vitality 45.", Requires = { Stats = { Vitality = 45 } }, Loyalty = 25 },
		},
	},
	{
		Id = "frozen_captain", Name = "The Frozen Captain", Title = "Captain Lost in Time", Sect = "Garden of Frozen Petals", Discipline = "Ice",
		Color = Color3.fromRGB(180, 220, 255), Regions = { "frozen_garden" },
		Description = "Froze themselves mid-Bankai centuries ago. Thaws for one hour a year to teach.",
		Requires = { MinRealm = 8, Stats = { QiControl = 70 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Thousand-Year Frost Bankai", Description = "x4 Reiatsu, +10% awakening, +100 years.",
			Buffs = { QiMult = 4, BreakthroughBonus = 0.1, LifespanBonus = 100 } },
		Quests = {
			{ Name = "Wait a Year in the Garden", Description = "Reach age 150.", Requires = { MinAge = 150 }, Loyalty = 20 },
			{ Name = "Freeze Your Doubts", Description = "Reach Spiritual Class 9.", Requires = { MinRealm = 9 }, Loyalty = 20 },
			{ Name = "Master Your Own Blade", Description = "Zanjutsu proficiency 60.", Requires = { Proficiency = { Sword = 60 } }, Loyalty = 25 },
		},
	},
}

-- Where each mentor can be found (World module): "Seek a Mentor" only finds mentors
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
	{ Id = "Outer", Name = "Academy Student", Stipend = 100 },
	{ Id = "Inner", Name = "Unseated Officer", Stipend = 400, Requires = { MasterLoyalty = 30, MinAge = 14 }, TrialChance = 0.6, TrialStat = "Strength" },
	{ Id = "Core", Name = "Seated Officer", Stipend = 1500, Requires = { MasterLoyalty = 60, MinRealm = 2 }, TrialChance = 0.5, TrialStat = "QiControl" },
	{ Id = "Elder", Name = "Lieutenant", Stipend = 5000, Requires = { MasterLoyalty = 90, MinRealm = 3, MinAge = 30 }, TrialChance = 0.4, TrialStat = "QiControl" },
	{ Id = "Patriarch", Name = "Captain", Stipend = 15000, Requires = { MasterLoyalty = 100, MinRealm = 4, MinAge = 50 }, TrialChance = 0.3, TrialStat = "Charisma" },
}
MastersConfig.TrialFailHealth = -15

MastersConfig.ById = {}
for _, master in MastersConfig.List do
	MastersConfig.ById[master.Id] = master
	master.Regions = master.Regions or MastersConfig.Regions[master.Id]
end

return MastersConfig
