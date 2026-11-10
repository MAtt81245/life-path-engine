--[[
	Academy (experimental): an anime-style hero academy used to probe how much of the
	engine is reusable. Different stats, rivals, tournaments; no cultivation.
]]

return {
	Id = "academy",
	Name = "Life Path: Hero Academy",
	Version = "0.1.0",
	EngineVersion = "0.3",

	Theme = {
		Genre = "Anime academy simulation",
		Description = "Enroll at a hero academy, train your Quirk, beat your rivals and win the tournament.",
	},

	-- Only what the probe supplies content for; the rest stays off.
	Modules = {
		Cultivation = false,
		Education = false,
		Careers = false,
		Masters = false,
		Relationships = true,
		Masteries = false,
		Titles = true,
		Lineages = false,
		NpcAutonomy = true,
		Inventory = false,
		Fame = true, -- add-on module (Shared/EngineModules/Fame)
	},

	EventPools = {
		{ Config = "YearlyEventsConfig" },
	},

	Interface = {
		TabLabels = { Progression = "Hero Titles" },
		CounterNames = { TournamentWins = "Sports Festival wins" },
	},

	Dependencies = {},
}
