--[[
	ArcanaSystem: magic (ArcanaConfig; Arcana module, requires Skills).

	Per-life data in ModuleData(state, "Arcana") (Snapshot.Modules.Arcana):
		Affinity { Element = 0-100 }, Special { School = true }, Mastery { SpellId = { Level, Casts } },
		Mana, ManaBonus, MaxMana, CollapseAge, SilentCasting, SilentTrialAge, ForgeAge,
		Custom { grimoireId = true } (forged this life), Learned { grimoireId = true }.
	state.Grimoire (account-wide, saved): forged spells { Id, Name, Elements, Shape, Rank,
	Creator, Life, Year, Taught }.

	ArcanaAction remote: ("Practice", spellId) | ("SilentTrial", hits) |
	("Forge", { Elements, Shape, Rank, Name }) | ("Learn", grimoireId).
	Practice costs mana, not actions: the pool refills every year, so mana is the limit.
	Forged names are filtered with TextService; a refused name falls back to a generated one.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
local GamePack = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GamePack"))
local CombatMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatMath"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local SkillSystem = require(script.Parent:WaitForChild("SkillSystem"))
local Rng = require(script.Parent:WaitForChild("Rng"))

local Arcana = Content.Get("ArcanaConfig")

local ArcanaSystem = {}

local function rollAffinities(data)
	data.Affinity = {}
	local birth = Arcana.BirthAffinity
	for _, element in Arcana.Elements do
		data.Affinity[element.Id] = Rng:NextInteger(birth.Min, birth.Max)
	end
	local favored = Arcana.Elements[Rng:NextInteger(1, #Arcana.Elements)]
	data.Affinity[favored.Id] += birth.FavoredBonus
	data.Favored = favored.Id
end

function ArcanaSystem.Data(state)
	local data = PlayerState.ModuleData(state, "Arcana", {})
	if not data.Affinity then
		rollAffinities(data)
	end
	data.Special = data.Special or {}
	data.Mastery = data.Mastery or {}
	data.Custom = data.Custom or {}
	data.Learned = data.Learned or {}
	data.ManaBonus = data.ManaBonus or 0
	data.MaxMana = ArcanaSystem.MaxMana(state, data)
	data.Mana = math.min(data.Mana or data.MaxMana, data.MaxMana)
	return data
end

function ArcanaSystem.MaxMana(state, data): number
	local base = CombatMath.MaxMana(PlayerState.StatLevels(state), (data or ArcanaSystem.Data(state)).ManaBonus)
	return math.floor(base * (PlayerState.GetBuffs(state).MaxManaMult or 1)) -- 0 with the Heavenly Restriction
end

-- Max Mana growth from outside (Mana Collapse, Catch the Light).
function ArcanaSystem.AddManaBonus(state, amount: number)
	local data = ArcanaSystem.Data(state)
	data.ManaBonus += amount
	data.MaxMana = ArcanaSystem.MaxMana(state, data)
end

function ArcanaSystem.OpenAge(state): number
	return Content.Get("SkillsConfig").OpenAge("Magic", PlayerState.GetTrainingAgeOffset(state))
end

-- Special schools open with the Knowledge skill.
function ArcanaSystem.RefreshSchools(player, state)
	local data = ArcanaSystem.Data(state)
	local knowledge = SkillSystem.Level(state, "Knowledge")
	for _, school in Arcana.SpecialSchools do
		if not data.Special[school.Id] and knowledge >= school.Knowledge then
			data.Special[school.Id] = true
			data.Affinity[school.Id] = math.max(data.Affinity[school.Id] or 0, Arcana.SpecialStartAffinity)
			PlayerState.Log(player, ("Your studies open a hidden school of magic: %s."):format(school.Name), "realm")
		end
	end
end

function ArcanaSystem.ElementOpen(state, elementId: string): boolean
	local element = Arcana.ElementsById[elementId]
	return element ~= nil and (not element.Special or ArcanaSystem.Data(state).Special[elementId] == true)
end

-- A forged spell from the Family Grimoire as a spell record (nil if unknown).
function ArcanaSystem.GrimoireSpell(state, id: string)
	for _, entry in state.Grimoire or {} do
		if entry.Id == id then
			return entry
		end
	end
	return nil
end

-- Spells this life can cast: base spells it qualifies for plus forged / learned ones.
function ArcanaSystem.Known(state): { [string]: boolean }
	local data = ArcanaSystem.Data(state)
	local known = {}
	for id, spell in Arcana.SpellsById do
		if ArcanaSystem.ElementOpen(state, spell.Element) and (data.Affinity[spell.Element] or 0) >= spell.Affinity then
			known[id] = true
		end
	end
	for id in data.Custom do known[id] = true end
	for id in data.Learned do known[id] = true end
	return known
end

-- (damage or heal, mana cost, chantless, name) of a known spell.
function ArcanaSystem.SpellPower(state, spellId: string, buffs)
	buffs = buffs or PlayerState.GetBuffs(state)
	local data = ArcanaSystem.Data(state)
	local levels = PlayerState.StatLevels(state)
	local skills = SkillSystem.Levels(state)
	local spell = Arcana.SpellsById[spellId]
	if spell then
		local power = CombatMath.MagicDamage(levels, skills, spell.Rank, data.Affinity[spell.Element] or 0, buffs)
		local mastery = data.Mastery[spellId]
		return power, CombatMath.ManaCost(spell.ManaCost, levels, buffs), (mastery and mastery.Level or 0) >= Arcana.MaxMastery, spell.Name
	end
	local custom = ArcanaSystem.GrimoireSpell(state, spellId)
	if custom then
		local affinity = 0
		for _, element in custom.Elements do
			affinity += (data.Affinity[element] or 0) / #custom.Elements
		end
		local shape = Arcana.Shape(custom.Shape) or { Power = 1 }
		local fusion = if #custom.Elements > 1 then Arcana.Forge.FusionBonus else 1
		local power = math.floor(CombatMath.MagicDamage(levels, skills, custom.Rank, affinity, buffs) * shape.Power * fusion + 0.5)
		local mastery = data.Mastery[spellId]
		return power, CombatMath.ManaCost(Arcana.BaseManaCost[custom.Rank], levels, buffs), (mastery and mastery.Level or 0) >= Arcana.MaxMastery, custom.Name
	end
	return 0, math.huge, false, "?"
end

local function primaryElement(state, spellId: string): string?
	local spell = Arcana.SpellsById[spellId]
	if spell then
		return spell.Element
	end
	local custom = ArcanaSystem.GrimoireSpell(state, spellId)
	return custom and custom.Elements[1]
end

-- Practice a known spell: mana, mastery, affinity, skill and stat XP; Mana Collapse.
function ArcanaSystem.Practice(player, state, spellId: string)
	if state.Age < ArcanaSystem.OpenAge(state) then
		return false, ("Real magic practice opens at age %d."):format(ArcanaSystem.OpenAge(state)), "warn"
	end
	if not ArcanaSystem.Known(state)[spellId] then
		return false, "You cannot cast that spell yet.", "warn"
	end
	local data = ArcanaSystem.Data(state)
	local buffs = PlayerState.GetBuffs(state)
	local _, cost, _, name = ArcanaSystem.SpellPower(state, spellId, buffs)
	if data.Mana <= 0 then
		return false, "Your mana is spent. It returns next year.", "warn"
	end
	data.Mana = math.max(0, data.Mana - cost)
	local parts = {}
	-- Mastery (chantless at the top).
	local mastery = data.Mastery[spellId] or { Level = 0, Casts = 0 }
	data.Mastery[spellId] = mastery
	if mastery.Level < Arcana.MaxMastery then
		mastery.Casts += 1
		if mastery.Casts >= Arcana.MasteryCasts[mastery.Level + 1] then
			mastery.Casts = 0
			mastery.Level += 1
			table.insert(parts, if mastery.Level >= Arcana.MaxMastery then "CHANTLESS!" else ("mastery %d/%d"):format(mastery.Level, Arcana.MaxMastery))
			if mastery.Level >= Arcana.MaxMastery then
				PlayerState.Log(player, ("%s is now chantless: you cast it without a word."):format(name), "realm")
			end
		end
	end
	-- Affinity grows, slower near the top.
	local element = primaryElement(state, spellId)
	if element then
		local before = data.Affinity[element] or 0
		data.Affinity[element] = math.min(100, before + math.max(0.25, 2 * (1 - before / 120)))
	end
	local rank = (Arcana.SpellsById[spellId] or ArcanaSystem.GrimoireSpell(state, spellId) or { Rank = 1 }).Rank
	local xp = SkillSystem.Grant(player, state, "Magic", 2 + rank * 2, buffs)
	if xp > 0 then
		table.insert(parts, ("+%d Magic"):format(xp))
	end
	for stat, amount in { MagicPower = 3, MagicControl = 3, Mana = 2 } do
		if state.Stats[stat] then
			PlayerState.AddStatXp(player, state, stat, amount, buffs)
		end
	end
	SkillSystem.Count(player, state, "spells_cast", 1)
	-- Mana Collapse: emptying the pool once a year deepens it for good.
	if data.Mana <= 0 and data.CollapseAge ~= state.Age then
		data.CollapseAge = state.Age
		local gain = Arcana.CollapseGain(state.Age)
		ArcanaSystem.AddManaBonus(state, gain)
		PlayerState.AdjustMeter(state, "Stress", 4)
		table.insert(parts, ("MANA COLLAPSE: max mana +%d"):format(gain))
		PlayerState.Log(player, ("You pushed your mana to empty and collapsed safely. Max mana +%d."):format(gain), "realm")
	end
	data.MaxMana = ArcanaSystem.MaxMana(state, data)
	return true, ("%s (-%d mana): %s"):format(name, cost, table.concat(parts, ", ")), "good"
end

function ArcanaSystem.SilentTrial(player, state, hits)
	local data = ArcanaSystem.Data(state)
	local trial = Arcana.SilentTrial
	if data.SilentCasting then
		return false, "You already cast in silence.", "warn"
	elseif ((state.Stats.MagicControl and state.Stats.MagicControl.Level) or 0) < trial.MagicControl then
		return false, ("The trial needs Magic Control %d."):format(trial.MagicControl), "warn"
	elseif data.SilentTrialAge == state.Age then
		return false, "One attempt a year.", "warn"
	end
	data.SilentTrialAge = state.Age
	if math.clamp(math.floor(tonumber(hits) or 0), 0, trial.Hits) < trial.Hits then
		return true, "The circle flickers out. Try again next year.", "bad"
	end
	data.SilentCasting = true
	PlayerState.SetLifeBuff(state, "SilentCasting", "Silent Casting", trial.Buffs)
	PlayerState.Log(player, "Silent Casting mastered: spells cost 30% less mana and hit 20% harder.", "realm")
	return true, "SILENT CASTING mastered!", "good"
end

function ArcanaSystem.CanForge(state): (boolean, string?)
	local forge = Arcana.Forge
	if state.Age < forge.Age then
		return false, ("The Spell Forge opens at age %d."):format(forge.Age)
	elseif SkillSystem.Level(state, "Magic") < forge.MagicSkill then
		return false, ("Needs Advanced Magic (%d)."):format(forge.MagicSkill)
	elseif SkillSystem.Level(state, "Knowledge") < forge.KnowledgeSkill then
		return false, ("Needs Knowledge %d."):format(forge.KnowledgeSkill)
	end
	return true
end

local function filterName(player, text: string): string?
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return nil
	end
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, player.UserId):GetNonChatStringForBroadcastAsync()
	end)
	if ok and type(result) == "string" and result ~= "" and not string.find(result, "#", 1, true) then
		return result
	end
	return nil
end

function ArcanaSystem.Forge(player, state, spec)
	local ok, reason = ArcanaSystem.CanForge(state)
	if not ok then
		return false, reason, "warn"
	end
	local data = ArcanaSystem.Data(state)
	if data.ForgeAge == state.Age then
		return false, "The forge needs a year to cool.", "warn"
	elseif state.Actions < 1 then
		return false, "No actions left this year.", "warn"
	end
	local forge = Arcana.Forge
	local elements, seen = {}, {}
	for _, id in (type(spec.Elements) == "table" and spec.Elements or {}) do
		if type(id) == "string" and not seen[id] and ArcanaSystem.ElementOpen(state, id) then
			seen[id] = true
			table.insert(elements, id)
		end
	end
	local shape = type(spec.Shape) == "string" and Arcana.Shape(spec.Shape)
	local rank = math.floor(tonumber(spec.Rank) or 0)
	if #elements < 1 or #elements > forge.MaxElements or not shape or rank < 1 or rank > #Arcana.RankNames then
		return false, "Pick one or two open elements, a shape and a rank.", "warn"
	end
	-- The rank needs both the Magic skill and every element's affinity.
	local need = Arcana.RankAffinity[rank]
	if SkillSystem.Level(state, "Magic") < need then
		return false, ("A %s spell needs Magic %d."):format(Arcana.RankNames[rank], need), "warn"
	end
	for _, id in elements do
		if (data.Affinity[id] or 0) < need then
			return false, ("Your %s affinity is too low for a %s spell."):format(id, Arcana.RankNames[rank]), "warn"
		end
	end
	local generated = ("%s %s of %s"):format(Arcana.RankNames[rank], shape.Name, table.concat(elements, " & "))
	local requested = type(spec.Name) == "string" and string.sub(string.gsub(spec.Name, "[%c]", ""), 1, forge.MaxNameLength) or ""
	local name = (requested ~= "" and filterName(player, requested)) or generated
	state.Grimoire = state.Grimoire or {}
	local entry = {
		Id = "custom_" .. string.sub(HttpService:GenerateGUID(false), 1, 8), Name = name, Elements = elements, Shape = shape.Id, Rank = rank,
		Creator = state.Name, Life = state.Lives, Year = (state.Modules and state.Modules.Chronicle and state.Modules.Chronicle.BirthYear or 0) + state.Age,
		Taught = false,
	}
	table.insert(state.Grimoire, entry)
	while #state.Grimoire > forge.GrimoireLimit do
		table.remove(state.Grimoire, 1)
	end
	data.Custom[entry.Id] = true
	data.ForgeAge = state.Age
	SkillSystem.Count(player, state, "forged", 1)
	state.Actions -= 1
	SkillSystem.Grant(player, state, "Magic", 10)
	PlayerState.Log(player, ("You forged a new spell, %s, and wrote it into the Family Grimoire."):format(name), "realm")
	return true, ("Forged: %s"):format(name), "good"
end

-- Learn a Family Grimoire spell from an earlier life (a Legend's spells are free).
function ArcanaSystem.Learn(player, state, id: string)
	local entry = ArcanaSystem.GrimoireSpell(state, id)
	local data = ArcanaSystem.Data(state)
	if not entry then
		return false
	elseif data.Custom[id] or data.Learned[id] then
		return false, "You already know that spell.", "warn"
	elseif SkillSystem.Level(state, "Magic") < Arcana.RankAffinity[entry.Rank] then
		return false, ("Needs Magic %d."):format(Arcana.RankAffinity[entry.Rank]), "warn"
	elseif not entry.Taught and state.Actions < 1 then
		return false, "No actions left this year.", "warn"
	end
	if not entry.Taught then
		state.Actions -= 1
	end
	data.Learned[id] = true
	return true, ("You learned %s%s."):format(entry.Name, if entry.Taught then " at an academy" else " from the Family Grimoire"), "good"
end

function ArcanaSystem.IsLegend(state): boolean
	local legend = Arcana.Legend
	for _, level in SkillSystem.Levels(state) do
		if level >= legend.SkillLevel then
			return true
		end
	end
	local fame = state.Modules and state.Modules.Fame
	return (fame and (fame.Peak or 0) >= legend.Fame) or (state.Ascensions or 0) > 0
end

-- Knowledge opens the special schools the moment it levels up.
table.insert(SkillSystem.LevelHooks, function(player, state, skillId)
	if skillId == "Knowledge" and GamePack.IsActive("Arcana") then
		ArcanaSystem.RefreshSchools(player, state)
	end
end)

-- Affinities are rolled at birth (and for saves made before the module).
local function ensure(state)
	if GamePack.IsActive("Arcana") then
		ArcanaSystem.Data(state)
	end
end
table.insert(PlayerState.NewLifeHooks, ensure)
table.insert(PlayerState.LoadHooks, ensure)

-- A Legend's forged spells are taught in academies in every later life.
table.insert(PlayerState.DeathRecorders, function(state)
	if GamePack.IsActive("Arcana") and ArcanaSystem.IsLegend(state) then
		for _, entry in state.Grimoire or {} do
			if entry.Life == state.Lives and not entry.Taught then
				entry.Taught = true
				require(script.Parent:WaitForChild("HistorySystem")).Record(state,
					("The spell '%s' discovered by %s is now taught in academies."):format(entry.Name, entry.Creator or state.Name), "deed")
			end
		end
	end
end)

ArcanaSystem.Hooks = {
	-- Item / event effect: ManaBonus = n (Magic Crystal).
	Effects = {
		ManaBonus = function(_, state, value)
			if type(value) == "number" and value > 0 then
				ArcanaSystem.AddManaBonus(state, value)
				return ("max mana +%d"):format(value)
			end
			return nil
		end,
	},
	YearTicks = {
		{
			Phase = "Growth", Order = 20, Module = "Arcana",
			Run = function(player, state)
				local data = ArcanaSystem.Data(state)
				ArcanaSystem.RefreshSchools(player, state)
				data.MaxMana = ArcanaSystem.MaxMana(state, data)
				data.Mana = data.MaxMana -- the pool refills every year
			end,
		},
	},
	Remotes = {
		ArcanaAction = {
			Module = "Arcana",
			Cooldown = 0.25,
			Validate = function(action, arg)
				return (action == "Practice" or action == "Learn") and type(arg) == "string"
					or action == "SilentTrial" and type(arg) == "number"
					or action == "Forge" and type(arg) == "table"
			end,
			Handle = function(player, state, _, action, arg)
				if action == "Practice" then
					return ArcanaSystem.Practice(player, state, arg)
				elseif action == "SilentTrial" then
					return ArcanaSystem.SilentTrial(player, state, arg)
				elseif action == "Forge" then
					return ArcanaSystem.Forge(player, state, arg)
				end
				return ArcanaSystem.Learn(player, state, arg)
			end,
		},
	},
}

return ArcanaSystem
