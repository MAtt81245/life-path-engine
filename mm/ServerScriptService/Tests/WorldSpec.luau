--[[
	World module: birth regions, region modifiers and hazards, travel rules (age,
	roads, requirements, action + fee) and road encounters.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = game:GetService("ServerScriptService").Modules

local PlayerState = require(Modules.PlayerState)
local RegionSystem = require(Modules.RegionSystem)
local Rng = require(Modules.Rng)
local Content = require(ReplicatedStorage.Shared.Content)
local GamePack = require(ReplicatedStorage.Shared.GamePack)
local Requirements = require(ReplicatedStorage.Shared.Requirements)

local Regions = Content.Get("WorldRegionsConfig")

local function character(name: string, age: number)
	local player = { Name = name }
	local state = PlayerState.CreateState({}, nil)
	PlayerState.Track(player, state)
	state.Age = age
	PlayerState.StartYear(state)
	return player, state
end

return function(test, expect)
	test("every new life is born in a starter region with its modifiers", function()
		expect.skipUnless(GamePack.IsEnabled("World"), "World disabled")
		local seen = {}
		Rng.Seed(11)
		for _ = 1, 60 do
			local state = PlayerState.CreateState({}, nil)
			local region = Regions.ById[state.Modules.World.Region]
			expect.truthy(region and region.Starter, "starter region")
			seen[region.Id] = true
		end
		Rng.Seed(nil)
		local starters = 0
		for _, region in Regions.Regions do
			if region.Starter then
				starters += 1
				expect.truthy(seen[region.Id], "rolled " .. region.Id)
			end
		end
		expect.truthy(starters >= 1, "at least one birthplace")
		local _, state = character("Kunlun", 20)
		RegionSystem.SetRegion(state, "kunlun")
		local withRegion = PlayerState.GetBuffs(state).QiMult
		PlayerState.SetLifeBuff(state, "Region", nil, nil)
		expect.near(withRegion / PlayerState.GetBuffs(state).QiMult, Regions.ById.kunlun.Buffs.QiMult, 1e-6, "Qi density")
	end)

	test("travel costs an action diamond and the fee, needs a road and the destination's requirements", function()
		expect.skipUnless(GamePack.IsEnabled("World"), "World disabled")
		local player, state = character("Traveler", 10)
		RegionSystem.SetRegion(state, "qinghe")
		state.Money = 5000
		local reason = RegionSystem.Check(state, "capital")
		expect.truthy(reason and string.find(reason, "travel alone", 1, true), "too young: " .. tostring(reason))
		state.Age = 13
		reason = RegionSystem.Check(state, "ruins")
		expect.truthy(reason and string.find(reason, "No road", 1, true), "not a neighbor: " .. tostring(reason))
		reason = RegionSystem.Check(state, "kunlun")
		expect.truthy(reason and string.find(reason, "Requires", 1, true), "realm gate: " .. tostring(reason))
		if Regions.ById.capital.Requires then
			reason = RegionSystem.Check(state, "capital")
			expect.truthy(reason and string.find(reason, "Requires", 1, true), "capital gate: " .. tostring(reason))
			state.RealmIndex = Regions.ById.capital.Requires.MinRealm or state.RealmIndex
		end
		local actions, money = state.Actions, state.Money
		local ok = RegionSystem.Travel(player, state, "capital")
		expect.truthy(ok, "traveled")
		expect.equal(state.Modules.World.Region, "capital", "arrived")
		expect.equal(actions - state.Actions, Regions.TravelSlots, "one diamond")
		expect.equal(money - state.Money, Regions.ById.capital.TravelFee, "fee")
		expect.truthy(Requirements.Check(state, { Region = "capital" }), "Region requirement")
		state.Actions = 0
		reason = RegionSystem.Check(state, "qinghe")
		expect.truthy(reason and string.find(reason, "No actions", 1, true), "needs a diamond: " .. tostring(reason))
		PlayerState.Track(player, nil)
	end)

	test("journeys roll a road encounter", function()
		expect.skipUnless(GamePack.IsEnabled("World"), "World disabled")
		local player, state = character("Road", 20)
		RegionSystem.SetRegion(state, "qinghe")
		state.RealmIndex = math.max(state.RealmIndex, (Regions.ById.capital.Requires or {}).MinRealm or 1)
		state.Money = 5000
		local encounters = 0
		for _ = 1, 6 do
			state.Actions, state.PendingEvent, state.EventQueue = 3, nil, {}
			local target = if state.Modules.World.Region == "qinghe" then "capital" else "qinghe"
			RegionSystem.Travel(player, state, target)
			local pending = state.PendingEvent or state.EventQueue[1]
			if pending then
				encounters += 1
				local event = Content.Get("TravelEventsConfig").Events[pending.Id]
				expect.truthy(event and event.Trigger == "Travel", "a road event: " .. tostring(pending.Id))
			end
		end
		expect.equal(encounters, 6, "every journey has an encounter")
		PlayerState.Track(player, nil)
	end)

	test("the Blood Marsh drains the righteous but feeds demonic cultivators", function()
		expect.skipUnless(GamePack.IsEnabled("World"), "World disabled")
		local player, state = character("Marsh", 30)
		RegionSystem.SetRegion(state, "marsh")
		state.Alignment = 10
		local health = state.Health
		RegionSystem.YearTick(player, state)
		expect.equal(state.Health - health, Regions.ById.marsh.Hazard.Health, "resentment hurts")
		local righteousQi = PlayerState.GetBuffs(state).QiMult
		state.Alignment = -40
		health = state.Health
		RegionSystem.YearTick(player, state)
		expect.equal(state.Health, health, "demonic cultivators are immune")
		expect.near(PlayerState.GetBuffs(state).QiMult / righteousQi, Regions.ById.marsh.DemonicBuffs.QiMult, 1e-6, "demonic Qi bonus")
		PlayerState.Track(player, nil)
	end)

	test("every region is reachable by road and roads go both ways", function()
		local reached, frontier = { [Regions.Default] = true }, { Regions.Default }
		while #frontier > 0 do
			local id = table.remove(frontier)
			for _, other in Regions.ById[id].Neighbors do
				expect.truthy(Regions.AreNeighbors(other, id), ("road %s <-> %s"):format(id, other))
				if not reached[other] then
					reached[other] = true
					table.insert(frontier, other)
				end
			end
		end
		for _, region in Regions.Regions do
			expect.truthy(reached[region.Id], region.Id .. " reachable")
		end
	end)
end
