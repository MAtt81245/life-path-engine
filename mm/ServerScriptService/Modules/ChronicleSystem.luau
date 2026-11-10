--[[
	ChronicleSystem: the living chronicle around a life (ChronicleConfig).

	- World calendar: Life 1 is born in StartYear; each later life RebirthGap years after
	  the last death (state.WorldYear, kept across lives). Per-life data (BirthYear,
	  Gender, Routine, OmenDay) lives in PlayerState.ModuleData(state, "Chronicle") and
	  reaches the client as Snapshot.Modules.Chronicle; world year = BirthYear + Age.
	- Routine: one of ChronicleConfig.Routines is active and pays its Gains every year.
	- Today's Omen: one claim per real (UTC) day, across lives (state.OmenDay).

	ChronicleAction remote: ("Routine", id) | ("Omen").
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local Rng = require(script.Parent:WaitForChild("Rng"))

local Chronicle = Content.Get("ChronicleConfig")
local Stats = Content.Get("PlayerStatsConfig")

local ChronicleSystem = {}

-- fn(player, state) after Today's Omen is read (Character: hidden talents, personality).
ChronicleSystem.OmenHooks = {}

function ChronicleSystem.Data(state)
	local data = PlayerState.ModuleData(state, "Chronicle", {
		BirthYear = Chronicle.StartYear, Gender = Chronicle.Genders[1].Id, Routine = Chronicle.DefaultRoutine,
	})
	data.OmenDay = state.OmenDay
	return data
end

function ChronicleSystem.WorldYear(state): number
	return ChronicleSystem.Data(state).BirthYear + state.Age
end

-- Applies a Gains table. Returns readable parts ("+4 joy", "-4 stress", ...).
function ChronicleSystem.ApplyGains(player, state, gains, buffs): { string }
	local parts = {}
	if gains.Happiness then
		state.Happiness = math.clamp(state.Happiness + gains.Happiness, 0, 100)
		table.insert(parts, ("%+d joy"):format(gains.Happiness))
	end
	if gains.Stress then
		state.Stress = math.clamp(state.Stress + gains.Stress, 0, 100)
		table.insert(parts, ("%+d stress"):format(gains.Stress))
	end
	if gains.Money then
		state.Money += gains.Money
		table.insert(parts, ("+%d money"):format(gains.Money))
	end
	if gains.Health then
		PlayerState.AddHealth(state, gains.Health, buffs)
		table.insert(parts, ("+%d health"):format(gains.Health))
	end
	if gains.StatXp then
		local stat = gains.StatXp.Stat or (gains.StatXp.Role and Stats.Roles and Stats.Roles[gains.StatXp.Role])
		if stat and state.Stats[stat] then
			PlayerState.AddStatXp(player, state, stat, gains.StatXp.Amount, buffs)
			table.insert(parts, ("+%d %s XP"):format(gains.StatXp.Amount, Stats.Stats[stat].Short or stat))
		end
	end
	for key, category in { FamilyAffection = "Family", FriendAffection = "Friend" } do
		local amount = gains[key]
		if amount then
			local touched = false
			for _, rel in state.Relationships do
				if rel.Alive ~= false and rel.Category == category then
					rel.Affection = math.clamp(rel.Affection + amount, 0, 100)
					touched = true
				end
			end
			if touched then
				table.insert(parts, ("+%d %s bond"):format(amount, string.lower(category)))
			end
		end
	end
	return parts
end

function ChronicleSystem.SetRoutine(state, routineId: string): (boolean, string?)
	local routine = Chronicle.RoutinesById[routineId]
	if not routine then
		return false, "Unknown routine."
	end
	if state.Dead then
		return false, "The dead keep no routine."
	end
	ChronicleSystem.Data(state).Routine = routine.Id
	return true, ("Routine: %s."):format(Chronicle.RoutineName(routine, state.Age))
end

-- Today's Omen. Returns (ok, message, kind).
function ChronicleSystem.ClaimOmen(player, state, buffs, now: number?)
	local day = Chronicle.Day(now)
	if state.OmenDay == day then
		return false, "Today's omen has already spoken. Come back tomorrow.", "warn"
	end
	if state.Dead then
		return false, "The dead read no omens.", "warn"
	end
	local omen = Chronicle.Omens[Rng:NextInteger(1, #Chronicle.Omens)]
	state.OmenDay = day
	local data = ChronicleSystem.Data(state)
	data.LastOmen = omen.Id
	local parts = ChronicleSystem.ApplyGains(player, state, omen.Gains, buffs or PlayerState.GetBuffs(state))
	local text = ("Omen: %s (%s)"):format(omen.Text, table.concat(parts, ", "))
	PlayerState.Log(player, text, "good")
	for _, hook in ChronicleSystem.OmenHooks do
		hook(player, state)
	end
	return true, text, "good"
end

-- New life: born RebirthGap years after the last death, a gender and the default routine.
function ChronicleSystem.OnNewLife(state)
	local data = ChronicleSystem.Data(state)
	local gap = Chronicle.RebirthGap or { 0, 0 }
	data.BirthYear = if state.WorldYear then state.WorldYear + Rng:NextInteger(gap[1], gap[2]) else Chronicle.StartYear
	data.Gender = Chronicle.Genders[Rng:NextInteger(1, #Chronicle.Genders)].Id
	data.Routine = Chronicle.DefaultRoutine
	state.WorldYear = data.BirthYear
end
table.insert(PlayerState.NewLifeHooks, function(state)
	ChronicleSystem.OnNewLife(state)
end)

-- The year a life ends is where the next one starts counting from.
function ChronicleSystem.OnDeath(state, entry)
	local year = ChronicleSystem.WorldYear(state)
	state.WorldYear = year
	entry.WorldYear = year
end
table.insert(PlayerState.DeathRecorders, function(state, entry)
	ChronicleSystem.OnDeath(state, entry)
end)

ChronicleSystem.Hooks = {
	YearTicks = {
		{
			Phase = "Systems", Order = 5,
			Run = function(player, state, buffs)
				local data = ChronicleSystem.Data(state)
				state.WorldYear = data.BirthYear + state.Age
				local routine = Chronicle.RoutinesById[data.Routine]
				if routine and state.Age >= 1 then
					local parts = ChronicleSystem.ApplyGains(player, state, routine.Gains, buffs)
					data.LastRoutineGain = table.concat(parts, "  ")
				end
			end,
		},
	},
	Remotes = {
		ChronicleAction = {
			Cooldown = 0.3,
			Validate = function(action, id)
				return (action == "Routine" and type(id) == "string") or action == "Omen"
			end,
			Handle = function(player, state, buffs, action, id)
				if action == "Routine" then
					return ChronicleSystem.SetRoutine(state, id)
				end
				return ChronicleSystem.ClaimOmen(player, state, buffs)
			end,
		},
	},
}

return ChronicleSystem
