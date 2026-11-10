--[[
	GamePack: engine-side view of the active game pack (Configs/GameManifest).

	- EngineVersion and compatibility checks for packs.
	- Registry of engine gameplay modules, built from Shared/EngineModules: one
	  ModuleScript per module, so adding a module never edits this file. Fields:
		Id, Name, Description
		Requires = { moduleId }         hard dependencies
		Optional = true                 packs that do not list it are silently off
		EffectKeys = { key }            event effect keys the module owns
		RequirementFields = { field }   requirement fields the module owns
		Requirements = { Field = fn(view, value) -> (met, text) }
		                                new requirement fields and how to check them
		Buffs = { Key = "add" | "mult" | "nested" }  new buff keys
		Settings = { ... }              tuning shared by the server system and the page
		Tab = { Label, Order }          adds a UI tab; its page is a ModuleScript named
		                                "Page" inside the definition (Init(ctx, frame),
		                                Render(snapshot)); UIController builds the rest
	  Server behaviour (year ticks, remotes, effect handlers) lives on the system
	  modules themselves; see ServerScriptService/Modules/SystemRegistry.
	- Known buff, effect and requirement keys (the contracts content is written against).
]]

local Content = require(script.Parent:WaitForChild("Content"))
local Manifest = Content.Get("GameManifest")

local GamePack = {}

GamePack.EngineVersion = "0.3.0"
GamePack.Manifest = Manifest

-- Effect keys NPC actions may use (NpcBehaviorConfig, applied by NpcSystem).
GamePack.NpcEffectKeys = {
	Affection = true, PlayerHappiness = true, PlayerStress = true, PlayerMoney = true,
	SetOccupation = true, Retire = true, Married = true, Children = true, Away = true, Remove = true,
}

-- Conditions NPC actions may check in `When` (NpcSystem).
GamePack.NpcConditionKeys = {
	MinAge = true, MaxAge = true, MinAffection = true, MaxAffection = true, Occupation = true, Married = true, Away = true,
}

-- UI tab keys a manifest may relabel through Interface.TabLabels.
GamePack.TabKeys = {
	Training = true, Study = true, Masters = true, Social = true, Progression = true, Inventory = true, Journal = true, Lineage = true,
	Family = true,
}

-- Core contracts every game has (true = core, no owning module).
local CORE_EFFECTS = {
	"Stats", "Proficiency", "Health", "MaxHealth", "Happiness", "Stress", "Actions", "Money",
	"Karma", "Alignment", "Lifespan", "Counters", "Flags", "FollowUp", "Delayed",
}

-- Buff keys merged by PlayerState.GetBuffs and how they combine: "mult" starts at
-- 1 and multiplies, "add" starts at 0 and adds, "nested" is a table of multipliers.
GamePack.BuffDefs = {
	QiMult = "mult", PassiveQiMult = "mult", AllStatXp = "mult", LifespanMult = "mult", KarmaMult = "mult",
	SalaryMult = "mult", RelationshipMult = "mult", StudyMult = "mult",
	StatXp = "nested", ProficiencyXp = "nested",
	LifespanBonus = "add", BreakthroughBonus = "add", MaxHealthBonus = "add", ActionSlots = "add",
	HappinessPerYear = "add", StressPerYear = "add", SocialBonus = "add", KnowledgeBonus = "add", StartingMoney = "add",
}

GamePack.Modules = {} -- [id] = definition
GamePack.ModuleOrder = {} -- ids sorted by name
GamePack.EffectKeys = {} -- [key] = true (core) or owning module id
GamePack.RequirementModules = {} -- [field] = owning module id
GamePack.RequirementEvaluators = {} -- [field] = fn(view, value) -> (met, text)
GamePack.Pages = {} -- [id] = page ModuleScript of a module that declares a Tab

for _, key in CORE_EFFECTS do
	GamePack.EffectKeys[key] = true
end

