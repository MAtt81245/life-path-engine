--[[
	JournalSystem: the Adventurer's Journal and the Legacy Tree's new effects
	(JournalConfig, SamsaraUpgradesConfig; core).

	Account-wide state.Journal (Snapshot.Journal): { LoginDay, Streak, Daily = { Day,
	Progress = { questId = n }, Claimed } }. Per life: journal counters in
	state.Counters (Requirements "Counters"), and ModuleData(state, "Goals") =
	{ Done = { goalId = true } }.
	JournalAction remote: ("Login") | ("Daily").
	Legacy Tree effects applied at birth: AllStatXp, LifespanBonus (buff source
	"Legacy Tree"), StartingMoney, TalentChance (a free common talent), Heirloom (an item).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
local GamePack = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GamePack"))
local Requirements = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Requirements"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local SkillSystem = require(script.Parent:WaitForChild("SkillSystem"))
local TrainingSystem = require(script.Parent:WaitForChild("TrainingSystem"))
local ChronicleSystem = require(script.Parent:WaitForChild("ChronicleSystem"))
local Rng = require(script.Parent:WaitForChild("Rng"))

local Journal = Content.Get("JournalConfig")
local Talents = Content.Get("TalentsConfig")

local JournalSystem = {}

JournalSystem.HeirloomItems = { "wooden_sword", "lucky_charm", "jade_pendant", "padded_robe" }

local function today(): number
	return math.floor(os.time() / 86400)
end

function JournalSystem.Data(state)
	state.Journal = state.Journal or { Streak = 0 }
	local journal = state.Journal
	if not journal.Daily or journal.Daily.Day ~= today() then
		journal.Daily = { Day = today(), Progress = {}, Claimed = false }
	end
	return journal
end

-- Today's quests (the same three for everyone).
function JournalSystem.Quests(day: number?)
	local random = Random.new((day or today()) * 31)
	local pool = table.clone(Journal.DailyPool)
	local quests = {}
	for _ = 1, math.min(Journal.DailyCount, #pool) do
		table.insert(quests, table.remove(pool, random:NextInteger(1, #pool)))
	end
	return quests
end

-- A journal counter moved: per-life counters, best bond level, daily quests.
function JournalSystem.Count(state, counter: string, n: number?)
	local key = Journal.CounterMap[counter] or counter
	n = n or 1
	state.Counters = state.Counters or {}
	if key == "BondLevels" then
		state.Counters.BondLevels = math.max(state.Counters.BondLevels or 0, n)
	else
		state.Counters[key] = (state.Counters[key] or 0) + n
	end
	local daily = JournalSystem.Data(state).Daily
	for _, quest in JournalSystem.Quests() do
		if quest.Counter == key then
			daily.Progress[quest.Id] = math.min(quest.Need, (daily.Progress[quest.Id] or 0) + n)
		end
	end
end

function JournalSystem.ClaimLogin(player, state)
	local journal = JournalSystem.Data(state)
	if journal.LoginDay == today() then
		return false, "Today's login reward is already claimed.", "warn"
	end
	journal.Streak = if journal.LoginDay == today() - 1 then (journal.Streak % #Journal.LoginRewards) + 1 else 1
	journal.LoginDay = today()
	local reward = Journal.LoginRewards[journal.Streak]
	local parts = {}
	if reward.Money then state.Money += reward.Money; table.insert(parts, PlayerState.FormatMoney(reward.Money)) end
	if reward.Karma then state.Karma += reward.Karma; table.insert(parts, PlayerState.Words("%d {MetaCurrency}"):format(reward.Karma)) end
	if reward.Item and GamePack.IsActive("Inventory") and PlayerState.AddItem(state, reward.Item, 1) > 0 then
		table.insert(parts, Content.Get("ItemsConfig").ById[reward.Item].Name)
	end
	if reward.Ticket and GamePack.IsActive("Raids") then
		local raids = require(script.Parent:WaitForChild("RaidSystem")).Data(state)
		raids.Tickets += reward.Ticket
		table.insert(parts, "a raid ticket")
	end
	return true, ("Day %d login reward: %s"):format(journal.Streak, table.concat(parts, ", ")), "good"
end

function JournalSystem.ClaimDaily(player, state)
	local daily = JournalSystem.Data(state).Daily
	if daily.Claimed then
		return false, "Today's quest reward is already claimed.", "warn"
	end
	for _, quest in JournalSystem.Quests() do
		if (daily.Progress[quest.Id] or 0) < quest.Need then
			return false, "Finish all three daily quests first.", "warn"
		end
	end
	daily.Claimed = true
	state.Karma += Journal.DailyReward
	return true, PlayerState.Words("All daily quests done: +%d {MetaCurrency}."):format(Journal.DailyReward), "good"
end

-- Life goals reached since the last check (logged once each).
function JournalSystem.CheckGoals(player, state)
	local goals = PlayerState.ModuleData(state, "Goals", {})
	goals.Done = goals.Done or {}
	local view = nil
	for _, entry in Journal.LifeGoals do
		if not goals.Done[entry.Id] then
			view = view or PlayerState.Snapshot(state)
			local ok, met = pcall(Requirements.Check, view, entry.Requires)
			if ok and met then
				goals.Done[entry.Id] = true
				PlayerState.Log(player, "Life goal: " .. entry.Text, "good")
			end
		end
	end
end

-- Legacy Tree effects at birth.
function JournalSystem.ApplyLegacyTree(state)
	local buffs = {}
	local wisdom = PlayerState.UpgradeEffect(state, "AllStatXp")
	if wisdom > 0 then buffs.AllStatXp = 1 + wisdom end
	local life = PlayerState.UpgradeEffect(state, "LifespanBonus")
	if life > 0 then buffs.LifespanBonus = life end
	PlayerState.SetLifeBuff(state, "LegacyTree", "Legacy Tree", buffs)
	state.Money += PlayerState.UpgradeEffect(state, "StartingMoney")
	local chance = PlayerState.UpgradeEffect(state, "TalentChance")
	if chance > 0 and #state.Talents < PlayerState.MaxTalents and Rng:NextNumber() < chance then
		local pool = {}
		for _, talent in Talents.List do
			if talent.Rarity == (Talents.RarityOrder[1]) and not table.find(state.Talents, talent.Id) then table.insert(pool, talent) end
		end
		if #pool > 0 then
			local pick = pool[Rng:NextInteger(1, #pool)]
			table.insert(state.Talents, pick.Id)
			PlayerState.CodexAdd(state, "Talents", pick.Id)
		end
	end
	if PlayerState.UpgradeEffect(state, "Heirloom") > 0 and GamePack.IsActive("Inventory") then
		PlayerState.AddItem(state, JournalSystem.HeirloomItems[Rng:NextInteger(1, #JournalSystem.HeirloomItems)], 1)
	end
end

table.insert(PlayerState.NewLifeHooks, function(state)
	JournalSystem.ApplyLegacyTree(state)
	PlayerState.ModuleData(state, "Goals", { Done = {} })
end)

table.insert(SkillSystem.CounterHooks, function(_, state, counter, n)
	if Journal.CounterMap[counter] then
		JournalSystem.Count(state, counter, if counter == "motes_caught" then 1 else n)
	end
end)
table.insert(TrainingSystem.ActionHooks, function(_, state)
	JournalSystem.Count(state, "train", 1)
	return nil
end)
table.insert(ChronicleSystem.OmenHooks, function(_, state)
	JournalSystem.Count(state, "omens", 1)
end)
if script.Parent:FindFirstChild("RelationshipSystem") then
	table.insert(require(script.Parent.RelationshipSystem).InteractHooks, function(_, state)
		JournalSystem.Count(state, "social", 1)
		return nil
	end)
end

JournalSystem.Hooks = {
	YearTicks = {
		{ Phase = "Systems", Order = 99, Run = function(_, state) JournalSystem.Count(state, "years", 1) end },
	},
	AfterChange = {
		{ Run = function(player, state) JournalSystem.CheckGoals(player, state) end },
	},
	Remotes = {
		JournalAction = {
			Cooldown = 0.5,
			Validate = function(action)
				return action == "Login" or action == "Daily"
			end,
			Handle = function(player, state, _, action)
				if action == "Login" then
					return JournalSystem.ClaimLogin(player, state)
				end
				return JournalSystem.ClaimDaily(player, state)
			end,
		},
	},
}

return JournalSystem
