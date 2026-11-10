--[[
	GameManager: secure entry point for every client request. The client only sends
	intentions; everything is validated here (alive, no pending event, rate limit,
	module active, argument checks). Gameplay remotes are registered by the systems
	themselves (SystemRegistry); this script owns only life events and state sync.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ServerScriptService:WaitForChild("Modules")
local PlayerState = require(Modules:WaitForChild("PlayerState"))
local Engine = require(Modules:WaitForChild("LifeEventsEngine"))
local SystemRegistry = require(Modules:WaitForChild("SystemRegistry"))
local MonetizationSystem = require(Modules:WaitForChild("MonetizationSystem"))
local TutorialSystem = require(Modules:WaitForChild("TutorialSystem"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GamePack = require(Shared:WaitForChild("GamePack"))
local ContentValidator = require(Shared:WaitForChild("ContentValidator"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Validate the game pack before accepting players; problems are reported, not fatal.
do
	local report = ContentValidator.Run()
	print(("[GamePack] %s v%s on engine %s: %d error(s), %d warning(s)"):format(
		GamePack.Manifest.Name, GamePack.Manifest.Version, GamePack.EngineVersion, #report.Errors, #report.Warnings))
	for _, message in report.Errors do
		warn("[ContentValidator] ERROR " .. message)
	end
	for _, message in report.Warnings do
		print("[ContentValidator] WARNING " .. message)
	end
end

local AUTOSAVE_INTERVAL = 120

local lastAction: { [Player]: { [string]: number } } = {}

local function throttle(player: Player, actionKey: string, cooldown: number): boolean
	local times = lastAction[player]
	if not times then
		times = {}
		lastAction[player] = times
	end
	local now = os.clock()
	if times[actionKey] and now - times[actionKey] < cooldown then
		return false
	end
	times[actionKey] = now
	return true
end

-- Shared wrapper: alive check, no pending event, rate limit, notify, titles, death, push.
local function act(player: Player, actionKey: string, cooldown: number, handler)
	local state = PlayerState.Get(player)
	if not state or state.Dead then
		return
	end
	if state.PendingEvent then
		PlayerState.Notify(player, "Resolve the current life event first.", "warn")
		return
	end
	if not throttle(player, actionKey, cooldown) then
		return
	end
	local ok, message, kind = handler(state, PlayerState.GetBuffs(state))
	if message then
		PlayerState.Notify(player, message, kind or (if ok then "good" else "bad"))
	end
	if ok then
		SystemRegistry.AfterChange(player, state)
	end
	if not PlayerState.CheckDeath(player) then
		PlayerState.Push(player)
	end
end

-- Gameplay remotes come from the system registry (each system's Hooks.Remotes).
-- A missing RemoteEvent is created, so a new module needs no manual setup.
for name, remote in SystemRegistry.Remotes() do
	local event = Remotes:FindFirstChild(name)
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = Remotes
	end
	event.OnServerEvent:Connect(function(player, ...)
		if not SystemRegistry.Active(remote.Module) or (remote.Validate and not remote.Validate(...)) then
			return
		end
		local args = table.pack(...)
		act(player, name, remote.Cooldown or 0.2, function(state, buffs)
			return remote.Handle(player, state, buffs, table.unpack(args, 1, args.n))
		end)
	end)
end

Remotes.EventChoice.OnServerEvent:Connect(function(player, eventId, optionIndex)
	if type(eventId) ~= "string" or type(optionIndex) ~= "number" or optionIndex % 1 ~= 0 then
		return
	end
	local state = PlayerState.Get(player)
	if not state or state.Dead or not throttle(player, "EventChoice", 0.25) then
		return
	end
	if Engine.Resolve(player, state, eventId, optionIndex) then
		SystemRegistry.AfterChange(player, state)
		if not PlayerState.CheckDeath(player) then
			Engine.PresentNext(player, state)
			PlayerState.Push(player)
		end
	end
end)

Remotes.GetState.OnServerInvoke = function(player)
	-- Each call may wait for the load and resends the pending prompt: rate-limit it.
	if not throttle(player, "GetState", 1) then
		return nil
	end
	local deadline = os.clock() + 10
	while not PlayerState.Get(player) and os.clock() < deadline do
		task.wait(0.1)
	end
	local state = PlayerState.Get(player)
	if not state then
		return nil
	end
	task.defer(function()
		if state.PendingEvent then
			Engine.SendPrompt(player, state)
		else
			Engine.PresentNext(player, state)
		end
	end)
	return PlayerState.Snapshot(state), state.Log
end

----------------------------------------------------------------------
-- Persistence
----------------------------------------------------------------------

MonetizationSystem.Start(Remotes)
TutorialSystem.Start(Remotes)

local function onPlayerAdded(player: Player)
	PlayerState.Load(player)
	MonetizationSystem.Refresh(player)
	PlayerState.Push(player, true)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	PlayerState.Save(player, true) -- final save releases the session lock
	PlayerState.Remove(player)
	lastAction[player] = nil
end)

-- Save everyone in parallel so shutdown stays inside Roblox's time budget.
game:BindToClose(function()
	local pending = 0
	for player in PlayerState.All() do
		pending += 1
		task.spawn(function()
			PlayerState.Save(player, true)
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end)

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for player in PlayerState.All() do
			task.spawn(PlayerState.Save, player)
		end
	end
end)
