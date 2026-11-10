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
	Id = "cursed_path_sorcerer",
	Name = "Cursed Path: Sorcerer Lineage",
	Version = "0.1.0",
	-- Engine major.minor this game was built for (see GamePack.EngineVersion).
	EngineVersion = "0.3",

	Theme = {
		Genre = "Occult dark-fantasy sorcerer life simulation",
		Description = "Awaken your cursed energy, rise through the sorcerer grades and carry your clan's techniques across generations.",
	},

	-- Engine gameplay modules (see GamePack.Modules for what each one owns). The
	-- "Cultivation" module is the progression engine: here it drives Sorcerer Grades.
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
	},

	-- Event pools evaluated every birthday. `Module` gates a whole pool.
	EventPools = {
		{ Config = "YearlyEventsConfig" },
		{ Config = "LifeEventsConfig", Module = "Cultivation" },
		{ Config = "TravelEventsConfig", Module = "World" },
	},

	-- Optional interface text, e.g. TabLabels = { Masters = "Mentors" } (keys: GamePack.TabKeys).
	Interface = {
		TabLabels = { Training = "Missions & Train", Journal = "Case File", Family = "Clan Tree", Lineage = "Reincarnation" },
	},

	-- Other libraries this game needs (none yet).
	Dependencies = {},
}
