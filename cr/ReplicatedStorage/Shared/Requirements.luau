--[[
	Shared requirement checker used by masters, quests, titles, careers, education
	and event options. Works on the server state and on the client snapshot, which
	share the same field names.

	Spec (every listed field must pass):
		Stats = { Strength = 15 }, Proficiency = { Sword = 10 }, Counters = { Knowledge = 20 }
		MinAge, MaxAge, MinRealm, MinMoney, MinAlignment, MaxAlignment, MinStress
		Graduated = "HighSchool", Honors = "HighSchool", Enrolled = true | "TierId"
		Employed = true | false, HasMaster = true | false, MasterLoyalty = 100
		Friends = { Count = 5, Affection = 70 }, HasRelationship = "Partner", NoRelationship = "Partner"
		Flag = "Married", NotFlag = "Married", Items = { itemId = count }
]]

local Configs = script.Parent.Parent:WaitForChild("Configs")
local Content = require(script.Parent:WaitForChild("Content"))
local PackTheme = require(script.Parent:WaitForChild("PackTheme"))
local BigNum = require(Configs:WaitForChild("BigNum"))
local Stats = Content.Get("PlayerStatsConfig")
local Training = Content.Get("TrainingConfig")
local Studies = Content.Get("StudiesAndCareerConfig")
local Realms = Content.Get("RealmsConfig")
local Items = Content.Get("ItemsConfig")
local GamePack = require(script.Parent:WaitForChild("GamePack"))

local Requirements = {}

Requirements.CounterNames = {
	Knowledge = "Knowledge",
	Fights = "Fights won",
}
-- Packs name their own counters with GameManifest.Interface.CounterNames.
local interface = Content.Get("GameManifest").Interface
for key, name in interface and interface.CounterNames or {} do
	Requirements.CounterNames[key] = name
end

-- Every field Evaluate understands (used by Shared/ContentValidator).
Requirements.Fields = {
	Stats = true, Proficiency = true, Counters = true, MinAge = true, MaxAge = true, MinRealm = true,
	MinMoney = true, MinAlignment = true, MaxAlignment = true, MinStress = true, Graduated = true,
	Honors = true, Enrolled = true, Employed = true, HasMaster = true, MasterLoyalty = true, Friends = true,
	HasRelationship = true, NoRelationship = true, Flag = true, NotFlag = true, Items = true,
	Race = true,
}
-- Engine modules add their own fields (Shared/EngineModules `Requirements`).
for field in GamePack.RequirementEvaluators do
	Requirements.Fields[field] = true
end

local function levelOf(view, group: string, key: string): number
	local block = view[group]
	local entry = block and block[key]
	return entry and entry.Level or 0
end

local function tierName(id: string): string
	local tier = Studies.TiersById[id]
	return tier and tier.Name or id
end

local function hasRelationship(view, category: string): boolean
	for _, rel in view.Relationships or {} do
		if rel.Alive ~= false and rel.Category == category then
			return true
		end
	end
	return false
end

local function friendCount(view, minAffection: number): number
	local count = 0
	for _, rel in view.Relationships or {} do
		if rel.Alive ~= false and rel.Category == "Friend" and rel.Affection >= minAffection then
			count += 1
		end
	end
	return count
end

-- Keys of `map` missing from `order`, sorted (so their text is stable).
local function unlistedKeys(map, order): { string }
	local keys = {}
	for key in map do
		if not table.find(order, key) then
			table.insert(keys, tostring(key))
		end
	end
	table.sort(keys)
	return keys
end

