--[[
	NPC autonomy: profiles, life stages, filters, personality/goal/memory weights,
	event triggers, yearly caps, module gating and long simulations.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ServerScriptService.Modules
local PlayerState = require(Modules.PlayerState)
local NpcSystem = require(Modules.NpcSystem)
local Engine = require(Modules.LifeEventsEngine)
local YearSystem = require(Modules.YearSystem)
local Requirements = require(ReplicatedStorage.Shared.Requirements)
local GamePack = require(ReplicatedStorage.Shared.GamePack)
local Content = require(ReplicatedStorage.Shared.Content)
local Npc = Content.Get("NpcBehaviorConfig")
local RelConfig = Content.Get("RelationshipsConfig")

local ACTIONS = {}
for _, action in Npc.Actions do
	ACTIONS[action.Id] = action
end

local function newCharacter(name: string, age: number)
	local player = { Name = name }
	local state = PlayerState.CreateState({}, "Human")
	state.Age = age
	PlayerState.Track(player, state)
	return player, state
end

local function liveYears(player, state, rel, years: number)
	local budget = { Logs = 99, Events = 0 }
	for _ = 1, years do
		rel.Age += 1
		local action = NpcSystem.Choose(rel)
		if action then
			NpcSystem.Apply(player, state, rel, action, budget, PlayerState.GetBuffs(state))
		end
	end
end

return function(test, expect)
	test("relationships get NPC profiles", function()
		local _, state = newCharacter("NpcA", 0)
		for _, rel in state.Relationships do
			NpcSystem.Ensure(rel)
			expect.truthy(rel.Personality and rel.Goal, "personality and goal for " .. rel.Type)
			expect.equal(#rel.Memories, 0, "no memories yet")
			if rel.Type == "Mother" or rel.Type == "Father" then
				expect.truthy(rel.Married, "parents start married")
			end
		end
	end)

	test("adults find work and elders retire", function()
		NpcSystem.SetSeed(7)
		local player, state = newCharacter("NpcB", 20)
		local friend = PlayerState.CreateRelationship(state, "Friend", { Age = 17, Affection = 50 })
		NpcSystem.Ensure(friend)
		liveYears(player, state, friend, 15)
		expect.truthy(friend.Occupation ~= nil or not PlayerState.FindRelationship(state, friend.Id), "found a job by 32 (or drifted away)")
		if PlayerState.FindRelationship(state, friend.Id) then
			friend.Age = 66
			friend.Occupation = friend.Occupation or "Farmer"
			liveYears(player, state, friend, 12)
			expect.truthy(friend.Retired and friend.Occupation == nil, "retired as an elder")
		end
		PlayerState.Track(player, nil)
	end)

	test("actions respect stages, categories and types", function()
		local _, state = newCharacter("NpcC", 20)
		local rival = PlayerState.CreateRelationship(state, "Rival", { Age = 20, Affection = 90 })
		local child = PlayerState.CreateRelationship(state, "Friend", { Age = 4, Affection = 90 })
		NpcSystem.Ensure(rival)
		NpcSystem.Ensure(child)
		local mother
		for _, rel in state.Relationships do
			if rel.Type == "Mother" then mother = rel end
		end
		NpcSystem.Ensure(mother)
		mother.Married = false
		expect.equal(NpcSystem.Weight(rival, ACTIONS.Visit), 0, "rivals never visit")
		expect.equal(NpcSystem.Weight(rival, ACTIONS.Gift), 0, "rivals never send gifts")
		expect.equal(NpcSystem.Weight(mother, ACTIONS.Marry), 0, "parents do not remarry")
		expect.equal(NpcSystem.Weight(child, ACTIONS.StartCareer), 0, "children do not work")
		expect.truthy(NpcSystem.Weight(rival, ACTIONS.Sabotage) > 0, "rivals may sabotage")
	end)

	test("personality, goals and memories shape choices", function()
		local _, state = newCharacter("NpcD", 20)
		local rival = PlayerState.CreateRelationship(state, "Rival", { Age = 25, Affection = 20 })
		NpcSystem.Ensure(rival)
		rival.Goal = "Revenge"
		rival.Personality = "Kind"
		local kind = NpcSystem.Weight(rival, ACTIONS.Sabotage)
		rival.Personality = "Scheming"
		local scheming = NpcSystem.Weight(rival, ACTIONS.Sabotage)
		expect.truthy(scheming > kind * 5, "scheming rivals sabotage far more")
		PlayerState.Remember(state, rival, "Lost a duel to you", -1)
		PlayerState.Remember(state, rival, "Argued with you", -1)
		expect.near(NpcSystem.Weight(rival, ACTIONS.Sabotage), scheming * 2, 1e-6, "grudges double the weight")
		for i = 1, 6 do
			PlayerState.Remember(state, rival, "memory " .. i, 0)
		end
		expect.equal(#rival.Memories, PlayerState.MaxMemories, "memories are capped")
		expect.equal(rival.Memories[1].Text, "memory 6", "newest first")
	end)

	test("goals are replaced when completed", function()
		local player, state = newCharacter("NpcE", 30)
		local friend = PlayerState.CreateRelationship(state, "Friend", { Age = 30, Affection = 60 })
		NpcSystem.Ensure(friend)
		friend.Goal = "Family"
		friend.Married = true
		NpcSystem.Apply(player, state, friend, ACTIONS.HaveChild, { Logs = 1, Events = 0 })
		expect.equal(friend.Children, 1, "child born")
		expect.truthy(friend.Goal ~= "Family", "new goal chosen")
		PlayerState.Track(player, nil)
	end)

	test("NPCs can trigger life events about themselves", function()
		local _, state = newCharacter("NpcF", 20)
		local friend = PlayerState.CreateRelationship(state, "Friend", { Age = 20, Affection = 60 })
		local rival = PlayerState.CreateRelationship(state, "Rival", { Age = 20, Affection = 20 })
		expect.falsy(Engine.TriggerFor(state, "friend_in_need", rival), "event filters still apply")
		expect.truthy(Engine.TriggerFor(state, "friend_in_need", friend), "queued for the friend")
		expect.equal(state.EventQueue[1].TargetId, friend.Id, "the friend is the event's person")
		expect.falsy(Engine.TriggerFor(state, "friend_in_need", friend), "not queued twice")
	end)

	test("yearly journal lines and triggered events are capped", function()
		NpcSystem.SetSeed(11)
		local player, state = newCharacter("NpcG", 30)
		for _ = 1, RelConfig.MaxRelationships - #state.Relationships do
			PlayerState.CreateRelationship(state, "Friend", { Age = 30, Affection = 95 })
		end
		for year = 1, 10 do
			state.Age += 1
			state.EventQueue = {}
			local logs = #state.Log
			NpcSystem.YearTick(player, state)
			expect.truthy(#state.Log - logs <= Npc.MaxJournalEntriesPerYear, "journal cap in year " .. year)
			expect.truthy(#state.EventQueue <= Npc.MaxTriggeredEventsPerYear, "event cap in year " .. year)
		end
		PlayerState.Track(player, nil)
	end)

	test("drifting apart removes the friend safely", function()
		local player, state = newCharacter("NpcH", 30)
		local friend = PlayerState.CreateRelationship(state, "Friend", { Age = 30, Affection = 10 })
		NpcSystem.Ensure(friend)
		NpcSystem.Apply(player, state, friend, ACTIONS.Drift, { Logs = 1, Events = 0 })
		expect.falsy(PlayerState.FindRelationship(state, friend.Id), "removed")
		PlayerState.Track(player, nil)
	end)

	test("autonomy stays off when its module is disabled", function()
		local modules = GamePack.Manifest.Modules
		local saved = modules.NpcAutonomy
		modules.NpcAutonomy = false
		local ok, err = pcall(function()
			local player, state = newCharacter("NpcI", 0)
			for _ = 1, 5 do
				state.PendingEvent, state.EventQueue = nil, {}
				YearSystem.Advance(player, state)
			end
			for _, rel in state.Relationships do
				expect.falsy(rel.Personality, "no NPC profile without the module")
			end
			PlayerState.Track(player, nil)
		end)
		modules.NpcAutonomy = saved
		if not ok then
			error(err, 0)
		end
	end)

	test("long simulations keep NPCs active and the world valid", function()
		NpcSystem.SetSeed(3)
		local employed, married, memories = 0, 0, 0
		for life = 1, 15 do
			local player, state = newCharacter("NpcSim" .. life, 0)
			local rng = Random.new(life)
			for _ = 1, 400 do
				local guard = 0
				while state.PendingEvent and not state.Dead and guard < 10 do
					guard += 1
					local entry = state.PendingEvent
					local event = Engine.Get(entry.Pool, entry.Id)
					local choices = {}
					for i, option in event.Options do
						if Requirements.Check(state, option.Requires) then table.insert(choices, i) end
					end
					Engine.Resolve(player, state, entry.Id, choices[rng:NextInteger(1, #choices)])
					if not PlayerState.CheckDeath(player) then Engine.PresentNext(player, state) end
				end
				if state.Dead then break end
				YearSystem.Advance(player, state)
				assert(#state.Relationships <= RelConfig.MaxRelationships, "relationship cap")
				-- Measured during the life: by old age most peers have died or drifted away.
				for _, rel in state.Relationships do
					assert(#(rel.Memories or {}) <= PlayerState.MaxMemories, "memory cap")
					assert(rel.Affection >= 0 and rel.Affection <= 100, "affection range")
					if rel.Occupation then employed += 1 end
					if rel.Married and rel.Type ~= "Mother" and rel.Type ~= "Father" then married += 1 end
					memories += #(rel.Memories or {})
				end
			end
			expect.truthy(state.Dead, "life " .. life .. " ended")
			PlayerState.Track(player, nil)
		end
		expect.truthy(employed > 0, "NPCs found work (" .. employed .. ")")
		expect.truthy(married > 0, "NPCs married (" .. married .. ")")
		expect.truthy(memories > 0, "NPCs formed memories (" .. memories .. ")")
	end)
end
