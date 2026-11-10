--[[
	CreationSystem: Life 1 pre-birth rolls. A brand-new save gets state.Creation =
	{ Spins = 3 }: free spins of the Wheel for the starting Bloodline (Lineages) and
	Family Legacy (Dynasty), shown on the client drum (Remotes.SpinResult) by
	ReplicatedFirst/IntroAndLoadingUI before the prologue. Only at age 0 of Life 1;
	"Done" (or the first birthday) closes it. With no bloodline or legacy wheel to roll
	(GamePack.CreationSpins) it is closed at birth and the client skips the screen.
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
	if #parts > 0 then
		PlayerState.Log(player, ("Before your first breath: %s."):format(table.concat(parts, ", ")), "realm")
	end
end

-- action = "Bloodline" | "Legacy" | "Done". Returns (ok, message, kind).
function CreationSystem.Roll(player, state, action: string)
	if not CreationSystem.Open(state) then
		return false, "The starter spins are only before your first life begins."
	end
	local creation = state.Creation
	if action == "Done" then
		creation.Done = true
		logResult(player, state)
		return true, nil
	elseif creation.Spins <= 0 then
		return false, "No free spins left."
	end
	creation.Pity = creation.Pity or {}
	local luck = PlayerState.GetSpinLuck(state)
	local entry, rarity, forced
	local wheels = GamePack.CreationSpins()
	if action == "Bloodline" then
		if not wheels.Bloodline then
			return false, PlayerState.Words("{RaceNamePlural} are fixed in this game.")
		end
		entry, rarity, forced = Gacha.Roll(Races.Spin, Races.List, creation.Pity, Rng, nil, luck)
		PlayerState.SetRace(state, entry.Id)
	elseif action == "Legacy" then
		if not wheels.Legacy then
			return false, "Family legacies are fixed in this game."
		end
		entry, rarity, forced = Gacha.Roll(Legacies.Spin, Legacies.List, creation.Pity, Rng, nil, luck)
		DynastySystem.ApplyLegacy(state, entry.Id)
	else
		return false
	end
	creation.Spins -= 1
	PlayerState.Fire(Remotes.SpinResult, player, {
		Kind = action, Id = entry.Id, Name = entry.Name, Rarity = rarity, Forced = forced, Speed = PlayerState.GetSpinSpeed(state), Creation = true,
	})
	-- No toast or journal line: the drum reveals the result; "Done" logs the final pick.
	return true, nil
end

-- No wheel to roll (both disabled or empty): the creation step is closed at birth,
-- so the client goes straight to the prologue.
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
				return action == "Bloodline" or action == "Legacy" or action == "Done"
			end,
			Handle = function(player, state, _, action)
				return CreationSystem.Roll(player, state, action)
			end,
		},
	},
}

return CreationSystem
