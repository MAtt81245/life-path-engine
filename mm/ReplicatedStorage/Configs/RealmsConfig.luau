--[[
	Cultivation realms. Every realm has 9 sub-levels.
	- BaseRequirement: Qi needed for the first breakthrough of the realm (sub-level 1 -> 2).
	  The requirement grows geometrically up to the next realm's BaseRequirement.
	- BaseChance / ChanceDecay: success chance of minor breakthroughs (drops per sub-level).
	- MajorChance: chance of advancing from sub-level 9 into the next realm.
	- LongevityBonus: extra years of life granted when the realm is reached.
	- QiMultiplier: Qi gain multiplier while inside the realm.
	- ActionSlots: extra yearly action slots while in the realm (high-realm passive).
	- YearsPerLevel: years the foundation needs to stabilize at each sub-level before
	  the next breakthrough. Qi gains scale with the requirement, so this is what
	  paces the late game (fast early realms, centuries for the last ones).
]]

-- Absolute path so a game pack can override this module from its own folder.
local BigNum = require(game:GetService("ReplicatedStorage"):WaitForChild("Configs"):WaitForChild("BigNum"))

local RealmsConfig = {}

RealmsConfig.SubLevels = 9
RealmsConfig.BaseLifespan = 80
RealmsConfig.MinChance = 0.05
RealmsConfig.MaxChance = 0.99

RealmsConfig.Realms = {
	-- Pacing (balance report, campaign mode): a fresh life peaks around Nascent Soul;
	-- stabilizing the later realms takes longer than their longevity grants, so True
	-- Immortal needs lifespan legacies (bloodlines, talents) from many rebirths.
	{ Name = "Mortal", Color = Color3.fromRGB(196, 186, 172), BaseRequirement = { m = 1, e = 2 }, BaseChance = 1.0, ChanceDecay = 0, MajorChance = 0.9, LongevityBonus = 0, QiMultiplier = 1, YearsPerLevel = 0 },
	{ Name = "Qi Condensation", Color = Color3.fromRGB(120, 210, 255), BaseRequirement = { m = 1, e = 4 }, BaseChance = 0.92, ChanceDecay = 0.02, MajorChance = 0.75, LongevityBonus = 5, QiMultiplier = 2.5, YearsPerLevel = 2 },
	{ Name = "Foundation Establishment", Color = Color3.fromRGB(110, 230, 170), BaseRequirement = { m = 1, e = 7 }, BaseChance = 0.85, ChanceDecay = 0.025, MajorChance = 0.6, LongevityBonus = 10, QiMultiplier = 6, YearsPerLevel = 3 },
	{ Name = "Core Formation", Color = Color3.fromRGB(240, 200, 100), BaseRequirement = { m = 1, e = 11 }, BaseChance = 0.8, ChanceDecay = 0.03, MajorChance = 0.5, LongevityBonus = 15, QiMultiplier = 15, YearsPerLevel = 8 }, -- 8: a fresh life peaks at Core Formation (BalanceReport)
	{ Name = "Nascent Soul", Color = Color3.fromRGB(255, 150, 110), BaseRequirement = { m = 1, e = 16 }, BaseChance = 0.75, ChanceDecay = 0.03, MajorChance = 0.4, LongevityBonus = 25, QiMultiplier = 40, YearsPerLevel = 10, ActionSlots = 1 },
	{ Name = "Soul Transformation", Color = Color3.fromRGB(240, 110, 170), BaseRequirement = { m = 1, e = 22 }, BaseChance = 0.7, ChanceDecay = 0.035, MajorChance = 0.35, LongevityBonus = 50, QiMultiplier = 110, YearsPerLevel = 16, ActionSlots = 1 },
	{ Name = "Void Refinement", Color = Color3.fromRGB(180, 120, 255), BaseRequirement = { m = 1, e = 29 }, BaseChance = 0.65, ChanceDecay = 0.035, MajorChance = 0.3, LongevityBonus = 100, QiMultiplier = 300, YearsPerLevel = 24, ActionSlots = 1 },
	{ Name = "Body Integration", Color = Color3.fromRGB(130, 140, 255), BaseRequirement = { m = 1, e = 37 }, BaseChance = 0.6, ChanceDecay = 0.04, MajorChance = 0.25, LongevityBonus = 200, QiMultiplier = 900, YearsPerLevel = 35, ActionSlots = 2 },
	{ Name = "Mahayana", Color = Color3.fromRGB(255, 230, 150), BaseRequirement = { m = 1, e = 46 }, BaseChance = 0.55, ChanceDecay = 0.04, MajorChance = 0.2, LongevityBonus = 350, QiMultiplier = 2800, YearsPerLevel = 50, ActionSlots = 2 },
	{ Name = "Tribulation Transcendence", Color = Color3.fromRGB(150, 240, 255), BaseRequirement = { m = 1, e = 56 }, BaseChance = 0.5, ChanceDecay = 0.045, MajorChance = 0.15, LongevityBonus = 600, QiMultiplier = 9000, YearsPerLevel = 70, ActionSlots = 2 },
	{ Name = "True Immortal", Color = Color3.fromRGB(255, 255, 255), BaseRequirement = { m = 1, e = 70 }, BaseChance = 0.45, ChanceDecay = 0.05, MajorChance = 0, LongevityBonus = 100000, QiMultiplier = 30000, YearsPerLevel = 100, ActionSlots = 2 },
}

function RealmsConfig.Get(realmIndex: number)
	return RealmsConfig.Realms[realmIndex]
end

function RealmsConfig.IsMaxed(realmIndex: number, subLevel: number): boolean
	return realmIndex >= #RealmsConfig.Realms and subLevel >= RealmsConfig.SubLevels
end

-- Qi needed to break through from (realmIndex, subLevel).
function RealmsConfig.GetRequirement(realmIndex: number, subLevel: number)
	local realm = RealmsConfig.Realms[realmIndex]
	local base = BigNum.from(realm.BaseRequirement)
	local nextRealm = RealmsConfig.Realms[realmIndex + 1]
	local nextBase = if nextRealm then BigNum.from(nextRealm.BaseRequirement) else base:Mul(BigNum.new(1, 14))
	local span = nextBase:Log10() - base:Log10()
	return base:Mul(BigNum.new(1, span * (subLevel - 1) / RealmsConfig.SubLevels))
end

-- Base success chance before stats and buffs.
function RealmsConfig.GetSuccessChance(realmIndex: number, subLevel: number): number
	local realm = RealmsConfig.Realms[realmIndex]
	if subLevel >= RealmsConfig.SubLevels then
		return realm.MajorChance
	end
	return realm.BaseChance - realm.ChanceDecay * (subLevel - 1)
end

-- Base lifespan plus the longevity bonus of every realm reached.
function RealmsConfig.GetLongevity(realmIndex: number): number
	local total = RealmsConfig.BaseLifespan
	for i = 1, realmIndex do
		total += RealmsConfig.Realms[i].LongevityBonus
	end
	return total
end

return RealmsConfig
