--[[
	Yearly actions. Every year the character gets a few Action Slots (BitLife-style);
	each action costs Slots (default 1) and may be repeated at most MaxPerYear times
	(default DefaultMaxPerYear), so every year is a real choice.

	Free slots per year = BaseActionSlots + Temporal Awareness + stat peak
	  (PlayerStatsConfig.ActionBonus) + realm passive (RealmsConfig ActionSlots) + age
	  windows (SlotBonuses) + the ActionSlots buff, capped at FreeActionCap; golden
	  slots from game passes come on top, up to MaxActionSlots.
	Consumables and events can add slots for the current year (effect Actions).

	Action fields:
		Slots, MaxPerYear, MinAge, MaxAge, Page ("Training" or "Study")
		Requires                         -> Shared/Requirements spec (e.g. the Spirit Root flag)
		Actions outside their age window are hidden in the UI (progressive disclosure).
		StatXp = { Stat = xp }            -> base XP (multiplied by buffs and mood)
		Proficiency, ProficiencyXp       -> weapon / power mastery
		QiFraction                       -> Qi gained as a fraction of the current breakthrough requirement
		Health, Stress, Happiness        -> flat changes
		Knowledge                        -> knowledge points (unlock event choices)
		MeetChance                       -> chance to make a new friend
		SeekMaster                       -> searches for an undiscovered master
		RequiresEnrolled / RequiresJob   -> only while studying / employed
		Module                           -> engine module that must be enabled (see Shared/GamePack)
		Performance / JobPerformance     -> grades / job performance
		SalaryFraction                   -> bonus pay as a fraction of yearly salary
]]

local TrainingConfig = {}

-- A new save starts with 2 diamonds; Temporal Awareness (Karma) and other bonuses
-- raise the free slots to FreeActionCap; golden pass diamonds go up to MaxActionSlots.
TrainingConfig.BaseActionSlots = 2
TrainingConfig.FreeActionCap = 4
TrainingConfig.MaxActionSlots = 6
TrainingConfig.DefaultMaxPerYear = 2
TrainingConfig.SlotBonuses = {}

TrainingConfig.ProficiencyOrder = { "Sword", "Spear", "QiArts" }
TrainingConfig.Proficiencies = {
	Sword = { Name = "Zanjutsu", Color = Color3.fromRGB(56, 189, 248) },
	Spear = { Name = "Hakuda & Hoho", Short = "Hakuda/Hoho", Color = Color3.fromRGB(249, 115, 22) },
	QiArts = { Name = "Kido & Cero Arts", Short = "Kido Arts", Color = Color3.fromRGB(165, 180, 252) },
}
-- Short (optional): compact name for action cards and the proficiency list.

