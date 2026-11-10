--[[
	ProgressionSystem: mastery tree purchases and title unlocking / equipping.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
local Masteries = Content.Get("MasteriesConfig")
local Titles = Content.Get("TitlesConfig")
local Requirements = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Requirements"))
local GamePack = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GamePack"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))

local ProgressionSystem = {}

function ProgressionSystem.UnlockMastery(player: Player, state, nodeId: string)
	local node = Masteries.NodesById[nodeId]
	if not node then
		return false
	end
	if state.Masteries[nodeId] then
		return false, "Already unlocked."
	end
	if node.Previous and not state.Masteries[node.Previous] then
		return false, "Unlock the previous mastery in this branch first."
	end
	if state.MasteryPoints < node.Cost then
		return false, ("Needs %d mastery points."):format(node.Cost)
	end
	state.MasteryPoints -= node.Cost
	state.Masteries[nodeId] = true
	PlayerState.Log(player, ("Mastery unlocked: %s."):format(node.Name), "good")
	return true, "Unlocked " .. node.Name .. "."
end

function ProgressionSystem.ToggleTitle(player: Player, state, titleId: string)
	local title = Titles.ById[titleId]
	if not title or not state.Titles.Unlocked[titleId] then
		return false
	end
	local index = table.find(state.Titles.Equipped, titleId)
	if index then
		table.remove(state.Titles.Equipped, index)
		return true, "Unequipped " .. title.Name .. ".", "info"
	end
	if #state.Titles.Equipped >= Titles.MaxEquipped then
		return false, ("You can equip %d titles. Unequip one first."):format(Titles.MaxEquipped)
	end
	table.insert(state.Titles.Equipped, titleId)
	return true, "Equipped " .. title.Name .. "."
end

function ProgressionSystem.CheckTitles(player: Player, state)
	if not GamePack.IsEnabled("Titles") then
		return
	end
	for _, title in Titles.List do
		if not state.Titles.Unlocked[title.Id] and Requirements.Check(state, title.Requires) then
			state.Titles.Unlocked[title.Id] = true
			PlayerState.CodexAdd(state, "Titles", title.Id)
			local equipped = #state.Titles.Equipped < Titles.MaxEquipped
			if equipped then
				table.insert(state.Titles.Equipped, title.Id)
			end
			PlayerState.Log(player, ("Title unlocked: %s%s"):format(title.Name, if equipped then " (equipped)" else ""), "event")
			PlayerState.Notify(player, "New title: " .. title.Name, "event")
		end
	end
end

-- Registry hooks (see SystemRegistry).
ProgressionSystem.Hooks = {
	Remotes = {
		ProgressionAction = {
			Module = { "Masteries", "Titles" },
			Cooldown = 0.2,
			Validate = function(_, id)
				return type(id) == "string"
			end,
			Handle = function(player, state, _, action, id)
				if action == "Unlock" and GamePack.IsEnabled("Masteries") then
					return ProgressionSystem.UnlockMastery(player, state, id)
				elseif action == "Equip" and GamePack.IsEnabled("Titles") then
					return ProgressionSystem.ToggleTitle(player, state, id)
				end
				return false
			end,
		},
	},
	AfterChange = { { Module = "Titles", Run = ProgressionSystem.CheckTitles } },
}

return ProgressionSystem
