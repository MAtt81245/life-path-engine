--[[
	HistorySystem: the world that outlives you (HistoryConfig; core, always on).

	Account-wide state.World (Snapshot.World): { History = { { Year, Text, Kind } },
	Ruler, Destroyed = { regionId = rebuildYear } }. Record() is how other systems
	write deeds (boss statues, thrones, raids, taught spells) into it.
	Per-life ModuleData(state, "Birth"): { Class, Anomaly, Rebirth }.

	Birth: a random soul rolls a social class; an heir keeps the family's. Every birth
	may roll one anomaly (never chosen). Death screen: the Reincarnate remote's action
	"Organic" ("Heir" | "Random") rebirths through WheelSystem (Descendant / Stranger
	path), free. (Gameplay remotes refuse the dead; the Wheel's remote is theirs.)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
local GamePack = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GamePack"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local ChronicleSystem = require(script.Parent:WaitForChild("ChronicleSystem"))
local Rng = require(script.Parent:WaitForChild("Rng"))

local History = Content.Get("HistoryConfig")

local HistorySystem = {}

function HistorySystem.World(state)
	state.World = state.World or {}
	local world = state.World
	world.History = world.History or {}
	world.Destroyed = world.Destroyed or {}
	return world
end

function HistorySystem.Birth(state)
	return PlayerState.ModuleData(state, "Birth", {})
end

local function year(state): number
	local ok, value = pcall(ChronicleSystem.WorldYear, state)
	return if ok then value else (state.WorldYear or 1000)
end

-- Writes one line into the World Chronicle (kept across every life).
function HistorySystem.Record(state, text: string, kind: string?)
	local world = HistorySystem.World(state)
	table.insert(world.History, { Year = year(state), Text = text, Kind = kind or "world" })
	while #world.History > History.MaxEntries do
		table.remove(world.History, 1)
	end
end

local function regions()
	local list = {}
	if GamePack.IsActive("World") then
		for _, region in Content.Get("WorldRegionsConfig").List or {} do
			table.insert(list, region)
		end
	end
	return list
end

local function weighted(list)
	local total = 0
	for _, entry in list do total += entry.Weight or 1 end
	local roll = Rng:NextNumber() * total
	for _, entry in list do
		roll -= entry.Weight or 1
		if roll <= 0 then return entry end
	end
	return list[#list]
end

-- One world event (the yearly roll, or forced by tests).
function HistorySystem.WorldEvent(player, state, eventId: string?)
	local event = nil
	for _, entry in History.Events do
		if entry.Id == eventId then event = entry end
	end
	event = event or weighted(History.Events)
	local world = HistorySystem.World(state)
	local list = regions()
	local a = list[Rng:NextInteger(1, math.max(1, #list))]
	local b = list[Rng:NextInteger(1, math.max(1, #list))]
	local text = event.Text
	if event.Succession then
		world.Ruler = PlayerState.RandomPersonName(nil, state)
	end
	text = text:gsub("{region}", a and a.Name or "the capital"):gsub("{regionB}", b and b.Name or "the frontier"):gsub("{ruler}", world.Ruler or "A new ruler")
	if event.Destroy and a then
		world.Destroyed[a.Id] = year(state) + Rng:NextInteger(History.RebuildYears[1], History.RebuildYears[2])
	end
	HistorySystem.Record(state, text, event.Id)
	-- Living there hurts.
	local here = state.Modules and state.Modules.World and state.Modules.World.Region
	if a and here == a.Id and not state.Dead then
		if event.Stress then PlayerState.AdjustMeter(state, "Stress", event.Stress) end
		if event.Health then PlayerState.AddHealth(state, event.Health) end
		if event.Money then state.Money += event.Money end
	end
	PlayerState.Log(player, "World: " .. text, "realm")
	return text
end

-- Birth: social class (heirs keep the family's) and a possible anomaly.
function HistorySystem.OnNewLife(state)
	local birth = HistorySystem.Birth(state)
	local heir = state.RebirthChoice == "Heir"
	birth.Rebirth = state.RebirthChoice or (if state.Lives <= 1 then "First" else "Wheel")
	state.RebirthChoice = nil
	local class = (heir and History.ClassesById[state.FamilyClass or ""]) or weighted(History.Classes)
	birth.Class = class.Id
	state.FamilyClass = class.Id
	if not heir then
		state.Money = math.max(0, state.Money - 50 + class.Money)
	end
	PlayerState.SetLifeBuff(state, "Class", class.Name .. " birth", class.Buffs)
	-- Anomalies (rolled, never chosen).
	state.StatCaps = {}
	birth.Anomaly = nil
	local mult = if PlayerState.OwnsPass(state, "SecretBirth") then History.SecretBirthMult else 1
	local roll, edge = Rng:NextNumber(), 0
	for _, anomaly in History.Anomalies do
		edge += anomaly.Chance * mult
		if roll < edge then
			HistorySystem.ApplyAnomaly(state, anomaly.Id)
			break
		end
	end
	-- Destroyed cities rise again.
	local world = HistorySystem.World(state)
	for regionId, rebuilt in world.Destroyed do
		if year(state) >= rebuilt then
			world.Destroyed[regionId] = nil
		end
	end
end

function HistorySystem.ApplyAnomaly(state, anomalyId: string)
	local anomaly = History.AnomaliesById[anomalyId]
	if not anomaly then return end
	HistorySystem.Birth(state).Anomaly = anomaly.Id
	state.StatCaps = table.clone(anomaly.StatCaps or {})
	for stat, cap in state.StatCaps do
		if state.Stats[stat] then
			state.Stats[stat].Level = math.min(state.Stats[stat].Level, cap)
		end
	end
	for stat, levels in anomaly.Levels or {} do
		if state.Stats[stat] then
			state.Stats[stat].Level += levels
		end
	end
	PlayerState.SetLifeBuff(state, "Anomaly", anomaly.Name, anomaly.Buffs)
	state.Health = math.min(state.Health, PlayerState.GetMaxHealth(state))
end

table.insert(PlayerState.NewLifeHooks, HistorySystem.OnNewLife)

-- A starter bloodline spin rebuilds stats: the anomaly's ceilings still hold.
table.insert(PlayerState.StatResetHooks, function(state)
	for stat, cap in state.StatCaps or {} do
		if state.Stats[stat] then
			state.Stats[stat].Level = math.min(state.Stats[stat].Level, cap)
		end
	end
end)

-- The death screen's two organic choices.
function HistorySystem.Rebirth(player, state, choice: string)
	if not state.Dead then
		return false, "Only the dead choose how to return.", "warn"
	end
	local WheelSystem = require(script.Parent:WaitForChild("WheelSystem"))
	local wheel = WheelSystem.Wheel(state)
	local region = state.Modules and state.Modules.World and state.Modules.World.Region
	if choice == "Heir" then
		local oldest
		for _, rel in state.Relationships or {} do
			if rel.Alive and rel.Type == "Child" and (not oldest or rel.Age > oldest.Age) then oldest = rel end
		end
		wheel.Heir = oldest and oldest.Id
		wheel.HeirMode = oldest and "TakeOver" or nil
		wheel.Path = if GamePack.IsEnabled("Samsara") then "Descendant" else nil
	elseif choice == "Random" then
		wheel.Heir, wheel.HeirMode = nil, nil
		wheel.Path = if GamePack.IsEnabled("Samsara") then "Stranger" else nil
	else
		return false
	end
	state.RebirthChoice = choice
	local ok, message = WheelSystem.Confirm(player, state, true)
	if not ok then
		state.RebirthChoice = nil
		return false, message
	end
	-- An heir grows up in the family's city.
	if choice == "Heir" and region and GamePack.IsActive("World") then
		require(script.Parent:WaitForChild("RegionSystem")).SetRegion(state, region)
	end
	return true, nil
end

HistorySystem.Hooks = {
	YearTicks = {
		{
			Phase = "Systems", Order = 8,
			Run = function(player, state)
				local world = HistorySystem.World(state)
				for regionId, rebuilt in world.Destroyed do
					if year(state) >= rebuilt then
						world.Destroyed[regionId] = nil
						local region = Content.Get("WorldRegionsConfig").Get(regionId)
						HistorySystem.Record(state, ("%s rises again from the ashes."):format(region and region.Name or regionId), "rebuilt")
					end
				end
				if Rng:NextNumber() < History.YearlyChance then
					HistorySystem.WorldEvent(player, state)
				end
			end,
		},
	},
}

return HistorySystem
