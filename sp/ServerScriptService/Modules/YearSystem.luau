--[[
	YearSystem: simulates one year of a character's life.
	Used by AgingSystem (Advance Year button and auto-age loop) and by the tests.

	Each year: aging and energy refill, the "Systems" phase of registry year ticks
	(education/career, masters, relationships, NPC autonomy...), a buff refresh and
	the "Growth" phase (passive Qi...), then core health and mood, scheduled
	consequences, after-change checks (titles...), the death check and the yearly
	life events. Gameplay modules hook in through SystemRegistry; this file does
	not know them.
]]

local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local Engine = require(script.Parent:WaitForChild("LifeEventsEngine"))
local SystemRegistry = require(script.Parent:WaitForChild("SystemRegistry"))

local YearSystem = {}

YearSystem.HealthRegenPerYear = 0.05
YearSystem.OldAgeThreshold = 0.8
YearSystem.OldAgeDecay = 0.03
YearSystem.BaseStressRecovery = -6

-- Returns (advanced, reason).
function YearSystem.Advance(player, state): (boolean, string?)
	state = state or PlayerState.Get(player)
	if not state or state.Dead then
		return false
	end
	if state.PendingEvent or #state.EventQueue > 0 then
		if state.PendingEvent then
			Engine.SendPrompt(player, state)
		else
			Engine.PresentNext(player, state)
		end
		return false, "Resolve your pending life event first."
	end

	local buffs = PlayerState.GetBuffs(state)
	state.Age += 1
	PlayerState.StartYear(state, buffs)

	SystemRegistry.RunYear("Systems", player, state, buffs)
	buffs = PlayerState.GetBuffs(state)
	SystemRegistry.RunYear("Growth", player, state, buffs)

	-- Body and mood
	local maxHealth = PlayerState.GetMaxHealth(state, buffs)
	PlayerState.AddHealth(state, maxHealth * YearSystem.HealthRegenPerYear, buffs)
	PlayerState.AdjustMeter(state, "Stress", YearSystem.BaseStressRecovery + buffs.StressPerYear)
	PlayerState.AdjustMeter(state, "Happiness", (55 - state.Happiness) * 0.1 + buffs.HappinessPerYear)
	if state.Stress >= 85 then
		state.Health -= maxHealth * 0.05
		PlayerState.Log(player, "Crushing stress is damaging your health.", "bad")
	end
	if state.Money < 0 then
		PlayerState.AdjustMeter(state, "Happiness", -5)
	end
	if state.Age >= PlayerState.GetMaxLifespan(state, buffs) * YearSystem.OldAgeThreshold then
		state.Health -= maxHealth * YearSystem.OldAgeDecay
		if not state.WarnedOldAge then
			state.WarnedOldAge = true
			PlayerState.Log(player, "You feel the weight of the years. Your lifespan nears its end.", "bad")
		end
	end

	Engine.ProcessScheduled(player, state)
	SystemRegistry.AfterChange(player, state)
	if PlayerState.CheckDeath(player) then
		return true
	end
	if state.Age % 10 == 0 then
		PlayerState.Log(player, ("You turn %d."):format(state.Age), "info")
	end

	Engine.RollYear(player, state)
	PlayerState.Push(player)
	return true
end

return YearSystem
