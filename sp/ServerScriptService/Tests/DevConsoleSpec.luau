--[[
	DevConsole: Studio gate, commands and explanations. Also guards the refactors
	it relies on (Engine.WhyIneligible, TrainingSystem.Check, PlayerState.BuffSources).
	Written against whatever pack is active.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ServerScriptService.Modules
local DevConsole = require(Modules.DevConsole)
local PlayerState = require(Modules.PlayerState)
local Engine = require(Modules.LifeEventsEngine)
local TrainingSystem = require(Modules.TrainingSystem)
local Content = require(ReplicatedStorage.Shared.Content)
local GamePack = require(ReplicatedStorage.Shared.GamePack)

local Training = Content.Get("TrainingConfig")
local Talents = Content.Get("TalentsConfig")

local function newCharacter(name: string, age: number)
	local player = { Name = name }
	local state = PlayerState.CreateState({}, nil)
	state.Age = age
	PlayerState.Track(player, state)
	return player, state
end

local function run(player, line: string): string
	return table.concat(DevConsole.Execute(player, line), "\n")
end

local function events()
	local list = {}
	for _, pool in GamePack.Manifest.EventPools do
		if GamePack.IsEnabled(pool.Module) then
			for id, event in Content.Get(pool.Config).Events do
				table.insert(list, { Id = id, Event = event })
			end
		end
	end
	table.sort(list, function(a, b) return a.Id < b.Id end)
	return list
end

return function(test, expect)
	test("runs only in Studio and can be switched off", function()
		local player = newCharacter("DevGate", 10)
		expect.truthy(DevConsole.Enabled(), "enabled in Studio")
		ServerScriptService:SetAttribute("DevConsole", false)
		local off = run(player, "state")
		ServerScriptService:SetAttribute("DevConsole", nil)
		expect.truthy(string.find(off, "only runs in Studio", 1, true), "refused when off: " .. off)
		PlayerState.Track(player, nil)
	end)

	test("rejects bad input without throwing", function()
		local player = newCharacter("DevInput", 10)
		expect.truthy(string.find(run(player, "nope"), "Unknown command", 1, true), "unknown command")
		expect.truthy(string.find(table.concat(DevConsole.Execute(player, string.rep("x", 400)), ""), "characters", 1, true), "too long")
		expect.truthy(string.find(table.concat(DevConsole.Execute(player, 42 :: any), ""), "characters", 1, true), "not a string")
		expect.truthy(string.find(run({ Name = "Nobody" }, "state"), "No character", 1, true), "no state")
		local help = run(player, "help")
		for _, name in DevConsole.Commands() do
			expect.truthy(string.find(help, name, 1, true), "help lists " .. name)
		end
		PlayerState.Track(player, nil)
	end)

	test("reads and sets state within limits", function()
		local player, state = newCharacter("DevSet", 20)
		run(player, "set Money 1234")
		expect.equal(state.Money, 1234, "money")
		run(player, "set Happiness 500")
		expect.equal(state.Happiness, 100, "happiness clamped")
		expect.truthy(string.find(run(player, "set Name Bob"), "Fields:", 1, true), "unknown field refused")
		expect.equal(state.Name ~= "Bob", true, "name untouched")
		local stat = Content.Get("PlayerStatsConfig").Order[1]
		run(player, ("stat %s 33"):format(stat))
		expect.equal(state.Stats[stat].Level, 33, "stat level")
		expect.truthy(string.find(run(player, "get Stats." .. stat), "Level=33", 1, true), "get path")
		expect.truthy(string.find(run(player, "state"), state.Name, 1, true), "state summary")
		PlayerState.Track(player, nil)
	end)

	test("why action matches what TrainingSystem enforces", function()
		local player, state = newCharacter("DevWhy", 40)
		local action = Training.Actions[1]
		state.Actions = 0
		local _, reason = TrainingSystem.Check(state, action.Id)
		expect.truthy(reason, "blocked without energy")
		expect.truthy(string.find(run(player, "why action " .. action.Id), reason, 1, true), "same reason")
		state.Actions, state.ActionCounts = 6, {}
		local known, now = TrainingSystem.Check(state, action.Id)
		if known and not now then
			expect.truthy(string.find(run(player, "why action " .. action.Id), "available", 1, true), "available")
		end
		PlayerState.Track(player, nil)
	end)

	test("event explanations agree with the yearly roll for every event", function()
		local player, state = newCharacter("DevEvents", 25)
		for _, entry in events() do
			local reason = Engine.WhyIneligible(state, entry.Id, entry.Event)
			expect.equal(Engine.IsEligible(state, entry.Id, entry.Event), reason == nil, entry.Id)
		end
		local listing = run(player, "events")
		expect.truthy(string.find(listing, "event(s)", 1, true), "events listing")
		PlayerState.Track(player, nil)
	end)

	test("presents an event on demand and resolves it", function()
		local player, state = newCharacter("DevEvent", 30)
		local chosen
		for _, entry in events() do
			if not entry.Event.Target and not entry.Event.ChainOnly then
				chosen = entry
				break
			end
		end
		expect.skipUnless(chosen, "no untargeted event in the active pack")
		run(player, "event " .. chosen.Id)
		expect.truthy(state.PendingEvent and state.PendingEvent.Id == chosen.Id, "presented")
		expect.truthy(string.find(run(player, "event " .. chosen.Id), "Resolve the pending event", 1, true), "one at a time")
		local choice = 1
		for i, option in chosen.Event.Options do
			if require(ReplicatedStorage.Shared.Requirements).Check(state, option.Requires) then
				choice = i
				break
			end
		end
		expect.truthy(string.find(run(player, "choose " .. choice), "Resolved", 1, true), "resolved")
		expect.truthy(state.SeenEvents[chosen.Id], "recorded as seen")
		PlayerState.Track(player, nil)
	end)

	test("advances time, resolving events with auto", function()
		local player, state = newCharacter("DevYear", 20)
		local out = run(player, "year 5 auto")
		expect.truthy(state.Age == 25 or state.Dead, "five years later: " .. out)
		expect.falsy(state.PendingEvent, "no event left pending")
		PlayerState.Track(player, nil)
	end)

	test("buff sources merge into exactly GetBuffs", function()
		local player, state = newCharacter("DevBuffs", 20)
		local talent = Talents.List[1]
		state.Talents = { talent.Id }
		local sources = PlayerState.BuffSources(state)
		local labels = {}
		for _, source in sources do
			table.insert(labels, source.Label)
		end
		expect.contains(labels, "Talent: " .. talent.Name, "talent listed")
		expect.truthy(string.find(run(player, "buffs"), "Talent: " .. talent.Name, 1, true), "buffs command")
		local total = PlayerState.GetBuffs(state)
		for key, value in talent.Buffs do
			if type(value) == "number" then
				expect.truthy(total[key] ~= PlayerState.NewBuffs()[key], "talent changes " .. key)
			end
		end
		PlayerState.Track(player, nil)
	end)

	test("adds relationships within the cap", function()
		expect.skipUnless(GamePack.IsEnabled("Relationships"), "Relationships disabled")
		local player, state = newCharacter("DevNpc", 20)
		local before = #state.Relationships
		run(player, "npc Friend 70")
		expect.equal(#state.Relationships, before + 1, "friend added")
		expect.equal(state.Relationships[#state.Relationships].Affection, 70, "affection")
		PlayerState.Track(player, nil)
	end)
end
