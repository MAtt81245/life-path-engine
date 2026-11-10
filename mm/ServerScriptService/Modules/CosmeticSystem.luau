--[[
	CosmeticSystem: portrait frames, UI themes and backgrounds, codes, the ULTIMATE
	stat chooser and save slots (MonetizationConfig; core).

	Account-wide (saved): state.Cosmetics = { Frames = { id = true }, Frame, Theme,
	Backdrop }, state.CodesUsed = { CODE = true }, state.Slots = { Active, Saved = {
	[n] = copy } }. Snapshot: Cosmetics, CodesUsed, SlotCards.
	CosmeticAction remote: ("Frame", id) | ("Theme", id) | ("Backdrop", id) |
	("Code", text) | ("Slot", n) | ("ChooseStats", { Stat = level }).

	Save slots: switching stores this character's per-life fields in the slot it leaves
	and restores the other (or starts a new life there). Account data (Karma, Legacy
	Tree, Grimoire, World Chronicle...) is shared by every slot.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
local GamePack = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GamePack"))
local BigNum = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("BigNum"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local PathSystem = require(script.Parent:WaitForChild("PathSystem"))

local Monetization = Content.Get("MonetizationConfig")
local Races = Content.Get("RacesConfig")
local Stats = Content.Get("PlayerStatsConfig")

local CosmeticSystem = {}

-- Never copied into or out of a slot (runtime fields too).
CosmeticSystem.SlotSkip = { Passes = true, ReadOnly = true, SessionId = true }

function CosmeticSystem.Data(state)
	state.Cosmetics = state.Cosmetics or {}
	local data = state.Cosmetics
	data.Frames = data.Frames or {}
	data.Theme = data.Theme or "Moonlight"
	data.Backdrop = data.Backdrop or "Void"
	return data
end

local function guildMember(player): boolean
	if not GamePack.IsActive("WorldHub") then return false end
	return require(script.Parent:WaitForChild("WorldHubSystem")).InGroup(player)
end

function CosmeticSystem.OwnsFrame(player, state, id: string): boolean
	for _, frame in Monetization.Frames do
		if frame.Id == id then
			return (frame.Free == "Group" and guildMember(player)) or CosmeticSystem.Data(state).Frames[id] == true
		end
	end
	return false
end

function CosmeticSystem.OwnsTheme(state, id: string): boolean
	for _, theme in Monetization.Themes do
		if theme.Id == id then
			return theme.Pass == nil or PlayerState.OwnsPass(state, theme.Pass)
		end
	end
	return false
end

function CosmeticSystem.Redeem(player, state, text)
	local code = string.upper(string.gsub(tostring(text), "%s", ""))
	local reward = Monetization.Codes[code]
	state.CodesUsed = state.CodesUsed or {}
	if not reward then
		return false, "That code does not exist (or has expired).", "warn"
	elseif state.CodesUsed[code] then
		return false, "You already used that code.", "warn"
	end
	state.CodesUsed[code] = true
	local parts = {}
	if reward.Money then state.Money += reward.Money; table.insert(parts, PlayerState.FormatMoney(reward.Money)) end
	if reward.Karma then state.Karma += reward.Karma; table.insert(parts, PlayerState.Words("%d {MetaCurrency}"):format(reward.Karma)) end
	for itemId, count in reward.Items or {} do
		if GamePack.IsActive("Inventory") and PlayerState.AddItem(state, itemId, count) > 0 then
			table.insert(parts, Content.Get("ItemsConfig").ById[itemId].Name)
		end
	end
	return true, ("Code %s: %s"):format(code, table.concat(parts, ", ")), "good"
end

-- ULTIMATE pass: choose every starting attribute, once per life, at age 0.
function CosmeticSystem.ChooseStats(player, state, levels)
	local pass = Monetization.ById.Ultimate
	local birth = PlayerState.ModuleData(state, "Birth", {})
	if not pass or not PlayerState.OwnsPass(state, pass.Id) then
		return false, "Needs the ULTIMATE pass.", "warn"
	elseif state.Age ~= 0 or birth.StatsChosen then
		return false, "Starting attributes are chosen once, at birth.", "warn"
	elseif type(levels) ~= "table" then
		return false
	end
	local range = pass.ChooseStats
	for _, stat in Stats.Order do
		local value = tonumber(levels[stat])
		if value then
			local cap = state.StatCaps and state.StatCaps[stat] or math.huge -- anomalies still rule
			state.Stats[stat] = { Level = math.min(cap, math.clamp(math.floor(value), range.Min, range.Max)), Xp = 0 }
		end
	end
	birth.StatsChosen = true
	state.Health = PlayerState.GetMaxHealth(state)
	return true, "Your starting attributes are set.", "good"
end

----------------------------------------------------------------------
-- Save slots
----------------------------------------------------------------------

local function slotData(state)
	state.Slots = state.Slots or { Active = 1, Saved = {} }
	state.Slots.Saved = state.Slots.Saved or {}
	return state.Slots
end

local function slotOwned(state, n: number): boolean
	if n == 1 then return true end
	for _, pass in Monetization.Passes do
		if pass.Slot == n and PlayerState.OwnsPass(state, pass.Id) then return true end
	end
	return false
end

local function perLife(key): boolean
	return not PathSystem.AccountKeys[key] and not CosmeticSystem.SlotSkip[key]
end

-- This character's per-life fields as a saveable copy (BigNum Qi as text).
function CosmeticSystem.Capture(state)
	local copy = {}
	for key, value in state do
		if perLife(key) then
			copy[key] = if type(value) == "table" then Content.DeepCopy(value) else value
		end
	end
	copy.Qi = if state.Qi and state.Qi.ToString then state.Qi:ToString() else "0"
	copy.Log = {}
	return copy
end

function CosmeticSystem.Switch(player, state, n)
	n = math.floor(tonumber(n) or 0)
	local slots = slotData(state)
	if n < 1 or n > 3 then
		return false
	elseif n == slots.Active then
		return false, "You are already playing that character.", "warn"
	elseif not slotOwned(state, n) then
		return false, ("Save Slot %d is locked (Trove)."):format(n), "warn"
	elseif state.PendingEvent then
		return false, "Finish the current life event first.", "warn"
	end
	slots.Saved[slots.Active] = CosmeticSystem.Capture(state)
	local saved = slots.Saved[n]
	slots.Saved[n] = nil
	slots.Active = n
	if saved then
		for key in state do
			if perLife(key) and saved[key] == nil and key ~= "Log" then state[key] = nil end
		end
		for key, value in saved do
			state[key] = value
		end
		state.Qi = BigNum.from(saved.Qi or "0")
		state.Log = {}
		PlayerState.Log(player, ("You return to %s (slot %d)."):format(state.Name, n), "realm")
	else
		state.Dead = false
		PlayerState.StartNewLife(state, {}, Races.Default)
		PlayerState.Log(player, ("A new story begins in slot %d: %s."):format(n, state.Name), "realm")
	end
	PlayerState.Push(player, true)
	return true, ("Now playing slot %d."):format(n), "good"
end

-- The Characters carousel: one card per slot.
function PlayerState.SlotCards(state)
	local slots = state.Slots or { Active = 1, Saved = {} }
	local cards = {}
	for n = 1, 3 do
		local saved = (slots.Saved or {})[n]
		if n == (slots.Active or 1) then
			cards[n] = { Name = state.Name, Age = state.Age, Lives = state.Lives, Active = true, Dead = state.Dead, Owned = true }
		elseif saved then
			cards[n] = { Name = saved.Name, Age = saved.Age, Dead = saved.Dead, Owned = slotOwned(state, n) }
		else
			cards[n] = { Empty = true, Owned = slotOwned(state, n) }
		end
	end
	return cards
end

CosmeticSystem.Hooks = {
	Remotes = {
		CosmeticAction = {
			Cooldown = 0.4,
			Validate = function(action)
				return type(action) == "string"
			end,
			Handle = function(player, state, _, action, arg)
				local data = CosmeticSystem.Data(state)
				if action == "Frame" then
					if arg == "None" then data.Frame = nil; return true end
					if type(arg) ~= "string" or not CosmeticSystem.OwnsFrame(player, state, arg) then return false, "You don't own that frame.", "warn" end
					data.Frame = arg
					return true, "Frame equipped.", "good"
				elseif action == "Theme" then
					if type(arg) ~= "string" or not CosmeticSystem.OwnsTheme(state, arg) then return false, "That theme is locked (Trove).", "warn" end
					data.Theme = arg
					return true
				elseif action == "Backdrop" then
					if type(arg) ~= "string" or not table.find(Monetization.Backdrops, arg) then return false end
					data.Backdrop = arg
					return true
				elseif action == "Code" then
					return CosmeticSystem.Redeem(player, state, arg)
				elseif action == "Slot" then
					return CosmeticSystem.Switch(player, state, arg)
				elseif action == "ChooseStats" then
					return CosmeticSystem.ChooseStats(player, state, arg)
				end
				return false
			end,
		},
	},
}

return CosmeticSystem
