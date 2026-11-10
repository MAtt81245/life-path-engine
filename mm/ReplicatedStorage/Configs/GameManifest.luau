--[[
	Game pack manifest: identifies the game built from this Configs folder and
	selects which engine gameplay modules it uses. The engine (Shared/GamePack)
	reads it; Shared/ContentValidator checks it against the content at startup.

	To build a different game on the same engine, change the content modules and
	flip the Modules flags (e.g. a modern-life game: Cultivation = false, Masters = false).
]]

return {
	Id = "life_path_xianxia",
	Name = "Life Path: Chasing Immortality",
	Version = "1.0.0",
	-- Engine major.minor this pack was built for (see GamePack.EngineVersion).
	EngineVersion = "0.3",

	Theme = {
		Genre = "Xianxia life simulation",
		Description = "Live, study, love and cultivate toward immortality, one year at a time.",
	},

	-- Engine gameplay modules (see GamePack.Modules for what each one owns).
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
		-- Journal counters (3.0) as requirement text shows them.
		CounterNames = {
			Battles = "Battles won", Bosses = "Bosses slain", Spells = "Spells practiced", Forged = "Spells forged",
			Fusions = "Traits fused", Omens = "Omens read", Minigames = "Minigames played", SkillActions = "Mastery actions",
			Raids = "Raids cleared", Leads = "Relic leads", Thrones = "Thrones claimed", BondLevels = "Best bond level",
			Trainings = "Trainings", Socials = "Social actions", Years = "Years lived",
		},
	},

	-- Other packs or libraries this pack needs (none yet). A pack in GamePacks can
	-- also set `Extends = "<packId>"` to inherit that pack's content overrides.
	Dependencies = {},
}
