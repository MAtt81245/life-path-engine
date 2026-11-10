--[[
	BalanceReport: plays many lives of the game with several bot
	policies through the real server modules, then turns the results into
	diagnostics (crashes, invalid states, early deaths, dominant strategies,
	passive or runaway resources, unreachable content, thin content).

	Runs are reproducible: every life is seeded (Rng + NpcSystem) from Seed and
	the life number, and every policy replays the same seeds, so policies are
	compared on the same starting families and the same event luck.

	Run it on a playtest server:
		local BalanceReport = require(game.ServerScriptService.Tools.BalanceReport)
		print(BalanceReport.Format(BalanceReport.Run({ Lives = 20, Seed = 1 })))

	Thresholds live in BalanceReport.Defaults; a pack may override any of them
	with GameManifest.Balance = { ... }.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = script.Parent.Parent:WaitForChild("Modules")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Content = require(Shared:WaitForChild("Content"))
local GamePack = require(Shared:WaitForChild("GamePack"))
local Requirements = require(Shared:WaitForChild("Requirements"))
local Rng = require(Modules:WaitForChild("Rng"))
local PlayerState = require(Modules:WaitForChild("PlayerState"))
local YearSystem = require(Modules:WaitForChild("YearSystem"))
local Engine = require(Modules:WaitForChild("LifeEventsEngine"))
local TrainingSystem = require(Modules:WaitForChild("TrainingSystem"))
local CultivationSystem = require(Modules:WaitForChild("CultivationSystem"))
local CareerSystem = require(Modules:WaitForChild("CareerSystem"))
local MasterSystem = require(Modules:WaitForChild("MasterSystem"))
local RelationshipSystem = require(Modules:WaitForChild("RelationshipSystem"))
local ProgressionSystem = require(Modules:WaitForChild("ProgressionSystem"))
local InventorySystem = require(Modules:WaitForChild("InventorySystem"))
local NpcSystem = require(Modules:WaitForChild("NpcSystem"))
local SystemRegistry = require(Modules:WaitForChild("SystemRegistry"))
local WheelSystem = require(Modules:WaitForChild("WheelSystem"))
local RegionSystem = require(Modules:WaitForChild("RegionSystem"))
local DynastySystem = require(Modules:WaitForChild("DynastySystem"))
local CreationSystem = require(Modules:WaitForChild("CreationSystem"))
local DuelSystem = require(Modules:WaitForChild("DuelSystem"))

local Training = Content.Get("TrainingConfig")
local Studies = Content.Get("StudiesAndCareerConfig")
local Masters = Content.Get("MastersConfig")
local Masteries = Content.Get("MasteriesConfig")
local Titles = Content.Get("TitlesConfig")
local Items = Content.Get("ItemsConfig")
local RelConfig = Content.Get("RelationshipsConfig")
local Realms = Content.Get("RealmsConfig")
local StatsConfig = Content.Get("PlayerStatsConfig")

local BalanceReport = {}

BalanceReport.Defaults = {
	Lives = 20,
	MaxYears = 400,
	Seed = 1,
	EarlyDeathRatio = 0.5, -- a death before this share of the character's own lifespan is early...
	EarlyDeathShare = 0.5, -- ...and this share of all lives dying early is a warning
	IdleProgressRatio = 0.8, -- idle reaching this share of the best active progress
	DominanceRatio = 1.5, -- focused progress this many times the balanced progress
	MoneyRunaway = 1e9, -- money this large is treated as unbounded
	MoneyGrowthPerYear = 0.15, -- yearly growth sustained over two GrowthWindow spans in a row...
	MoneyGrowthFloor = 1e6, -- ...ending at least this rich...
	MoneyGrowthBase = 1e4, -- ...from a starting balance at least this large (not pocket money)
	GrowthWindow = 30,
	CeilingShare = 0.5, -- share of lives reaching the final realm that counts as "end-game reached"
	MinEventsPerLife = 5,
	MaxActionsPerYear = 20,
	YieldEvery = 25, -- simulated years between task.wait() calls, so long runs never freeze Studio (0 = never)
	FreshPeakMin = 4, -- with Cultivation, a fresh life should peak between these realm indexes
	FreshPeakMax = 5, -- (Core Formation .. Nascent Soul)
}

local LEVEL_ORDER = { ERROR = 1, WARN = 2, INFO = 3 }

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

local function median(list): number
	if #list == 0 then
		return 0
	end
	local sorted = table.clone(list)
	table.sort(sorted)
	return sorted[(#sorted + 1) // 2]
end

local function finite(x): boolean
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end

local function bump(map, key, amount: number?)
	map[key] = (map[key] or 0) + (amount or 1)
end

local function topKey(map): (string?, number)
	local best, count = nil, 0
	for key, n in map do
		if n > count or (n == count and best and tostring(key) < tostring(best)) then
			best, count = key, n
		end
	end
	return best, count
end

-- What the game allows right now (TrainingSystem.Check: slots, yearly limits, age...).
local function usable(state, action): boolean
	local known, reason = TrainingSystem.Check(state, action.Id)
	return known ~= nil and reason == nil
end

local function xpValue(action): number
	local total = action.ProficiencyXp or 0
	for _, xp in action.StatXp or {} do
		total += xp
	end
	return total
end

-- Best usable action by score(action) / energy; nil if none scores above 0.
local function bestAction(state, score)
	local best, bestValue = nil, 0
	for _, action in Training.Actions do
		if usable(state, action) then
			local value = score(action) / math.max(1, action.Slots or 1)
			if value > bestValue then
				best, bestValue = action, value
			end
		end
	end
	return best
end

local function perform(ctx, action): boolean
	if ctx.performed >= ctx.options.MaxActionsPerYear then
		return false
	end
	local ok = TrainingSystem.Perform(ctx.player, ctx.state, action.Id)
	if ok then
		ctx.performed += 1
		bump(ctx.acc.Actions, action.Id)
	end
	return ok == true
end

local function relieveStress(ctx, target: number)
	local state = ctx.state
	while state.Stress > target do
		local action = bestAction(state, function(a) return -(a.Stress or 0) end)
		if not action or not perform(ctx, action) then
			return
		end
	end
end

----------------------------------------------------------------------
-- Policies
----------------------------------------------------------------------

local function trainGreedy(ctx)
	for _, action in Training.Actions do
		if usable(ctx.state, action) then
			perform(ctx, action)
		end
	end
end

local function trainFocused(ctx)
	local state = ctx.state
	if state.Stress >= 75 then
		relieveStress(ctx, 40)
	end
	local best = bestAction(state, xpValue)
	while best and perform(ctx, best) do
	end
end

local function trainBalanced(ctx)
	local state, player = ctx.state, ctx.player
	if state.Stress >= 60 or state.Happiness <= 30 then
		relieveStress(ctx, 30)
	end
	if state.Health < PlayerState.GetMaxHealth(state) * 0.5 then
		local heal = bestAction(state, function(a) return a.Health or 0 end)
		if heal then
			perform(ctx, heal)
		end
	end
	-- Keep the closest people close (one visit a year).
	local spend = RelConfig.InteractionsById and RelConfig.InteractionsById.SpendTime
	if spend and GamePack.IsEnabled("Relationships") and (state.Social or 0) > 0 then
		local lowest
		for _, rel in state.Relationships do
			if rel.Alive and not rel.Away and spend.Categories[rel.Category] and (not lowest or rel.Affection < lowest.Affection) then
				lowest = rel
			end
		end
		if lowest then
			RelationshipSystem.Interact(player, state, lowest.Id, "SpendTime", PlayerState.GetBuffs(state))
		end
	end
	-- Spread XP: favor the stats that are furthest behind; skip stressful work when tense.
	local function score(action)
		if state.Stress >= 50 and (action.Stress or 0) > 0 then
			return 0
		end
		local value = action.ProficiencyXp or 0
		for stat, xp in action.StatXp or {} do
			local entry = state.Stats[stat]
			value += xp / (1 + (if entry then entry.Level else 0))
		end
		return value
	end
	local action = bestAction(state, score)
	while action and perform(ctx, action) do
		action = bestAction(state, score)
	end
end

-- Court a partner (when single) and keep the closest people close, partner first.
local function socialize(ctx)
	local state, player = ctx.state, ctx.player
	local byId = RelConfig.InteractionsById or {}
	if not GamePack.IsEnabled("Relationships") then
		return
	end
	local buffs = PlayerState.GetBuffs(state)
	local partner, friends = nil, {}
	for _, rel in state.Relationships do
		if rel.Alive and not rel.Away then
			if rel.Category == "Partner" then
				partner = rel
			elseif rel.Category == "Friend" then
				table.insert(friends, rel)
			end
		end
	end
	table.sort(friends, function(a, b) return a.Affection > b.Affection end)
	local romance = byId.Romance
	if not partner and romance and friends[1] and friends[1].Affection >= (romance.MinAffection or 0) then
		RelationshipSystem.Interact(player, state, friends[1].Id, "Romance", buffs)
	end
	local spend = byId.SpendTime
	if not spend then
		return
	end
	local close = { partner }
	for i = 1, math.min(5, #friends) do
		table.insert(close, friends[i])
	end
	for _, rel in close do
		if rel.Affection < 85 and (state.Social or 0) > 0 then
			RelationshipSystem.Interact(player, state, rel.Id, "SpendTime", buffs)
		end
	end
end

-- Masters one stat per life (ctx.Focus); the social specialist also invests in people.
local function trainSpecialist(ctx)
	local state, focus = ctx.state, ctx.Focus
	if state.Stress >= 70 then
		relieveStress(ctx, 35)
	end
	if focus and focus == PlayerState.RoleStat("Social") then
		socialize(ctx)
	end
	local best = bestAction(state, function(a) return a.StatXp and a.StatXp[focus] or 0 end) or bestAction(state, xpValue)
	while best and perform(ctx, best) do
	end
end

local function trainRandom(ctx)
	for _ = 1, ctx.options.MaxActionsPerYear do
		local choices = {}
		for _, action in Training.Actions do
			if usable(ctx.state, action) then
				table.insert(choices, action)
			end
		end
		if #choices == 0 then
			return
		end
		perform(ctx, choices[ctx.bot:NextInteger(1, #choices)])
	end
end

-- Event choice strategies: return an option index.
local function metOptions(state, event): { number }
	local list = {}
	for i, option in event.Options do
		if Requirements.Check(state, option.Requires) then
			table.insert(list, i)
		end
	end
	return list
end

local CHOOSERS = {
	first = function(_ctx, _event, options)
		return options[1]
	end,
	random = function(ctx, _event, options)
		return options[ctx.bot:NextInteger(1, #options)]
	end,
	safest = function(ctx, event, options)
		local buffs = PlayerState.GetBuffs(ctx.state)
		local best, bestChance = options[1], -1
		for _, i in options do
			local option = event.Options[i]
			local chance = if option.Chance then Engine.GetChance(ctx.state, option, buffs) else 1
			if chance > bestChance then
				best, bestChance = i, chance
			end
		end
		return best
	end,
}

BalanceReport.Policies = {
	{ Id = "Idle", Description = "Never acts; first available event choice. Baseline for passive gains.", Choose = "first" },
	{ Id = "Greedy", Description = "Every action in list order until energy runs out; uses every system.", Train = trainGreedy, Systems = true, Choose = "first" },
	{ Id = "Focused", Description = "Spams the action with the most XP per energy; rests only above 75 stress.", Train = trainFocused, Systems = true, Choose = "first" },
	{ Id = "Balanced", Description = "Manages stress, health and relationships, then spreads XP; safest choices.", Train = trainBalanced, Systems = true, Choose = "safest" },
	{ Id = "Random", Description = "Random affordable actions and random event choices.", Train = trainRandom, Systems = true, Choose = "random" },
	{ Id = "Specialist", Description = "Each life masters one stat (cycling through all); the social one courts and keeps friends close.", Train = trainSpecialist, Systems = true, Choose = "safest" },
}

----------------------------------------------------------------------
-- Systems every active policy uses (each gated by its module)
----------------------------------------------------------------------

local careersBySalary = table.clone(Studies.Careers or {})
table.sort(careersBySalary, function(a, b) return (a.Salary or 0) > (b.Salary or 0) end)

local function useSystems(ctx)
	local state, player = ctx.state, ctx.player
	local buffs = PlayerState.GetBuffs(state)
	if GamePack.IsEnabled("Cultivation") and state.Qi:Ge(PlayerState.GetRequirement(state)) then
		CultivationSystem.Breakthrough(player, state)
	end
	if GamePack.IsEnabled("Education") and not state.Education.Enrolled then
		for _, tier in Studies.Tiers or {} do
			if not tier.Auto and not state.Graduated[tier.Id] and CareerSystem.Enroll(player, state, tier.Id) then
				break
			end
		end
	end
	if GamePack.IsEnabled("Careers") and not state.Career.Id and state.LastApplyAge ~= state.Age then
		for _, career in careersBySalary do
			if Requirements.Check(state, career.Requires) then
				CareerSystem.ApplyJob(player, state, career.Id, buffs)
				break
			end
		end
	end
	if GamePack.IsEnabled("Masters") then
		if not state.Master.Id then
			for masterId in state.DiscoveredMasters do
				if MasterSystem.Join(player, state, masterId) then
					break
				end
			end
		end
		local master = state.Master.Id and Masters.ById[state.Master.Id]
		for i in if master then master.Quests or {} else {} do
			MasterSystem.CompleteQuest(player, state, i)
		end
	end
	-- Dynasty: start a family once partnered (two children is enough for an heir).
	if GamePack.IsActive("Dynasty") and state.Age >= 20 and state.Age <= 45 then
		local partner, children = nil, 0
		for _, rel in state.Relationships do
			if rel.Type == "Partner" and rel.Alive then partner = rel end
			if rel.Type == "Child" then children += 1 end
		end
		if partner and children < 2 then
			RelationshipSystem.Interact(player, state, partner.Id, "TryForChild", buffs)
		elseif not partner then
			-- Court the closest friend: spend time until close, then ask them out.
			local best
			for _, rel in state.Relationships do
				if rel.Type == "Friend" and rel.Alive and (not best or rel.Affection > best.Affection) then
					best = rel
				end
			end
			if best then
				local romance = Content.Get("RelationshipsConfig").InteractionsById.Romance
				local interaction = if best.Affection >= (romance and romance.MinAffection or 60) then "Romance" else "SpendTime"
				RelationshipSystem.Interact(player, state, best.Id, interaction, buffs)
			end
		end
	end
	-- World: move to a richer-Qi neighbor when affordable (5x the fee) and its hazard is survivable.
	if GamePack.IsActive("World") and not state.PendingEvent then
		local Regions = Content.Get("WorldRegionsConfig")
		local here = RegionSystem.Region(state)
		local best, bestQi = nil, (here.Buffs and here.Buffs.QiMult) or 1
		for _, id in here.Neighbors do
			local region = Regions.ById[id]
			local qi = (region.Buffs and region.Buffs.QiMult) or 1
			local hazard = region.Hazard
			local safe = not hazard or (hazard.ImmuneMaxAlignment and state.Alignment <= hazard.ImmuneMaxAlignment) or state.RealmIndex >= 4
			local reason, fee = RegionSystem.Check(state, id)
			if qi > bestQi and safe and not reason and state.Money >= fee * 5 then
				best, bestQi = id, qi
			end
		end
		if best then
			RegionSystem.Travel(player, state, best)
			bump(ctx.acc.Actions, "Travel:" .. best)
		end
	end
	if GamePack.IsEnabled("Masteries") then
		for _, branch in Masteries.Branches or {} do
			for _, node in branch.Nodes or {} do
				ProgressionSystem.UnlockMastery(player, state, node.Id)
			end
		end
	end
	if GamePack.IsEnabled("Inventory") then
		for itemId in table.clone(state.Inventory.Items) do
			local item = Items.ById[itemId]
			if item and item.Use then
				InventorySystem.Use(player, state, itemId)
			elseif item and item.Equip and not state.Inventory.Equipped[item.Equip.Slot] then
				InventorySystem.Equip(player, state, itemId)
			end
		end
		-- Dynasty: consecrate the first equipped item so the next lives inherit it.
		if GamePack.IsActive("Dynasty") and not DynastySystem.Data(state).Consecrated then
			for _, slot in { "Weapon", "Armor", "Accessory" } do
				if state.Inventory.Equipped[slot] and DynastySystem.Consecrate(player, state, slot) then
					break
				end
			end
		end
		-- Buy what is cheap relative to savings (20x the price).
		for _, itemId in Items.Shop or {} do
			local item = Items.ById[itemId]
			if item and item.Price and state.Money >= item.Price * 20 and PlayerState.ItemCount(state, itemId) == 0
				and (item.Use or (item.Equip and not state.Inventory.Equipped[item.Equip.Slot])) then
				InventorySystem.Buy(player, state, itemId)
			end
		end
	end
end

----------------------------------------------------------------------
-- Simulation
----------------------------------------------------------------------

local function checkInvariants(state, acc)
	local function fail(message: string)
		bump(acc.Violations, message)
	end
	if not finite(state.Money) then fail("money is not finite") end
	if state.Happiness < 0 or state.Happiness > 100 then fail("happiness out of 0-100") end
	if state.Stress < 0 or state.Stress > 100 then fail("stress out of 0-100") end
	if (state.Actions or 0) < 0 or (state.Actions or 0) > Training.MaxActionSlots then fail("action slots out of range") end
	if (state.Social or 0) < 0 then fail("negative social budget") end
	for actionId, count in state.ActionCounts or {} do
		local action = Training.ById[actionId]
		if action and count > (action.MaxPerYear or Training.DefaultMaxPerYear) then
			fail("yearly limit exceeded for " .. actionId)
		end
	end
	if not finite(state.Health) or state.Health > PlayerState.GetMaxHealth(state) + 1e-6 then fail("health above max or not finite") end
	if #state.Relationships > RelConfig.MaxRelationships then fail("too many relationships") end
	for stat, entry in state.Stats do
		if not finite(entry.Level) or entry.Level < 0 or not finite(entry.Xp) then
			fail("invalid level/xp for stat " .. tostring(stat))
		end
	end
end

-- Plays one life. Without (player, state) it seeds and creates a fresh first life;
-- the campaign passes its reincarnating character instead.
local function playLife(policy, life: number, options, acc, player, state)
	local seed = options.Seed * 100003 + life
	local owned = state == nil
	if owned then
		Rng.Seed(seed)
		NpcSystem.SetSeed(seed + 1)
		player = { Name = ("Balance_%s_%d"):format(policy.Id, life) }
		state = PlayerState.CreateState({}, nil)
		PlayerState.Track(player, state)
	end
	local ctx = { player = player, state = state, acc = acc, options = options, performed = 0, bot = Random.new(seed + 2),
		Focus = StatsConfig.Order[(life - 1) % #StatsConfig.Order + 1] }
	local choose = CHOOSERS[policy.Choose] or CHOOSERS.first
	local moneyByAge, moneyMax, events = {}, state.Money, 0
	local ceilingAge = nil
	local lifespanByAge = {}
	local careers = {}

	local function year()
		local guard = 0
		while state.PendingEvent and not state.Dead and guard < 20 do
			guard += 1
			local entry = state.PendingEvent
			local event = Engine.Get(entry.Pool, entry.Id)
			local choices = event and metOptions(state, event) or {}
			if #choices == 0 then
				error(("event '%s' has no choice the character can take"):format(tostring(entry.Id)), 0)
			end
			if not Engine.Resolve(player, state, entry.Id, choose(ctx, event, choices)) then
				error(("could not resolve event '%s'"):format(tostring(entry.Id)), 0)
			end
			events += 1
			bump(acc.Events, entry.Id)
			SystemRegistry.AfterChange(player, state) -- as GameManager does after an event choice
			if not PlayerState.CheckDeath(player) then
				Engine.PresentNext(player, state)
			end
		end
		if state.Dead then
			return
		end
		ctx.performed = 0
		if policy.Systems then
			useSystems(ctx)
		end
		if policy.Train then
			policy.Train(ctx)
		end
		-- Duels opened this year (feuds, trials, heirloom fights) are quick-resolved like a player would.
		if state.PendingDuel then
			DuelSystem.Quick(player, state)
			DuelSystem.Close(state)
		end
		SystemRegistry.AfterChange(player, state) -- as GameManager does after actions
		if state.Career.Id then
			careers[state.Career.Id] = true
		end
		if PlayerState.CheckDeath(player) then
			return
		end
		YearSystem.Advance(player, state)
		moneyByAge[state.Age] = state.Money
		lifespanByAge[state.Age] = PlayerState.GetMaxLifespan(state)
		if not ceilingAge and GamePack.IsEnabled("Cultivation") and Realms.IsMaxed(state.RealmIndex, state.SubLevel) then
			ceilingAge = state.Age
		end
		if finite(state.Money) then
			moneyMax = math.max(moneyMax, state.Money)
		else
			moneyMax = state.Money
		end
		checkInvariants(state, acc)
		if options.OnYear then
			options.OnYear(policy.Id, life, state)
		end
	end

	for y = 1, options.MaxYears do
		if options.YieldEvery > 0 and y % options.YieldEvery == 0 then
			task.wait()
		end
		local ok, err = pcall(year)
		if not ok then
			bump(acc.Errors, tostring(err))
			break
		end
		if state.Dead then
			break
		end
	end

	-- Per-life metrics
	local best, total, count = 0, 0, 0
	for _, entry in state.Stats do
		best = math.max(best, entry.Level)
		total += entry.Level
		count += 1
	end
	-- Death statistics only count lives that ended (not ones cut off by MaxYears).
	if state.Dead then
		local lifespan = PlayerState.GetMaxLifespan(state)
		table.insert(acc.DeathAges, state.Age)
		table.insert(acc.Lifespans, lifespan)
		if state.Age < lifespan * options.EarlyDeathRatio then
			acc.EarlyDeaths += 1
			bump(acc.EarlyCauses, state.DeathCause or "unknown")
		end
	end
	acc.LivesPlayed += 1
	if ceilingAge then
		table.insert(acc.CeilingAges, ceilingAge)
	end
	table.insert(acc.BestStats, best)
	table.insert(acc.MeanStats, if count > 0 then total / count else 0)
	table.insert(acc.Money, state.Money)
	table.insert(acc.EventsPerLife, events)
	table.insert(acc.Realms, state.RealmIndex)
	table.insert(acc.Karma, state.Karma)
	acc.MoneyMax = if finite(moneyMax) and finite(acc.MoneyMax) then math.max(acc.MoneyMax, moneyMax) else moneyMax
	if state.Dead then
		bump(acc.Causes, state.DeathCause or "unknown")
	else
		acc.AliveAtEnd += 1
	end
	for titleId in state.Titles.Unlocked do
		bump(acc.Titles, titleId)
	end
	for tierId in state.Graduated do
		bump(acc.Graduated, tierId)
	end
	for careerId in careers do
		bump(acc.Careers, careerId)
	end
	-- A life that never ended while its lifespan kept outgrowing its age (the last
	-- 100 years) would never end at all. Realm jumps in lives that do end are fine.
	local lastLifespan, earlierLifespan = lifespanByAge[state.Age], lifespanByAge[state.Age - 100]
	if not state.Dead and lastLifespan and earlierLifespan and lastLifespan - earlierLifespan >= 100 then
		acc.LifespanRunaway += 1
	end
	-- Compounding money: the growth rate holds over two windows in a row (linear
	-- income from a small base passes one window, never two).
	local window = options.GrowthWindow
	local factor = (1 + options.MoneyGrowthPerYear) ^ window
	for age, money in moneyByAge do
		local mid, early = moneyByAge[age - window], moneyByAge[age - 2 * window]
		if mid and early and early >= options.MoneyGrowthBase and money >= options.MoneyGrowthFloor
			and money / mid >= factor and mid / early >= factor then
			acc.GrowthLives += 1
			break
		end
	end
	if owned then
		PlayerState.Track(player, nil)
	end
end

local function newAccumulator()
	return {
		DeathAges = {}, Lifespans = {}, BestStats = {}, MeanStats = {}, Money = {}, EventsPerLife = {},
		Realms = {}, Karma = {}, MoneyMax = 0, Causes = {}, AliveAtEnd = 0, GrowthLives = 0, LivesPlayed = 0, CeilingAges = {},
		EarlyDeaths = 0, EarlyCauses = {}, LifespanRunaway = 0,
		Actions = {}, Events = {}, Titles = {}, Graduated = {}, Careers = {}, Errors = {}, Violations = {},
	}
end

local function summarize(policy, acc)
	local cause, causeCount = topKey(acc.Causes)
	local earlyCause, earlyCauseCount = topKey(acc.EarlyCauses)
	local action, actionCount = topKey(acc.Actions)
	local actionTotal = 0
	for _, n in acc.Actions do
		actionTotal += n
	end
	return {
		Id = policy.Id,
		Description = policy.Description,
		Active = policy.Train ~= nil,
		Lives = acc.LivesPlayed,
		Deaths = #acc.DeathAges,
		DeathAge = if #acc.DeathAges > 0 then { Median = median(acc.DeathAges), Min = math.min(table.unpack(acc.DeathAges)), Max = math.max(table.unpack(acc.DeathAges)) } else nil,
		Lifespan = median(acc.Lifespans),
		EarlyDeaths = acc.EarlyDeaths, EarlyCause = earlyCause, EarlyCauseCount = earlyCauseCount,
		LifespanRunaway = acc.LifespanRunaway,
		CeilingLives = #acc.CeilingAges,
		CeilingAge = median(acc.CeilingAges),
		TopCause = cause, TopCauseCount = causeCount, Causes = acc.Causes,
		AliveAtEnd = acc.AliveAtEnd,
		BestStat = median(acc.BestStats),
		MeanStat = median(acc.MeanStats),
		Money = median(acc.Money),
		MoneyMax = acc.MoneyMax,
		GrowthLives = acc.GrowthLives,
		EventsPerLife = median(acc.EventsPerLife),
		Realm = median(acc.Realms),
		RealmMax = acc.Realms[1] and math.max(table.unpack(acc.Realms)) or 0,
		Karma = median(acc.Karma),
		TopAction = action, TopActionShare = if actionTotal > 0 then actionCount / actionTotal else 0,
		Actions = acc.Actions,
	}
end

-- Every event a life of this pack could roll or chain into.
local function knownEvents()
	local list = {}
	for _, pool in GamePack.Manifest.EventPools or {} do
		if GamePack.IsEnabled(pool.Module) then
			local module = Content.Resolve(pool.Config)
			for id, event in if module then require(module).Events or {} else {} do
				-- Bloodline-only events need Wheel spins: the campaign covers them, not fresh lives.
				local wheelOnly = event.Requires and event.Requires.Race ~= nil
				if not wheelOnly and GamePack.IsEnabled(event.Module) and not (event.Target and not GamePack.IsEnabled("Relationships")) then
					table.insert(list, { Id = id, ChainOnly = event.ChainOnly == true, Weight = event.Weight })
				end
			end
		end
	end
	table.sort(list, function(a, b) return a.Id < b.Id end)
	return list
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

function BalanceReport.Options(overrides)
	local options = table.clone(BalanceReport.Defaults)
	for key, value in GamePack.Manifest.Balance or {} do
		options[key] = value
	end
	for key, value in overrides or {} do
		options[key] = value
	end
	return options
end

-- overrides: any Defaults field, plus Policies = { "Greedy", ... } to run a subset
-- and OnYear(policyId, life, state) to trace lives while debugging a finding.
function BalanceReport.Run(overrides)
	local options = BalanceReport.Options(overrides)
	local started = os.clock()
	local report = {
		Pack = GamePack.Manifest.Id,
		PackName = GamePack.Manifest.Name,
		Options = options,
		Policies = {},
		Events = {}, Titles = {}, Actions = {}, Graduated = {}, Careers = {}, Errors = {}, Violations = {},
		KnownEvents = knownEvents(),
		KnownTitles = if GamePack.IsEnabled("Titles") then Titles.List else {},
		KnownActions = {},
	}
	for _, action in Training.Actions do
		if GamePack.IsEnabled(action.Module) then
			table.insert(report.KnownActions, action.Id)
		end
	end

	for _, policy in BalanceReport.Policies do
		if not options.Policies or table.find(options.Policies, policy.Id) then
			local acc = newAccumulator()
			for life = 1, options.Lives do
				playLife(policy, life, options, acc)
			end
			table.insert(report.Policies, summarize(policy, acc))
			for _, field in { "Events", "Titles", "Actions", "Graduated", "Careers", "Errors", "Violations" } do
				for key, n in acc[field] do
					bump(report[field], key, n)
				end
			end
		end
	end
	Rng.Seed(nil)
	NpcSystem.Rng = Random.new()

	report.Cultivation = GamePack.IsEnabled("Cultivation")
	report.Findings = BalanceReport.Diagnose(report)
	report.Seconds = os.clock() - started
	return report
end

----------------------------------------------------------------------
-- Campaign: one character over many lives
----------------------------------------------------------------------

local function rarityRank(spin, rarity): number
	return table.find(spin.RarityOrder, rarity) or 0
end

-- Samsara upgrades bought first, in this order (one rank per pass while affordable).
local UPGRADE_PRIORITY = { "TemporalAwareness", "KarmicFortune", "SocialMagnetism", "SoulRetention" }

local function buyUpgrades(player, state)
	local Upgrades = Content.Get("SamsaraUpgradesConfig")
	local bought = true
	while bought do
		bought = false
		for _, id in UPGRADE_PRIORITY do
			local upgrade = Upgrades.ById[id]
			local rank = PlayerState.UpgradeRank(state, id)
			-- Keep half the Karma for the wheel itself.
			if upgrade and rank < upgrade.MaxRank and state.Karma * 0.5 >= upgrade.Costs[rank + 1] then
				bought = WheelSystem.BuyUpgrade(player, state, id) or bought
				break
			end
		end
	end
end

-- Wheel strategy: buy Samsara upgrades, chase a Legendary+ bloodline, lock it when
-- affordable, then fill the talent slots (re-spinning a slot until Epic+ or three tries).
local function spendOnWheel(player, state)
	local Races, Talents = Content.Get("RacesConfig"), Content.Get("TalentsConfig")
	local wheel = WheelSystem.Wheel(state)
	buyUpgrades(player, state)
	local spin = Races.Spin
	if spin and GamePack.IsEnabled("Lineages") and not wheel.StoredRace then
		local budget = state.Karma * 0.6
		while state.Karma >= spin.Cost and budget >= spin.Cost
			and rarityRank(spin, Races.Get(wheel.Race).Rarity) < rarityRank(spin, "Legendary") do
			budget -= spin.Cost
			WheelSystem.SpinBloodline(player, state)
		end
		if rarityRank(spin, Races.Get(wheel.Race).Rarity) >= rarityRank(spin, "Legendary") and state.Karma >= spin.LockCost then
			WheelSystem.Lock(player, state)
		end
	end
	-- Talents: re-spin each slot until Epic+ (Mythic while Karma is plentiful).
	local talentSpin = Talents.Spin
	local top = talentSpin and talentSpin.RarityOrder[#talentSpin.RarityOrder]
	for slot = 1, if talentSpin then talentSpin.Slots else 0 do
		for _ = 1, 40 do
			if state.Karma < talentSpin.Cost then
				break
			end
			local talent = Talents.Get(wheel.Talents[slot])
			local rank = if talent then rarityRank(talentSpin, talent.Rarity) else 0
			if rank >= rarityRank(talentSpin, top) or (rank >= rarityRank(talentSpin, "Epic") and state.Karma < 60) then
				break
			end
			WheelSystem.SpinTalent(player, state, slot)
		end
	end
end

-- overrides: Lives (default 30), Policy (default "Balanced"), Seed, MaxYears (default 3000).
function BalanceReport.Campaign(overrides)
	local options = BalanceReport.Options(overrides)
	options.Lives = (overrides and overrides.Lives) or 30
	options.MaxYears = (overrides and overrides.MaxYears) or 3000
	local policy
	for _, candidate in BalanceReport.Policies do
		if candidate.Id == ((overrides and overrides.Policy) or "Balanced") then
			policy = candidate
		end
	end
	assert(policy, "unknown policy")
	local started = os.clock()
	Rng.Seed(options.Seed)
	NpcSystem.SetSeed(options.Seed + 1)
	local player = { Name = "Campaign_" .. policy.Id }
	local state = PlayerState.CreateState({}, nil)
	PlayerState.Track(player, state)
	-- Life 1 starter spins: two legacy rolls and one bloodline roll.
	for _, kind in { "Legacy", "Bloodline", "Legacy" } do
		CreationSystem.Roll(player, state, kind)
	end
	CreationSystem.Roll(player, state, "Done")
	local acc = newAccumulator()
	local campaign = { Policy = policy.Id, Pack = GamePack.Manifest.Id, Options = options, Lives = {}, FinalRealmLife = nil }
	local Realms = Content.Get("RealmsConfig")
	for life = 1, options.Lives do
		playLife(policy, life, options, acc, player, state)
		local maxed = GamePack.IsEnabled("Cultivation") and Realms.IsMaxed(state.RealmIndex, state.SubLevel)
		table.insert(campaign.Lives, {
			Life = life, Realm = state.RealmIndex, SubLevel = state.SubLevel, Age = state.Age, Race = state.Race,
			Talents = table.concat(state.Talents, "+"), Codex = PlayerState.CodexCount(state), Karma = state.Karma, Dead = state.Dead,
		})
		if maxed and not campaign.FinalRealmLife then
			campaign.FinalRealmLife = life
		end
		if not state.Dead or maxed then
			break
		end
		-- With Karma for a real wheel run (120+), a full rebirth; otherwise reborn as the
		-- best-bred living child (highest spirit root), else Descendant when married (free),
		-- otherwise a stranger in the same era.
		local Genetics = Content.Get("GeneticsConfig")
		local heir, best = nil, 0
		for _, rel in state.Relationships do
			local grade = rel.Type == "Child" and rel.Alive and rel.Genetics and Genetics.GradeIndex[rel.Genetics.Grade] or 0
			if grade > best then
				heir, best = rel, grade
			end
		end
		-- Young heirs are taken over; an adult heir is asked for a newborn (a fresh life to cultivate).
		if heir and state.Karma < 120 and WheelSystem.ChooseHeir(player, state, heir.Id, if heir.Age >= WheelSystem.GrandchildMinAge then "Grandchild" else "TakeOver") then
			campaign.Heirs = (campaign.Heirs or 0) + 1
		else
			spendOnWheel(player, state)
			WheelSystem.ChoosePath(player, state, if state.Flags.Married then "Descendant" else "Stranger")
		end
		WheelSystem.Confirm(player, state)
	end
	PlayerState.Track(player, nil)
	Rng.Seed(nil)
	NpcSystem.Rng = Random.new()
	campaign.Errors, campaign.Violations = acc.Errors, acc.Violations
	campaign.Seconds = os.clock() - started
	return campaign
end

function BalanceReport.FormatCampaign(campaign): string
	local Realms = Content.Get("RealmsConfig")
	local lines = { ("CAMPAIGN  %s, policy %s, seed %d, %d lives played, %.1fs"):format(
		campaign.Pack, campaign.Policy, campaign.Options.Seed, #campaign.Lives, campaign.Seconds or 0) }
	for _, life in campaign.Lives do
		table.insert(lines, ("  life %2d  %-26s age %-5d %-18s codex %-3d karma %-4d %s"):format(life.Life,
			("%s %d/9"):format(Realms.Get(life.Realm).Name, life.SubLevel), life.Age, life.Race, life.Codex, life.Karma,
			if life.Talents ~= "" then life.Talents else "-"))
	end
	table.insert(lines, if campaign.FinalRealmLife then ("Final realm first reached in life %d."):format(campaign.FinalRealmLife)
		else "Final realm not reached in this campaign.")
	for message, n in campaign.Errors do
		table.insert(lines, ("  [ERROR] %dx %s"):format(n, message))
	end
	return table.concat(lines, "\n")
end

-- Pure: turns a report (real or hand-built) into a sorted list of findings.
function BalanceReport.Diagnose(report)
	local options = report.Options or BalanceReport.Defaults
	local findings = {}
	local function add(level: string, code: string, message: string)
		table.insert(findings, { Level = level, Code = code, Message = message })
	end

	for message, n in report.Errors or {} do
		add("ERROR", "runtime_error", ("%dx %s"):format(n, message))
	end
	for message, n in report.Violations or {} do
		add("ERROR", "invalid_state", ("%dx %s"):format(n, message))
	end

	local byId, active = {}, {}
	for _, policy in report.Policies or {} do
		byId[policy.Id] = policy
		if policy.Active then
			table.insert(active, policy)
		end
		if not finite(policy.MoneyMax) then
			add("ERROR", "non_finite", ("%s: money became %s"):format(policy.Id, tostring(policy.MoneyMax)))
		elseif policy.MoneyMax >= options.MoneyRunaway then
			add("WARN", "runaway_money", ("%s: money reached %.3g (limit %.3g)"):format(policy.Id, policy.MoneyMax, options.MoneyRunaway))
		end
		if (policy.GrowthLives or 0) > 0 then
			add("WARN", "exponential_money", ("%s: %d of %d lives grew money by %d%%+ a year for %d years"):format(
				policy.Id, policy.GrowthLives, policy.Lives, math.floor(options.MoneyGrowthPerYear * 100), options.GrowthWindow))
		end
		local early = policy.EarlyDeaths or 0
		if policy.Active and early > 0 then
			add(if early >= policy.Lives * options.EarlyDeathShare then "WARN" else "INFO", "early_death",
				("%s: %d of %d lives died before %d%% of their lifespan (median death %s); top cause '%s' (%d)"):format(
					policy.Id, early, policy.Lives, math.floor(options.EarlyDeathRatio * 100),
					if policy.DeathAge then tostring(policy.DeathAge.Median) else "-", tostring(policy.EarlyCause), policy.EarlyCauseCount or 0))
		end
		if policy.Active and (policy.CeilingLives or 0) >= policy.Lives * options.CeilingShare and policy.Lives > 0 then
			add("WARN", "progression_ceiling", ("%s: %d of %d lives reached the final realm, median at age %d"):format(
				policy.Id, policy.CeilingLives, policy.Lives, policy.CeilingAge))
		end
		if (policy.LifespanRunaway or 0) > 0 then
			add("WARN", "lifespan_runaway", ("%s: in %d of %d lives lifespan grew faster than age (endless life)"):format(
				policy.Id, policy.LifespanRunaway, policy.Lives))
		end
		if (policy.AliveAtEnd or 0) > 0 then
			add("INFO", "outlived_simulation", ("%s: %d of %d lives were still alive after %d years"):format(
				policy.Id, policy.AliveAtEnd, policy.Lives, options.MaxYears))
		end
	end

	if report.Cultivation then
		for _, policy in active do
			if policy.Realm and (policy.Realm > options.FreshPeakMax or policy.Realm < options.FreshPeakMin) and (policy.CeilingLives or 0) == 0 then
				add("WARN", "fresh_peak", ("%s: a fresh life peaks at realm %d (target %d-%d)"):format(policy.Id, policy.Realm, options.FreshPeakMin, options.FreshPeakMax))
			end
		end
	end

	local idle = byId.Idle
	local bestActive, bestMoney = 0, -math.huge
	for _, policy in active do
		bestActive = math.max(bestActive, policy.BestStat)
		bestMoney = math.max(bestMoney, policy.Money)
	end
	if idle and #active > 0 then
		if bestActive > 0 and idle.BestStat >= bestActive * options.IdleProgressRatio then
			add("WARN", "idle_competitive", ("Idle reaches best stat %d vs %d for the best active policy: actions barely matter"):format(idle.BestStat, bestActive))
		end
		if idle.Money > bestMoney and idle.Money > 0 then
			add("WARN", "passive_income", ("Idle ends richer (%.3g) than every active policy (best %.3g)"):format(idle.Money, bestMoney))
		end
	end

	local focused, balanced = byId.Focused, byId.Balanced
	if focused and balanced and balanced.BestStat > 0
		and focused.BestStat >= balanced.BestStat * options.DominanceRatio
		and (if focused.DeathAge then focused.DeathAge.Median else math.huge) >= (if balanced.DeathAge then balanced.DeathAge.Median else math.huge) * 0.9 then
		add("WARN", "dominant_strategy", ("Spamming '%s' (%d%% of actions) reaches best stat %d vs %d balanced, without dying sooner"):format(
			tostring(focused.TopAction), math.floor((focused.TopActionShare or 0) * 100), focused.BestStat, balanced.BestStat))
	end

	local unreachable, unchained = {}, {}
	for _, event in report.KnownEvents or {} do
		if not (report.Events or {})[event.Id] then
			if event.ChainOnly then
				table.insert(unchained, event.Id)
			else
				table.insert(unreachable, ("%s (w %.2g)"):format(event.Id, event.Weight or 0))
			end
		end
	end
	if #unreachable > 0 then
		add("WARN", "event_never_fired", ("%d event(s) never fired in any run: %s"):format(#unreachable, table.concat(unreachable, ", ")))
	end
	if #unchained > 0 then
		add("WARN", "chain_never_reached", ("%d chain event(s) never reached: %s"):format(#unchained, table.concat(unchained, ", ")))
	end

	local lockedTitles = {}
	for _, title in report.KnownTitles or {} do
		if not (report.Titles or {})[title.Id] then
			table.insert(lockedTitles, title.Id)
		end
	end
	if #lockedTitles > 0 then
		add("WARN", "title_never_unlocked", ("%d title(s) never unlocked: %s"):format(#lockedTitles, table.concat(lockedTitles, ", ")))
	end

	local unused = {}
	for _, actionId in report.KnownActions or {} do
		if not (report.Actions or {})[actionId] then
			table.insert(unused, actionId)
		end
	end
	if #unused > 0 then
		add("WARN", "action_never_used", ("%d action(s) no policy could perform: %s"):format(#unused, table.concat(unused, ", ")))
	end

	local perLife = {}
	for _, policy in active do
		table.insert(perLife, policy.EventsPerLife)
	end
	if #perLife > 0 and median(perLife) < options.MinEventsPerLife then
		add("INFO", "thin_content", ("active policies see a median of %d events per life (target %d)"):format(median(perLife), options.MinEventsPerLife))
	end

	table.sort(findings, function(a, b)
		if a.Level ~= b.Level then
			return LEVEL_ORDER[a.Level] < LEVEL_ORDER[b.Level]
		end
		return a.Code < b.Code
	end)
	return findings
end

function BalanceReport.Format(report): string
	local options = report.Options
	local lines = {
		("BALANCE REPORT  %s (%s)  seed %d, %d lives x %d policies, max %d years, %.1fs"):format(
			tostring(report.PackName), report.Pack, options.Seed, options.Lives, #report.Policies, options.MaxYears, report.Seconds or 0),
		("%-9s %-17s %-8s %-9s %-8s %-11s %-7s %s"):format("Policy", "Death med/min/max", "Lifespan", "BestStat", "Events", "Money(med)", "Realm", "Top cause / top action"),
	}
	for _, p in report.Policies do
		local death = if p.DeathAge then ("%d/%d/%d"):format(p.DeathAge.Median, p.DeathAge.Min, p.DeathAge.Max) else "none died"
		table.insert(lines, ("%-9s %-17s %-8s %-9d %-8d %-11s %-7s %s / %s %d%%"):format(
			p.Id, death, ("%.3g"):format(p.Lifespan), p.BestStat,
			p.EventsPerLife, ("%.3g"):format(p.Money), ("%d (%d)"):format(p.Realm, p.RealmMax),
			p.TopCause or "-", tostring(p.TopAction or "-"), math.floor((p.TopActionShare or 0) * 100)))
	end
	table.insert(lines, ("FINDINGS (%d)"):format(#report.Findings))
	for _, finding in report.Findings do
		table.insert(lines, ("  [%s] %s: %s"):format(finding.Level, finding.Code, finding.Message))
	end
	if #report.Findings == 0 then
		table.insert(lines, "  none")
	end
	return table.concat(lines, "\n")
end

return BalanceReport
