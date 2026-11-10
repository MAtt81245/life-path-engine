--[[
	Long-running simulation tests: whole lives played through the real server
	modules with a simulated player (a plain table, so no network traffic).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ServerScriptService.Modules
local PlayerState = require(Modules.PlayerState)
local YearSystem = require(Modules.YearSystem)
local Engine = require(Modules.LifeEventsEngine)
local Rng = require(Modules.Rng)
local TrainingSystem = require(Modules.TrainingSystem)
local CultivationSystem = require(Modules.CultivationSystem)
local Requirements = require(ReplicatedStorage.Shared.Requirements)
local GamePack = require(ReplicatedStorage.Shared.GamePack)
local Content = require(ReplicatedStorage.Shared.Content)
local LifeEvents = Content.Get("LifeEventsConfig")
local RelConfig = Content.Get("RelationshipsConfig")

local ACTIONS = { "ReadBooks", "PhysicalTraining", "Meditate", "StudyHard", "Socialize" }
-- A pack with its own training actions is simulated with those instead.
local Training = Content.Get("TrainingConfig")
if not Training.ById[ACTIONS[1]] then
	ACTIONS = {}
	for _, action in Training.Actions do
		table.insert(ACTIONS, action.Id)
	end
end

-- Plays until death (or maxYears). Returns how many times each event resolved.
local function playLife(player, state, maxYears: number, onYear)
	local resolved = {}
	for _ = 1, maxYears do
		local guard = 0
		while state.PendingEvent and not state.Dead and guard < 10 do
			guard += 1
			local entry = state.PendingEvent
			local event = Engine.Get(entry.Pool, entry.Id)
			local choice = 1
			for i, option in event.Options do
				if Requirements.Check(state, option.Requires) then
					choice = i
					break
				end
			end
			assert(Engine.Resolve(player, state, entry.Id, choice), "could not resolve " .. entry.Id)
			resolved[entry.Id] = (resolved[entry.Id] or 0) + 1
			if not PlayerState.CheckDeath(player) then
				Engine.PresentNext(player, state)
			end
		end
		if state.Dead then
			break
		end
		for _, action in ACTIONS do
			TrainingSystem.Perform(player, state, action)
		end
		if state.Qi:Ge(PlayerState.GetRequirement(state)) then
			CultivationSystem.Breakthrough(player, state)
		end
		YearSystem.Advance(player, state)
		if onYear then
			onYear(state)
		end
	end
	return resolved
end

local function checkInvariants(state)
	assert(state.Money == state.Money and math.abs(state.Money) < math.huge, "money must be finite")
	assert(state.Happiness >= 0 and state.Happiness <= 100, "happiness out of range")
	assert(state.Stress >= 0 and state.Stress <= 100, "stress out of range")
	assert(state.Health <= PlayerState.GetMaxHealth(state) + 1e-6, "health above max")
	assert(#state.Relationships <= RelConfig.MaxRelationships, "too many relationships")
	assert(state.Actions >= 0 and state.Social >= 0, "negative action or social budget")
end

return function(test, expect)
	test("creates a first-life character from race and talents", function()
		local state = PlayerState.CreateState({}, "Human")
		expect.equal(state.Age, 0, "age")
		expect.equal(state.Lives, 1, "lives")
		for _, stat in Content.Get("PlayerStatsConfig").Order do
			expect.truthy(state.Stats[stat], "starts with stat " .. stat)
		end
		expect.equal(state.Actions, PlayerState.GetMaxActions(state), "action slots start full")
		expect.truthy(#state.Relationships >= 2, "has a family")

		-- Base talent and race fixtures; a pack with its own talents skips the rest.
		expect.skipUnless(Content.Get("TalentsConfig").ById.chaos_body, "active pack has no 'chaos_body' talent")
		local gifted = PlayerState.CreateState({ "chaos_body" }, "Mutant")
		expect.truthy(PlayerState.GetMaxHealth(gifted) > PlayerState.GetMaxHealth(state), "talent raises max health")
		if GamePack.IsEnabled("Lineages") then
			expect.equal(gifted.Race, "Mutant", "chosen race")
			expect.truthy(PlayerState.GetStatXpMultiplier(gifted, "Strength") > 1.5, "race and talent multiply XP")
		else
			expect.equal(gifted.Race, "Human", "race selection ignored without Lineages")
		end
	end)

	-- A cultivator may legitimately still be alive (immortal) after 400 years.
	test("a full life stays valid every year and ends in death or immortality", function()
		Rng.Seed(2024) -- reproducible life
		local player = { Name = "SimPlayer" }
		local state = PlayerState.CreateState({}, "Human")
		PlayerState.Track(player, state)
		local resolved = playLife(player, state, 400, checkInvariants)
		PlayerState.Track(player, nil)
		Rng.Seed(nil)
		if state.Dead then
			expect.truthy(type(state.DeathCause) == "string", "death has a cause")
		else
			expect.truthy(PlayerState.GetMaxLifespan(state) > state.Age, "alive only within the lifespan")
		end
		expect.truthy(state.Age >= 20, "lived past 20 (age " .. state.Age .. ")")
		local best = 0
		for _, entry in state.Stats do
			best = math.max(best, entry.Level)
		end
		expect.truthy(best > 10, "stats progressed")
		local total = 0
		for id, count in resolved do
			total += count
			local event = Engine.Get("YearlyEventsConfig", id) or Engine.Get("LifeEventsConfig", id) or Engine.Get("TravelEventsConfig", id)
			if not event.Repeatable then
				expect.equal(count, 1, "non-repeatable event " .. id)
			end
		end
		expect.truthy(total >= 5, "several events happened (" .. total .. ")")
	end)

	test("reincarnation keeps karma and lineage", function()
		Rng.Seed(77)
		local player = { Name = "SimPlayer2" }
		local state = PlayerState.CreateState({}, "Human")
		PlayerState.Track(player, state)
		playLife(player, state, 120)
		Rng.Seed(nil)
		if not state.Dead then
			state.Health = 0 -- an immortal cultivator: end the life here
			PlayerState.CheckDeath(player)
		end
		expect.truthy(state.Dead, "died")
		local karma = state.Karma
		expect.truthy(karma > 0, "earned karma")
		local talent = Content.Get("TalentsConfig").List[1].Id
		state.Wheel.Talents[1] = talent
		expect.truthy(PlayerState.Reincarnate(player), "reincarnates")
		expect.equal(state.Talents[1], talent, "born with the wheel's talent")
		expect.equal(state.Lives, 2, "lives")
		expect.equal(state.Karma, karma, "free rebirth keeps karma")
		expect.equal(#state.Lineage, 1, "lineage records the past life")
		expect.falsy(state.Dead, "alive again")
		PlayerState.Track(player, nil)
	end)

	test("disabled modules stay out of the simulation", function()
		local modules = GamePack.Manifest.Modules
		local saved = table.clone(modules)
		modules.Cultivation, modules.Masters, modules.Relationships = false, false, false
		local ok, err = pcall(function()
			local player = { Name = "SimPlayer3" }
			local state = PlayerState.CreateState({}, "Human")
			PlayerState.Track(player, state)
			expect.equal(#state.Relationships, 0, "no family without Relationships")
			expect.falsy(TrainingSystem.Perform(player, state, "Meditate"), "Meditate needs Cultivation")
			playLife(player, state, 40)
			expect.truthy(state.Qi:IsZero(), "no Qi without Cultivation")
			expect.equal(#state.Relationships, 0, "no relationships created")
			for id in state.SeenEvents do
				expect.falsy(LifeEvents.Events[id], "cultivation event fired: " .. id)
			end
			PlayerState.Track(player, nil)
		end)
		for key, value in saved do
			modules[key] = value
		end
		if not ok then
			error(err, 0)
		end
	end)

	test("save preparation protects incompatible data", function()
		local player = { Name = "SimPlayer4" }
		local state = {}
		expect.falsy(PlayerState.PrepareSave(player, state, { Version = 99, Lives = 3 }), "newer save not applied")
		expect.truthy(state.ReadOnly, "newer save makes the session read-only")
		expect.falsy(PlayerState.PrepareSave(player, {}, { Version = 2, Lives = 3, Pack = "another_game" }), "foreign pack not applied")
		local current = { Version = PlayerState.SaveVersion, Lives = 3 }
		expect.equal(PlayerState.PrepareSave(player, {}, current), current, "current save applied as-is")
	end)
end
