-- Academy: a completely different attribute set (no Strength/Charisma/QiControl...).
local PlayerStatsConfig = {}

PlayerStatsConfig.Order = { "Power", "Technique", "Speed", "Spirit", "Intellect", "Charm" }
PlayerStatsConfig.Roles = { Social = "Charm", Knowledge = "Intellect" }
PlayerStatsConfig.BaseXp = 10
PlayerStatsConfig.MaxLevel = 60
PlayerStatsConfig.XpGrowth = 1.08

PlayerStatsConfig.HighStress = 75
PlayerStatsConfig.LowHappiness = 20
PlayerStatsConfig.HighStressXpMult = 0.6
PlayerStatsConfig.LowHappinessXpMult = 0.8

local function stat(name, short, r, g, b, description)
	return {
		Name = name, Short = short, Color = Color3.fromRGB(r, g, b), Description = description,
		Describe = function(level: number): string
			return ("%s level %d"):format(name, level)
		end,
	}
end

PlayerStatsConfig.Stats = {
	Power = stat("Power", "POW", 240, 110, 100, "Raw output of your Quirk."),
	Technique = stat("Technique", "TEC", 150, 210, 255, "Control and precision."),
	Speed = stat("Speed", "SPD", 120, 230, 150, "Reflexes and movement."),
	Spirit = stat("Spirit", "SPR", 250, 170, 90, "Grit, stamina and willpower."),
	Intellect = stat("Intellect", "INT", 110, 180, 255, "Tactics and grades."),
	Charm = stat("Charm", "CHM", 240, 130, 210, "Friends, fans and teamwork."),
}

function PlayerStatsConfig.XpForLevel(level: number): number
	return math.floor(PlayerStatsConfig.BaseXp * PlayerStatsConfig.XpGrowth ^ level)
end
function PlayerStatsConfig.MaxHealth(levels): number return 100 + (levels.Spirit or 0) * 5 end
function PlayerStatsConfig.LifespanBonus(levels): number return 0 end
function PlayerStatsConfig.ActionBonus(levels): number return if (levels.Spirit or 0) >= 30 then 1 else 0 end
function PlayerStatsConfig.BreakthroughBonus(levels): number return 0 end
function PlayerStatsConfig.QiMultiplier(levels): number return 1 end
function PlayerStatsConfig.SocialBonus(levels): number return (levels.Charm or 0) * 0.01 end
function PlayerStatsConfig.StudyMultiplier(levels): number return 1 + (levels.Intellect or 0) * 0.02 end
function PlayerStatsConfig.Evasion(levels): number return math.min(0.6, (levels.Speed or 0) * 0.005) end

return PlayerStatsConfig
