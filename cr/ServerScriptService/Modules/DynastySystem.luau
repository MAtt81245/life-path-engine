--[[
	DynastySystem: the Dynasty module (FamilyTreeConfig).
	- Ancestral Heirlooms: consecrate one equipped Weapon, Robe or Talisman (DynastyAction
	  "Consecrate", slot). At death it becomes an heirloom (state.Heirlooms, permanent)
	  and the ancestor's past-life record keeps its name (LineageMemory never lets an
	  inscribed ancestor fade). Each new life adds a generation: +5% all-XP soul stacks.
	  Direct descendants inherit family heirlooms at InheritAge; any other rebirth finds
	  them held by the old family in their region (heirloom_reclaim: buy, duel or steal).
	- Extended relatives join the family tree only through events (MeetRelative).
	- Past-life records get a short biography for the tree.
	- Genetics (GeneticsConfig): friends, rivals and partners get a spirit-root Grade, a
	  bloodline and a hereditary Trait; children are conceived from both parents
	  (TryForChild interaction, child_born event / HaveChild effect) and can be chosen as
	  your next life (WheelSystem ChooseHeir -> BecomeHeir).
	- Family legacies (FamilyLegacyConfig): applied to every new life from the wheel
	  (state.Wheel.Legacy) or the default; Life 1 rerolls them with free starter spins.
	Per-life data: state.Modules.Dynasty = { Consecrated, Met = { {Role, Name} } }.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Content = require(Shared:WaitForChild("Content"))
local GamePack = require(Shared:WaitForChild("GamePack"))
local Gacha = require(Shared:WaitForChild("Gacha"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local DuelSystem = require(script.Parent:WaitForChild("DuelSystem"))
local Rng = require(script.Parent:WaitForChild("Rng"))

local Tree = Content.Get("FamilyTreeConfig")
local Items = Content.Get("ItemsConfig")
local Genetics = Content.Get("GeneticsConfig")
local Legacies = Content.Get("FamilyLegacyConfig")
local Races = Content.Get("RacesConfig")
local StatsConfig = Content.Get("PlayerStatsConfig")

local DynastySystem = {}

local function data(state)
	local info = PlayerState.ModuleData(state, "Dynasty", {})
	info.Met = info.Met or {}
	return info
end
DynastySystem.Data = data

local function heirlooms(state)
	state.Heirlooms = state.Heirlooms or {}
	return state.Heirlooms
end

local function currentRegion(state): string?
	local world = state.Modules and state.Modules.World
	return world and world.Region
end

function DynastySystem.SoulStacks(heirloom): number
	return (heirloom.Generations or 0) * Tree.Heirloom.SoulStackPerGeneration
end

-- The all-XP bonus of every heirloom the character holds in this life.
function DynastySystem.RefreshBuffs(state)
	local mult, names = 1, {}
	for _, heirloom in heirlooms(state) do
		if heirloom.Holder == "Player" and heirloom.HeldLife == state.Lives then
			mult *= 1 + DynastySystem.SoulStacks(heirloom)
			table.insert(names, heirloom.Name)
		end
	end
	PlayerState.SetLifeBuff(state, "Heirloom", "Ancestral Soul: " .. table.concat(names, ", "), if mult > 1 then { AllStatXp = mult } else nil)
end

local function take(player, state, heirloom, how: string): string
	heirloom.Holder, heirloom.HeldLife, heirloom.Lost = "Player", state.Lives, false
	if GamePack.IsEnabled("Inventory") and Items.ById[heirloom.ItemId] then
		PlayerState.AddItem(state, heirloom.ItemId, 1)
	end
	DynastySystem.RefreshBuffs(state)
	local text = ("%s %s, forged by %s %d generation%s ago (+%d%% soul stacks)."):format(how, heirloom.Name, heirloom.Creator,
		heirloom.Generations, if heirloom.Generations == 1 then "" else "s", math.floor(DynastySystem.SoulStacks(heirloom) * 100 + 0.5))
	PlayerState.Log(player, text, "realm")
	return text
end

-- Returns (ok, message, kind).
function DynastySystem.Consecrate(player, state, slot)
	if slot == "Clear" then
		data(state).Consecrated = nil
		return true, "No heirloom will be consecrated.", "warn"
	end
	if type(slot) ~= "string" or not Tree.Heirloom.Slots[slot] then
		return false
	end
	local itemId = PlayerState.Inventory(state).Equipped[slot]
	local item = itemId and Items.ById[itemId]
	if not item then
		return false, "Equip something in that slot first."
	end
	for _, heirloom in heirlooms(state) do
		if heirloom.Holder == "Player" and heirloom.HeldLife == state.Lives and heirloom.ItemId == itemId then
			return false, item.Name .. " is already an ancestral heirloom."
		end
	end
	data(state).Consecrated = itemId
	PlayerState.Log(player, ("You consecrate your %s with your name and deeds. It will pass to your descendants."):format(item.Name), "realm")
	return true, item.Name .. " consecrated as your ancestral heirloom.", "realm"
end

table.insert(PlayerState.DeathRecorders, function(state, entry)
	if not GamePack.IsActive("Dynasty") then
		return
	end
	local region = currentRegion(state)
	for _, heirloom in heirlooms(state) do
		if heirloom.Holder == "Player" and heirloom.HeldLife == state.Lives then
			heirloom.Holder, heirloom.Region, heirloom.HeldLife = "Family", region or heirloom.Region, nil
		end
	end
	local itemId = data(state).Consecrated
	local item = itemId and Items.ById[itemId]
	if item and PlayerState.ItemCount(state, itemId) > 0 then
		local list = heirlooms(state)
		table.insert(list, {
			Id = "h" .. (#list + 1) .. "_" .. state.Lives, ItemId = itemId, Name = item.Name, Creator = state.Name,
			CreatorLife = state.Lives, Region = region, Generations = 0, Holder = "Family", Lost = false,
		})
		entry.Heirloom = item.Name
	end
	local regionName = region and Content.Get("WorldRegionsConfig").Get(region).Name
	local parts = { ("Lived in %s."):format(regionName or "a quiet village") }
	if entry.Occupation then
		table.insert(parts, "Worked as " .. entry.Occupation .. ".")
	end
	if GamePack.IsEnabled("Cultivation") then
		table.insert(parts, ("Reached %s %d/9."):format(entry.Realm, entry.SubLevel))
	end
	if entry.Partner then
		table.insert(parts, "Loved " .. entry.Partner .. ".")
	end
	if entry.Rival then
		table.insert(parts, "Feuded with " .. entry.Rival .. ".")
	end
	if entry.Heirloom then
		table.insert(parts, "Consecrated the " .. entry.Heirloom .. ".")
	end
	table.insert(parts, ("Died at %d: %s"):format(entry.Age, entry.Cause))
	entry.Biography = table.concat(parts, " ")
end)

-- Each new life is one more generation for every heirloom.
table.insert(PlayerState.NewLifeHooks, function(state)
	for _, heirloom in state.Heirlooms or {} do
		heirloom.Generations = (heirloom.Generations or 0) + 1
		if heirloom.Holder == "Player" then
			heirloom.Holder, heirloom.HeldLife = "Family", nil
		end
		-- Lost until a rebirth path says otherwise (Direct Descendant keeps the family's).
		heirloom.Lost = true
	end
end)

function DynastySystem.YearTick(player, state)
	if state.Age ~= Tree.Heirloom.InheritAge then
		return
	end
	for _, heirloom in heirlooms(state) do
		if heirloom.Holder == "Family" and not heirloom.Lost then
			take(player, state, heirloom, "Your family entrusts you with")
			PlayerState.Notify(player, "You inherited the " .. heirloom.Name .. "!", "realm")
		end
	end
end

local function reclaim(player, state, how)
	local here = currentRegion(state)
	for _, heirloom in heirlooms(state) do
		if heirloom.Holder == "Family" and heirloom.Lost and (here == nil or heirloom.Region == here) then
			local verb = if how == "Steal" then "You steal back" elseif how == "Duel" then "You win back" else "You buy back"
			return take(player, state, heirloom, verb)
		end
	end
	return nil
end

local function meetRelative(_player, state, role)
	local relative = type(role) == "string" and Tree.Relatives[role]
	if not relative then
		return nil
	end
	local info = data(state)
	for _, met in info.Met do
		if met.Role == role then
			return nil
		end
	end
	local surname = string.match(state.Name or "", "(%S+)$")
	local name = PlayerState.RandomPersonName(surname, state)
	table.insert(info.Met, { Role = role, Name = name, Age = state.Age })
	return ("%s %s joins your family tree"):format(relative.Name, name)
end

----------------------------------------------------------------------
-- Genetics
----------------------------------------------------------------------

local GENETIC_TYPES = { Friend = true, Rival = true, Partner = true }

local function rarityRank(race): number
	return (Races.Spin and table.find(Races.Spin.RarityOrder, race.Rarity)) or 1
end

function DynastySystem.RollGrade()
	local total = 0
	for _, grade in Genetics.Grades do
		total += grade.Weight
	end
	local roll = Rng:NextNumber() * total
	for _, grade in Genetics.Grades do
		roll -= grade.Weight
		if roll <= 0 then
			return grade
		end
	end
	return Genetics.Grades[1]
end

-- Genetics of someone who enters your life; better roots lean to rarer bloodlines.
function DynastySystem.RollGenetics()
	local grade = DynastySystem.RollGrade()
	local race = Races.Get(Races.Default)
	if Races.Spin and GamePack.IsEnabled("Lineages") then
		race = Gacha.Roll(Races.Spin, Races.List, {}, Rng, nil, (Genetics.GradeIndex[grade.Id] - 1) * 0.5) or race
	end
	local trait = Genetics.Traits[Rng:NextInteger(1, #Genetics.Traits)]
	return { Race = race.Id, Grade = grade.Id, Trait = trait.Id }
end

table.insert(PlayerState.RelationshipHooks, function(_state, rel, opts)
	if GamePack.IsActive("Dynasty") and GENETIC_TYPES[rel.Type] and not rel.Genetics then
		rel.Genetics = (opts and opts.Genetics) or DynastySystem.RollGenetics()
	end
end)

function DynastySystem.PlayerGrade(state): number
	local byRealm = Genetics.PlayerGradeByRealm
	return byRealm[math.clamp(state.RealmIndex or 1, 1, #byRealm)]
end

local function childCount(state): number
	local count = 0
	for _, rel in state.Relationships do
		if rel.Type == "Child" then
			count += 1
		end
	end
	return count
end

-- Genetics of a child of `blood` (the family line) and `other` (their spouse's genetics).
-- blood = { Race, GradeIndex, Talents, Trait, Potential }. Pure apart from Rng.
function DynastySystem.Combine(blood, other)
	local otherIndex = Genetics.GradeIndex[other.Grade] or 1
	local otherGrade = Genetics.Grades[otherIndex]
	-- Bloodline: the higher parent's 60% of the time, then a chance to awaken one tier.
	local mine, theirs = Races.Get(blood.Race), Races.Get(other.Race)
	local higher, lower = mine, theirs
	if rarityRank(theirs) > rarityRank(mine) then
		higher, lower = theirs, mine
	end
	local race = if Rng:NextNumber() < Genetics.HigherParentShare then higher else lower
	local mutated = false
	if Races.Spin and Rng:NextNumber() < Genetics.BaseMutation + otherGrade.MutationBonus then
		local nextRarity = Races.Spin.RarityOrder[rarityRank(race) + 1]
		local candidates = {}
		for _, candidate in Races.List do
			if candidate.Rarity == nextRarity then
				table.insert(candidates, candidate)
			end
		end
		if #candidates > 0 then
			race, mutated = candidates[Rng:NextInteger(1, #candidates)], true
		end
	end
	local talents = {}
	local pool = blood.Talents or {}
	if #pool > 0 then
		table.insert(talents, pool[Rng:NextInteger(1, #pool)])
	end
	-- The spouse's trait at their grade's chance, else (rarely) the family line's own.
	local trait = if Rng:NextNumber() < otherGrade.TraitChance then other.Trait
		elseif blood.Trait and Rng:NextNumber() < 0.5 then blood.Trait else nil
	local gradeIndex = math.clamp(math.ceil((otherIndex + (blood.GradeIndex or 1)) / 2), 1, #Genetics.Grades)
	return {
		Race = race.Id, Grade = Genetics.Grades[gradeIndex].Id, Talents = talents, Trait = trait,
		Potential = blood.Potential or {}, Mutated = mutated or nil,
	}
end

-- Your side of a conception: your race, realm-based grade, talents and stat potential.
local function playerBlood(state)
	local potential = {}
	for _, stat in StatsConfig.Order do
		local bonus = math.floor(state.Stats[stat].Level / Genetics.PotentialPerLevels)
		if bonus > 0 then
			potential[stat] = bonus
		end
	end
	return { Race = state.Race, GradeIndex = DynastySystem.PlayerGrade(state), Talents = state.Talents, Potential = potential }
end

-- A child's side of a conception (for your grandchildren): half their potential.
function DynastySystem.ChildBlood(g)
	local potential = {}
	for stat, bonus in (g and g.Potential) or {} do
		if math.floor(bonus / 2) > 0 then
			potential[stat] = math.floor(bonus / 2)
		end
	end
	return { Race = g and g.Race or Races.Default, GradeIndex = Genetics.GradeIndex[g and g.Grade or ""] or 1,
		Talents = g and g.Talents or {}, Trait = g and g.Trait, Potential = potential }
end

-- A child of you and partner, with genetics from both parents. Returns the child or nil.
function DynastySystem.Conceive(player, state, partner)
	if childCount(state) >= Genetics.TryForChild.MaxChildren then
		return nil
	end
	partner.Genetics = partner.Genetics or DynastySystem.RollGenetics()
	local genes = DynastySystem.Combine(playerBlood(state), partner.Genetics)
	local race, mutated = Races.Get(genes.Race), genes.Mutated
	local surname = string.match(state.Name or "", "(%S+)$")
	local child = PlayerState.CreateRelationship(state, "Child", { Name = PlayerState.RandomPersonName(surname, state), Age = 0, Affection = 80 })
	if not child then
		return nil
	end
	genes.Parents = { state.Name, partner.Name }
	child.Genetics = genes
	PlayerState.Remember(state, child, "Was born to you and " .. partner.Name, 1)
	local note = if mutated then PlayerState.Words(" Their %s {raceName} has awakened!"):format(race.Name) else ""
	PlayerState.Log(player, ("%s is born to you and %s.%s"):format(child.Name, partner.Name, note), "good")
	return child
end

-- TryForChild interaction (RelationshipSystem has validated affection, age and budget).
function DynastySystem.TryForChild(player, state, partner)
	local rules = Genetics.TryForChild
	if state.Age > rules.MaxAge then
		return false, "That chapter of your life has passed."
	elseif childCount(state) >= rules.MaxChildren then
		return false, "Your household is full."
	end
	local chance = rules.Chance + (if state.Flags.Married then rules.MarriedBonus else 0)
	if Rng:NextNumber() >= chance then
		PlayerState.AdjustAffection(partner, 3)
		return true, "No child this year. Perhaps next year.", "warn"
	end
	local child = DynastySystem.Conceive(player, state, partner)
	if not child then
		return false, "Your household is full."
	end
	PlayerState.AdjustMeter(state, "Happiness", 15)
	return true, ("A child is born: %s!"):format(child.Name), "realm"
end

local function haveChild(player, state)
	for _, rel in state.Relationships do
		if rel.Type == "Partner" and rel.Alive then
			local child = DynastySystem.Conceive(player, state, rel)
			return child and ("%s is born"):format(child.Name) or nil
		end
	end
	return nil
end

----------------------------------------------------------------------
-- Family legacy
----------------------------------------------------------------------

-- Applies a legacy to the current (newborn) life. A starter reroll undoes the money and
-- item of the legacy it replaces (state.LegacyGrant).
function DynastySystem.ApplyLegacy(state, legacyId: string?)
	local grant = state.LegacyGrant
	if grant then
		state.Money -= grant.Money or 0
		if grant.Item then
			PlayerState.AddItem(state, grant.Item, -1)
		end
	end
	local legacy = Legacies.Get(legacyId)
	state.Legacy = legacy.Id
	state.Money += legacy.Money or 0
	local item = legacy.Item and GamePack.IsEnabled("Inventory") and Items.ById[legacy.Item] and legacy.Item or nil
	if item then
		PlayerState.AddItem(state, item, 1)
	end
	state.LegacyGrant = { Money = legacy.Money or 0, Item = item }
	PlayerState.SetLifeBuff(state, "Legacy", legacy.Name, legacy.Buffs)
	if legacy.FamilyAffection then
		for _, rel in state.Relationships do
			if rel.Type == "Mother" or rel.Type == "Father" then
				rel.Affection = Rng:NextInteger(legacy.FamilyAffection[1], legacy.FamilyAffection[2])
			end
		end
	end
	return legacy
end

table.insert(PlayerState.NewLifeHooks, function(state)
	state.LegacyGrant = nil
	if GamePack.IsActive("Dynasty") then
		DynastySystem.ApplyLegacy(state, state.Wheel and state.Wheel.Legacy)
	end
end)

----------------------------------------------------------------------
-- Rebirth as your own child
----------------------------------------------------------------------

-- A grandchild born to one of your children (NPC autonomy HaveChild on a Child).
function DynastySystem.AddGrandchild(state, child)
	child.Offspring = child.Offspring or {}
	if #child.Offspring >= Genetics.TryForChild.MaxChildren then
		return nil
	end
	child.SpouseGenetics = child.SpouseGenetics or DynastySystem.RollGenetics()
	local genes = DynastySystem.Combine(DynastySystem.ChildBlood(child.Genetics), child.SpouseGenetics)
	local surname = string.match(child.Name or "", "(%S+)$")
	local kid = { Name = PlayerState.RandomPersonName(surname, state), Age = 0, Genetics = genes }
	table.insert(child.Offspring, kid)
	return kid
end

table.insert(PlayerState.NpcChildHooks, function(player, state, rel)
	if GamePack.IsActive("Dynasty") and rel.Type == "Child" then
		local kid = DynastySystem.AddGrandchild(state, rel)
		if kid then
			PlayerState.Log(player, ("Your grandchild %s is born to %s."):format(kid.Name, rel.Name), "good")
		end
	end
end)

-- Heir handover at an age: stats grow with the years already lived (plus the upbringing
-- focus), the Spirit Root wakes from 6, weapons from 12. Age gates follow the age.
DynastySystem.GrowthPerYear = 0.4
DynastySystem.UpbringingPerYear = 0.3
function DynastySystem.GrowUp(state, age: number, upbringing: string?)
	if age <= 0 then
		return
	end
	state.Age = age
	local focus = upbringing and Genetics.Upbringings[upbringing]
	for _, stat in StatsConfig.Order do
		local gain = age * DynastySystem.GrowthPerYear + (if focus and focus.Stats[stat] then age * DynastySystem.UpbringingPerYear else 0)
		state.Stats[stat].Level = math.min(StatsConfig.MaxLevel or math.huge, state.Stats[stat].Level + math.floor(gain))
	end
	if age > 12 then
		for _, entry in state.Proficiencies do
			entry.Level = math.min(StatsConfig.MaxLevel or math.huge, entry.Level + math.floor((age - 12) * 0.5))
		end
	end
	if age >= 6 then
		state.Flags.SpiritRoot = true
	end
	PlayerState.StartYear(state)
	state.Health = PlayerState.GetMaxHealth(state)
end

-- After WheelSystem reincarnated you with the heir's bloodline and talents: take over
-- the heir's name, hereditary trait, potential and upbringing at `age` (0 = newborn);
-- your spouse becomes your parent and your other children your siblings.
function DynastySystem.BecomeHeir(player, state, heir, spouse, siblings, age: number?)
	local g = heir.Genetics or {}
	age = age or 0
	local rewind = math.max(0, heir.Age - age) -- years the family is wound back (adult snapshot)
	state.Name = heir.Name
	local trait = g.Trait and Genetics.TraitsById[g.Trait]
	PlayerState.SetLifeBuff(state, "Heredity", trait and ("Hereditary: " .. trait.Name), trait and trait.Buffs)
	local levels = table.clone(g.Potential or {})
	local upbringing = g.Upbringing and Genetics.Upbringings[g.Upbringing]
	for stat, bonus in (upbringing and upbringing.Stats) or {} do
		levels[stat] = (levels[stat] or 0) + bonus
	end
	for stat, bonus in levels do
		if state.Stats[stat] then
			state.Stats[stat].Level = math.min(StatsConfig.MaxLevel or math.huge, state.Stats[stat].Level + bonus)
		end
	end
	for i = #state.Relationships, 1, -1 do
		if state.Relationships[i].Category == "Family" then
			table.remove(state.Relationships, i)
		end
	end
	if spouse then
		PlayerState.CreateRelationship(state, "Parent", { Name = spouse.Name, Age = math.max(18, spouse.Age - rewind), Affection = 90 })
	end
	for _, sibling in siblings or {} do
		local siblingAge = sibling.Age - rewind
		if siblingAge >= 0 then
			PlayerState.CreateRelationship(state, "Sibling", { Name = sibling.Name, Age = siblingAge, Affection = 70 })
		end
	end
	DynastySystem.GrowUp(state, age, g.Upbringing)
	state.Health = PlayerState.GetMaxHealth(state)
	if age > 0 then
		PlayerState.Log(player, PlayerState.Words("You awaken in the body of %s, your own child, at age %d. The {raceName} and talents you bred carry on."):format(heir.Name, age), "realm")
	else
		PlayerState.Log(player, PlayerState.Words("You open your eyes as %s, your own child. The {raceName} and talents you bred carry on."):format(heir.Name), "realm")
	end
end

-- Rebirth as a newborn grandchild: `genes` were combined from the heir and their spouse.
-- The heir becomes your parent, your old spouse your grandparent, their children your siblings.
function DynastySystem.BecomeGrandchild(player, state, heir, genes, spouse)
	local surname = string.match(heir.Name or "", "(%S+)$")
	local first = string.match(state.Name or "", "^(%S+)") or state.Name
	state.Name = first .. (if surname then " " .. surname else "")
	local trait = genes.Trait and Genetics.TraitsById[genes.Trait]
	PlayerState.SetLifeBuff(state, "Heredity", trait and ("Hereditary: " .. trait.Name), trait and trait.Buffs)
	for stat, bonus in genes.Potential or {} do
		if state.Stats[stat] then
			state.Stats[stat].Level = math.min(StatsConfig.MaxLevel or math.huge, state.Stats[stat].Level + bonus)
		end
	end
	for i = #state.Relationships, 1, -1 do
		if state.Relationships[i].Category == "Family" then
			table.remove(state.Relationships, i)
		end
	end
	local parent = PlayerState.CreateRelationship(state, "Parent", { Name = heir.Name, Age = heir.Age, Affection = 92 })
	if parent then
		parent.Genetics = heir.Genetics
	end
	if spouse then
		PlayerState.CreateRelationship(state, "Grandparent", { Name = spouse.Name, Age = spouse.Age, Affection = 88 })
	end
	for _, cousin in heir.Offspring or {} do
		PlayerState.CreateRelationship(state, "Sibling", { Name = cousin.Name, Age = cousin.Age, Affection = 70 })
	end
	state.Health = PlayerState.GetMaxHealth(state)
	PlayerState.Log(player, ("You are born as %s, child of %s. Your old self is now a grandparent's legend.%s"):format(
		state.Name, heir.Name, if genes.Mutated then PlayerState.Words(" Your {raceName} has awakened again!") else ""), "realm")
end

-- Heirloom duel outcome (DuelSystem): the win reclaims it, the loss costs health.
DuelSystem.Outcomes.Heirloom = function(player, state, _duel, won)
	if won then
		return reclaim(player, state, "Duel") or "You win, but the heirloom is gone."
	end
	PlayerState.AddHealth(state, -20)
	return "Your old family's heir beats you soundly."
end

DynastySystem.Hooks = {
	YearTicks = { { Phase = "Systems", Order = 60, Module = "Dynasty", Run = DynastySystem.YearTick } },
	Remotes = {
		DynastyAction = {
			Module = "Dynasty",
			Cooldown = 0.3,
			Validate = function(action, slot)
				return action == "Consecrate" and type(slot) == "string"
			end,
			Handle = function(player, state, _, _, slot)
				return DynastySystem.Consecrate(player, state, slot)
			end,
		},
	},
	Effects = {
		MeetRelative = meetRelative,
		HaveChild = haveChild,
		-- StartDuel = "Heirloom": fight your old family's descendant for the heirloom.
		StartDuel = function(player, state)
			if state.PendingDuel then
				return nil
			end
			DuelSystem.Start(player, state, { Kind = "Heirloom", Title = "Duel for the Heirloom", FoeName = "Your old family's heir",
				Difficulty = Content.Get("DuelConfig").Difficulty.Heirloom, Weapon = "Family blade", Technique = "Ancestral forms" })
			return "a duel begins"
		end,
		ReclaimHeirloom = function(player, state, value)
			return reclaim(player, state, value)
		end,
	},
}

return DynastySystem
