--[[
	AscensionSystem: the endgame. At the peak realm (True Immortal 9, Realms.IsMaxed) the
	Breakthrough seal becomes "Ascend Beyond the Mortal Plane" (AscendAction remote).
	Ascending ends the life gloriously: AscensionKarma, the permanent Heavenly Ascendant
	title (Codex + flag every later life), and a Divine Legacy of DivineMult per
	ascension on all stat XP and Qi in every future life. The client plays the ending
	screen on the "Ascend" feedback cue.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
local GamePack = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GamePack"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))

local Realms = Content.Get("RealmsConfig")

local AscensionSystem = {}

AscensionSystem.AscensionKarma = 500
AscensionSystem.DivineMult = 1.1
AscensionSystem.TitleId = "heavenly_ascendant"

function AscensionSystem.CanAscend(state): (boolean, string?)
	if state.Dead then
		return false, "The dead cannot ascend."
	elseif not Realms.IsMaxed(state.RealmIndex, state.SubLevel) then
		return false, PlayerState.Term("AscendRequirement")
	end
	return true, nil
end

function AscensionSystem.Ascend(player, state)
	local ok, reason = AscensionSystem.CanAscend(state)
	if not ok then
		return false, reason
	end
	state.Ascensions = (state.Ascensions or 0) + 1
	PlayerState.CodexAdd(state, "Titles", AscensionSystem.TitleId)
	PlayerState.Log(player, PlayerState.Term("AscendLog"):format(state.Name, state.Ascensions), "realm")
	PlayerState.Feedback(player, "Ascend", { Name = state.Name, Ascensions = state.Ascensions, Karma = AscensionSystem.AscensionKarma })
	PlayerState.Die(player, PlayerState.Term("AscendDeath"), { Final = true })
	state.Karma += AscensionSystem.AscensionKarma
	return true, PlayerState.Term("AscendDone"), "realm"
end

-- Every later life carries the Divine Legacy and may claim the title.
table.insert(PlayerState.NewLifeHooks, function(state)
	local count = state.Ascensions or 0
	if count > 0 then
		local mult = AscensionSystem.DivineMult ^ count
		PlayerState.SetLifeBuff(state, "Divine", ("%s x%d"):format(PlayerState.Term("LegacyBuffName"), count), { AllStatXp = mult, QiMult = mult })
		state.Flags.HeavenlyAscendant = true
	end
end)

AscensionSystem.Hooks = {
	Remotes = {
		AscendAction = {
			Module = "Cultivation",
			Cooldown = 1,
			Handle = function(player, state)
				return AscensionSystem.Ascend(player, state)
			end,
		},
	},
}

return AscensionSystem
