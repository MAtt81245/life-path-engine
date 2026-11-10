--[[
	CultivationSystem: breakthrough attempts between sub-levels and realms.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
local Realms = Content.Get("RealmsConfig")
local Masteries = Content.Get("MasteriesConfig")
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))

local CultivationSystem = {}

local rng = require(script.Parent:WaitForChild("Rng"))

-- Returns (ok, message, kind).
function CultivationSystem.Breakthrough(player: Player, state)
	if Realms.IsMaxed(state.RealmIndex, state.SubLevel) then
		return false, PlayerState.Term("PeakLine")
	end
	local wait = PlayerState.GetBreakthroughWait(state)
	if wait > 0 then
		return false, ("Your foundation needs %d more year%s to stabilize."):format(wait, if wait == 1 then "" else "s")
	end
	local requirement = PlayerState.GetRequirement(state)
	if state.Qi:Lt(requirement) then
		return false, PlayerState.Words("You need %s {EnergyName}."):format(requirement:ToString())
	end

	local buffs = PlayerState.GetBuffs(state)
	local isMajor = state.SubLevel >= Realms.SubLevels
	local chance = PlayerState.GetBreakthroughChance(state, buffs)
	state.PillBonus = nil -- a Miracle Pill lasts one attempt
	if rng:NextNumber() < chance then
		state.Qi = state.Qi:Sub(requirement):Max(0)
		state.LevelSince = state.Age
		if isMajor then
			state.RealmIndex += 1
			state.SubLevel = 1
			state.MasteryPoints += Masteries.PointsPerMajorBreakthrough
			state.Health = PlayerState.GetMaxHealth(state)
			local realm = Realms.Get(state.RealmIndex)
			PlayerState.Log(player, ("You ascend to %s! +%d years of lifespan."):format(realm.Name, realm.LongevityBonus), "realm")
			PlayerState.Feedback(player, "BreakthroughMajor")
			return true, "New realm: " .. realm.Name .. "!", "realm"
		end
		state.SubLevel += 1
		local message = PlayerState.Words("{AdvanceTierName}! %s level %d."):format(Realms.Get(state.RealmIndex).Name, state.SubLevel)
		PlayerState.Log(player, message, "good")
		PlayerState.Feedback(player, "BreakthroughSuccess")
		return true, message
	end

	-- Qi deviation: lose part of the Qi and take damage
	local maxHealth = PlayerState.GetMaxHealth(state, buffs)
	state.Qi = state.Qi:Mul(if isMajor then 0.4 else 0.6)
	state.Health -= maxHealth * (if isMajor then 0.35 else 0.15)
	PlayerState.AdjustMeter(state, "Stress", 10)
	PlayerState.Log(player, PlayerState.Words("The {advanceTierName} fails. Your {energyName} backlashes through your body."), "bad")
	PlayerState.Feedback(player, "BreakthroughFail")
	return false, PlayerState.Words("{AdvanceTierName} failed!")
end

-- Passive Qi, after the yearly buff refresh.
function CultivationSystem.YearTick(_, state, buffs)
	PlayerState.AddQi(state, PlayerState.GetPassiveGain(state, buffs))
end

-- Registry hooks (see SystemRegistry).
CultivationSystem.Hooks = {
	YearTicks = { { Phase = "Growth", Order = 10, Module = "Cultivation", Run = CultivationSystem.YearTick } },
	Remotes = {
		Breakthrough = {
			Module = "Cultivation",
			Cooldown = 0.8,
			Handle = function(player, state)
				return CultivationSystem.Breakthrough(player, state)
			end,
		},
	},
}

return CultivationSystem
