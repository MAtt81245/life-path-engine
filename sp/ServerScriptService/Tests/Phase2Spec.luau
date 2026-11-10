--[[
	2.0 engine, Phase 2: stat separation and ratings, skills (age gates, ceilings,
	unlocks), Arcana (practice, Mana Collapse, chantless, Spell Forge, Grimoire),
	Character (upbringing, genetics, personality, fusion, hidden talents), minigames and
	battles. Cases skip when the active pack has the module off.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = game:GetService("ServerScriptService").Modules

local PlayerState = require(Modules.PlayerState)
local SkillSystem = require(Modules.SkillSystem)
local ArcanaSystem = require(Modules.ArcanaSystem)
local CharacterSystem = require(Modules.CharacterSystem)
local MinigameSystem = require(Modules.MinigameSystem)
local BattleSystem = require(Modules.BattleSystem)
local Content = require(ReplicatedStorage.Shared.Content)
local GamePack = require(ReplicatedStorage.Shared.GamePack)
local CombatMath = require(ReplicatedStorage.Shared.CombatMath)
local Requirements = require(ReplicatedStorage.Shared.Requirements)

local Stats = Content.Get("PlayerStatsConfig")

local function character(name: string, age: number)
	local player = { Name = name }
	local state = PlayerState.CreateState({}, nil)
	state.Age = age
	PlayerState.Track(player, state)
	return player, state
end

local function need(expect, module: string)
	expect.skipUnless(GamePack.IsActive(module), "pack has " .. module .. " off")
end

return function(test, expect)
	test("sword damage never reads magic stats, magic damage never reads sword stats", function()
		local base = { Strength = 20, Agility = 10, BattleAura = 15, Mana = 5, MagicPower = 5, MagicControl = 5 }
		local sword = CombatMath.SwordDamage(base, { Swordsmanship = 10 })
		local magic = CombatMath.MagicDamage(base, { Magic = 10 }, 2, 30)
		local more = table.clone(base)
		more.Mana, more.MagicPower, more.MagicControl = 99, 99, 99
		expect.equal(CombatMath.SwordDamage(more, { Swordsmanship = 10, Magic = 99 }), sword, "sword ignores magic")
		local strong = table.clone(base)
		strong.Strength, strong.Agility, strong.BattleAura = 99, 99, 99
		expect.equal(CombatMath.MagicDamage(strong, { Magic = 10, Swordsmanship = 99 }, 2, 30), magic, "magic ignores sword")
		expect.truthy(CombatMath.MagicDamage(more, { Magic = 10 }, 2, 30) > magic, "magic grows with magic stats")
	end)

	test("rating scale: adult average 50, legendary at 140, no level cap", function()
		expect.skipUnless(Stats.Rating, "pack has no rating scale")
		expect.equal(select(2, Stats.Rating(25)), "Average", "level 25 adult")
		expect.equal(select(2, Stats.Rating(70)), "Legendary", "rating 140")
		expect.equal(Stats.MaxLevel, nil, "attributes uncapped")
		local player, state = character("Uncapped", 30)
		state.Stats.Strength = { Level = 80, Xp = 0 }
		PlayerState.AddStatXp(player, state, "Strength", 1e6)
		expect.truthy(state.Stats.Strength.Level > 80, "levels past 60")
		PlayerState.Track(player, nil)
	end)

	test("skills: combat skills open at 8 (5 with Prodigy), stage ceilings, tier unlocks", function()
		need(expect, "Skills")
		local player, state = character("Kid", 6)
		expect.equal(SkillSystem.Grant(player, state, "Swordsmanship", 50), 0, "too young for the sword")
		expect.truthy(SkillSystem.Grant(player, state, "Knowledge", 50) > 0, "books are fine")
		state.Passes = { Prodigy = true }
		expect.truthy(SkillSystem.Grant(player, state, "Swordsmanship", 5) > 0, "Prodigy opens it at 5")
		SkillSystem.Grant(player, state, "Knowledge", 100000)
		expect.equal(SkillSystem.Level(state, "Knowledge"), 12, "child ceiling")
		state.Age = 20
		SkillSystem.SetLevel(player, state, "Trade", 15)
		local passive = false
		for _, buff in state.LifeBuffs do
			if buff.Kind == "Skill:Trade15" then passive = true end
		end
		expect.truthy(passive, "tier 15 passive")
		state.Actions = 2
		expect.truthy(SkillSystem.DoAction(player, state, "MarketStall"), "tier action")
		expect.falsy(SkillSystem.DoAction(player, state, "MarketStall"), "once a year")
		expect.falsy(SkillSystem.DoAction(player, state, "Caravan"), "tier 30 still locked")
		PlayerState.Track(player, nil)
	end)

	test("Arcana: practice spends mana, Mana Collapse once a year, chantless at mastery 5", function()
		need(expect, "Arcana")
		local player, state = character("Mage", 10)
		local data = ArcanaSystem.Data(state)
		local spell = data.Favored .. "1"
		ArcanaSystem.AddManaBonus(state, 1000) -- a deep pool (Data() clamps Mana to the max)
		data.Mana = data.MaxMana
		local bonus = data.ManaBonus
		for _ = 1, 30 do ArcanaSystem.Practice(player, state, spell) end
		expect.equal(data.Mastery[spell].Level, 5, "mastered")
		local _, _, chantless = ArcanaSystem.SpellPower(state, spell)
		expect.truthy(chantless, "chantless")
		data.Mana = 1
		expect.truthy(ArcanaSystem.Practice(player, state, spell), "last drop")
		local gain = Content.Get("ArcanaConfig").CollapseGain(10)
		expect.equal(data.ManaBonus, bonus + gain, "collapse at a young age")
		data.Mana = 1
		ArcanaSystem.Practice(player, state, spell)
		expect.equal(data.ManaBonus, bonus + gain, "once a year")
		expect.falsy(ArcanaSystem.Practice(player, state, data.Favored .. "7"), "God rank needs affinity 90")
		PlayerState.Track(player, nil)
	end)

	test("Spell Forge: gated, writes the Family Grimoire; a Legend's spells are taught", function()
		need(expect, "Arcana")
		local player, state = character("Forger", 9)
		local data = ArcanaSystem.Data(state)
		local spec = { Elements = { data.Favored }, Shape = "Lance", Rank = 1 }
		expect.falsy(ArcanaSystem.Forge(player, state, spec), "too young")
		state.Age, state.Actions = 12, 2
		SkillSystem.SetLevel(player, state, "Magic", 30)
		SkillSystem.SetLevel(player, state, "Knowledge", 15)
		expect.truthy(ArcanaSystem.Forge(player, state, spec), "forged")
		expect.equal(#state.Grimoire, 1, "in the grimoire")
		expect.falsy(ArcanaSystem.Forge(player, state, spec), "forge cools for a year")
		SkillSystem.SetLevel(player, state, "Magic", 80)
		expect.truthy(ArcanaSystem.IsLegend(state), "Emperor-rank skill = Legend")
		for _, record in PlayerState.DeathRecorders do
			pcall(record, state, {})
		end
		expect.truthy(state.Grimoire[1].Taught, "taught in academies")
		PlayerState.Track(player, nil)
	end)

	test("Character: upbringing, parents, personality thresholds, fusion, hidden talents", function()
		need(expect, "Character")
		local player, state = character("Persona", 14)
		local data = CharacterSystem.Data(state)
		expect.truthy(Content.Get("CharacterConfig").UpbringingsById[data.Upbringing], "upbringing")
		expect.truthy(data.Parents.Father.Attributes.Strength and data.Parents.Mother.Attributes.Strength, "parents' stat cards")
		local view = PlayerState.Snapshot(state)
		expect.falsy(Requirements.Check(view, { Personality = { Bravery = 50 } }), "not brave yet")
		CharacterSystem.Push(player, state, { Bravery = 60 })
		expect.truthy(Requirements.Check(PlayerState.Snapshot(state), { Personality = { Bravery = 50 } }), "brave now")
		local brave = false
		for _, buff in state.LifeBuffs do
			if buff.Kind == "Personality" and buff.Buffs.SwordDamageMult then brave = true end
		end
		expect.truthy(brave, "brave buff")
		-- Hidden talent reveals through its counter, then fuses by recipe.
		data.Hidden = { { Id = "battle_instinct", Revealed = false } }
		CharacterSystem.Count(player, state, "battles_won", 5)
		expect.truthy(data.Hidden[1].Revealed, "revealed")
		state.Talents = { "iron_bones" }
		expect.skipUnless(Content.Get("TalentsConfig").Get("iron_bones"), "pack has no iron_bones")
		expect.truthy(CharacterSystem.Fuse(player, state, "T:iron_bones", "H:battle_instinct"), "Born Warrior")
		expect.equal(#state.Talents, 0, "inputs consumed")
		expect.truthy(next(state.FusionDiscovered) ~= nil, "recipe discovered")
		expect.falsy(CharacterSystem.Fuse(player, state, "T:a", "T:b"), "once a year")
		PlayerState.Track(player, nil)
	end)

	test("minigames: score capped, once a year, age windows", function()
		need(expect, "Minigames")
		local player, state = character("Player1", 10)
		local ok, text = MinigameSystem.Motes(player, state, 999)
		expect.truthy(ok and string.find(text, "40 motes", 1, true), "capped at 40")
		expect.falsy(MinigameSystem.Motes(player, state, 5), "once a year")
		state.Age = 30
		expect.falsy(MinigameSystem.Sneak(player, state, true), "too old to sneak past Mother")
		PlayerState.Track(player, nil)
	end)

	test("battles: only open foes and the next target; win unlocks; guard; flee", function()
		need(expect, "Battle")
		local Battle = Content.Get("BattleConfig")
		local visible = Battle.Visible(nil, {})
		expect.equal(#visible, 2, "first foe + next target")
		expect.equal(visible[2].State, "Next", "next target shown, locked")
		local player, state = character("Fighter", 16)
		state.Actions = 3
		state.Stats.Strength.Level, state.Stats.BattleAura.Level = 60, 60
		expect.falsy(BattleSystem.Start(player, state, "bandit_scout"), "locked foe")
		expect.truthy(BattleSystem.Start(player, state, "wild_boar"), "started")
		local guard = 0
		while BattleSystem.Data(state).Active and guard < 20 do
			guard += 1
			BattleSystem.Act(player, state, "Attack")
		end
		expect.truthy(BattleSystem.Data(state).Defeated.wild_boar, "boar beaten")
		expect.truthy(Battle.CanFight(nil, BattleSystem.Data(state).Defeated, "bandit_scout"), "next foe unlocked")
		expect.truthy(state.Health >= PlayerState.GetMaxHealth(state) * Battle.Injury.Floor or state.Health > 0, "injury floor")
		PlayerState.Track(player, nil)
	end)
end
