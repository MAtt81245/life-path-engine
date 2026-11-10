--[[
	DevConsole: Studio-only developer commands to inspect and change a character.
	Commands run on the server through the real modules, so `why` explains exactly
	what the game enforces (TrainingSystem.Check, Engine.WhyIneligible,
	Requirements) and `buffs` lists the same sources GetBuffs merges.

	Enabled only when RunService:IsStudio() and ServerScriptService does not have
	the attribute DevConsole = false. DevConsoleServer creates the DevCommand
	remote only then, so live servers never expose it; Execute re-checks anyway.

	DevConsole.Execute(player, "help") -> { lines }
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Content = require(Shared:WaitForChild("Content"))
local GamePack = require(Shared:WaitForChild("GamePack"))
local Requirements = require(Shared:WaitForChild("Requirements"))
local Rng = require(script.Parent:WaitForChild("Rng"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local YearSystem = require(script.Parent:WaitForChild("YearSystem"))
local Engine = require(script.Parent:WaitForChild("LifeEventsEngine"))
local TrainingSystem = require(script.Parent:WaitForChild("TrainingSystem"))
local SystemRegistry = require(script.Parent:WaitForChild("SystemRegistry"))
local MonetizationSystem = require(script.Parent:WaitForChild("MonetizationSystem"))
local SamsaraSystem = require(script.Parent:WaitForChild("SamsaraSystem"))
local RegionSystem = require(script.Parent:WaitForChild("RegionSystem"))
local DynastySystem = require(script.Parent:WaitForChild("DynastySystem"))
local WheelSystem = require(script.Parent:WaitForChild("WheelSystem"))
local DuelSystem = require(script.Parent:WaitForChild("DuelSystem"))

local StatsConfig = Content.Get("PlayerStatsConfig")
local Training = Content.Get("TrainingConfig")
local Studies = Content.Get("StudiesAndCareerConfig")
local Masters = Content.Get("MastersConfig")
local Masteries = Content.Get("MasteriesConfig")
local Titles = Content.Get("TitlesConfig")
local Items = Content.Get("ItemsConfig")
local RelConfig = Content.Get("RelationshipsConfig")
local Realms = Content.Get("RealmsConfig")

local DevConsole = {}

DevConsole.MaxLineLength = 300
DevConsole.MaxOutputLines = 60

function DevConsole.Enabled(): boolean
	return RunService:IsStudio() and ServerScriptService:GetAttribute("DevConsole") ~= false
end

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

local function fmt(value, depth: number?): string
	depth = depth or 0
	if type(value) == "table" then
		if getmetatable(value) and type(value.ToString) == "function" then
			return value:ToString() -- BigNum
		end
		local keys = {}
		for key in value do
			table.insert(keys, key)
		end
		if depth >= 2 then
			return ("{%d entries}"):format(#keys)
		end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		local parts = {}
		for i, key in keys do
			if i > 12 then
				table.insert(parts, ("... +%d more"):format(#keys - 12))
				break
			end
			table.insert(parts, tostring(key) .. "=" .. fmt(value[key], depth + 1))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	elseif type(value) == "number" then
		return if value % 1 == 0 and math.abs(value) < 1e15 then tostring(value) else ("%.4g"):format(value)
	end
	return tostring(value)
end
DevConsole.Format = fmt

local function num(text: string?): number?
	local n = tonumber(text)
	if n == nil or n ~= n or math.abs(n) == math.huge then
		return nil
	end
	return n
end

local function keysOf(map): string
	local keys = {}
	for key in map or {} do
		table.insert(keys, tostring(key))
	end
	table.sort(keys)
	return table.concat(keys, ", ")
end

local function unmet(state, req): string?
	local met, items = Requirements.Evaluate(state, req)
	return if met then nil else "requires " .. Requirements.UnmetText(items)
end

-- Every event the active pack can roll or chain into: { Id, Event }, sorted.
local function allEvents()
	local list = {}
	for _, pool in GamePack.Manifest.EventPools or {} do
		local module = Content.Resolve(pool.Config)
		for id, event in if module then require(module).Events or {} else {} do
			table.insert(list, { Id = id, Event = event, PoolModule = pool.Module })
		end
	end
	table.sort(list, function(a, b) return a.Id < b.Id end)
	return list
end

local function optionLines(state, event): { string }
	local lines = {}
	for i, option in event.Options do
		local locked = unmet(state, option.Requires)
		table.insert(lines, ("  %d. %s%s"):format(i, option.Text, if locked then "  [locked: " .. locked .. "]" else ""))
	end
	return lines
end

-- Resolves pending/queued events with the first available choice.
local function autoResolve(player, state): (number, string?)
	if not state.PendingEvent then
		Engine.PresentNext(player, state)
	end
	local resolved, guard = 0, 0
	while state.PendingEvent and not state.Dead and guard < 20 do
		guard += 1
		local entry = state.PendingEvent
		local event = Engine.Get(entry.Pool, entry.Id)
		local choice
		for i, option in event.Options do
			if Requirements.Check(state, option.Requires) then
				choice = i
				break
			end
		end
		if not choice or not Engine.Resolve(player, state, entry.Id, choice) then
			return resolved, ("could not auto-resolve '%s'"):format(entry.Id)
		end
		resolved += 1
		if not PlayerState.CheckDeath(player) then
			Engine.PresentNext(player, state)
		end
	end
	return resolved, nil
end

----------------------------------------------------------------------
-- Commands
----------------------------------------------------------------------

local commands, order = {}, {}

-- run(ctx, args) returns a list of lines; set ctx.changed when state was modified.
local function command(name: string, usage: string, help: string, run)
	commands[name] = { Usage = usage, Help = help, Run = run }
	table.insert(order, name)
end

command("help", "help [command]", "List commands, or show one command.", function(_, args)
	if args[1] then
		local entry = commands[string.lower(args[1])]
		return if entry then { entry.Usage, "  " .. entry.Help } else { "Unknown command " .. args[1] }
	end
	local lines = { "Developer console (Studio only). Commands:" }
	for _, name in order do
		table.insert(lines, ("  %-30s %s"):format(commands[name].Usage, commands[name].Help))
	end
	return lines
end)

command("pack", "pack", "Active game pack, engine version and enabled modules.", function()
	local manifest = GamePack.Manifest
	local on, off = {}, {}
	for id in GamePack.Modules do
		table.insert(if GamePack.IsEnabled(id) then on else off, id)
	end
	table.sort(on)
	table.sort(off)
	local pools = {}
	for _, pool in manifest.EventPools or {} do
		table.insert(pools, pool.Config)
	end
	return {
		("%s (%s) v%s on engine %s"):format(manifest.Name, Content.ActivePackId() or Content.BaseName, manifest.Version, GamePack.EngineVersion),
		"Modules on:  " .. table.concat(on, ", "),
		"Modules off: " .. (if #off > 0 then table.concat(off, ", ") else "none"),
		"Event pools: " .. table.concat(pools, ", "),
	}
end)

command("systems", "systems", "Registered gameplay systems: year ticks in order, remotes and effects.", function()
	local lines = { "Systems: " .. table.concat(SystemRegistry.Systems(), ", ") }
	for _, phase in SystemRegistry.Phases do
		local parts = {}
		for _, tick in SystemRegistry.Ticks() do
			if tick.Phase == phase then
				local module = if type(tick.Module) == "table" then table.concat(tick.Module, "/") else tostring(tick.Module or "core")
				table.insert(parts, ("%s(%s%s)"):format(tick.Source, module, if SystemRegistry.Active(tick.Module) then "" else ", off"))
			end
		end
		table.insert(lines, ("Year %s: %s"):format(phase, if #parts > 0 then table.concat(parts, " -> ") else "none"))
	end
	local names = {}
	for name, remote in SystemRegistry.Remotes() do
		table.insert(names, name .. (if SystemRegistry.Active(remote.Module) then "" else " (off)"))
	end
	table.sort(names)
	table.insert(lines, "Remotes: " .. table.concat(names, ", "))
	table.insert(lines, "Effect handlers: " .. keysOf(Engine.EffectHandlers))
	return lines
end)

command("state", "state", "Summary of the character.", function(ctx)
	local s = ctx.state
	local buffs = PlayerState.GetBuffs(s)
	local lines = {
		("%s, age %d / lifespan %d%s"):format(s.Name, s.Age, PlayerState.GetMaxLifespan(s, buffs), if s.Dead then " (dead: " .. tostring(s.DeathCause) .. ")" else ""),
		("Health %s/%s  Happiness %s  Stress %s  Actions %s/%s  Social %s/%s"):format(fmt(math.floor(s.Health)), fmt(math.floor(PlayerState.GetMaxHealth(s, buffs))),
			fmt(math.floor(s.Happiness)), fmt(math.floor(s.Stress)), fmt(s.Actions), fmt(PlayerState.GetMaxActions(s, buffs)), fmt(s.Social), fmt(PlayerState.GetMaxSocial(s))),
		("Money %s  Karma %s  Alignment %s  Lives %d  Mastery points %s"):format(PlayerState.FormatMoney(s.Money), fmt(s.Karma), fmt(s.Alignment), s.Lives, fmt(s.MasteryPoints)),
		("Race %s  Talents %s"):format(tostring(s.Race), if #s.Talents > 0 then table.concat(s.Talents, ", ") else "none"),
	}
	if GamePack.IsEnabled("Cultivation") then
		table.insert(lines, ("Realm %s %d/%d  Qi %s / %s  Breakthrough %d%%"):format(Realms.Get(s.RealmIndex).Name, s.SubLevel, Realms.SubLevels,
			s.Qi:ToString(), PlayerState.GetRequirement(s):ToString(), math.floor(PlayerState.GetBreakthroughChance(s, buffs) * 100 + 0.5)))
	end
	if GamePack.IsEnabled("Education") then
		table.insert(lines, ("Education %s%s  Graduated: %s"):format(tostring(s.Education.Tier), if s.Education.Enrolled then " (enrolled)" else "", keysOf(s.Graduated)))
	end
	if GamePack.IsEnabled("Careers") then
		table.insert(lines, ("Career %s  years %s  performance %s  salary %s"):format(tostring(s.Career.Id), fmt(s.Career.Years), fmt(math.floor(s.Career.Performance)), PlayerState.FormatMoney(PlayerState.GetSalary(s, buffs))))
	end
	if GamePack.IsEnabled("Masters") then
		table.insert(lines, ("Master %s  loyalty %s"):format(tostring(s.Master.Id), fmt(s.Master.Loyalty)))
	end
	table.insert(lines, ("Relationships %d  Titles equipped: %s"):format(#s.Relationships, if #s.Titles.Equipped > 0 then table.concat(s.Titles.Equipped, ", ") else "none"))
	table.insert(lines, ("Pending event %s  queued %d  scheduled %d event(s) / %d effect(s)"):format(
		if s.PendingEvent then s.PendingEvent.Id else "none", #s.EventQueue, #s.ScheduledEvents, #s.ScheduledEffects))
	return lines
end)

command("get", "get <path>", "Read any state field, e.g. get Stats.Strength or get Counters.", function(ctx, args)
	if not args[1] then
		return { "Fields: " .. keysOf(ctx.state) }
	end
	local value = ctx.state
	for key in string.gmatch(args[1], "[^%.]+") do
		if type(value) ~= "table" then
			return { "No such field: " .. args[1] }
		end
		local nextValue = value[key]
		if nextValue == nil and tonumber(key) then
			nextValue = value[tonumber(key)]
		end
		value = nextValue
	end
	return { args[1] .. " = " .. fmt(value) }
end)

local SETTABLE = {
	Age = { Min = 0 }, Money = {}, Health = { Min = 0 }, Happiness = { Min = 0, Max = 100 }, Stress = { Min = 0, Max = 100 },
	Actions = { Min = 0, Max = 6 }, Social = { Min = 0, Max = 20 }, Karma = { Min = 0 }, Alignment = { Min = -100, Max = 100 }, MasteryPoints = { Min = 0 }, BonusLifespan = {},
}

command("set", "set <field> <number>", "Set Age, Money, Health, Happiness, Stress, Actions, Social, Karma, Alignment, MasteryPoints or BonusLifespan.", function(ctx, args)
	local field, value = args[1], num(args[2])
	local rule = field and SETTABLE[field]
	if not rule or not value then
		return { "Usage: set <field> <number>. Fields: " .. keysOf(SETTABLE) }
	end
	value = math.max(rule.Min or -math.huge, math.min(rule.Max or math.huge, value))
	if field == "Health" then
		value = math.min(value, PlayerState.GetMaxHealth(ctx.state))
	end
	ctx.state[field] = value
	ctx.changed = true
	return { ("%s = %s"):format(field, fmt(value)) }
end)

command("stat", "stat <stat> <level>", "Set an attribute level (XP resets to 0).", function(ctx, args)
	local stat, level = args[1], num(args[2])
	if not stat or not StatsConfig.Stats[stat] or not level then
		return { "Usage: stat <stat> <level>. Stats: " .. table.concat(StatsConfig.Order, ", ") }
	end
	ctx.state.Stats[stat] = { Level = math.max(0, math.floor(level)), Xp = 0 }
	ctx.changed = true
	return { ("%s = level %d"):format(stat, ctx.state.Stats[stat].Level) }
end)

command("skill", "skill <proficiency> <level>", "Set a proficiency level.", function(ctx, args)
	local key, level = args[1], num(args[2])
	if not key or not Training.Proficiencies[key] or not level then
		return { "Usage: skill <proficiency> <level>. Proficiencies: " .. table.concat(Training.ProficiencyOrder, ", ") }
	end
	ctx.state.Proficiencies[key] = { Level = math.max(0, math.floor(level)), Xp = 0 }
	ctx.changed = true
	return { ("%s = level %d"):format(key, ctx.state.Proficiencies[key].Level) }
end)

command("lifeskill", "lifeskill <skill> <level>", "Set a life skill level (Skills module); unlocks its tiers.", function(ctx, args)
	local SkillSystem = require(script.Parent:WaitForChild("SkillSystem"))
	local level = num(args[2])
	if not args[1] or not level or not SkillSystem.SetLevel(ctx.player, ctx.state, args[1], level) then
		return { "Usage: lifeskill <skill> <level>. Skills: " .. table.concat(require(game:GetService("ReplicatedStorage").Shared.Content).Get("SkillsConfig").Order, ", ") }
	end
	ctx.changed = true
	return { ("%s = level %d"):format(args[1], math.floor(level)) }
end)

command("counter", "counter <key> <n>", "Set a counter (Knowledge, Fights or any pack counter).", function(ctx, args)
	local value = num(args[2])
	if not args[1] or not value then
		return { "Usage: counter <key> <n>. Current: " .. fmt(ctx.state.Counters) }
	end
	ctx.state.Counters[args[1]] = value
	ctx.changed = true
	return { ("Counters.%s = %s"):format(args[1], fmt(value)) }
end)

command("flag", "flag <name> [off]", "Set or clear a story flag.", function(ctx, args)
	if not args[1] then
		return { "Flags: " .. keysOf(ctx.state.Flags) }
	end
	ctx.state.Flags[args[1]] = if args[2] == "off" then nil else true
	ctx.changed = true
	return { ("Flag %s %s"):format(args[1], if args[2] == "off" then "cleared" else "set") }
end)

command("qi", "qi <fraction>", "Cultivation: set Qi to a fraction (0-1) of the breakthrough requirement.", function(ctx, args)
	local fraction = num(args[1])
	if not GamePack.IsEnabled("Cultivation") then
		return { "Cultivation is disabled in this pack." }
	elseif not fraction then
		return { "Usage: qi <fraction>, e.g. qi 1 to reach the bottleneck." }
	end
	ctx.state.Qi = PlayerState.GetRequirement(ctx.state):Mul(math.clamp(fraction, 0, 1))
	ctx.changed = true
	return { "Qi = " .. ctx.state.Qi:ToString() }
end)

command("realm", "realm <index> [sublevel]", "Cultivation: jump to a realm and sub-level.", function(ctx, args)
	local index, sub = num(args[1]), num(args[2]) or 1
	if not GamePack.IsEnabled("Cultivation") then
		return { "Cultivation is disabled in this pack." }
	elseif not index then
		return { ("Usage: realm <1-%d> [1-%d]"):format(#Realms.Realms, Realms.SubLevels) }
	end
	local s = ctx.state
	s.RealmIndex = math.clamp(math.floor(index), 1, #Realms.Realms)
	s.SubLevel = math.clamp(math.floor(sub), 1, Realms.SubLevels)
	s.Qi = PlayerState.GetRequirement(s):Mul(0)
	s.LevelSince = s.Age - (Realms.Get(s.RealmIndex).YearsPerLevel or 0) -- stable at once
	ctx.changed = true
	return { ("Realm %s, level %d"):format(Realms.Get(s.RealmIndex).Name, s.SubLevel) }
end)

command("year", "year [n] [auto]", "Advance n years (max 200). Stops at events unless auto (first available choice).", function(ctx, args)
	local s, player = ctx.state, ctx.player
	local auto = args[1] == "auto" or args[2] == "auto"
	local count = math.clamp(math.floor(num(args[1]) or 1), 1, 200)
	local advanced, resolved, problem = 0, 0, nil
	for _ = 1, count do
		if s.Dead then
			break
		end
		if s.PendingEvent or #s.EventQueue > 0 then
			if not auto then
				break
			end
			local n
			n, problem = autoResolve(player, s)
			resolved += n
			if problem or s.Dead then
				break
			end
		end
		if not YearSystem.Advance(player, s) then
			break
		end
		advanced += 1
	end
	if auto and not s.Dead and not problem then
		local n
		n, problem = autoResolve(player, s)
		resolved += n
	end
	ctx.changed = true
	local lines = { ("Advanced %d year(s) to age %d%s"):format(advanced, s.Age, if resolved > 0 then (", auto-resolved %d event(s)"):format(resolved) else "") }
	if problem then
		table.insert(lines, "Stopped: " .. problem)
	end
	if s.PendingEvent then
		table.insert(lines, ("Stopped at event '%s' (choose <n>, or year %d auto):"):format(s.PendingEvent.Id, count))
		local event = Engine.Get(s.PendingEvent.Pool, s.PendingEvent.Id)
		for _, line in if event then optionLines(s, event) else {} do
			table.insert(lines, line)
		end
	end
	if s.Dead then
		table.insert(lines, "Died: " .. tostring(s.DeathCause))
	end
	return lines
end)

command("events", "events [filter]", "List events with their eligibility right now.", function(ctx, args)
	local filter = args[1] and string.lower(args[1])
	local lines, shown, total = {}, 0, 0
	for _, entry in allEvents() do
		if not filter or string.find(string.lower(entry.Id), filter, 1, true) then
			total += 1
			if shown < 40 then
				shown += 1
				local reason = if not GamePack.IsEnabled(entry.PoolModule) then "pool module " .. entry.PoolModule .. " is disabled"
					else Engine.WhyIneligible(ctx.state, entry.Id, entry.Event)
				table.insert(lines, ("  %-26s %s"):format(entry.Id, reason or ("ELIGIBLE (weight %s)"):format(fmt(entry.Event.Weight))))
			end
		end
	end
	table.insert(lines, 1, ("%d event(s)%s:"):format(total, if filter then " matching '" .. filter .. "'" else ""))
	if total > shown then
		table.insert(lines, ("  ... %d more (add a filter)"):format(total - shown))
	end
	return lines
end)

command("event", "event <id>", "Present an event now, bypassing eligibility.", function(ctx, args)
	local s, player, id = ctx.state, ctx.player, args[1]
	if not id then
		return { "Usage: event <id> (see events)" }
	elseif s.Dead then
		return { "The character is dead." }
	elseif s.PendingEvent then
		return { ("Resolve the pending event '%s' first (choose <n>)."):format(s.PendingEvent.Id) }
	end
	local pool = Engine.FindPool(id)
	if not pool then
		return { ("Unknown event '%s' (see events)."):format(id) }
	end
	local before = #s.EventQueue
	Engine.Enqueue(s, pool, id)
	if #s.EventQueue == before then
		return { ("Could not queue '%s': no relationship matches its Target (add one with npc)."):format(id) }
	end
	table.insert(s.EventQueue, 1, table.remove(s.EventQueue))
	Engine.PresentNext(player, s)
	ctx.changed = true
	local lines = { ("Presented '%s':"):format(id) }
	for _, line in optionLines(s, Engine.Get(pool, id)) do
		table.insert(lines, line)
	end
	return lines
end)

command("choose", "choose <n>", "Resolve the pending event with option n.", function(ctx, args)
	local s, player = ctx.state, ctx.player
	local index = num(args[1])
	if not s.PendingEvent then
		return { "No pending event." }
	elseif not index then
		return { "Usage: choose <n>" }
	end
	local id = s.PendingEvent.Id
	index = math.floor(index)
	if not Engine.Resolve(player, s, id, index) then
		return { ("Option %s of '%s' is locked or does not exist."):format(fmt(index), id) }
	end
	if not PlayerState.CheckDeath(player) then
		Engine.PresentNext(player, s)
	end
	ctx.changed = true
	local last = s.Log[#s.Log]
	local lines = { ("Resolved '%s' with option %d.%s"):format(id, index, if last then " " .. last.Text else "") }
	if s.PendingEvent then
		table.insert(lines, "Next pending: " .. s.PendingEvent.Id)
	end
	return lines
end)

command("npc", "npc <type> [affection] [age]", "Add a relationship (Friend, Rival, Partner, Sibling...).", function(ctx, args)
	local relType = args[1]
	if not GamePack.IsEnabled("Relationships") then
		return { "Relationships are disabled in this pack." }
	elseif not relType or not RelConfig.Types[relType] then
		return { "Usage: npc <type> [affection] [age]. Types: " .. keysOf(RelConfig.Types) }
	end
	local rel = PlayerState.CreateRelationship(ctx.state, relType, {
		Affection = math.clamp(num(args[2]) or 50, 0, 100),
		Age = if num(args[3]) then math.max(0, math.floor(num(args[3]) :: number)) else nil,
	})
	if not rel then
		return { ("No room: the limit is %d relationships."):format(RelConfig.MaxRelationships) }
	end
	ctx.changed = true
	return { ("Added %s %s (age %s, affection %s, id %s)."):format(relType, rel.Name, fmt(rel.Age), fmt(rel.Affection), tostring(rel.Id)) }
end)

command("buffs", "buffs", "Active modifiers: totals and every source.", function(ctx)
	local total, defaults = PlayerState.GetBuffs(ctx.state), PlayerState.NewBuffs()
	local changed = {}
	for key, value in total do
		if type(value) == "table" then
			if next(value) then
				changed[key] = value
			end
		elseif value ~= defaults[key] then
			changed[key] = value
		end
	end
	local lines = { "Total: " .. (if next(changed) then fmt(changed) else "no modifiers") }
	for _, source in PlayerState.BuffSources(ctx.state) do
		table.insert(lines, ("  %s %s"):format(source.Label, fmt(source.Buffs)))
	end
	return lines
end)

-- why <kind> <id>: kind -> explainer(state, id) returning a list of lines.
local WHY = {}

WHY.action = function(state, id)
	local action = Training.ById[id]
	if not action then
		return { ("Unknown action '%s'. Actions: %s"):format(id, keysOf(Training.ById)) }
	end
	local _, reason = TrainingSystem.Check(state, id)
	if not GamePack.IsEnabled(action.Module) then
		reason = "module " .. action.Module .. " is disabled"
	end
	return { ("%s: %s"):format(action.Name, reason or ("available (%s action, %s left this year)"):format(fmt(action.Slots), fmt(state.Actions))) }
end

WHY.event = function(state, id)
	local pool = Engine.FindPool(id)
	local event = pool and Engine.Get(pool, id)
	if not event then
		return { ("Unknown event '%s'."):format(id) }
	end
	local reason = Engine.WhyIneligible(state, id, event)
	return { ("%s: %s"):format(id, reason or ("eligible to roll this year (weight %s, max %d events a year)"):format(fmt(event.Weight), Engine.MaxEventsPerYear)) }
end

WHY.title = function(state, id)
	local title = Titles.ById[id]
	if not title then
		return { ("Unknown title '%s'. Titles: %s"):format(id, keysOf(Titles.ById)) }
	elseif not GamePack.IsEnabled("Titles") then
		return { "Titles are disabled in this pack." }
	elseif state.Titles.Unlocked[id] then
		return { title.Name .. ": already unlocked" .. (if table.find(state.Titles.Equipped, id) then " and equipped" else " (not equipped)") }
	end
	return { title.Name .. ": " .. (unmet(state, title.Requires) or "requirements met; unlocks at the next check") }
end

WHY.career = function(state, id)
	local career = Studies.CareersById[id]
	if not career then
		return { ("Unknown career '%s'. Careers: %s"):format(id, keysOf(Studies.CareersById)) }
	elseif not GamePack.IsEnabled("Careers") then
		return { "Careers are disabled in this pack." }
	elseif state.Career.Id == id then
		return { career.Name .. ": you already work here" }
	elseif state.LastApplyAge == state.Age then
		return { career.Name .. ": you already had an interview this year" }
	end
	return { career.Name .. ": " .. (unmet(state, career.Requires) or "requirements met; the interview is a chance roll") }
end

WHY.tier = function(state, id)
	local tier = Studies.TiersById[id]
	if not tier then
		return { ("Unknown school tier '%s'. Tiers: %s"):format(id, keysOf(Studies.TiersById)) }
	elseif not GamePack.IsEnabled("Education") then
		return { "Education is disabled in this pack." }
	elseif tier.Auto then
		return { ("%s: automatic, starts at age %s"):format(tier.Name, fmt(tier.StartAge)) }
	elseif state.Graduated[id] then
		return { tier.Name .. ": already completed" }
	elseif state.Education.Enrolled then
		return { tier.Name .. ": already enrolled in " .. tostring(state.Education.Tier) }
	end
	return { tier.Name .. ": " .. (unmet(state, tier.Requires) or "you can enroll") }
end

WHY.master = function(state, id)
	local master = Masters.ById[id]
	if not master then
		return { ("Unknown master '%s'. Masters: %s"):format(id, keysOf(Masters.ById)) }
	elseif not GamePack.IsEnabled("Masters") then
		return { "Masters are disabled in this pack." }
	elseif state.Master.Id == id then
		return { master.Name .. ": already your master" }
	elseif not state.DiscoveredMasters[id] then
		return { master.Name .. ": not discovered yet (Seek a Master)" }
	end
	return { master.Name .. ": " .. (unmet(state, master.Requires) or "you can join") }
end

WHY.item = function(state, id)
	local item = Items.ById[id]
	if not item then
		return { ("Unknown item '%s'. Items: %s"):format(id, keysOf(Items.ById)) }
	elseif not GamePack.IsEnabled("Inventory") then
		return { "Inventory is disabled in this pack." }
	elseif item.Module and not GamePack.IsEnabled(item.Module) then
		return { item.Name .. ": module " .. item.Module .. " is disabled" }
	end
	local reasons = {}
	if not item.Price or not table.find(Items.Shop or {}, id) then table.insert(reasons, "not sold in the market") end
	if item.MinAge and state.Age < item.MinAge then table.insert(reasons, ("must be %d"):format(item.MinAge)) end
	if item.Price and state.Money < item.Price then table.insert(reasons, ("costs %s"):format(PlayerState.FormatMoney(item.Price))) end
	if PlayerState.ItemCount(state, id) >= Items.MaxStack(item) then table.insert(reasons, "stack is full") end
	local requirement = unmet(state, item.Requires)
	if requirement then table.insert(reasons, requirement) end
	return { item.Name .. ": " .. (if #reasons > 0 then "cannot buy: " .. table.concat(reasons, "; ") else "you can buy it") }
end

WHY.breakthrough = function(state)
	if not GamePack.IsEnabled("Cultivation") then
		return { "Cultivation is disabled in this pack." }
	elseif Realms.IsMaxed(state.RealmIndex, state.SubLevel) then
		return { "At the peak: no breakthrough left." }
	end
	local realm = Realms.Get(state.RealmIndex)
	local wait = PlayerState.GetBreakthroughWait(state)
	if wait > 0 then
		return { ("Foundation stabilizing: %s more year(s) (%s needs %s per level)."):format(fmt(wait), realm.Name, fmt(realm.YearsPerLevel)) }
	end
	local requirement = PlayerState.GetRequirement(state)
	if state.Qi:Lt(requirement) then
		return { ("Needs Qi %s / %s."):format(state.Qi:ToString(), requirement:ToString()) }
	end
	return { ("Ready: %d%% success."):format(math.floor(PlayerState.GetBreakthroughChance(state) * 100 + 0.5)) }
end

WHY.mastery = function(state, id)
	local node = Masteries.NodesById[id]
	if not node then
		return { ("Unknown mastery '%s'."):format(id) }
	elseif not GamePack.IsEnabled("Masteries") then
		return { "Masteries are disabled in this pack." }
	elseif state.Masteries[id] then
		return { node.Name .. ": already unlocked" }
	elseif node.Previous and not state.Masteries[node.Previous] then
		return { node.Name .. ": unlock " .. node.Previous .. " first" }
	elseif state.MasteryPoints < node.Cost then
		return { ("%s: needs %s mastery points (you have %s)"):format(node.Name, fmt(node.Cost), fmt(state.MasteryPoints)) }
	end
	return { node.Name .. ": you can unlock it" }
end

command("why", "why <kind> <id>", "Explain why something is unavailable. Kinds: action, event, title, career, tier, master, item, mastery, breakthrough.", function(ctx, args)
	local kind = args[1] and string.lower(args[1])
	local explain = kind and WHY[kind]
	if not explain or (not args[2] and kind ~= "breakthrough") then
		return { "Usage: why <kind> <id>. Kinds: " .. keysOf(WHY) }
	end
	return explain(ctx.state, args[2])
end)

command("item", "item <id> [count]", "Give (or with a negative count, take) items.", function(ctx, args)
	local item = args[1] and Items.ById[args[1]]
	if not item then
		return { "Usage: item <id> [count]. Items: " .. keysOf(Items.ById) }
	end
	local added = PlayerState.AddItem(ctx.state, item.Id, math.floor(num(args[2]) or 1))
	ctx.changed = true
	return { ("%s: %+d (now %d)"):format(item.Name, added, PlayerState.ItemCount(ctx.state, item.Id)) }
end)

command("title", "title <id>", "Unlock a title.", function(ctx, args)
	local title = args[1] and Titles.ById[args[1]]
	if not title then
		return { "Usage: title <id>. Titles: " .. keysOf(Titles.ById) }
	end
	ctx.state.Titles.Unlocked[title.Id] = true
	ctx.changed = true
	return { "Unlocked " .. title.Name .. " (equip it in the UI)." }
end)

command("heal", "heal", "Full health, refilled actions and social budget, no stress.", function(ctx)
	local s = ctx.state
	s.Health = PlayerState.GetMaxHealth(s)
	PlayerState.StartYear(s)
	s.Stress = 0
	ctx.changed = true
	return { "Healed." }
end)

command("pass", "pass <id> on|off", "Grant or remove a game pass for testing (golden diamonds, VIP luck/speed).", function(ctx, args)
	if not args[1] or (args[2] ~= "on" and args[2] ~= "off") then
		return { "Usage: pass <id> on|off. Owned: " .. keysOf(ctx.state.Passes or {}) }
	end
	local _, message = MonetizationSystem.SetDevPass(ctx.player, args[1], args[2] == "on")
	PlayerState.StartYear(ctx.state)
	ctx.changed = true
	return { message, ("Actions this year: %d (%d golden)"):format(ctx.state.Actions, PlayerState.GetGoldenActions(ctx.state)) }
end)

command("buy", "buy <productId>", "Studio test purchase of a developer product (Karma packs, MiracleRevival, MiraclePill).", function(ctx, args)
	local products = Content.Get("MonetizationConfig").ProductsById
	if not products[args[1] or ""] then
		return { "Usage: buy <productId>. Products: " .. keysOf(products) }
	end
	local ok, message = MonetizationSystem.Handle(ctx.player, ctx.state, "BuyProduct", args[1], true)
	ctx.changed = true
	return { message or (if ok then "Granted." else "Not available.") }
end)

command("tutorial", "tutorial reset|skip", "Restart the Life 1 onboarding guide, or finish it.", function(ctx, args)
	if args[1] == "reset" then
		ctx.state.TutorialCompleted, ctx.state.TutorialStep = nil, 0
	elseif args[1] == "skip" then
		ctx.state.TutorialCompleted = true
	else
		return { "Usage: tutorial reset|skip" }
	end
	ctx.changed = true
	return { ("Tutorial %s."):format(if ctx.state.TutorialCompleted then "completed" else "reset") }
end)

command("upgrade", "upgrade <id> <rank>", "Set a permanent Samsara upgrade rank.", function(ctx, args)
	local Upgrades = Content.Get("SamsaraUpgradesConfig")
	local upgrade, rank = Upgrades.ById[args[1] or ""], num(args[2])
	if not upgrade or not rank then
		return { "Usage: upgrade <id> <rank>. Upgrades: " .. keysOf(Upgrades.ById) }
	end
	ctx.state.Upgrades = ctx.state.Upgrades or {}
	ctx.state.Upgrades[upgrade.Id] = math.clamp(math.floor(rank), 0, upgrade.MaxRank)
	ctx.changed = true
	return { ("%s rank %d/%d"):format(upgrade.Name, ctx.state.Upgrades[upgrade.Id], upgrade.MaxRank) }
end)

command("region", "region [id]", "Show the current region, or move there instantly (no cost, no encounter).", function(ctx, args)
	local Regions = Content.Get("WorldRegionsConfig")
	if args[1] then
		if not Regions.ById[args[1]] then
			return { "Regions: " .. keysOf(Regions.ById) }
		end
		RegionSystem.SetRegion(ctx.state, args[1])
		ctx.changed = true
	end
	local region = RegionSystem.Region(ctx.state)
	return { ("%s (%s)  ·  roads: %s"):format(region.Name, region.Id, table.concat(region.Neighbors, ", ")) }
end)

command("travel", "travel <id>", "Travel like the Map tab (1 action + fee, road encounter).", function(ctx, args)
	local ok, message = RegionSystem.Travel(ctx.player, ctx.state, args[1] or "")
	ctx.changed = ok
	return { tostring(message) }
end)

command("consecrate", "consecrate <Weapon|Armor|Accessory|Clear>", "Consecrate the equipped item as this life's ancestral heirloom.", function(ctx, args)
	local ok, message = DynastySystem.Consecrate(ctx.player, ctx.state, args[1] or "")
	ctx.changed = ok
	return { tostring(message or "Usage: consecrate <Weapon|Armor|Accessory|Clear>") }
end)

command("equip", "equip <itemId>", "Give and equip an equipment item in its slot.", function(ctx, args)
	local item = Items.ById[args[1] or ""]
	if not item or not item.Equip then
		return { "Usage: equip <itemId> (an Equipment item)." }
	end
	if PlayerState.ItemCount(ctx.state, item.Id) == 0 then
		PlayerState.AddItem(ctx.state, item.Id, 1)
	end
	PlayerState.Inventory(ctx.state).Equipped[item.Equip.Slot] = item.Id
	ctx.changed = true
	return { ("Equipped %s (%s)."):format(item.Name, item.Equip.Slot) }
end)

command("family", "family [children]", "Give a married partner (rolled genetics) and children conceived with them.", function(ctx, args)
	local s = ctx.state
	local partner
	for _, rel in s.Relationships do
		if rel.Type == "Partner" then partner = rel end
	end
	partner = partner or PlayerState.CreateRelationship(s, "Partner", { Age = s.Age, Affection = 85 })
	if not partner then
		return { "No room for a partner." }
	end
	s.Flags.Married = true
	local born = {}
	for _ = 1, math.clamp(num(args[1]) or 2, 0, 6) do
		local child = DynastySystem.Conceive(ctx.player, s, partner)
		if child then
			child.Age = math.random(1, 8)
			table.insert(born, child.Name)
		end
	end
	ctx.changed = true
	return { ("Married %s; children: %s"):format(partner.Name, if #born > 0 then table.concat(born, ", ") else "none") }
end)

command("grandchildren", "grandchildren [n]", "Age your children to adults, marry them and give each up to n children.", function(ctx, args)
	local count, lines = math.clamp(num(args[1]) or 2, 1, 4), {}
	for _, rel in ctx.state.Relationships do
		if rel.Type == "Child" then
			rel.Age = math.max(rel.Age, math.random(22, 30))
			rel.Married, rel.Spouse = true, rel.Spouse or PlayerState.RandomPersonName(nil, ctx.state)
			for _ = 1, count do
				local kid = DynastySystem.AddGrandchild(ctx.state, rel)
				if kid then kid.Age = math.random(0, 5) end
			end
			table.insert(lines, ("%s (married to %s): %d children"):format(rel.Name, rel.Spouse, #(rel.Offspring or {})))
		end
	end
	ctx.changed = true
	return if #lines > 0 then lines else { "No children yet (use family first)." }
end)

command("duel", "duel [difficulty]", "Open a practice Tactical Clash against a sparring partner.", function(ctx, args)
	if ctx.state.PendingDuel then
		return { "A duel is already open." }
	end
	DuelSystem.Start(ctx.player, ctx.state, { Kind = "Practice", Title = "Practice Clash", FoeName = "Sparring Partner",
		Difficulty = num(args[1]) or 1, Weapon = "Training sword", Technique = "Basic forms" })
	ctx.changed = true
	return { "Practice duel opened." }
end)

command("reborn", "reborn [path]", "While dead: choose a rebirth path (Descendant, Stranger, Past, Future) and reincarnate.", function(ctx, args)
	if not ctx.state.Dead then
		return { "Only between lives (use kill first)." }
	end
	if args[1] then
		WheelSystem.ChoosePath(ctx.player, ctx.state, args[1])
	end
	local ok, message = WheelSystem.Confirm(ctx.player, ctx.state)
	ctx.changed = true
	return { if ok then ("Reborn as %s (life %d)."):format(ctx.state.Name, ctx.state.Lives) else tostring(message or "Refused.") }
end)

command("glimpse", "glimpse", "Trigger a Past-Life Glimpse now (needs a previous life).", function(ctx)
	local text = SamsaraSystem.Glimpse(ctx.player, ctx.state)
	ctx.changed = text ~= nil
	return { text or "No past life to remember yet." }
end)

command("kill", "kill [cause]", "End the current life (opens the Wheel of Reincarnation).", function(ctx, args)
	if ctx.state.Dead then
		return { "Already dead." }
	end
	PlayerState.Die(ctx.player, if #args > 0 then table.concat(args, " ") else "Struck down by the developer console.")
	ctx.changed = true
	return { "Died. Karma is now " .. ctx.state.Karma .. "." }
end)

command("seed", "seed <n|off>", "Make gameplay randomness reproducible (off = random again).", function(_, args)
	if args[1] == "off" then
		Rng.Seed(nil)
		return { "Gameplay randomness is unseeded." }
	end
	local seed = num(args[1])
	if not seed then
		return { "Usage: seed <n|off>" }
	end
	Rng.Seed(seed)
	return { ("Gameplay randomness seeded with %s."):format(fmt(seed)) }
end)

command("log", "log [n]", "Last n journal entries (default 10).", function(ctx, args)
	local log = ctx.state.Log
	local count = math.clamp(math.floor(num(args[1]) or 10), 1, 50)
	local lines = {}
	for i = math.max(1, #log - count + 1), #log do
		table.insert(lines, ("  %3d  %s"):format(log[i].Age or 0, log[i].Text))
	end
	return if #lines > 0 then lines else { "The journal is empty." }
end)

----------------------------------------------------------------------
-- Entry point
----------------------------------------------------------------------

local NO_STATE_COMMANDS = { help = true, pack = true, seed = true }

function DevConsole.Execute(player, line): { string }
	if not DevConsole.Enabled() then
		return { "The developer console only runs in Studio." }
	end
	if type(line) ~= "string" or #line == 0 or #line > DevConsole.MaxLineLength then
		return { ("Commands must be 1-%d characters."):format(DevConsole.MaxLineLength) }
	end
	local words = {}
	for word in string.gmatch(line, "%S+") do
		table.insert(words, word)
	end
	local name = string.lower(table.remove(words, 1) or "")
	local entry = commands[name]
	if not entry then
		return { ("Unknown command '%s'. Type help."):format(name) }
	end
	local state = PlayerState.Get(player)
	if not state and not NO_STATE_COMMANDS[name] then
		return { "No character is loaded for this player yet." }
	end
	local ctx = { player = player, state = state, changed = false }
	local ok, result = pcall(entry.Run, ctx, words)
	if ctx.changed and state then
		if not state.Dead then
			SystemRegistry.AfterChange(player, state) -- as GameManager does after any change
			PlayerState.CheckDeath(player)
		end
		PlayerState.Push(player)
	end
	if not ok then
		return { "Error: " .. tostring(result) }
	end
	local lines = if type(result) == "table" then result else { tostring(result) }
	if #lines > DevConsole.MaxOutputLines then
		local extra = #lines - DevConsole.MaxOutputLines
		lines = table.move(lines, 1, DevConsole.MaxOutputLines, 1, {})
		table.insert(lines, ("... %d more line(s)"):format(extra))
	end
	return lines
end

function DevConsole.Commands(): { string }
	return table.clone(order)
end

return DevConsole
