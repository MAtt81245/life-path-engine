--[[
	Modern Life: an everyday life simulation built on the base content library.
	No cultivation, no sects, no bloodlines; school, work, friends and skills.
	Only the modules listed in this folder override Configs; everything else is inherited.
]]

return {
	Id = "modern_life",
	Name = "Life Path: Modern Days",
	Version = "1.0.0",
	EngineVersion = "0.3",

	Theme = {
		Genre = "Modern life simulation",
		Description = "Grow up, study, build a career and a circle of friends in today's world.",
	},

	Modules = {
		Cultivation = false,
		Education = true,
		Careers = true,
		Masters = false,
		Relationships = true,
		Masteries = true,
		Titles = true,
		Lineages = false,
		NpcAutonomy = true,
		Inventory = true,
	},

	EventPools = {
		{ Config = "YearlyEventsConfig" },
	},

	Interface = {
		TabLabels = { Progression = "Skills & Titles" },
	},

	Dependencies = {},
}