TrainingConfig.Actions = {
	{ Id = "CrawlPlay", Name = "See Friendly Ghosts", Description = "Wave at the friendly ghosts in the park that nobody else can see.", MinAge = 0, MaxAge = 3,
		StatXp = { Agility = 6, Vitality = 5 }, Happiness = 5 },
	{ Id = "ListenParents", Name = "Comfort a Ghost Child", Description = "Sing to the little ghost who cries by the river every evening.", MinAge = 0, MaxAge = 3,
		StatXp = { Intelligence = 7, Charisma = 5 }, Happiness = 3 },
	{ Id = "PhysicalTraining", Name = "Karate Dojo Practice", Description = "Kicks, punches and falls at the neighborhood karate dojo.", MinAge = 7,
		StatXp = { Strength = 14, Agility = 9, Vitality = 4 }, Health = -3, Stress = 4 },
	{ Id = "ReadBooks", Name = "Help at Family Clinic", Description = "Sort bandages, read medical books and listen to patients. Knowledge unlocks event choices.", MinAge = 4,
		StatXp = { Intelligence = 16 }, Stress = 2, Knowledge = 1 },
	{ Id = "PracticeSword", Name = "Kendo & Zanjutsu", Description = "Kendo club by day, real swordwork by night.", MinAge = 12,
		Proficiency = "Sword", ProficiencyXp = 16, StatXp = { Agility = 6 }, Stress = 3 },
	{ Id = "PracticeSpear", Name = "Hakuda & Flash Step", Description = "Bare-handed forms and short bursts of Hoho speed.", MinAge = 12,
		Proficiency = "Spear", ProficiencyXp = 16, StatXp = { Strength = 6 }, Stress = 3 },
	{ Id = "PracticeQiArts", Name = "Kido Incantations", Description = "Chant Bakudo and Hado until the reishi obeys you.", MinAge = 12,
		Proficiency = "QiArts", ProficiencyXp = 16, StatXp = { QiControl = 8 }, Stress = 3 },
	{ Id = "Meditate", Name = "Inner World Meditation", Description = "Meditate in your inner world and listen for your Zanpakuto's voice.", MinAge = 6,
		Requires = { Flag = "SpiritRoot" },
		QiFraction = 1 / 6, StatXp = { QiControl = 6 }, Stress = -4, Module = "Cultivation" },
	-- 2.0: Zanjutsu, Fighting Reiatsu and Kido training (Skills / Arcana modules).
	{ Id = "SwordDrills", Name = "Zanjutsu Drills", Description = "Stances and cuts until your arms burn.", MinAge = 8, Prodigy = true,
		StatXp = { Strength = 6, BattleAura = 10 }, Proficiency = "Sword", ProficiencyXp = 8, SkillXp = { Swordsmanship = 12 }, Health = -2, Stress = 3, Module = "Skills" },
	{ Id = "AuraBreathing", Name = "Reiatsu Breathing", Description = "Wrap your body in spiritual pressure.", MinAge = 10, Prodigy = true,
		StatXp = { AuraPotential = 8, BattleAura = 6 }, SkillXp = { Swordsmanship = 6 }, Stress = -2, Module = "Skills" },
	{ Id = "ManaMeditation", Name = "Reiryoku Meditation", Description = "Feel the reishi move under your skin.", MinAge = 8, Prodigy = true,
		StatXp = { Mana = 10, MagicControl = 6 }, SkillXp = { Magic = 8 }, Stress = -3, Module = "Arcana" },
	{ Id = "SpellTomes", Name = "Study Kido Scrolls", Description = "Incantations, circles and theory.", MinAge = 6,
		StatXp = { Intelligence = 6, MagicPower = 8 }, SkillXp = { Magic = 4, Knowledge = 6 }, Stress = 2, Module = "Arcana" },
	{ Id = "Socialize", Name = "Meet People", Description = "Hang out around Karakura Town.", MinAge = 4, MaxPerYear = 1,
		StatXp = { Charisma = 12 }, Happiness = 4, MeetChance = 0.35 },
	{ Id = "Relax", Name = "Rest", Description = "Rest, play and let your spiritual pressure settle.", MinAge = 0, MaxPerYear = 1,
		Stress = -15, Happiness = 6, Health = 4 },
	{ Id = "SeekMaster", Name = "Seek a Mentor", Description = "Search for someone strong enough to teach you.", MinAge = 12, MaxPerYear = 1,
		SeekMaster = true, Stress = 2, Module = "Masters" },
	{ Id = "StudyHard", Name = "Study Hard", Page = "Study", Description = "Hit the books for better grades.", MinAge = 3, MaxPerYear = 1,
		RequiresEnrolled = true, Performance = 12, StatXp = { Intelligence = 10 }, Stress = 5, Module = "Education" },
	{ Id = "WorkOvertime", Name = "Work Overtime", Page = "Study", Description = "Impress your boss and earn a bonus.", MinAge = 16, MaxPerYear = 1,
		RequiresJob = true, JobPerformance = 10, SalaryFraction = 0.1, Stress = 7, Module = "Careers" },
	-- Content expansion (2026-11-02): 17 more actions.
	{ Id = "BlockTower", Name = "Stack Blocks", Description = "Build towers and knock them down.", MinAge = 2, MaxAge = 4,
		StatXp = { Intelligence = 5, Agility = 5 }, Happiness = 4 },
	{ Id = "ChaseButterflies", Name = "Chase Butterflies", Description = "Run through the garden after anything that flutters.", MinAge = 2, MaxAge = 6,
		StatXp = { Agility = 8, Vitality = 4 }, Happiness = 5 },
	{ Id = "ChoresAtHome", Name = "Help with Chores", Description = "Carry water, sweep the yard, feed the chickens.", MinAge = 5, MaxAge = 15, MaxPerYear = 1,
		StatXp = { Strength = 8, Vitality = 6 }, Stress = 2, SkillXp = { Fitness = 4 } },
	{ Id = "Calligraphy", Name = "Calligraphy", Description = "A thousand strokes of the same character.", MinAge = 6,
		StatXp = { Intelligence = 8, Agility = 5 }, Stress = -2, SkillXp = { Knowledge = 4, Crafting = 3 } },
	{ Id = "Horseback", Name = "Bike Riding", Description = "Learn to ride, then learn to fall.", MinAge = 9,
		StatXp = { Agility = 10, Strength = 4 }, Health = -2, Stress = 2, SkillXp = { Exploration = 6 } },
	{ Id = "MountainRun", Name = "Shrine Stair Sprint", Description = "Up the thousand shrine steps and down again.", MinAge = 10,
		StatXp = { Vitality = 14, Agility = 4 }, Health = -2, Stress = 3, SkillXp = { Fitness = 8 } },
	{ Id = "WeightStones", Name = "Stone Lifting", Description = "Lift river stones until your back complains.", MinAge = 11,
		StatXp = { Strength = 15, Vitality = 4 }, Health = -3, Stress = 4, SkillXp = { Fitness = 6 } },
	{ Id = "IronPalm", Name = "Hakuda Palm Strikes", Description = "Strike the training post until your palms turn to iron.", MinAge = 13,
		Proficiency = "QiArts", ProficiencyXp = 10, StatXp = { Strength = 8 }, Health = -3, Stress = 3 },
	{ Id = "SpearForms", Name = "Hoho Footwork Forms", Description = "Slow footwork forms until every step is silent.", MinAge = 13,
		Proficiency = "Spear", ProficiencyXp = 10, StatXp = { Agility = 5, Vitality = 4 }, Stress = 2 },
	{ Id = "ShadowSparring", Name = "Shadow Sparring", Description = "Fight an imaginary opponent who never tires.", MinAge = 12,
		Proficiency = "Sword", ProficiencyXp = 10, StatXp = { Agility = 7 }, Stress = 2 },
	{ Id = "HerbGathering", Name = "Gather Herbs", Description = "Comb the hills for medicinal roots.", MinAge = 8, MaxPerYear = 1,
		StatXp = { Intelligence = 6, Vitality = 4 }, SkillXp = { Medicine = 8, Survival = 4 }, Stress = -2 },
	{ Id = "MarketHaggling", Name = "Haggle on the Shopping Street", Description = "Buy low, sell high, smile always.", MinAge = 10, MaxPerYear = 1,
		StatXp = { Charisma = 9, Intelligence = 4 }, SkillXp = { Trade = 8 } },
	{ Id = "TempleService", Name = "Shrine Service", Description = "Sweep the shrine and ring the Konso bell.", MinAge = 6, MaxPerYear = 1,
		StatXp = { QiControl = 4, Charisma = 4 }, SkillXp = { Faith = 8 }, Stress = -6 },
	{ Id = "StarGazing", Name = "Star Gazing", Description = "Map the constellations and wonder.", MinAge = 6, MaxPerYear = 1,
		StatXp = { Intelligence = 6, Luck = 4 }, Stress = -5, Happiness = 3 },
	{ Id = "WaterfallTraining", Name = "Waterfall Jinzen", Description = "Sit beneath freezing water and hold your Reiatsu.", MinAge = 14,
		Requires = { Flag = "SpiritRoot" },
		QiFraction = 1 / 8, StatXp = { Vitality = 6, QiControl = 4 }, Health = -3, Stress = 2, Module = "Cultivation" },
	{ Id = "ElementalAttunement", Name = "Kido Attunement", Description = "Hold a candle, a cup and a stone until the reishi in them answers.", MinAge = 9, Prodigy = true,
		StatXp = { MagicControl = 8, Mana = 4 }, SkillXp = { Magic = 6 }, Stress = 1, Module = "Arcana" },
	{ Id = "StreetPerformance", Name = "Street Performance", Description = "Juggle, sing or tell stories for coins.", MinAge = 10, MaxPerYear = 1,
		StatXp = { Charisma = 10, Agility = 3 }, Happiness = 4, MeetChance = 0.2 },
}

TrainingConfig.ById = {}
for _, action in TrainingConfig.Actions do
	action.Page = action.Page or "Training"
	action.Slots = action.Slots or 1
	TrainingConfig.ById[action.Id] = action
end

return TrainingConfig
