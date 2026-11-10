--[[
	SchoolingSystem: the Education modes (SchoolingConfig; Education module). Per-life
	ModuleData(state, "Schooling") = { Mode, LastGain }. SchoolingAction remote:
	("Mode", id). The year tick pays the mode's gains and charges its cost.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local SkillSystem = require(script.Parent:WaitForChild("SkillSystem"))
local ChronicleSystem = require(script.Parent:WaitForChild("ChronicleSystem"))

local Schooling = Content.Get("SchoolingConfig")

local SchoolingSystem = {}

local function mode(id: string?)
	for _, entry in Schooling.Modes do
		if entry.Id == id then return entry end
	end
	return nil
end
SchoolingSystem.Mode = mode

function SchoolingSystem.Data(state)
	local data = PlayerState.ModuleData(state, "Schooling", {})
	data.Mode = data.Mode or Schooling.Default
	return data
end

function SchoolingSystem.SetMode(state, id: string)
	local entry = mode(id)
	if not entry then
		return false
	elseif state.Age < Schooling.MinAge or state.Age > Schooling.MaxAge then
		return false, ("Schooling is for ages %d-%d."):format(Schooling.MinAge, Schooling.MaxAge), "warn"
	elseif entry.MinMoney and state.Money < entry.MinMoney then
		return false, ("%s needs a family with %s."):format(entry.Name, PlayerState.FormatMoney(entry.MinMoney)), "warn"
	end
	SchoolingSystem.Data(state).Mode = entry.Id
	return true, ("From now on: %s."):format(entry.Name), "good"
end

function SchoolingSystem.YearTick(player, state)
	if state.Age < Schooling.MinAge or state.Age > Schooling.MaxAge then
		return
	end
	local data = SchoolingSystem.Data(state)
	local entry = mode(data.Mode) or mode(Schooling.Default)
	if entry.Cost > 0 and state.Money < entry.Cost then
		PlayerState.Log(player, ("Your family can no longer pay for the %s. Back to the %s."):format(entry.Name, mode(Schooling.Default).Name), "warn")
		entry = mode(Schooling.Default)
		data.Mode = entry.Id
	end
	state.Money -= entry.Cost
	local gains = table.clone(entry.Gains)
	local family = gains.FamilyAffection
	gains.FamilyAffection = nil
	local parts = SkillSystem.ApplyEffects(player, state, gains)
	if family then
		for _, part in ChronicleSystem.ApplyGains(player, state, { FamilyAffection = family }) do
			table.insert(parts, part)
		end
	end
	data.LastGain = table.concat(parts, ", ") .. (if entry.Cost > 0 then (" (-%s)"):format(PlayerState.FormatMoney(entry.Cost)) else "")
end

SchoolingSystem.Hooks = {
	YearTicks = {
		{ Phase = "Systems", Order = 9, Module = "Education", Run = SchoolingSystem.YearTick },
	},
	Remotes = {
		SchoolingAction = {
			Module = "Education",
			Cooldown = 0.3,
			Validate = function(action, id)
				return action == "Mode" and type(id) == "string"
			end,
			Handle = function(_, state, _, _, id)
				return SchoolingSystem.SetMode(state, id)
			end,
		},
	},
}

return SchoolingSystem