-- Returns (allMet, items) where items = { { Met = bool, Text = string } }.
function Requirements.Evaluate(view, req)
	local items = {}
	if not req then
		return true, items
	end
	local function add(met, text: string)
		items[#items + 1] = { Met = met and true or false, Text = text }
	end

	if req.Stats then
		for _, stat in Stats.Order do
			local need = req.Stats[stat]
			if need then
				add(levelOf(view, "Stats", stat) >= need, ("%s %d"):format(Stats.Stats[stat].Name, need))
			end
		end
		-- Stats this pack does not define fail closed instead of being skipped.
		for _, stat in unlistedKeys(req.Stats, Stats.Order) do
			add(levelOf(view, "Stats", stat) >= req.Stats[stat], ("%s %d"):format(stat, req.Stats[stat]))
		end
	end
	if req.Proficiency then
		for _, key in unlistedKeys(req.Proficiency, Training.ProficiencyOrder) do
			add(levelOf(view, "Proficiencies", key) >= req.Proficiency[key], ("%s proficiency %d"):format(key, req.Proficiency[key]))
		end
		for _, key in Training.ProficiencyOrder do
			local need = req.Proficiency[key]
			if need then
				add(levelOf(view, "Proficiencies", key) >= need, ("%s proficiency %d"):format(Training.Proficiencies[key].Name, need))
			end
		end
	end
	if req.MinAge then add((view.Age or 0) >= req.MinAge, ("Age %d+"):format(req.MinAge)) end
	if req.MaxAge then add((view.Age or 0) <= req.MaxAge, ("Age %d or younger"):format(req.MaxAge)) end
	if req.MinRealm then add((view.RealmIndex or 1) >= req.MinRealm, Realms.Get(req.MinRealm).Name) end
	if req.MinMoney then add((view.Money or 0) >= req.MinMoney, "$" .. BigNum.from(req.MinMoney):ToString()) end
	if req.MinAlignment then add((view.Alignment or 0) >= req.MinAlignment, ("Alignment %+d or higher"):format(req.MinAlignment)) end
	if req.MaxAlignment then add((view.Alignment or 0) <= req.MaxAlignment, ("Alignment %+d or lower"):format(req.MaxAlignment)) end
	if req.MinStress then add((view.Stress or 0) >= req.MinStress, ("Stress %d+"):format(req.MinStress)) end
	if req.Graduated then add(view.Graduated and view.Graduated[req.Graduated], "Graduated " .. tierName(req.Graduated)) end
	if req.Honors then add(view.Honors and view.Honors[req.Honors], "Honors in " .. tierName(req.Honors)) end
	if req.Enrolled ~= nil then
		local edu = view.Education or {}
		if req.Enrolled == true then
			add(edu.Enrolled, "Enrolled in school")
		else
			add(edu.Enrolled and edu.Tier == req.Enrolled, "Enrolled in " .. tierName(req.Enrolled))
		end
	end
	if req.Employed ~= nil then
		local employed = view.Career ~= nil and view.Career.Id ~= nil
		add(employed == req.Employed, if req.Employed then "Employed" else "Unemployed")
	end
	if req.HasMaster ~= nil then
		local has = view.Master ~= nil and view.Master.Id ~= nil
		add(has == req.HasMaster, PackTheme.Words(if req.HasMaster then "{StudentName} of a {mentorName}" else "No {mentorName}"))
	end
	if req.MasterLoyalty then
		add(view.Master and view.Master.Id ~= nil and view.Master.Loyalty >= req.MasterLoyalty, PackTheme.Words("{MentorName} loyalty %d"):format(req.MasterLoyalty))
	end
	if req.Counters then
		for key, need in req.Counters do
			add(((view.Counters or {})[key] or 0) >= need, ("%s %d"):format(Requirements.CounterNames[key] or key, need))
		end
	end
	if req.Friends then
		local affection = req.Friends.Affection or 0
		add(friendCount(view, affection) >= req.Friends.Count, ("%d friends at %d+ affection"):format(req.Friends.Count, affection))
	end
	if req.HasRelationship then add(hasRelationship(view, req.HasRelationship), "Has a " .. string.lower(req.HasRelationship)) end
	if req.NoRelationship then add(not hasRelationship(view, req.NoRelationship), "No " .. string.lower(req.NoRelationship)) end
	if req.Items then
		local owned = (view.Inventory and view.Inventory.Items) or {}
		for itemId, need in req.Items do
			local item = Items.ById[itemId]
			local name = if item then item.Name else itemId
			add((owned[itemId] or 0) >= need, if need > 1 then ("%dx %s"):format(need, name) else "Has " .. name)
		end
	end
	if req.Race then
		local ids = if type(req.Race) == "table" then req.Race else { req.Race }
		local names = {}
		for _, id in ids do
			local race = Content.Get("RacesConfig").ById[id]
			table.insert(names, if race then race.Name else tostring(id))
		end
		add(table.find(ids, view.RaceId or view.Race) ~= nil, "Bloodline: " .. table.concat(names, " / "))
	end
	if req.Flag then add((view.Flags or {})[req.Flag], req.Flag) end
	if req.NotFlag then add(not (view.Flags or {})[req.NotFlag], "Not " .. string.lower(req.NotFlag)) end
	for field, evaluate in GamePack.RequirementEvaluators do
		if req[field] ~= nil then
			local met, text = evaluate(view, req[field])
			add(met, text or field)
		end
	end

	local allMet = true
	for _, item in items do
		if not item.Met then
			allMet = false
			break
		end
	end
	return allMet, items
end

function Requirements.Check(view, req): boolean
	return (Requirements.Evaluate(view, req))
end

-- Comma-separated text of the unmet items.
function Requirements.UnmetText(items): string
	local parts = {}
	for _, item in items do
		if not item.Met then
			table.insert(parts, item.Text)
		end
	end
	return table.concat(parts, ", ")
end

return Requirements
