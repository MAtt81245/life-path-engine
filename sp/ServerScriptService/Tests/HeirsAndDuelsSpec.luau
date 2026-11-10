--[[
	Heir handover at the child's real age (young) or an age-25 snapshot (adult), rebirth as
	a newborn grandchild, grandchildren born to your children, the 3-exchange Tactical
	Clash resolver, and the True Immortal ascension endgame.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = game:GetService("ServerScriptService").Modules

local PlayerState = require(Modules.PlayerState)
local DynastySystem = require(Modules.DynastySystem)
local WheelSystem = require(Modules.WheelSystem)
local DuelSystem = require(Modules.DuelSystem)
local AscensionSystem = require(Modules.AscensionSystem)
local Rng = require(Modules.Rng)
local Content = require(ReplicatedStorage.Shared.Content)
local GamePack = require(ReplicatedStorage.Shared.GamePack)

local Duel = Content.Get("DuelConfig")
local Realms = Content.Get("RealmsConfig")

local function parentWithChild(name: string, childAge: number)
	local player = { Name = name }
	local state = PlayerState.CreateState({}, nil)
	PlayerState.Track(player, state)
	state.Age = 50
	state.Talents = { "iron_bones" }
	local spouse = PlayerState.CreateRelationship(state, "Partner", { Name = "Mei Lin", Age = 50, Affection = 90 })
	spouse.Genetics = { Race = state.Race, Grade = "Rare", Trait = "QiAffinity" }
	local child = DynastySystem.Conceive(player, state, spouse)
	child.Age = childAge
	return player, state, child, spouse
end

local function heirModules(): boolean
	return GamePack.IsActive("Dynasty") and GamePack.IsEnabled("Samsara")
end

return function(test, expect)
	test("a young heir is taken over at their real age, grown up and with gates unlocked", function()
		expect.skipUnless(heirModules(), "Dynasty/Samsara disabled")
		local player, state, child = parentWithChild("YoungHeir", 14)
		child.Genetics.Upbringing = "Martial"
		PlayerState.Die(player, "test")
		expect.truthy(WheelSystem.ChooseHeir(player, state, child.Id, "TakeOver"), "chosen")
		expect.truthy(WheelSystem.Confirm(player, state), "reborn")
		expect.equal(state.Name, child.Name, "you are the child")
		expect.equal(state.Age, 14, "at their real age")
		expect.truthy(state.Flags.SpiritRoot, "the Spirit Root woke years ago")
		expect.truthy(state.Stats.Strength.Level >= math.floor(14 * DynastySystem.GrowthPerYear), "stats grew with the years")
		local parent
		for _, rel in state.Relationships do
			if rel.Type == "Parent" then parent = rel end
		end
		expect.truthy(parent and parent.Age == 50, "your spouse is your parent, not rewound")
		PlayerState.Track(player, nil)
	end)

	test("an adult heir is taken over as an age-25 snapshot", function()
		expect.skipUnless(heirModules(), "Dynasty/Samsara disabled")
		local player, state, child = parentWithChild("AdultHeir", 40)
		PlayerState.Die(player, "test")
		WheelSystem.ChooseHeir(player, state, child.Id, "TakeOver")
		WheelSystem.Confirm(player, state)
		expect.equal(state.Age, WheelSystem.TakeOverCap, "capped snapshot")
		local parent
		for _, rel in state.Relationships do
			if rel.Type == "Parent" then parent = rel end
		end
		expect.truthy(parent and parent.Age == 50 - (40 - WheelSystem.TakeOverCap), "the family is wound back with you")
		PlayerState.Track(player, nil)
	end)

	test("rebirth as a newborn grandchild: your child becomes your parent", function()
		expect.skipUnless(heirModules(), "Dynasty/Samsara disabled")
		local player, state, child = parentWithChild("Grandchild", 30)
		PlayerState.Die(player, "test")
		local ok, reason = WheelSystem.ChooseHeir(player, state, child.Id, "Grandchild")
		expect.truthy(ok, "adult children can have you: " .. tostring(reason))
		expect.truthy(WheelSystem.Confirm(player, state), "reborn")
		expect.equal(state.Age, 0, "a newborn")
		local parent, grand = nil, nil
		for _, rel in state.Relationships do
			if rel.Type == "Parent" then parent = rel end
			if rel.Type == "Grandparent" then grand = rel end
		end
		expect.truthy(parent and parent.Name == child.Name, "the old child is your parent")
		expect.truthy(grand and grand.Name == "Mei Lin", "the old spouse is your grandparent")
		expect.equal(state.Lineage[1].NextPath, "Descendant", "bloodline link")
		PlayerState.Track(player, nil)
	end)

	test("young children cannot be asked for a grandchild", function()
		expect.skipUnless(heirModules(), "Dynasty/Samsara disabled")
		local player, state, child = parentWithChild("Teen", 12)
		PlayerState.Die(player, "test")
		local ok, reason = WheelSystem.ChooseHeir(player, state, child.Id, "Grandchild")
		expect.falsy(ok, "too young")
		expect.truthy(reason and string.find(reason, "too young", 1, true), "explains: " .. tostring(reason))
		PlayerState.Track(player, nil)
	end)

	test("your children's children appear as grandchildren with combined genetics", function()
		expect.skipUnless(GamePack.IsActive("Dynasty"), "Dynasty disabled")
		local player, state, child = parentWithChild("Grandparent", 28)
		local kid = DynastySystem.AddGrandchild(state, child)
		expect.truthy(kid and kid.Genetics and kid.Genetics.Race, "a grandchild with genetics")
		expect.equal(#child.Offspring, 1, "tracked on the child")
		expect.truthy(child.SpouseGenetics, "the child's spouse has genetics too")
		local age = kid.Age
		require(Modules.RelationshipSystem).YearTick(player, state)
		expect.equal(kid.Age, age + 1, "grandchildren grow up")
		PlayerState.Track(player, nil)
	end)

	test("the clash resolver: stance advantage, best of 3, quick resolve and outcomes", function()
		local player = { Name = "Duelist" }
		local state = PlayerState.CreateState({}, nil)
		PlayerState.Track(player, state)
		state.Age = 30
		local outcomes = {}
		DuelSystem.Outcomes.TestDuel = function(_, _, duel, won)
			table.insert(outcomes, won)
			return if won then "won" else "lost"
		end
		Rng.Seed(3)
		local wins = 0
		for _ = 1, 60 do
			DuelSystem.Start(player, state, { Kind = "TestDuel", FoeName = "Dummy", Difficulty = 1 })
			local duel = state.PendingDuel
			-- Always counter the foe's style: the advantage should win most duels.
			local counter
			for id, stance in Duel.Stances do
				if stance.Beats == duel.Foe.Style then counter = id end
			end
			local guard = 0
			while not duel.Done and guard < 5 do
				guard += 1
				DuelSystem.Exchange(player, state, counter)
			end
			expect.truthy(duel.Done, "ends within 3 exchanges")
			expect.truthy(#duel.Log <= 3 and math.max(duel.Wins, duel.Losses) == Duel.WinsNeeded, "best of 3")
			if duel.Won then wins += 1 end
			DuelSystem.Close(state)
		end
		Rng.Seed(nil)
		expect.equal(#outcomes, 60, "every duel reported its outcome")
		expect.truthy(wins > 30, ("countering the foe's style wins most duels (%d/60)"):format(wins))
		DuelSystem.Start(player, state, { Kind = "TestDuel", FoeName = "Dummy" })
		DuelSystem.Quick(player, state)
		expect.truthy(state.PendingDuel.Done and state.PendingDuel.Result, "quick resolve finishes with a result")
		expect.truthy(DuelSystem.Close(state), "closed")
		DuelSystem.Start(player, state, { Kind = "TestDuel", FoeName = "Dummy" })
		DuelSystem.Hooks.YearTicks[1].Run(player, state)
		expect.equal(state.PendingDuel, nil, "an open duel resolves when the year advances")
		DuelSystem.Outcomes.TestDuel = nil
		PlayerState.Track(player, nil)
	end)

	test("ascension at True Immortal 9: Karma, the title and a Divine Legacy for every future life", function()
		expect.skipUnless(GamePack.IsEnabled("Cultivation"), "Cultivation disabled")
		local player = { Name = "Ascendant" }
		local state = PlayerState.CreateState({}, nil)
		PlayerState.Track(player, state)
		state.Age = 500
		expect.falsy(AscensionSystem.Ascend(player, state), "not at the peak yet")
		state.RealmIndex, state.SubLevel = #Realms.Realms, Realms.SubLevels
		local karma = state.Karma
		expect.truthy(AscensionSystem.Ascend(player, state), "ascended")
		expect.truthy(state.Dead, "the life ends")
		expect.truthy(state.Karma >= karma + AscensionSystem.AscensionKarma, "massive Karma")
		expect.equal(state.Ascensions, 1, "counted")
		expect.truthy(state.Codex.Titles[AscensionSystem.TitleId], "title in the Codex")
		PlayerState.Reincarnate(player)
		expect.truthy(state.Flags.HeavenlyAscendant, "every later life can claim the title")
		local divine
		for _, buff in state.LifeBuffs do
			if buff.Kind == "Divine" then divine = buff end
		end
		expect.truthy(divine and math.abs(divine.Buffs.AllStatXp - AscensionSystem.DivineMult) < 1e-6, "+10% Divine Legacy")
		PlayerState.Track(player, nil)
	end)
end
