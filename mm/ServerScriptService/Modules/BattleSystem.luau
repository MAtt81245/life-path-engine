--[[
	BattleSystem: turn-based battles (BattleConfig; Battle module, requires Skills).

	Per-life data in ModuleData(state, "Battle") (Snapshot.Modules.Battle):
		Defeated { EnemyId = true }, Active = { EnemyId, HP, MaxHP, EnemyHP, EnemyMax,
		SignatureUsed, Guarding, Turn, Log } while a fight is on.
	Damage comes from Shared/CombatMath: Attack uses only the sword side, Cast only the
	magic side (ArcanaSystem.SpellPower; casting spends real mana). Guard blocks 60% of
	the next hit and restores 12% mana; Flee may fail; the signature move is once per
	battle. A finished fight turns battle damage into real health loss (never below 30%).
	BattleAction remote: ("Start", enemyId) | ("Attack") | ("Cast", spellId, chantOk) |
	("Guard") | ("Flee") | ("Signature").
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
local GamePack = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GamePack"))
local CombatMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatMath"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local SkillSystem = require(script.Parent:WaitForChild("SkillSystem"))
local Rng = require(script.Parent:WaitForChild("Rng"))

local Battle = Content.Get("BattleConfig")
local Races = Content.Get("RacesConfig")
local Talents = Content.Get("TalentsConfig")

local BattleSystem = {}

BattleSystem.LogLines = 6
-- fn(player, state, enemy) after a won battle (Legends: relic leads; Journal: quests).
BattleSystem.WinHooks = {}

function BattleSystem.Data(state)
	local data = PlayerState.ModuleData(state, "Battle", {})
	data.Defeated = data.Defeated or {}
	return data
end

local function region(state): string?
	local world = state.Modules and state.Modules.World
	return world and world.Region
end

local function arcana()
	return if GamePack.IsActive("Arcana") then require(script.Parent:WaitForChild("ArcanaSystem")) else nil
end

-- The once-per-battle move, named after a birth trait: "Use <name>".
function BattleSystem.SignatureName(state): string
	local talent = state.Talents and state.Talents[1] and Talents.Get(state.Talents[1])
	if talent then
		return talent.Signature or talent.Name
	end
	local race = Races.Get(state.Race)
	return race.Signature or (race.Passive and string.match(race.Passive, "^([^:]+):")) or race.Name
end

local function log(active, text: string)
	table.insert(active.Log, text)
	while #active.Log > BattleSystem.LogLines do
		table.remove(active.Log, 1)
	end
end

-- (damage, crit) of a sword hit.
function BattleSystem.SwordHit(state, buffs): (number, boolean)
	local levels = PlayerState.StatLevels(state)
	local damage = CombatMath.SwordDamage(levels, SkillSystem.Levels(state), buffs) * Rng:NextNumber(0.9, 1.1)
	local crit = Rng:NextNumber() < CombatMath.CritChance(levels)
	return math.max(1, math.floor(damage * (if crit then Battle.CritMult else 1) + 0.5)), crit
end

function BattleSystem.Start(player, state, enemyId: string)
	local data = BattleSystem.Data(state)
	local enemy = Battle.ById[enemyId]
	if data.Active then
		return false, "You are already fighting.", "warn"
	elseif not enemy or not Battle.CanFight(region(state), data.Defeated, enemyId) then
		return false, "That enemy is not here, or not open to you yet.", "warn"
	elseif state.Age < Battle.MinAge then
		return false, ("Battles open at age %d."):format(Battle.MinAge), "warn"
	elseif state.Actions < Battle.StartCost then
		return false, "No actions left this year.", "warn"
	end
	state.Actions -= Battle.StartCost
	local maxHp = CombatMath.BattleHealth(PlayerState.StatLevels(state))
	local hp = math.max(1, math.floor(maxHp * state.Health / math.max(1, PlayerState.GetMaxHealth(state)) + 0.5))
	data.Active = { EnemyId = enemyId, HP = hp, MaxHP = maxHp, EnemyHP = enemy.HP, EnemyMax = enemy.HP, Turn = 1,
		SignatureUsed = false, Signature = BattleSystem.SignatureName(state), Used = { Sword = 0, Magic = 0 }, Log = {} }
	log(data.Active, ("%s %s blocks your path!"):format(enemy.Icon, enemy.Name))
	return true, nil
end

local function finish(player, state, won: boolean, fled: boolean)
	local data = BattleSystem.Data(state)
	local active = data.Active
	local enemy = Battle.ById[active.EnemyId]
	data.Active = nil
	-- Battle damage becomes real health loss, never below the floor.
	local lost = 1 - active.HP / math.max(1, active.MaxHP)
	local maxHealth = PlayerState.GetMaxHealth(state)
	local floor = math.floor(maxHealth * Battle.Injury.Floor)
	local loss = math.floor(lost * Battle.Injury.Share * maxHealth)
	if loss > 0 then
		state.Health = math.max(math.min(state.Health, floor), state.Health - loss)
	end
	local character = GamePack.IsActive("Character") and require(script.Parent:WaitForChild("CharacterSystem"))
	local pushes = Content.Get("CharacterConfig").Pushes
	if fled then
		if character then character.Push(player, state, pushes.Flee) end
		PlayerState.Log(player, ("You fled from the %s."):format(enemy.Name), "warn")
		return "You escaped."
	end
	if not won then
		PlayerState.AdjustMeter(state, "Stress", 8)
		PlayerState.Log(player, ("The %s beat you. You limp home."):format(enemy.Name), "bad")
		return "Defeated..."
	end
	local buffs = PlayerState.GetBuffs(state)
	local reward = table.clone(enemy.Reward or {})
	if type(reward.Money) == "table" then
		reward.Money = math.floor(Rng:NextInteger(reward.Money[1], reward.Money[2]) * (buffs.BattleRewardMult or 1))
	end
	reward.SkillXp = table.clone(reward.SkillXp or {})
	local skillXp = 6 + math.floor(enemy.Power / 2)
	local main = if active.Used.Magic > active.Used.Sword then "Magic" else "Swordsmanship"
	reward.SkillXp[main] = (reward.SkillXp[main] or 0) + skillXp
	local first = not data.Defeated[enemy.Id]
	data.Defeated[enemy.Id] = true
	local parts = SkillSystem.ApplyEffects(player, state, reward, buffs)
	SkillSystem.Count(player, state, "battles_won", 1)
	if character then character.Push(player, state, pushes.BattleWin) end
	if enemy.Boss then
		SkillSystem.Count(player, state, "bosses", 1)
	end
	if first and enemy.Boss then
		require(script.Parent:WaitForChild("HistorySystem")).Record(state,
			("A statue of %s is raised for slaying the %s."):format(state.Name, enemy.Name), "deed")
	end
	for _, hook in BattleSystem.WinHooks do
		hook(player, state, enemy)
	end
	PlayerState.Log(player, ("Victory over the %s%s! %s"):format(enemy.Name, if first then " (new foes unlocked)" else "", table.concat(parts, ", ")), "good")
	return "VICTORY!"
end

-- The enemy answers (unless the fight just ended).
local function enemyTurn(state, active, buffs)
	local enemy = Battle.ById[active.EnemyId]
	if (buffs.DodgeChance or 0) > 0 and Rng:NextNumber() < buffs.DodgeChance then
		log(active, ("%s %s attacks, but you sense it coming and dodge."):format(enemy.Icon, enemy.Name))
		active.Guarding = false
		return
	end
	local damage = enemy.Power * Rng:NextNumber(0.8, 1.2) * (buffs.DamageTakenMult or 1)
	if active.Guarding then
		damage *= 1 - Battle.Guard.Block
	end
	damage = math.max(1, math.floor(damage + 0.5))
	active.HP = math.max(0, active.HP - damage)
	log(active, ("%s %s hits you for %d%s."):format(enemy.Icon, enemy.Name, damage, if active.Guarding then " (guarded)" else ""))
	active.Guarding = false
end

function BattleSystem.Act(player, state, action: string, arg, chantOk)
	local data = BattleSystem.Data(state)
	local active = data.Active
	if not active then
		return false, "No battle is on.", "warn"
	end
	local enemy = Battle.ById[active.EnemyId]
	local buffs = PlayerState.GetBuffs(state)
	if action == "Attack" then
		local damage, crit = BattleSystem.SwordHit(state, buffs)
		active.EnemyHP = math.max(0, active.EnemyHP - damage)
		active.Used.Sword += 1
		log(active, ("You strike for %d%s."):format(damage, if crit then " CRITICAL!" else ""))
	elseif action == "Cast" then
		local Arcana = arcana()
		if not Arcana or type(arg) ~= "string" or not Arcana.Known(state)[arg] then
			return false, "You cannot cast that.", "warn"
		end
		local power, cost, chantless, name = Arcana.SpellPower(state, arg, buffs)
		local mana = Arcana.Data(state)
		if mana.Mana < cost then
			return false, "Not enough mana.", "warn"
		end
		mana.Mana -= cost
		local chanted = chantless or chantOk == true
		local amount = math.floor(power * (if chanted then Battle.Chant.Bonus else 1) + 0.5)
		active.Used.Magic += 1
		local spell = Content.Get("ArcanaConfig").SpellsById[arg]
		if spell and spell.Heals then
			active.HP = math.min(active.MaxHP, active.HP + amount)
			log(active, ("%s heals you for %d%s."):format(name, amount, if chantless then " (chantless)" elseif chanted then " (chant!)" else ""))
		else
			active.EnemyHP = math.max(0, active.EnemyHP - amount)
			log(active, ("%s hits for %d%s."):format(name, amount, if chantless then " (chantless)" elseif chanted then " (chant!)" else ""))
		end
	elseif action == "Guard" then
		active.Guarding = true
		local Arcana = arcana()
		if Arcana then
			local mana = Arcana.Data(state)
			mana.Mana = math.min(mana.MaxMana, mana.Mana + math.floor(mana.MaxMana * Battle.Guard.ManaRestore + 0.5))
		end
		log(active, "You raise your guard and gather your breath.")
	elseif action == "Flee" then
		local levels = PlayerState.StatLevels(state)
		local chance = math.min(Battle.Flee.Max, Battle.Flee.Base + (levels.Agility or 0) * Battle.Flee.PerAgility + (buffs.FleeBonus or 0))
		if Rng:NextNumber() < chance then
			return true, finish(player, state, false, true), "warn"
		end
		log(active, "You try to run, but it cuts you off!")
	elseif action == "Signature" then
		if active.SignatureUsed then
			return false, "Your signature move is spent this battle.", "warn"
		end
		active.SignatureUsed = true
		local best = BattleSystem.SwordHit(state, buffs)
		local Arcana = arcana()
		if Arcana then
			for id in Arcana.Known(state) do
				best = math.max(best, (Arcana.SpellPower(state, id, buffs)))
			end
		end
		local damage = math.floor(best * Battle.Signature.Mult + 0.5)
		active.EnemyHP = math.max(0, active.EnemyHP - damage)
		log(active, ("SIGNATURE: %s! %d damage!"):format(active.Signature, damage))
	else
		return false
	end
	if active.EnemyHP <= 0 then
		return true, finish(player, state, true, false), "good"
	end
	enemyTurn(state, active, buffs)
	active.Turn += 1
	if active.HP <= 0 then
		return true, finish(player, state, false, false), "bad"
	end
	return true, nil
end

BattleSystem.Hooks = {
	YearTicks = {
		{
			-- A year never passes mid-fight: an open battle ends as a retreat.
			Phase = "Systems", Order = 7, Module = "Battle",
			Run = function(player, state)
				local data = BattleSystem.Data(state)
				if data.Active then
					finish(player, state, false, true)
				end
			end,
		},
	},
	Remotes = {
		BattleAction = {
			Module = "Battle",
			Cooldown = 0.25,
			Validate = function(action)
				return type(action) == "string"
			end,
			Handle = function(player, state, _, action, arg, chantOk)
				if action == "Start" then
					return BattleSystem.Start(player, state, arg)
				end
				return BattleSystem.Act(player, state, action, arg, chantOk)
			end,
		},
	},
}

return BattleSystem
