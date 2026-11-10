--[[
	CreationSystem: Life 1 pre-birth rolls. A brand-new save gets state.Creation =
	{ Spins = 3 }: free spins of the Wheel for the starting Bloodline (Lineages) and
	Family Legacy (Dynasty), shown on the client drum (Remotes.SpinResult) by
	ReplicatedFirst/IntroAndLoadingUI before the prologue. Only at age 0 of Life 1;
	"Done" (or the first birthday) closes it. With no bloodline or legacy wheel to roll
	(GamePack.CreationSpins) it is closed at birth and the client skips the screen.

	Birth screen (2.0): a third card rolls an innate talent (talent slot 1). "Quick" spends
	the free spins left at once and is born straight away (no prologue). Reroll rolls every
	card together: "RerollMeta" pays MonetizationConfig.BirthRerollMetaCost in the meta
	currency; the BirthReroll developer product calls CreationSystem.Reroll after purchase.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Content = require(Shared:WaitForChild("Content"))
local GamePack = require(Shared:WaitForChild("GamePack"))
local Gacha = require(Shared:WaitForChild("Gacha"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local DynastySystem = require(script.Parent:WaitForChild("DynastySystem"))
local Rng = require(script.Parent:WaitForChild("Rng"))

local Races = Content.Get("RacesConfig")
local Legacies = Content.Get("FamilyLegacyConfig")
local Talents = Content.Get("TalentsConfig")
local Monetization = Content.Get("MonetizationConfig")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local CreationSystem = {}

function CreationSystem.Open(state): boolean
	local creation = state.Creation
	return creation ~= nil and not creation.Done and state.Lives == 1 and state.Age == 0 and not state.Dead
end

-- The journal keeps only what you were finally born with (rerolls are not logged).
local function logResult(player, state)
	local wheels = GamePack.CreationSpins()
	local parts = {}
	if wheels.Bloodline then
		local race = Races.Get(state.Race)
		table.insert(parts, ("%s %s"):format(Gacha.RarityName(Races.Spin, race.Rarity), race.Name))
	end
	if wheels.Legacy then
		local legacy = Legacies.Get(state.Legacy)
		table.insert(parts, ("%s %s"):format(Gacha.RarityName(Legacies.Spin, legacy.Rarity), legacy.Name))
	end
	local talent = state.Creation.Talent and Talents.Get(state.Creation.Talent)
	if talent then
		table.insert(parts, ("%s %s"):format(Gacha.RarityName(Talents.Spin, talent.Rarity), talent.Name))
	end
	if #parts > 0 then
		PlayerState.Log(player, ("Before your first breath: %s."):format(table.concat(parts, ", ")), "realm")
	end
end

-- One card rolled and applied (no spin cost). Returns the result, or nil if that wheel
-- is off in this pack.
local function rollCard(state, kind: string)
	local creation = state.Creation
	creation.Pity = creation.Pity or {}
	local luck = PlayerState.GetSpinLuck(state)
	local wheels = GamePack.CreationSpins()
	local entry, rarity, forced
	if kind == "Bloodline" and wheels.Bloodline then
		entry, rarity, forced = Gacha.Roll(Races.Spin, Races.List, creation.Pity, Rng, nil, luck)
		PlayerState.SetRace(state, entry.Id)
	elseif kind == "Legacy" and wheels.Legacy then
		entry, rarity, forced = Gacha.Roll(Legacies.Spin, Legacies.List, creation.Pity, Rng, nil, luck)
		DynastySystem.ApplyLegacy(state, entry.Id)
	elseif kind == "Talent" and wheels.Talent then
		creation.TalentPity = creation.TalentPity or {}
		entry, rarity, forced = Gacha.Roll(Talents.Spin, Talents.List, creation.TalentPity, Rng, nil, luck)
		state.Talents[1] = entry.Id -- the birth talent fills slot 1 for this life
		creation.Talent = entry.Id
		PlayerState.CodexAdd(state, "Talents", entry.Id)
		state.Health = PlayerState.GetMaxHealth(state)
	else
		return nil
	end
	return { Kind = kind, Id = entry.Id, Name = entry.Name, Rarity = rarity, Forced = forced }
end

CreationSystem.Cards = { "Bloodline", "Legacy", "Talent" }

-- Every card at once (paid reroll). Returns true when the creation screen was open.
function CreationSystem.Reroll(player, state): boolean
	if not CreationSystem.Open(state) then
		return false
	end
	local results = {}
	for _, kind in CreationSystem.Cards do
		local result = rollCard(state, kind)
		if result then
			table.insert(results, result)
		end
	end
	PlayerState.Fire(Remotes.SpinResult, player, { Kind = "Reroll", Results = results, Creation = true, Speed = PlayerState.GetSpinSpeed(state) })
	return true
end

-- action = "Bloodline" | "Legacy" | "Talent" | "Quick" | "RerollMeta" | "Done".
-- Returns (ok, message, kind).
function CreationSystem.Roll(player, state, action: string)
	if not CreationSystem.Open(state) then
		return false, "The starter spins are only before your first life begins."
	end
	local creation = state.Creation
	if action == "Done" then
		creation.Done = true
		logResult(player, state)
		return true, nil
	elseif action == "Quick" then
		-- Be born now: free spins left are rolled instantly, round-robin over the cards.
		local i = 0
		while creation.Spins > 0 and i < 12 do
			i += 1
			if rollCard(state, CreationSystem.Cards[(i - 1) % #CreationSystem.Cards + 1]) then
				creation.Spins -= 1
			end
		end
		creation.Quick = true
		creation.Done = true
		logResult(player, state)
		return true, nil
	elseif action == "RerollMeta" then
		local cost = Monetization.BirthRerollMetaCost or 30
		if state.Karma < cost then
			return false, PlayerState.Words("You need %d {MetaCurrency} to reroll."):format(cost), "warn"
		end
		state.Karma -= cost
		CreationSystem.Reroll(player, state)
		return true, nil
	elseif creation.Spins <= 0 then
		return false, "No free spins left."
	end
	if action ~= "Bloodline" and action ~= "Legacy" and action ~= "Talent" then
		return false
	end
	local result = rollCard(state, action)
	if not result then
		return false, if action == "Bloodline" then PlayerState.Words("{RaceNamePlural} are fixed in this game.")
			elseif action == "Legacy" then "Family legacies are fixed in this game."
			else "Innate talents are fixed in this game."
	end
	creation.Spins -= 1
	result.Speed = PlayerState.GetSpinSpeed(state)
	result.Creation = true
	PlayerState.Fire(Remotes.SpinResult, player, result)
	-- No toast or journal line: the card reveals the result; "Done" logs the final pick.
	return true, nil
end

-- No wheel to roll (both disabled or empty, e.g. the modern_life pack): the creation
-- step is closed at birth, so the client goes straight to the prologue.
table.insert(PlayerState.NewLifeHooks, function(state)
	if state.Creation and not state.Creation.Done and not GamePack.CreationSpins().Any then
		state.Creation.Done = true
	end
end)

CreationSystem.Hooks = {
	Remotes = {
		CreationAction = {
			Cooldown = 0.5,
			Validate = function(action)
				return action == "Bloodline" or action == "Legacy" or action == "Talent" or action == "Quick"
					or action == "RerollMeta" or action == "Done"
			end,
			Handle = function(player, state, _, action)
				return CreationSystem.Roll(player, state, action)
			end,
		},
	},
}

return CreationSystem
