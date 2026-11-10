--[[
	Game manifest: identifies the game built from this Configs folder and
	selects which engine gameplay modules it uses. The engine (Shared/GamePack)
	reads it; Shared/ContentValidator checks it against the content at startup.

	To build a different game on the same engine, clone the place, give this manifest
	a new Id, change the content modules and UIThemeConfig, and flip the Modules flags
	(e.g. a modern-life game: Cultivation = false, Masters = false).
	A new Id means saves of the previous game are backed up instead of loaded.
]]

return {
	Id = "soul_path_zanpakuto",
	Name = "Soul Path: Zanpakuto Dynasty",
	Version = "0.1.0",
	-- Engine major.minor this game was built for (see GamePack.EngineVersion).
	EngineVersion = "0.3",

	Theme = {
		Genre = "Soul Reaper, Hollow and Quincy spiritual-pressure life simulation",
		Description = "Grow up seeing ghosts in Karakura Town, awaken your Zanpakuto, rise through the Spiritual Classes from the World of the Living to the Soul King's palace, and pass your blade down the generations.",
	},

	-- Engine gameplay modules (see GamePack.Modules for what each one owns). The
	-- "Cultivation" module is the progression engine: here it drives Spiritual Classes.
	Modules = {
		Cultivation = true,
		Education = true,
		Careers = true,
		Masters = true,
		Relationships = true,
		Masteries = true,
		Titles = true,
		Lineages = true,
		NpcAutonomy = true,
		Inventory = true,
		Samsara = true,
		World = true,
		Dynasty = true,
		-- 2.0 engine modules
		Skills = true,
		Arcana = true,
		Character = true,
		Minigames = true,
		Battle = true,
		-- 3.0 engine modules
		Legends = true,
		WorldHub = true,
		Raids = true,
		Goals = true,
	},

	-- Event pools evaluated every birthday. `Module` gates a whole pool.
	EventPools = {
		{ Config = "YearlyEventsConfig" },
		{ Config = "LifeEventsConfig", Module = "Cultivation" },
		{ Config = "TravelEventsConfig", Module = "World" },
	},

	-- Optional interface text, e.g. TabLabels = { Masters = "Mentors" } (keys: GamePack.TabKeys).
	Interface = {
		TabLabels = { Training = "Train & Patrol", Journal = "Soul Record", Family = "Soul Lineage", Lineage = "Senkaimon Rebirth",
			Arcana = "Kido & Zanjutsu" },
		-- Journal counters (3.0) as requirement text shows them.
		CounterNames = {
			Battles = "Hollows purified", Bosses = "Great Hollows slain", Spells = "Kido practiced", Forged = "Kido forged",
			Fusions = "Traits fused", Omens = "Signs read", Minigames = "Minigames played", SkillActions = "Mastery actions",
			Raids = "Raids cleared", Leads = "Relic leads", Thrones = "Seats claimed", BondLevels = "Best bond level",
			Trainings = "Trainings", Socials = "Social actions", Years = "Years lived",
		},
	},

	-- Other libraries this game needs (none yet).
	Dependencies = {},
}
