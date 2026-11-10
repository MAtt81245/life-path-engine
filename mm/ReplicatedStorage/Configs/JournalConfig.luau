--[[
	JournalConfig: the Adventurer's Journal (Modules/JournalSystem, Goals tab).

	LoginRewards  a 7-day streak (claimed once per real day; missing a day restarts it).
	              Reward keys: Money, Karma, Item, Ticket (raid ticket).
	Daily         DailyCount quests a day from DailyPool (the same for everyone that day);
	              all done = DailyReward meta currency. Counter = a journal counter.
	Counters      journal counters (per life, in state.Counters, shown with CounterNames)
	              fed by the systems: battles, bosses, spells, forged, fusions, omens...
	LifeGoals     86 goals per life (Shared/Requirements specs), reset every life.
]]

local JournalConfig = {}

JournalConfig.LoginRewards = {
	{ Money = 100 }, { Ticket = 1 }, { Money = 250 }, { Item = "magic_crystal" },
	{ Karma = 5 }, { Item = "focus_tonic" }, { Karma = 20, Money = 500 },
}

JournalConfig.DailyCount = 3
JournalConfig.DailyReward = 1
JournalConfig.DailyPool = {
	{ Id = "train", Text = "Train twice", Counter = "Trainings", Need = 2 },
	{ Id = "battle", Text = "Win a battle", Counter = "Battles", Need = 1 },
	{ Id = "omen", Text = "Read today's omen", Counter = "Omens", Need = 1 },
	{ Id = "spells", Text = "Practice 3 spells", Counter = "Spells", Need = 3 },
	{ Id = "social", Text = "Spend a social action", Counter = "Socials", Need = 1 },
	{ Id = "years", Text = "Live through 2 years", Counter = "Years", Need = 2 },
	{ Id = "mastery", Text = "Do a skill mastery action", Counter = "SkillActions", Need = 1 },
	{ Id = "game", Text = "Play a minigame", Counter = "Minigames", Need = 1 },
	-- Content expansion (2026-11-02): 8 more daily quests.
	{ Id = "train4", Text = "Train four times", Counter = "Trainings", Need = 4 },
	{ Id = "battle3", Text = "Win 3 battles", Counter = "Battles", Need = 3 },
	{ Id = "spells6", Text = "Practice 6 spells", Counter = "Spells", Need = 6 },
	{ Id = "social3", Text = "Spend 3 social actions", Counter = "Socials", Need = 3 },
	{ Id = "years5", Text = "Live through 5 years", Counter = "Years", Need = 5 },
	{ Id = "mastery3", Text = "Do 3 skill mastery actions", Counter = "SkillActions", Need = 3 },
	{ Id = "boss", Text = "Slay a boss", Counter = "Bosses", Need = 1 },
	{ Id = "forge", Text = "Forge a spell", Counter = "Forged", Need = 1 },
}

-- SkillSystem.Count / other hooks -> journal counter.
JournalConfig.CounterMap = {
	spells_cast = "Spells", skill_actions = "SkillActions", battles_won = "Battles", minigames = "Minigames",
	forged = "Forged", fusions = "Fusions", raids = "Raids", leads = "Leads", thrones = "Thrones", bosses = "Bosses",
	train = "Trainings", social = "Socials", years = "Years", omens = "Omens", BondLevels = "BondLevels",
}
JournalConfig.CounterNames = {
	Battles = "Battles won", Bosses = "Bosses slain", Spells = "Spells practiced", Forged = "Spells forged",
	Fusions = "Traits fused", Omens = "Omens read", Minigames = "Minigames played", SkillActions = "Mastery actions",
	Raids = "Raids cleared", Leads = "Relic leads", Thrones = "Thrones claimed", BondLevels = "Best bond level",
	Trainings = "Trainings", Socials = "Social actions", Years = "Years lived",
}

