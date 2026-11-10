--[[
	NpcSystem: yearly autonomy for the people in the character's life.

	Each year every relationship gets an NPC profile if it lacks one (personality,
	goal, occupation, family, memories), then picks one action from
	NpcBehaviorConfig by weighted random choice against an idle weight. Actions
	change the NPC's own life, affect the player, or queue an existing life event
	with the NPC as its person. Journal lines and triggered events are capped per
	year so the player is informed, not flooded. Only the player's relationships
	are simulated (at most RelationshipsConfig.MaxRelationships per year).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
local Npc = Content.Get("NpcBehaviorConfig")
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local Engine = require(script.Parent:WaitForChild("LifeEventsEngine"))

local NpcSystem = {}

NpcSystem.Rng = Random.new()

-- Deterministic choices for tests and simulations.
function NpcSystem.SetSeed(seed: number)
	NpcSystem.Rng = Random.new(seed)
end

local personalities, goals = {}, {}
for _, personality in Npc.Personalities do
	personalities[personality.Id] = personality
end
for _, goal in Npc.Goals do
	goals[goal.Id] = goal
end

local function pick(list)
	return list[NpcSystem.Rng:NextInteger(1, #list)]
end

local function pickGoal(rel, previous: string?): string?
	local options = {}
	for _, goal in Npc.Goals do
		if goal.Id ~= previous and (not goal.Categories or goal.Categories[rel.Category]) then
			table.insert(options, goal.Id)
		end
	end
	return if #options > 0 then pick(options) else previous
end

-- Fills in NPC fields missing on new or older relationships.
function NpcSystem.Ensure(rel)
	rel.Personality = rel.Personality or pick(Npc.Personalities).Id
	if not rel.Goal or (goals[rel.Goal] and goals[rel.Goal].Categories and not goals[rel.Goal].Categories[rel.Category]) then
		rel.Goal = pickGoal(rel)
	end
	rel.Children = rel.Children or 0
	rel.Memories = rel.Memories or {}
	if rel.Married == nil then
		rel.Married = rel.Type == "Mother" or rel.Type == "Father"
	end
	if rel.Away == nil then
		rel.Away = false
	end
end

function NpcSystem.Stage(rel): string
	for _, stage in Npc.Stages do
		if rel.Age <= stage.MaxAge then
			return stage.Id
		end
	end
	return Npc.Stages[#Npc.Stages].Id
end

local function meets(rel, when): boolean
	if not when then
		return true
	end
	if when.MinAge and rel.Age < when.MinAge then return false end
	if when.MaxAge and rel.Age > when.MaxAge then return false end
	if when.MinAffection and rel.Affection < when.MinAffection then return false end
	if when.MaxAffection and rel.Affection > when.MaxAffection then return false end
	if when.Occupation ~= nil and (rel.Occupation ~= nil) ~= when.Occupation then return false end
	if when.Married ~= nil and (rel.Married == true) ~= when.Married then return false end
	if when.Away ~= nil and (rel.Away == true) ~= when.Away then return false end
	return true
end

-- Weight of `action` for `rel` (0 when not allowed).
function NpcSystem.Weight(rel, action): number
	if action.Stages and not action.Stages[NpcSystem.Stage(rel)] then return 0 end
	if action.Categories and not action.Categories[rel.Category] then return 0 end
	if action.Types and not action.Types[rel.Type] then return 0 end
	if not meets(rel, action.When) then return 0 end

	local weight = action.Weight or 0
	local personality = personalities[rel.Personality]
	weight *= (personality and personality.Weights[action.Id]) or 1
	local goal = goals[rel.Goal]
	weight *= (goal and goal.Weights[action.Id]) or 1
	if action.AffectionScale then
		weight *= rel.Affection / 50
	end
	if action.MemoryBias then
		local good, bad = 0, 0
		for _, memory in rel.Memories or {} do
			if memory.Mood > 0 then good += 1 elseif memory.Mood < 0 then bad += 1 end
		end
		weight *= 1 + (action.MemoryBias.Positive or 0) * good + (action.MemoryBias.Negative or 0) * bad
	end
	return math.max(0, weight)
end

-- Picks this year's action for `rel`, or nil to stay idle.
function NpcSystem.Choose(rel)
	local options, total = {}, Npc.IdleWeight
	for _, action in Npc.Actions do
		local weight = NpcSystem.Weight(rel, action)
		if weight > 0 then
			table.insert(options, { Action = action, Weight = weight })
			total += weight
		end
	end
	local roll = NpcSystem.Rng:NextNumber() * total
	for _, option in options do
		roll -= option.Weight
		if roll < 0 then
			return option.Action
		end
	end
	return nil
end

local function fill(text: string, rel): string
	local values = { name = rel.Name, occupation = rel.Occupation or "worker", spouse = rel.Spouse or "their sweetheart" }
	return (string.gsub(text, "{(%w+)}", function(key) return values[key] or "{" .. key .. "}" end))
end

-- Applies `action` for `rel`. `budget` = { Logs, Events } remaining this year.
function NpcSystem.Apply(player, state, rel, action, budget, buffs)
	local effects = action.Effects or {}
	if effects.SetOccupation then
		rel.Occupation = pick(Npc.Occupations)
	end
	if effects.Retire then
		rel.Occupation = nil
		rel.Retired = true
	end
	if effects.Married then
		rel.Married = true
		rel.Spouse = PlayerState.RandomPersonName(nil, state)
	end
	if effects.Children then
		rel.Children = (rel.Children or 0) + effects.Children
		for _, hook in PlayerState.NpcChildHooks do
			hook(player, state, rel)
		end
	end
	if effects.Away ~= nil then
		rel.Away = effects.Away
	end
	if effects.Affection then
		PlayerState.AdjustAffection(rel, effects.Affection, buffs)
	end
	if effects.PlayerHappiness then
		PlayerState.AdjustMeter(state, "Happiness", effects.PlayerHappiness)
	end
	if effects.PlayerStress then
		PlayerState.AdjustMeter(state, "Stress", effects.PlayerStress)
	end
	if effects.PlayerMoney then
		-- A loan to an NPC never puts you in debt: it takes at most what you have.
		state.Money += math.max(effects.PlayerMoney, -math.max(state.Money, 0))
	end
	if action.Memory then
		PlayerState.Remember(state, rel, action.Memory.Text, action.Memory.Mood)
	end
	if action.TriggerEvent and budget.Events > 0 and Engine.TriggerFor(state, action.TriggerEvent, rel) then
		budget.Events -= 1
	end

	local goal = goals[rel.Goal]
	if goal and goal.CompletedBy == action.Id then
		rel.Goal = pickGoal(rel, rel.Goal)
	end

	if action.Log and action.Notable and budget.Logs > 0 and rel.Affection >= (action.MinAffectionToLog or 0) then
		budget.Logs -= 1
		PlayerState.Log(player, fill(action.Log, rel), "info")
	end
	if effects.Remove then
		PlayerState.RemoveRelationship(state, rel.Id)
	end
end

-- One year of autonomy for every relationship, in random order.
function NpcSystem.YearTick(player, state, buffs)
	buffs = buffs or PlayerState.GetBuffs(state)
	local budget = { Logs = Npc.MaxJournalEntriesPerYear, Events = Npc.MaxTriggeredEventsPerYear }
	local people = table.clone(state.Relationships)
	for i = #people, 2, -1 do
		local j = NpcSystem.Rng:NextInteger(1, i)
		people[i], people[j] = people[j], people[i]
	end
	local acted = 0
	for _, rel in people do
		if rel.Alive and PlayerState.FindRelationship(state, rel.Id) then
			NpcSystem.Ensure(rel)
			local action = NpcSystem.Choose(rel)
			if action then
				acted += 1
				NpcSystem.Apply(player, state, rel, action, budget, buffs)
			end
		end
	end
	return acted
end

-- Registry hooks (see SystemRegistry). NpcAutonomy requires Relationships.
NpcSystem.Hooks = {
	YearTicks = { { Phase = "Systems", Order = 40, Module = "NpcAutonomy", Run = NpcSystem.YearTick } },
}

return NpcSystem
