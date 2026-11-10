--[[
	SkillSystem: the 12 skills (SkillsConfig; Skills module).

	Per-life data in PlayerState.ModuleData(state, "Skills") (Snapshot.Modules.Skills):
	Levels = { Skill = { Level, Xp } }, Done = { ActionId = age }, Unlocked = { key = true }.

	- Grant(player, state, skill, xp): XP is refused before a combat skill opens (age 8,
	  minus the Prodigy pass) and stops at the life-stage ceiling (SkillsConfig.Stages).
	- Reaching 15 / 30 / 45 unlocks that tier's action and its permanent passive
	  (a per-life buff source "Skill:<id><level>").
	- Training trains skills too: TrainingSystem.ActionHooks -> FromTraining.
	- SkillAction remote (actionId): an unlocked mastery action, once a year, 1 action.
	- ApplyEffects: the effect applier shared with Arcana, Battle and Minigames.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
local GamePack = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GamePack"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local TrainingSystem = require(script.Parent:WaitForChild("TrainingSystem"))
local Rng = require(script.Parent:WaitForChild("Rng"))

local Skills = Content.Get("SkillsConfig")
local Stats = Content.Get("PlayerStatsConfig")

local SkillSystem = {}

-- Other systems count things here (Character hidden talents); fn(player, state, counter, n).
SkillSystem.CounterHooks = {}
-- fn(player, state, skillId, level) after a skill gains levels (Arcana: special schools).
SkillSystem.LevelHooks = {}

local function leveled(player, state, skillId: string, level: number)
	for _, hook in SkillSystem.LevelHooks do
		hook(player, state, skillId, level)
	end
end

function SkillSystem.Count(player, state, counter: string, n: number?)
	for _, hook in SkillSystem.CounterHooks do
		hook(player, state, counter, n or 1)
	end
end

function SkillSystem.Data(state)
	local data = PlayerState.ModuleData(state, "Skills", {})
	data.Levels = data.Levels or {}
	data.Done = data.Done or {}
	data.Unlocked = data.Unlocked or {}
	for _, id in Skills.Order do
		data.Levels[id] = data.Levels[id] or { Level = 0, Xp = 0 }
	end
	return data
end

function SkillSystem.Level(state, skillId: string): number
	local entry = SkillSystem.Data(state).Levels[skillId]
	return if entry then entry.Level else 0
end

function SkillSystem.Levels(state)
	local out = {}
	for id, entry in SkillSystem.Data(state).Levels do
		out[id] = entry.Level
	end
	return out
end

-- (ceiling, open age) for a skill right now.
function SkillSystem.Limits(state, skillId: string): (number, number)
	return Skills.Stage(state.Age).Cap, Skills.OpenAge(skillId, PlayerState.GetTrainingAgeOffset(state))
end

local function unlock(player, state, data, skill, level: number)
	local key = skill.Id .. level
	if data.Unlocked[key] then
		return
	end
	data.Unlocked[key] = true
	local tier = skill.Unlocks[level]
	if tier and tier.Passive then
		PlayerState.SetLifeBuff(state, "Skill:" .. key, tier.Passive.Name, tier.Passive.Buffs)
	end
	PlayerState.Log(player, ("%s reached %s! New: %s (passive %s)."):format(skill.Name, Skills.Rank(level).Name,
		tier and tier.Action.Name or "-", tier and tier.Passive and tier.Passive.Name or "-"), "realm")
end

-- Returns the XP actually granted.
function SkillSystem.Grant(player, state, skillId: string, amount: number, buffs): number
	local skill = Skills.ById[skillId]
	if not skill or amount <= 0 or state.Dead or not GamePack.IsActive("Skills") then
		return 0
	end
	local cap, openAge = SkillSystem.Limits(state, skillId)
	if state.Age < openAge then
		return 0
	end
	local data = SkillSystem.Data(state)
	local entry = data.Levels[skillId]
	if entry.Level >= cap then
		return 0
	end
	buffs = buffs or PlayerState.GetBuffs(state)
	local nested = buffs.SkillXp and buffs.SkillXp[skillId] or 1
	local xp = math.max(1, math.floor(amount * (buffs.SkillXpMult or 1) * nested + 0.5))
	entry.Xp += xp
	while entry.Level < cap and entry.Xp >= Skills.XpForLevel(entry.Level) do
		entry.Xp -= Skills.XpForLevel(entry.Level)
		entry.Level += 1
		for _, level in Skills.UnlockLevels do
			if entry.Level == level then
				unlock(player, state, data, skill, level)
			end
		end
	end
	if entry.Level >= cap then
		entry.Xp = 0
	end
	leveled(player, state, skillId, entry.Level)
	return xp
end

-- Sets a level directly (dev console, tests); unlocks every tier at or below it.
function SkillSystem.SetLevel(player, state, skillId: string, level: number): boolean
	local skill = Skills.ById[skillId]
	if not skill then
		return false
	end
	local data = SkillSystem.Data(state)
	data.Levels[skillId] = { Level = math.max(0, math.floor(level)), Xp = 0 }
	for _, unlockLevel in Skills.UnlockLevels do
		if level >= unlockLevel then
			unlock(player, state, data, skill, unlockLevel)
		end
	end
	leveled(player, state, skillId, data.Levels[skillId].Level)
	return true
end

-- Skill XP earned by a training action (explicit SkillXp, else inferred from its stats).
function SkillSystem.FromTraining(player, state, action, buffs): string?
	local gains = {}
	if action.SkillXp then
		for skill, xp in action.SkillXp do
			gains[skill] = (gains[skill] or 0) + xp
		end
	else
		local ratio = Skills.Inference.Ratio
		for stat, xp in action.StatXp or {} do
			local skill = Skills.Inference.Stats[stat]
			if skill then
				gains[skill] = (gains[skill] or 0) + xp * ratio
			end
		end
		local skill = action.Proficiency and Skills.Inference.Proficiencies[action.Proficiency]
		if skill then
			gains[skill] = (gains[skill] or 0) + (action.ProficiencyXp or 0) * ratio
		end
	end
	local parts = {}
	for _, skill in Skills.Order do
		local xp = gains[skill] and SkillSystem.Grant(player, state, skill, gains[skill], buffs) or 0
		if xp > 0 then
			table.insert(parts, ("+%d %s"):format(xp, Skills.ById[skill].Name))
		end
	end
	return if #parts > 0 then table.concat(parts, "  ") else nil
end

local function roll(value)
	if type(value) == "table" then
		return Rng:NextInteger(value[1], value[2])
	end
	return value
end

-- Shared effect applier. Returns readable parts.
function SkillSystem.ApplyEffects(player, state, effects, buffs): { string }
	buffs = buffs or PlayerState.GetBuffs(state)
	local parts = {}
	if effects.Money then
		local money = roll(effects.Money)
		if money > 0 then
			money = math.floor(money * (buffs.GoldMult or 1) + 0.5)
		end
		state.Money += money
		table.insert(parts, (if money >= 0 then "+" else "-") .. PlayerState.FormatMoney(math.abs(money)))
	end
	if effects.Fame and GamePack.IsActive("Fame") then
		local FameSystem = require(script.Parent:WaitForChild("FameSystem"))
		local gained = FameSystem.Add(state, effects.Fame, buffs)
		table.insert(parts, ("%+d fame"):format(gained))
	end
	for _, meter in { "Happiness", "Stress" } do
		if effects[meter] then
			PlayerState.AdjustMeter(state, meter, effects[meter])
			table.insert(parts, ("%+d %s"):format(effects[meter], string.lower(meter)))
		end
	end
	if effects.Health then
		PlayerState.AddHealth(state, effects.Health, buffs)
		table.insert(parts, ("%+d health"):format(effects.Health))
	end
	for _, stat in Stats.Order do
		local xp = effects.StatXp and effects.StatXp[stat]
		if xp and state.Stats[stat] then
			table.insert(parts, ("+%d %s"):format(PlayerState.AddStatXp(player, state, stat, xp, buffs), Stats.Stats[stat].Short))
		end
	end
	for _, skill in Skills.Order do
		local xp = effects.SkillXp and effects.SkillXp[skill]
		if xp then
			local granted = SkillSystem.Grant(player, state, skill, xp, buffs)
			if granted > 0 then
				table.insert(parts, ("+%d %s"):format(granted, Skills.ById[skill].Name))
			end
		end
	end
	if effects.LifeBuff then
		PlayerState.SetLifeBuff(state, "Crafted:" .. effects.LifeBuff.Name, effects.LifeBuff.Name, effects.LifeBuff.Buffs)
		table.insert(parts, effects.LifeBuff.Name)
	end
	if effects.Flag then
		state.Flags[effects.Flag] = true
	end
	return parts
end

-- Why an unlocked action cannot be done now (nil = allowed). Returns (action, reason).
function SkillSystem.Check(state, actionId: string)
	local action = Skills.ActionsById[actionId]
	if not action then
		return nil, nil
	end
	local data = SkillSystem.Data(state)
	if data.Levels[action.Skill].Level < action.Level then
		return action, ("Needs %s %d."):format(Skills.ById[action.Skill].Name, action.Level)
	elseif state.Age < (action.MinAge or 12) then
		return action, ("You must be %d."):format(action.MinAge or 12)
	elseif data.Done[actionId] == state.Age then
		return action, "Already done this year."
	elseif state.Actions < 1 then
		return action, "No actions left this year."
	end
	return action, nil
end

-- Success chance of a risky action: +1% per level above its unlock, up to 95%.
function SkillSystem.Chance(state, action): number
	return math.min(0.95, (action.Chance or 1) + (SkillSystem.Level(state, action.Skill) - action.Level) * 0.01)
end

function SkillSystem.DoAction(player, state, actionId: string)
	local action, reason = SkillSystem.Check(state, actionId)
	if not action then
		return false
	elseif reason then
		return false, reason, "warn"
	end
	local data = SkillSystem.Data(state)
	data.Done[actionId] = state.Age
	state.Actions -= 1
	local buffs = PlayerState.GetBuffs(state)
	local success = action.Chance == nil or Rng:NextNumber() < SkillSystem.Chance(state, action)
	local parts = SkillSystem.ApplyEffects(player, state, if success then action.Effects else (action.Fail or {}), buffs)
	SkillSystem.Grant(player, state, action.Skill, 6, buffs)
	SkillSystem.Count(player, state, "skill_actions", 1)
	local text = ("%s %s: %s"):format(action.Name, if success then "succeeded" else "went wrong", table.concat(parts, ", "))
	PlayerState.Log(player, text, if success then "good" else "bad")
	return true, text, if success then "good" else "bad"
end

-- The skill sheet exists from birth (and for saves made before the module).
local function ensure(state)
	if GamePack.IsActive("Skills") then
		SkillSystem.Data(state)
	end
end
table.insert(PlayerState.NewLifeHooks, ensure)
table.insert(PlayerState.LoadHooks, ensure)

table.insert(TrainingSystem.ActionHooks, function(player, state, action, buffs)
	return SkillSystem.FromTraining(player, state, action, buffs)
end)

SkillSystem.Hooks = {
	Remotes = {
		SkillAction = {
			Module = "Skills",
			Cooldown = 0.3,
			Validate = function(actionId)
				return type(actionId) == "string"
			end,
			Handle = function(player, state, _, actionId)
				return SkillSystem.DoAction(player, state, actionId)
			end,
		},
	},
}

return SkillSystem