local definitions = script.Parent:WaitForChild("EngineModules"):GetChildren()
table.sort(definitions, function(a, b) return a.Name < b.Name end)
for _, moduleScript in definitions do
	if moduleScript:IsA("ModuleScript") then
		local def = require(moduleScript)
		local id = def.Id or moduleScript.Name
		GamePack.Modules[id] = def
		table.insert(GamePack.ModuleOrder, id)
		for _, key in def.EffectKeys or {} do
			GamePack.EffectKeys[key] = id
		end
		for _, field in def.RequirementFields or {} do
			GamePack.RequirementModules[field] = id
		end
		for field, evaluate in def.Requirements or {} do
			GamePack.RequirementModules[field] = id
			GamePack.RequirementEvaluators[field] = evaluate
		end
		for key, mode in def.Buffs or {} do
			GamePack.BuffDefs[key] = mode
		end
		local page = moduleScript:FindFirstChild("Page")
		if def.Tab and page and page:IsA("ModuleScript") then
			GamePack.Pages[id] = page
			GamePack.TabKeys[id] = true -- manifests may relabel it via Interface.TabLabels
		end
	end
end

GamePack.BuffKeys = {}
for key in GamePack.BuffDefs do
	GamePack.BuffKeys[key] = true
end

function GamePack.IsEnabled(moduleId: string?): boolean
	if moduleId == nil then
		return true
	end
	return Manifest.Modules ~= nil and Manifest.Modules[moduleId] == true
end

-- Enabled and every module it requires is active too.
function GamePack.IsActive(moduleId: string?): boolean
	if not GamePack.IsEnabled(moduleId) then
		return false
	end
	local def = moduleId and GamePack.Modules[moduleId]
	for _, dependency in if def then def.Requires or {} else {} do
		if not GamePack.IsActive(dependency) then
			return false
		end
	end
	return true
end

-- True if any of the listed modules is enabled (an empty list counts as core).
function GamePack.AnyEnabled(moduleIds: { string }?): boolean
	if not moduleIds or #moduleIds == 0 then
		return true
	end
	for _, id in moduleIds do
		if GamePack.IsEnabled(id) then
			return true
		end
	end
	return false
end

-- Life 1 pre-birth wheels that have something to roll: a bloodline wheel (Lineages
-- module, RacesConfig.Spin with entries) and a family legacy wheel (Dynasty module,
-- FamilyLegacyConfig.Spin with entries). With neither, the creation screen is skipped.
-- Talent: an innate-talent card (TalentsConfig.Spin, Lineages) that only rides along
-- when the screen opens for one of the other two.
function GamePack.CreationSpins(): { Bloodline: boolean, Legacy: boolean, Talent: boolean, Any: boolean }
	local function wheel(moduleId: string, configName: string): boolean
		if not GamePack.IsActive(moduleId) or not Content.Resolve(configName) then
			return false
		end
		local config = Content.Get(configName)
		return config.Spin ~= nil and type(config.List) == "table" and #config.List > 0
	end
	local bloodline, legacy = wheel("Lineages", "RacesConfig"), wheel("Dynasty", "FamilyLegacyConfig")
	local talent = (bloodline or legacy) and wheel("Lineages", "TalentsConfig")
	return { Bloodline = bloodline, Legacy = legacy, Talent = talent, Any = bloodline or legacy }
end

function GamePack.EffectEnabled(effectKey: string): boolean
	local owner = GamePack.EffectKeys[effectKey]
	return owner == true or (type(owner) == "string" and GamePack.IsEnabled(owner))
end

local function parseVersion(version: string?): (number?, number?)
	if type(version) ~= "string" then
		return nil, nil
	end
	local major, minor = string.match(version, "^(%d+)%.(%d+)")
	return tonumber(major), tonumber(minor)
end

-- A pack is compatible when it targets the same major version and a minor
-- version this engine already provides.
function GamePack.IsEngineCompatible(packEngineVersion: string?, engineVersion: string?): boolean
	local packMajor, packMinor = parseVersion(packEngineVersion)
	local engineMajor, engineMinor = parseVersion(engineVersion or GamePack.EngineVersion)
	if not packMajor or not engineMajor then
		return false
	end
	return packMajor == engineMajor and packMinor <= engineMinor
end

return GamePack
