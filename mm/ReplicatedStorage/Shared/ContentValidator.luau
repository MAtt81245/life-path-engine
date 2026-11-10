--[[
	ContentValidator: checks the active game pack (Configs/*) before the game runs.

	Detects: engine incompatibility, unknown or mis-wired modules, missing content
	modules, duplicate ids, missing references (stats, tiers, careers, relationship
	types, mastery prerequisites...), unknown buff / effect / requirement keys,
	inconsistent progression curves and content that depends on disabled modules.

	Validator.Run(overrides?, packId?) -> { Errors = {string}, Warnings = {string} }
	`overrides` maps a config name (or "GameManifest") to a replacement table, which
	lets tests validate broken content without touching the real modules.
	`packId` validates a GamePacks pack other than the active one.
	Validator.RunAll() validates the base Configs game and every pack.
]]

local Shared = script.Parent
local Content = require(Shared:WaitForChild("Content"))
local GamePack = require(Shared:WaitForChild("GamePack"))
local Requirements = require(Shared:WaitForChild("Requirements"))

local Validator = {}

Validator.ContentModules = {
	"PlayerStatsConfig", "TrainingConfig", "RealmsConfig", "TalentsConfig", "RacesConfig", "TitlesConfig",
	"MastersConfig", "MasteriesConfig", "StudiesAndCareerConfig", "RelationshipsConfig", "NpcBehaviorConfig",
	"ItemsConfig", "SamsaraUpgradesConfig", "MonetizationConfig", "RebirthPathsConfig",
	"WorldRegionsConfig", "ProgressionGatesConfig", "FamilyTreeConfig", "UIThemeConfig",
}

Validator.MaxEventOptions = 3 -- the event modal fits three choices

function Validator.Run(overrides, packId: (string | boolean)?)
	overrides = overrides or {}
	local report = { Errors = {}, Warnings = {} }
	local manifest = overrides.GameManifest
	if packId == nil then
		packId = Content.ActivePackId() or false
	end
	if not manifest then
		local ok, result = pcall(Content.Get, "GameManifest", packId)
		if not ok or type(result) ~= "table" then
			table.insert(report.Errors, ("%s.GameManifest: could not load (%s)"):format(tostring(packId or Content.BaseName), tostring(result)))
			return report
		end
		manifest = result
	end
	-- Problems inside content owned by a disabled module are counted, not reported: that
	-- content is never used, so a pack need not rewrite it (it is checked once enabled).
	local disabledScope: string? = nil
	local skipped = {}
	local function err(where: string, message: string)
		if disabledScope then
			skipped[disabledScope] = (skipped[disabledScope] or 0) + 1
			return
		end
		table.insert(report.Errors, where .. ": " .. message)
	end
	local function warnAt(where: string, message: string)
		table.insert(report.Warnings, where .. ": " .. message)
	end
	local modules = manifest.Modules or {}
	local counterNames = (manifest.Interface or {}).CounterNames or {}
	local function enabled(id: string?): boolean
		return id == nil or modules[id] == true
	end
	-- While checking a disabled module's own content, don't warn about its
	-- dependencies on other disabled modules (that content is never used).
	local insideDisabledModule = false
	-- Enters the scope of a known module's content; returns the scope to restore.
	local function scope(moduleId: string?): string?
		local previous = disabledScope
		if not previous and moduleId and GamePack.Modules[moduleId] and not enabled(moduleId) then
			disabledScope = moduleId
		end
		insideDisabledModule = disabledScope ~= nil
		return previous
	end
	local function unscope(previous: string?)
		disabledScope = previous
		insideDisabledModule = previous ~= nil
	end
	-- Follow-up references collected while checking effects; resolved after all events load.
	local followUpRefs = {}
	local currentEvent = nil

	------------------------------------------------------------------ manifest
	if type(manifest.Id) ~= "string" or manifest.Id == "" then
		err("GameManifest", "missing Id")
	end
	if not GamePack.IsEngineCompatible(manifest.EngineVersion) then
		err("GameManifest", ("targets engine %s but this engine is %s"):format(tostring(manifest.EngineVersion), GamePack.EngineVersion))
	end
	for id, flag in modules do
		if not GamePack.Modules[id] then
			err("GameManifest", ("unknown module '%s'"):format(tostring(id)))
		elseif type(flag) ~= "boolean" then
			err("GameManifest", ("module '%s' flag must be true or false"):format(id))
		end
	end
	for id, info in GamePack.Modules do
		if info.Tab and not GamePack.Pages[id] then
			err("EngineModules." .. id, "declares a Tab but has no Page ModuleScript inside its definition")
		end
		if modules[id] == nil and not info.Optional then
			warnAt("GameManifest", ("module '%s' not listed; treated as disabled"):format(id))
		end
		for _, dependency in info.Requires or {} do
			if enabled(id) and not enabled(dependency) then
				err("GameManifest", ("module '%s' requires module '%s'"):format(id, dependency))
			end
		end
	end

	for tabKey in (manifest.Interface and manifest.Interface.TabLabels) or {} do
		if not GamePack.TabKeys[tabKey] then
			err("GameManifest", ("Interface.TabLabels uses unknown tab '%s'"):format(tostring(tabKey)))
		end
	end

	------------------------------------------------------------------ game pack folder
	local knownModules = { GameManifest = true }
	for _, name in Validator.ContentModules do
		knownModules[name] = true
	end
	for _, pool in manifest.EventPools or {} do
		if type(pool.Config) == "string" then
			knownModules[pool.Config] = true
		end
	end
	knownModules.BigNum = true
	if packId then
		local chain, problem = Content.Chain(packId)
		if problem then
			err("GamePacks", problem)
		end
		local folder = chain[1]
		if folder and folder.Name == packId then
			if manifest.Id ~= packId then
				err("GamePacks." .. packId, ("folder name must match manifest Id '%s'"):format(tostring(manifest.Id)))
			end
			for _, child in folder:GetChildren() do
				if child:IsA("ModuleScript") and not knownModules[child.Name] then
					warnAt("GamePacks." .. packId, ("module '%s' is not a known content module and is never loaded"):format(child.Name))
				end
			end
		end
	end

	------------------------------------------------------------------ load content
	local content = {}
	local function load(name: string)
		if overrides[name] ~= nil then
			content[name] = overrides[name]
			return
		end
		local module = Content.Resolve(name, packId)
		if not module then
			err("GameManifest", "missing content module " .. name)
			return
		end
		local ok, result = pcall(require, module)
		if ok then
			content[name] = result
		else
			err(name, "failed to load: " .. tostring(result))
		end
	end
	for _, name in Validator.ContentModules do
		load(name)
	end
	local pools = {}
	for i, pool in manifest.EventPools or {} do
		if type(pool.Config) ~= "string" then
			err("GameManifest", ("EventPools[%d] has no Config"):format(i))
		else
			if pool.Module and not GamePack.Modules[pool.Module] then
				err("GameManifest", ("event pool %s uses unknown module '%s'"):format(pool.Config, pool.Module))
			end
			load(pool.Config)
			if content[pool.Config] then
				table.insert(pools, { Name = pool.Config, Module = pool.Module, Events = content[pool.Config].Events or {} })
			end
		end
	end
	for _, name in Validator.ContentModules do
		if not content[name] then
			return report -- cross-reference checks need every content module
		end
	end

	local Stats = content.PlayerStatsConfig
	local Training = content.TrainingConfig
	local Realms = content.RealmsConfig
	local Talents = content.TalentsConfig
	local Races = content.RacesConfig
	local Titles = content.TitlesConfig
	local Masters = content.MastersConfig
	local Masteries = content.MasteriesConfig
	local Studies = content.StudiesAndCareerConfig
	local Rel = content.RelationshipsConfig

	local tiers, careers = {}, {}
	for _, tier in Studies.Tiers or {} do tiers[tier.Id] = tier end
	for _, career in Studies.Careers or {} do careers[career.Id] = career end
	local ItemsCfg = content.ItemsConfig
	local itemsById = {}
	for _, item in ItemsCfg.Items or {} do
		if type(item.Id) == "string" then itemsById[item.Id] = item end
	end

	------------------------------------------------------------------ helpers
	local function uniqueIds(where: string, list)
		local seen = {}
		for i, item in list or {} do
			local id = item.Id
			if type(id) ~= "string" then
				err(where, ("entry #%d has no Id"):format(i))
			elseif seen[id] then
				err(where, ("duplicate id '%s'"):format(id))
			else
				seen[id] = true
			end
		end
		return seen
	end

	local function checkStatKeys(where: string, map, label: string)
		for stat in map or {} do
			if not Stats.Stats[stat] then
				err(where, ("unknown stat '%s' in %s"):format(tostring(stat), label))
			end
		end
	end

	local function checkProficiencyKeys(where: string, map, label: string)
		for key in map or {} do
			if not Training.Proficiencies[key] then
				err(where, ("unknown proficiency '%s' in %s"):format(tostring(key), label))
			end
		end
	end

	local function checkBuffs(where: string, buffs)
		for key, value in buffs or {} do
			if not GamePack.BuffKeys[key] then
				err(where, ("unknown buff '%s'"):format(tostring(key)))
			elseif key == "StatXp" then
				checkStatKeys(where, value, "StatXp")
			elseif key == "ProficiencyXp" then
				checkProficiencyKeys(where, value, "ProficiencyXp")
			elseif type(value) ~= "number" then
				err(where, ("buff '%s' must be a number"):format(key))
			end
		end
	end

	local function checkRequirement(where: string, req)
		if req == nil then
			return
		end
		for field in req do
			if not Requirements.Fields[field] then
				err(where, ("unknown requirement '%s'"):format(tostring(field)))
			else
				local owner = GamePack.RequirementModules[field]
				if owner and not enabled(owner) and not insideDisabledModule then
					warnAt(where, ("requirement '%s' depends on disabled module %s"):format(field, owner))
				end
			end
		end
		checkStatKeys(where, req.Stats, "requirement")
		checkProficiencyKeys(where, req.Proficiency, "requirement")
		for _, raceId in if type(req.Race) == "table" then req.Race elseif req.Race then { req.Race } else {} do
			if not Races.ById[raceId] then
				err(where, ("unknown race '%s' in requirement"):format(tostring(raceId)))
			end
		end
		for counter in req.Counters or {} do
			if not Requirements.CounterNames[counter] and not counterNames[counter] then
				warnAt(where, ("counter '%s' has no display name"):format(tostring(counter)))
			end
		end
		if req.MinRealm and not Realms.Realms[req.MinRealm] then
			err(where, ("MinRealm %s is out of range"):format(tostring(req.MinRealm)))
		end
		for _, field in { "Graduated", "Honors" } do
			if req[field] and not tiers[req[field]] then
				err(where, ("%s references unknown tier '%s'"):format(field, tostring(req[field])))
			end
		end
		for itemId, count in if type(req.Items) == "table" then req.Items else {} do
			if not itemsById[itemId] then
				err(where, ("Items requirement references unknown item '%s'"):format(tostring(itemId)))
			elseif type(count) ~= "number" or count < 1 then
				err(where, "required item counts must be >= 1")
			end
		end
		if type(req.Enrolled) == "string" and not tiers[req.Enrolled] then
			err(where, ("Enrolled references unknown tier '%s'"):format(req.Enrolled))
		end
		for _, field in { "HasRelationship", "NoRelationship" } do
			if req[field] and not Rel.Categories[req[field]] then
				err(where, ("%s references unknown category '%s'"):format(field, tostring(req[field])))
			end
		end
		if req.MinAge and req.MaxAge and req.MinAge > req.MaxAge then
			err(where, "MinAge is greater than MaxAge")
		end
	end

	local function checkEffects(where: string, effects)
		for key, value in effects or {} do
			local owner = GamePack.EffectKeys[key]
			if owner == nil then
				err(where, ("unknown effect '%s'"):format(tostring(key)))
			elseif type(owner) == "string" and not enabled(owner) and not insideDisabledModule then
				warnAt(where, ("effect '%s' depends on disabled module %s (ignored at runtime)"):format(key, owner))
			end
			if key == "Stats" then
				checkStatKeys(where, value, "Stats effect")
			elseif key == "Proficiency" then
				checkProficiencyKeys(where, value, "Proficiency effect")
			elseif key == "Career" and not careers[value] then
				err(where, ("Career effect references unknown career '%s'"):format(tostring(value)))
			elseif key == "TargetBecomes" and not Rel.Types[value] then
				err(where, ("TargetBecomes references unknown type '%s'"):format(tostring(value)))
			elseif key == "NewRelationship" and not (type(value) == "table" and Rel.Types[value.Type]) then
				err(where, "NewRelationship needs a known Type")
			elseif key == "Items" then
				for itemId, count in if type(value) == "table" then value else {} do
					if not itemsById[itemId] then
						err(where, ("Items effect references unknown item '%s'"):format(tostring(itemId)))
					elseif type(count) ~= "number" or count == 0 or count % 1 ~= 0 then
						err(where, "item counts must be non-zero whole numbers")
					end
				end
			elseif key == "FollowUp" then
				local list = if type(value) == "table" and value.Id ~= nil then { value } else value
				for _, followUp in if type(list) == "table" then list else {} do
					table.insert(followUpRefs, { Where = where, FollowUp = followUp, Parent = currentEvent })
				end
			elseif key == "Delayed" then
				local list = if type(value) == "table" and value.Effects ~= nil then { value } else value
				for _, delayed in if type(list) == "table" then list else {} do
					if type(delayed.InYears) ~= "number" or delayed.InYears < 1 then
						err(where, "Delayed needs InYears >= 1")
					end
					if type(delayed.Effects) ~= "table" then
						err(where, "Delayed needs an Effects table")
					else
						checkEffects(where .. ".Delayed", delayed.Effects)
					end
				end
			end
		end
	end

	------------------------------------------------------------------ stats & training
	for _, stat in Stats.Order or {} do
		if not Stats.Stats[stat] then
			err("PlayerStatsConfig", ("Order lists unknown stat '%s'"):format(stat))
		end
	end
	for role, stat in Stats.Roles or {} do
		if not Stats.Stats[stat] then
			err("PlayerStatsConfig", ("role %s uses unknown stat '%s'"):format(tostring(role), tostring(stat)))
		end
	end
	for level = 1, 100 do
		if Stats.XpForLevel(level) < Stats.XpForLevel(level - 1) or Stats.XpForLevel(level - 1) <= 0 then
			err("PlayerStatsConfig", ("XP curve must be positive and non-decreasing (level %d)"):format(level))
			break
		end
	end

	uniqueIds("TrainingConfig", Training.Actions)
	for _, key in Training.ProficiencyOrder or {} do
		if not Training.Proficiencies[key] then
			err("TrainingConfig", ("ProficiencyOrder lists unknown proficiency '%s'"):format(key))
		end
	end
	for _, action in Training.Actions or {} do
		local where = "TrainingConfig." .. tostring(action.Id)
		local previousScope = scope(action.Module)
		if type(action.Slots) ~= "number" or action.Slots < 1 or action.Slots % 1 ~= 0 then
			err(where, "Slots must be a whole number >= 1")
		end
		if action.MaxPerYear ~= nil and (type(action.MaxPerYear) ~= "number" or action.MaxPerYear < 1) then
			err(where, "MaxPerYear must be >= 1")
		end
		if action.Energy ~= nil then
			warnAt(where, "Energy is obsolete: actions cost yearly Slots now")
		end
		checkStatKeys(where, action.StatXp, "StatXp")
		if action.Proficiency and not Training.Proficiencies[action.Proficiency] then
			err(where, ("unknown proficiency '%s'"):format(tostring(action.Proficiency)))
		end
		if action.Module and not GamePack.Modules[action.Module] then
			err(where, ("unknown module '%s'"):format(tostring(action.Module)))
		end
		unscope(previousScope)
	end

	------------------------------------------------------------------ realms
	local previous
	for i, realm in Realms.Realms or {} do
		local where = "RealmsConfig." .. tostring(realm.Name or i)
		local base = realm.BaseRequirement or {}
		local magnitude = (base.e or 0) + math.log10(math.max(base.m or 1, 1e-9))
		if previous and magnitude <= previous then
			err(where, "BaseRequirement must increase with every realm")
		end
		previous = magnitude
		for _, field in { "BaseChance", "MajorChance" } do
			if type(realm[field]) ~= "number" or realm[field] < 0 or realm[field] > 1 then
				err(where, field .. " must be between 0 and 1")
			end
		end
		if realm.YearsPerLevel ~= nil and (type(realm.YearsPerLevel) ~= "number" or realm.YearsPerLevel < 0) then
			err(where, "YearsPerLevel must be a non-negative number")
		end
	end
	-- The first realms must be finishable within the base lifespan; later realms are
	-- meant to outlast it (they need lifespan legacies; see the balance campaign).
	if enabled("Cultivation") and Realms.GetLongevity then
		local minimumAge = 0
		for i = 1, math.min(3, #(Realms.Realms or {})) do
			local realm = Realms.Realms[i]
			minimumAge += (realm.YearsPerLevel or 0) * (Realms.SubLevels or 9)
			if minimumAge >= Realms.GetLongevity(i) then
				warnAt("RealmsConfig." .. tostring(realm.Name or i), ("stabilizing takes at least %d years but the lifespan is %d"):format(minimumAge, Realms.GetLongevity(i)))
			end
		end
	end

	------------------------------------------------------------------ talents, races, titles
	uniqueIds("TalentsConfig", Talents.List)
	for _, talent in Talents.List or {} do
		local where = "TalentsConfig." .. tostring(talent.Id)
		if not Talents.Rarities[talent.Rarity] then
			err(where, ("unknown rarity '%s'"):format(tostring(talent.Rarity)))
		end
		checkBuffs(where, talent.Buffs)
	end

	local raceIds = uniqueIds("RacesConfig", Races.List)
	if not raceIds[Races.Default] then
		err("RacesConfig", ("Default race '%s' does not exist"):format(tostring(Races.Default)))
	end
	local function checkSpin(where: string, spin, list)
		if not spin then
			return
		end
		for _, rarity in spin.RarityOrder or {} do
			local info = spin.Rarities and spin.Rarities[rarity]
			if not info or type(info.Weight) ~= "number" or info.Weight <= 0 then
				err(where .. ".Spin", ("rarity '%s' needs a positive Weight"):format(tostring(rarity)))
			end
		end
		for _, rule in spin.Pity or {} do
			if not table.find(spin.RarityOrder or {}, rule.Rarity) or type(rule.Every) ~= "number" or rule.Every < 1 then
				err(where .. ".Spin", ("bad pity rule for '%s'"):format(tostring(rule.Rarity)))
			end
		end
		for _, entry in list or {} do
			if not table.find(spin.RarityOrder or {}, entry.Rarity) then
				err(where .. "." .. tostring(entry.Id), ("unknown spin rarity '%s'"):format(tostring(entry.Rarity)))
			end
		end
	end
	checkSpin("RacesConfig", Races.Spin, Races.List)
	checkSpin("TalentsConfig", Talents.Spin, Talents.List)
	for _, race in Races.List or {} do
		local where = "RacesConfig." .. tostring(race.Id)
		checkStatKeys(where, race.BaseStats, "BaseStats")
		checkBuffs(where, race.Buffs)
	end

	uniqueIds("TitlesConfig", Titles.List)
	for _, title in Titles.List or {} do
		local where = "TitlesConfig." .. tostring(title.Id)
		checkRequirement(where, title.Requires)
		checkBuffs(where, title.Buffs)
	end

	------------------------------------------------------------------ masters & masteries
	uniqueIds("MastersConfig", Masters.List)
	scope("Masters")
	for _, master in Masters.List or {} do
		local where = "MastersConfig." .. tostring(master.Id)
		checkRequirement(where, master.Requires)
		if not master.Technique then
			err(where, "missing Technique")
		else
			checkBuffs(where .. ".Technique", master.Technique.Buffs)
		end
		if (master.TechniqueLoyalty or 0) > (Masters.MaxLoyalty or 100) then
			err(where, "TechniqueLoyalty exceeds MaxLoyalty")
		end
		for i, quest in master.Quests or {} do
			checkRequirement(("%s.Quests[%d]"):format(where, i), quest.Requires)
		end
	end
	unscope(nil)

	scope("Masteries")
	local nodeIds = {}
	for _, branch in Masteries.Branches or {} do
		for _, node in branch.Nodes or {} do
			local where = "MasteriesConfig." .. tostring(node.Id)
			if nodeIds[node.Id] then
				err("MasteriesConfig", ("duplicate node id '%s'"):format(tostring(node.Id)))
			end
			nodeIds[node.Id] = true
			if type(node.Cost) ~= "number" or node.Cost <= 0 then
				err(where, "Cost must be positive")
			end
			checkBuffs(where, node.Buffs)
		end
	end
	for _, branch in Masteries.Branches or {} do
		for _, node in branch.Nodes or {} do
			if node.Previous and not nodeIds[node.Previous] then
				err("MasteriesConfig." .. tostring(node.Id), ("Previous '%s' does not exist"):format(tostring(node.Previous)))
			end
		end
	end

	unscope(nil)

	------------------------------------------------------------------ studies & careers
	scope("Education")
	uniqueIds("StudiesAndCareerConfig.Tiers", Studies.Tiers)
	for _, tier in Studies.Tiers or {} do
		local where = "StudiesAndCareerConfig." .. tostring(tier.Id)
		if tier.Previous and not tiers[tier.Previous] then
			err(where, ("Previous tier '%s' does not exist"):format(tostring(tier.Previous)))
		end
		if tier.Auto and type(tier.StartAge) ~= "number" then
			err(where, "Auto tiers need a StartAge")
		end
		checkStatKeys(where, tier.YearlyXp, "YearlyXp")
		checkRequirement(where, tier.Requires)
	end
	unscope(nil)
	scope("Careers")
	uniqueIds("StudiesAndCareerConfig.Careers", Studies.Careers)
	for _, career in Studies.Careers or {} do
		checkRequirement("StudiesAndCareerConfig." .. tostring(career.Id), career.Requires)
	end
	unscope(nil)

	------------------------------------------------------------------ relationships
	for typeId, info in Rel.Types or {} do
		if not Rel.Categories[info.Category] then
			err("RelationshipsConfig." .. typeId, ("unknown category '%s'"):format(tostring(info.Category)))
		end
	end
	local familyHelp = Rel.FamilyHelp
	if type(familyHelp) ~= "table" or type(familyHelp.Brackets) ~= "table" or #familyHelp.Brackets == 0 then
		err("RelationshipsConfig.FamilyHelp", "needs a non-empty Brackets list")
	else
		local lastMaxAge = -1
		for i, bracket in familyHelp.Brackets do
			local where = ("RelationshipsConfig.FamilyHelp.Brackets[%d]"):format(i)
			if type(bracket.MaxAge) ~= "number" or bracket.MaxAge <= lastMaxAge then
				err(where, "MaxAge must increase from bracket to bracket")
			end
			if type(bracket.Min) ~= "number" or type(bracket.Max) ~= "number" or bracket.Min < 0 or bracket.Min > bracket.Max then
				err(where, "needs 0 <= Min <= Max")
			end
			lastMaxAge = bracket.MaxAge or lastMaxAge
		end
		if lastMaxAge ~= math.huge then
			warnAt("RelationshipsConfig.FamilyHelp", "the last bracket should use MaxAge = math.huge so every age is covered")
		end
	end
	uniqueIds("RelationshipsConfig.Interactions", Rel.Interactions)
	for _, interaction in Rel.Interactions or {} do
		local where = "RelationshipsConfig." .. tostring(interaction.Id)
		for category in interaction.Categories or {} do
			if not Rel.Categories[category] then
				err(where, ("unknown category '%s'"):format(tostring(category)))
			end
		end
		if interaction.ChanceStat and not Stats.Stats[interaction.ChanceStat] then
			err(where, ("unknown ChanceStat '%s'"):format(interaction.ChanceStat))
		end
	end

	------------------------------------------------------------------ items
	scope("Inventory")
	uniqueIds("ItemsConfig.Items", ItemsCfg.Items)
	local slots = ItemsCfg.Slots or {}
	for _, slot in ItemsCfg.SlotOrder or {} do
		if not slots[slot] then
			err("ItemsConfig", ("SlotOrder lists unknown slot '%s'"):format(tostring(slot)))
		end
	end
	for _, item in ItemsCfg.Items or {} do
		local where = "ItemsConfig." .. tostring(item.Id)
		if not (ItemsCfg.Categories or {})[item.Category] then
			err(where, ("unknown category '%s'"):format(tostring(item.Category)))
		end
		if item.Module and not GamePack.Modules[item.Module] then
			err(where, ("unknown module '%s'"):format(tostring(item.Module)))
		end
		for _, field in { "Price", "SellPrice" } do
			if item[field] ~= nil and (type(item[field]) ~= "number" or item[field] < 0) then
				err(where, field .. " must be a non-negative number")
			end
		end
		if item.MaxStack ~= nil and (type(item.MaxStack) ~= "number" or item.MaxStack < 1) then
			err(where, "MaxStack must be >= 1")
		end
		if not item.Use and not item.Equip and item.Price == nil and item.SellPrice == nil then
			warnAt(where, "can never be used, equipped, bought or sold")
		end
		if item.Use then
			if type(item.Use.Effects) ~= "table" then
				err(where, "Use needs an Effects table")
			else
				checkEffects(where .. ".Use", item.Use.Effects)
			end
			if item.Use.UsesPerYear ~= nil and (type(item.Use.UsesPerYear) ~= "number" or item.Use.UsesPerYear < 1) then
				err(where, "UsesPerYear must be >= 1")
			end
			if item.Use.MaxPerLife ~= nil and (type(item.Use.MaxPerLife) ~= "number" or item.Use.MaxPerLife < 1) then
				err(where, "MaxPerLife must be >= 1")
			end
			if type(item.Use.Effects) == "table" and (item.Use.Effects.Lifespan or 0) > 0 and not item.Use.MaxPerLife then
				warnAt(where, "a repeatable lifespan item without MaxPerLife allows endless life")
			end
		end
		if item.Equip then
			if not slots[item.Equip.Slot] then
				err(where, ("unknown equipment slot '%s'"):format(tostring(item.Equip.Slot)))
			end
			checkBuffs(where .. ".Equip", item.Equip.Buffs)
		end
		local previousScope = scope(item.Module)
		checkRequirement(where, item.Requires)
		unscope(previousScope)
	end
	local stocked = {}
	for _, itemId in ItemsCfg.Shop or {} do
		local item = itemsById[itemId]
		if not item then
			err("ItemsConfig.Shop", ("unknown item '%s'"):format(tostring(itemId)))
		elseif type(item.Price) ~= "number" then
			err("ItemsConfig.Shop", ("'%s' has no Price"):format(itemId))
		elseif stocked[itemId] then
			warnAt("ItemsConfig.Shop", ("'%s' is listed twice"):format(itemId))
		end
		stocked[itemId] = true
	end
	unscope(nil)

	------------------------------------------------------------------ events
	local eventIds, eventsById, eventPools = {}, {}, {}
	for _, pool in pools do
		for id, event in pool.Events do
			local where = pool.Name .. "." .. tostring(id)
			currentEvent = event
			if eventIds[id] then
				err(where, ("event id also used in %s (ids must be unique across pools)"):format(eventIds[id]))
			end
			eventIds[id] = pool.Name
			eventsById[id] = event
			eventPools[id] = pool
			-- Chain-only events are reached through FollowUp, so the yearly roll fields are optional.
			if not event.ChainOnly then
				if type(event.MinAge) ~= "number" or type(event.MaxAge) ~= "number" or event.MinAge > event.MaxAge then
					err(where, "needs MinAge <= MaxAge")
				end
				if type(event.Weight) ~= "number" or event.Weight < 0 or event.Weight > 1 then
					err(where, "Weight must be between 0 and 1")
				end
			end
			if event.Cooldown ~= nil and (type(event.Cooldown) ~= "number" or event.Cooldown < 1) then
				err(where, "Cooldown must be a number of years >= 1")
			end
			if event.Cooldown and not event.Repeatable then
				warnAt(where, "Cooldown has no effect on a non-repeatable event")
			end
			if event.Target and event.Target.Inherit and not event.ChainOnly then
				err(where, "Target.Inherit is only valid on ChainOnly events")
			end
			if event.MinRealm and not Realms.Realms[event.MinRealm] then
				err(where, "MinRealm is out of range")
			end
			if event.Module and not GamePack.Modules[event.Module] then
				err(where, ("unknown module '%s'"):format(tostring(event.Module)))
			end
			checkRequirement(where, event.Requires)

			local target = event.Target
			if target then
				if not enabled("Relationships") and enabled(pool.Module) then
					warnAt(where, "targets a relationship but Relationships is disabled (event never fires)")
				end
				if target.Category and not Rel.Categories[target.Category] then
					err(where, ("Target category '%s' does not exist"):format(tostring(target.Category)))
				end
				for _, typeId in target.Type or {} do
					if not Rel.Types[typeId] then
						err(where, ("Target type '%s' does not exist"):format(tostring(typeId)))
					end
				end
			end
			local function checkText(text: string?, label: string)
				if type(text) ~= "string" then
					return
				end
				if string.find(text, "{name}", 1, true) and not (target and not target.Create) then
					err(where, label .. " uses {name} without an existing-relationship Target")
				end
				if string.find(text, "{new}", 1, true) and not (target and target.Create) then
					err(where, label .. " uses {new} without Target = { Create = true }")
				end
			end
			checkText(event.Title, "Title")
			checkText(event.Text, "Text")

			local options = event.Options or {}
			if #options == 0 then
				err(where, "has no Options")
			elseif #options > Validator.MaxEventOptions then
				warnAt(where, ("has %d options; the event modal fits %d"):format(#options, Validator.MaxEventOptions))
			end
			for i, option in options do
				local optionWhere = ("%s.Options[%d]"):format(where, i)
				if type(option.Text) ~= "string" or type(option.Result) ~= "string" then
					err(optionWhere, "needs Text and Result")
				end
				if option.Chance ~= nil and type(option.FailResult) ~= "string" then
					err(optionWhere, "has a Chance but no FailResult")
				end
				if option.ChanceStat and not Stats.Stats[option.ChanceStat] then
					err(optionWhere, ("unknown ChanceStat '%s'"):format(option.ChanceStat))
				end
				checkRequirement(optionWhere, option.Requires)
				checkEffects(optionWhere, option.Effects)
				checkEffects(optionWhere .. ".Fail", option.FailEffects)
				checkText(option.Result, "Result")
				checkText(option.FailResult, "FailResult")
			end
		end
	end
	currentEvent = nil

	------------------------------------------------------------------ event chains
	local referenced = {}
	for _, ref in followUpRefs do
		local followUp, where = ref.FollowUp, ref.Where
		local child = type(followUp) == "table" and eventsById[followUp.Id]
		if not child then
			err(where, ("FollowUp references unknown event '%s'"):format(tostring(type(followUp) == "table" and followUp.Id)))
		else
			referenced[followUp.Id] = true
			if followUp.InYears ~= nil and (type(followUp.InYears) ~= "number" or followUp.InYears < 0) then
				err(where, "FollowUp InYears must be a number >= 0")
			end
			if followUp.Pool ~= nil and followUp.Pool ~= eventIds[followUp.Id] then
				err(where, ("FollowUp Pool '%s' does not contain '%s'"):format(tostring(followUp.Pool), followUp.Id))
			end
			local childPool = eventPools[followUp.Id]
			if not enabled(childPool.Module) or not enabled(child.Module) then
				warnAt(where, ("follow-up '%s' belongs to a disabled module and will be skipped"):format(followUp.Id))
			end
			if child.Target and child.Target.Inherit and ref.Parent and not ref.Parent.Target then
				warnAt(where, ("follow-up '%s' inherits a target but this event has none"):format(followUp.Id))
			end
		end
	end
	for id, event in eventsById do
		-- Trigger = "Travel" | "System": queued by a system (RegionSystem, SamsaraSystem).
		if event.Trigger ~= nil and event.Trigger ~= "Travel" and event.Trigger ~= "System" then
			err(eventIds[id] .. "." .. id, ("unknown Trigger '%s'"):format(tostring(event.Trigger)))
		end
		if event.Trigger and not event.ChainOnly then
			err(eventIds[id] .. "." .. id, "Trigger events must be ChainOnly (never rolled yearly)")
		end
		if event.ChainOnly and not referenced[id] and not event.Trigger then
			warnAt(eventIds[id] .. "." .. id, "ChainOnly event is never referenced by a FollowUp (unreachable)")
		end
	end

	------------------------------------------------------------------ NPC autonomy
	local Npc = content.NpcBehaviorConfig
	local stageIds = {}
	for _, stage in Npc.Stages or {} do
		stageIds[stage.Id] = true
		if type(stage.MaxAge) ~= "number" then
			err("NpcBehaviorConfig.Stages", ("stage '%s' needs a MaxAge"):format(tostring(stage.Id)))
		end
	end
	if type(Npc.Occupations) ~= "table" or #Npc.Occupations == 0 then
		err("NpcBehaviorConfig", "Occupations must be a non-empty list")
	end
	if type(Npc.IdleWeight) ~= "number" or Npc.IdleWeight < 0 then
		err("NpcBehaviorConfig", "IdleWeight must be a non-negative number")
	end
	local actionIds = uniqueIds("NpcBehaviorConfig.Actions", Npc.Actions)
	for _, action in Npc.Actions or {} do
		local where = "NpcBehaviorConfig." .. tostring(action.Id)
		if type(action.Weight) ~= "number" or action.Weight < 0 then
			err(where, "Weight must be a non-negative number")
		end
		for stage in action.Stages or {} do
			if not stageIds[stage] then err(where, ("unknown stage '%s'"):format(tostring(stage))) end
		end
		for category in action.Categories or {} do
			if not Rel.Categories[category] then err(where, ("unknown category '%s'"):format(tostring(category))) end
		end
		for typeId in action.Types or {} do
			if not Rel.Types[typeId] then err(where, ("unknown relationship type '%s'"):format(tostring(typeId))) end
		end
		for key in action.When or {} do
			if not GamePack.NpcConditionKeys[key] then err(where, ("unknown condition '%s'"):format(tostring(key))) end
		end
		for key in action.Effects or {} do
			if not GamePack.NpcEffectKeys[key] then err(where, ("unknown NPC effect '%s'"):format(tostring(key))) end
		end
		if action.TriggerEvent then
			local event = eventsById[action.TriggerEvent]
			if not event then
				err(where, ("TriggerEvent references unknown event '%s'"):format(tostring(action.TriggerEvent)))
			elseif enabled("NpcAutonomy") and (not enabled(eventPools[action.TriggerEvent].Module) or not enabled(event.Module)) then
				warnAt(where, ("TriggerEvent '%s' belongs to a disabled module"):format(action.TriggerEvent))
			end
		end
		if action.Memory and type(action.Memory.Text) ~= "string" then
			err(where, "Memory needs Text")
		end
		if action.Log and type(action.Log) ~= "string" then
			err(where, "Log must be a string")
		end
	end
	local function checkActionWeights(where: string, weights)
		for actionId in weights or {} do
			if not actionIds[actionId] then
				err(where, ("weights unknown action '%s'"):format(tostring(actionId)))
			end
		end
	end
	uniqueIds("NpcBehaviorConfig.Personalities", Npc.Personalities)
	for _, personality in Npc.Personalities or {} do
		checkActionWeights("NpcBehaviorConfig." .. tostring(personality.Id), personality.Weights)
	end
	uniqueIds("NpcBehaviorConfig.Goals", Npc.Goals)
	for _, goal in Npc.Goals or {} do
		local where = "NpcBehaviorConfig." .. tostring(goal.Id)
		checkActionWeights(where, goal.Weights)
		if goal.CompletedBy and not actionIds[goal.CompletedBy] then
			err(where, ("CompletedBy references unknown action '%s'"):format(tostring(goal.CompletedBy)))
		end
		for category in goal.Categories or {} do
			if not Rel.Categories[category] then err(where, ("unknown category '%s'"):format(tostring(category))) end
		end
	end

	for moduleId, count in skipped do
		warnAt("GameManifest", ("%d problem(s) in content of disabled module %s not reported (checked once it is enabled)"):format(count, moduleId))
	end
	return report
end

-- Validates the base game and every pack: { [packId or "Configs"] = report }.
function Validator.RunAll()
	local reports = { [Content.BaseName] = Validator.Run(nil, false) }
	for _, id in Content.ListPacks() do
		reports[id] = Validator.Run(nil, id)
	end
	return reports
end

function Validator.Format(report): string
	local lines = { ("%d error(s), %d warning(s)"):format(#report.Errors, #report.Warnings) }
	for _, message in report.Errors do
		table.insert(lines, "  ERROR   " .. message)
	end
	for _, message in report.Warnings do
		table.insert(lines, "  WARNING " .. message)
	end
	return table.concat(lines, "\n")
end

return Validator
