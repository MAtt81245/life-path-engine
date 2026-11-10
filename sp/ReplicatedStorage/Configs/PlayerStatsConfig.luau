--[[
	Core character attributes. Each stat has a Level and XP toward the next level.
	The helper functions below turn a table of stat levels ({ Strength = 12, ... })
	into gameplay bonuses, so server and client describe the same numbers.
]]

local PlayerStatsConfig = {}

-- Physical & Aura first, then Magical & Mental (Groups below); sword damage only ever
-- reads the physical side and magic damage only the magical side (Shared/CombatMath).
PlayerStatsConfig.Order = {
	"Strength", "Agility", "Vitality", "BattleAura", "AuraPotential",
	"Intelligence", "Mana", "MagicPower", "MagicControl", "Luck", "Charisma", "QiControl",
}
PlayerStatsConfig.Groups = {
	{ Name = "Body & Reiatsu", Stats = { "Strength", "Agility", "Vitality", "BattleAura", "AuraPotential" } },
	{ Name = "Kido & Mind", Stats = { "Intelligence", "Mana", "MagicPower", "MagicControl", "Luck", "Charisma", "QiControl" } },
}

-- Which stat plays each engine role, so packs can use any stat names. A role may be
-- left out: Social adds social buffs to chance rolls and drives master searches and
-- job interviews; Knowledge is the stat shown on the character sheet.
PlayerStatsConfig.Roles = { Social = "Charisma", Knowledge = "Intelligence" }
PlayerStatsConfig.BaseXp = 10
-- Attributes have no upper cap (XpGrowth makes high levels slow); proficiencies stop here.
PlayerStatsConfig.MaxLevel = nil
PlayerStatsConfig.ProficiencyMaxLevel = 60

-- The (i) rating scale: rating = level x RatingScale, adult average 50, no top.
PlayerStatsConfig.RatingScale = 2
PlayerStatsConfig.AdultAverage = 50
PlayerStatsConfig.Ratings = {
	{ Min = 0, Name = "Very Low" }, { Min = 20, Name = "Low" }, { Min = 35, Name = "Below Average" },
	{ Min = 45, Name = "Average" }, { Min = 60, Name = "Above Average" }, { Min = 75, Name = "High" },
	{ Min = 90, Name = "Very High" }, { Min = 110, Name = "Exceptional" }, { Min = 140, Name = "Legendary" },
}

-- Rating of a stat level -> (rating, band name).
function PlayerStatsConfig.Rating(level: number): (number, string)
	local rating = math.floor(level * PlayerStatsConfig.RatingScale)
	local name = PlayerStatsConfig.Ratings[1].Name
	for _, band in PlayerStatsConfig.Ratings do
		if rating >= band.Min then
			name = band.Name
		end
	end
	return rating, name
end
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
	BattleAura = {
		Name = "Fighting Reiatsu", Short = "FRA", Color = Color3.fromRGB(255, 196, 92),
		Description = "Reiatsu wrapped around blade and body. Zanjutsu damage, never Kido.",
		Describe = function(level: number): string
			return ("Zanjutsu damage +%d%%  ·  Guard +%d%%"):format(level * 2, level)
		end,
	},
	AuraPotential = {
		Name = "Reiatsu Potential", Short = "POT", Color = Color3.fromRGB(255, 150, 70),
		Description = "How far your spiritual pressure can grow. Speeds up Fighting Reiatsu training.",
		Describe = function(level: number): string
			return ("Fighting Reiatsu XP +%d%%"):format(level * 2)
		end,
	},
	Mana = {
		Name = "Reiryoku", Short = "RRY", Color = Color3.fromRGB(96, 170, 255),
		Description = "The depth of your spiritual energy. Grows with practice and Reiryoku Collapse.",
		Describe = function(level: number): string
			return ("Max reiryoku +%d"):format(level * 4)
		end,
	},
	MagicPower = {
		Name = "Kido Power", Short = "KPW", Color = Color3.fromRGB(186, 120, 255),
		Description = "Raw strength of your Kido. Kido damage, never Zanjutsu damage.",
		Describe = function(level: number): string
			return ("Kido damage +%d%%"):format(level * 2)
		end,
	},
	MagicControl = {
		Name = "Kido Control", Short = "KCT", Color = Color3.fromRGB(140, 200, 255),
		Description = "Precision and efficiency. Lowers reiryoku costs; 20 opens the Chantless Kido Trial.",
		Describe = function(level: number): string
			return ("Reiryoku cost -%d%%"):format(math.min(40, math.floor(level * 0.5)))
		end,
	},
	Luck = {
		Name = "Luck", Short = "LCK", Color = Color3.fromRGB(120, 230, 150),
		Description = "Fortune's favor: critical hits, finds and close calls.",
		Describe = function(level: number): string
			return ("Critical +%.1f%%"):format(math.min(30, level * 0.3))
		end,
	},
	QiControl = {
		Name = "Reiatsu Control", Short = "RC", Color = Color3.fromRGB(125, 211, 252),
		Description = "Control over your spiritual pressure output and refinement.",
		Describe = function(level: number): string
			return ("Awakening +%.1f%%  ·  SP +%d%%"):format(level * 0.4, level * 2)
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