local function goal(text, requires) return { Text = text, Requires = requires } end
JournalConfig.LifeGoals = {
	goal("Say your first word", { MinAge = 1 }), goal("Reach school age", { MinAge = 6 }), goal("Become a teenager", { MinAge = 13 }),
	goal("Come of age", { MinAge = 18 }), goal("Reach 30", { MinAge = 30 }), goal("Reach 50", { MinAge = 50 }),
	goal("Grow old (70)", { MinAge = 70 }), goal("Live to 90", { MinAge = 90 }),
	goal("Finish primary school", { Graduated = "PrimarySchool" }), goal("Finish high school", { Graduated = "HighSchool" }),
	goal("Graduate university", { Graduated = "University" }), goal("Get your first job", { Employed = true }),
	goal("Save 10,000", { MinMoney = 10000 }), goal("Become wealthy (100,000)", { MinMoney = 100000 }),
	goal("Marry", { Flag = "Married" }), goal("Have a child", { HasRelationship = "Child" }),
	goal("Make 3 good friends", { Friends = { Count = 3, Affection = 60 } }), goal("Find a master", { HasMaster = true }),
	goal("Break through once", { MinRealm = 2 }), goal("Reach the fourth realm", { MinRealm = 4 }),
	goal("Win your first battle", { Counters = { Battles = 1 } }), goal("Win 10 battles", { Counters = { Battles = 10 } }),
	goal("Slay a boss", { Counters = { Bosses = 1 } }), goal("Practice 10 spells", { Counters = { Spells = 10 } }),
	goal("Reach Intermediate Magic", { MinSkill = { Magic = 15 } }), goal("Reach Intermediate Swordsmanship", { MinSkill = { Swordsmanship = 15 } }),
	goal("Reach Advanced Knowledge", { MinSkill = { Knowledge = 30 } }), goal("Do 3 mastery actions", { Counters = { SkillActions = 3 } }),
	goal("Read 3 omens", { Counters = { Omens = 3 } }), goal("Play 2 minigames", { Counters = { Minigames = 2 } }),
	goal("Strength 25", { Stats = { Strength = 25 } }), goal("Intelligence 25", { Stats = { Intelligence = 25 } }),
	goal("Charisma 25", { Stats = { Charisma = 25 } }), goal("Walk the Hero's path", { MinAlignment = 10 }),
	goal("Walk the Villain's path", { MaxAlignment = -8 }), goal("Become brave", { Personality = { Bravery = 50 } }),
	goal("Become kind", { Personality = { Kindness = 50 } }), goal("Fuse two traits", { Counters = { Fusions = 1 } }),
	goal("Forge a spell", { Counters = { Forged = 1 } }), goal("Reach bond level 3 with someone", { Counters = { BondLevels = 3 } }),
	goal("Clear a raid", { Counters = { Raids = 1 } }), goal("Find a relic lead", { Counters = { Leads = 1 } }),
	goal("Claim one of the Seven Thrones", { Counters = { Thrones = 1 } }),
	-- Content expansion (2026-11-02): 43 more goals.
	goal("Reach 15", { MinAge = 15 }), goal("Reach 40", { MinAge = 40 }), goal("Reach 60", { MinAge = 60 }),
	goal("Live to 100", { MinAge = 100 }), goal("Live to 150", { MinAge = 150 }), goal("Live to 300", { MinAge = 300 }),
	goal("Finish kindergarten", { Graduated = "Kindergarten" }), goal("Earn a graduate degree", { Graduated = "Graduate" }),
	goal("Graduate with honors", { Honors = "HighSchool" }), goal("Save 1,000", { MinMoney = 1000 }),
	goal("Save 5,000", { MinMoney = 5000 }), goal("Become rich (1,000,000)", { MinMoney = 1000000 }),
	goal("Make a friend", { Friends = { Count = 1, Affection = 50 } }), goal("Make 5 close friends", { Friends = { Count = 5, Affection = 70 } }),
	goal("Break through twice", { MinRealm = 3 }), goal("Reach the sixth realm", { MinRealm = 6 }),
	goal("Reach the eighth realm", { MinRealm = 8 }), goal("Win 25 battles", { Counters = { Battles = 25 } }),
	goal("Win 50 battles", { Counters = { Battles = 50 } }), goal("Slay 3 bosses", { Counters = { Bosses = 3 } }),
	goal("Practice 50 spells", { Counters = { Spells = 50 } }), goal("Forge 3 spells", { Counters = { Forged = 3 } }),
	goal("Fuse 3 traits", { Counters = { Fusions = 3 } }), goal("Read 10 omens", { Counters = { Omens = 10 } }),
	goal("Play 10 minigames", { Counters = { Minigames = 10 } }), goal("Do 15 mastery actions", { Counters = { SkillActions = 15 } }),
	goal("Clear 3 raids", { Counters = { Raids = 3 } }), goal("Find 3 relic leads", { Counters = { Leads = 3 } }),
	goal("Reach bond level 5 with someone", { Counters = { BondLevels = 5 } }), goal("Win 5 street fights", { Counters = { Fights = 5 } }),
	goal("Read deeply (Knowledge counter 10)", { Counters = { Knowledge = 10 } }), goal("Reach Advanced Magic", { MinSkill = { Magic = 30 } }),
	goal("Reach Advanced Swordsmanship", { MinSkill = { Swordsmanship = 30 } }), goal("Reach Advanced Medicine", { MinSkill = { Medicine = 30 } }),
	goal("Reach Advanced Trade", { MinSkill = { Trade = 30 } }), goal("Reach Advanced Exploration", { MinSkill = { Exploration = 30 } }),
	goal("Agility 25", { Stats = { Agility = 25 } }), goal("Vitality 25", { Stats = { Vitality = 25 } }),
	goal("Strength 50", { Stats = { Strength = 50 } }), goal("Intelligence 50", { Stats = { Intelligence = 50 } }),
	goal("Become a Saint (alignment 80)", { MinAlignment = 80 }), goal("Become honest", { Personality = { Honesty = 50 } }),
	goal("Become patient", { Personality = { Patience = 50 } }),
}
for i, entry in JournalConfig.LifeGoals do
	entry.Id = "goal" .. i
end

return JournalConfig
