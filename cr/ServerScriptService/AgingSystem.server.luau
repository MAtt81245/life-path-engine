--[[
	AgingSystem: advances characters one year at a time.
	- "Advance Year" button (AdvanceYear remote) ages the character immediately.
	- Auto-age (SetAutoAge remote) lets the task.wait loop age them every
	  `SecondsPerYear` seconds (attribute on this script).
	The yearly simulation itself lives in Modules/YearSystem.
	At Age >= MaxLifespan the character dies and the Wheel of Reincarnation
	(Modules/WheelSystem) lets the player spin a bloodline and talents with Karma.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ServerScriptService:WaitForChild("Modules")
local PlayerState = require(Modules:WaitForChild("PlayerState"))
local YearSystem = require(Modules:WaitForChild("YearSystem"))
local WheelSystem = require(Modules:WaitForChild("WheelSystem"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local DEFAULT_SECONDS_PER_YEAR = 4

if script:GetAttribute("SecondsPerYear") == nil then
	script:SetAttribute("SecondsPerYear", DEFAULT_SECONDS_PER_YEAR)
end

local lastAdvance: { [Player]: number } = {}
local lastRequest: { [Player]: { [string]: number } } = {}

local function throttle(player: Player, key: string, cooldown: number): boolean
	local times = lastRequest[player]
	if not times then
		times = {}
		lastRequest[player] = times
	end
	local now = os.clock()
	if times[key] and now - times[key] < cooldown then
		return false
	end
	times[key] = now
	return true
end

Remotes.AdvanceYear.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if lastAdvance[player] and now - lastAdvance[player] < 0.35 then
		return
	end
	lastAdvance[player] = now
	local ok, reason = YearSystem.Advance(player)
	if not ok and reason then
		PlayerState.Notify(player, reason, "warn")
	end
end)

Remotes.SetAutoAge.OnServerEvent:Connect(function(player, enabled)
	local state = PlayerState.Get(player)
	if state and type(enabled) == "boolean" and throttle(player, "AutoAge", 0.5) then
		state.AutoAge = enabled
		PlayerState.Push(player)
	end
end)

local SPIN_REVEAL = 3.3 -- seconds: WheelSpinner.Duration plus a beat

-- Wheel of Reincarnation (WheelSystem): SpinBloodline, SpinTalent (slot), Lock, Unlock,
-- BuyUpgrade (id), ChoosePath (id), Confirm.
Remotes.Reincarnate.OnServerEvent:Connect(function(player, action, arg, arg2)
	if type(action) ~= "string" or not throttle(player, "Reincarnate", 0.25) then
		return
	end
	local state = PlayerState.Get(player)
	if not state or not state.Dead then
		return
	end
	local ok, message, kind = WheelSystem.Handle(player, state, action, arg, if type(arg2) == "string" then arg2 else nil)
	if ok then
		PlayerState.ClearRevival(state) -- acting on the Wheel accepts Heaven's verdict
	end
	if message then
		-- A spin result waits until the client drum (Shared/WheelSpinner) has landed.
		local delay = if ok and string.sub(action, 1, 4) == "Spin" then SPIN_REVEAL / PlayerState.GetSpinSpeed(state) else 0
		task.delay(delay, PlayerState.Notify, player, message, kind or (if ok then "good" else "bad"))
	end
	if state.Dead then
		PlayerState.Push(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastAdvance[player] = nil
	lastRequest[player] = nil
end)

-- Auto-age loop: each player ages on their own clock (Celestial Timekeeper is faster).
local lastAuto: { [Player]: number } = {}
Players.PlayerRemoving:Connect(function(player)
	lastAuto[player] = nil
end)
while true do
	task.wait(0.25)
	local secondsPerYear = math.max(0.5, tonumber(script:GetAttribute("SecondsPerYear")) or DEFAULT_SECONDS_PER_YEAR)
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local state = PlayerState.Get(player)
		if state and state.AutoAge and not state.Dead and not state.PendingEvent and #state.EventQueue == 0 then
			local interval = math.max(0.5, PlayerState.GetAutoAgeSeconds(state, secondsPerYear))
			if now - (lastAuto[player] or 0) >= interval then
				lastAuto[player] = now
				local ok, err = pcall(YearSystem.Advance, player)
				if not ok then
					warn("[AgingSystem]", err)
				end
			end
		else
			lastAuto[player] = now -- a fresh full interval once auto-age resumes
		end
	end
end
