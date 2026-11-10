--[[
	BondSystem: active bonding with the people in your life (Relationships module).
	Talking (Spend Time), training together and gifts cost Social points
	(RelationshipSystem) and grow a Bond level on that person (rel.Bond = { Level, Xp },
	saved with the relationship). Bond levels add up into a per-life buff source "Bonds":
	family -> faster growth, friends -> social success, partner and children -> health.
	Train Together also trains a physical stat and Swordsmanship.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
local GamePack = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GamePack"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local RelationshipSystem = require(script.Parent:WaitForChild("RelationshipSystem"))
local SkillSystem = require(script.Parent:WaitForChild("SkillSystem"))
local Rng = require(script.Parent:WaitForChild("Rng"))

local Stats = Content.Get("PlayerStatsConfig")

local BondSystem = {}

BondSystem.XpPerLevel = 3
BondSystem.MaxLevel = 10
BondSystem.Gains = { SpendTime = 1, Gift = 2, TrainTogether = 2, AskHelp = 1 }
BondSystem.TrainStats = { "Strength", "Agility", "Vitality" }

-- Buffs from every bond level you hold (caps keep it a bonus, not a strategy).
function BondSystem.Buffs(state)
	local family, friends, close = 0, 0, 0
	for _, rel in state.Relationships or {} do
		local level = rel.Alive ~= false and rel.Bond and rel.Bond.Level or 0
		if rel.Category == "Family" then
			family += level
		elseif rel.Category == "Friend" then
			friends += level
		elseif rel.Category == "Partner" or rel.Category == "Child" then
			close += level
		end
	end
	local buffs = {}
	if family > 0 then buffs.AllStatXp = 1 + math.min(0.15, family * 0.005) end
	if friends > 0 then buffs.SocialBonus = math.min(0.1, friends * 0.005) end
	if close > 0 then buffs.MaxHealthBonus = math.min(60, close * 3) end
	return buffs, family, friends, close
end

function BondSystem.Refresh(state)
	local buffs = BondSystem.Buffs(state)
	PlayerState.SetLifeBuff(state, "Bonds", "Bonds", buffs)
end

-- One bonding interaction with `rel`. Returns a summary line or nil.
function BondSystem.Gain(player, state, rel, interactionId: string): string?
	local gain = BondSystem.Gains[interactionId]
	if not rel or not gain then
		return nil
	end
	local parts = {}
	if interactionId == "TrainTogether" then
		local stat = BondSystem.TrainStats[Rng:NextInteger(1, #BondSystem.TrainStats)]
		if state.Stats[stat] then
			table.insert(parts, ("+%d %s"):format(PlayerState.AddStatXp(player, state, stat, 12), Stats.Stats[stat].Short))
		end
		local xp = SkillSystem.Grant(player, state, "Swordsmanship", 4)
		if xp > 0 then table.insert(parts, ("+%d Swordsmanship"):format(xp)) end
	end
	rel.Bond = rel.Bond or { Level = 0, Xp = 0 }
	local bond = rel.Bond
	if bond.Level < BondSystem.MaxLevel then
		bond.Xp += gain
		while bond.Level < BondSystem.MaxLevel and bond.Xp >= BondSystem.XpPerLevel do
			bond.Xp -= BondSystem.XpPerLevel
			bond.Level += 1
			table.insert(parts, ("bond with %s: level %d"):format(rel.Name, bond.Level))
			SkillSystem.Count(player, state, "BondLevels", bond.Level)
		end
	end
	BondSystem.Refresh(state)
	return if #parts > 0 then table.concat(parts, ", ") else nil
end

table.insert(RelationshipSystem.InteractHooks, function(player, state, rel, interactionId)
	if GamePack.IsEnabled("Relationships") then
		return BondSystem.Gain(player, state, rel, interactionId)
	end
	return nil
end)

-- People leave and die: the buff follows the bonds you still have.
BondSystem.Hooks = {
	YearTicks = {
		{ Phase = "Systems", Order = 95, Module = "Relationships", Run = function(_, state) BondSystem.Refresh(state) end },
	},
}

return BondSystem
