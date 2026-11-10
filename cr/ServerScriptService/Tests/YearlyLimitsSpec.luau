--[[
	BitLife-style yearly limits: a few action slots per year, a per-activity yearly
	cap, a yearly social budget and each interaction once per person per year.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = game:GetService("ServerScriptService").Modules

local PlayerState = require(Modules.PlayerState)
local TrainingSystem = require(Modules.TrainingSystem)
local RelationshipSystem = require(Modules.RelationshipSystem)
local YearSystem = require(Modules.YearSystem)
local Engine = require(Modules.LifeEventsEngine)
local Content = require(ReplicatedStorage.Shared.Content)
local GamePack = require(ReplicatedStorage.Shared.GamePack)

local Training = Content.Get("TrainingConfig")
local RelConfig = Content.Get("RelationshipsConfig")

local function newCharacter(name: string, age: number)
	local player = { Name = name }
	local state = PlayerState.CreateState({}, nil)
	state.Age = age
	PlayerState.StartYear(state)
	PlayerState.Track(player, state)
	return player, state
end

-- A cost-free, always-available action with the default yearly cap.
local function repeatableAction(state)
	for _, action in Training.Actions do
		local known, reason = TrainingSystem.Check(state, action.Id)
		if known and not reason and not action.MaxPerYear and not action.QiFraction and (action.Health or 0) >= 0 then
			return action
		end
	end
	return nil
end

return function(test, expect)
	test("a new save starts with 2 action diamonds and 3 social interactions", function()
		local state = PlayerState.CreateState({}, nil)
		expect.equal(PlayerState.GetMaxActions(state), 2, "two diamonds in Life 1")
		expect.equal(PlayerState.GetMaxSocial(state), 3, "three social interactions")
		expect.equal(state.Actions, 2, "year starts full")
	end)

	test("actions spend yearly slots and stop when none are left", function()
		local player, state = newCharacter("Slots", 40)
		local max = PlayerState.GetMaxActions(state)
		expect.truthy(max >= Training.BaseActionSlots and max <= Training.MaxActionSlots, "slots within range")
		expect.equal(state.Actions, max, "full at the start of the year")
		local used = 0
		for _, action in Training.Actions do
			if TrainingSystem.Perform(player, state, action.Id) then
				used += 1
			end
			state.Health = PlayerState.GetMaxHealth(state)
		end
		expect.equal(used, max, "exactly max actions performed")
		expect.equal(state.Actions, 0, "no slots left")
		local adultAction
		for _, action in Training.Actions do
			if not action.MaxAge and not action.Requires and action.MinAge <= state.Age then
				adultAction = adultAction or action
			end
		end
		local _, reason = TrainingSystem.Check(state, adultAction.Id)
		expect.truthy(reason and string.find(reason, "No actions left", 1, true), "explains: " .. tostring(reason))
		PlayerState.Track(player, nil)
	end)

	test("the same activity is capped per year", function()
		local player, state = newCharacter("Cap", 40)
		state.Actions = Training.MaxActionSlots -- room beyond the cap (a fresh life has only 2)
		local action = repeatableAction(state)
		expect.skipUnless(action, "no repeatable action")
		for i = 1, Training.DefaultMaxPerYear do
			expect.truthy(TrainingSystem.Perform(player, state, action.Id), "perform #" .. i)
		end
		local ok, reason = TrainingSystem.Perform(player, state, action.Id)
		expect.falsy(ok, "capped")
		expect.truthy(string.find(reason, "this year", 1, true), "explains: " .. tostring(reason))
		expect.truthy(state.Actions > 0, "slots remain for other activities")
		PlayerState.Track(player, nil)
	end)

	test("a new year refills slots and clears the yearly counters", function()
		local player, state = newCharacter("Refill", 40)
		state.Actions, state.Social = 0, 0
		state.ActionCounts = { Anything = 2 }
		state.SocialDone = { r1 = { SpendTime = true } }
		YearSystem.Advance(player, state)
		if not state.Dead then
			expect.equal(state.Actions, PlayerState.GetMaxActions(state), "slots refilled")
			expect.equal(next(state.ActionCounts), nil, "activity counters cleared")
			expect.equal(state.Social, PlayerState.GetMaxSocial(state), "social budget refilled")
			expect.equal(next(state.SocialDone), nil, "per-person marks cleared")
		end
		PlayerState.Track(player, nil)
	end)

	test("bonus slots stack but never pass the cap", function()
		local _, state = newCharacter("Bonus", 40)
		local base = PlayerState.GetMaxActions(state)
		local window = Training.SlotBonuses and Training.SlotBonuses[1]
		if window and (window.MaxAge or math.huge) < 40 then
			state.Age = window.MinAge
			expect.equal(PlayerState.GetMaxActions(state), math.min(Training.MaxActionSlots, base + window.Slots), "age window adds slots")
			state.Age = 40
		end
		local buffs = PlayerState.GetBuffs(state)
		buffs.ActionSlots = 10
		local freeCap = math.min(Training.FreeActionCap or Training.MaxActionSlots, Training.MaxActionSlots)
		expect.equal(PlayerState.GetMaxActions(state, buffs), freeCap, "free slots capped at FreeActionCap")
		state.Passes = { CelestialTimekeeper = true, ImmortalVIP = true }
		expect.equal(PlayerState.GetMaxActions(state, buffs), math.min(Training.MaxActionSlots, freeCap + 2), "golden slots on top, within MaxActionSlots")
		expect.truthy(base >= 1, "at least one slot")
	end)

	test("consumable action effects add slots for this year only", function()
		local player, state = newCharacter("Ginseng", 40)
		state.Actions = 1
		Engine.ApplyEffects(player, state, { Id = "probe" }, { Actions = 1 })
		expect.equal(state.Actions, 2, "one more action")
		Engine.ApplyEffects(player, state, { Id = "probe" }, { Actions = 99 })
		expect.equal(state.Actions, Training.MaxActionSlots, "never above the cap")
		PlayerState.Track(player, nil)
	end)

	test("each interaction once per person per year, within the social budget", function()
		expect.skipUnless(GamePack.IsEnabled("Relationships"), "Relationships disabled")
		local player, state = newCharacter("Social", 30)
		local friends = {}
		for i = 1, RelConfig.SocialPerYear + 1 do
			table.insert(friends, PlayerState.CreateRelationship(state, "Friend", { Affection = 50 }))
		end
		local buffs = PlayerState.GetBuffs(state)
		expect.truthy(RelationshipSystem.Interact(player, state, friends[1].Id, "SpendTime", buffs), "first visit")
		local ok, reason = RelationshipSystem.Interact(player, state, friends[1].Id, "SpendTime", buffs)
		expect.falsy(ok, "same interaction, same person, same year")
		expect.truthy(string.find(reason, "already", 1, true), "explains: " .. tostring(reason))
		for i = 2, RelConfig.SocialPerYear do
			expect.truthy(RelationshipSystem.Interact(player, state, friends[i].Id, "SpendTime", buffs), "visit " .. i)
		end
		expect.equal(state.Social, 0, "budget spent")
		local _, capped = RelationshipSystem.Interact(player, state, friends[#friends].Id, "SpendTime", buffs)
		expect.truthy(capped and string.find(capped, "No social interactions left", 1, true), "global cap: " .. tostring(capped))
		PlayerState.Track(player, nil)
	end)
end
