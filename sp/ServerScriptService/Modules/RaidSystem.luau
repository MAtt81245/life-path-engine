--[[
	RaidSystem: raids with parties of players in this server (RaidConfig; Raids module,
	requires Skills). Parties live in memory (they end with the server); tickets and
	tokens are account-wide and saved (state.Raids = { Tickets, Tokens, TicketDay, Cleared }).
	RaidAction remote: ("Create", difficultyId) | ("Join", partyId) | ("QuickJoin",
	difficultyId) | ("Leave") | ("Start") | ("Buy", shopIndex).
	RaidQuery remote function -> { Level, Tickets, Tokens, Party, Lobby }.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
local GamePack = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GamePack"))
local CombatMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatMath"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local SkillSystem = require(script.Parent:WaitForChild("SkillSystem"))
local Rng = require(script.Parent:WaitForChild("Rng"))

local Raid = Content.Get("RaidConfig")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local RaidSystem = {}

local parties = {} -- [id] = { Id, Leader, Members = { player }, Difficulty }
local partyOf = setmetatable({}, { __mode = "k" }) -- [player] = party
local nextId = 0

local function difficulty(id)
	for _, entry in Raid.Difficulties do
		if entry.Id == id then return entry end
	end
	return nil
end
RaidSystem.Difficulty = difficulty

local function today(): number
	return math.floor(os.time() / 86400)
end

-- Account-wide tickets and tokens; a new real day tops tickets up.
function RaidSystem.Data(state)
	state.Raids = state.Raids or { Tickets = Raid.StartTickets, Tokens = 0, TicketDay = today(), Cleared = {} }
	local data = state.Raids
	data.Cleared = data.Cleared or {}
	local days = today() - (data.TicketDay or today())
	if days > 0 then
		data.Tickets = math.min(Raid.MaxTickets, data.Tickets + days * Raid.TicketsPerDay)
		data.TicketDay = today()
	end
	return data
end

function RaidSystem.Power(state): number
	local affinity = 0
	for _, value in (state.Modules and state.Modules.Arcana and state.Modules.Arcana.Affinity) or {} do
		affinity = math.max(affinity, value)
	end
	return CombatMath.Power(PlayerState.StatLevels(state), SkillSystem.Levels(state), affinity)
end

function RaidSystem.Level(state): number
	return CombatMath.Level(RaidSystem.Power(state))
end

local function eligible(player, entry): (boolean, string?)
	local state = PlayerState.Get(player)
	if not state or state.Dead then
		return false, "the dead cannot raid"
	elseif state.Age < Raid.MinAge then
		return false, ("raids open at age %d"):format(Raid.MinAge)
	elseif RaidSystem.Level(state) < entry.MinLevel then
		return false, ("needs adventurer level %d"):format(entry.MinLevel)
	elseif RaidSystem.Data(state).Tickets < 1 then
		return false, "no raid tickets left"
	end
	return true
end

function RaidSystem.Leave(player)
	local party = partyOf[player]
	if not party then return false end
	partyOf[player] = nil
	local at = table.find(party.Members, player)
	if at then table.remove(party.Members, at) end
	if #party.Members == 0 then
		parties[party.Id] = nil
	elseif party.Leader == player then
		party.Leader = party.Members[1]
	end
	return true, "You left the party.", "info"
end

function RaidSystem.Create(player, difficultyId)
	local entry = difficulty(difficultyId)
	if not entry then return false end
	local ok, reason = eligible(player, entry)
	if not ok then return false, "Cannot raid: " .. reason, "warn" end
	RaidSystem.Leave(player)
	nextId += 1
	local party = { Id = nextId, Leader = player, Members = { player }, Difficulty = entry.Id }
	parties[party.Id] = party
	partyOf[player] = party
	return true, ("Party opened: %s raid. Waiting for adventurers."):format(entry.Name), "good"
end

function RaidSystem.Join(player, partyId)
	local party = parties[tonumber(partyId) or -1]
	if not party then return false, "That party is gone.", "warn" end
	if #party.Members >= Raid.MaxParty then return false, "That party is full.", "warn" end
	local ok, reason = eligible(player, difficulty(party.Difficulty))
	if not ok then return false, "Cannot join: " .. reason, "warn" end
	RaidSystem.Leave(player)
	table.insert(party.Members, player)
	partyOf[player] = party
	return true, "You joined the party.", "good"
end

function RaidSystem.QuickJoin(player, difficultyId)
	for _, party in parties do
		if party.Difficulty == difficultyId and #party.Members < Raid.MaxParty and party ~= partyOf[player] then
			return RaidSystem.Join(player, party.Id)
		end
	end
	return RaidSystem.Create(player, difficultyId)
end

-- The leader starts the raid for the whole party.
function RaidSystem.Start(player)
	local party = partyOf[player]
	if not party then return false, "Create or join a party first.", "warn" end
	if party.Leader ~= player then return false, "Only the party leader can start.", "warn" end
	local entry = difficulty(party.Difficulty)
	for _, member in party.Members do
		local ok, reason = eligible(member, entry)
		if not ok then
			return false, ("%s: %s"):format(tostring(member.Name), reason), "warn"
		end
	end
	local total = 0
	for _, member in party.Members do
		local state = PlayerState.Get(member)
		RaidSystem.Data(state).Tickets -= 1
		total += RaidSystem.Power(state)
	end
	local power = total * (1 + Raid.PartyBonus * (#party.Members - 1))
	local chance = math.clamp(0.5 + (power / entry.BossPower - 1) * 1.2, 0.05, 0.95)
	local won = Rng:NextNumber() < chance
	local names = {}
	for _, member in party.Members do table.insert(names, tostring(member.Name)) end
	for _, member in party.Members do
		local state = PlayerState.Get(member)
		local data = RaidSystem.Data(state)
		if won then
			data.Tokens += entry.Rewards.Tokens
			local parts = SkillSystem.ApplyEffects(member, state, { Money = entry.Rewards.Money, SkillXp = { Swordsmanship = 10, Magic = 10 } })
			PlayerState.Log(member, ("Raid cleared: %s (%s)! +%d Raid Tokens, %s"):format(entry.Boss, entry.Name, entry.Rewards.Tokens, table.concat(parts, ", ")), "good")
			if entry.Conquer and not data.Cleared[entry.Id] then
				require(script.Parent:WaitForChild("HistorySystem")).Record(state,
					("%s's party (%s) conquers %s."):format(state.Name, table.concat(names, ", "), entry.Boss), "deed")
			end
			data.Cleared[entry.Id] = true
			SkillSystem.Count(member, state, "raids", 1)
			if GamePack.IsActive("Legends") then
				require(script.Parent:WaitForChild("LegendsSystem")).FindLead(member, state, "Raid")
			end
		else
			local maxHealth = PlayerState.GetMaxHealth(state)
			state.Health = math.max(math.floor(maxHealth * 0.3), state.Health - math.floor(maxHealth * Raid.Failure.HealthShare))
			PlayerState.AdjustMeter(state, "Stress", Raid.Failure.Stress)
			PlayerState.Log(member, ("The raid on %s failed. The party retreats, bloodied."):format(entry.Boss), "bad")
		end
		if member ~= player and typeof(member) == "Instance" then
			PlayerState.Push(member)
		end
	end
	for _, member in table.clone(party.Members) do
		partyOf[member] = nil
	end
	parties[party.Id] = nil
	return true, if won then ("VICTORY over %s!"):format(entry.Boss) else ("Defeat... (%d%% odds)"):format(math.floor(chance * 100)), if won then "good" else "bad"
end

function RaidSystem.Buy(player, state, index)
	local offer = Raid.Shop[math.floor(tonumber(index) or 0)]
	local data = RaidSystem.Data(state)
	if not offer then return false end
	if data.Tokens < offer.Cost then return false, "Not enough Raid Tokens.", "warn" end
	if offer.Item and PlayerState.AddItem(state, offer.Item, 1) <= 0 then return false, "Your bag is full.", "warn" end
	data.Tokens -= offer.Cost
	if offer.Ticket then data.Tickets += offer.Ticket end
	if offer.Karma then state.Karma += offer.Karma end
	return true, ("Raid Shop: %s"):format(offer.Name), "good"
end

function RaidSystem.Query(player)
	local state = PlayerState.Get(player)
	if not state then return nil end
	local data = RaidSystem.Data(state)
	local function view(party)
		local members = {}
		for _, member in party.Members do
			local memberState = PlayerState.Get(member)
			table.insert(members, { Name = tostring(member.Name), Level = memberState and RaidSystem.Level(memberState) or 0, Leader = member == party.Leader })
		end
		return { Id = party.Id, Difficulty = party.Difficulty, Members = members }
	end
	local lobby = {}
	for _, party in parties do
		if party ~= partyOf[player] and #party.Members < Raid.MaxParty then
			table.insert(lobby, view(party))
		end
	end
	local mine = partyOf[player]
	return { Level = RaidSystem.Level(state), Power = RaidSystem.Power(state), Tickets = data.Tickets, Tokens = data.Tokens,
		Party = mine and view(mine), Leader = mine and mine.Leader == player, Lobby = lobby }
end

local started = false
function RaidSystem.Start_()
	if started then return end
	started = true
	local query = Remotes:FindFirstChild("RaidQuery") or Instance.new("RemoteFunction")
	query.Name = "RaidQuery"
	query.Parent = Remotes
	query.OnServerInvoke = function(player)
		return RaidSystem.Query(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		RaidSystem.Leave(player)
	end)
end

RaidSystem.Hooks = {
	Remotes = {
		RaidAction = {
			Module = "Raids",
			Cooldown = 0.4,
			Validate = function(action)
				return type(action) == "string"
			end,
			Handle = function(player, state, _, action, arg)
				if action == "Create" then return RaidSystem.Create(player, arg)
				elseif action == "Join" then return RaidSystem.Join(player, arg)
				elseif action == "QuickJoin" then return RaidSystem.QuickJoin(player, arg)
				elseif action == "Leave" then return RaidSystem.Leave(player)
				elseif action == "Start" then return RaidSystem.Start(player)
				elseif action == "Buy" then return RaidSystem.Buy(player, state, arg)
				end
				return false
			end,
		},
	},
}

return RaidSystem
