--[[
	SamsaraSystem: how and when the character is reborn (RebirthPathsConfig).
	- Paths: Direct Descendant (surname, 25% wealth, an heirloom, loving parents;
	  free if married), Stranger in the same era, the Ancient Primordial Era, or a
	  century later. Costs are paid on the Wheel (WheelSystem.Confirm).
	- Eras grant per-life buffs (state.LifeBuffs) and gate era events.
	- Echoes: people from the past life still live and can be met again
	  (event past_life_encounter, effect MeetEcho).
	- Legends: in the future the world remembers the previous self (LegendOfSelf).
	- Past-Life Glimpses: in childhood and youth a flashback of the previous life
	  recovers part of its best proficiency and attribute (Soul Retention scales it).
	Per-life data lives in PlayerState.ModuleData(state, "Samsara").
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
local GamePack = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GamePack"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local Rng = require(script.Parent:WaitForChild("Rng"))
local Engine = require(script.Parent:WaitForChild("LifeEventsEngine"))
local RegionSystem = require(script.Parent:WaitForChild("RegionSystem"))

local Paths = Content.Get("RebirthPathsConfig")
local Realms = Content.Get("RealmsConfig")
local Training = Content.Get("TrainingConfig")
local StatsConfig = Content.Get("PlayerStatsConfig")
local Masters = Content.Get("MastersConfig")
local Items = Content.Get("ItemsConfig")
local Regions = Content.Get("WorldRegionsConfig")

local SamsaraSystem = {}

-- The old-rival mentor arc (rival_mentor -> BecomeRivalDisciple -> rival_reckoning).
SamsaraSystem.Mentor = {
	YearlyProficiencyXp = 25, TechniqueYears = 2, ClimaxYears = 3, ClimaxProficiency = 20,
	TechniqueBuffs = function(key) return { ProficiencyXp = { [key] = 1.5 }, QiMult = 1.2 } end,
	NewRivalAge = 8,
}

local function data(state)
	return PlayerState.ModuleData(state, "Samsara", { Era = "Present", Glimpses = 0 })
end
SamsaraSystem.Data = data

function SamsaraSystem.Path(pathId: string?)
	return Paths.ById[pathId or ""] or Paths.ById[Paths.Default]
end

-- Karma this path costs right now (0 when its FreeIfFlag is set) and why it is refused.
function SamsaraSystem.PathCost(state, pathId: string?): (number, string?)
	local path = SamsaraSystem.Path(pathId)
	local cost = if path.FreeIfFlag and state.Flags and state.Flags[path.FreeIfFlag] then 0 else (path.Cost or 0)
	if state.Karma < cost then
		return cost, PlayerState.Words("%s needs %d {MetaCurrency}."):format(path.Name, cost)
	end
	return cost, nil
end

local function bestOf(block, order, names)
	local best
	for _, key in order do
		local entry = block and block[key]
		if entry and (not best or entry.Level > best.Level) then
			best = { Key = key, Name = names[key] and names[key].Name or key, Level = entry.Level }
		end
	end
	return best
end

-- Everything a rebirth path may carry over, read from the life that just ended.
function SamsaraSystem.Capture(state)
	local previous = data(state)
	local master = state.Master and state.Master.Id and Masters.ById[state.Master.Id]
	local region = state.Modules and state.Modules.World and state.Modules.World.Region
	local top = bestOf(state.Proficiencies, Training.ProficiencyOrder, Training.Proficiencies)
	local echoes = {}
	for _, rel in state.Relationships or {} do
		if rel.Alive and Paths.EchoTypes[rel.Type] then
			-- A rival who rose alongside you becomes a power of the next era.
			local powerful = rel.Type == "Rival" and (not GamePack.IsEnabled("Cultivation") or state.RealmIndex >= 2)
			table.insert(echoes, {
				Name = rel.Name, Type = rel.Type, AgeAtDeath = rel.Age, Affection = rel.Affection, Region = region,
				Powerful = powerful or nil, Signature = top and top.Key, SignatureName = top and top.Name,
			})
		end
	end
	local heirloom
	for _, itemId in (state.Inventory and state.Inventory.Equipped) or {} do
		heirloom = itemId
		break
	end
	return {
		Name = state.Name,
		Surname = string.match(state.Name or "", "(%S+)$"),
		Money = state.Money or 0,
		Era = previous.Era or "Present",
		Alignment = state.Alignment or 0,
		RealmName = Realms.Get(state.RealmIndex).Name,
		RealmIndex = state.RealmIndex,
		MasterName = master and master.Name,
		TopProficiency = bestOf(state.Proficiencies, Training.ProficiencyOrder, Training.Proficiencies),
		TopStat = bestOf(state.Stats, StatsConfig.Order, StatsConfig.Stats),
		Heirloom = heirloom,
		Region = region,
		Echoes = echoes,
	}
end

-- Applies the chosen path to the newborn (after PlayerState.Reincarnate).
function SamsaraSystem.Apply(player, state, previous, pathId: string?)
	local path = SamsaraSystem.Path(pathId)
	local info = data(state)
	info.Path = path.Id
	info.Era = if path.Era == "Same" then (previous.Era or "Present") else path.Era
	info.PastSelf = previous
	info.Echoes = if path.Echoes then previous.Echoes else {}
	info.Legend = if path.Legends then { Name = previous.Name, Alignment = previous.Alignment, Realm = previous.RealmName } else nil
	info.Glimpses = 0
	info.NewRivalAge = if GamePack.IsEnabled("Relationships") then SamsaraSystem.Mentor.NewRivalAge else nil
	local era = Paths.Eras[info.Era]
	PlayerState.SetLifeBuff(state, "Era", era and era.Name, era and era.Buffs)
	local descendant = path.WealthShare ~= nil or path.FamilyAffection ~= nil
	-- Descendants are born where the family lives; their family keeps its heirlooms.
	if descendant and previous.Region and GamePack.IsActive("World") then
		RegionSystem.SetRegion(state, previous.Region)
	end
	for _, heirloom in state.Heirlooms or {} do
		if heirloom.Holder == "Family" then
			heirloom.Lost = not descendant
		end
	end
	if path.WealthShare or path.Heirloom or path.FamilyAffection then
		local surname = previous.Surname
		if surname then
			local first = string.match(state.Name, "^(%S+)") or state.Name
			state.Name = first .. " " .. surname
		end
		for _, rel in state.Relationships do
			if rel.Category == "Family" then
				if surname then
					rel.Name = (string.match(rel.Name, "^(%S+)") or rel.Name) .. " " .. surname
				end
				if path.FamilyAffection then
					rel.Affection = Rng:NextInteger(path.FamilyAffection[1], path.FamilyAffection[2])
				end
			end
		end
		local inherited = math.max(0, math.floor((previous.Money or 0) * (path.WealthShare or 0)))
		state.Money += inherited
		local parts = { ("You are born into the %s family again."):format(surname or "same") }
		if inherited > 0 then
			table.insert(parts, "Inheritance: " .. PlayerState.FormatMoney(inherited) .. ".")
		end
		-- Without the Dynasty module the first equipped item passes down at birth.
		if path.Heirloom and not GamePack.IsActive("Dynasty") and previous.Heirloom and GamePack.IsEnabled("Inventory") and Items.ById[previous.Heirloom] then
			PlayerState.AddItem(state, previous.Heirloom, 1)
			table.insert(parts, "Heirloom: " .. Items.ById[previous.Heirloom].Name .. ".")
		end
		PlayerState.Log(player, table.concat(parts, " "), "realm")
	end
	if info.Era ~= "Present" then
		PlayerState.Log(player, ("You open your eyes in the %s."):format(era and era.Name or info.Era), "realm")
	end
end

----------------------------------------------------------------------
-- Past-Life Glimpses
----------------------------------------------------------------------

function SamsaraSystem.GlimpseOdds(state): (number, number)
	local bonus = PlayerState.UpgradeEffect(state, "GlimpseChance")
	local world = state.Modules and state.Modules.World
	local regionBonus = if world and world.Region and GamePack.IsEnabled("World") then (Regions.Get(world.Region).GlimpseBonus or 0) else 0
	return Paths.Glimpse.BaseChance + bonus + regionBonus, Paths.Glimpse.BaseStrength + bonus
end

-- Applies one glimpse now (also used by tests and the dev console).
function SamsaraSystem.Glimpse(player, state): string?
	local info = data(state)
	local past = info.PastSelf
	if not past then
		return nil
	end
	local _, strength = SamsaraSystem.GlimpseOdds(state)
	local gains = {}
	local prof = past.TopProficiency
	if prof and prof.Level > 0 and state.Proficiencies[prof.Key] then
		local levels = math.max(1, math.floor(prof.Level * strength))
		state.Proficiencies[prof.Key].Level = math.min(StatsConfig.MaxLevel or math.huge, state.Proficiencies[prof.Key].Level + levels)
		table.insert(gains, ("+%d %s"):format(levels, prof.Name))
	end
	local stat = past.TopStat
	if stat and stat.Level > 0 and state.Stats[stat.Key] then
		local levels = math.max(1, math.floor(stat.Level * strength))
		state.Stats[stat.Key].Level = math.min(StatsConfig.MaxLevel or math.huge, state.Stats[stat.Key].Level + levels)
		table.insert(gains, ("+%d %s"):format(levels, stat.Name))
	end
	if GamePack.IsEnabled("Cultivation") and (past.RealmIndex or 1) > state.RealmIndex then
		PlayerState.AddQi(state, PlayerState.GetRequirement(state):Mul(strength))
		table.insert(gains, PlayerState.Words("a surge of {EnergyName}"))
	end
	info.Glimpses = (info.Glimpses or 0) + 1
	local memory = ("you were %s, who reached %s"):format(past.Name or "someone else", past.RealmName or "old age")
	if past.MasterName then
		memory ..= " under " .. past.MasterName
	end
	if prof and prof.Level > 0 then
		memory ..= (" and mastered %s (level %d)"):format(prof.Name, prof.Level)
	end
	local text = ("Past-Life Glimpse: for a moment %s. (%s)"):format(memory, if #gains > 0 then table.concat(gains, ", ") else "a strange calm")
	PlayerState.Log(player, text, "realm")
	PlayerState.Notify(player, "A past life stirs in your memory...", "realm")
	return text
end

-- Disciple of the old rival: yearly lessons, their signature technique, then the climax.
local function mentorTick(player, state, info)
	local mentor = info.Mentor
	if not mentor or mentor.Done then
		return
	end
	local rules = SamsaraSystem.Mentor
	mentor.Years += 1
	if mentor.Signature and state.Proficiencies[mentor.Signature] then
		PlayerState.AddProficiencyXp(player, state, mentor.Signature, rules.YearlyProficiencyXp)
	end
	if mentor.Years == rules.TechniqueYears and mentor.Signature then
		mentor.Technique = ("%s's %s Art"):format(mentor.Name, mentor.SignatureName or "Secret")
		PlayerState.SetLifeBuff(state, "Technique", mentor.Technique, rules.TechniqueBuffs(mentor.Signature))
		PlayerState.Log(player, ("%s teaches you their signature technique: %s."):format(mentor.Name, mentor.Technique), "realm")
	end
	local skilled = mentor.Signature and state.Proficiencies[mentor.Signature] and state.Proficiencies[mentor.Signature].Level >= rules.ClimaxProficiency
	if not mentor.Climax and mentor.Years >= rules.ClimaxYears and ((info.Glimpses or 0) > 0 or skilled) then
		mentor.Climax = true
		Engine.Schedule(state, { Id = "rival_reckoning", InYears = 0 })
	end
end

function SamsaraSystem.YearTick(player, state)
	local info = data(state)
	if info.NewRivalAge and state.Age >= info.NewRivalAge then
		info.NewRivalAge = nil
		local rel = PlayerState.CreateRelationship(state, "Rival", { Age = math.max(0, state.Age + Rng:NextInteger(-1, 1)), Affection = 20 })
		if rel then
			PlayerState.Log(player, ("%s, a child your age, decides you are their rival."):format(rel.Name), "event")
		end
	end
	mentorTick(player, state, info)
	local rules = Paths.Glimpse
	if state.Lives < 2 or not info.PastSelf or state.Age < rules.MinAge or state.Age > rules.MaxAge or (info.Glimpses or 0) >= rules.MaxPerLife then
		return
	end
	local chance = SamsaraSystem.GlimpseOdds(state)
	if Rng:NextNumber() < chance then
		SamsaraSystem.Glimpse(player, state)
	end
end

----------------------------------------------------------------------
-- Event effects
----------------------------------------------------------------------

-- MeetEcho = bonus affection: the next living echo enters your life again.
local function here(state): string?
	local world = state.Modules and state.Modules.World
	return world and world.Region
end

-- Index of the first echo living in the current region (optionally a powerful rival).
local function echoHere(state, info, powerfulRival: boolean)
	local region = here(state)
	for i, echo in info.Echoes or {} do
		local near = echo.Region == nil or region == nil or echo.Region == region
		local isMentor = echo.Type == "Rival" and echo.Powerful == true
		if near and isMentor == powerfulRival then
			return i
		end
	end
	return nil
end

local function meetEcho(_player, state, value)
	local info = data(state)
	while info.Echoes and #info.Echoes > 0 do
		local index = echoHere(state, info, false) or echoHere(state, info, true)
		if not index then
			return nil
		end
		local echo = table.remove(info.Echoes, index)
		local age = (echo.AgeAtDeath or 30) + state.Age
		if age <= 100 then
			local bonus = if type(value) == "number" then value else 0
			local rel = PlayerState.CreateRelationship(state, if echo.Type == "Rival" then "Rival" else "Friend", {
				Name = echo.Name, Age = age, Affection = math.clamp(math.floor((echo.Affection or 50) * 0.6) + bonus, 0, 100),
			})
			if rel then
				PlayerState.Remember(state, rel, ("Was your %s in a past life"):format(string.lower(echo.Type)), 1)
				return ("%s, now %d, was your %s in a past life"):format(echo.Name, age, string.lower(echo.Type))
			end
			return nil
		end
	end
	return nil
end

-- LegendOfSelf: the world remembers who you were (future rebirths).
local function legendOfSelf(_player, state)
	local legend = data(state).Legend
	if not legend then
		return nil
	end
	if legend.Alignment <= -50 then
		state.Karma += 2
		PlayerState.AdjustMeter(state, "Stress", 8)
		return ("They still fear %s, the Demon Sovereign of %s"):format(legend.Name, legend.Realm)
	elseif legend.Alignment >= 50 then
		state.Karma += 4
		PlayerState.AdjustMeter(state, "Happiness", 10)
		return ("Temples honor %s, the saint who reached %s"):format(legend.Name, legend.Realm)
	end
	state.Karma += 1
	return ("Old stories mention %s, a wanderer who reached %s"):format(legend.Name, legend.Realm)
end

-- BecomeRivalDisciple: your past-life rival does not recognize you and takes you in.
local function becomeRivalDisciple(_player, state)
	local info = data(state)
	local index = echoHere(state, info, true)
	if not index or (info.Mentor and not info.Mentor.Done) then
		return nil
	end
	local echo = table.remove(info.Echoes, index)
	local age = (echo.AgeAtDeath or 30) + state.Age
	info.Mentor = { Name = echo.Name, Signature = echo.Signature, SignatureName = echo.SignatureName, Years = 0 }
	if GamePack.IsEnabled("Relationships") then
		local rel = PlayerState.CreateRelationship(state, "Friend", { Name = echo.Name, Age = age, Affection = 55 })
		if rel then
			info.Mentor.RelId = rel.Id
			PlayerState.Remember(state, rel, PlayerState.Words("Took you as a {studentName}, never knowing who you were"), 1)
		end
	end
	return PlayerState.Words("%s, now %d, accepts you as a {studentName} and does not recognize you"):format(echo.Name, age)
end

-- RivalReckoning = "Revenge" | "Defeat" | "Legacy": the end of the mentor arc.
local function rivalReckoning(_player, state, outcome)
	local info = data(state)
	local mentor = info.Mentor
	if not mentor or mentor.Done then
		return nil
	end
	mentor.Done, mentor.Outcome = true, outcome
	local rel = mentor.RelId and PlayerState.FindRelationship(state, mentor.RelId)
	local key = mentor.Signature
	if outcome == "Revenge" then
		state.Karma += 5
		PlayerState.AdjustMeter(state, "Happiness", 15)
		if key and state.Proficiencies[key] then
			state.Proficiencies[key].Level = math.min(StatsConfig.MaxLevel or math.huge, state.Proficiencies[key].Level + 5)
		end
		if rel then
			PlayerState.RemoveRelationship(state, rel.Id)
		end
		return ("%s learns who you were a heartbeat before falling. The old feud is over"):format(mentor.Name)
	elseif outcome == "Defeat" then
		if rel then
			PlayerState.SetRelationshipType(rel, "Rival")
			rel.Affection = 5
		end
		PlayerState.SetLifeBuff(state, "Technique", nil, nil)
		return ("%s laughs: two lifetimes, and you still lose. They cast you out"):format(mentor.Name)
	end
	state.Money += 3000
	state.Alignment = math.clamp(state.Alignment + 10, -100, 100)
	if key and state.Proficiencies[key] then
		state.Proficiencies[key].Level = math.min(StatsConfig.MaxLevel or math.huge, state.Proficiencies[key].Level + 8)
	end
	if rel then
		rel.Affection = 95
	end
	return ("%s names you heir to their legacy, never knowing who you once were"):format(mentor.Name)
end

SamsaraSystem.Hooks = {
	YearTicks = { { Phase = "Growth", Order = 30, Module = "Samsara", Run = SamsaraSystem.YearTick } },
	Effects = { MeetEcho = meetEcho, LegendOfSelf = legendOfSelf, BecomeRivalDisciple = becomeRivalDisciple, RivalReckoning = rivalReckoning },
}

return SamsaraSystem
