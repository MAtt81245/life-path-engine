--[[
	Inventory: market rules, selling, consumables, equipment buffs, item effects
	and requirements from events, module gating and item validation. Items are
	picked by their properties, so the spec runs against any game pack.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerState = require(ServerScriptService.Modules.PlayerState)
local InventorySystem = require(ServerScriptService.Modules.InventorySystem)
local Engine = require(ServerScriptService.Modules.LifeEventsEngine)
local Content = require(ReplicatedStorage.Shared.Content)
local GamePack = require(ReplicatedStorage.Shared.GamePack)
local Requirements = require(ReplicatedStorage.Shared.Requirements)
local Validator = require(ReplicatedStorage.Shared.ContentValidator)
local Items = Content.Get("ItemsConfig")

local function find(predicate)
	for _, itemId in Items.Shop do
		local item = Items.ById[itemId]
		if GamePack.IsEnabled(item.Module) and predicate(item) then
			return item
		end
	end
	error("no shop item matches the test's needs")
end

local function newCharacter(age: number, money: number)
	local player = { Name = "InventoryTester" }
	local state = PlayerState.CreateState({}, "Human")
	state.Age, state.Money = age, money
	PlayerState.Track(player, state)
	return player, state
end

local function simple(item)
	return item.Requires == nil and (item.MinAge or 0) <= 30
end

return function(test, expect)
	test("buying spends money and respects market rules", function()
		local player, state = newCharacter(30, 100000)
		local item = find(function(i) return simple(i) and i.Use ~= nil end)
		expect.truthy(InventorySystem.Buy(player, state, item.Id), "bought")
		expect.equal(state.Money, 100000 - item.Price, "price paid")
		expect.equal(PlayerState.ItemCount(state, item.Id), 1, "in the bag")
		expect.falsy(InventorySystem.Buy(player, state, "no_such_item"), "unknown item")

		local gear = find(function(i) return simple(i) and i.Equip ~= nil end)
		expect.truthy(InventorySystem.Buy(player, state, gear.Id), "bought equipment")
		expect.falsy(InventorySystem.Buy(player, state, gear.Id), "equipment does not stack")

		local gated = find(function(i) return i.Requires ~= nil end)
		expect.falsy(Requirements.Check(state, gated.Requires), "test needs an unmet requirement")
		expect.falsy(InventorySystem.Buy(player, state, gated.Id), "requirements enforced")

		state.Money = 0
		expect.falsy(InventorySystem.Buy(player, state, item.Id), "cannot afford")
		PlayerState.Track(player, nil)
	end)

	test("items not on the market cannot be bought", function()
		local player, state = newCharacter(30, 100000)
		for _, item in Items.Items do
			if not table.find(Items.Shop, item.Id) then
				expect.falsy(InventorySystem.Buy(player, state, item.Id), item.Id .. " is not sold")
			end
		end
		PlayerState.Track(player, nil)
	end)

	test("selling pays and unequips the last copy", function()
		local player, state = newCharacter(30, 0)
		local gear = find(function(i) return i.Equip ~= nil end)
		PlayerState.AddItem(state, gear.Id, 1)
		expect.truthy(InventorySystem.Equip(player, state, gear.Id), "equipped")
		expect.truthy(InventorySystem.Sell(player, state, gear.Id), "sold")
		expect.equal(state.Money, Items.SellPrice(gear), "sale price")
		expect.equal(PlayerState.ItemCount(state, gear.Id), 0, "removed")
		expect.falsy(PlayerState.Inventory(state).Equipped[gear.Equip.Slot], "unequipped")
		expect.falsy(InventorySystem.Sell(player, state, gear.Id), "nothing left to sell")
		PlayerState.Track(player, nil)
	end)

	test("consumables apply effects, get used up and respect yearly limits", function()
		local player, state = newCharacter(30, 0)
		local healer = find(function(i) return i.Use and i.Use.Effects.Health ~= nil end)
		PlayerState.AddItem(state, healer.Id, 1)
		state.Health = 10
		expect.truthy(InventorySystem.Use(player, state, healer.Id), "used")
		expect.equal(state.Health, 10 + healer.Use.Effects.Health, "healed")
		expect.equal(PlayerState.ItemCount(state, healer.Id), 0, "consumed")

		local limited = find(function(i) return i.Use and i.Use.UsesPerYear ~= nil and i.Use.Effects.Qi == nil end)
		PlayerState.AddItem(state, limited.Id, limited.Use.UsesPerYear + 2)
		for n = 1, limited.Use.UsesPerYear do
			expect.truthy(InventorySystem.Use(player, state, limited.Id), "use " .. n)
		end
		expect.falsy(InventorySystem.Use(player, state, limited.Id), "yearly limit reached")
		state.Age += 1
		expect.truthy(InventorySystem.Use(player, state, limited.Id), "limit resets next year")
		PlayerState.Track(player, nil)
	end)

	test("equipment buffs apply only while equipped and while the module is on", function()
		expect.skipUnless(GamePack.IsEnabled("Inventory"), "Inventory is disabled in the active pack")
		local player, state = newCharacter(30, 0)
		local gear = find(function(i) return i.Equip ~= nil end)
		local key, value = next(gear.Equip.Buffs)
		local function buff()
			local buffs = PlayerState.GetBuffs(state)
			if type(value) == "table" then
				local sub = next(value)
				return buffs[key][sub] or 1
			end
			return buffs[key]
		end
		local before = buff()
		PlayerState.AddItem(state, gear.Id, 1)
		expect.equal(buff(), before, "owning is not enough")
		InventorySystem.Equip(player, state, gear.Id)
		expect.truthy(buff() ~= before, "equipped buff applies")

		local modules = GamePack.Manifest.Modules
		modules.Inventory = false
		local disabled = buff()
		modules.Inventory = true
		expect.equal(disabled, before, "no buffs with the module off")
		InventorySystem.Unequip(player, state, gear.Equip.Slot)
		expect.equal(buff(), before, "unequipped")
		PlayerState.Track(player, nil)
	end)

	test("events grant, remove and require items", function()
		expect.skipUnless(GamePack.IsEnabled("Inventory"), "Inventory is disabled in the active pack")
		local player, state = newCharacter(30, 0)
		local item = Items.Items[1]
		Engine.ApplyEffects(player, state, { Id = "test" }, { Items = { [item.Id] = 2 } })
		expect.equal(PlayerState.ItemCount(state, item.Id), math.min(2, Items.MaxStack(item)), "granted")
		local owned = PlayerState.ItemCount(state, item.Id)
		expect.truthy(Requirements.Check(state, { Items = { [item.Id] = owned } }), "requirement met")
		expect.falsy(Requirements.Check(state, { Items = { [item.Id] = owned + 1 } }), "requirement unmet")
		Engine.ApplyEffects(player, state, { Id = "test" }, { Items = { [item.Id] = -owned } })
		expect.equal(PlayerState.ItemCount(state, item.Id), 0, "removed")
		PlayerState.Track(player, nil)
	end)

	test("a new life starts with an empty inventory", function()
		local state = PlayerState.CreateState({}, "Human")
		local inventory = PlayerState.Inventory(state)
		expect.equal(next(inventory.Items), nil, "no items")
		expect.equal(next(inventory.Equipped), nil, "nothing equipped")
	end)

	test("the validator catches broken items", function()
		local broken = Content.DeepCopy(Content.Get("ItemsConfig", false))
		table.insert(broken.Items, { Id = "bad_gear", Name = "Bad", Category = "Equipment", Price = 5, Equip = { Slot = "Hat", Buffs = { Shiny = 2 } } })
		table.insert(broken.Items, { Id = "bad_food", Name = "Bad", Category = "Snack", Price = 5, Use = { Effects = { Items = { ghost_item = 1 } } } })
		table.insert(broken.Shop, "missing_item")
		local report = Validator.Run({ ItemsConfig = broken }, false)
		expect.contains(report.Errors, "unknown equipment slot 'Hat'", "errors")
		expect.contains(report.Errors, "unknown buff 'Shiny'", "errors")
		expect.contains(report.Errors, "unknown category 'Snack'", "errors")
		expect.contains(report.Errors, "unknown item 'ghost_item'", "errors")
		expect.contains(report.Errors, "unknown item 'missing_item'", "errors")
	end)
end
