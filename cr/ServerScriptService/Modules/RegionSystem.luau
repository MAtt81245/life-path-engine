--[[
	RegionSystem: the World module (WorldRegionsConfig, TravelEventsConfig).
	- Every new life is born in a starter region (weighted); SamsaraSystem may override
	  it (descendants are born where the family lives).
	- The region's modifiers are a per-life buff source (PlayerState.SetLifeBuff "Region"),
	  refreshed yearly (demonic bonus) and on travel; hazards cost health yearly.
	- TravelAction remote: move to a neighboring region for 1 action diamond + fee, then a
	  road encounter (Trigger = "Travel" events) is queued.
	Per-life data: state.Modules.World = { Region, Visited }.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Content = require(Shared:WaitForChild("Content"))
local GamePack = require(Shared:WaitForChild("GamePack"))
local Requirements = require(Shared:WaitForChild("Requirements"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local Engine = require(script.Parent:WaitForChild("LifeEventsEngine"))
local Rng = require(script.Parent:WaitForChild("Rng"))

local Regions = Content.Get("WorldRegionsConfig")
local TravelEvents = Content.Get("TravelEventsConfig")

local RegionSystem = {}

local function data(state)
	local info = PlayerState.ModuleData(state, "World", {})
	info.Visited = info.Visited or {}
	return info
end
RegionSystem.Data = data

function RegionSystem.Region(state)
	return Regions.Get(data(state).Region)
end

-- Region buffs plus the demonic bonus, merged with the shared buff rules.
local function regionBuffs(state, region)
	local out = {}
	local function add(buffs)
		for key, value in buffs or {} do
			local mode = GamePack.BuffDefs[key]
			if mode == "nested" then
				out[key] = out[key] or {}
				for sub, mult in value do
					out[key][sub] = (out[key][sub] or 1) * mult
				end
			elseif mode == "mult" then
				out[key] = (out[key] or 1) * value
			else
				out[key] = (out[key] or 0) + value
			end
		end
	end
	add(region.Buffs)
	if region.DemonicBuffs and state.Alignment <= Regions.DemonicAlignment then
		add(region.DemonicBuffs)
	end
	return out
end

function RegionSystem.RefreshBuffs(state)
	local region = RegionSystem.Region(state)
	PlayerState.SetLifeBuff(state, "Region", region.Name, regionBuffs(state, region))
end

function RegionSystem.SetRegion(state, regionId: string)
	local info = data(state)
	info.Region = Regions.Get(regionId).Id
	info.Visited[info.Region] = true
	RegionSystem.RefreshBuffs(state)
end

function RegionSystem.RollStarter(): string
	local total = 0
	for _, region in Regions.Regions do
		if region.Starter then
			total += region.StarterWeight or 1
		end
	end
	local roll = Rng:NextNumber() * total
	for _, region in Regions.Regions do
		if region.Starter then
			roll -= region.StarterWeight or 1
			if roll <= 0 then
				return region.Id
			end
		end
	end
	return Regions.Default
end

table.insert(PlayerState.NewLifeHooks, function(state)
	if GamePack.IsActive("World") then
		RegionSystem.SetRegion(state, RegionSystem.RollStarter())
	end
end)

table.insert(PlayerState.DeathRecorders, function(state, entry)
	if GamePack.IsActive("World") then
		local region = RegionSystem.Region(state)
		entry.Region, entry.RegionName = region.Id, region.Name
	end
end)

-- Why the character cannot travel to regionId now. Returns (reason?, fee).
function RegionSystem.Check(state, regionId: string): (string?, number)
	local target = Regions.ById[regionId]
	if not target then
		return "Unknown region.", 0
	end
	local here = RegionSystem.Region(state)
	local fee = target.TravelFee or 0
	if here.Id == target.Id then
		return "You are already there.", fee
	elseif state.Age < Regions.TravelMinAge then
		return ("You must be %d to travel alone."):format(Regions.TravelMinAge), fee
	elseif not Regions.AreNeighbors(here.Id, target.Id) then
		return ("No road leads from %s to %s."):format(here.Name, target.Name), fee
	end
	local met, items = Requirements.Evaluate(state, target.Requires)
	-- An alternative way in (e.g. age 16 and a sect toll instead of the realm).
	if not met and target.AltRequires and Requirements.Check(state, target.AltRequires) then
		met, fee = true, target.AltFee or fee
	end
	if not met then
		local alt = if target.AltRequires then (" (or age %d + %s toll)"):format(target.AltRequires.MinAge or 0, PlayerState.FormatMoney(target.AltFee or 0)) else ""
		return "Requires " .. Requirements.UnmetText(items) .. alt, fee
	elseif state.Actions < Regions.TravelSlots then
		return "No actions left this year. Advance the year.", fee
	elseif state.Money < fee then
		return ("The journey costs %s."):format(PlayerState.FormatMoney(fee)), fee
	end
	return nil, fee
end

-- Road encounter for a journey between two regions (nil when none fits).
function RegionSystem.PickEncounter(state, from: string, to: string): (string?, any)
	local candidates, total = {}, 0
	for id, event in TravelEvents.Events do
		if event.Trigger == "Travel" and GamePack.IsEnabled(event.Module) and Requirements.Check(state, event.Requires) then
			local onRoute = not event.Route or table.find(event.Route, from) ~= nil or table.find(event.Route, to) ~= nil
			local rel
			if event.Target then
				for _, candidate in state.Relationships do
					if candidate.Alive and candidate.Category == event.Target.Category then
						rel = candidate
						break
					end
				end
			end
			if onRoute and (not event.Target or rel) then
				table.insert(candidates, { Id = id, Rel = rel, Weight = event.Weight or 1 })
				total += event.Weight or 1
			end
		end
	end
	table.sort(candidates, function(a, b) return a.Id < b.Id end) -- reproducible with a seeded Rng
	local roll = Rng:NextNumber() * total
	for _, candidate in candidates do
		roll -= candidate.Weight
		if roll <= 0 then
			return candidate.Id, candidate.Rel
		end
	end
	return nil, nil
end

-- Returns (ok, message, kind).
function RegionSystem.Travel(player, state, regionId: string)
	local reason, fee = RegionSystem.Check(state, regionId)
	if reason then
		return false, reason
	end
	local from = RegionSystem.Region(state)
	local target = Regions.ById[regionId]
	state.Actions -= Regions.TravelSlots
	state.Money -= fee
	RegionSystem.SetRegion(state, target.Id)
	PlayerState.Log(player, ("You travel from %s to %s."):format(from.Name, target.Name), "event")
	local encounter, rel = RegionSystem.PickEncounter(state, from.Id, target.Id)
	if encounter and Engine.TriggerFor(state, encounter, rel) then
		Engine.PresentNext(player, state)
	end
	return true, ("Arrived in %s."):format(target.Name), "realm"
end

function RegionSystem.YearTick(player, state)
	RegionSystem.RefreshBuffs(state)
	local region = RegionSystem.Region(state)
	local hazard = region.Hazard
	if hazard and hazard.Health and not (hazard.ImmuneMaxAlignment and state.Alignment <= hazard.ImmuneMaxAlignment) then
		state.Health += hazard.Health
		if state.Age % 5 == 0 then
			PlayerState.Log(player, ("The air of %s gnaws at you (%d health)."):format(region.Name, hazard.Health), "bad")
		end
	end
end

RegionSystem.Hooks = {
	YearTicks = { { Phase = "Systems", Order = 15, Module = "World", Run = RegionSystem.YearTick } },
	Remotes = {
		TravelAction = {
			Module = "World",
			Cooldown = 0.5,
			Validate = function(action, regionId)
				return action == "Travel" and type(regionId) == "string" and Regions.ById[regionId] ~= nil
			end,
			Handle = function(player, state, _, _, regionId)
				return RegionSystem.Travel(player, state, regionId)
			end,
		},
	},
}

return RegionSystem
