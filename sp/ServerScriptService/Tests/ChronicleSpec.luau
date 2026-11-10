--[[
	2.0 engine, Phase 1: the living chronicle (world calendar, routine, Today's Omen),
	the birth screen (talent card, Quick Start, rerolls) and YOUR PATH (decision nodes,
	real choice counts, Return to This Path).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = game:GetService("ServerScriptService").Modules

local PlayerState = require(Modules.PlayerState)
local Engine = require(Modules.LifeEventsEngine)
local ChronicleSystem = require(Modules.ChronicleSystem)
local CreationSystem = require(Modules.CreationSystem)
local MonetizationSystem = require(Modules.MonetizationSystem)
local PathSystem = require(Modules.PathSystem)
local ChoiceStats = require(Modules.ChoiceStats)
local Content = require(ReplicatedStorage.Shared.Content)
local GamePack = require(ReplicatedStorage.Shared.GamePack)

local Chronicle = Content.Get("ChronicleConfig")
local Monetization = Content.Get("MonetizationConfig")
local Stats = Content.Get("PlayerStatsConfig")

local function character(name: string, age: number?)
	local player = { Name = name }
	local state = PlayerState.CreateState({}, nil)
	state.Age = age or state.Age
	PlayerState.Track(player, state)
	return player, state
end

-- A yearly event whose first two options need nothing (fixture for decisions).
local function plainEvent()
	for id, event in Content.Get("YearlyEventsConfig").Events do
		local options = event.Options or {}
		local second = options[2]
		if #options >= 2 and not options[1].Requires and not second.Requires and not event.Target
			and not (second.Effects and second.Effects.FollowUp) and not (second.FailEffects and second.FailEffects.FollowUp) then
			return id, event
		end
	end
	return nil
end

return function(test, expect)
	test("world calendar: Life 1 in StartYear, the next life after the death year, eras by year", function()
		local player, state = character("Calendar")
		expect.equal(ChronicleSystem.Data(state).BirthYear, Chronicle.StartYear, "Life 1 birth year")
		state.Age = 50
		ChronicleSystem.OnDeath(state, {})
		expect.equal(state.WorldYear, Chronicle.StartYear + 50, "death year remembered")
		state.Modules, state.Age = {}, 0
		ChronicleSystem.OnNewLife(state)
		local born = ChronicleSystem.Data(state).BirthYear
		expect.truthy(born >= Chronicle.StartYear + 50 + Chronicle.RebirthGap[1] and born <= Chronicle.StartYear + 50 + Chronicle.RebirthGap[2], "reborn after a gap")
		local first, last = Chronicle.Eras[1], Chronicle.Eras[#Chronicle.Eras]
		expect.equal(Chronicle.Era(last.From), last.Name, "latest era")
		expect.equal(Chronicle.Era(-1e9), first.Name, "first era")
		expect.equal(Chronicle.Stage(0).Id, Chronicle.Stages[1].Id, "stage by age")
		PlayerState.Track(player, nil)
	end)

	test("routine: the active one pays its gains every year; unknown or dead is refused", function()
		local player, state = character("Routine", 8)
		local knowledge = Stats.Roles and Stats.Roles.Knowledge
		expect.skipUnless(knowledge and state.Stats[knowledge], "pack has no knowledge stat")
		expect.truthy(ChronicleSystem.SetRoutine(state, "Study"), "set")
		local stat = state.Stats[knowledge]
		local before = stat.Level * 1e6 + stat.Xp
		ChronicleSystem.Hooks.YearTicks[1].Run(player, state, PlayerState.GetBuffs(state))
		expect.truthy(stat.Level * 1e6 + stat.Xp > before, "study XP paid")
		expect.truthy(string.find(ChronicleSystem.Data(state).LastRoutineGain or "", "XP", 1, true), "shown on the bar")
		expect.falsy(ChronicleSystem.SetRoutine(state, "Bogus"), "unknown routine")
		state.Dead = true
		expect.falsy(ChronicleSystem.SetRoutine(state, "Relax"), "dead")
		PlayerState.Track(player, nil)
	end)

	test("Today's Omen: one claim per real day", function()
		local player, state = character("Omen", 10)
		local day = 20000 * 86400
		expect.truthy(ChronicleSystem.ClaimOmen(player, state, nil, day), "first claim")
		expect.falsy(ChronicleSystem.ClaimOmen(player, state, nil, day + 3600), "same day")
		expect.equal(ChronicleSystem.Data(state).OmenDay, 20000, "the client sees today's claim")
		expect.truthy(Chronicle.OmensById[ChronicleSystem.Data(state).LastOmen], "remembers the omen")
		expect.truthy(ChronicleSystem.ClaimOmen(player, state, nil, day + 86400), "next day")
		PlayerState.Track(player, nil)
	end)

	test("birth screen: talent card, meta-currency reroll, Quick Start", function()
		local wheels = GamePack.CreationSpins()
		expect.skipUnless(wheels.Any, "this pack has no birth screen")
		local player, state = character("Newborn")
		expect.truthy(CreationSystem.Open(state), "open at birth")
		if wheels.Talent then
			expect.truthy(CreationSystem.Roll(player, state, "Talent"), "talent spin")
			expect.equal(state.Talents[1], state.Creation.Talent, "born with it")
			expect.equal(state.Creation.Spins, 2, "one free spin used")
		end
		local spins = state.Creation.Spins
		state.Karma = 0
		expect.falsy(CreationSystem.Roll(player, state, "RerollMeta"), "needs the meta currency")
		state.Karma = Monetization.BirthRerollMetaCost + 10
		expect.truthy(CreationSystem.Roll(player, state, "RerollMeta"), "paid reroll")
		expect.equal(state.Karma, 10, "cost paid")
		expect.equal(state.Creation.Spins, spins, "free spins kept")
		expect.truthy(CreationSystem.Roll(player, state, "Quick"), "quick start")
		expect.truthy(state.Creation.Done and state.Creation.Quick, "born at once")
		expect.equal(state.Creation.Spins, 0, "free spins rolled")
		expect.falsy(CreationSystem.Roll(player, state, "Bloodline"), "closed after birth")
		PlayerState.Track(player, nil)
	end)

	test("Reroll Fate (Robux) is refused after birth and refunds a late receipt", function()
		local player, state = character("LateRoll", 3)
		state.Creation.Done = true
		expect.falsy(MonetizationSystem.Handle(player, state, "BuyProduct", "BirthReroll", true), "no prompt once born")
		local before = state.Karma
		expect.truthy(MonetizationSystem.GrantProduct(player, state, "BirthReroll"), "late receipt still honoured")
		expect.equal(state.Karma - before, Monetization.BirthRerollMetaCost * 2, "refunded in the meta currency")
		expect.truthy(Monetization.ProductsById.BirthReroll.RandomItem, "flagged for PolicyService")
		expect.truthy(MonetizationSystem.PaidRandomAllowed(player), "simulated players are not policy-checked")
		PlayerState.Track(player, nil)
	end)

	test("YOUR PATH: decisions become nodes; a rewind restores the life, not the account", function()
		local id, event = plainEvent()
		expect.skipUnless(id, "pack has no plain two-option event")
		ChoiceStats.SetStore(false) -- memory only
		local player, state = character("Walker", math.max(event.MinAge or 0, 12))
		local moneyBefore = state.Money
		state.PendingEvent = { Pool = "YearlyEventsConfig", Id = id }
		expect.truthy(Engine.Resolve(player, state, id, 2), "resolved")
		local nodes = PathSystem.Data(state).Nodes
		expect.equal(#nodes, 1, "one node")
		local node = nodes[1]
		expect.equal(node.ChoiceIndex, 2, "your choice")
		expect.equal(#node.Options, #event.Options, "roads not taken kept")
		expect.truthy(node.Remembered ~= "" and node.Year == ChronicleSystem.WorldYear(state), "remembered in its year")
		expect.equal(ChoiceStats.Get(id)[2], 1, "counted for everyone")

		state.Money, state.Karma = moneyBefore + 99999, 77
		local ok = PathSystem.Rewind(player, state, node.Id)
		expect.truthy(ok, "rewound")
		expect.equal(state.Money, moneyBefore, "life restored")
		expect.equal(state.Karma, 77, "account kept")
		expect.truthy(state.PendingEvent and state.PendingEvent.Id == id, "the question is asked again")
		expect.equal(#PathSystem.Data(state).Nodes, 0, "later nodes gone")
		expect.falsy(PathSystem.Rewind(player, state, node.Id), "that future no longer exists")
		state.Dead = true
		expect.falsy(PathSystem.CanRewind(player, state, node.Id), "only living paths")
		PlayerState.Track(player, nil)
	end)

	test("Return to This Path needs a selected recent decision", function()
		local player, state = character("NoTarget", 20)
		expect.falsy(MonetizationSystem.Handle(player, state, "BuyProduct", "PathRewind", true), "nothing selected")
		expect.truthy(Monetization.ProductsById.PathRewind.Hidden, "not listed in the shop")
		PlayerState.Track(player, nil)
	end)
end
