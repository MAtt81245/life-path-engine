--[[
	CharacterSystem: who you are (CharacterConfig; Character module).

	Per-life data in ModuleData(state, "Character") (Snapshot.Modules.Character):
		Upbringing, Parents { Father, Mother = { Name, Attributes } }, Inherited { Stat = { Levels | Mult } },
		Hidden { { Id, Revealed, Fused } }, Counters, Personality { Slider = value },
		FusionAge, Fused { { Id, Name, Recipe? } }.
	state.FusionDiscovered (account-wide): recipe ids ever fused.

	Birth: upbringing (buff source "Upbringing"), parents' attributes and inheritance,
	4 hidden talents, personality at neutral. Hidden talents reveal through counters
	(SkillSystem.Count). Sliders move with training, routines, risky or moral choices,
	battles and minigames; past the threshold a side's buffs apply (source "Personality").
	CharacterAction remote: ("Fuse", traitA, traitB) with trait keys "T:<talentId>" or
	"H:<hiddenId>".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
local GamePack = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GamePack"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local TrainingSystem = require(script.Parent:WaitForChild("TrainingSystem"))
local SkillSystem = require(script.Parent:WaitForChild("SkillSystem"))
local ChronicleSystem = require(script.Parent:WaitForChild("ChronicleSystem"))
local Engine = require(script.Parent:WaitForChild("LifeEventsEngine"))
local Rng = require(script.Parent:WaitForChild("Rng"))

local Character = Content.Get("CharacterConfig")
local Stats = Content.Get("PlayerStatsConfig")
local Talents = Content.Get("TalentsConfig")

local CharacterSystem = {}

local function active(): boolean
	return GamePack.IsActive("Character")
end

-- Buff tables merged by mode (GamePack.BuffDefs): mult multiplies, add adds, nested per key.
local function merge(into, buffs)
	for key, value in buffs or {} do
		local mode = GamePack.BuffDefs[key]
		if mode == "nested" then
			into[key] = into[key] or {}
			for sub, mult in value do
				into[key][sub] = (into[key][sub] or 1) * mult
			end
		elseif mode == "mult" then
			into[key] = (into[key] or 1) * value
		else
			into[key] = (into[key] or 0) + value
		end
	end
	return into
end

local function weighted(list)
	local total = 0
	for _, entry in list do total += entry.Weight end
	local roll = Rng:NextNumber() * total
	for _, entry in list do
		roll -= entry.Weight
		if roll <= 0 then return entry end
	end
	return list[#list]
end

local function rollParent(name: string?)
	local parents = Character.Parents
	local attributes = {}
	for _, stat in Stats.Order do
		local mean = if parents.MagicStats[stat] then parents.MagicMean else parents.Mean
		attributes[stat] = math.max(0, math.floor(mean + Rng:NextNumber(-1, 1) * parents.Spread + 0.5))
	end
	return { Name = name or "Unknown", Attributes = attributes }
end

local function parentName(state, relType: string): string?
	for _, rel in state.Relationships or {} do
		if rel.Type == relType then
			return rel.Name
		end
	end
	return nil
end

function CharacterSystem.Data(state)
	local data = PlayerState.ModuleData(state, "Character", {})
	if not data.Upbringing then
		data.Upbringing = weighted(Character.Upbringings).Id
		data.Parents = { Father = rollParent(parentName(state, "Father")), Mother = rollParent(parentName(state, "Mother")) }
		data.Personality = {}
		for _, slider in Character.Sliders do
			data.Personality[slider.Id] = if slider.Unipolar then Character.UnipolarStart else 0
		end
		local pool = table.clone(Character.HiddenTalents)
		data.Hidden = {}
		for _ = 1, math.min(Character.HiddenSlots, #pool) do
			local pick = table.remove(pool, Rng:NextInteger(1, #pool))
			table.insert(data.Hidden, { Id = pick.Id, Revealed = false })
		end
		data.Counters, data.Fused, data.Inherited = {}, {}, {}
	end
	return data
end

-- Inheritance: Inherit stats from the parents' average, other stats train faster/slower.
function CharacterSystem.ApplyInheritance(state, grantLevels: boolean)
	local data = CharacterSystem.Data(state)
	local parents = Character.Parents
	local inherit, xp = {}, {}
	for _, stat in parents.Inherit do inherit[stat] = true end
	for _, stat in Stats.Order do
		local avg = (data.Parents.Father.Attributes[stat] + data.Parents.Mother.Attributes[stat]) / 2
		if inherit[stat] then
			local levels = math.floor(avg * parents.Share + 0.5)
			data.Inherited[stat] = { Levels = levels }
			if grantLevels and levels > 0 and state.Stats[stat] then
				state.Stats[stat].Level += levels
			end
		else
			local mean = if parents.MagicStats[stat] then parents.MagicMean else parents.Mean
			local mult = math.clamp(1 + (avg - mean) * parents.XpPerPoint, parents.MinXp, parents.MaxXp)
			data.Inherited[stat] = { Mult = math.floor(mult * 100 + 0.5) / 100 }
			xp[stat] = data.Inherited[stat].Mult
		end
	end
	PlayerState.SetLifeBuff(state, "Genetics", "Parents' genetics", { StatXp = xp })
end

function CharacterSystem.RefreshPersonality(state)
	local data = CharacterSystem.Data(state)
	local buffs = {}
	for _, slider in Character.Sliders do
		local value = data.Personality[slider.Id] or 0
		if value >= Character.Threshold and slider.RightBuffs then
			merge(buffs, slider.RightBuffs)
		elseif not slider.Unipolar and value <= -Character.Threshold and slider.LeftBuffs then
			merge(buffs, slider.LeftBuffs)
		end
	end
	PlayerState.SetLifeBuff(state, "Personality", "Personality", buffs)
end

-- Moves sliders; logs when a side is crossed. pushes = { Slider = delta }.
function CharacterSystem.Push(player, state, pushes)
	if not active() or not pushes then
		return
	end
	local data = CharacterSystem.Data(state)
	local crossed = false
	for id, delta in pushes do
		local slider = Character.SlidersById[id]
		if slider then
			local before = data.Personality[id] or 0
			local after = math.clamp(before + delta, if slider.Unipolar then 0 else -100, 100)
			data.Personality[id] = after
			local t = Character.Threshold
			if (before < t and after >= t) or (not slider.Unipolar and before > -t and after <= -t) then
				crossed = true
				PlayerState.Log(player, ("Your personality settles: you are %s."):format(string.lower(if after > 0 then slider.Right else slider.Left)), "realm")
			end
			if (before >= t and after < t) or (not slider.Unipolar and before <= -t and after > -t) then
				crossed = true
			end
		end
	end
	if crossed then
		CharacterSystem.RefreshPersonality(state)
	end
end

-- Hidden talents count up and reveal themselves.
function CharacterSystem.Count(player, state, counter: string, n: number)
	if not active() then
		return
	end
	local data = CharacterSystem.Data(state)
	data.Counters[counter] = (data.Counters[counter] or 0) + n
	for _, slot in data.Hidden do
		local def = Character.HiddenById[slot.Id]
		if def and not slot.Revealed and def.Counter == counter and data.Counters[counter] >= def.Need then
			slot.Revealed = true
			PlayerState.SetLifeBuff(state, "Hidden:" .. def.Id, def.Name, def.Buffs)
			PlayerState.Log(player, ("A hidden talent awakens: %s. %s"):format(def.Name, def.Description), "realm")
		end
	end
end

-- Traits that can be fused right now: { Key, Id, Name, Rarity }.
function CharacterSystem.Traits(state)
	local list = {}
	for _, id in state.Talents or {} do
		local talent = Talents.Get(id)
		if talent then
			table.insert(list, { Key = "T:" .. id, Id = id, Name = talent.Name, Rarity = talent.Rarity })
		end
	end
	for _, slot in CharacterSystem.Data(state).Hidden do
		local def = Character.HiddenById[slot.Id]
		if def and slot.Revealed and not slot.Fused then
			table.insert(list, { Key = "H:" .. def.Id, Id = def.Id, Name = def.Name, Rarity = def.Rarity })
		end
	end
	return list
end

local function consume(state, trait)
	if string.sub(trait.Key, 1, 2) == "T:" then
		local at = table.find(state.Talents, trait.Id)
		if at then table.remove(state.Talents, at) end
	else
		for _, slot in CharacterSystem.Data(state).Hidden do
			if slot.Id == trait.Id then slot.Fused = true end
		end
		PlayerState.SetLifeBuff(state, "Hidden:" .. trait.Id, nil, nil)
	end
end

function CharacterSystem.Fuse(player, state, keyA: string, keyB: string)
	local data = CharacterSystem.Data(state)
	if state.Age < Character.Fusion.MinAge then
		return false, ("Trait Fusion opens at age %d."):format(Character.Fusion.MinAge), "warn"
	elseif data.FusionAge == state.Age then
		return false, "One fusion a year.", "warn"
	elseif keyA == keyB then
		return false, "Pick two different traits.", "warn"
	end
	local a, b
	for _, trait in CharacterSystem.Traits(state) do
		if trait.Key == keyA then a = trait end
		if trait.Key == keyB then b = trait end
	end
	if not a or not b then
		return false, "You do not have those traits.", "warn"
	end
	local recipe = Character.Recipe(a.Id, b.Id)
	if recipe then
		consume(state, a)
		consume(state, b)
		data.FusionAge = state.Age
		table.insert(data.Fused, { Id = recipe.Id, Name = recipe.Name })
		PlayerState.SetLifeBuff(state, "Fusion:" .. recipe.Id, recipe.Name, recipe.Buffs)
		state.FusionDiscovered = state.FusionDiscovered or {}
		local fresh = not state.FusionDiscovered[recipe.Id]
		state.FusionDiscovered[recipe.Id] = true
		SkillSystem.Count(player, state, "fusions", 1)
		PlayerState.Log(player, ("Trait Fusion: %s + %s became %s%s."):format(a.Name, b.Name, recipe.Name, if fresh then " (new recipe!)" else ""), "realm")
		return true, ("Fused: %s"):format(recipe.Name), "good"
	end
	-- Wild fusion: same rarity, no recipe -> a random talent of the next rarity.
	if a.Rarity ~= b.Rarity then
		return false, "No recipe joins those two, and they are not the same rarity.", "warn"
	end
	local order = Talents.RarityOrder
	local at = table.find(order, a.Rarity) or 1
	local target = order[math.min(#order, at + 1)]
	local pool = {}
	for _, talent in Talents.List do
		if talent.Rarity == target and not table.find(state.Talents, talent.Id) then
			table.insert(pool, talent)
		end
	end
	if #pool == 0 then
		return false, "The fusion fizzles: nothing higher answers.", "warn"
	end
	local result = pool[Rng:NextInteger(1, #pool)]
	consume(state, a)
	consume(state, b)
	data.FusionAge = state.Age
	table.insert(state.Talents, result.Id)
	PlayerState.CodexAdd(state, "Talents", result.Id)
	table.insert(data.Fused, { Id = result.Id, Name = result.Name, Wild = true })
	SkillSystem.Count(player, state, "fusions", 1)
	PlayerState.Log(player, ("Wild Fusion: %s + %s became %s."):format(a.Name, b.Name, result.Name), "realm")
	return true, ("Wild fusion: %s"):format(result.Name), "good"
end

function CharacterSystem.OnNewLife(state)
	if not active() then
		return
	end
	local data = CharacterSystem.Data(state)
	local upbringing = Character.UpbringingsById[data.Upbringing]
	PlayerState.SetLifeBuff(state, "Upbringing", upbringing.Name, upbringing.Buffs)
	if upbringing.FamilyAffection then
		for _, rel in state.Relationships or {} do
			if rel.Category == "Family" then
				rel.Affection = math.clamp(rel.Affection + upbringing.FamilyAffection, 0, 100)
			end
		end
	end
	CharacterSystem.ApplyInheritance(state, true)
	CharacterSystem.RefreshPersonality(state)
end

table.insert(PlayerState.NewLifeHooks, CharacterSystem.OnNewLife)

-- A starter bloodline spin rebuilds the stats: inherited levels come back.
table.insert(PlayerState.StatResetHooks, function(state)
	local data = active() and state.Modules and state.Modules.Character
	if data and data.Inherited then
		for stat, entry in data.Inherited do
			if entry.Levels and state.Stats[stat] then
				state.Stats[stat].Level += entry.Levels
			end
		end
	end
end)

-- Saves from before the module: a character sheet without retroactive levels.
table.insert(PlayerState.LoadHooks, function(state)
	if active() and not (state.Modules and state.Modules.Character) then
		CharacterSystem.Data(state)
		local upbringing = Character.UpbringingsById[state.Modules.Character.Upbringing]
		PlayerState.SetLifeBuff(state, "Upbringing", upbringing.Name, upbringing.Buffs)
		CharacterSystem.ApplyInheritance(state, false)
	end
end)

table.insert(SkillSystem.CounterHooks, CharacterSystem.Count)

table.insert(TrainingSystem.ActionHooks, function(player, state, action)
	CharacterSystem.Push(player, state, if action.Id == "Relax" then Character.Pushes.Rest else Character.Pushes.Training)
	return nil
end)

table.insert(ChronicleSystem.OmenHooks, function(player, state)
	CharacterSystem.Count(player, state, "omens", 1)
	CharacterSystem.Push(player, state, Character.Pushes.Omen)
end)

-- Risky and moral choices shape who you are.
table.insert(Engine.AfterResolve, function(player, state, info)
	local option = info.Event.Options[info.OptionIndex]
	if option and option.Chance then
		CharacterSystem.Push(player, state, Character.Pushes.RiskyChoice)
	end
	local effects = option and (if info.Success then option.Effects else option.FailEffects)
	local alignment = effects and effects.Alignment
	if type(alignment) == "number" and alignment ~= 0 then
		CharacterSystem.Push(player, state, if alignment > 0 then Character.Pushes.GoodDeed else Character.Pushes.BadDeed)
	end
end)

CharacterSystem.Hooks = {
	-- Event effect: Personality = { Slider = delta }.
	Effects = {
		Personality = function(player, state, value)
			if type(value) == "table" then
				CharacterSystem.Push(player, state, value)
				return "your character shifts"
			end
			return nil
		end,
	},
	YearTicks = {
		{
			Phase = "Systems", Order = 6, Module = "Character",
			Run = function(player, state)
				local routine = ChronicleSystem.Data(state).Routine
				if state.Age >= 1 and routine then
					CharacterSystem.Push(player, state, Character.Pushes.Routine[routine])
					if routine == "Study" then
						CharacterSystem.Count(player, state, "study_years", 1)
					elseif routine == "Family" then
						CharacterSystem.Count(player, state, "family_years", 1)
					end
				end
			end,
		},
	},
	Remotes = {
		CharacterAction = {
			Module = "Character",
			Cooldown = 0.4,
			Validate = function(action, a, b)
				return action == "Fuse" and type(a) == "string" and type(b) == "string"
			end,
			Handle = function(player, state, _, _, a, b)
				return CharacterSystem.Fuse(player, state, a, b)
			end,
		},
	},
}

return CharacterSystem
