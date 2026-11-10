--[[
	3.0 engine, Phase 3: world history and organic rebirth, birth anomalies, Legends
	(thrones, family weapon, relics, hall), bonds, schooling, the World hub, raids, the
	journal and Legacy Tree, and the store (products, one-time, Second Life, codes,
	save slots, ULTIMATE). Cases skip when the active pack has the module off.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = game:GetService("ServerScriptService").Modules

local PlayerState = require(Modules.PlayerState)
local HistorySystem = require(Modules.HistorySystem)
local LegendsSystem = require(Modules.LegendsSystem)
local BondSystem = require(Modules.BondSystem)
local SchoolingSystem = require(Modules.SchoolingSystem)
local WorldHubSystem = require(Modules.WorldHubSystem)
local RaidSystem = require(Modules.RaidSystem)
local JournalSystem = require(Modules.JournalSystem)
local MonetizationSystem = require(Modules.MonetizationSystem)
local CosmeticSystem = require(Modules.CosmeticSystem)
local SkillSystem = require(Modules.SkillSystem)
local Content = require(ReplicatedStorage.Shared.Content)
local GamePack = require(ReplicatedStorage.Shared.GamePack)

local Stats = Content.Get("PlayerStatsConfig")

local function character(name: string, age: number)
	local player = { Name = name }
	local state = PlayerState.CreateState({}, nil)
	state.Age = age
	PlayerState.Track(player, state)
	return player, state
end

local function need(expect, module: string)
	expect.skipUnless(GamePack.IsActive(module), "pack has " .. module .. " off")
end

local function strong(state)
	for _, stat in Stats.Order do
		state.Stats[stat] = { Level = 400, Xp = 0 }
	end
end

return function(test, expect)
	test("world history: events and deeds outlive the life; organic rebirth as heir or random soul", function()
		local player, state = character("Elder", 60)
		HistorySystem.WorldEvent(player, state, "succession")
		HistorySystem.Record(state, "A statue of Elder is raised.", "deed")
		local history = HistorySystem.World(state).History
		expect.equal(#history, 2, "two chronicle lines")
		expect.truthy(HistorySystem.World(state).Ruler, "a ruler was crowned")
		local class = state.Modules.Birth.Class
		local region = state.Modules.World and state.Modules.World.Region
		PlayerState.Die(player, "old age", { Final = true })
		expect.truthy(state.Dead, "dead")
		expect.truthy(HistorySystem.Rebirth(player, state, "Heir"), "continued as heir")
		expect.falsy(state.Dead, "alive again")
		expect.equal(state.Modules.Birth.Rebirth, "Heir", "heir birth")
		expect.equal(state.Modules.Birth.Class, class, "family class kept")
		if region then
			expect.equal(state.Modules.World.Region, region, "family city kept")
		end
		expect.equal(#HistorySystem.World(state).History >= 2, true, "the chronicle survives the rebirth")
		PlayerState.Die(player, "test", { Final = true })
		expect.truthy(HistorySystem.Rebirth(player, state, "Random"), "random soul")
		expect.equal(state.Modules.Birth.Rebirth, "Random", "random birth")
		expect.falsy(HistorySystem.Rebirth(player, state, "Random"), "only the dead choose")
		PlayerState.Track(player, nil)
	end)

	test("birth anomalies: Heavenly Restriction caps mana for good; Frail caps the body", function()
		-- Packs with their own stat sets lack Mana / Strength; only caps on stats they have apply.
		local player, state = character("Anomaly", 0)
		HistorySystem.ApplyAnomaly(state, "HeavenlyRestriction")
		if state.Stats.Mana then
			PlayerState.AddStatXp(player, state, "Mana", 100000)
			expect.equal(state.Stats.Mana.Level, 0, "no mana, ever")
		end
		if GamePack.IsActive("Arcana") then
			expect.equal(require(Modules.ArcanaSystem).MaxMana(state), 0, "empty pool")
		end
		if GamePack.IsActive("Skills") then
			expect.truthy((PlayerState.GetBuffs(state).SwordDamageMult or 1) > 1, "the body answers")
		end
		local _, frail = character("Frail", 0)
		HistorySystem.ApplyAnomaly(frail, "Frail")
		local checked = 0
		for stat, cap in Content.Get("HistoryConfig").AnomaliesById.Frail.StatCaps or {} do
			if frail.Stats[stat] then
				PlayerState.AddStatXp(player, frail, stat, 100000)
				expect.truthy(frail.Stats[stat].Level <= cap, stat .. " ceiling")
				checked += 1
			end
		end
		PlayerState.Track(player, nil)
		expect.skipUnless(checked > 0 or state.Stats.Mana, "pack has none of the capped stats")
	end)

	test("Legends: vacant throne, family weapon for heirs, two leads recover a relic, hall score", function()
		need(expect, "Legends")
		local player, state = character("Legend", 30)
		strong(state)
		state.Actions, state.Money = 5, 5000
		expect.truthy(LegendsSystem.Throne(player, state, "Challenge", 4), "claimed the vacant seat")
		expect.equal(LegendsSystem.World(state).Thrones[4].Holder, state.Name, "seat held")
		expect.falsy(LegendsSystem.Throne(player, state, "Challenge", 6), "one challenge a year")
		SkillSystem.SetLevel(player, state, "Crafting", 40)
		expect.truthy(LegendsSystem.ForgeWeapon(player, state), "family weapon")
		expect.equal(LegendsSystem.World(state).FamilyWeapon.Tier, 2, "tier from Crafting 40")
		local leads = 0
		for _ = 1, 2 do
			if LegendsSystem.FindLead(player, state, "Boss") then leads += 1 end
		end
		expect.equal(leads, 2, "bosses always leave a lead")
		expect.truthy(next(LegendsSystem.World(state).Relics) ~= nil, "a relic for every generation")
		PlayerState.Die(player, "glory", { Final = true })
		expect.truthy(state.Lineage[1].Score and state.Lineage[1].Epitaph and state.Lineage[1].Throne, "hall entry")
		expect.truthy(LegendsSystem.Share(player, state, 1), "shared")
		expect.falsy(LegendsSystem.Share(player, state, 1), "shared once")
		PlayerState.Track(player, nil)
	end)

	test("bonds grow with social actions; schooling pays and charges", function()
		local player, state = character("Kin", 10)
		local mother
		for _, rel in state.Relationships do
			if rel.Type == "Mother" then mother = rel end
		end
		expect.skipUnless(mother, "no family in this pack")
		BondSystem.Gain(player, state, mother, "TrainTogether")
		BondSystem.Gain(player, state, mother, "Gift")
		expect.equal(mother.Bond.Level, 1, "bond level 1")
		expect.truthy(PlayerState.GetBuffs(state).AllStatXp > 1, "family bonds speed growth")
		state.Money = 100
		expect.falsy(SchoolingSystem.SetMode(state, "Tutor"), "tutors need wealth")
		state.Money = 1000
		expect.truthy(SchoolingSystem.SetMode(state, "Tutor"), "tutor")
		SchoolingSystem.YearTick(player, state)
		expect.equal(state.Money, 880, "120 a year")
		PlayerState.Track(player, nil)
	end)

	test("World hub: shared rotations, crafting from drops, Sell All", function()
		need(expect, "WorldHub")
		local event = WorldHubSystem.Event(1000000)
		expect.equal(WorldHubSystem.Event(1000000), event, "same event for the same moment")
		expect.equal(#WorldHubSystem.Merchant(1000000), Content.Get("WorldHubConfig").MerchantCount, "three offers")
		local player, state = character("Crafter", 20)
		PlayerState.AddItem(state, "boar_tusk", 5)
		expect.truthy(WorldHubSystem.Craft(player, state, 1), "Hunter's Token")
		expect.equal(PlayerState.Inventory(state).Items.boar_tusk, 2, "tusks spent")
		local money = state.Money
		expect.truthy(require(Modules.InventorySystem).SellAll(player, state, "boar_tusk"), "sold")
		expect.equal((PlayerState.Inventory(state).Items.boar_tusk or 0), 0, "none left")
		expect.truthy(state.Money > money, "paid")
		PlayerState.Track(player, nil)
	end)

	test("raids: a party of two, tickets spent, tokens on victory", function()
		need(expect, "Raids")
		local a, stateA = character("Leader", 30)
		local b, stateB = character("Friend", 30)
		strong(stateA)
		strong(stateB)
		expect.truthy(RaidSystem.Create(a, "Normal"), "party opened")
		expect.truthy(RaidSystem.QuickJoin(b, "Normal"), "quick join")
		expect.falsy(RaidSystem.Start(b), "only the leader starts")
		local ok, _, tone = RaidSystem.Start(a)
		expect.truthy(ok, "raid run")
		expect.equal(RaidSystem.Data(stateA).Tickets, Content.Get("RaidConfig").StartTickets - 1, "ticket spent")
		-- Odds cap at 95%, so a loss is rare but legal.
		if tone == "good" then
			expect.truthy(RaidSystem.Data(stateB).Tokens > 0, "tokens for the whole party")
		else
			expect.equal(RaidSystem.Data(stateB).Tokens, 0, "no tokens on defeat")
		end
		expect.falsy(RaidSystem.Start(a), "the party disbands after the run")
		RaidSystem.Leave(a)
		PlayerState.Track(a, nil)
		PlayerState.Track(b, nil)
	end)

	test("journal: daily quests, one login claim a day, life goals; Legacy Tree at birth", function()
		local player, state = character("Diarist", 20)
		local quest = JournalSystem.Quests()[1]
		JournalSystem.Count(state, quest.Counter, quest.Need)
		expect.equal(JournalSystem.Data(state).Daily.Progress[quest.Id], quest.Need, "quest done")
		expect.truthy(JournalSystem.ClaimLogin(player, state), "login reward")
		expect.falsy(JournalSystem.ClaimLogin(player, state), "once a day")
		JournalSystem.CheckGoals(player, state)
		expect.truthy(state.Modules.Goals.Done.goal4, "came of age")
		state.Upgrades.FamilyFortune = 2
		local before = state.Money
		JournalSystem.ApplyLegacyTree(state)
		expect.equal(state.Money - before, 1000, "Family Fortune")
		PlayerState.Track(player, nil)
	end)

	test("store: micro products, one-time Starter Pack, Second Life, codes, slots, ULTIMATE", function()
		local player, state = character("Patron", 20)
		local actions = state.Actions
		expect.truthy(MonetizationSystem.GrantProduct(player, state, "Hourglass"), "hourglass")
		expect.equal(state.Actions, actions + 3, "+3 actions")
		expect.truthy(MonetizationSystem.Handle(player, state, "BuyProduct", "StarterPack", true), "starter pack")
		expect.falsy(MonetizationSystem.Handle(player, state, "BuyProduct", "StarterPack", true), "once per account")
		state.Passes = { SecondLife = true }
		PlayerState.Die(player, "ambush")
		expect.falsy(state.Dead, "escaped death")
		PlayerState.Die(player, "ambush again")
		expect.truthy(state.Dead, "once per life")
		local _, alive = character("Coder", 20)
		expect.truthy(CosmeticSystem.Redeem(player, alive, "free99"), "code")
		expect.falsy(CosmeticSystem.Redeem(player, alive, "FREE99"), "code once")
		expect.falsy(CosmeticSystem.Switch(player, alive, 2), "slot 2 locked")
		alive.Passes = { SaveSlot2 = true }
		local first = alive.Name
		expect.truthy(CosmeticSystem.Switch(player, alive, 2), "slot 2")
		expect.truthy(CosmeticSystem.Switch(player, alive, 1), "back to slot 1")
		expect.equal(alive.Name, first, "the first character returns")
		local _, baby = character("Chosen", 0)
		local first, second = Stats.Order[1], Stats.Order[2]
		expect.falsy(CosmeticSystem.ChooseStats(player, baby, { [first] = 100 }), "needs ULTIMATE")
		baby.Passes = { Ultimate = true }
		expect.truthy(CosmeticSystem.ChooseStats(player, baby, { [first] = 500, [second] = 1 }), "chosen")
		expect.equal(baby.Stats[first].Level, 100, "clamped to 100")
		expect.equal(baby.Stats[second].Level, 10, "clamped to 10")
		PlayerState.Track(player, nil)
	end)
end
