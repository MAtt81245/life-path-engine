--[[
	Spiritual Classes (the engine's "realms"). Every class has 9 sub-levels (stages).
	Numbers are unchanged from the template: a fresh life peaks around class 4
	(Seated Squad Officer) stage 7/9; the top classes need many reincarnations.
	Stamp: short badge on the Soul Pass portrait ([H], [SR], [LT], [CAP], [SZ] ...).
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

local BigNum = require(game:GetService("ReplicatedStorage"):WaitForChild("Configs"):WaitForChild("BigNum"))

local RealmsConfig = {}

RealmsConfig.SubLevels = 9
RealmsConfig.BaseLifespan = 80
RealmsConfig.MinChance = 0.05
RealmsConfig.MaxChance = 0.99

RealmsConfig.Realms = {
	-- Pacing (balance report, campaign mode): a fresh life peaks around Seated Squad Officer;
	-- stabilizing the later classes takes longer than their longevity grants, so the
	-- Transcendent Hybrid needs lifespan legacies (origins, talents) from many reincarnations.
	-- 11 tiers (the template's curve): the 9 classes, with the top split into Schutzstaffel and Squad Zero.
	{ Name = "Spiritually Aware Human", Stamp = "H", Color = Color3.fromRGB(176, 170, 190), BaseRequirement = { m = 1, e = 2 }, BaseChance = 1.0, ChanceDecay = 0, MajorChance = 0.9, LongevityBonus = 0, QiMultiplier = 1, YearsPerLevel = 0 },
	{ Name = "Substitute Reaper / Academy Cadet", Stamp = "SR", Color = Color3.fromRGB(120, 200, 255), BaseRequirement = { m = 1, e = 4 }, BaseChance = 0.92, ChanceDecay = 0.02, MajorChance = 0.75, LongevityBonus = 5, QiMultiplier = 2.5, YearsPerLevel = 2 },
	{ Name = "Unseated Soul Reaper", Stamp = "US", Color = Color3.fromRGB(56, 189, 248), BaseRequirement = { m = 1, e = 7 }, BaseChance = 0.85, ChanceDecay = 0.025, MajorChance = 0.6, LongevityBonus = 10, QiMultiplier = 6, YearsPerLevel = 3 },
	{ Name = "Seated Squad Officer", Stamp = "SO", Color = Color3.fromRGB(140, 120, 255), BaseRequirement = { m = 1, e = 11 }, BaseChance = 0.8, ChanceDecay = 0.03, MajorChance = 0.5, LongevityBonus = 15, QiMultiplier = 15, YearsPerLevel = 8 }, -- 8: a fresh life peaks at this class (BalanceReport)
	{ Name = "Shikai Awakened Specialist", Stamp = "SK", Color = Color3.fromRGB(157, 78, 221), BaseRequirement = { m = 1, e = 16 }, BaseChance = 0.75, ChanceDecay = 0.03, MajorChance = 0.4, LongevityBonus = 25, QiMultiplier = 40, YearsPerLevel = 10, ActionSlots = 1 },
	{ Name = "Squad Lieutenant", Stamp = "LT", Color = Color3.fromRGB(200, 90, 230), BaseRequirement = { m = 1, e = 22 }, BaseChance = 0.7, ChanceDecay = 0.035, MajorChance = 0.35, LongevityBonus = 50, QiMultiplier = 110, YearsPerLevel = 16, ActionSlots = 1 },
	{ Name = "Bankai Captain", Stamp = "CAP", Color = Color3.fromRGB(244, 63, 94), BaseRequirement = { m = 1, e = 29 }, BaseChance = 0.65, ChanceDecay = 0.035, MajorChance = 0.3, LongevityBonus = 100, QiMultiplier = 300, YearsPerLevel = 24, ActionSlots = 1 },
	{ Name = "Head-Captain / Vasto Lorde", Stamp = "HC", Color = Color3.fromRGB(225, 29, 72), BaseRequirement = { m = 1, e = 37 }, BaseChance = 0.6, ChanceDecay = 0.04, MajorChance = 0.25, LongevityBonus = 200, QiMultiplier = 900, YearsPerLevel = 35, ActionSlots = 2 },
	{ Name = "Schutzstaffel Royal Guard", Stamp = "SS", Color = Color3.fromRGB(245, 158, 11), BaseRequirement = { m = 1, e = 46 }, BaseChance = 0.55, ChanceDecay = 0.04, MajorChance = 0.2, LongevityBonus = 350, QiMultiplier = 2800, YearsPerLevel = 50, ActionSlots = 2 },
	{ Name = "Squad Zero Guardian", Stamp = "SZ", Color = Color3.fromRGB(150, 230, 255), BaseRequirement = { m = 1, e = 56 }, BaseChance = 0.5, ChanceDecay = 0.045, MajorChance = 0.15, LongevityBonus = 600, QiMultiplier = 9000, YearsPerLevel = 70, ActionSlots = 2 },
	{ Name = "Transcendent Hogyoku Hybrid", Stamp = "TH", Color = Color3.fromRGB(255, 240, 245), BaseRequirement = { m = 1, e = 70 }, BaseChance = 0.45, ChanceDecay = 0.05, MajorChance = 0, LongevityBonus = 100000, QiMultiplier = 30000, YearsPerLevel = 100, ActionSlots = 2 },
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
