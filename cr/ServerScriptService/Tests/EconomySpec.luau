--[[
	Economy guards. The family "Ask Help" exploit (spend time with and ask every
	relative for help every single year) must not fund the market for a child.
	Baseline before the rebalance (30 lives): median $11,057 from family by age 13,
	12 of 14 market items affordable.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ServerScriptService.Modules
local PlayerState = require(Modules.PlayerState)
local YearSystem = require(Modules.YearSystem)
local Engine = require(Modules.LifeEventsEngine)
local RelationshipSystem = require(Modules.RelationshipSystem)
local Requirements = require(ReplicatedStorage.Shared.Requirements)
local Content = require(ReplicatedStorage.Shared.Content)
local Items = Content.Get("ItemsConfig")
local RelConfig = Content.Get("RelationshipsConfig")

local LIVES = 20

local function median(values)
	table.sort(values)
	return values[math.ceil(#values / 2)]
end

-- How many market items (cheapest first) a sum of money buys.
local function affordable(money: number): number
	local prices = {}
	for _, itemId in Items.Shop do
		table.insert(prices, Items.ById[itemId].Price)
	end
	table.sort(prices)
	local count = 0
	for _, price in prices do
		if money < price then break end
		money -= price
		count += 1
	end
	return count
end

-- Plays to 18 asking every relative for help every year; returns family income at 13 and 18.
local function exploitLife(seed: number): (number, number)
	local player = { Name = "EconomyTester" .. seed }
	local state = PlayerState.CreateState({}, "Human")
	PlayerState.Track(player, state)
	local rng = Random.new(seed)
	local family, at13 = 0, 0
	while state.Age < 18 and not state.Dead do
		while state.PendingEvent and not state.Dead do
			local entry = state.PendingEvent
			local event = Engine.Get(entry.Pool, entry.Id)
			local choices = {}
			for i, option in event.Options do
				if Requirements.Check(state, option.Requires) then table.insert(choices, i) end
			end
			Engine.Resolve(player, state, entry.Id, choices[rng:NextInteger(1, #choices)])
			if not PlayerState.CheckDeath(player) then Engine.PresentNext(player, state) end
		end
		local buffs = PlayerState.GetBuffs(state)
		for _, rel in table.clone(state.Relationships) do
			if rel.Category == "Family" then
				RelationshipSystem.Interact(player, state, rel.Id, "SpendTime", buffs)
				local before = state.Money
				RelationshipSystem.Interact(player, state, rel.Id, "AskHelp", buffs)
				family += state.Money - before
			end
		end
		YearSystem.Advance(player, state)
		if state.Age == 13 then
			at13 = family
		end
	end
	PlayerState.Track(player, nil)
	return at13, family
end

return function(test, expect)
	test("family help cannot fund the market for a child", function()
		local by13, by18 = {}, {}
		for seed = 1, LIVES do
			local a, b = exploitLife(seed)
			table.insert(by13, a)
			table.insert(by18, b)
		end
		local median13, median18 = median(by13), median(by18)
		expect.truthy(median13 <= 1000, ("median family income by 13 is $%d"):format(median13))
		expect.truthy(affordable(median13) <= math.floor(#Items.Shop / 2), ("by 13 it buys %d of %d items"):format(affordable(median13), #Items.Shop))
		expect.truthy(median18 <= 3000, ("median family income by 18 is $%d"):format(median18))
		expect.truthy(median13 > 0, "children still get some pocket money")
	end)

	test("adult help stays within its bracket", function()
		local state = PlayerState.CreateState({}, "Human")
		state.Age = 30
		local parent = PlayerState.CreateRelationship(state, "Father", { Age = 55, Affection = 100 })
		local help = RelConfig.FamilyHelp
		local adult = help.Brackets[#help.Brackets]
		for _ = 1, 50 do
			local gift = RelationshipSystem.FamilyGift(state, parent)
			expect.truthy(gift >= adult.Min and gift <= adult.Max, "gift " .. gift)
		end
		parent.Occupation = "Merchant"
		for _ = 1, 50 do
			local gift = RelationshipSystem.FamilyGift(state, parent)
			expect.truthy(gift <= adult.Max * help.EmployedMult, "employed gift " .. gift)
		end
	end)

	test("underage siblings comfort instead of paying", function()
		local player = { Name = "EconomySibling" }
		local state = PlayerState.CreateState({}, "Human")
		state.Age = 10
		PlayerState.Track(player, state)
		local sibling = PlayerState.CreateRelationship(state, "Sibling", { Age = 12, Affection = 90 })
		local money, stress = state.Money, state.Stress
		local ok = RelationshipSystem.Interact(player, state, sibling.Id, "AskHelp", PlayerState.GetBuffs(state))
		expect.truthy(ok, "asked")
		expect.equal(state.Money, money, "no money from a child")
		expect.truthy(state.Stress <= stress, "comforted")
		PlayerState.Track(player, nil)
	end)
end
