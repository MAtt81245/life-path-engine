--[[
	LifeEventsEngine: evaluates YearlyEventsConfig + LifeEventsConfig on every birthday,
	queues the chosen events, presents them one at a time and applies the outcome of
	the player's choice. Aging pauses while an event is pending.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
local StatsConfig = Content.Get("PlayerStatsConfig")
local Training = Content.Get("TrainingConfig")
local Studies = Content.Get("StudiesAndCareerConfig")
local RelConfig = Content.Get("RelationshipsConfig")
local ItemsConfig = Content.Get("ItemsConfig")
local Requirements = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Requirements"))
local GamePack = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GamePack"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Engine = {}

Engine.MaxEventsPerYear = 2

-- Effect keys implemented by registry modules: [key] = fn(player, state, value, entry, buffs) -> summary?
-- Filled by SystemRegistry from each system's Hooks.Effects.
Engine.EffectHandlers = {}

-- Event pools come from the game manifest: [configName] = { Events, Module }.
local POOLS = {}
for _, pool in GamePack.Manifest.EventPools or {} do
	local module = Content.Resolve(pool.Config)
	if module then
		POOLS[pool.Config] = { Events = require(module).Events or {}, Module = pool.Module }
	else
		warn("[LifeEventsEngine] Missing event pool " .. tostring(pool.Config))
	end
end

-- Pool keys used by saves written before pools came from the manifest.
local LEGACY_POOLS = { Yearly = "YearlyEventsConfig", Life = "LifeEventsConfig" }

local rng = require(script.Parent:WaitForChild("Rng"))

function Engine.Get(pool: string, id: string)
	local entry = POOLS[pool] or POOLS[LEGACY_POOLS[pool] or ""]
	return entry and entry.Events[id]
end

local function matchesTarget(rel, target): boolean
	if not rel.Alive then return false end
	if target.Category and rel.Category ~= target.Category then return false end
	if target.Type and not table.find(target.Type, rel.Type) then return false end
	if rel.Affection < (target.MinAffection or 0) or rel.Affection > (target.MaxAffection or 100) then return false end
	if rel.Age < (target.MinAge or 0) then return false end
	return true
end

local function findTargets(state, target)
	local found = {}
	for _, rel in state.Relationships do
		if matchesTarget(rel, target) then
			table.insert(found, rel)
		end
	end
	return found
end

-- Why an event cannot roll this year (nil = eligible). Chain events never roll.
-- Single source of truth for the yearly roll and the dev console's `why`.
local function whyIneligible(state, id: string, event): string?
	if event.ChainOnly then return "chain-only (reached through a FollowUp)" end
	if not GamePack.IsEnabled(event.Module) then return "module " .. tostring(event.Module) .. " is disabled" end
	local lastAge = state.EventLastAge and state.EventLastAge[id]
	if event.Cooldown and lastAge and state.Age - lastAge < event.Cooldown then
		return ("on cooldown until age %d"):format(lastAge + event.Cooldown)
	end
	if event.Target and not GamePack.IsEnabled("Relationships") then return "targets a relationship but Relationships is disabled" end
	if state.Age < event.MinAge or state.Age > event.MaxAge then
		return ("age %d is outside %d-%d"):format(state.Age, event.MinAge, event.MaxAge)
	end
	if state.RealmIndex < (event.MinRealm or 1) then return ("needs realm %d"):format(event.MinRealm) end
	if not event.Repeatable and state.SeenEvents[id] then return "already happened (not repeatable)" end
	if event.Target and not event.Target.Create and #findTargets(state, event.Target) == 0 then
		return "no relationship matches its Target"
	end
	local met, items = Requirements.Evaluate(state, event.Requires)
	if not met then return "requires " .. Requirements.UnmetText(items) end
	return nil
end
Engine.WhyIneligible = whyIneligible

local function isEligible(state, id: string, event): boolean
	return whyIneligible(state, id, event) == nil
end
Engine.IsEligible = isEligible

local function fill(text: string?, state, entry): string
	if not text then
		return ""
	end
	local target = entry.TargetId and PlayerState.FindRelationship(state, entry.TargetId)
	local targetName = if target then target.Name else "someone"
	local newName = entry.NewName or "a stranger"
	text = string.gsub(text, "{name}", function() return targetName end)
	text = string.gsub(text, "{new}", function() return newName end)
	return text
end

function Engine.GetChance(state, option, buffs): number
	local chance = option.Chance or 1
	if option.ChanceStat and state.Stats[option.ChanceStat] then
		chance += state.Stats[option.ChanceStat].Level * 0.01
		if option.ChanceStat == PlayerState.RoleStat("Social") then
			chance += buffs.SocialBonus
		end
	end
	return math.clamp(chance, 0.05, 0.95)
end

function Engine.Enqueue(state, pool: string, id: string)
	local event = Engine.Get(pool, id)
	if not event then
		return
	end
	local entry = { Pool = pool, Id = id }
	if event.Target then
		if event.Target.Create then
			entry.NewName = PlayerState.RandomPersonName(nil, state)
		else
			local targets = findTargets(state, event.Target)
			if #targets == 0 then
				return
			end
			entry.TargetId = targets[rng:NextInteger(1, #targets)].Id
		end
	end
	table.insert(state.EventQueue, entry)
end

----------------------------------------------------------------------
-- Event chains: follow-up events and delayed consequences
----------------------------------------------------------------------

local function chainLists(state)
	state.ScheduledEvents = state.ScheduledEvents or {}
	state.ScheduledEffects = state.ScheduledEffects or {}
	state.EventLastAge = state.EventLastAge or {}
end

function Engine.FindPool(id: string): string?
	for poolName, pool in POOLS do
		if pool.Events[id] then
			return poolName
		end
	end
	return nil
end

-- Queues a follow-up of `parent` now (InYears 0) or at a later birthday.
-- The follow-up keeps the parent's target / new person so chains stay about them.
function Engine.Schedule(state, followUp, parent)
	chainLists(state)
	local pool = followUp.Pool or Engine.FindPool(followUp.Id)
	if not pool then
		warn("[LifeEventsEngine] Unknown follow-up event " .. tostring(followUp.Id))
		return
	end
	local entry = { Pool = pool, Id = followUp.Id, Chained = true }
	if parent then
		entry.TargetId = parent.TargetId
		entry.NewName = parent.NewName
	end
	local delay = math.max(0, math.floor(followUp.InYears or 0))
	if delay == 0 then
		table.insert(state.EventQueue, entry)
	else
		entry.DueAge = state.Age + delay
		table.insert(state.ScheduledEvents, entry)
	end
end

-- Whether a chained entry may still fire (the world may have changed meanwhile).
function Engine.CanChain(state, entry, event): boolean
	local pool = POOLS[entry.Pool] or POOLS[LEGACY_POOLS[entry.Pool] or ""]
	if not pool or not GamePack.IsEnabled(pool.Module) or not GamePack.IsEnabled(event.Module) then return false end
	if not event.Repeatable and state.SeenEvents[entry.Id] then return false end
	local lastAge = state.EventLastAge and state.EventLastAge[entry.Id]
	if event.Cooldown and lastAge and state.Age - lastAge < event.Cooldown then return false end
	if event.Target then
		if not GamePack.IsEnabled("Relationships") then return false end
		if event.Target.Inherit and not entry.TargetId then return false end
		if not event.Target.Inherit and not event.Target.Create then
			-- A regular targeted event only fires for a person matching its filters.
			local rel = entry.TargetId and PlayerState.FindRelationship(state, entry.TargetId)
			if not rel or not matchesTarget(rel, event.Target) then return false end
		end
	end
	return Requirements.Check(state, event.Requires)
end

-- Queues `eventId` this year with `rel` as its person (used by NPC autonomy).
-- The event's own rules still apply: module, repeats, cooldown, age window,
-- target filters and requirements. Returns true when queued.
function Engine.TriggerFor(state, eventId: string, rel): boolean
	local poolName = Engine.FindPool(eventId)
	if not poolName then
		return false
	end
	local event = POOLS[poolName].Events[eventId]
	if event.MinAge and (state.Age < event.MinAge or state.Age > (event.MaxAge or math.huge)) then
		return false
	end
	local entry = { Pool = poolName, Id = eventId, TargetId = rel and rel.Id, Chained = true }
	if not Engine.CanChain(state, entry, event) then
		return false
	end
	for _, queued in state.EventQueue do
		if queued.Id == eventId then
			return false
		end
	end
	table.insert(state.EventQueue, entry)
	return true
end

-- Called by YearSystem each birthday before the death check: applies delayed
-- consequences that are due and moves due follow-up events into the queue.
function Engine.ProcessScheduled(player, state)
	chainLists(state)
	local effects = state.ScheduledEffects
	state.ScheduledEffects = {}
	for _, item in effects do
		if item.DueAge <= state.Age and item.TargetId and not PlayerState.FindRelationship(state, item.TargetId) then
			-- The person behind this consequence is gone (died or left): drop it.
			continue
		elseif item.DueAge <= state.Age then
			local text = fill(item.Text, state, item)
			local summary = Engine.ApplyEffects(player, state, item, item.Effects)
			if text ~= "" or summary ~= "" then
				PlayerState.Log(player, if summary ~= "" then ("%s  (%s)"):format(text, summary) else text, "event")
			end
		else
			table.insert(state.ScheduledEffects, item)
		end
	end

	local due, waiting = {}, {}
	for _, entry in state.ScheduledEvents do
		table.insert(if entry.DueAge <= state.Age then due else waiting, entry)
	end
	table.sort(due, function(a, b) return a.DueAge < b.DueAge end)
	state.ScheduledEvents = waiting
	for _, entry in due do
		entry.DueAge = nil
		table.insert(state.EventQueue, entry)
	end
end

-- Called by AgingSystem after each birthday.
function Engine.RollYear(player: Player, state)
	local picked, rolled = {}, {}
	for poolName, pool in POOLS do
		if GamePack.IsEnabled(pool.Module) then
			for id, event in pool.Events do
				if isEligible(state, id, event) then
					if event.MinAge == event.MaxAge then
						table.insert(picked, { poolName, id })
					elseif rng:NextNumber() < event.Weight then
						table.insert(rolled, { poolName, id })
					end
				end
			end
		end
	end
	-- Follow-ups already queued this year count toward the yearly limit.
	if #picked + #state.EventQueue < Engine.MaxEventsPerYear and #rolled > 0 then
		table.insert(picked, rolled[rng:NextInteger(1, #rolled)])
	end
	for _, pick in picked do
		Engine.Enqueue(state, pick[1], pick[2])
	end
	Engine.PresentNext(player, state)
end

function Engine.SendPrompt(player: Player, state)
	local entry = state.PendingEvent
	local event = entry and Engine.Get(entry.Pool, entry.Id)
	if not event then
		state.PendingEvent = nil
		return
	end
	local buffs = PlayerState.GetBuffs(state)
	local options = {}
	for i, option in event.Options do
		local met, items = Requirements.Evaluate(state, option.Requires)
		local hint
		if not met then
			hint = "Requires " .. Requirements.UnmetText(items)
		elseif option.Chance then
			hint = ("%d%% success"):format(math.floor(Engine.GetChance(state, option, buffs) * 100 + 0.5))
		end
		-- Risky: a roll can fail (Chance) or the content flags it; the client shows a ⚠ badge.
		options[i] = { Text = option.Text, Hint = hint, Locked = not met, Risky = option.Chance ~= nil or option.Risky == true }
	end
	PlayerState.Fire(Remotes.EventPrompt, player, {
		Id = entry.Id,
		Title = fill(event.Title, state, entry),
		Text = fill(event.Text, state, entry),
		Age = state.Age,
		Options = options,
		Remaining = #state.EventQueue,
	})
end

function Engine.PresentNext(player: Player, state)
	while not state.Dead and not state.PendingEvent and #state.EventQueue > 0 do
		local entry = table.remove(state.EventQueue, 1)
		local targetGone = entry.TargetId and not PlayerState.FindRelationship(state, entry.TargetId)
		local event = Engine.Get(entry.Pool, entry.Id)
		if event and entry.Chained and not Engine.CanChain(state, entry, event) then
			event = nil
		end
		if event and not targetGone then
			state.PendingEvent = entry
			Engine.SendPrompt(player, state)
		end
	end
end

-- Applies an Effects table and returns a readable summary.
function Engine.ApplyEffects(player: Player, state, entry, effects): string
	if not effects then
		return ""
	end
	-- Effects owned by a disabled module are ignored.
	local active = {}
	for key, value in effects do
		if GamePack.EffectEnabled(key) then
			active[key] = value
		end
	end
	effects = active
	local parts = {}
	local buffs = PlayerState.GetBuffs(state)
	local target = entry.TargetId and PlayerState.FindRelationship(state, entry.TargetId)

	if effects.Qi and effects.Qi ~= 0 then
		local amount = PlayerState.GetRequirement(state):Mul(math.abs(effects.Qi))
		if effects.Qi > 0 then
			amount = amount:Mul(PlayerState.GetQiMultiplier(state, buffs))
			PlayerState.AddQi(state, amount)
			table.insert(parts, "+" .. amount:ToString() .. " " .. PlayerState.Term("EnergyName"))
		else
			state.Qi = state.Qi:Sub(amount):Max(0)
			table.insert(parts, "-" .. amount:ToString() .. " " .. PlayerState.Term("EnergyName"))
		end
	end
	if effects.Stats then
		for _, stat in StatsConfig.Order do
			local xp = effects.Stats[stat]
			if xp then
				local granted = PlayerState.AddStatXp(player, state, stat, xp, buffs)
				table.insert(parts, ("+%d %s XP"):format(granted, StatsConfig.Stats[stat].Short))
			end
		end
	end
	if effects.Proficiency then
		for _, key in Training.ProficiencyOrder do
			local xp = effects.Proficiency[key]
			if xp then
				local granted = PlayerState.AddProficiencyXp(player, state, key, xp, buffs)
				table.insert(parts, ("+%d %s XP"):format(granted, Training.Proficiencies[key].Name))
			end
		end
	end
	if effects.MaxHealth then
		state.BonusMaxHealth += effects.MaxHealth
		state.Health += math.max(0, effects.MaxHealth)
		table.insert(parts, ("%+d max HP"):format(effects.MaxHealth))
	end
	if effects.Health then
		PlayerState.AddHealth(state, effects.Health, buffs)
		table.insert(parts, ("%+d health"):format(effects.Health))
	end
	if effects.Happiness then
		PlayerState.AdjustMeter(state, "Happiness", effects.Happiness)
		table.insert(parts, ("%+d happiness"):format(effects.Happiness))
	end
	if effects.Stress then
		PlayerState.AdjustMeter(state, "Stress", effects.Stress)
		table.insert(parts, ("%+d stress"):format(effects.Stress))
	end
	if effects.Actions then
		local before = state.Actions
		state.Actions = math.clamp(state.Actions + effects.Actions, 0, Training.MaxActionSlots)
		if state.Actions ~= before then
			table.insert(parts, ("%+d action%s this year"):format(state.Actions - before, if math.abs(state.Actions - before) == 1 then "" else "s"))
		end
	end
	if effects.Money then
		state.Money += effects.Money
		table.insert(parts, (if effects.Money >= 0 then "+" else "") .. PlayerState.FormatMoney(effects.Money))
	end
	if effects.Karma then
		local karma = effects.Karma
		if karma > 0 then
			karma = math.floor(karma * buffs.KarmaMult + 0.5)
		end
		state.Karma = math.max(0, state.Karma + karma)
		table.insert(parts, PlayerState.Words("%+d {MetaCurrency}"):format(karma))
	end
	if effects.Alignment then
		state.Alignment = math.clamp(state.Alignment + effects.Alignment, -100, 100)
		table.insert(parts, ("%+d alignment"):format(effects.Alignment))
	end
	if effects.Lifespan then
		state.BonusLifespan += effects.Lifespan
		table.insert(parts, ("%+d years of life"):format(effects.Lifespan))
	end
	if effects.Performance and state.Education.Enrolled then
		state.Education.Performance = math.clamp(state.Education.Performance + effects.Performance, 0, 100)
		table.insert(parts, ("%+d grades"):format(effects.Performance))
	end
	if effects.JobPerformance and state.Career.Id then
		state.Career.Performance = math.clamp(state.Career.Performance + effects.JobPerformance, 0, 100)
		table.insert(parts, ("%+d job performance"):format(effects.JobPerformance))
	end
	if effects.Counters then
		for counter, amount in effects.Counters do
			state.Counters[counter] = (state.Counters[counter] or 0) + amount
		end
	end
	if effects.Flags then
		for _, flag in effects.Flags do
			state.Flags[flag] = true
		end
	end
	if effects.Items then
		for itemId, count in effects.Items do
			local changed = PlayerState.AddItem(state, itemId, count)
			local item = ItemsConfig.ById[itemId]
			if changed ~= 0 and item then
				table.insert(parts, ("%s%d %s"):format(if changed > 0 then "+" else "", changed, item.Name))
			end
		end
	end
	if target then
		if effects.Affection then
			local delta = PlayerState.AdjustAffection(target, effects.Affection, buffs)
			table.insert(parts, ("%+d affection (%s)"):format(delta, target.Name))
		end
		if effects.TargetBecomes and RelConfig.Types[effects.TargetBecomes] then
			PlayerState.SetRelationshipType(target, effects.TargetBecomes)
			table.insert(parts, ("%s is now your %s"):format(target.Name, string.lower(effects.TargetBecomes)))
		end
		if effects.RemoveTarget then
			PlayerState.RemoveRelationship(state, target.Id)
			table.insert(parts, target.Name .. " left your life")
		end
	end
	if effects.NewRelationship then
		local rel = PlayerState.CreateRelationship(state, effects.NewRelationship.Type, {
			Name = entry.NewName,
			Affection = effects.NewRelationship.Affection,
		})
		if rel then
			table.insert(parts, ("New %s: %s"):format(string.lower(effects.NewRelationship.Type), rel.Name))
			-- Follow-ups of this event are about the person just met.
			entry.TargetId = entry.TargetId or rel.Id
		end
	end
	if effects.Career and not state.Career.Id and Studies.CareersById[effects.Career] then
		state.Career = { Id = effects.Career, Years = 0, Performance = 50 }
		table.insert(parts, "New job: " .. Studies.CareersById[effects.Career].Name)
	end
	if effects.QuitJob and state.Career.Id then
		state.Career = { Id = nil, Years = 0, Performance = 50 }
		table.insert(parts, "You quit your job")
	end
	for key, handler in Engine.EffectHandlers do
		if effects[key] ~= nil then
			local summary = handler(player, state, effects[key], entry, buffs)
			if summary and summary ~= "" then
				table.insert(parts, summary)
			end
		end
	end
	-- Chains are not shown in the summary: consequences arrive later.
	if effects.FollowUp then
		for _, followUp in (if effects.FollowUp.Id then { effects.FollowUp } else effects.FollowUp) do
			Engine.Schedule(state, followUp, entry)
		end
	end
	if effects.Delayed then
		chainLists(state)
		for _, delayed in (if effects.Delayed.Effects then { effects.Delayed } else effects.Delayed) do
			table.insert(state.ScheduledEffects, {
				DueAge = state.Age + math.max(1, math.floor(delayed.InYears or 1)),
				Text = delayed.Text,
				Effects = delayed.Effects,
				TargetId = entry.TargetId,
				NewName = entry.NewName,
			})
		end
	end
	return table.concat(parts, "  ·  ")
end

-- Resolve hooks (Modules/PathSystem): BeforeResolve fn(player, state, entry) runs before
-- any effect; AfterResolve fn(player, state, info) after the result, with
-- info = { Entry, Event, OptionIndex, Title, Text, Choice, Options, Result, Summary, Success }.
Engine.BeforeResolve = {}
Engine.AfterResolve = {}

-- Resolves the pending event with the chosen option. Returns true on success.
function Engine.Resolve(player: Player, state, eventId: string, optionIndex: number): boolean
	local entry = state.PendingEvent
	if not entry or entry.Id ~= eventId then
		return false
	end
	local event = Engine.Get(entry.Pool, entry.Id)
	local option = event and event.Options[optionIndex]
	if not option or not Requirements.Check(state, option.Requires) then
		return false
	end

	for _, hook in Engine.BeforeResolve do
		hook(player, state, entry)
	end
	local buffs = PlayerState.GetBuffs(state)
	local success = option.Chance == nil or rng:NextNumber() < Engine.GetChance(state, option, buffs)
	local title = fill(event.Title, state, entry)
	local storyText = fill(event.Text, state, entry)
	local resultText = fill(if success then option.Result else option.FailResult, state, entry)
	local effects = if success then option.Effects else option.FailEffects
	local summary = Engine.ApplyEffects(player, state, entry, effects)
	-- Big moments are remembered by the person involved.
	local person = entry.TargetId and PlayerState.FindRelationship(state, entry.TargetId)
	if person and effects and type(effects.Affection) == "number" and math.abs(effects.Affection) >= 10 then
		PlayerState.Remember(state, person, title, if effects.Affection > 0 then 1 else -1)
	end

	state.PendingEvent = nil
	state.SeenEvents[entry.Id] = true
	chainLists(state)
	state.EventLastAge[entry.Id] = state.Age
	PlayerState.Log(player, title .. ": " .. resultText, if success then "event" else "bad")
	PlayerState.Fire(Remotes.EventResult, player, { Title = title, Text = resultText, Summary = summary, Success = success })
	if #Engine.AfterResolve > 0 then
		local optionTexts = {}
		for i, other in event.Options do
			optionTexts[i] = fill(other.Text, state, entry)
		end
		local info = { Entry = entry, Event = event, OptionIndex = optionIndex, Title = title, Text = storyText, Choice = optionTexts[optionIndex],
			Options = optionTexts, Result = resultText, Summary = summary, Success = success }
		for _, hook in Engine.AfterResolve do
			hook(player, state, info)
		end
	end
	return true
end

return Engine
