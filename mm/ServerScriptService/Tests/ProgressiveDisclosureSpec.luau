--[[
	Progressive disclosure: infant actions, age windows, the Spirit Root gate on
	Meditate, milestone notices and the tab gates config.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = game:GetService("ServerScriptService").Modules

local PlayerState = require(Modules.PlayerState)
local TrainingSystem = require(Modules.TrainingSystem)
local MilestoneSystem = require(Modules.MilestoneSystem)
local Content = require(ReplicatedStorage.Shared.Content)
local GamePack = require(ReplicatedStorage.Shared.GamePack)

local Training = Content.Get("TrainingConfig")
local Gates = Content.Get("ProgressionGatesConfig")

local function baby(age: number)
	local state = PlayerState.CreateState({}, nil)
	state.Age = age
	PlayerState.StartYear(state)
	return state
end

local function available(state): { string }
	local ids = {}
	for _, action in Training.Actions do
		local known, reason = TrainingSystem.Check(state, action.Id)
		if known and not reason then
			table.insert(ids, action.Id)
		end
	end
	return ids
end

return function(test, expect)
	test("infants only crawl, listen and rest; those actions are outgrown", function()
		expect.skipUnless(Training.ById.CrawlPlay ~= nil, "no infant actions in this pack")
		local ids = available(baby(1))
		table.sort(ids)
		expect.equal(table.concat(ids, ","), "CrawlPlay,ListenParents,Relax", "infant actions")
		local _, reason = TrainingSystem.Check(baby(5), "CrawlPlay")
		expect.truthy(reason and string.find(reason, "outgrown", 1, true), "outgrown: " .. tostring(reason))
	end)

	test("actions unlock by age: study at 4, training at 7, weapons and masters at 12", function()
		expect.skipUnless(Training.ById.CrawlPlay ~= nil, "base pack ages only")
		local function can(age, id)
		local state = baby(age)
			state.Health = PlayerState.GetMaxHealth(state)
			local _, reason = TrainingSystem.Check(state, id)
			return reason == nil
		end
		expect.falsy(can(3, "ReadBooks"), "no study at 3")
		expect.truthy(can(4, "ReadBooks"), "study at 4")
		expect.falsy(can(6, "PhysicalTraining"), "no training at 6")
		expect.truthy(can(7, "PhysicalTraining"), "training at 7")
		expect.falsy(can(11, "PracticeSword"), "no weapons at 11")
		expect.truthy(can(12, "PracticeSword"), "weapons at 12")
	end)

	test("Meditate waits for the Spirit Root awakening", function()
		expect.skipUnless(GamePack.IsEnabled("Cultivation"), "Cultivation disabled")
		local state = baby(6)
		local _, reason = TrainingSystem.Check(state, "Meditate")
		expect.truthy(reason and string.find(reason, "Requires", 1, true), "locked: " .. tostring(reason))
		state.Flags.SpiritRoot = true
		_, reason = TrainingSystem.Check(state, "Meditate")
		expect.equal(reason, nil, "unlocked by the Spirit Root")
		local event = Content.Get("LifeEventsConfig").Events.spirit_root
		for i, option in event.Options do
			local effects = option.Effects.Flags or {}
			expect.truthy(table.find(effects, "SpiritRoot"), "option " .. i .. " awakens the root")
		end
	end)

	test("milestone birthdays announce what unfolds", function()
		for _, milestone in Gates.Milestones do
			expect.contains(MilestoneSystem.At(milestone.Age), string.sub(milestone.Text, 1, 12), "age " .. milestone.Age)
		end
		expect.equal(#MilestoneSystem.At(2), 0, "no milestone at 2")
	end)

	test("tab gates name real tabs and grow with age", function()
		for key, age in Gates.Tabs do
			expect.truthy(GamePack.TabKeys[key] or GamePack.Modules[key], "known tab " .. key)
			expect.truthy(type(age) == "number" and age >= 0 and age <= 18, key .. " age")
		end
		expect.truthy((Gates.Tabs.Masters or 0) >= (Gates.Tabs.Social or 0), "masters after bonds")
	end)
end
