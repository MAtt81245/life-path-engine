--[[
	Dynasty: ancestral heirlooms (consecrate, soul stacks per generation, descendant
	inheritance at 12, reclaiming from the old family), relatives met through events,
	and the family tree's memory decay (Shared/LineageMemory).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = game:GetService("ServerScriptService").Modules

local PlayerState = require(Modules.PlayerState)
local DynastySystem = require(Modules.DynastySystem)
local RegionSystem = require(Modules.RegionSystem)
local WheelSystem = require(Modules.WheelSystem)
local Requirements = require(ReplicatedStorage.Shared.Requirements)
local LineageMemory = require(ReplicatedStorage.Shared.LineageMemory)
local Content = require(ReplicatedStorage.Shared.Content)
local GamePack = require(ReplicatedStorage.Shared.GamePack)

local Tree = Content.Get("FamilyTreeConfig")

local function lifeWithHeirloom(name: string)
	local player = { Name = name }
	local state = PlayerState.CreateState({}, nil)
	PlayerState.Track(player, state)
	state.Age = 30
	PlayerState.AddItem(state, "iron_sword", 1)
	PlayerState.Inventory(state).Equipped.Weapon = "iron_sword"
	return player, state
end

local function rebirth(player, state, path)
	if not state.Dead then
		PlayerState.Die(player, "test")
	end
	state.Karma = 500
	WheelSystem.ChoosePath(player, state, path)
	WheelSystem.Confirm(player, state)
end

return function(test, expect)
	test("a consecrated item becomes an heirloom whose creator is never forgotten", function()
		expect.skipUnless(GamePack.IsEnabled("Dynasty") and GamePack.IsEnabled("Inventory"), "Dynasty/Inventory disabled")
		local player, state = lifeWithHeirloom("Smith")
		expect.falsy(DynastySystem.Consecrate(player, state, "Armor"), "nothing equipped there")
		expect.truthy(DynastySystem.Consecrate(player, state, "Weapon"), "consecrated")
		local creator = state.Name
		PlayerState.Die(player, "test")
		expect.equal(#state.Heirlooms, 1, "heirloom created")
		local heirloom = state.Heirlooms[1]
		expect.equal(heirloom.Creator, creator, "inscribed with the creator")
		expect.equal(state.Lineage[1].Heirloom, heirloom.Name, "the past-life record keeps it")
		local tier, preserved = LineageMemory.Tier(state.Lineage[1], 9, {})
		expect.equal(tier, "Clear", "never fades")
		expect.equal(preserved, "Heirloom", "preserved by the inscription")
		PlayerState.Track(player, nil)
	end)

	test("descendants inherit the heirloom at 12 with +5% soul stacks per generation", function()
		expect.skipUnless(GamePack.IsEnabled("Dynasty") and GamePack.IsEnabled("Samsara") and GamePack.IsEnabled("Inventory"), "modules disabled")
		local player, state = lifeWithHeirloom("Heir")
		DynastySystem.Consecrate(player, state, "Weapon")
		rebirth(player, state, "Descendant")
		rebirth(player, state, "Descendant")
		local heirloom = state.Heirlooms[1]
		expect.equal(heirloom.Generations, 2, "two generations")
		expect.falsy(heirloom.Lost, "kept by the family")
		expect.equal(PlayerState.ItemCount(state, "iron_sword"), 0, "not before the inherit age")
		local before = PlayerState.GetBuffs(state).AllStatXp
		state.Age = Tree.Heirloom.InheritAge
		DynastySystem.YearTick(player, state)
		expect.equal(PlayerState.ItemCount(state, "iron_sword"), 1, "inherited")
		expect.equal(heirloom.Holder, "Player", "held")
		expect.near(PlayerState.GetBuffs(state).AllStatXp / before, 1 + 2 * Tree.Heirloom.SoulStackPerGeneration, 1e-6, "soul stacks")
		PlayerState.Track(player, nil)
	end)

	test("a stranger must find the old family to reclaim the heirloom", function()
		expect.skipUnless(GamePack.IsEnabled("Dynasty") and GamePack.IsEnabled("Samsara") and GamePack.IsEnabled("World"), "modules disabled")
		local player, state = lifeWithHeirloom("Stranger")
		RegionSystem.SetRegion(state, "crimson")
		DynastySystem.Consecrate(player, state, "Weapon")
		rebirth(player, state, "Stranger")
		local heirloom = state.Heirlooms[1]
		expect.truthy(heirloom.Lost, "held by the old family")
		expect.equal(heirloom.Region, "crimson", "where the family lives")
		RegionSystem.SetRegion(state, "qinghe")
		expect.falsy(Requirements.Check(state, { LostHeirloomHere = true }), "not here")
		RegionSystem.SetRegion(state, "crimson")
		expect.truthy(Requirements.Check(state, { LostHeirloomHere = true }), "found the family")
		local text = DynastySystem.Hooks.Effects.ReclaimHeirloom(player, state, "Duel")
		expect.truthy(text and string.find(text, "win back", 1, true), "reclaimed: " .. tostring(text))
		expect.equal(heirloom.Holder, "Player", "yours again")
		PlayerState.Track(player, nil)
	end)

	test("relatives join the tree only through events, once each", function()
		expect.skipUnless(GamePack.IsEnabled("Dynasty"), "Dynasty disabled")
		local player = { Name = "Grandchild" }
		local state = PlayerState.CreateState({}, nil)
		PlayerState.Track(player, state)
		expect.equal(#DynastySystem.Data(state).Met, 0, "no filler relatives")
		expect.truthy(DynastySystem.Hooks.Effects.MeetRelative(player, state, "Grandfather"), "met")
		expect.falsy(DynastySystem.Hooks.Effects.MeetRelative(player, state, "Grandfather"), "once")
		expect.falsy(DynastySystem.Hooks.Effects.MeetRelative(player, state, "Bogus"), "unknown role")
		expect.equal(#DynastySystem.Data(state).Met, 1, "one relative")
		PlayerState.Track(player, nil)
	end)

	test("the mist of time: clear, fading, forgotten - delayed by Chronicler and Soul Retention", function()
		local entry = { Name = "Old Wu", Life = 1, Realm = "Mortal", RealmIndex = 1, Cause = "Natural death", Region = "qinghe", RegionName = "Qinghe" }
		expect.equal(LineageMemory.Tier(entry, Tree.ClearGenerations, {}), "Clear", "recent")
		expect.equal(LineageMemory.Tier(entry, Tree.ClearGenerations + 1, {}), "Fading", "oral history")
		expect.equal(LineageMemory.Tier(entry, Tree.FadingGenerations + 1, {}), "Forgotten", "forgotten")
		local upgrades = { AncestralChronicler = 2, SoulRetention = 2 }
		expect.equal(LineageMemory.Keep(upgrades), 3, "2 chronicler + 1 from soul retention")
		expect.equal(LineageMemory.Tier(entry, Tree.ClearGenerations + 3, upgrades), "Clear", "clear memory lasts longer")
		expect.equal(LineageMemory.Tier(entry, Tree.FadingGenerations + 3, upgrades), "Fading", "oral history lasts longer")
		expect.equal(LineageMemory.Tier(entry, Tree.FadingGenerations + 4, upgrades), "Forgotten", "but still fades")
		local forgotten = LineageMemory.Describe(entry, 9, {})
		expect.truthy(string.find(forgotten.Name, "Unknown Ancestor of Qinghe", 1, true), "stone label: " .. forgotten.Name)
		expect.equal(forgotten.Cause, LineageMemory.Lost, "details eroded")
		local fading = LineageMemory.Describe(entry, Tree.ClearGenerations + 1, {})
		expect.equal(fading.Occupation, LineageMemory.Lost, "occupation lost to time")
		entry.RealmIndex = Tree.ImmortalRealm
		local tier, preserved = LineageMemory.Tier(entry, 20, {})
		expect.truthy(tier == "Clear" and preserved == "Immortal", "immortals are remembered forever")
	end)
end
