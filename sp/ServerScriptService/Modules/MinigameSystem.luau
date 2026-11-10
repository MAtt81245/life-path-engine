--[[
	MinigameSystem: rewards for the Today page minigames (MinigamesConfig; Minigames
	module). The client plays; the server checks age and the once-a-year limit and caps
	the score, so a forged result can never pay more than a perfect run.
	Per-life data in ModuleData(state, "Minigames"): { Played = { Id = age } }.
	Minigame remote: ("Motes", score) | ("Sneak", success).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
local GamePack = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GamePack"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local SkillSystem = require(script.Parent:WaitForChild("SkillSystem"))

local Minigames = Content.Get("MinigamesConfig")

local MinigameSystem = {}

function MinigameSystem.Data(state)
	local data = PlayerState.ModuleData(state, "Minigames", {})
	data.Played = data.Played or {}
	return data
end

function MinigameSystem.Check(state, id: string): string?
	local def = Minigames[id]
	if not def then
		return "Unknown game."
	elseif state.Dead then
		return "The dead do not play."
	elseif state.Age < def.MinAge or state.Age > (def.MaxAge or math.huge) then
		return ("%s is for ages %d-%s."):format(def.Name, def.MinAge, if def.MaxAge then tostring(def.MaxAge) else "any")
	elseif MinigameSystem.Data(state).Played[id] == state.Age then
		return "Once a year. Come back next year."
	end
	return nil
end

function MinigameSystem.Motes(player, state, score)
	local reason = MinigameSystem.Check(state, "Motes")
	if reason then
		return false, reason, "warn"
	end
	local def = Minigames.Motes
	score = math.clamp(math.floor(tonumber(score) or 0), 0, def.MaxScore)
	MinigameSystem.Data(state).Played.Motes = state.Age
	local buffs = PlayerState.GetBuffs(state)
	local parts = SkillSystem.ApplyEffects(player, state, {
		StatXp = { Mana = math.floor(score * def.ManaXpPer), Luck = math.floor(score * def.LuckXpPer) },
		SkillXp = { Magic = math.floor(score * def.MagicXpPer) },
	}, buffs)
	local bonus = math.min(def.MaxManaBonus, math.floor(score / def.ManaBonusPer))
	if bonus > 0 and GamePack.IsActive("Arcana") then
		require(script.Parent:WaitForChild("ArcanaSystem")).AddManaBonus(state, bonus)
		table.insert(parts, ("max mana +%d"):format(bonus))
	end
	SkillSystem.Count(player, state, "motes_caught", score)
	SkillSystem.Count(player, state, "minigames", 1)
	local text = ("Catch the Light: %d motes. %s"):format(score, table.concat(parts, ", "))
	PlayerState.Log(player, text, "good")
	return true, text, "good"
end

function MinigameSystem.Sneak(player, state, success)
	local reason = MinigameSystem.Check(state, "Sneak")
	if reason then
		return false, reason, "warn"
	end
	local def = Minigames.Sneak
	MinigameSystem.Data(state).Played.Sneak = state.Age
	local parts = SkillSystem.ApplyEffects(player, state, if success then def.Success else def.Fail)
	if success then
		SkillSystem.Count(player, state, "sneak_wins", 1)
	end
	SkillSystem.Count(player, state, "minigames", 1)
	if GamePack.IsActive("Character") then
		local Character = Content.Get("CharacterConfig")
		require(script.Parent:WaitForChild("CharacterSystem")).Push(player, state, Character.Pushes.Sneak)
	end
	local text = if success then ("You reached the study unseen and read until dawn. %s"):format(table.concat(parts, ", "))
		else ("Mother caught you and sent you to bed. %s"):format(table.concat(parts, ", "))
	PlayerState.Log(player, text, if success then "good" else "bad")
	return true, text, if success then "good" else "bad"
end

MinigameSystem.Hooks = {
	Remotes = {
		Minigame = {
			Module = "Minigames",
			Cooldown = 1,
			Validate = function(id, result)
				return (id == "Motes" and type(result) == "number") or (id == "Sneak" and type(result) == "boolean")
			end,
			Handle = function(player, state, _, id, result)
				if id == "Motes" then
					return MinigameSystem.Motes(player, state, result)
				end
				return MinigameSystem.Sneak(player, state, result)
			end,
		},
	},
}

return MinigameSystem
