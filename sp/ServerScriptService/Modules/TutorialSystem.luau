--[[
	TutorialSystem: the Life 1 onboarding guide (client UIController/TutorialGuide).

	The client shows each spotlight step when its moment comes (creation wheel, first
	turn, out of actions, Spirit Root awakening) and reports it here; the server only
	stores progress. state.TutorialStep = furthest step seen, state.TutorialCompleted
	once the last step is acknowledged or the guide is skipped. Both are saved, so the
	guide never shows again. Life 2+ always counts as completed (veterans).

	TutorialAction remote: ("Step", n) | ("Skip").
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GamePack = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GamePack"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))

local TutorialSystem = {}

-- Step ids in order (the client owns the texts and conditions).
TutorialSystem.Steps = { "Creation", "Actions", "Advance", "SpiritRoot" }

-- The last step this pack shows (no Spirit Root without cultivation).
function TutorialSystem.LastStep(): number
	return if GamePack.IsEnabled("Cultivation") then 4 else 3
end

function TutorialSystem.Complete(state)
	state.TutorialCompleted = true
	state.TutorialStep = math.max(state.TutorialStep or 0, TutorialSystem.LastStep())
end

-- Records step n as seen. Returns true if progress changed.
function TutorialSystem.Ack(state, step: number): boolean
	if state.TutorialCompleted or type(step) ~= "number" or step % 1 ~= 0 or step < 1 or step > #TutorialSystem.Steps then
		return false
	end
	if step <= (state.TutorialStep or 0) then
		return false
	end
	state.TutorialStep = step
	if step >= TutorialSystem.LastStep() then
		TutorialSystem.Complete(state)
	end
	return true
end

function TutorialSystem.Skip(state): boolean
	if state.TutorialCompleted then
		return false
	end
	TutorialSystem.Complete(state)
	return true
end

-- Veterans: any life after the first finishes the guide.
table.insert(PlayerState.NewLifeHooks, function(state)
	if (state.Lives or 0) > 1 then
		state.TutorialCompleted = true
	end
end)

local started = false
function TutorialSystem.Start(remotes: Instance)
	if started then
		return
	end
	started = true
	local remote = remotes:FindFirstChild("TutorialAction")
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "TutorialAction"
		remote.Parent = remotes
	end
	local last = setmetatable({}, { __mode = "k" })
	remote.OnServerEvent:Connect(function(player, action, step)
		local state = PlayerState.Get(player)
		local now = os.clock()
		if not state or (last[player] and now - last[player] < 0.2) then
			return
		end
		last[player] = now
		local changed = if action == "Skip" then TutorialSystem.Skip(state)
			elseif action == "Step" then TutorialSystem.Ack(state, step)
			else false
		if changed then
			PlayerState.Push(player)
		end
	end)
end

return TutorialSystem
