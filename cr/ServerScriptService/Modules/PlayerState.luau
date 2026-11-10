--[[
	PlayerState: authoritative per-player state (server only).
	Owns buffs, derived stats, XP, relationships helpers, life cycle, death,
	reincarnation, snapshots for the client and DataStore persistence.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Configs = ReplicatedStorage:WaitForChild("Configs")
local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
local BigNum = require(Configs:WaitForChild("BigNum"))
local Realms = Content.Get("RealmsConfig")
local Talents = Content.Get("TalentsConfig")
local Races = Content.Get("RacesConfig")
local StatsConfig = Content.Get("PlayerStatsConfig")
local Training = Content.Get("TrainingConfig")
local Titles = Content.Get("TitlesConfig")
local Masters = Content.Get("MastersConfig")
local Masteries = Content.Get("MasteriesConfig")
local Studies = Content.Get("StudiesAndCareerConfig")
local RelConfig = Content.Get("RelationshipsConfig")
local Items = Content.Get("ItemsConfig")
local Upgrades = Content.Get("SamsaraUpgradesConfig")
local Monetization = Content.Get("MonetizationConfig")
local GamePack = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GamePack"))
local PackTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PackTheme"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PlayerState = {}

PlayerState.SaveVersion = 2
PlayerState.MaxTalents = 2
PlayerState.TalentOfferCount = 4
PlayerState.RerollBaseCost = 3
PlayerState.LineageBonusPerLife = 0.05
PlayerState.PassiveQiPerYear = 0.05
PlayerState.MaxLog = 80
PlayerState.MaxLineage = 30

-- Module hooks (registered by systems at require time):
-- NewLifeHooks: fn(state) at the end of every new life (birth region, ...).
-- DeathRecorders: fn(state, lineageEntry, player) to add fields to the past-life record.
PlayerState.NewLifeHooks = {}
PlayerState.DeathRecorders = {}
-- RelationshipHooks: fn(state, rel) when someone enters your life (genetics, ...).
PlayerState.RelationshipHooks = {}
-- NpcChildHooks: fn(player, state, rel) when an NPC in your life has a baby (grandchildren).
PlayerState.NpcChildHooks = {}
PlayerState.SaveAttempts = 3

-- Game vocabulary for server messages (Configs/UIThemeConfig.Terms): write
-- Words("+%d {MetaCurrency}") instead of hardcoding "Karma", "Qi" or "bloodline".
PlayerState.Words = PackTheme.Words
PlayerState.Term = PackTheme.Term

-- Session locking: a save record carries _Lock = { Owner, Time }. Only the owning
-- server writes; autosaves refresh Time, so a crashed server's lock expires after
-- LockTimeout seconds. Studio has an empty JobId, so each session gets a GUID.
PlayerState.SessionId = if game.JobId ~= "" then game.JobId else HttpService:GenerateGUID(false)
PlayerState.LockTimeout = 300
PlayerState.LockAttempts = 3
PlayerState.LockRetryDelay = 2

-- Save migrations: [fromVersion] = function(data) -> data upgraded to fromVersion + 1.
-- Saves that cannot be migrated are backed up under a separate key, never overwritten.
PlayerState.Migrations = {}

local rng = require(script.Parent:WaitForChild("Rng"))
local states: { [Player]: any } = {}

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("LifePathSave_v2")
	end)
	if ok then
		store = result
	end
end

-- Swaps the DataStore (tests use an in-memory mock). Returns the previous one.
function PlayerState.SetStore(newStore)
	local previous = store
	store = newStore
	return previous
end

----------------------------------------------------------------------
-- Buffs (race + talents + equipped titles + masteries + techniques)
----------------------------------------------------------------------

-- Buff keys and how they combine come from GamePack.BuffDefs (modules may add keys).
local MULTIPLICATIVE, NESTED = {}, {}
for key, mode in GamePack.BuffDefs do
	if mode == "mult" then
		MULTIPLICATIVE[key] = true
	elseif mode == "nested" then
		NESTED[key] = true
	end
end

local function newBuffs()
	local buffs = {}
	for key, mode in GamePack.BuffDefs do
		buffs[key] = if mode == "mult" then 1 elseif mode == "nested" then {} else 0
	end
	return buffs
end

local function mergeBuffs(total, buffs)
	if not buffs then
		return
	end
	for key, value in buffs do
		if NESTED[key] then
			for sub, mult in value do
				total[key][sub] = (total[key][sub] or 1) * mult
			end
		elseif MULTIPLICATIVE[key] then
			total[key] *= value
		else
			total[key] = (total[key] or 0) + value
		end
	end
end

PlayerState.NewBuffs = newBuffs

----------------------------------------------------------------------
-- Collection Codex (permanent across lives)
----------------------------------------------------------------------

PlayerState.CodexGroups = { "Races", "Talents", "Titles", "Techniques" }

-- Records a discovery. Returns true when it is new.
function PlayerState.CodexAdd(state, group: string, id: string): boolean
	state.Codex = state.Codex or {}
	local set = state.Codex[group]
	if not set then
		set = {}
		state.Codex[group] = set
	end
	if set[id] then
		return false
	end
	set[id] = true
	return true
end

function PlayerState.CodexCount(state): number
	local count = 0
	for _, group in PlayerState.CodexGroups do
		for _ in (state.Codex and state.Codex[group]) or {} do
			count += 1
		end
	end
	return count
end

-- Codex buffs per entry count (cached: GetBuffs is a hot path).
local codexBuffCache = {}
local function codexBuffs(count: number)
	local cached = codexBuffCache[count]
	if not cached then
		cached = {}
		local codex = Talents.Codex or {}
		for _, key in codex.Buffs or {} do
			cached[key] = 1 + count * (codex.BonusPerEntry or 0)
		end
		codexBuffCache[count] = cached
	end
	return cached
end

-- Calls visit(kind, name, buffs) for every active modifier source, in merge order.
-- The single list behind GetBuffs (hot path: no allocation) and BuffSources.
local function eachBuffSource(state, visit)
	local race = Races.Get(state.Race)
	visit("Race", race.Name, race.Buffs)
	local entries = PlayerState.CodexCount(state)
	if entries > 0 then
		visit("Codex", ("%d entries"):format(entries), codexBuffs(entries))
	end
	-- Per-life buffs granted by modules (e.g. the era of a rebirth path).
	for _, source in state.LifeBuffs or {} do
		visit(source.Kind or "Life", source.Name, source.Buffs)
	end
	for _, id in state.Talents do
		local talent = Talents.Get(id)
		if talent then visit("Talent", talent.Name, talent.Buffs) end
	end
	if GamePack.IsEnabled("Titles") then
		for _, id in state.Titles.Equipped do
			local title = Titles.ById[id]
			if title then visit("Title", title.Name, title.Buffs) end
		end
	end
	if GamePack.IsEnabled("Masteries") then
		for id in state.Masteries do
			local node = Masteries.NodesById[id]
			if node then visit("Mastery", node.Name, node.Buffs) end
		end
	end
	if GamePack.IsEnabled("Masters") then
		for id in state.LearnedTechniques do
			local master = Masters.ById[id]
			if master then visit("Technique", master.Technique.Name or master.Name, master.Technique.Buffs) end
		end
	end
	if GamePack.IsEnabled("Inventory") and state.Inventory then
		for _, id in state.Inventory.Equipped do
			local item = Items.ById[id]
			if item and item.Equip then visit("Item", item.Name, item.Equip.Buffs) end
		end
	end
end

-- Sets (or clears, with nil buffs) the per-life buff source of one Kind (Region, Era, ...).
function PlayerState.SetLifeBuff(state, kind: string, name: string?, buffs)
	state.LifeBuffs = state.LifeBuffs or {}
	for i = #state.LifeBuffs, 1, -1 do
		if state.LifeBuffs[i].Kind == kind then
			table.remove(state.LifeBuffs, i)
		end
	end
	if buffs and next(buffs) then
		table.insert(state.LifeBuffs, { Kind = kind, Name = name or kind, Buffs = buffs })
	end
end

-- Every active modifier source as { Label, Buffs } (dev console).
function PlayerState.BuffSources(state)
	local sources = {}
	eachBuffSource(state, function(kind, name, buffs)
		if buffs and next(buffs) then
			table.insert(sources, { Label = kind .. ": " .. tostring(name), Buffs = buffs })
		end
	end)
	return sources
end

function PlayerState.GetBuffs(state)
	local total = newBuffs()
	eachBuffSource(state, function(_, _, buffs)
		mergeBuffs(total, buffs)
	end)
	return total
end

----------------------------------------------------------------------
-- Derived values
----------------------------------------------------------------------

function PlayerState.Get(player: Player)
	return states[player]
end

function PlayerState.All()
	return states
end

function PlayerState.StatLevels(state)
	local levels = {}
	for _, stat in StatsConfig.Order do
		levels[stat] = state.Stats[stat].Level
	end
	return levels
end

function PlayerState.GetLineageBonus(state): number
	return PlayerState.LineageBonusPerLife * math.max(0, state.Lives - 1)
end

function PlayerState.GetRequirement(state)
	return Realms.GetRequirement(state.RealmIndex, state.SubLevel)
end

function PlayerState.GetQiMultiplier(state, buffs): number
	buffs = buffs or PlayerState.GetBuffs(state)
	local realm = Realms.Get(state.RealmIndex)
	return realm.QiMultiplier * buffs.QiMult * StatsConfig.QiMultiplier(PlayerState.StatLevels(state)) * (1 + PlayerState.GetLineageBonus(state))
end

function PlayerState.GetPassiveGain(state, buffs)
	buffs = buffs or PlayerState.GetBuffs(state)
	return PlayerState.GetRequirement(state):Mul(PlayerState.PassiveQiPerYear * PlayerState.GetQiMultiplier(state, buffs) * buffs.PassiveQiMult)
end

function PlayerState.GetMaxLifespan(state, buffs): number
	buffs = buffs or PlayerState.GetBuffs(state)
	local years = Realms.GetLongevity(state.RealmIndex) + StatsConfig.LifespanBonus(PlayerState.StatLevels(state)) + buffs.LifespanBonus + state.BonusLifespan
	return math.max(1, math.floor(years * buffs.LifespanMult))
end

function PlayerState.GetMaxHealth(state, buffs): number
	buffs = buffs or PlayerState.GetBuffs(state)
	return math.max(10, StatsConfig.MaxHealth(PlayerState.StatLevels(state)) + buffs.MaxHealthBonus + state.BonusMaxHealth)
end

----------------------------------------------------------------------
-- Samsara upgrades and game passes
----------------------------------------------------------------------

function PlayerState.UpgradeRank(state, upgradeId: string): number
	return (state.Upgrades and state.Upgrades[upgradeId]) or 0
end

-- Sum of an upgrade effect over every owned rank (SamsaraUpgradesConfig).
function PlayerState.UpgradeEffect(state, effect: string): number
	local total = 0
	for _, upgrade in Upgrades.List or {} do
		if upgrade.Effect == effect then
			total += PlayerState.UpgradeRank(state, upgrade.Id) * (upgrade.PerRank or 0)
		end
	end
	return total
end

-- Owned game passes (runtime only, refreshed by MonetizationSystem; never saved).
function PlayerState.OwnsPass(state, passId: string): boolean
	return state.Passes ~= nil and state.Passes[passId] == true
end

local function passTotal(state, field: string, combine: string?)
	local total = if combine == "max" then 1 else 0
	for _, pass in Monetization.Passes or {} do
		if PlayerState.OwnsPass(state, pass.Id) and pass[field] then
			total = if combine == "max" then math.max(total, pass[field]) else total + pass[field]
		end
	end
	return total
end

function PlayerState.GetGoldenActions(state): number
	return passTotal(state, "GoldenActions")
end

function PlayerState.GetSpinLuck(state): number
	return PlayerState.UpgradeEffect(state, "SpinLuck") + passTotal(state, "Luck")
end

function PlayerState.GetSpinSpeed(state): number
	return passTotal(state, "SpinSpeed", "max")
end

-- Seconds per auto-aged year: the fastest owned pass (Celestial Timekeeper), else `default`.
function PlayerState.GetAutoAgeSeconds(state, default: number): number
	local seconds = default
	for _, pass in Monetization.Passes or {} do
		if PlayerState.OwnsPass(state, pass.Id) and pass.AutoAgeSeconds then
			seconds = math.min(seconds, pass.AutoAgeSeconds)
		end
	end
	return seconds
end

-- Ancestral Bloodline Vault: locking a bloodline on the Wheel is free.
function PlayerState.HasFreeLock(state): boolean
	for _, pass in Monetization.Passes or {} do
		if pass.FreeLock and PlayerState.OwnsPass(state, pass.Id) then
			return true
		end
	end
	return false
end

-- Name badges of owned passes (e.g. "VIP").
function PlayerState.GetBadges(state): { string }
	local badges = {}
	for _, pass in Monetization.Passes or {} do
		if pass.Badge and PlayerState.OwnsPass(state, pass.Id) then
			table.insert(badges, pass.Badge)
		end
	end
	return badges
end

-- Yearly action diamonds. Free slots: base (2) + Temporal Awareness + stat peak +
-- realm passive + age windows + buffs, capped at FreeActionCap (4); golden slots
-- from game passes come on top, all within MaxActionSlots (6).
function PlayerState.GetMaxActions(state, buffs): number
	buffs = buffs or PlayerState.GetBuffs(state)
	local slots = Training.BaseActionSlots + buffs.ActionSlots + PlayerState.UpgradeEffect(state, "ActionSlots")
	if StatsConfig.ActionBonus then
		slots += StatsConfig.ActionBonus(PlayerState.StatLevels(state))
	end
	if GamePack.IsEnabled("Cultivation") then
		slots += Realms.Get(state.RealmIndex).ActionSlots or 0
	end
	for _, bonus in Training.SlotBonuses or {} do
		if state.Age >= (bonus.MinAge or 0) and state.Age <= (bonus.MaxAge or math.huge) then
			slots += bonus.Slots
		end
	end
	slots = math.min(math.floor(slots), Training.FreeActionCap or Training.MaxActionSlots)
	return math.clamp(slots + PlayerState.GetGoldenActions(state), 1, Training.MaxActionSlots)
end

-- Social interactions allowed per year (across all relationships).
function PlayerState.GetMaxSocial(state): number
	return (RelConfig.SocialPerYear or 4) + PlayerState.UpgradeEffect(state, "SocialSlots")
end

-- New year: refill action slots and the social budget, clear the per-year counters.
function PlayerState.StartYear(state, buffs)
	state.Actions = PlayerState.GetMaxActions(state, buffs)
	state.ActionCounts = {}
	state.Social = PlayerState.GetMaxSocial(state)
	state.SocialDone = {}
end

-- Years left before the current sub-level is stable enough to break through.
function PlayerState.GetBreakthroughWait(state): number
	local years = Realms.Get(state.RealmIndex).YearsPerLevel or 0
	return math.max(0, years - (state.Age - (state.LevelSince or -math.huge)))
end

function PlayerState.GetBreakthroughChance(state, buffs): number
	buffs = buffs or PlayerState.GetBuffs(state)
	local chance = Realms.GetSuccessChance(state.RealmIndex, state.SubLevel) + buffs.BreakthroughBonus + StatsConfig.BreakthroughBonus(PlayerState.StatLevels(state))
		+ (state.PillBonus or 0) -- Instant Miracle Pill, spent by the next attempt (CultivationSystem)
	return math.clamp(chance, Realms.MinChance, Realms.MaxChance)
end

function PlayerState.GetSocialBonus(state, buffs): number
	buffs = buffs or PlayerState.GetBuffs(state)
	return StatsConfig.SocialBonus(PlayerState.StatLevels(state)) + buffs.SocialBonus
end

-- Stat key that plays `role` in PlayerStatsConfig.Roles (nil if the pack has none).
function PlayerState.RoleStat(role: string): string?
	local stat = StatsConfig.Roles and StatsConfig.Roles[role]
	return if stat and StatsConfig.Stats[stat] then stat else nil
end

function PlayerState.RoleLevel(state, role: string): number
	local stat = PlayerState.RoleStat(role)
	return if stat and state.Stats[stat] then state.Stats[stat].Level else 0
end

-- Chance helper: base + 1% per level of `stat` (+ social buffs for the Social stat).
function PlayerState.RollChance(state, base: number, stat: string?, buffs): (boolean, number)
	local chance = base
	if stat and state.Stats[stat] then
		chance += state.Stats[stat].Level * 0.01
		if stat == PlayerState.RoleStat("Social") then
			chance += (buffs or PlayerState.GetBuffs(state)).SocialBonus
		end
	end
	chance = math.clamp(chance, 0.05, 0.95)
	return rng:NextNumber() < chance, chance
end

local function moodMultiplier(state): number
	local mult = 1
	if state.Stress >= StatsConfig.HighStress then mult *= StatsConfig.HighStressXpMult end
	if state.Happiness <= StatsConfig.LowHappiness then mult *= StatsConfig.LowHappinessXpMult end
	return mult
end

function PlayerState.GetStatXpMultiplier(state, stat: string, buffs): number
	buffs = buffs or PlayerState.GetBuffs(state)
	return buffs.AllStatXp * (buffs.StatXp[stat] or 1) * (1 + 0.25 * (state.RealmIndex - 1)) * moodMultiplier(state)
end

function PlayerState.GetProficiencyXpMultiplier(state, key: string, buffs): number
	buffs = buffs or PlayerState.GetBuffs(state)
	return (buffs.ProficiencyXp[key] or 1) * moodMultiplier(state)
end

function PlayerState.GetSalary(state, buffs): number
	local career = state.Career.Id and Studies.CareersById[state.Career.Id]
	if not career then
		return 0
	end
	buffs = buffs or PlayerState.GetBuffs(state)
	local raise = 1 + Studies.RaisePerYear * state.Career.Years
	local performance = 0.75 + state.Career.Performance / 200
	return math.floor(career.Salary * raise * performance * buffs.SalaryMult)
end

----------------------------------------------------------------------
-- Mutators
----------------------------------------------------------------------

-- Levels stop at PlayerStatsConfig.MaxLevel (attributes and proficiencies), so maxing
-- everything in one life is out of reach with a few actions a year.
local function addXp(entry, amount: number): number
	local cap = StatsConfig.MaxLevel or math.huge
	if entry.Level >= cap then
		entry.Xp = 0
		return 0
	end
	entry.Xp += amount
	local gained = 0
	while entry.Level < cap and entry.Xp >= StatsConfig.XpForLevel(entry.Level) do
		entry.Xp -= StatsConfig.XpForLevel(entry.Level)
		entry.Level += 1
		gained += 1
	end
	return gained
end

-- Returns the XP actually granted after multipliers.
function PlayerState.AddStatXp(player: Player, state, stat: string, amount: number, buffs): number
	local entry = state.Stats[stat]
	if not entry or amount <= 0 then
		return 0
	end
	local xp = math.floor(amount * PlayerState.GetStatXpMultiplier(state, stat, buffs) + 0.5)
	local gained = addXp(entry, xp)
	if gained > 0 then
		state.MasteryPoints += gained * Masteries.PointsPerStatLevel
		PlayerState.Log(player, ("%s reached level %d (+%d mastery point%s)."):format(
			StatsConfig.Stats[stat].Name, entry.Level, gained, if gained > 1 then "s" else ""), "good")
	end
	return xp
end

function PlayerState.AddProficiencyXp(player: Player, state, key: string, amount: number, buffs): number
	local entry = state.Proficiencies[key]
	if not entry or amount <= 0 then
		return 0
	end
	local xp = math.floor(amount * PlayerState.GetProficiencyXpMultiplier(state, key, buffs) + 0.5)
	if addXp(entry, xp) > 0 then
		PlayerState.Log(player, ("%s proficiency reached level %d."):format(Training.Proficiencies[key].Name, entry.Level), "good")
	end
	return xp
end

function PlayerState.AdjustMeter(state, meter: string, delta: number)
	state[meter] = math.clamp(state[meter] + delta, 0, 100)
end

function PlayerState.AddHealth(state, delta: number, buffs)
	state.Health = math.min(state.Health + delta, PlayerState.GetMaxHealth(state, buffs))
end

-- Qi cannot exceed the requirement: the bottleneck must be broken first.
function PlayerState.AddQi(state, amount)
	state.Qi = state.Qi:Add(amount):Min(PlayerState.GetRequirement(state)):Max(0)
end

function PlayerState.FormatMoney(amount: number): string
	local symbol = PackTheme.Get().Terms.MoneySymbol or "$" -- "¥" for yen
	if amount < 0 then
		return "-" .. symbol .. BigNum.from(-amount):ToString()
	end
	return symbol .. BigNum.from(math.floor(amount)):ToString()
end

----------------------------------------------------------------------
-- Relationships
----------------------------------------------------------------------

-- Avoids names already used by the character or the people in their life.
function PlayerState.RandomPersonName(surname: string?, state): string
	local name
	for _ = 1, 10 do
		local first = RelConfig.FirstNames[rng:NextInteger(1, #RelConfig.FirstNames)]
		name = first .. " " .. (surname or RelConfig.Surnames[rng:NextInteger(1, #RelConfig.Surnames)])
		local taken = state ~= nil and name == state.Name
		for _, rel in (state and state.Relationships) or {} do
			if rel.Name == name then
				taken = true
				break
			end
		end
		if not taken then
			break
		end
	end
	return name
end

function PlayerState.CreateRelationship(state, relType: string, opts)
	opts = opts or {}
	if #state.Relationships >= RelConfig.MaxRelationships or not RelConfig.Types[relType] then
		return nil
	end
	state.NextRelId += 1
	local rel = {
		Id = "r" .. state.NextRelId,
		Name = opts.Name or PlayerState.RandomPersonName(nil, state),
		Type = relType,
		Category = RelConfig.Types[relType].Category,
		Age = opts.Age or math.max(0, state.Age + rng:NextInteger(-2, 2)),
		Affection = math.clamp(opts.Affection or 50, 0, 100),
		Alive = true,
		LastHelpAge = -1,
	}
	table.insert(state.Relationships, rel)
	for _, hook in PlayerState.RelationshipHooks do
		hook(state, rel, opts)
	end
	return rel
end

function PlayerState.FindRelationship(state, id)
	for _, rel in state.Relationships do
		if rel.Id == id then
			return rel
		end
	end
	return nil
end

function PlayerState.RemoveRelationship(state, id)
	for i, rel in state.Relationships do
		if rel.Id == id then
			table.remove(state.Relationships, i)
			return
		end
	end
end

function PlayerState.SetRelationshipType(rel, relType: string)
	rel.Type = relType
	rel.Category = RelConfig.Types[relType].Category
end

-- Positive changes are scaled by RelationshipMult. Returns the applied delta.
function PlayerState.AdjustAffection(rel, delta: number, buffs): number
	if delta > 0 and buffs then
		delta *= buffs.RelationshipMult
	end
	delta = math.floor(delta + 0.5)
	rel.Affection = math.clamp(rel.Affection + delta, 0, 100)
	return delta
end

----------------------------------------------------------------------
-- Inventory
----------------------------------------------------------------------

-- The character's inventory; per-year use counters reset on a new age.
-- Per-life data bag of an engine module, created from `defaults` on first use.
-- Saved with the character and sent to the client as Snapshot.Modules.
function PlayerState.ModuleData(state, moduleId: string, defaults)
	state.Modules = state.Modules or {}
	local data = state.Modules[moduleId]
	if not data then
		data = table.clone(defaults or {})
		state.Modules[moduleId] = data
	end
	return data
end

function PlayerState.Inventory(state)
	state.Inventory = state.Inventory or { Items = {}, Equipped = {}, Uses = {}, UsesAge = -1 }
	local inventory = state.Inventory
	if inventory.UsesAge ~= state.Age then
		inventory.Uses = {}
		inventory.UsesAge = state.Age
	end
	return inventory
end

function PlayerState.ItemCount(state, itemId: string): number
	return PlayerState.Inventory(state).Items[itemId] or 0
end

-- Adds (or removes, with a negative count) items within MaxStack. Removing the
-- last copy of an equipped item unequips it. Returns the change applied.
function PlayerState.AddItem(state, itemId: string, count: number): number
	local item = Items.ById[itemId]
	if not item or count == 0 then
		return 0
	end
	local inventory = PlayerState.Inventory(state)
	local current = inventory.Items[itemId] or 0
	local new = math.clamp(current + count, 0, Items.MaxStack(item))
	inventory.Items[itemId] = if new > 0 then new else nil
	if new == 0 then
		for slot, equipped in inventory.Equipped do
			if equipped == itemId then
				inventory.Equipped[slot] = nil
			end
		end
	end
	return new - current
end

PlayerState.MaxMemories = 4

-- Something a person remembers about the character (newest first). Mood: 1 good, -1 bad.
function PlayerState.Remember(state, rel, text: string, mood: number?)
	rel.Memories = rel.Memories or {}
	table.insert(rel.Memories, 1, { Age = state.Age, Text = text, Mood = mood or 0 })
	while #rel.Memories > PlayerState.MaxMemories do
		table.remove(rel.Memories)
	end
end

----------------------------------------------------------------------
-- Log / notify / push
----------------------------------------------------------------------

function PlayerState.Log(player: Player, text: string, kind: string?)
	local state = states[player]
	if not state then
		return
	end
	local entry = { Age = state.Age, Text = text, Kind = kind or "info" }
	table.insert(state.Log, entry)
	while #state.Log > PlayerState.MaxLog do
		table.remove(state.Log, 1)
	end
	PlayerState.Fire(Remotes.LogEntry, player, entry)
end

-- Only real players receive network messages; simulated (test) players are skipped.
function PlayerState.Fire(remote: RemoteEvent, player, ...)
	if typeof(player) == "Instance" and player:IsA("Player") then
		remote:FireClient(player, ...)
	end
end

-- Audio / juice cues for the client (StarterPlayerScripts/SoundFX): Clash, DuelWin,
-- BreakthroughSuccess, BreakthroughFail, Milestone, Ascend, ...
function PlayerState.Feedback(player, cue: string, data)
	if Remotes:FindFirstChild("Feedback") then
		PlayerState.Fire(Remotes.Feedback, player, cue, data)
	end
end

function PlayerState.Notify(player: Player, text: string, kind: string?)
	PlayerState.Fire(Remotes.Notify, player, text, kind or "info")
end

local function levelBlock(block, order, multFn, state, buffs)
	local out = {}
	for _, key in order do
		local entry = block[key]
		out[key] = {
			Level = entry.Level,
			Xp = entry.Xp,
			Next = StatsConfig.XpForLevel(entry.Level),
			XpMult = multFn(state, key, buffs),
		}
	end
	return out
end

function PlayerState.Snapshot(state)
	local buffs = PlayerState.GetBuffs(state)
	local realm = Realms.Get(state.RealmIndex)
	local requirement = PlayerState.GetRequirement(state)
	local qiMult = PlayerState.GetQiMultiplier(state, buffs)
	-- Qi each Qi-gathering action would give right now (packs may have none).
	local qiGains = {}
	for _, action in Training.Actions do
		if action.QiFraction then
			qiGains[action.Id] = requirement:Mul(action.QiFraction * qiMult):ToString()
		end
	end
	return {
		Name = state.Name,
		RaceId = state.Race,
		Race = Races.Get(state.Race).Name,
		Age = state.Age,
		MaxLifespan = PlayerState.GetMaxLifespan(state, buffs),
		Lives = state.Lives,
		LineageBonus = PlayerState.GetLineageBonus(state),
		Karma = state.Karma,
		Alignment = state.Alignment,
		Health = math.max(0, math.floor(state.Health)),
		MaxHealth = PlayerState.GetMaxHealth(state, buffs),
		Happiness = math.floor(state.Happiness),
		Stress = math.floor(state.Stress),
		Actions = state.Actions,
		MaxActions = PlayerState.GetMaxActions(state, buffs),
		GoldenActions = math.min(PlayerState.GetGoldenActions(state), PlayerState.GetMaxActions(state, buffs)),
		Upgrades = state.Upgrades or {},
		Passes = state.Passes or {},
		SpinLuck = PlayerState.GetSpinLuck(state),
		SpinSpeed = PlayerState.GetSpinSpeed(state),
		Badges = PlayerState.GetBadges(state),
		FreeLock = PlayerState.HasFreeLock(state),
		PillBonus = state.PillBonus or 0,
		Revivable = PlayerState.CanRevive(state),
		TutorialCompleted = state.TutorialCompleted == true,
		TutorialStep = state.TutorialStep or 0,
		ActionCounts = state.ActionCounts or {},
		Social = state.Social,
		MaxSocial = PlayerState.GetMaxSocial(state),
		SocialDone = state.SocialDone or {},
		Money = math.floor(state.Money),

		Realm = realm.Name,
		RealmColor = realm.Color,
		RealmIndex = state.RealmIndex,
		SubLevel = state.SubLevel,
		SubLevels = Realms.SubLevels,
		IsMaxed = Realms.IsMaxed(state.RealmIndex, state.SubLevel),
		Qi = state.Qi:ToString(),
		QiRequired = requirement:ToString(),
		QiProgress = math.clamp(state.Qi:Div(requirement):ToNumber(), 0, 1),
		QiPerYear = PlayerState.GetPassiveGain(state, buffs):ToString(),
		QiMultiplier = string.format("%.2f", qiMult),
		QiGains = qiGains,
		BreakthroughChance = PlayerState.GetBreakthroughChance(state, buffs),
		BreakthroughWait = PlayerState.GetBreakthroughWait(state),

		Stats = levelBlock(state.Stats, StatsConfig.Order, PlayerState.GetStatXpMultiplier, state, buffs),
		Proficiencies = levelBlock(state.Proficiencies, Training.ProficiencyOrder, PlayerState.GetProficiencyXpMultiplier, state, buffs),
		Counters = state.Counters,
		Flags = state.Flags,
		Modules = state.Modules or {},

		Education = state.Education,
		Graduated = state.Graduated,
		Honors = state.Honors,
		Career = { Id = state.Career.Id, Years = state.Career.Years, Performance = state.Career.Performance, Salary = PlayerState.GetSalary(state, buffs) },
		SocialStatus = Studies.GetSocialStatus(state.Graduated, state.Career.Id),

		Master = state.Master,
		DiscoveredMasters = state.DiscoveredMasters,
		LearnedTechniques = state.LearnedTechniques,
		Relationships = state.Relationships,
		Masteries = state.Masteries,
		MasteryPoints = state.MasteryPoints,
		Titles = state.Titles,
		MaxEquippedTitles = Titles.MaxEquipped,
		Inventory = PlayerState.Inventory(state),

		Talents = state.Talents,
		Lineage = state.Lineage,
		Heirlooms = state.Heirlooms or {},
		Legacy = state.Legacy,
		Creation = state.Creation,
		PendingDuel = state.PendingDuel,
		Ascensions = state.Ascensions or 0,
		Dead = state.Dead,
		DeathCause = state.DeathCause,
		Wheel = state.Wheel,
		SpinCosts = { Bloodline = Races.Spin and Races.Spin.Cost, Talent = Talents.Spin and Talents.Spin.Cost,
			Lock = Races.Spin and (if PlayerState.HasFreeLock(state) then 0 else Races.Spin.LockCost) },
		Codex = state.Codex,
		CodexCount = PlayerState.CodexCount(state),
		CodexBonus = PlayerState.CodexCount(state) * ((Talents.Codex and Talents.Codex.BonusPerEntry) or 0),
		MaxTalents = PlayerState.MaxTalents,
		HasPendingEvent = state.PendingEvent ~= nil or #state.EventQueue > 0,
		AutoAge = state.AutoAge,
	}
end

function PlayerState.Push(player: Player, includeLog: boolean?)
	local state = states[player]
	if state then
		PlayerState.Fire(Remotes.StateUpdate, player, PlayerState.Snapshot(state), if includeLog then state.Log else nil)
	end
end

----------------------------------------------------------------------
-- Life cycle
----------------------------------------------------------------------

local function newLevelBlock(order, base)
	local block = {}
	for _, key in order do
		block[key] = { Level = (base and base[key]) or 0, Xp = 0 }
	end
	return block
end

local function startNewLife(state, talents, raceId)
	local race = Races.Get(if GamePack.IsEnabled("Lineages") then raceId or Races.Default else Races.Default)
	local surname = RelConfig.Surnames[rng:NextInteger(1, #RelConfig.Surnames)]

	state.Lives += 1
	state.Name = PlayerState.RandomPersonName(surname)
	state.Race = race.Id
	state.Talents = talents or {}
	state.Age = 0
	state.Stats = newLevelBlock(StatsConfig.Order, race.BaseStats)
	state.Proficiencies = newLevelBlock(Training.ProficiencyOrder)
	state.Qi = BigNum.zero()
	state.RealmIndex = 1
	state.SubLevel = 1
	state.LevelSince = 0
	state.BonusLifespan = 0
	state.BonusMaxHealth = 0
	state.Alignment = 0
	state.Happiness = 70
	state.Stress = 10
	state.Counters = { Knowledge = 0, Fights = 0 }
	state.Flags = {}
	state.Education = { Tier = nil, Enrolled = false, Years = 0, Performance = 50 }
	state.Graduated = {}
	state.Honors = {}
	state.Career = { Id = nil, Years = 0, Performance = 50 }
	state.Master = { Id = nil, Loyalty = 0, QuestsDone = {} }
	state.DiscoveredMasters = {}
	state.LearnedTechniques = {}
	state.Relationships = {}
	state.NextRelId = 0
	state.Masteries = {}
	state.MasteryPoints = 0
	state.Titles = { Unlocked = {}, Equipped = {} }
	state.Inventory = { Items = {}, Equipped = {}, Uses = {}, UsesAge = -1 }
	state.Modules = {} -- per-life data of registry modules (PlayerState.ModuleData)
	state.LifeBuffs = {} -- per-life buff sources granted by modules ({ Kind, Name, Buffs })
	state.SeenEvents = {}
	state.EventQueue = {}
	state.ScheduledEvents = {}
	state.ScheduledEffects = {}
	state.EventLastAge = {}
	state.PendingEvent = nil
	state.Dead = false
	state.DeathCause = nil
	state.WarnedOldAge = false
	state.Log = {}

	PlayerState.CodexAdd(state, "Races", race.Id)
	for _, id in state.Talents do
		PlayerState.CodexAdd(state, "Talents", id)
	end

	local buffs = PlayerState.GetBuffs(state)
	state.Money = 50 + buffs.StartingMoney
	state.Health = PlayerState.GetMaxHealth(state, buffs)
	PlayerState.StartYear(state, buffs)

	-- Family
	if GamePack.IsEnabled("Relationships") then
		PlayerState.CreateRelationship(state, "Mother", { Name = PlayerState.RandomPersonName(surname, state), Age = rng:NextInteger(20, 35), Affection = rng:NextInteger(60, 85) })
		PlayerState.CreateRelationship(state, "Father", { Name = PlayerState.RandomPersonName(surname, state), Age = rng:NextInteger(22, 40), Affection = rng:NextInteger(55, 85) })
		for _ = 1, rng:NextInteger(0, 2) do
			PlayerState.CreateRelationship(state, "Sibling", { Name = PlayerState.RandomPersonName(surname, state), Age = rng:NextInteger(1, 8), Affection = rng:NextInteger(45, 75) })
		end
	end
	for _, hook in PlayerState.NewLifeHooks do
		hook(state)
	end
end

-- Changes the bloodline of a newborn (Life 1 starter spins): base stats, health, Codex.
function PlayerState.SetRace(state, raceId: string)
	local race = Races.Get(raceId)
	state.Race = race.Id
	state.Stats = newLevelBlock(StatsConfig.Order, race.BaseStats)
	PlayerState.CodexAdd(state, "Races", race.Id)
	state.Health = PlayerState.GetMaxHealth(state)
end

-- The Wheel of Reincarnation (WheelSystem): the bloodline and talents of the next
-- life, spin pity counters and a bloodline locked across lives.
function PlayerState.NewWheel()
	return { Race = Races.Default, Talents = {}, Pity = { Bloodline = {}, Talent = {} }, StoredRace = nil, Spins = 0 }
end

local function defaultState()
	return {
		Karma = 0, Lives = 0, Lineage = {}, Log = {}, AutoAge = false,
		Codex = { Races = {}, Talents = {}, Titles = {}, Techniques = {} },
		Wheel = PlayerState.NewWheel(),
		Upgrades = {}, -- Samsara meta-upgrade ranks (permanent)
		Heirlooms = {}, -- ancestral heirlooms across lives (Dynasty module)
		Creation = { Spins = 3 }, -- Life 1 free starter spins (CreationSystem)
	}
end

-- Builds a fresh first-life state without registering a player (tests, simulations).
function PlayerState.CreateState(talents, raceId)
	local state = defaultState()
	startNewLife(state, talents or {}, raceId)
	return state
end

-- Registers a state for a player key. Non-Player keys act as simulated players.
function PlayerState.Track(player, state)
	states[player] = state
end

-- Miracle Revival: an untimely death keeps a copy of the life it ended (runtime only,
-- never saved), so a revival can restore it. [state] = { Copy, Karma }.
local revivals = setmetatable({}, { __mode = "k" })

-- options.Final: no revival possible (natural death, ascension).
function PlayerState.Die(player: Player, cause: string, options: { Final: boolean? }?)
	local state = states[player]
	if not state or state.Dead then
		return
	end
	local buffs = PlayerState.GetBuffs(state)
	local untimely = not (options and options.Final) and state.Age < PlayerState.GetMaxLifespan(state, buffs)
		and not (state.Flags and state.Flags.Revived)
	revivals[state] = if untimely then { Copy = Content.DeepCopy(state) } else nil
	local titles, degrees = 0, 0
	for _ in state.Titles.Unlocked do titles += 1 end
	for _ in state.Graduated do degrees += 1 end
	local raw = 1 + (state.RealmIndex - 1) * 3 + state.SubLevel * 0.3 + state.Age / 25
		+ math.max(0, state.Alignment) / 25 + titles * 0.5 + degrees * 0.5
	local earned = math.max(1, math.floor(raw * buffs.KarmaMult))

	if revivals[state] then
		revivals[state].Karma = earned
	end
	state.Dead = true
	state.DeathCause = cause
	state.PendingEvent = nil
	state.EventQueue = {}
	state.ScheduledEvents = {}
	state.ScheduledEffects = {}
	state.Karma += earned
	-- The next life starts from the locked bloodline (or the default) and no talents.
	state.Wheel = state.Wheel or PlayerState.NewWheel()
	state.Wheel.Race = state.Wheel.StoredRace or Races.Default
	state.Wheel.Talents = {}
	state.Wheel.Legacy, state.Wheel.Heir, state.Wheel.HeirMode = nil, nil, nil

	local entry = {
		Life = state.Lives,
		Name = state.Name,
		Race = Races.Get(state.Race).Name,
		Realm = Realms.Get(state.RealmIndex).Name,
		RealmIndex = state.RealmIndex,
		SubLevel = state.SubLevel,
		Age = state.Age,
		Cause = cause,
		Karma = earned,
		Occupation = state.Career.Id and Studies.CareersById[state.Career.Id] and Studies.CareersById[state.Career.Id].Name or nil,
	}
	for _, rel in state.Relationships do
		if rel.Alive and rel.Type == "Rival" and not entry.Rival then
			entry.Rival = rel.Name
		elseif rel.Alive and rel.Type == "Partner" and not entry.Partner then
			entry.Partner = rel.Name
		end
	end
	for _, record in PlayerState.DeathRecorders do
		record(state, entry, player)
	end
	table.insert(state.Lineage, 1, entry)
	while #state.Lineage > PlayerState.MaxLineage do
		table.remove(state.Lineage)
	end

	PlayerState.Log(player, PlayerState.Words("%s dies at age %d. %s (+%d {MetaCurrency})"):format(state.Name, state.Age, cause, earned), "death")
	PlayerState.Notify(player, PlayerState.Words("You have died. The {RebirthWheel} awaits."), "death")
	PlayerState.Push(player)
end

function PlayerState.CanRevive(state): boolean
	return state.Dead == true and revivals[state] ~= nil
end

-- The offer ends once the player acts on the Wheel (spins, upgrades, rebirth).
function PlayerState.ClearRevival(state)
	revivals[state] = nil
end

-- Restores the life that just ended at ReviveHealth of max health. Karma earned by
-- the death is taken back; purchases, passes and tutorial progress are kept.
function PlayerState.Revive(player): boolean
	local state = states[player]
	local entry = state and revivals[state]
	if not entry or not state.Dead then
		return false
	end
	revivals[state] = nil
	local keep = {
		Karma = math.max(0, state.Karma - (entry.Karma or 0)), Receipts = state.Receipts, Passes = state.Passes,
		TutorialCompleted = state.TutorialCompleted, TutorialStep = state.TutorialStep, PillBonus = state.PillBonus,
		AutoAge = false,
	}
	for field in state do
		state[field] = nil
	end
	for field, value in entry.Copy do
		state[field] = value
	end
	for field, value in keep do
		state[field] = value
	end
	-- Whatever was in progress when the blow landed is over.
	state.PendingEvent, state.PendingDuel = nil, nil
	state.EventQueue = {}
	state.Flags = state.Flags or {}
	state.Flags.Revived = true
	state.Health = math.max(1, PlayerState.GetMaxHealth(state) * (Monetization.ReviveHealth or 0.5))
	PlayerState.Log(player, PackTheme.Term("ReviveLog"):format(state.Name, state.Age), "realm")
	PlayerState.Feedback(player, "Revive")
	return true
end

-- Returns true if the character is (now) dead.
function PlayerState.CheckDeath(player: Player): boolean
	local state = states[player]
	if not state then
		return false
	elseif state.Dead then
		return true
	end
	if state.Health <= 0 then
		PlayerState.Die(player, "Their wounds proved fatal.")
		return true
	elseif state.Age >= PlayerState.GetMaxLifespan(state) then
		PlayerState.Die(player, "Natural death: their lifespan ran out.", { Final = true })
		return true
	end
	return false
end

-- Rebirth with what the Wheel holds (spun with WheelSystem; nothing to pay here).
function PlayerState.Reincarnate(player: Player): boolean
	local state = states[player]
	if not state or not state.Dead then
		return false
	end
	local wheel = state.Wheel or PlayerState.NewWheel()
	local raceId = if GamePack.IsEnabled("Lineages") and Races.ById[wheel.Race] then wheel.Race else Races.Default
	local chosen = {}
	for slot = 1, PlayerState.MaxTalents do
		local id = wheel.Talents[slot]
		if id and Talents.Get(id) then
			table.insert(chosen, id)
		end
	end
	wheel.Talents = {}
	startNewLife(state, chosen, raceId)
	PlayerState.Log(player, ("You are reborn as %s, a %s. Life #%d of your lineage."):format(state.Name, Races.Get(state.Race).Name, state.Lives), "realm")
	for _, id in chosen do
		PlayerState.Log(player, "Innate talent: " .. Talents.Get(id).Name, "good")
	end
	PlayerState.Push(player, true)
	return true
end

----------------------------------------------------------------------
-- Persistence
----------------------------------------------------------------------

local function key(player: Player): string
	return "u_" .. player.UserId
end

-- Takes this server's session lock on the player's save and returns
-- ("acquired", data | nil), ("locked", nil) when another live server holds it,
-- or ("error", nil) when the DataStore cannot be reached.
function PlayerState.AcquireLock(player)
	local outcome, record, lastError = "error", nil, nil
	for attempt = 1, PlayerState.LockAttempts do
		outcome = "error"
		local ok, err = pcall(store.UpdateAsync, store, key(player), function(current)
			local now = os.time()
			if type(current) ~= "table" then
				current = {}
			end
			local lock = current._Lock
			if type(lock) == "table" and lock.Owner ~= PlayerState.SessionId and now - (tonumber(lock.Time) or 0) < PlayerState.LockTimeout then
				outcome = "locked"
				return nil -- cancel: another live server owns this save
			end
			current._Lock = { Owner = PlayerState.SessionId, Time = now }
			outcome, record = "acquired", current
			return current
		end)
		if not ok then
			outcome, lastError = "error", err
			-- Permanent failures (no API access in Studio, forbidden) will not recover by waiting.
			local message = tostring(err)
			if string.find(message, "StudioAccessToApisNotAllowed", 1, true) or string.find(message, "403", 1, true) then
				break
			end
		end
		if outcome == "acquired" then
			local data = table.clone(record)
			data._Lock = nil
			return "acquired", if next(data) then data else nil
		end
		if attempt < PlayerState.LockAttempts then
			task.wait(PlayerState.LockRetryDelay * attempt)
		end
	end
	if outcome == "error" then
		warn("[PlayerState] Load failed:", lastError)
	end
	return outcome, nil
end

-- Drops this server's lock without touching the save (read-only sessions, ghosts).
function PlayerState.ReleaseLock(player)
	if not store or not player.UserId then
		return
	end
	pcall(store.UpdateAsync, store, key(player), function(current)
		if type(current) == "table" and type(current._Lock) == "table" and current._Lock.Owner == PlayerState.SessionId then
			current._Lock = nil
			return current
		end
		return nil
	end)
end

function PlayerState.Load(player: Player)
	local data
	local loadFailed = false
	if store then
		local outcome
		outcome, data = PlayerState.AcquireLock(player)
		if outcome == "locked" then
			warn(("[PlayerState] Save for %s is locked by another server."):format(tostring(player)))
			if typeof(player) == "Instance" then
				player:Kick("Your save is still open on another server. Please rejoin in a minute.")
			end
			return nil
		end
		loadFailed = outcome == "error"
	end
	-- The player may have left while the save was loading: don't register a ghost state.
	if typeof(player) == "Instance" and player.Parent == nil then
		if not loadFailed then
			PlayerState.ReleaseLock(player)
		end
		return nil
	end

	local state = defaultState()
	states[player] = state
	-- The real save may exist but be unreachable: never overwrite it with a fresh life.
	state.ReadOnly = loadFailed or nil
	if type(data) == "table" and data.Lives and data.Lives > 0 then
		data = PlayerState.PrepareSave(player, state, data)
	end
	if type(data) == "table" and data.Version == PlayerState.SaveVersion and data.Lives and data.Lives > 0 then
		for k, v in data do
			state[k] = v
		end
		state.Qi = BigNum.from(data.Qi)
		state.EventQueue = state.EventQueue or {}
		state.Upgrades = state.Upgrades or {}
		state.LifeBuffs = state.LifeBuffs or {}
		state.Heirlooms = state.Heirlooms or {}
		-- Saves from before the Spirit Root gate: older children already awakened.
		if state.Flags and (state.Age or 0) >= 7 then
			state.Flags.SpiritRoot = true
		end
		-- Saves from before the Wheel / Codex: start both and seed the Codex.
		if not state.Wheel then
			state.Wheel = PlayerState.NewWheel()
			state.TalentOffers, state.RerollCount = nil, nil
		end
		if not state.Codex then
			state.Codex = { Races = {}, Talents = {}, Titles = {}, Techniques = {} }
			PlayerState.CodexAdd(state, "Races", state.Race)
			for _, id in state.Talents or {} do PlayerState.CodexAdd(state, "Talents", id) end
			for id in (state.Titles and state.Titles.Unlocked) or {} do PlayerState.CodexAdd(state, "Titles", id) end
			for id in state.LearnedTechniques or {} do PlayerState.CodexAdd(state, "Techniques", id) end
		end
		-- Saves from before yearly action slots carried an Energy pool.
		if state.Actions == nil then
			state.Energy = nil
			PlayerState.StartYear(state)
		end
	else
		startNewLife(state, {}, Races.Default)
		PlayerState.Log(player, ("You are born as %s into a humble family. %s"):format(state.Name, PackTheme.Term("BirthLine")), "realm")
	end
	return state
end

-- Checks a loaded save against this engine version and pack. Returns data that is
-- safe to apply, or nil. Never lets an incompatible save be silently overwritten:
-- newer saves make the session read-only; older/foreign saves are backed up first.
function PlayerState.PrepareSave(player: Player, state, data)
	local packId = GamePack.Manifest.Id
	if data.Pack ~= nil and data.Pack ~= packId then
		PlayerState.BackupSave(player, data, "pack_" .. tostring(data.Pack))
		return nil
	end
	local version = tonumber(data.Version) or 0
	if version > PlayerState.SaveVersion then
		state.ReadOnly = true
		warn(("[PlayerState] Save v%d is newer than engine save v%d; session will not be saved."):format(version, PlayerState.SaveVersion))
		return nil
	end
	while version < PlayerState.SaveVersion do
		local migrate = PlayerState.Migrations[version]
		local ok, migrated = false, nil
		if migrate then
			ok, migrated = pcall(migrate, table.clone(data))
		end
		if not ok or type(migrated) ~= "table" then
			PlayerState.BackupSave(player, data, "v" .. version)
			return nil
		end
		data = migrated
		version += 1
		data.Version = version
	end
	return data
end

function PlayerState.BackupSave(player: Player, data, suffix: string)
	warn(("[PlayerState] Incompatible save for %s backed up as '%s'."):format(tostring(player), suffix))
	if store and player.UserId then
		pcall(store.SetAsync, store, key(player) .. "_backup_" .. suffix, data)
	end
end

-- Writes the save if this server still owns the session lock. `release` also
-- drops the lock (leaving / shutdown). Returns true when written.
-- The saved form of a state (a shallow copy; runtime-only fields removed).
function PlayerState.Serialize(state)
	local data = table.clone(state)
	data.Passes = nil -- ownership is re-checked every session (MonetizationSystem)
	data.Qi = state.Qi:Serialize()
	data.Version = PlayerState.SaveVersion
	data.Pack = GamePack.Manifest.Id
	data.ReadOnly = nil
	return data
end

function PlayerState.Save(player: Player, release: boolean?)
	local state = states[player]
	if not state or not store or not player.UserId then
		return false
	end
	if state.ReadOnly then
		if release then
			PlayerState.ReleaseLock(player)
		end
		return false
	end
	local data = PlayerState.Serialize(state)
	-- Retry transient DataStore failures so a hiccup on leave doesn't lose progress.
	local err
	for attempt = 1, PlayerState.SaveAttempts do
		local ok
		local lost = false
		ok, err = pcall(store.UpdateAsync, store, key(player), function(current)
			local lock = type(current) == "table" and current._Lock
			if type(lock) == "table" and lock.Owner ~= PlayerState.SessionId then
				lost = true
				return nil -- another server took over this save: never overwrite it
			end
			data._Lock = if release then nil else { Owner = PlayerState.SessionId, Time = os.time() }
			return data
		end)
		if ok and lost then
			state.ReadOnly = true
			warn(("[PlayerState] Another server took the save of %s; this session stops saving."):format(tostring(player)))
			return false
		elseif ok then
			return true
		end
		if attempt < PlayerState.SaveAttempts then
			task.wait(attempt)
		end
	end
	warn("[PlayerState] Save failed after retries:", err)
	return false
end

function PlayerState.Remove(player: Player)
	states[player] = nil
end

return PlayerState
