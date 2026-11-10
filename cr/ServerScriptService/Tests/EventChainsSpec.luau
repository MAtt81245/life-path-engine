--[[
	Event chains: follow-ups (same year and delayed), delayed consequences,
	inherited targets, cooldowns and chain validation.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerState = require(ServerScriptService.Modules.PlayerState)
local Engine = require(ServerScriptService.Modules.LifeEventsEngine)
local Content = require(ReplicatedStorage.Shared.Content)
local Validator = require(ReplicatedStorage.Shared.ContentValidator)

local Events = Content.Get("YearlyEventsConfig").Events
local POOL = "YearlyEventsConfig"

local function newCharacter(name: string, age: number)
	local player = { Name = name }
	local state = PlayerState.CreateState({}, "Human")
	state.Age = age
	PlayerState.Track(player, state)
	return player, state
end

-- These cases use base event content as fixtures; packs that replace it skip them.
local function needEvents(expect, ...)
	for _, id in { ... } do
		expect.skipUnless(Events[id], "active pack has no event '" .. id .. "'")
	end
end

local function advanceTo(player, state, age: number)
	while state.Age < age do
		state.Age += 1
		Engine.ProcessScheduled(player, state)
	end
end

return function(test, expect)
	test("a delayed follow-up fires years later about the same person", function()
		needEvents(expect, "stolen_notes", "notes_thief_returns")
		local player, state = newCharacter("ChainA", 14)
		local entry = { Pool = POOL, Id = "stolen_notes", NewName = "Rui Zhao" }
		Engine.ApplyEffects(player, state, entry, Events.stolen_notes.Options[1].Effects)
		local rival = PlayerState.FindRelationship(state, entry.TargetId)
		expect.truthy(rival and rival.Name == "Rui Zhao", "new rival becomes the chain target")
		expect.equal(#state.ScheduledEvents, 1, "follow-up scheduled")
		expect.equal(state.ScheduledEvents[1].DueAge, 18, "due in 4 years")

		advanceTo(player, state, 17)
		expect.equal(#state.EventQueue, 0, "not due yet")
		advanceTo(player, state, 18)
		Engine.PresentNext(player, state)
		expect.truthy(state.PendingEvent and state.PendingEvent.Id == "notes_thief_returns", "follow-up presented")
		expect.equal(state.PendingEvent.TargetId, rival.Id, "same person")

		expect.truthy(Engine.Resolve(player, state, "notes_thief_returns", 1), "resolved")
		expect.equal(rival.Category, "Friend", "the rival became a friend")
		PlayerState.Track(player, nil)
	end)

	test("a same-year follow-up is queued immediately", function()
		needEvents(expect, "mugging", "watch_captain")
		local player, state = newCharacter("ChainB", 25)
		Engine.ApplyEffects(player, state, { Pool = POOL, Id = "mugging" }, Events.mugging.Options[1].Effects)
		expect.equal(#state.EventQueue, 1, "queued")
		expect.equal(state.EventQueue[1].Id, "watch_captain", "follow-up id")
		PlayerState.Track(player, nil)
	end)

	test("delayed consequences apply once, on time", function()
		needEvents(expect, "friend_in_need")
		expect.skipUnless(Events.friend_in_need.Options[1].Effects.Delayed, "active pack's friend_in_need has no delayed loan")
		local player, state = newCharacter("ChainC", 30)
		local friend = PlayerState.CreateRelationship(state, "Friend", { Affection = 50 })
		Engine.ApplyEffects(player, state, { Pool = POOL, Id = "friend_in_need", TargetId = friend.Id }, Events.friend_in_need.Options[1].Effects)
		local money, affection = state.Money, friend.Affection
		advanceTo(player, state, 32)
		expect.equal(state.Money, money, "nothing before it is due")
		advanceTo(player, state, 33)
		expect.equal(state.Money, money + 800, "loan repaid")
		expect.equal(friend.Affection, affection + 10, "affection applied to the same friend")
		advanceTo(player, state, 40)
		expect.equal(state.Money, money + 800, "applied only once")
		PlayerState.Track(player, nil)
	end)

	test("chains are skipped when their person is gone", function()
		needEvents(expect, "notes_thief_returns")
		local player, state = newCharacter("ChainD", 20)
		local rival = PlayerState.CreateRelationship(state, "Rival", { Affection = 20 })
		Engine.Schedule(state, { Id = "notes_thief_returns", InYears = 1 }, { TargetId = rival.Id })
		PlayerState.RemoveRelationship(state, rival.Id)
		advanceTo(player, state, 21)
		Engine.PresentNext(player, state)
		expect.falsy(state.PendingEvent, "no prompt for a missing person")

		Engine.Schedule(state, { Id = "notes_thief_returns" }, nil)
		Engine.PresentNext(player, state)
		expect.falsy(state.PendingEvent, "inherited target required")
		PlayerState.Track(player, nil)
	end)

	test("chain-only events never roll and cooldowns block repeats", function()
		needEvents(expect, "purse_owner", "lost_wallet")
		local player, state = newCharacter("ChainE", 20)
		for age = 0, 120, 10 do
			state.Age = age
			expect.falsy(Engine.IsEligible(state, "purse_owner", Events.purse_owner), "chain-only at age " .. age)
		end
		state.Age = 20
		expect.truthy(Engine.IsEligible(state, "lost_wallet", Events.lost_wallet), "eligible before it happens")
		state.EventLastAge.lost_wallet = 20
		state.Age = 25
		expect.falsy(Engine.IsEligible(state, "lost_wallet", Events.lost_wallet), "blocked during cooldown")
		state.Age = 30
		expect.truthy(Engine.IsEligible(state, "lost_wallet", Events.lost_wallet), "allowed after cooldown")
		PlayerState.Track(player, nil)
	end)

	test("death clears pending chains", function()
		local player, state = newCharacter("ChainF", 40)
		Engine.Schedule(state, { Id = "purse_owner", InYears = 5 }, nil)
		state.Health = 0
		expect.truthy(PlayerState.CheckDeath(player), "died")
		expect.equal(#state.ScheduledEvents, 0, "scheduled events cleared")
		expect.equal(#state.ScheduledEffects, 0, "scheduled effects cleared")
		PlayerState.Track(player, nil)
	end)

	test("the validator catches broken chains", function()
		local events = { Events = {
			start = { Title = "Start", Text = "x", MinAge = 1, MaxAge = 5, Weight = 0.5, Options = {
				{ Text = "a", Result = "b", Effects = { FollowUp = { Id = "missing_event", InYears = 2 }, Delayed = { Effects = { Money = 5 } } } },
			} },
			lonely = { Title = "Lonely", Text = "x", ChainOnly = true, Options = { { Text = "a", Result = "b" } } },
			wrong_inherit = { Title = "Bad", Text = "{name}", MinAge = 1, MaxAge = 5, Weight = 0.1, Target = { Inherit = true }, Options = { { Text = "a", Result = "b" } } },
		} }
		local report = Validator.Run({ YearlyEventsConfig = events })
		expect.contains(report.Errors, "unknown event 'missing_event'", "errors")
		expect.contains(report.Errors, "Delayed needs InYears", "errors")
		expect.contains(report.Errors, "Inherit is only valid on ChainOnly", "errors")
		expect.contains(report.Warnings, "never referenced", "warnings")
	end)
end
