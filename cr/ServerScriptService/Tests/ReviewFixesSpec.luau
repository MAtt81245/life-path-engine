--[[
	Regression tests for problems found in the final code review.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ServerScriptService.Modules
local PlayerState = require(Modules.PlayerState)
local Engine = require(Modules.LifeEventsEngine)
local RelationshipSystem = require(Modules.RelationshipSystem)

local function newCharacter(name: string, age: number)
	local player = { Name = name }
	local state = PlayerState.CreateState({}, "Human")
	state.Age = age
	PlayerState.Track(player, state)
	return player, state
end

return function(test, expect)
	test("a delayed consequence is dropped when its person is gone", function()
		local player, state = newCharacter("ReviewA", 30)
		local friend = PlayerState.CreateRelationship(state, "Friend", { Affection = 60 })
		Engine.ApplyEffects(player, state, { Id = "loan", TargetId = friend.Id }, {
			Delayed = { InYears = 2, Text = "{name} repays you.", Effects = { Money = 800 } },
		})
		PlayerState.RemoveRelationship(state, friend.Id)
		local money = state.Money
		state.Age = 32
		Engine.ProcessScheduled(player, state)
		expect.equal(state.Money, money, "no repayment from someone who is gone")
		expect.equal(#state.ScheduledEffects, 0, "consequence discarded")
		PlayerState.Track(player, nil)
	end)

	test("consequences without a person still apply", function()
		local player, state = newCharacter("ReviewB", 30)
		Engine.ApplyEffects(player, state, { Id = "cave" }, { Delayed = { InYears = 1, Text = "Legacy.", Effects = { Money = 50 } } })
		local money = state.Money
		state.Age = 31
		Engine.ProcessScheduled(player, state)
		expect.equal(state.Money, money + 50, "applied")
		PlayerState.Track(player, nil)
	end)

	test("losing a partner clears the married flag", function()
		local player, state = newCharacter("ReviewC", 60)
		PlayerState.CreateRelationship(state, "Partner", { Age = 250, Affection = 90 })
		state.Flags.Married = true
		RelationshipSystem.YearTick(player, state)
		expect.falsy(state.Flags.Married, "widowed characters can marry again")
		PlayerState.Track(player, nil)
	end)

	test("malformed wheel requests are rejected without spending karma", function()
		local WheelSystem = require(game:GetService("ServerScriptService").Modules.WheelSystem)
		local player, state = newCharacter("ReviewD", 80)
		state.Karma = 1000
		expect.falsy(WheelSystem.Handle(player, state, "SpinTalent", 1), "alive characters cannot spin")
		state.Dead = true
		for _, slot in { 0, 99, 1.5, "1", {} } do
			expect.falsy(WheelSystem.Handle(player, state, "SpinTalent", slot), "slot " .. tostring(slot))
		end
		expect.falsy(WheelSystem.Handle(player, state, "Bogus"), "unknown action")
		expect.equal(state.Karma, 1000, "no karma spent")
		expect.truthy(state.Dead, "still on the wheel")
		PlayerState.Track(player, nil)
	end)

	test("save preparation never applies data from the future", function()
		local state = {}
		expect.falsy(PlayerState.PrepareSave({ Name = "ReviewE" }, state, { Version = PlayerState.SaveVersion + 1, Lives = 2 }), "rejected")
		expect.truthy(state.ReadOnly, "session protected")
	end)
end
