--[[
	CareerSystem: education tiers (auto-enrollment, grades, tuition, graduation)
	and careers (applications, salary, performance).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
local Studies = Content.Get("StudiesAndCareerConfig")
local Requirements = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Requirements"))
local GamePack = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GamePack"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))

local CareerSystem = {}

local rng = require(script.Parent:WaitForChild("Rng"))

local function enroll(player: Player, state, tier)
	state.Education = { Tier = tier.Id, Enrolled = true, Years = 0, Performance = Studies.StartPerformance }
	PlayerState.Log(player, ("You start %s."):format(tier.Name), "info")
end

-- Compulsory (Auto) tiers always graduate; the rest need passing grades.
local function finishTier(player: Player, state, tier)
	local performance = state.Education.Performance
	state.Education.Enrolled = false
	if tier.Auto or performance >= Studies.PassPerformance then
		state.Graduated[tier.Id] = true
		if performance >= Studies.HonorsPerformance then
			state.Honors[tier.Id] = true
			PlayerState.AdjustMeter(state, "Happiness", 10)
			PlayerState.Log(player, ("You graduate from %s with honors!"):format(tier.Name), "good")
		else
			PlayerState.Log(player, ("You graduate from %s."):format(tier.Name), "good")
		end
	else
		PlayerState.AdjustMeter(state, "Happiness", -10)
		PlayerState.Log(player, ("You failed to graduate from %s."):format(tier.Name), "bad")
	end
end

function CareerSystem.YearTick(player: Player, state, buffs)
	if GamePack.IsEnabled("Education") then
		CareerSystem.EducationTick(player, state, buffs)
	end
	if GamePack.IsEnabled("Careers") then
		CareerSystem.JobTick(player, state, buffs)
	end
end

function CareerSystem.EducationTick(player: Player, state, buffs)
	local edu = state.Education
	if edu.Enrolled then
		local tier = Studies.TiersById[edu.Tier]
		if tier then
			edu.Years += 1
			for stat, xp in tier.YearlyXp do
				PlayerState.AddStatXp(player, state, stat, xp, buffs)
			end
			local stressPenalty = if state.Stress >= 70 then 8 else 0
			edu.Performance = math.clamp(edu.Performance + (50 - edu.Performance) * 0.12 - stressPenalty, 0, 100)
			if tier.TuitionPerYear > 0 and edu.Performance < Studies.HonorsPerformance then
				if state.Money >= tier.TuitionPerYear then
					state.Money -= tier.TuitionPerYear
				else
					edu.Enrolled = false
					PlayerState.Log(player, ("You could not afford tuition and dropped out of %s."):format(tier.Name), "bad")
				end
			end
			if edu.Enrolled and edu.Years >= tier.Duration then
				finishTier(player, state, tier)
			end
		else
			edu.Enrolled = false
		end
	end

	if not state.Education.Enrolled then
		for _, tier in Studies.Tiers do
			local ready = tier.Auto and state.Age == tier.StartAge and not state.Graduated[tier.Id]
				and (not tier.Previous or state.Graduated[tier.Previous])
			if ready then
				enroll(player, state, tier)
				break
			end
		end
	end
end

function CareerSystem.JobTick(player: Player, state, buffs)
	local career = state.Career.Id and Studies.CareersById[state.Career.Id]
	if career then
		state.Money += PlayerState.GetSalary(state, buffs)
		state.Career.Years += 1
		PlayerState.AdjustMeter(state, "Stress", career.Stress)
		state.Career.Performance = math.clamp(state.Career.Performance + (50 - state.Career.Performance) * 0.1, 0, 100)
		if state.Career.Performance < 20 and rng:NextNumber() < 0.3 then
			state.Career = { Id = nil, Years = 0, Performance = 50 }
			PlayerState.AdjustMeter(state, "Happiness", -10)
			PlayerState.Log(player, ("You were fired from your job as %s."):format(career.Name), "bad")
		end
	end
end

function CareerSystem.Enroll(player: Player, state, tierId: string)
	local tier = Studies.TiersById[tierId]
	if not tier or tier.Auto then
		return false
	end
	if state.Education.Enrolled then
		return false, "You are already enrolled."
	end
	if state.Graduated[tier.Id] then
		return false, "You already completed " .. tier.Name .. "."
	end
	local met, items = Requirements.Evaluate(state, tier.Requires)
	if not met then
		return false, "Requirements not met: " .. Requirements.UnmetText(items)
	end
	local career = state.Career.Id and Studies.CareersById[state.Career.Id]
	if career and not career.PartTime then
		return false, "Quit your full-time job first."
	end
	enroll(player, state, tier)
	return true, "Enrolled in " .. tier.Name .. "."
end

function CareerSystem.DropOut(player: Player, state)
	local tier = state.Education.Enrolled and Studies.TiersById[state.Education.Tier]
	if not tier then
		return false
	end
	if tier.Auto and state.Age < 16 then
		return false, "School is compulsory until 16."
	end
	state.Education.Enrolled = false
	PlayerState.AdjustMeter(state, "Stress", -10)
	PlayerState.Log(player, ("You dropped out of %s."):format(tier.Name), "bad")
	return true, "You dropped out of " .. tier.Name .. ".", "warn"
end

function CareerSystem.ApplyJob(player: Player, state, careerId: string, buffs)
	local career = Studies.CareersById[careerId]
	if not career then
		return false
	end
	if state.Career.Id == careerId then
		return false, "You already work there."
	end
	if state.Age < Studies.MinWorkingAge then
		return false, "You are too young to work."
	end
	if state.Education.Enrolled and not career.PartTime then
		return false, "Only part-time jobs are possible while studying."
	end
	local met, items = Requirements.Evaluate(state, career.Requires)
	if not met then
		return false, "Requirements not met: " .. Requirements.UnmetText(items)
	end
	if state.LastApplyAge == state.Age then
		return false, "You already had a job interview this year."
	end
	state.LastApplyAge = state.Age
	if not PlayerState.RollChance(state, 0.6, PlayerState.RoleStat("Social"), buffs) then
		return false, "The interview went badly. Try again next year."
	end
	state.Career = { Id = careerId, Years = 0, Performance = 50 }
	PlayerState.Log(player, ("You were hired as %s."):format(career.Name), "good")
	return true, "Hired as " .. career.Name .. "!"
end

function CareerSystem.QuitJob(player: Player, state)
	local career = state.Career.Id and Studies.CareersById[state.Career.Id]
	if not career then
		return false
	end
	state.Career = { Id = nil, Years = 0, Performance = 50 }
	PlayerState.AdjustMeter(state, "Stress", -10)
	PlayerState.Log(player, ("You quit your job as %s."):format(career.Name), "info")
	return true, "You quit your job.", "warn"
end

-- Registry hooks (see SystemRegistry).
CareerSystem.Hooks = {
	YearTicks = { { Phase = "Systems", Order = 10, Module = { "Education", "Careers" }, Run = CareerSystem.YearTick } },
	Remotes = {
		CareerAction = {
			Module = { "Education", "Careers" },
			Cooldown = 0.3,
			Handle = function(player, state, buffs, action, arg)
				local education, careers = GamePack.IsEnabled("Education"), GamePack.IsEnabled("Careers")
				if education and action == "Enroll" and type(arg) == "string" then
					return CareerSystem.Enroll(player, state, arg)
				elseif education and action == "DropOut" then
					return CareerSystem.DropOut(player, state)
				elseif careers and action == "ApplyJob" and type(arg) == "string" then
					return CareerSystem.ApplyJob(player, state, arg, buffs)
				elseif careers and action == "QuitJob" then
					return CareerSystem.QuitJob(player, state)
				end
				return false
			end,
		},
	},
}

return CareerSystem
