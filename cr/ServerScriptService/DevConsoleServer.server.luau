--[[
	DevConsoleServer: exposes Modules/DevConsole to the Studio client through the
	DevCommand RemoteFunction. Outside Studio (or with the ServerScriptService
	attribute DevConsole = false) it returns at once and the remote never exists.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DevConsole = require(script.Parent:WaitForChild("Modules"):WaitForChild("DevConsole"))

if not DevConsole.Enabled() then
	return
end

local COOLDOWN = 0.1
local lastCall: { [Player]: number } = {}

local remote = Instance.new("RemoteFunction")
remote.Name = "DevCommand"
remote.OnServerInvoke = function(player, line)
	local now = os.clock()
	if lastCall[player] and now - lastCall[player] < COOLDOWN then
		return { "Slow down." }
	end
	lastCall[player] = now
	return DevConsole.Execute(player, line)
end
remote.Parent = ReplicatedStorage:WaitForChild("Remotes")

-- Server-side bridge for Studio tooling (MCP scripts, automated UI checks): runs a
-- command as the first player. Lives in ServerScriptService, never replicated.
local bridge = Instance.new("BindableFunction")
bridge.Name = "DevConsoleBridge"
bridge.OnInvoke = function(line)
	local player = Players:GetPlayers()[1]
	return if player then DevConsole.Execute(player, line) else { "No player." }
end
bridge.Parent = script

Players.PlayerRemoving:Connect(function(player)
	lastCall[player] = nil
end)

print("[DevConsole] Enabled (Studio only). Press F2 in a playtest; type help.")
