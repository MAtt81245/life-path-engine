--[[
	WheelSystem: the Wheel of Reincarnation, used while the character is dead.
	- Spin a bloodline (Lineages module) or a talent slot for Karma: weighted rarity
	  rolls with pity (Shared/Gacha, RacesConfig.Spin / TalentsConfig.Spin).
	- Lock the spun bloodline (LockCost) so every next life starts with it; spins are
	  refused while locked. Unlock is free.
	- Confirm: rebirth with what the wheel holds (PlayerState.Reincarnate) along the
	  chosen rebirth path (Samsara module; ChoosePath, cost paid on Confirm).
	- BuyUpgrade: permanent Samsara meta-upgrades (SamsaraUpgradesConfig).
	Spins use the player's spin luck (Karmic Fortune, VIP) and fire Remotes.SpinResult
	so the client drum can land on the result. Every result enters the Codex.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Content = require(Shared:WaitForChild("Content"))
local GamePack = require(Shared:WaitForChild("GamePack"))
local Gacha = require(Shared:WaitForChild("Gacha"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local Rng = require(script.Parent:WaitForChild("Rng"))
local SamsaraSystem = require(script.Parent:WaitForChild("SamsaraSystem"))
local DynastySystem = require(script.Parent:WaitForChild("DynastySystem"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Races = Content.Get("RacesConfig")
local Talents = Content.Get("TalentsConfig")
local Upgrades = Content.Get("SamsaraUpgradesConfig")
local RebirthPaths = Content.Get("RebirthPathsConfig")
local Legacies = Content.Get("FamilyLegacyConfig")

local WheelSystem = {}

local function wheelOf(state)
	state.Wheel = state.Wheel or PlayerState.NewWheel()
	local wheel = state.Wheel
	wheel.Talents = wheel.Talents or {}
	wheel.Pity = wheel.Pity or {}
	wheel.Pity.Bloodline = wheel.Pity.Bloodline or {}
	wheel.Pity.Talent = wheel.Pity.Talent or {}
	wheel.Pity.Legacy = wheel.Pity.Legacy or {}
	wheel.Spins = wheel.Spins or 0
	return wheel
end
WheelSystem.Wheel = wheelOf

-- The living child chosen as the next life (Descendant path), if any.
local function heirOf(state)
	local wheel = state.Wheel
	local rel = wheel and wheel.Heir and PlayerState.FindRelationship(state, wheel.Heir)
	return if rel and rel.Alive and rel.Type == "Child" then rel else nil
end
WheelSystem.Heir = heirOf

-- Spins are refused while you are set to be reborn as your own child.
local function heirBlocks(state): string?
	local heir = heirOf(state)
	return heir and PlayerState.Words("You will be reborn as %s: the {raceName} is inherited, not spun."):format(heir.Name)
end

local function pay(state, cost: number): (boolean, string?)
	if not state.Dead then
		return false, "The Wheel only turns between lives."
	elseif state.Karma < cost then
		return false, PlayerState.Words("Not enough {MetaCurrency} (%d needed)."):format(cost)
	end
	state.Karma -= cost
	return true
end

local function announce(player, state, kind: string, entry, rarity: string, forced: boolean, slot: number?)
	PlayerState.Fire(Remotes.SpinResult, player, {
		Kind = kind, Id = entry.Id, Name = entry.Name, Rarity = rarity, Forced = forced, Slot = slot,
		Speed = PlayerState.GetSpinSpeed(state),
	})
end

-- Returns (ok, message, kind).
function WheelSystem.SpinBloodline(player, state)
	if not GamePack.IsEnabled("Lineages") or not Races.Spin then
		return false, PlayerState.Words("{RaceNamePlural} are fixed in this game.")
	end
	local wheel = wheelOf(state)
	if wheel.StoredRace then
		return false, PlayerState.Words("Your {raceName} is locked. Unlock it to spin again.")
	end
	if heirBlocks(state) then
		return false, heirBlocks(state)
	end
	local ok, problem = pay(state, Races.Spin.Cost)
	if not ok then
		return false, problem
	end
	local race, rarity, forced = Gacha.Roll(Races.Spin, Races.List, wheel.Pity.Bloodline, Rng, nil, PlayerState.GetSpinLuck(state))
	wheel.Race = race.Id
	announce(player, state, "Bloodline", race, rarity, forced)
	wheel.Spins += 1
	local new = PlayerState.CodexAdd(state, "Races", race.Id)
	return true, PlayerState.Words("%s {raceName}: %s%s%s"):format(Gacha.RarityName(Races.Spin, rarity), race.Name, if forced then " (pity)" else "", if new then "  ·  new Codex entry!" else ""),
		if rarity == "Mythic" or rarity == "Legendary" then "realm" else "good"
end

function WheelSystem.SpinTalent(player, state, slot)
	local spin = Talents.Spin
	if not spin or type(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > math.min(spin.Slots, PlayerState.MaxTalents) then
		return false
	end
	local wheel = wheelOf(state)
	if heirBlocks(state) then
		return false, heirBlocks(state)
	end
	local ok, problem = pay(state, spin.Cost)
	if not ok then
		return false, problem
	end
	local exclude = {}
	for other, id in wheel.Talents do
		if other ~= slot then
			exclude[id] = true
		end
	end
	local talent, rarity, forced = Gacha.Roll(spin, Talents.List, wheel.Pity.Talent, Rng, exclude, PlayerState.GetSpinLuck(state))
	if not talent then
		state.Karma += spin.Cost
		return false, "No talents left to roll."
	end
	wheel.Talents[slot] = talent.Id
	wheel.Spins += 1
	announce(player, state, "Talent", talent, rarity, forced, slot)
	local new = PlayerState.CodexAdd(state, "Talents", talent.Id)
	return true, ("%s talent: %s%s%s"):format(Gacha.RarityName(spin, rarity), talent.Name, if forced then " (pity)" else "", if new then "  ·  new Codex entry!" else ""),
		if rarity == "Mythic" then "realm" else "good"
end

function WheelSystem.Lock(_player, state)
	if not GamePack.IsEnabled("Lineages") or not Races.Spin then
		return false, PlayerState.Words("{RaceNamePlural} are fixed in this game.")
	end
	local wheel = wheelOf(state)
	if wheel.StoredRace then
		return false, PlayerState.Words("A {raceName} is already locked.")
	end
	-- The Ancestral Bloodline Vault pass makes the lock free.
	local ok, problem = pay(state, if PlayerState.HasFreeLock(state) then 0 else Races.Spin.LockCost)
	if not ok then
		return false, problem
	end
	wheel.StoredRace = wheel.Race
	return true, ("%s is locked: every next life starts with it."):format(Races.Get(wheel.Race).Name)
end

function WheelSystem.Unlock(_player, state)
	local wheel = wheelOf(state)
	if not wheel.StoredRace then
		return false
	end
	wheel.StoredRace = nil
	return true, PlayerState.Words("{RaceName} unlocked. Spins will replace it."), "warn"
end

-- Permanent meta-upgrade, bought with Karma between lives.
function WheelSystem.BuyUpgrade(_player, state, upgradeId)
	local upgrade = type(upgradeId) == "string" and Upgrades.ById[upgradeId]
	if not upgrade then
		return false
	end
	local rank = PlayerState.UpgradeRank(state, upgrade.Id)
	if rank >= upgrade.MaxRank then
		return false, upgrade.Name .. " is already at its highest rank."
	end
	local ok, problem = pay(state, upgrade.Costs[rank + 1])
	if not ok then
		return false, problem
	end
	state.Upgrades = state.Upgrades or {}
	state.Upgrades[upgrade.Id] = rank + 1
	return true, ("%s rank %d/%d"):format(upgrade.Name, rank + 1, upgrade.MaxRank), "realm"
end

-- Full rebirth: roll the family legacy of the next life (Dynasty module).
function WheelSystem.SpinLegacy(player, state)
	if not GamePack.IsActive("Dynasty") then
		return false, "Family legacies are fixed in this game."
	end
	local wheel = wheelOf(state)
	if heirBlocks(state) then
		return false, heirBlocks(state)
	end
	local ok, problem = pay(state, Legacies.Spin.Cost)
	if not ok then
		return false, problem
	end
	local legacy, rarity, forced = Gacha.Roll(Legacies.Spin, Legacies.List, wheel.Pity.Legacy, Rng, nil, PlayerState.GetSpinLuck(state))
	wheel.Legacy = legacy.Id
	wheel.Spins += 1
	announce(player, state, "Legacy", legacy, rarity, forced)
	return true, ("%s %s: %s%s"):format(Gacha.RarityName(Legacies.Spin, rarity), string.lower(PlayerState.Term("LegacyName")), legacy.Name, if forced then " (pity)" else ""),
		if rarity == "Mythic" or rarity == "Legendary" then "realm" else "good"
end

-- How old you are when you take over an heir: their real age, adults as an age-25 snapshot.
WheelSystem.TakeOverCap = 25
WheelSystem.GrandchildMinAge = 19

-- Descendant rebirth as one of your living children (no wheel roll: their genetics).
-- mode "TakeOver" (default): continue their life at min(their age, TakeOverCap).
-- mode "Grandchild" (adult children): be reborn as their newborn child instead.
function WheelSystem.ChooseHeir(_player, state, relId, mode)
	if not GamePack.IsEnabled("Samsara") or not GamePack.IsActive("Dynasty") or type(relId) ~= "string" then
		return false
	elseif not state.Dead then
		return false, "Choose your heir between lives."
	end
	local rel = PlayerState.FindRelationship(state, relId)
	if not rel or not rel.Alive or rel.Type ~= "Child" then
		return false, "Only a living child can carry your soul."
	end
	mode = if mode == "Grandchild" then "Grandchild" else "TakeOver"
	if mode == "Grandchild" and rel.Age < WheelSystem.GrandchildMinAge then
		return false, ("%s is too young to have a child of their own."):format(rel.Name)
	end
	local wheel = wheelOf(state)
	wheel.Heir, wheel.HeirMode, wheel.Path = rel.Id, mode, "Descendant"
	if mode == "Grandchild" then
		return true, ("You will be reborn as %s's newborn child: your grandchild."):format(rel.Name), "realm"
	end
	return true, PlayerState.Words("You will continue as %s at age %d, inheriting their {raceName} and talents."):format(rel.Name, math.min(rel.Age, WheelSystem.TakeOverCap)), "realm"
end

function WheelSystem.ChoosePath(_player, state, pathId)
	if not GamePack.IsEnabled("Samsara") or type(pathId) ~= "string" or not RebirthPaths.ById[pathId] then
		return false
	elseif not state.Dead then
		return false, "The Wheel only turns between lives."
	end
	if pathId ~= "Descendant" then
		wheelOf(state).Heir = nil -- a full rebirth leaves the family tree behind
	end
	wheelOf(state).Path = pathId
	local cost = SamsaraSystem.PathCost(state, pathId)
	return true, ("Rebirth path: %s (%s)"):format(RebirthPaths.ById[pathId].Name, if cost > 0 then cost .. " " .. PlayerState.Term("MetaCurrency") else "free")
end

-- Rebirth along the chosen path: its Karma cost is paid here.
function WheelSystem.Confirm(player, state)
	if not state.Dead then
		return false
	end
	if not GamePack.IsEnabled("Samsara") then
		return PlayerState.Reincarnate(player), nil
	end
	local wheel = wheelOf(state)
	local pathId = if RebirthPaths.ById[wheel.Path or ""] then wheel.Path else RebirthPaths.Default
	local heir = if pathId == "Descendant" then heirOf(state) else nil
	local cost, problem = SamsaraSystem.PathCost(state, pathId)
	if heir then
		cost, problem = 0, nil -- your own child carries you on for free
	end
	if problem then
		return false, problem
	end
	local previous = SamsaraSystem.Capture(state)
	local heirInfo, spouse, siblings, grandGenes
	local heirMode = wheel.HeirMode or "TakeOver"
	if heir then
		-- Genetic continuation: the heir's bloodline, talents and family legacy, no roll.
		heirInfo = table.clone(heir)
		local g = heir.Genetics or {}
		wheel.Race = g.Race or state.Race
		wheel.Talents = table.clone(g.Talents or {})
		wheel.Legacy = state.Legacy
		if heirMode == "Grandchild" then
			-- One more generation: the heir and their spouse have you, with a new awakening chance.
			heir.SpouseGenetics = heir.SpouseGenetics or DynastySystem.RollGenetics()
			grandGenes = DynastySystem.Combine(DynastySystem.ChildBlood(g), heir.SpouseGenetics)
			wheel.Race = grandGenes.Race
			wheel.Talents = table.clone(grandGenes.Talents or {})
		end
		siblings = {}
		for _, rel in state.Relationships do
			if rel.Alive and rel.Type == "Partner" then
				spouse = { Name = rel.Name, Age = rel.Age }
			elseif rel.Alive and rel.Type == "Child" and rel ~= heir then
				table.insert(siblings, { Name = rel.Name, Age = rel.Age })
			end
		end
	end
	state.Karma -= cost
	if not PlayerState.Reincarnate(player) then
		state.Karma += cost
		return false
	end
	wheel.Path, wheel.Heir, wheel.HeirMode = nil, nil, nil
	-- The family tree draws a bloodline (Descendant) or a soul leap to the next life.
	if state.Lineage[1] then
		state.Lineage[1].NextPath = pathId
	end
	SamsaraSystem.Apply(player, state, previous, pathId)
	if heirInfo and grandGenes then
		DynastySystem.BecomeGrandchild(player, state, heirInfo, grandGenes, spouse)
	elseif heirInfo then
		DynastySystem.BecomeHeir(player, state, heirInfo, spouse, siblings, math.min(heirInfo.Age, WheelSystem.TakeOverCap))
	end
	PlayerState.Push(player, true)
	return true, nil
end

-- Remote entry (AgingSystem): action = SpinBloodline | SpinTalent | SpinLegacy | Lock |
-- Unlock | BuyUpgrade | ChoosePath | ChooseHeir | Confirm.
function WheelSystem.Handle(player, state, action, arg, arg2)
	if action == "SpinBloodline" then
		return WheelSystem.SpinBloodline(player, state)
	elseif action == "SpinLegacy" then
		return WheelSystem.SpinLegacy(player, state)
	elseif action == "ChooseHeir" then
		return WheelSystem.ChooseHeir(player, state, arg, arg2)
	elseif action == "SpinTalent" then
		return WheelSystem.SpinTalent(player, state, arg)
	elseif action == "Lock" then
		return WheelSystem.Lock(player, state)
	elseif action == "Unlock" then
		return WheelSystem.Unlock(player, state)
	elseif action == "BuyUpgrade" then
		return WheelSystem.BuyUpgrade(player, state, arg)
	elseif action == "ChoosePath" then
		return WheelSystem.ChoosePath(player, state, arg)
	elseif action == "Confirm" then
		return WheelSystem.Confirm(player, state)
	end
	return false
end

return WheelSystem
