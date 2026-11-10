--[[
	Core character attributes. Each stat has a Level and XP toward the next level.
	The helper functions below turn a table of stat levels ({ Strength = 12, ... })
	into gameplay bonuses, so server and client describe the same numbers.
]]

local PlayerStatsConfig = {}

PlayerStatsConfig.Order = { "Strength", "Agility", "Vitality", "Intelligence", "Charisma", "QiControl" }

-- Which stat plays each engine role, so packs can use any stat names. A role may be
-- left out: Social adds social buffs to chance rolls and drives master searches and
-- job interviews; Knowledge is the stat shown on the character sheet.
PlayerStatsConfig.Roles = { Social = "Charisma", Knowledge = "Intelligence" }
PlayerStatsConfig.BaseXp = 10
PlayerStatsConfig.MaxLevel = 60 -- attributes and proficiencies
PlayerStatsConfig.XpGrowth = 1.08

-- Above HighStress or below LowHappiness, XP gains are reduced.
PlayerStatsConfig.HighStress = 75
PlayerStatsConfig.LowHappiness = 20
PlayerStatsConfig.HighStressXpMult = 0.6
PlayerStatsConfig.LowHappinessXpMult = 0.8

PlayerStatsConfig.Stats = {
	Strength = {
		Name = "Strength", Short = "STR", Color = Color3.fromRGB(240, 110, 100),
		Description = "Melee damage and carrying capacity.",
		Describe = function(level: number): string
			return ("Melee +%d%%  ·  Carry %d kg"):format(level * 2, 50 + level * 5)
		end,
	},
	Agility = {
		Name = "Agility", Short = "AGI", Color = Color3.fromRGB(120, 230, 150),
		Description = "Evasion and speed.",
		Describe = function(level: number): string
			return ("Evasion %.1f%%  ·  Speed +%d%%"):format(math.min(60, level * 0.5), level)
		end,
	},
	Vitality = {
		Name = "Vitality", Short = "VIT", Color = Color3.fromRGB(250, 170, 90),
		Description = "Max health, energy and lifespan.",
		Describe = function(level: number): string
			return ("Max HP +%d  ·  Lifespan +%dy"):format(level * 5, math.floor(level / 2))
		end,
	},
	Intelligence = {
		Name = "Intelligence", Short = "INT", Color = Color3.fromRGB(110, 180, 255),
		Description = "Raised by reading and studying. Unlocks knowledge choices.",
		Describe = function(level: number): string
			return ("Study +%d%%  ·  Smarter choices"):format(level * 2)
		end,
	},
	Charisma = {
		Name = "Charisma", Short = "CHA", Color = Color3.fromRGB(240, 130, 210),
		Description = "Social success, hiring and deals.",
		Describe = function(level: number): string
			return ("Social success +%d%%"):format(level)
		end,
	},
	QiControl = {
		Name = "CE Manipulation", Short = "CE", Color = Color3.fromRGB(56, 189, 248),
		Description = "Control over your cursed energy output and refinement.",
		Describe = function(level: number): string
			return ("Promotion +%.1f%%  ·  CE +%d%%"):format(level * 0.4, level * 2)
		end,
	},
}

function PlayerStatsConfig.XpForLevel(level: number): number
	return math.floor(PlayerStatsConfig.BaseXp * PlayerStatsConfig.XpGrowth ^ level)
end

function PlayerStatsConfig.MaxHealth(levels): number
	return 100 + (levels.Vitality or 0) * 5
end

function PlayerStatsConfig.LifespanBonus(levels): number
	return math.floor((levels.Vitality or 0) / 2)
end

-- Extra yearly action slot at a Vitality peak.
function PlayerStatsConfig.ActionBonus(levels): number
	return if (levels.Vitality or 0) >= 30 then 1 else 0
end

function PlayerStatsConfig.BreakthroughBonus(levels): number
	return (levels.QiControl or 0) * 0.004
end

function PlayerStatsConfig.QiMultiplier(levels): number
	return 1 + (levels.QiControl or 0) * 0.02
end

function PlayerStatsConfig.SocialBonus(levels): number
	return (levels.Charisma or 0) * 0.01
end

function PlayerStatsConfig.StudyMultiplier(levels): number
	return 1 + (levels.Intelligence or 0) * 0.02
end

function PlayerStatsConfig.Evasion(levels): number
	return math.min(0.6, (levels.Agility or 0) * 0.005)
end

return PlayerStatsConfig
