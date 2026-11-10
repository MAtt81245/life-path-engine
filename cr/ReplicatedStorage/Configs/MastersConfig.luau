--[[
	Mentors and jujutsu factions. A mentor must first be discovered ("Seek a Mentor" action),
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
		Id = "elder_mo", Name = "The Old Kyoto Swordmaster", Title = "Grade 1 Sword Elder", Sect = "Kyoto Jujutsu High", Discipline = "Cursed Tools",
		Color = Color3.fromRGB(120, 200, 255),
		Description = "A stern elder whose drawn blade cuts curses before they finish forming.",
		Requires = { MinAge = 12, Stats = { Strength = 15, Intelligence = 30 }, MinAlignment = 0 },
		TechniqueLoyalty = 60,
		Technique = { Name = "Simple Domain: Battojutsu", Description = "x1.5 CE, x1.5 passive CE, x2 Cursed Tools XP.",
			Buffs = { QiMult = 1.5, PassiveQiMult = 1.5, ProficiencyXp = { Sword = 2 } } },
		Quests = {
			{ Name = "Clear the Training Hall", Description = "Prove your blade on the cursed corpse dummies.", Requires = { Proficiency = { Sword = 8 } }, Loyalty = 20 },
			{ Name = "Copy the Clan Records", Description = "Study the old techniques of the great clans.", Requires = { Counters = { Knowledge = 25 } }, Loyalty = 20 },
			{ Name = "Tithe to the School", Description = "Donate ¥2K to the school's treasury.", Requires = { MinMoney = 2000 }, PayMoney = 2000, Loyalty = 25 },
		},
	},
	{
		Id = "iron_fist_han", Name = "The Scarred Physical Assassin", Title = "Sorcerer Killer", Sect = "No Faction", Discipline = "Zero-CE Body",
		Color = Color3.fromRGB(250, 160, 100),
		Description = "Born without cursed energy, he hunts sorcerers with nothing but muscle and cursed tools.",
		Requires = { MinAge = 14, Stats = { Strength = 25, Vitality = 20 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Heavenly Pact Physique", Description = "x1.5 Strength & Vitality XP, +100 HP, x1.3 passive CE.",
			Buffs = { StatXp = { Strength = 1.5, Vitality = 1.5 }, MaxHealthBonus = 100, PassiveQiMult = 1.3 } },
		Quests = {
			{ Name = "Carry the Storage Curse", Description = "Haul a living arsenal of cursed tools on your back.", Requires = { Stats = { Strength = 35 } }, Loyalty = 20 },
			{ Name = "Survive the Poison Trial", Description = "Meditate seven nights while your body burns off curse venom.", Requires = { Stats = { Vitality = 30 } }, Loyalty = 20 },
			{ Name = "Collect a Bounty", Description = "Win three real fights first.", Requires = { Counters = { Fights = 3 } }, Loyalty = 25 },
		},
	},
	{
		Id = "scholar_bai", Name = "The Overtime Grade-1 Mentor", Title = "Ratio Technician", Sect = "Tokyo Jujutsu High", Discipline = "Critical Ratio",
		Color = Color3.fromRGB(130, 220, 200),
		Description = "A former salaryman who clocks out at six sharp. Past overtime, his strikes always find the 7:3 weak point.",
		Requires = { Graduated = "HighSchool", Stats = { Intelligence = 40, Charisma = 10 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Ratio: Critical Strike", Description = "x2 Intelligence XP, x1.5 study gains, x1.5 passive CE.",
			Buffs = { StatXp = { Intelligence = 2 }, StudyMult = 1.5, PassiveQiMult = 1.5 } },
		Quests = {
			{ Name = "File the Mission Reports", Description = "Accumulate deep knowledge.", Requires = { Counters = { Knowledge = 60 } }, Loyalty = 20 },
			{ Name = "Earn a Degree", Description = "Graduate from university.", Requires = { Graduated = "University" }, Loyalty = 20 },
			{ Name = "Find the Weak Point", Description = "Out-think a Grade 1 curse.", Requires = { Stats = { Intelligence = 55 } }, Loyalty = 25 },
		},
	},
	{
		Id = "madame_su", Name = "The Best-Friend Boogie Brawler", Title = "Clap-Swap Brother", Sect = "Kyoto Jujutsu High", Discipline = "Black Flash Rhythm",
		Color = Color3.fromRGB(240, 140, 210),
		Description = "He first asks what type of person you like. Answer well and he teaches you Black Flash rhythm and swap tactics.",
		Requires = { MinAge = 16, Stats = { Charisma = 30, Agility = 15 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Boogie Woogie Swap", Description = "x2 Charisma XP, x1.5 affection, +10% social, x1.4 passive CE.",
			Buffs = { StatXp = { Charisma = 2 }, RelationshipMult = 1.5, SocialBonus = 0.1, PassiveQiMult = 1.4 } },
		Quests = {
			{ Name = "Make Best Friends", Description = "Have 4 friends with 60+ affection.", Requires = { Friends = { Count = 4, Affection = 60 } }, Loyalty = 20 },
			{ Name = "Answer the Question", Description = "Tell him your type with total confidence.", Requires = { Stats = { Charisma = 45 } }, Loyalty = 20 },
			{ Name = "Buy Concert Tickets", Description = "Spend ¥5K on his idol's concert.", Requires = { MinMoney = 5000 }, PayMoney = 5000, Loyalty = 25 },
		},
	},
	{
		Id = "blood_lotus", Name = "The Stitched-Brow Curse User", Title = "Curse User", Sect = "Curse User Cabal", Discipline = "Forbidden Curses",
		Color = Color3.fromRGB(230, 70, 90),
		Description = "A thousand years of borrowed bodies. Power at any price, and the price is usually someone else.",
		Requires = { Stats = { QiControl = 25 }, MaxAlignment = -30 },
		TechniqueLoyalty = 60,
		Technique = { Name = "Cursed Spirit Manipulation", Description = "x3 CE, x2 passive CE, -30 years, -5 happiness per year.",
			Buffs = { QiMult = 3, PassiveQiMult = 2, LifespanBonus = -30, HappinessPerYear = -5 } },
		Quests = {
			{ Name = "Embrace the Curse", Description = "Reach -60 alignment.", Requires = { MaxAlignment = -60 }, Loyalty = 20 },
			{ Name = "Swallow a Curse", Description = "Barrier & Domain Arts 15.", Requires = { Proficiency = { QiArts = 15 } }, Loyalty = 20 },
			{ Name = "Prove Your Grade", Description = "Reach Grade 3 Sorcerer.", Requires = { MinRealm = 3 }, Loyalty = 25 },
		},
	},
	{
		Id = "spear_saint_long", Name = "The Immortal Fight-Club Boss", Title = "Jackpot Gambler", Sect = "Underground Fight Club", Discipline = "Taijutsu",
		Color = Color3.fromRGB(255, 200, 110),
		Description = "He runs an illegal fight club and bets everything on every round. When the jackpot hits, he cannot die.",
		Requires = { MinRealm = 2, Stats = { Agility = 30, Strength = 30 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Restless Jackpot Amplification", Description = "x2 Taijutsu XP, x1.5 Agility XP, x1.3 CE, x1.5 passive CE.",
			Buffs = { ProficiencyXp = { Spear = 2 }, StatXp = { Agility = 1.5 }, QiMult = 1.3, PassiveQiMult = 1.5 } },
		Quests = {
			{ Name = "One Thousand Rounds", Description = "Taijutsu 20.", Requires = { Proficiency = { Spear = 20 } }, Loyalty = 20 },
			{ Name = "Fight-Club Brawls", Description = "Win eight fights.", Requires = { Counters = { Fights = 8 } }, Loyalty = 20 },
			{ Name = "Hit the Jackpot", Description = "Reach Grade 3 Sorcerer.", Requires = { MinRealm = 3 }, Loyalty = 25 },
		},
	},
	{
		Id = "sage_ye", Name = "The Blindfolded Honored One", Title = "The Strongest", Sect = "Tokyo Jujutsu High", Discipline = "Limitless",
		Color = Color3.fromRGB(255, 245, 200),
		Description = "Throughout heaven and earth, he alone is the honored one. He teaches only students who amuse him.",
		Requires = { MinRealm = 3, Stats = { QiControl = 50, Intelligence = 50 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Limitless: Hollow Void", Description = "x4 CE, x2 passive CE, +10% grade promotion.",
			Buffs = { QiMult = 4, PassiveQiMult = 2, BreakthroughBonus = 0.1 } },
		Quests = {
			{ Name = "Earn Semi-Grade 2", Description = "Reach Semi-Grade 2 Sorcerer.", Requires = { MinRealm = 4 }, Loyalty = 20 },
			{ Name = "Touch Infinity", Description = "Barrier & Domain Arts 30.", Requires = { Proficiency = { QiArts = 30 } }, Loyalty = 20 },
			{ Name = "See Through the Six Eyes", Description = "Knowledge 120.", Requires = { Counters = { Knowledge = 120 } }, Loyalty = 25 },
		},
	},
	-- Content expansion (2026-11-02): 7 more mentors, one per new region plus a campus teacher.
	{
		Id = "graveyard_monk", Name = "The Cemetery Bell Monk", Title = "Temple Exorcist", Sect = "Hillside Temple", Discipline = "Barrier Arts",
		Color = Color3.fromRGB(170, 180, 200),
		Description = "He rings one bell every night at the cemetery. Weak curses fall asleep before they reach the gate.",
		Requires = { MinAge = 12, Stats = { Vitality = 15, Intelligence = 15 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Bell of Repose", Description = "x1.6 Barrier & Domain Arts XP, +10 years, x1.2 passive CE.",
			Buffs = { ProficiencyXp = { QiArts = 1.6 }, LifespanBonus = 10, PassiveQiMult = 1.2 } },
		Quests = {
			{ Name = "Ring the Night Bell", Description = "Vitality 25.", Requires = { Stats = { Vitality = 25 } }, Loyalty = 20 },
			{ Name = "Copy the Sutras", Description = "Knowledge 30.", Requires = { Counters = { Knowledge = 30 } }, Loyalty = 20 },
			{ Name = "Calm the Obon Swarm", Description = "Win four real fights.", Requires = { Counters = { Fights = 4 } }, Loyalty = 25 },
		},
	},
	{
		Id = "arcade_broker", Name = "The Pawn-Shop Freelancer", Title = "Unlicensed Sorcerer", Sect = "No Faction", Discipline = "Contract Exorcism",
		Color = Color3.fromRGB(240, 150, 200),
		Description = "Runs a pawn shop by day and haunted-house jobs by night. Pays well, asks nothing.",
		Requires = { MinAge = 15, Stats = { Charisma = 20 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Freelance Rates", Description = "x1.4 salary, x1.4 Charisma XP, x1.2 passive CE.",
			Buffs = { SalaryMult = 1.4, StatXp = { Charisma = 1.4 }, PassiveQiMult = 1.2 } },
		Quests = {
			{ Name = "Close a Deal", Description = "Charisma 35.", Requires = { Stats = { Charisma = 35 } }, Loyalty = 20 },
			{ Name = "Pay Your Cut", Description = "Hand over ¥3K.", Requires = { MinMoney = 3000 }, Loyalty = 25, PayMoney = 3000 },
			{ Name = "Make Connections", Description = "Have 3 friends with 50+ affection.", Requires = { Friends = { Count = 3, Affection = 50 } }, Loyalty = 20 },
		},
	},
	{
		Id = "window_chief", Name = "The Chain-Smoking Auxiliary Chief", Title = "Curtain Specialist", Sect = "Window Liaison Office", Discipline = "Curtains",
		Color = Color3.fromRGB(130, 160, 210),
		Description = "Twenty years of raising curtains around other people's fights. She knows every barrier rule by heart.",
		Requires = { MinRealm = 2, Stats = { Intelligence = 30 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Veil Specialist", Description = "x1.4 study gains, x1.5 Barrier & Domain Arts XP, x1.3 passive CE.",
			Buffs = { StudyMult = 1.4, ProficiencyXp = { QiArts = 1.5 }, PassiveQiMult = 1.3 } },
		Quests = {
			{ Name = "File Fifty Reports", Description = "Knowledge 50.", Requires = { Counters = { Knowledge = 50 } }, Loyalty = 20 },
			{ Name = "Hold a Curtain Alone", Description = "Barrier & Domain Arts 15.", Requires = { Proficiency = { QiArts = 15 } }, Loyalty = 20 },
			{ Name = "Pass the Audit", Description = "Intelligence 45.", Requires = { Stats = { Intelligence = 45 } }, Loyalty = 25 },
		},
	},
	{
		Id = "barrier_abbot", Name = "The Thousand-Year Barrier Abbot", Title = "Barrier Master", Sect = "Mountain Barrier Temple", Discipline = "Thousand-Year Barrier",
		Color = Color3.fromRGB(120, 220, 210),
		Description = "He has not left the mountain in sixty years. His barrier has not cracked in a thousand.",
		Requires = { MinRealm = 3, Stats = { QiControl = 40 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Barrier Within a Barrier", Description = "x1.4 CE, x1.5 passive CE, x2 Barrier & Domain Arts XP.",
			Buffs = { QiMult = 1.4, PassiveQiMult = 1.5, ProficiencyXp = { QiArts = 2 } } },
		Quests = {
			{ Name = "Seven Days of Silence", Description = "Intelligence 45.", Requires = { Stats = { Intelligence = 45 } }, Loyalty = 20 },
			{ Name = "Raise Your Own Barrier", Description = "Barrier & Domain Arts 30.", Requires = { Proficiency = { QiArts = 30 } }, Loyalty = 20 },
			{ Name = "Reach Semi-Grade 2", Description = "Reach Semi-Grade 2 Sorcerer.", Requires = { MinRealm = 4 }, Loyalty = 25 },
		},
	},
	{
		Id = "colony_duelist", Name = "The Revived Heian Duelist", Title = "Ancient Sorcerer", Sect = "Colony Players", Discipline = "Ancient Swordplay",
		Color = Color3.fromRGB(210, 110, 240),
		Description = "A sorcerer from a thousand years ago, wearing a stranger's body. He wants a worthy fight, and a worthy student.",
		Requires = { MinRealm = 4, Stats = { Strength = 50 }, Proficiency = { Sword = 30 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Heian Sword Forms", Description = "x2 CE, x1.6 passive CE, x2 Cursed Tools XP.",
			Buffs = { QiMult = 2, PassiveQiMult = 1.6, ProficiencyXp = { Sword = 2 } } },
		Quests = {
			{ Name = "Survive a Colony Night", Description = "Win eight real fights.", Requires = { Counters = { Fights = 8 } }, Loyalty = 20 },
			{ Name = "Match His Blade", Description = "Cursed Tools 50.", Requires = { Proficiency = { Sword = 50 } }, Loyalty = 20 },
			{ Name = "Reach Grade 2", Description = "Reach Grade 2 Sorcerer.", Requires = { MinRealm = 5 }, Loyalty = 25 },
		},
	},
	{
		Id = "coast_grandma", Name = "The Retired Seaside Grade 1", Title = "Retired Sorcerer", Sect = "Retired", Discipline = "Taijutsu",
		Color = Color3.fromRGB(100, 190, 240),
		Description = "A tiny grandmother who sells fish and once punched a Special Grade into the sea.",
		Requires = { MinAge = 14, Stats = { Agility = 20 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Tidebreak Footwork", Description = "x1.6 Taijutsu XP, x1.4 Agility XP, +40 HP, x1.2 passive CE.",
			Buffs = { ProficiencyXp = { Spear = 1.6 }, StatXp = { Agility = 1.4 }, MaxHealthBonus = 40, PassiveQiMult = 1.2 } },
		Quests = {
			{ Name = "Carry the Morning Catch", Description = "Strength 25.", Requires = { Stats = { Strength = 25 } }, Loyalty = 20 },
			{ Name = "Spar in the Surf", Description = "Taijutsu 15.", Requires = { Proficiency = { Spear = 15 } }, Loyalty = 20 },
			{ Name = "Keep Up with Her", Description = "Agility 40.", Requires = { Stats = { Agility = 40 } }, Loyalty = 25 },
		},
	},
	{
		Id = "puppet_teacher", Name = "The Grumpy Puppet Teacher", Title = "Cursed Corpse Maker", Sect = "Tokyo Jujutsu High", Discipline = "Cursed Corpses",
		Color = Color3.fromRGB(200, 150, 120),
		Description = "A stern teacher who knits cursed plush toys between lessons. They punch harder than most students.",
		Requires = { MinAge = 13, Stats = { Intelligence = 20, Charisma = 15 } },
		TechniqueLoyalty = 60,
		Technique = { Name = "Cursed Corpse Companion", Description = "x1.3 Intelligence & Charisma XP, x1.3 affection, x1.3 passive CE.",
			Buffs = { StatXp = { Intelligence = 1.3, Charisma = 1.3 }, RelationshipMult = 1.3, PassiveQiMult = 1.3 } },
		Quests = {
			{ Name = "Beat the Practice Doll", Description = "Strength 20.", Requires = { Stats = { Strength = 20 } }, Loyalty = 20 },
			{ Name = "Knit Your Own Doll", Description = "Intelligence 35.", Requires = { Stats = { Intelligence = 35 } }, Loyalty = 20 },
			{ Name = "Graduate High School", Description = "Graduate from high school.", Requires = { Graduated = "HighSchool" }, Loyalty = 25 },
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
	graveyard_monk = { "hills" },
	arcade_broker = { "arcade" },
	window_chief = { "window_office" },
	barrier_abbot = { "hiei" },
	colony_duelist = { "colony" },
	coast_grandma = { "coast" },
	puppet_teacher = { "crimson" },
}

-- Sect hierarchy while you follow a master (MasterSystem): a yearly stipend per rank;
-- a promotion trial costs 1 action diamond and needs Requires (incl. MasterLoyalty).
-- Chance + 0.5% per level of TrialStat.
MastersConfig.SectRanks = {
	{ Id = "Outer", Name = "Jujutsu Student", Stipend = 100 },
	{ Id = "Inner", Name = "Field Exorcist", Stipend = 400, Requires = { MasterLoyalty = 30, MinAge = 14 }, TrialChance = 0.6, TrialStat = "Strength" },
	{ Id = "Core", Name = "Senior Exorcist", Stipend = 1500, Requires = { MasterLoyalty = 60, MinRealm = 2 }, TrialChance = 0.5, TrialStat = "QiControl" },
	{ Id = "Elder", Name = "Faction Elder", Stipend = 5000, Requires = { MasterLoyalty = 90, MinRealm = 3, MinAge = 30 }, TrialChance = 0.4, TrialStat = "QiControl" },
	{ Id = "Patriarch", Name = "School Principal", Stipend = 15000, Requires = { MasterLoyalty = 100, MinRealm = 4, MinAge = 50 }, TrialChance = 0.3, TrialStat = "Charisma" },
}
MastersConfig.TrialFailHealth = -15

MastersConfig.ById = {}
for _, master in MastersConfig.List do
	MastersConfig.ById[master.Id] = master
	master.Regions = master.Regions or MastersConfig.Regions[master.Id]
end

return MastersConfig
