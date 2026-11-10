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
	Sword = { Name = "Cursed Tools", Color = Color3.fromRGB(225, 29, 72) },
	Spear = { Name = "Taijutsu", Color = Color3.fromRGB(245, 158, 11) },
	QiArts = { Name = "Barrier & Domain Arts", Short = "Barrier Arts", Color = Color3.fromRGB(157, 78, 221) },
}
-- Short (optional): compact name for action cards and the proficiency list.

TrainingConfig.Actions = {
	{ Id = "CrawlPlay", Name = "Sense Invisible Curses", Description = "Crawl after the shapes nobody else can see.", MinAge = 0, MaxAge = 3,
		StatXp = { Agility = 6, Vitality = 5 }, Happiness = 5 },
	{ Id = "ListenParents", Name = "Cursed Bear Movie Night", Description = "Action movies with a plush cursed corpse that punches you if you doze off.", MinAge = 0, MaxAge = 3,
		StatXp = { Intelligence = 7, Charisma = 5 }, Happiness = 3 },
	{ Id = "PhysicalTraining", Name = "Dojo Training", Description = "Run, punch and spar at the family dojo until your body can keep up with your eyes.", MinAge = 7,
		StatXp = { Strength = 14, Agility = 9, Vitality = 4 }, Health = -3, Stress = 4 },
	{ Id = "ReadBooks", Name = "Study Jujutsu Theory", Description = "Picture books, school lessons and old clan scrolls. Knowledge unlocks event choices.", MinAge = 4,
		StatXp = { Intelligence = 16 }, Stress = 2, Knowledge = 1 },
	{ Id = "PracticeSword", Name = "Cursed Tool Drills", Description = "Swing a cursed tool until it answers you.", MinAge = 12,
		Proficiency = "Sword", ProficiencyXp = 16, StatXp = { Agility = 6 }, Stress = 3 },
	{ Id = "PracticeSpear", Name = "Taijutsu Sparring", Description = "Bare-handed bouts that harden body and instinct.", MinAge = 12,
		Proficiency = "Spear", ProficiencyXp = 16, StatXp = { Strength = 6 }, Stress = 3 },
	{ Id = "PracticeQiArts", Name = "Barrier Studies", Description = "Shape cursed energy into veils, barriers and domains.", MinAge = 12,
		Proficiency = "QiArts", ProficiencyXp = 16, StatXp = { QiControl = 8 }, Stress = 3 },
	{ Id = "Meditate", Name = "Core CE Meditation", Description = "Meditate on the core of your cursed energy and steady your emotions.", MinAge = 6,
		Requires = { Flag = "SpiritRoot" },
		QiFraction = 1 / 6, StatXp = { QiControl = 6 }, Stress = -4, Module = "Cultivation" },
	{ Id = "Socialize", Name = "Meet People", Description = "Hang out in town.", MinAge = 4, MaxPerYear = 1,
		StatXp = { Charisma = 12 }, Happiness = 4, MeetChance = 0.35 },
	{ Id = "Relax", Name = "Rest", Description = "Rest, play and let your cursed energy settle.", MinAge = 0, MaxPerYear = 1,
		Stress = -15, Happiness = 6, Health = 4 },
	{ Id = "SeekMaster", Name = "Seek a Mentor", Description = "Search for a sorcerer willing to teach you.", MinAge = 12, MaxPerYear = 1,
		SeekMaster = true, Stress = 2, Module = "Masters" },
	{ Id = "StudyHard", Name = "Study Hard", Page = "Study", Description = "Hit the books for better grades.", MinAge = 3, MaxPerYear = 1,
		RequiresEnrolled = true, Performance = 12, StatXp = { Intelligence = 10 }, Stress = 5, Module = "Education" },
	{ Id = "WorkOvertime", Name = "Work Overtime", Page = "Study", Description = "Impress your boss and earn a bonus.", MinAge = 16, MaxPerYear = 1,
		RequiresJob = true, JobPerformance = 10, SalaryFraction = 0.1, Stress = 7, Module = "Careers" },
	-- Content expansion (2026-11-02): 13 more actions.
	{ Id = "BlockTower", Name = "Stack Blocks", Description = "Build towers and knock them down before the little curses can.", MinAge = 2, MaxAge = 4,
		StatXp = { Intelligence = 5, Agility = 5 }, Happiness = 4 },
	{ Id = "HideAndSeek", Name = "Hide and Seek", Description = "Hide from your siblings, and from the things only you can see.", MinAge = 3, MaxAge = 8,
		StatXp = { Agility = 8, Charisma = 3 }, Happiness = 5 },
	{ Id = "ChoresAtHome", Name = "Help at the Family Shop", Description = "Stack boxes, sweep the floor and run deliveries.", MinAge = 6, MaxAge = 15, MaxPerYear = 1,
		StatXp = { Strength = 8, Vitality = 6 }, Stress = 2 },
	{ Id = "BaseballPractice", Name = "Baseball Practice", Description = "Batting cages after school. Good for swings of every kind.", MinAge = 8,
		StatXp = { Strength = 8, Agility = 8 }, Health = -1, Stress = 1 },
	{ Id = "Parkour", Name = "Rooftop Parkour", Description = "Jump between rooftops like the sorcerers you saw as a kid.", MinAge = 11,
		StatXp = { Agility = 14, Vitality = 4 }, Health = -3, Stress = 3 },
	{ Id = "StairRuns", Name = "Shrine Stair Runs", Description = "Up the thousand shrine steps and down again.", MinAge = 10,
		StatXp = { Vitality = 14, Agility = 4 }, Health = -2, Stress = 3 },
	{ Id = "CursedCorpseSpar", Name = "Cursed Corpse Sparring", Description = "Spar with a stitched plush that hits back when you lose focus.", MinAge = 12,
		Proficiency = "Spear", ProficiencyXp = 10, StatXp = { Strength = 6, QiControl = 4 }, Health = -3, Stress = 3 },
	{ Id = "MovieFocus", Name = "Hold CE Through a Movie", Description = "Keep your cursed energy steady through three films without a flicker.", MinAge = 12,
		Requires = { Flag = "SpiritRoot" }, StatXp = { QiControl = 10, Intelligence = 4 }, Stress = 2 },
	{ Id = "TalismanBrushwork", Name = "Talisman Brushwork", Description = "Paint seals until every stroke holds cursed energy.", MinAge = 10,
		Proficiency = "QiArts", ProficiencyXp = 10, StatXp = { Intelligence = 6 }, Stress = 1 },
	{ Id = "ToolMaintenance", Name = "Cursed Tool Upkeep", Description = "Sharpen, polish and re-seal a cursed tool. It likes the attention.", MinAge = 13,
		Proficiency = "Sword", ProficiencyXp = 10, StatXp = { Intelligence = 4, Agility = 3 }, Stress = 1 },
	{ Id = "PatrolNight", Name = "Night Patrol", Description = "Walk the streets after midnight and exorcise anything small.", MinAge = 14, MaxPerYear = 1,
		Requires = { Flag = "SpiritRoot" }, StatXp = { Strength = 8, Agility = 6, QiControl = 6 }, Health = -4, Stress = 4, Knowledge = 1 },
	{ Id = "Karaoke", Name = "Karaoke Night", Description = "Sing badly with friends until sunrise.", MinAge = 13, MaxPerYear = 1,
		StatXp = { Charisma = 10 }, Happiness = 6, Stress = -6, MeetChance = 0.2 },
	{ Id = "WombStudy", Name = "Study Cursed Wombs", Description = "Watch a sealed cursed womb pulse and learn how curses are born.", MinAge = 15,
		Requires = { Flag = "SpiritRoot", MinRealm = 2 }, QiFraction = 1 / 12, StatXp = { Intelligence = 6 }, Stress = 3, Module = "Cultivation" },
}

TrainingConfig.ById = {}
for _, action in TrainingConfig.Actions do
	action.Page = action.Page or "Training"
	action.Slots = action.Slots or 1
	TrainingConfig.ById[action.Id] = action
end

return TrainingConfig
