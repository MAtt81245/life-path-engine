--[[
	MasterSystem: discovering masters, joining, loyalty quests and techniques.
	- Masters live in regions (MastersConfig.Regions, World module): "Seek a Master" only
	  finds masters of the current region.
	- Sect hierarchy (MastersConfig.SectRanks): a yearly stipend per rank and promotion
	  trials (MasterAction "Trial", 1 action diamond).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
local Masters = Content.Get("MastersConfig")
local Requirements = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Requirements"))
local GamePack = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GamePack"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local DuelSystem = require(script.Parent:WaitForChild("DuelSystem"))
local DuelConfig = Content.Get("DuelConfig")

local MasterSystem = {}

local rng = require(script.Parent:WaitForChild("Rng"))

local function current(state)
	return state.Master.Id and Masters.ById[state.Master.Id]
end

local function checkTechnique(player: Player, state)
	local master = current(state)
	if master and not state.LearnedTechniques[master.Id] and state.Master.Loyalty >= master.TechniqueLoyalty then
		state.LearnedTechniques[master.Id] = true
		PlayerState.CodexAdd(state, "Techniques", master.Id)
		PlayerState.Log(player, ("%s teaches you the legendary %s!"):format(master.Name, master.Technique.Name), "realm")
		PlayerState.Notify(player, "Legendary technique learned: " .. master.Technique.Name, "realm")
	end
end

-- Whether a master can be met where the character lives now.
function MasterSystem.InRegion(state, master): boolean
	if not master.Regions or not GamePack.IsActive("World") then
		return true
	end
	local world = state.Modules and state.Modules.World
	return world ~= nil and table.find(master.Regions, world.Region) ~= nil
end

-- True when no undiscovered master lives in the current region.
function MasterSystem.AllDiscovered(state): boolean
	for _, master in Masters.List do
		if not state.DiscoveredMasters[master.Id] and MasterSystem.InRegion(state, master) then
			return false
		end
	end
	return true
end

-- Returns a short summary of what the search found.
function MasterSystem.Seek(player: Player, state, buffs): string
	local undiscovered = {}
	for _, master in Masters.List do
		if not state.DiscoveredMasters[master.Id] and MasterSystem.InRegion(state, master) then
			table.insert(undiscovered, master)
		end
	end
	if #undiscovered == 0 then
		return PlayerState.Words("no {mentorName}s left to find in this region")
	end
	local chance = Masters.SeekChance + PlayerState.RoleLevel(state, "Social") * 0.005 + buffs.SocialBonus * 0.5
	if rng:NextNumber() >= chance then
		return "the search found nothing"
	end
	local master = undiscovered[rng:NextInteger(1, #undiscovered)]
	state.DiscoveredMasters[master.Id] = true
	PlayerState.Log(player, ("You found %s, %s of the %s."):format(master.Name, master.Title, master.Sect), "event")
	return "found " .. master.Name
end

function MasterSystem.Join(player: Player, state, masterId: string)
	local master = Masters.ById[masterId]
	if not master then
		return false
	end
	if not state.DiscoveredMasters[masterId] then
		return false, PlayerState.Words("You haven't found this {mentorName} yet.")
	end
	if state.Master.Id then
		return false, PlayerState.Words("You already follow a {mentorName}. Leave them first.")
	end
	local met, items = Requirements.Evaluate(state, master.Requires)
	if not met then
		return false, ("%s refuses: %s."):format(master.Name, Requirements.UnmetText(items))
	end
	state.Master = { Id = masterId, Loyalty = Masters.JoinLoyalty, QuestsDone = {}, Rank = 1 }
	PlayerState.Log(player, PlayerState.Words("%s accepts you as a {studentName} of the %s."):format(master.Name, master.Sect), "realm")
	return true, PlayerState.Words("You are now a {studentName} of %s."):format(master.Name)
end

function MasterSystem.Leave(player: Player, state)
	local master = current(state)
	if not master then
		return false
	end
	state.Master = { Id = nil, Loyalty = 0, QuestsDone = {} }
	PlayerState.AdjustMeter(state, "Happiness", -5)
	PlayerState.Log(player, ("You leave %s and the %s."):format(master.Name, master.Sect), "bad")
	return true, "You left " .. master.Name .. ".", "warn"
end

function MasterSystem.CompleteQuest(player: Player, state, index: number)
	local master = current(state)
	if not master then
		return false, PlayerState.Words("You have no {mentorName}.")
	end
	local quest = master.Quests[index]
	if not quest then
		return false
	end
	local key = tostring(index)
	if state.Master.QuestsDone[key] then
		return false, "Quest already completed."
	end
	local met, items = Requirements.Evaluate(state, quest.Requires)
	if not met then
		return false, "Not ready: " .. Requirements.UnmetText(items)
	end
	if quest.PayMoney then
		state.Money -= quest.PayMoney
	end
	state.Master.QuestsDone[key] = true
	state.Master.Loyalty = math.min(Masters.MaxLoyalty, state.Master.Loyalty + quest.Loyalty)
	PlayerState.Log(player, ("Loyalty quest complete: %s (+%d loyalty)."):format(quest.Name, quest.Loyalty), "good")
	checkTechnique(player, state)
	return true, ("Quest complete: %s"):format(quest.Name)
end

function MasterSystem.Rank(state)
	local ranks = Masters.SectRanks or {}
	local index = (state.Master and state.Master.Rank) or 1
	return ranks[math.clamp(index, 1, math.max(1, #ranks))], index
end

-- Promotion trial for the next sect rank. Returns (ok, message, kind).
function MasterSystem.Trial(player: Player, state)
	local master = current(state)
	if not master then
		return false, PlayerState.Words("You have no {sectName}.")
	end
	local ranks = Masters.SectRanks or {}
	local _, index = MasterSystem.Rank(state)
	local nextRank = ranks[index + 1]
	if not nextRank then
		return false, "There is no higher rank."
	elseif state.Actions < 1 then
		return false, "No actions left this year. Advance the year."
	end
	local met, items = Requirements.Evaluate(state, nextRank.Requires)
	if not met then
		return false, "Not ready: " .. Requirements.UnmetText(items)
	end
	if state.PendingDuel then
		return false, "Finish your current duel first."
	end
	state.Actions -= 1
	-- The trial is a Tactical Clash against a sect examiner (harder for higher ranks).
	DuelSystem.Start(player, state, {
		Kind = "Trial", Title = ("Trial: %s"):format(nextRank.Name), FoeName = ("%s Examiner"):format(master.Sect),
		Difficulty = DuelConfig.Difficulty.Trial + index * DuelConfig.RankStep,
		Weapon = PlayerState.Words("{SectName} blade"), Technique = master.Technique and master.Technique.Name or PlayerState.Words("{SectName} art"),
		Context = { Rank = index + 1 },
	})
	return true, nil
end

DuelSystem.Outcomes.Trial = function(player, state, duel, won)
	local master = current(state)
	local rank = (Masters.SectRanks or {})[duel.Context.Rank]
	if not master or not rank then
		return "The trial no longer matters."
	end
	if won then
		state.Master.Rank = duel.Context.Rank
		return ("You pass the trial: %s of the %s."):format(rank.Name, master.Sect)
	end
	PlayerState.AddHealth(state, Masters.TrialFailHealth or -15)
	return ("You fail the %s trial."):format(rank.Name)
end

function MasterSystem.YearTick(player: Player, state)
	if current(state) then
		state.Master.Loyalty = math.min(Masters.MaxLoyalty, state.Master.Loyalty + Masters.LoyaltyPerYear)
		checkTechnique(player, state)
		local rank = MasterSystem.Rank(state)
		if rank and rank.Stipend then
			state.Money += rank.Stipend
		end
	end
end

-- Registry hooks (see SystemRegistry).
MasterSystem.Hooks = {
	YearTicks = { { Phase = "Systems", Order = 20, Module = "Masters", Run = MasterSystem.YearTick } },
	Remotes = {
		MasterAction = {
			Module = "Masters",
			Cooldown = 0.3,
			Handle = function(player, state, _, action, arg)
				if action == "Join" and type(arg) == "string" then
					return MasterSystem.Join(player, state, arg)
				elseif action == "Leave" then
					return MasterSystem.Leave(player, state)
				elseif action == "Quest" and type(arg) == "number" and arg % 1 == 0 then
					return MasterSystem.CompleteQuest(player, state, arg)
				elseif action == "Trial" then
					return MasterSystem.Trial(player, state)
				end
				return false
			end,
		},
	},
}

return MasterSystem
