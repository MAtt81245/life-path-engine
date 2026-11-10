--[[
	RelationshipSystem: player interactions with family, friends, rivals and partner,
	plus yearly affection drift, aging and deaths of the people around you.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
local RelConfig = Content.Get("RelationshipsConfig")
local StatsConfig = Content.Get("PlayerStatsConfig")
local Requirements = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Requirements"))
local GamePack = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GamePack"))
local GeneticsText = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GeneticsText"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local DynastySystem = require(script.Parent:WaitForChild("DynastySystem"))
local DuelSystem = require(script.Parent:WaitForChild("DuelSystem"))
local DuelConfig = Content.Get("DuelConfig")

local RelationshipSystem = {}

local rng = require(script.Parent:WaitForChild("Rng"))

-- Money a family member gives when asked for help (RelationshipsConfig.FamilyHelp).
function RelationshipSystem.FamilyGift(state, rel): number
	local help = RelConfig.FamilyHelp
	local bracket = help.Brackets[#help.Brackets]
	for _, candidate in help.Brackets do
		if state.Age <= candidate.MaxAge then
			bracket = candidate
			break
		end
	end
	local amount = rng:NextInteger(bracket.Min, bracket.Max)
	if help.AffectionScale then
		amount *= 0.5 + rel.Affection / 200
	end
	if rel.Occupation then
		amount *= help.EmployedMult or 1
	end
	return math.floor(amount)
end

-- Returns (ok, message, kind).
function RelationshipSystem.Interact(player: Player, state, relId: string, interactionId: string, buffs)
	local rel = PlayerState.FindRelationship(state, relId)
	local interaction = RelConfig.InteractionsById[interactionId]
	if not rel or not rel.Alive or not interaction or not interaction.Categories[rel.Category] or not GamePack.IsEnabled(interaction.Module) then
		return false
	end
	if state.Age < 3 then
		return false, "You are too young."
	end
	if rel.Away and interactionId == "SpendTime" then
		return false, rel.Name .. " lives far away now."
	end
	if interaction.MinAge and state.Age < interaction.MinAge then
		return false, ("You must be %d to do that."):format(interaction.MinAge)
	end
	if interaction.MinAffection and rel.Affection < interaction.MinAffection then
		return false, ("%s isn't close enough (needs %d affection)."):format(rel.Name, interaction.MinAffection)
	end
	if interaction.OncePerYear and rel.LastHelpAge == state.Age then
		return false, ("You already asked %s this year."):format(rel.Name)
	end
	if interaction.MoneyCost and state.Money < interaction.MoneyCost then
		return false, "You can't afford that."
	end
	if interactionId == "Romance" and not Requirements.Check(state, { NoRelationship = "Partner" }) then
		return false, "You already have a partner."
	end
	if interactionId == "Romance" then
		local blocked = GeneticsText.RomanceBlock(state, rel)
		if blocked then
			return false, blocked
		end
	end
	if interaction.MinMoney and state.Money < interaction.MinMoney then
		return false, ("You need %s to wager."):format(PlayerState.FormatMoney(interaction.MinMoney))
	end
	if interaction.Upbringing and ((rel.Genetics and rel.Genetics.Upbringing) or rel.Age > (interaction.MaxChildAge or math.huge)) then
		return false, if rel.Genetics and rel.Genetics.Upbringing then ("%s's upbringing is already %s."):format(rel.Name, rel.Genetics.Upbringing)
			else rel.Name .. " is grown up now."
	end
	-- BitLife rule: each interaction once per person per year, within a yearly social budget.
	state.SocialDone = state.SocialDone or {}
	local done = state.SocialDone[rel.Id]
	if done and done[interactionId] then
		return false, ("You already did that with %s this year."):format(rel.Name)
	end
	if (state.Social or 0) <= 0 then
		return false, "No social interactions left this year."
	end

	state.Social -= 1
	done = done or {}
	done[interactionId] = true
	state.SocialDone[rel.Id] = done
	if interaction.MoneyCost then state.Money -= interaction.MoneyCost end
	if interaction.Happiness then PlayerState.AdjustMeter(state, "Happiness", interaction.Happiness) end
	if interaction.Stress then PlayerState.AdjustMeter(state, "Stress", interaction.Stress) end

	if interactionId == "AskHelp" then
		rel.LastHelpAge = state.Age
		PlayerState.Remember(state, rel, "Helped you when you asked", 1)
		PlayerState.AdjustAffection(rel, interaction.Affection)
		if rel.Category == "Family" then
			local help = RelConfig.FamilyHelp
			if rel.Age < help.MinGiverAge then
				PlayerState.AdjustMeter(state, "Happiness", 5)
				PlayerState.AdjustMeter(state, "Stress", -8)
				return true, rel.Name .. " has no money, but cheers you up."
			end
			local gift = RelationshipSystem.FamilyGift(state, rel)
			state.Money += gift
			return true, ("%s gives you %s."):format(rel.Name, PlayerState.FormatMoney(gift))
		elseif rel.Category == "Partner" then
			PlayerState.AdjustMeter(state, "Stress", -15)
			PlayerState.AdjustMeter(state, "Happiness", 8)
			return true, rel.Name .. " comforts you. Your stress melts away."
		end
		local stat = StatsConfig.Order[rng:NextInteger(1, #StatsConfig.Order)]
		local xp = PlayerState.AddStatXp(player, state, stat, 20, buffs)
		return true, ("%s helps you train: +%d %s."):format(rel.Name, xp, StatsConfig.Stats[stat].Short)

	elseif interactionId == "Romance" then
		local penalty = if rel.Genetics then GeneticsText.Grade(rel.Genetics).ChancePenalty else 0
		if PlayerState.RollChance(state, interaction.Chance - penalty, interaction.ChanceStat, buffs) then
			PlayerState.SetRelationshipType(rel, "Partner")
			PlayerState.AdjustAffection(rel, 10, buffs)
			PlayerState.AdjustMeter(state, "Happiness", 12)
			PlayerState.Log(player, ("%s said yes! You are now a couple."):format(rel.Name), "good")
			PlayerState.Remember(state, rel, "Started dating you", 1)
			return true, rel.Name .. " said yes!"
		end
		PlayerState.AdjustAffection(rel, -10)
		PlayerState.AdjustMeter(state, "Happiness", -5)
		return true, rel.Name .. " turned you down.", "bad"

	elseif interaction.Stake == "Wealth" or interaction.Stake == "Life" then
		return RelationshipSystem.StakedDuel(player, state, rel, interaction, buffs)

	elseif interactionId == "TryForChild" then
		return DynastySystem.TryForChild(player, state, rel)

	elseif interaction.Upbringing then
		rel.Genetics = rel.Genetics or {}
		rel.Genetics.Upbringing = interaction.Upbringing
		PlayerState.AdjustAffection(rel, interaction.Affection or 0, buffs)
		PlayerState.Remember(state, rel, ("Raised on a %s path"):format(string.lower(interaction.Upbringing)), 1)
		return true, ("You guide %s toward a %s upbringing."):format(rel.Name, string.lower(interaction.Upbringing))

	elseif interactionId == "Challenge" then
		local penalty = if rel.Genetics then GeneticsText.Grade(rel.Genetics).ChancePenalty else 0
		if PlayerState.RollChance(state, interaction.Chance - penalty, interaction.ChanceStat, buffs) then
			state.Counters.Fights += 1
			PlayerState.AdjustAffection(rel, 10, buffs)
			PlayerState.AdjustMeter(state, "Happiness", 8)
			if interaction.ChanceStat then
				PlayerState.AddStatXp(player, state, interaction.ChanceStat, 10, buffs)
			end
			PlayerState.Remember(state, rel, "Lost a duel to you", -1)
			return true, ("You defeated %s in a duel!"):format(rel.Name)
		end
		PlayerState.AddHealth(state, -15, buffs)
		PlayerState.AdjustMeter(state, "Happiness", -8)
		return true, ("%s beat you in the duel."):format(rel.Name), "bad"

	elseif interactionId == "Reconcile" then
		if PlayerState.RollChance(state, interaction.Chance, interaction.ChanceStat, buffs) then
			PlayerState.SetRelationshipType(rel, "Friend")
			rel.Affection = math.max(rel.Affection, 45)
			PlayerState.Log(player, ("You made peace with %s. You are friends now."):format(rel.Name), "good")
			PlayerState.Remember(state, rel, "Made peace with you", 1)
			return true, "You made peace with " .. rel.Name .. "."
		end
		PlayerState.AdjustAffection(rel, -5)
		return true, rel.Name .. " refuses to make peace.", "bad"
	end

	-- SpendTime / Gift / Argue
	local delta = PlayerState.AdjustAffection(rel, interaction.Affection, buffs)
	if interactionId == "Gift" then
		PlayerState.Remember(state, rel, "Got a gift from you", 1)
	elseif interactionId == "Argue" then
		PlayerState.Remember(state, rel, "Argued with you", -1)
	end
	local message = ("%s: %+d affection with %s."):format(interaction.Name, delta, rel.Name)
	if interactionId == "Argue" and rel.Category == "Friend" and rel.Affection < 20 then
		PlayerState.SetRelationshipType(rel, "Rival")
		PlayerState.Log(player, ("%s is now your rival."):format(rel.Name), "bad")
		message ..= " They are now your rival."
	end
	return true, message, if delta < 0 then "warn" else "good"
end

-- Adult duels with stakes open a Tactical Clash (DuelSystem): Wealth (wager 20% of your
-- money, at least $100) or Life (a blood feud: the loser dies, or you nearly do).
-- High-grade rivals fight harder.
function RelationshipSystem.StakedDuel(player, state, rel, interaction, _buffs)
	if state.PendingDuel then
		return false, "Finish your current duel first."
	end
	local grade = if rel.Genetics and rel.Genetics.Grade then (Content.Get("GeneticsConfig").GradeIndex[rel.Genetics.Grade] or 1) else 1
	local kind = if interaction.Stake == "Wealth" then "Wager" else "BloodFeud"
	DuelSystem.Start(player, state, {
		Kind = kind, Title = if kind == "Wager" then "Wager Duel" else "Blood Feud", FoeName = rel.Name,
		Difficulty = DuelConfig.Difficulty[kind] + (grade - 1) * DuelConfig.GradeStep,
		Weapon = if grade >= 4 then "Spirit blade" else "Steel blade", Technique = if grade >= 3 then "Family art" else "Street forms",
		Context = { RelId = rel.Id, MinMoney = interaction.MinMoney },
	})
	return true, nil
end

-- Duel outcomes (DuelSystem.Outcomes).
function RelationshipSystem.ResolveStake(player, state, rel, stake: string, won: boolean, buffs)
	buffs = buffs or PlayerState.GetBuffs(state)
	if not rel then
		return "Your rival is gone."
	end
	if stake == "Wealth" then
		local stake = math.max(100, math.floor(state.Money * 0.2))
		if won then
			state.Money += stake
			state.Counters.Fights += 1
			PlayerState.AdjustAffection(rel, -8)
			PlayerState.Remember(state, rel, "Lost a wager duel to you", -1)
			return ("You beat %s and win the wager: +%s."):format(rel.Name, PlayerState.FormatMoney(stake))
		end
		state.Money -= stake
		PlayerState.AddHealth(state, -10, buffs)
		return ("%s wins the wager: -%s."):format(rel.Name, PlayerState.FormatMoney(stake))
	end
	-- Life-and-death blood feud.
	if won then
		state.Counters.Fights += 1
		state.Alignment = math.clamp(state.Alignment - 8, -100, 100)
		PlayerState.AdjustMeter(state, "Happiness", 10)
		PlayerState.RemoveRelationship(state, rel.Id)
		return ("%s falls. The blood feud dies with them."):format(rel.Name)
	end
	PlayerState.AddHealth(state, -60, buffs)
	PlayerState.AdjustMeter(state, "Stress", 15)
	PlayerState.Remember(state, rel, "Nearly killed you in a blood feud", -1)
	return ("%s cuts you down. You barely survive."):format(rel.Name)
end

DuelSystem.Outcomes.Wager = function(player, state, duel, won)
	return RelationshipSystem.ResolveStake(player, state, PlayerState.FindRelationship(state, duel.Context.RelId), "Wealth", won)
end
DuelSystem.Outcomes.BloodFeud = function(player, state, duel, won)
	return RelationshipSystem.ResolveStake(player, state, PlayerState.FindRelationship(state, duel.Context.RelId), "Life", won)
end

function RelationshipSystem.YearTick(player: Player, state)
	for i = #state.Relationships, 1, -1 do
		local rel = state.Relationships[i]
		rel.Age += 1
		for _, kid in rel.Offspring or {} do
			kid.Age += 1 -- your grandchildren grow up too
		end
		local category = RelConfig.Categories[rel.Category]
		rel.Affection = math.clamp(rel.Affection + category.YearlyDrift, 0, 100)

		local onset = 60
		if rel.Genetics and rel.Genetics.Grade and GeneticsText.Grade(rel.Genetics) then
			local Genetics = Content.Get("GeneticsConfig")
			onset += (Genetics.GradeIndex[rel.Genetics.Grade] or 0) * (Genetics.LongevityPerGrade or 0)
		end
		local deathChance = if rel.Age > onset then (rel.Age - onset) * 0.012 else 0
		if rng:NextNumber() < deathChance then
			table.remove(state.Relationships, i)
			local typeName = string.lower(RelConfig.Types[rel.Type].Name)
			PlayerState.Log(player, ("Your %s %s passed away at %d."):format(typeName, rel.Name, rel.Age), "bad")
			if rel.Category == "Partner" then
				-- Widowed: a future partner can propose again.
				state.Flags.Married = nil
			end
			if rel.Category == "Family" or rel.Category == "Partner" then
				PlayerState.AdjustMeter(state, "Happiness", -15)
				PlayerState.AdjustMeter(state, "Stress", 10)
			elseif rel.Category == "Friend" then
				PlayerState.AdjustMeter(state, "Happiness", -6)
			end
		end
	end
end

-- Registry hooks (see SystemRegistry).
RelationshipSystem.Hooks = {
	YearTicks = { { Phase = "Systems", Order = 30, Module = "Relationships", Run = RelationshipSystem.YearTick } },
	Remotes = {
		RelationshipAction = {
			Module = "Relationships",
			Cooldown = 0.2,
			Validate = function(relId, interactionId)
				return type(relId) == "string" and type(interactionId) == "string"
			end,
			Handle = function(player, state, buffs, relId, interactionId)
				return RelationshipSystem.Interact(player, state, relId, interactionId, buffs)
			end,
		},
	},
}

return RelationshipSystem
