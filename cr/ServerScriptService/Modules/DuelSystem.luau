--[[
	DuelSystem: Tactical Clash duels (DuelConfig), best of 3 exchanges with stances
	(Strike beats Channel, Channel beats Guard, Guard beats Strike).
	- DuelSystem.Start(player, state, spec) opens state.PendingDuel (shown by the client
	  DuelModal). spec = { Kind, Title, FoeName, Difficulty, Weapon, Technique, Context }.
	- DuelAction remote: "Stance" <id> plays one exchange, "Quick" resolves the rest with
	  your strongest stance, "Close" dismisses a finished duel.
	- Outcomes are registered by the systems that start duels:
	  DuelSystem.Outcomes[Kind] = fn(player, state, duel, won) -> result text.
	- An unfinished duel is quick-resolved when the year advances.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local Rng = require(script.Parent:WaitForChild("Rng"))

local Duel = Content.Get("DuelConfig")
local Training = Content.Get("TrainingConfig")
local Items = Content.Get("ItemsConfig")

local DuelSystem = {}
DuelSystem.Outcomes = {}

local function level(state, stat: string): number
	local entry = state.Stats and state.Stats[stat]
	return entry and entry.Level or 0
end

-- Your power in each stance from stats, mastery, realm, techniques and equipment.
function DuelSystem.Powers(state)
	local inventory = PlayerState.Inventory(state)
	local equipped = inventory.Equipped or {}
	local bestProficiency = 0
	for _, key in Training.ProficiencyOrder do
		local entry = state.Proficiencies[key]
		bestProficiency = math.max(bestProficiency, entry and entry.Level or 0)
	end
	local techniques = 0
	for _ in state.LearnedTechniques or {} do
		techniques += 1
	end
	for _, buff in state.LifeBuffs or {} do
		if buff.Kind == "Technique" then
			techniques += 1
		end
	end
	local powers = {}
	for id, stance in Duel.Stances do
		local power = 5
		for stat, weight in stance.Stats do
			power += level(state, stat) * weight
		end
		power += bestProficiency * (stance.ProficiencyWeight or 0)
		power += (state.RealmIndex - 1) * (stance.RealmWeight or 0)
		power += techniques * (stance.TechniqueBonus or 0)
		if stance.WeaponBonus and equipped.Weapon then
			power += stance.WeaponBonus
		end
		if stance.ArmorBonus then
			power += (if equipped.Armor then stance.ArmorBonus else 0) + (if equipped.Accessory then stance.ArmorBonus else 0)
		end
		powers[id] = math.floor(power + 0.5)
	end
	return powers
end

local function average(powers): number
	local total, count = 0, 0
	for _, power in powers do
		total += power
		count += 1
	end
	return total / math.max(1, count)
end

local function bestStance(powers): string
	local best, value = Duel.StanceOrder[1], -1
	for _, id in Duel.StanceOrder do
		if powers[id] > value then
			best, value = id, powers[id]
		end
	end
	return best
end

-- Opens a duel. Returns the duel table.
function DuelSystem.Start(player, state, spec)
	local yours = DuelSystem.Powers(state)
	local strength = average(yours) * (spec.Difficulty or 1)
	-- The foe leans on one stance (it shows on their card as their style).
	local style = Duel.StanceOrder[Rng:NextInteger(1, #Duel.StanceOrder)]
	local foe = {}
	for _, id in Duel.StanceOrder do
		foe[id] = math.floor(strength * (if id == style then 1.15 else 0.92) + 0.5)
	end
	local inventory = PlayerState.Inventory(state)
	local weapon = inventory.Equipped and inventory.Equipped.Weapon and Items.ById[inventory.Equipped.Weapon]
	local technique
	for _, buff in state.LifeBuffs or {} do
		if buff.Kind == "Technique" then technique = buff.Name end
	end
	state.PendingDuel = {
		Kind = spec.Kind, Title = spec.Title or "Duel", Context = spec.Context or {},
		You = { Name = state.Name, Powers = yours, Weapon = weapon and weapon.Name or "Bare hands", Technique = technique or "None", HP = 100 },
		Foe = { Name = spec.FoeName or "Opponent", Powers = foe, Style = style, Weapon = spec.Weapon or "Unknown blade", Technique = spec.Technique or "Unknown art", HP = 100 },
		Wins = 0, Losses = 0, Round = 0, Log = {}, Done = false,
	}
	PlayerState.Feedback(player, "DuelStart")
	return state.PendingDuel
end

local function foeStance(duel): string
	-- Favors its style half of the time, otherwise any stance.
	if Rng:NextNumber() < 0.5 then
		return duel.Foe.Style
	end
	return Duel.StanceOrder[Rng:NextInteger(1, #Duel.StanceOrder)]
end

local function finish(player, state, duel)
	duel.Done = true
	local won = duel.Wins >= Duel.WinsNeeded
	duel.Won = won
	local outcome = DuelSystem.Outcomes[duel.Kind]
	duel.Result = (outcome and outcome(player, state, duel, won)) or (if won then "You win the duel." else "You lose the duel.")
	PlayerState.Feedback(player, if won then "DuelWin" else "DuelLose")
	PlayerState.Log(player, ("%s: %s"):format(duel.Title, duel.Result), if won then "good" else "bad")
end

-- One exchange. Returns (ok, message).
function DuelSystem.Exchange(player, state, stanceId: string)
	local duel = state.PendingDuel
	if not duel or duel.Done then
		return false
	elseif not Duel.Stances[stanceId] then
		return false
	end
	local theirs = foeStance(duel)
	local mine = Duel.Stances[stanceId]
	local function roll(base: number, advantage: boolean): number
		return base * (if advantage then Duel.AdvantageMult else 1) * (1 + (Rng:NextNumber() * 2 - 1) * Duel.Spread)
	end
	local yourRoll = roll(duel.You.Powers[stanceId], mine.Beats == theirs)
	local foeRoll = roll(duel.Foe.Powers[theirs], Duel.Stances[theirs].Beats == stanceId)
	duel.Round += 1
	local youWon = yourRoll >= foeRoll
	if youWon then
		duel.Wins += 1
		duel.Foe.HP = math.max(0, duel.Foe.HP - Duel.HitDamage)
	else
		duel.Losses += 1
		duel.You.HP = math.max(0, duel.You.HP - Duel.HitDamage)
	end
	table.insert(duel.Log, {
		Round = duel.Round, Yours = stanceId, Theirs = theirs, YourPower = math.floor(yourRoll), FoePower = math.floor(foeRoll), Won = youWon,
	})
	PlayerState.Feedback(player, "Clash")
	if duel.Wins >= Duel.WinsNeeded or duel.Losses >= Duel.WinsNeeded then
		finish(player, state, duel)
	end
	return true, nil
end

-- Resolves the rest of the duel with your strongest stance each exchange.
function DuelSystem.Quick(player, state)
	local duel = state.PendingDuel
	local guard = 0
	while duel and not duel.Done and guard < 10 do
		guard += 1
		DuelSystem.Exchange(player, state, bestStance(duel.You.Powers))
	end
	return duel ~= nil, nil
end

function DuelSystem.Close(state)
	if state.PendingDuel and state.PendingDuel.Done then
		state.PendingDuel = nil
		return true
	end
	return false
end

DuelSystem.Hooks = {
	YearTicks = { { Phase = "Systems", Order = 0, Run = function(player, state)
		if state.PendingDuel then
			DuelSystem.Quick(player, state)
			state.PendingDuel = nil
		end
	end } },
	Remotes = {
		DuelAction = {
			Cooldown = 0.25,
			Validate = function(action, stance)
				return action == "Quick" or action == "Close" or (action == "Stance" and type(stance) == "string")
			end,
			Handle = function(player, state, _, action, stance)
				if action == "Stance" then
					return DuelSystem.Exchange(player, state, stance)
				elseif action == "Quick" then
					return DuelSystem.Quick(player, state)
				end
				return DuelSystem.Close(state), nil
			end,
		},
	},
}

return DuelSystem
