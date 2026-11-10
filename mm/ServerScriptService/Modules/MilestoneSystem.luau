--[[
	MilestoneSystem: progressive disclosure (ProgressionGatesConfig). On milestone
	birthdays the player gets a toast and a Chronicle entry; the client reveals tabs
	and actions by age on its own (UIController, TrainingPage).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))

local Gates = Content.Get("ProgressionGatesConfig")

local MilestoneSystem = {}

-- Milestone texts reached exactly at this age.
function MilestoneSystem.At(age: number): { string }
	local texts = {}
	for _, milestone in Gates.Milestones or {} do
		if milestone.Age == age then
			table.insert(texts, milestone.Text)
		end
	end
	return texts
end

function MilestoneSystem.YearTick(player, state)
	for _, text in MilestoneSystem.At(state.Age) do
		PlayerState.Log(player, "Milestone: " .. text, "realm")
		PlayerState.Notify(player, text, "realm")
		PlayerState.Feedback(player, "Milestone")
	end
end

MilestoneSystem.Hooks = {
	YearTicks = { { Phase = "Systems", Order = 1, Run = MilestoneSystem.YearTick } },
}

return MilestoneSystem
