--[[
	PathSystem: YOUR PATH, the constellation of a life's decisions.

	Every resolved life event becomes a node in state.PathLog.Nodes (per life, saved, last
	MaxNodes; not part of the state snapshot, the client asks for it through PathQuery):
	what happened, your choice, the roads not taken, the consequences and how the world
	remembers it. Choices are counted in ChoiceStats.

	Return to This Path (developer product PathRewind): just before each decision the
	life is copied (runtime only, the last MaxCheckpoints decisions of this session).
	A rewind restores that copy (per-life fields; Karma, receipts, lineage, codex and
	other account data stay as they are), trims the chronicle and asks the question again.

	PathQuery remote function: ("List") -> { Nodes, Lives, BirthYear } |
	(nodeId) -> { Counts, MinSample, Rewindable }. GameManager calls PathSystem.Start().
	PathAction remote ("SelectRewind", nodeId): the node the next PathRewind purchase
	rewinds to.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local Engine = require(script.Parent:WaitForChild("LifeEventsEngine"))
local ChronicleSystem = require(script.Parent:WaitForChild("ChronicleSystem"))
local ChoiceStats = require(script.Parent:WaitForChild("ChoiceStats"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PathSystem = {}

PathSystem.MaxNodes = 60
PathSystem.MaxCheckpoints = 6
PathSystem.TextLimit = 260

-- Never rolled back by a rewind: account data and things paid for.
PathSystem.AccountKeys = {
	Karma = true, Lives = true, Lineage = true, Codex = true, Wheel = true, Upgrades = true, Heirlooms = true,
	Receipts = true, Passes = true, OmenDay = true, WorldYear = true, TutorialStep = true, TutorialCompleted = true,
	AutoAge = true, Creation = true, Ascensions = true, Log = true, Badges = true,
	Grimoire = true, FusionDiscovered = true, -- 2.0: the Family Grimoire and fusion recipes
	World = true, FamilyClass = true, Raids = true, Journal = true, -- 3.0: World Chronicle, family class, raids, journal
	Cosmetics = true, Purchases = true, CodesUsed = true, Slots = true, -- 3.0: the Trove and save slots
}

local checkpoints = setmetatable({}, { __mode = "k" }) -- [player] = { { NodeId, Copy, LogLength } }
local rewindTarget = setmetatable({}, { __mode = "k" }) -- [player] = nodeId

local function trim(text: string?): string
	text = text or ""
	if #text > PathSystem.TextLimit then
		return string.sub(text, 1, PathSystem.TextLimit - 1) .. "…"
	end
	return text
end

local function pathData(state)
	state.PathLog = state.PathLog or { Nodes = {}, NextNode = 1 }
	return state.PathLog
end
PathSystem.Data = pathData

-- How the world remembers a decision (one line for the node card).
function PathSystem.Remembered(state, info): string
	local firstName = string.match(state.Name or "", "^(%S+)") or "You"
	local year = ChronicleSystem.WorldYear(state)
	local verdict = if info.Success then "It is still told as a small triumph." else "It is still whispered as a warning."
	return ('In the year %d, %s chose "%s". %s'):format(year, firstName, info.Choice or "?", verdict)
end

function PathSystem.Checkpoint(player, state)
	local list = checkpoints[player] or {}
	checkpoints[player] = list
	local copy = {}
	for key, value in state do
		if not PathSystem.AccountKeys[key] then
			copy[key] = if type(value) == "table" then Content.DeepCopy(value) else value
		end
	end
	table.insert(list, { NodeId = pathData(state).NextNode, Copy = copy, LogLength = #(state.Log or {}) })
	while #list > PathSystem.MaxCheckpoints do
		table.remove(list, 1)
	end
end

function PathSystem.Record(player, state, info)
	local data = pathData(state)
	local options = {}
	for i, text in info.Options do
		options[i] = trim(text)
	end
	table.insert(data.Nodes, {
		Id = data.NextNode, Age = state.Age, Year = ChronicleSystem.WorldYear(state), EventId = info.Entry.Id,
		Title = info.Title, Text = trim(info.Text), Choice = trim(info.Choice), ChoiceIndex = info.OptionIndex, Options = options,
		Result = trim(info.Result), Summary = trim(info.Summary), Success = info.Success, Remembered = PathSystem.Remembered(state, info),
	})
	data.NextNode += 1
	while #data.Nodes > PathSystem.MaxNodes do
		table.remove(data.Nodes, 1)
	end
	ChoiceStats.Record(info.Entry.Id, info.OptionIndex)
end

local function findCheckpoint(player, nodeId)
	for i, checkpoint in checkpoints[player] or {} do
		if checkpoint.NodeId == nodeId then
			return checkpoint, i
		end
	end
	return nil
end

function PathSystem.CanRewind(player, state, nodeId): (boolean, string?)
	if not state or state.Dead then
		return false, "Only a living path can be walked again."
	end
	if type(nodeId) ~= "number" or not findCheckpoint(player, nodeId) then
		return false, "That moment has faded: only your latest decisions of this session can be revisited."
	end
	return true
end

-- Restores the life as it was just before node `nodeId` and asks that question again.
function PathSystem.Rewind(player, state, nodeId): (boolean, string?)
	local ok, reason = PathSystem.CanRewind(player, state, nodeId)
	if not ok then
		return false, reason
	end
	local checkpoint, index = findCheckpoint(player, nodeId)
	for key in state do
		if not PathSystem.AccountKeys[key] and checkpoint.Copy[key] == nil then
			state[key] = nil -- appeared after the checkpoint
		end
	end
	for key, value in checkpoint.Copy do
		state[key] = if type(value) == "table" then Content.DeepCopy(value) else value
	end
	local log = state.Log or {}
	for i = #log, checkpoint.LogLength + 1, -1 do
		table.remove(log, i)
	end
	-- Later checkpoints belong to a future that no longer exists.
	local list = checkpoints[player]
	for i = #list, index, -1 do
		table.remove(list, i)
	end
	rewindTarget[player] = nil
	PlayerState.Log(player, "« You returned to this path. The road forks once more.", "realm")
	if typeof(player) == "Instance" then
		Engine.SendPrompt(player, state)
	end
	return true, "You returned to this path. Choose again."
end

function PathSystem.SelectRewind(player, nodeId): boolean
	if type(nodeId) ~= "number" then
		return false
	end
	rewindTarget[player] = nodeId
	return true
end

function PathSystem.Target(player): number?
	return rewindTarget[player]
end

function PathSystem.Query(player, state, nodeId)
	if nodeId == "List" then
		return { Nodes = pathData(state).Nodes, Lives = state.Lives, BirthYear = ChronicleSystem.Data(state).BirthYear, Name = state.Name }
	end
	local node = nil
	for _, entry in pathData(state).Nodes do
		if entry.Id == nodeId then
			node = entry
		end
	end
	if not node then
		return nil
	end
	return {
		Counts = ChoiceStats.Get(node.EventId),
		MinSample = ChoiceStats.MinSample,
		Rewindable = (PathSystem.CanRewind(player, state, nodeId)),
	}
end

table.insert(Engine.BeforeResolve, function(player, state)
	PathSystem.Checkpoint(player, state)
end)
table.insert(Engine.AfterResolve, function(player, state, info)
	PathSystem.Record(player, state, info)
end)

-- A new life starts with an empty path and no way back into the last one.
table.insert(PlayerState.NewLifeHooks, function(state)
	state.PathLog = { Nodes = {}, NextNode = 1 }
	for player, list in checkpoints do
		if PlayerState.Get(player) == state then
			table.clear(list)
		end
	end
end)

local started = false
function PathSystem.Start()
	if started then
		return
	end
	started = true
	ChoiceStats.Start()
	local query = Remotes:FindFirstChild("PathQuery")
	if not query then
		query = Instance.new("RemoteFunction")
		query.Name = "PathQuery"
		query.Parent = Remotes
	end
	local last = setmetatable({}, { __mode = "k" })
	query.OnServerInvoke = function(player, nodeId)
		if type(nodeId) ~= "number" and nodeId ~= "List" then
			return nil
		end
		-- Rate limit per kind: opening the map asks for the list and a node at once.
		local now, kind = os.clock(), if nodeId == "List" then "List" else "Node"
		last[player] = last[player] or {}
		if last[player][kind] and now - last[player][kind] < 0.15 then
			return nil
		end
		last[player][kind] = now
		local state = PlayerState.Get(player)
		return state and PathSystem.Query(player, state, nodeId)
	end
	Players.PlayerRemoving:Connect(function(player)
		checkpoints[player], rewindTarget[player] = nil, nil
	end)
end

PathSystem.Hooks = {
	Remotes = {
		PathAction = {
			Cooldown = 0.2,
			Validate = function(action, nodeId)
				return action == "SelectRewind" and type(nodeId) == "number"
			end,
			Handle = function(player, _, _, _, nodeId)
				return PathSystem.SelectRewind(player, nodeId), nil
			end,
		},
	},
}

return PathSystem
