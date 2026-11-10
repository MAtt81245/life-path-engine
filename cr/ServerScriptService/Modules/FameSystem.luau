--[[
	FameSystem: the optional Fame module (Shared/EngineModules/Fame). Plugged in
	without editing any engine file: its data lives in PlayerState.ModuleData and
	its behaviour arrives through SystemRegistry hooks (year tick, FameAction
	remote, Fame event effect). The MinFame requirement and FameMult buff come
	from the shared definition.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GamePack = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GamePack"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))

local FameSystem = {}

-- Tuning lives in the shared definition so the client page shows the same numbers.
local Settings = GamePack.Modules.Fame.Settings
FameSystem.Settings = Settings

local DEFAULTS = { Points = 0, Peak = 0 }

function FameSystem.Data(state)
	return PlayerState.ModuleData(state, "Fame", DEFAULTS)
end

-- Adds fame (gains scale with FameMult). Returns the change applied.
function FameSystem.Add(state, amount: number, buffs): number
	local data = FameSystem.Data(state)
	if amount > 0 then
		amount *= (buffs or PlayerState.GetBuffs(state)).FameMult
	end
	local before = data.Points
	data.Points = math.max(0, math.floor(data.Points + amount + 0.5))
	data.Peak = math.max(data.Peak, data.Points)
	return data.Points - before
end

function FameSystem.YearTick(_, state)
	local data = FameSystem.Data(state)
	data.Points = math.floor(data.Points * (1 - Settings.YearlyDecay))
end

function FameSystem.Perform(player, state, buffs)
	if state.Age < Settings.PerformMinAge then
		return false, ("You must be %d to perform in public."):format(Settings.PerformMinAge)
	elseif state.Actions < Settings.PerformSlots then
		return false, "No actions left this year. Advance the year."
	elseif ((state.ActionCounts or {}).FamePerform or 0) >= Settings.PerformMaxPerYear then
		return false, ("You can perform %d times a year."):format(Settings.PerformMaxPerYear)
	end
	state.Actions -= Settings.PerformSlots
	state.ActionCounts = state.ActionCounts or {}
	state.ActionCounts.FamePerform = (state.ActionCounts.FamePerform or 0) + 1
	PlayerState.AdjustMeter(state, "Stress", 3)
	local gained = FameSystem.Add(state, Settings.PerformBase + PlayerState.RoleLevel(state, "Social") * Settings.PerformPerSocialLevel, buffs)
	PlayerState.Log(player, ("You performed in public (+%d fame)."):format(gained), "good")
	return true, ("Performance: +%d fame"):format(gained)
end

FameSystem.Hooks = {
	YearTicks = { { Phase = "Systems", Order = 50, Module = "Fame", Run = FameSystem.YearTick } },
	Remotes = {
		FameAction = {
			Module = "Fame",
			Cooldown = 0.3,
			Validate = function(action)
				return action == "Perform"
			end,
			Handle = function(player, state, buffs)
				return FameSystem.Perform(player, state, buffs)
			end,
		},
	},
	Effects = {
		Fame = function(_, state, value, _, buffs)
			if type(value) ~= "number" then
				return nil
			end
			return ("%+d fame"):format(FameSystem.Add(state, value, buffs))
		end,
	},
}

return FameSystem
