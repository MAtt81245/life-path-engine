--[[
	TrainingSystem: validates and applies energy-based actions from TrainingConfig.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
local Training = Content.Get("TrainingConfig")
local StatsConfig = Content.Get("PlayerStatsConfig")
local GamePack = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GamePack"))
local Requirements = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Requirements"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local MasterSystem = require(script.Parent:WaitForChild("MasterSystem"))

local TrainingSystem = {}

local rng = require(script.Parent:WaitForChild("Rng"))

-- Actions that cost health are refused below this share of max health, so
-- training alone can never kill (found by the balance report).
TrainingSystem.InjuryFloor = 0.3

-- fn(player, state, action, buffs) -> summary part? after every performed action
-- (SkillSystem: skill XP; CharacterSystem: personality).
TrainingSystem.ActionHooks = {}

-- Earliest age for an action; Prodigy actions open earlier with the Prodigy pass.
function TrainingSystem.MinAge(state, action): number
	return action.MinAge - (if action.Prodigy then PlayerState.GetTrainingAgeOffset(state) else 0)
end

-- Why an action cannot be performed right now. Returns (action, reason):
-- action is nil for unknown actions or a disabled module, reason is nil when allowed.
function TrainingSystem.Check(state, actionId: string)
	local action = Training.ById[actionId]
	if not action or not GamePack.IsEnabled(action.Module) then
		return nil, nil
	end
	local minAge = TrainingSystem.MinAge(state, action)
	if state.Age < minAge then
		return action, ("You must be %d to do that."):format(minAge)
	end
	if action.MaxAge and state.Age > action.MaxAge then
		return action, "You have outgrown that."
	end
	if action.Requires then
		local met, items = Requirements.Evaluate(state, action.Requires)
		if not met then
			return action, "Requires " .. Requirements.UnmetText(items)
		end
	end
	if action.RequiresEnrolled and not state.Education.Enrolled then
		return action, "You are not enrolled in school."
	end
	if action.RequiresJob and not state.Career.Id then
		return action, "You don't have a job."
	end
	if state.Actions < action.Slots then
		return action, "No actions left this year. Advance the year."
	end
	local limit = action.MaxPerYear or Training.DefaultMaxPerYear
	if ((state.ActionCounts or {})[action.Id] or 0) >= limit then
		return action, ("Already done %d time%s this year."):format(limit, if limit == 1 then "" else "s")
	end
	if (action.Health or 0) < 0 and state.Health + action.Health < PlayerState.GetMaxHealth(state) * TrainingSystem.InjuryFloor then
		return action, "You are too injured to train like this. Rest first."
	end
	if action.QiFraction and state.Qi:Ge(PlayerState.GetRequirement(state)) then
		return action, PlayerState.Words("Your {EnergyName} is at its limit. Attempt a {AdvanceTierName}!")
	end
	if action.SeekMaster and MasterSystem.AllDiscovered(state) then
		return action, PlayerState.Words("You have already found every {mentorName} in this region. Travel to find others.")
	end
	return action, nil
end

-- Returns (ok, message).
function TrainingSystem.Perform(player: Player, state, actionId: string)
	local action, reason = TrainingSystem.Check(state, actionId)
	if not action then
		return false
	elseif reason then
		return false, reason
	end

	state.Actions -= action.Slots
	state.ActionCounts = state.ActionCounts or {}
	state.ActionCounts[action.Id] = (state.ActionCounts[action.Id] or 0) + 1
	local buffs = PlayerState.GetBuffs(state)
	local parts = {}

	if action.StatXp then
		for _, stat in StatsConfig.Order do
			local xp = action.StatXp[stat]
			if xp then
				local granted = PlayerState.AddStatXp(player, state, stat, xp, buffs)
				table.insert(parts, ("+%d %s"):format(granted, StatsConfig.Stats[stat].Short))
			end
		end
	end
	if action.Proficiency then
		local granted = PlayerState.AddProficiencyXp(player, state, action.Proficiency, action.ProficiencyXp, buffs)
		table.insert(parts, ("+%d %s"):format(granted, Training.Proficiencies[action.Proficiency].Name))
	end
	if action.QiFraction then
		local gain = PlayerState.GetRequirement(state):Mul(action.QiFraction * PlayerState.GetQiMultiplier(state, buffs))
		PlayerState.AddQi(state, gain)
		table.insert(parts, "+" .. gain:ToString() .. " " .. PlayerState.Term("EnergyName"))
	end
	if action.Health then
		PlayerState.AddHealth(state, action.Health, buffs)
	end
	if action.Stress then
		PlayerState.AdjustMeter(state, "Stress", action.Stress)
		if action.Stress < 0 then
			table.insert(parts, ("%d stress"):format(action.Stress))
		end
	end
	if action.Happiness then
		PlayerState.AdjustMeter(state, "Happiness", action.Happiness)
		table.insert(parts, ("+%d happiness"):format(action.Happiness))
	end
	if action.Knowledge then
		local knowledge = action.Knowledge + buffs.KnowledgeBonus
		state.Counters.Knowledge += knowledge
		table.insert(parts, ("+%d knowledge"):format(knowledge))
	end
	if action.Performance then
		local gain = action.Performance * buffs.StudyMult * StatsConfig.StudyMultiplier(PlayerState.StatLevels(state))
		state.Education.Performance = math.clamp(state.Education.Performance + gain, 0, 100)
		table.insert(parts, ("+%d grades"):format(math.floor(gain + 0.5)))
	end
	if action.JobPerformance then
		state.Career.Performance = math.clamp(state.Career.Performance + action.JobPerformance, 0, 100)
		local bonus = math.floor(PlayerState.GetSalary(state, buffs) * action.SalaryFraction)
		state.Money += bonus
		table.insert(parts, "+" .. PlayerState.FormatMoney(bonus))
	end
	if action.MeetChance and GamePack.IsEnabled("Relationships") then
		if PlayerState.RollChance(state, action.MeetChance, "Charisma", buffs) then
			local rel = PlayerState.CreateRelationship(state, "Friend", { Affection = rng:NextInteger(40, 60) })
			if rel then
				PlayerState.Log(player, ("You befriended %s."):format(rel.Name), "good")
				table.insert(parts, "new friend: " .. rel.Name)
			end
		end
	end
	if action.SeekMaster then
		table.insert(parts, MasterSystem.Seek(player, state, buffs))
	end
	for _, hook in TrainingSystem.ActionHooks do
		local part = hook(player, state, action, buffs)
		if part then
			table.insert(parts, part)
		end
	end

	return true, action.Name .. ":  " .. table.concat(parts, "  ·  ")
end

-- Registry hooks (see SystemRegistry). Core: no owning module.
TrainingSystem.Hooks = {
	Remotes = {
		Train = {
			Cooldown = 0.15,
			Validate = function(actionId)
				return type(actionId) == "string"
			end,
			Handle = function(player, state, _, actionId)
				return TrainingSystem.Perform(player, state, actionId)
			end,
		},
	},
}

return TrainingSystem
