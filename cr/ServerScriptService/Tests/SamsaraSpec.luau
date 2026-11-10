--[[
	Samsara meta-progression: permanent Karma upgrades, game passes (golden
	diamonds, luck, spin speed, Studio dev toggle), spin luck, rebirth paths with
	eras and echoes, and Past-Life Glimpses.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = game:GetService("ServerScriptService").Modules

local PlayerState = require(Modules.PlayerState)
local WheelSystem = require(Modules.WheelSystem)
local SamsaraSystem = require(Modules.SamsaraSystem)
local MonetizationSystem = require(Modules.MonetizationSystem)
local RegionSystem = require(Modules.RegionSystem)
local Gacha = require(ReplicatedStorage.Shared.Gacha)
local Requirements = require(ReplicatedStorage.Shared.Requirements)
local Content = require(ReplicatedStorage.Shared.Content)
local GamePack = require(ReplicatedStorage.Shared.GamePack)

local Training = Content.Get("TrainingConfig")
local Races = Content.Get("RacesConfig")
local Upgrades = Content.Get("SamsaraUpgradesConfig")
local Paths = Content.Get("RebirthPathsConfig")

-- Echoes live where the old life ended: rebirth, then travel back there (World module).
local function rebornNear(player, state, path)
	local home = state.Modules and state.Modules.World and state.Modules.World.Region
	PlayerState.Die(player, "test")
	state.Karma = math.max(state.Karma, 100)
	WheelSystem.ChoosePath(player, state, path)
	WheelSystem.Confirm(player, state)
	if home and GamePack.IsActive("World") then
		RegionSystem.SetRegion(state, home)
	end
end

local function deadCharacter(name: string, karma: number)
	local player = { Name = name }
	local state = PlayerState.CreateState({}, nil)
	PlayerState.Track(player, state)
	state.Age = 40
	PlayerState.Die(player, "test")
	state.Karma = karma
	return player, state
end

return function(test, expect)
	test("upgrades cost Karma per rank, stop at the max rank and only sell between lives", function()
		local player, state = deadCharacter("Shop", 1000)
		local upgrade = Upgrades.ById.TemporalAwareness
		for rank = 1, upgrade.MaxRank do
			local before = state.Karma
			expect.truthy(WheelSystem.BuyUpgrade(player, state, upgrade.Id), "rank " .. rank)
			expect.equal(before - state.Karma, upgrade.Costs[rank], "rank cost")
		end
		local ok, reason = WheelSystem.BuyUpgrade(player, state, upgrade.Id)
		expect.falsy(ok, "maxed")
		expect.truthy(reason and string.find(reason, "highest", 1, true), "explains: " .. tostring(reason))
		expect.falsy(WheelSystem.BuyUpgrade(player, state, "Bogus"), "unknown upgrade")
		WheelSystem.Confirm(player, state)
		expect.falsy(WheelSystem.BuyUpgrade(player, state, "KarmicFortune"), "alive: refused")
		PlayerState.Track(player, nil)
	end)

	test("Temporal Awareness adds free diamonds up to the free cap; passes add golden ones", function()
		local freeCap = math.min(Training.FreeActionCap or Training.MaxActionSlots, Training.MaxActionSlots)
		local state = PlayerState.CreateState({}, nil)
		local base = PlayerState.GetMaxActions(state)
		state.Upgrades = { TemporalAwareness = 1 }
		expect.equal(PlayerState.GetMaxActions(state), math.min(base + 1, freeCap), "+1 per rank")
		state.Upgrades = { TemporalAwareness = 2 }
		local free = PlayerState.GetMaxActions(state)
		expect.truthy(free <= freeCap, "free slots capped")
		state.Passes = { CelestialTimekeeper = true }
		expect.equal(PlayerState.GetGoldenActions(state), 1, "one golden diamond")
		expect.equal(PlayerState.GetMaxActions(state), math.min(free + 1, Training.MaxActionSlots), "golden on top")
		state.Upgrades = { SocialMagnetism = 2 }
		expect.equal(PlayerState.GetMaxSocial(state), Content.Get("RelationshipsConfig").SocialPerYear + 2, "Social Magnetism")
	end)

	test("Immortal VIP: golden diamond, x2 spin speed and +25% luck; Studio dev toggle", function()
		local player = { Name = "Vip" }
		local state = PlayerState.CreateState({}, nil)
		PlayerState.Track(player, state)
		expect.equal(PlayerState.GetSpinSpeed(state), 1, "normal speed")
		local ok = MonetizationSystem.SetDevPass(player, "ImmortalVIP", true)
		expect.truthy(ok, "dev toggle works in Studio")
		expect.truthy(PlayerState.OwnsPass(state, "ImmortalVIP"), "owned")
		expect.equal(PlayerState.GetSpinSpeed(state), 2, "x2 speed")
		expect.near(PlayerState.GetSpinLuck(state), 0.25, 1e-6, "luck")
		state.Upgrades = { KarmicFortune = 2 }
		expect.near(PlayerState.GetSpinLuck(state), 0.25 + 0.16, 1e-6, "luck stacks with Karmic Fortune")
		MonetizationSystem.SetDevPass(player, "ImmortalVIP", false)
		expect.falsy(PlayerState.OwnsPass(state, "ImmortalVIP"), "removed")
		expect.falsy(MonetizationSystem.SetDevPass(player, "Bogus", true), "unknown pass")
		PlayerState.Track(player, nil)
	end)

	test("passes are never saved", function()
		local state = PlayerState.CreateState({}, nil)
		state.Passes = { ImmortalVIP = true }
		local data = PlayerState.Serialize(state)
		expect.equal(data.Passes, nil, "stripped from the save")
		expect.truthy(state.Passes.ImmortalVIP, "the live state keeps them")
	end)

	test("luck shifts spin odds toward higher rarities", function()
		local spin = Races.Spin
		expect.skipUnless(spin, "no bloodline spin")
		local plain = Gacha.Odds(spin, Races.List, {}, 0)
		local lucky = Gacha.Odds(spin, Races.List, {}, 0.4)
		-- The lowest rarity the pool actually has loses share to the luck-boosted ones.
		local lowest
		for _, rarity in spin.RarityOrder do
			if plain[rarity] > 0 then
				lowest = rarity
				break
			end
		end
		expect.skipUnless(lowest and lowest == spin.RarityOrder[1] and plain[lowest] < 1, "pool has no unboosted rarity")
		expect.truthy(lucky[lowest] < plain[lowest], "fewer commons")
		local top = spin.RarityOrder[#spin.RarityOrder]
		if plain[top] > 0 then
			expect.truthy(lucky[top] > plain[top], "more of the top rarity")
		end
	end)

	test("descendant rebirth keeps the surname, 25% wealth and loving parents; free if married", function()
		expect.skipUnless(GamePack.IsEnabled("Samsara"), "Samsara disabled")
		local player = { Name = "Heir" }
		local state = PlayerState.CreateState({}, nil)
		PlayerState.Track(player, state)
		state.Money, state.Flags.Married = 8000, true
		local surname = string.match(state.Name, "(%S+)$")
		PlayerState.Die(player, "test")
		state.Karma = 5
		expect.truthy(WheelSystem.ChoosePath(player, state, "Descendant"), "path chosen")
		expect.truthy(WheelSystem.Confirm(player, state), "reborn")
		expect.equal(state.Karma, 5, "free when married")
		expect.equal(string.match(state.Name, "(%S+)$"), surname, "same surname")
		local legacyMoney = if GamePack.IsActive("Dynasty") then (Content.Get("FamilyLegacyConfig").Get(state.Legacy).Money or 0) else 0
		expect.equal(state.Money, 50 + PlayerState.GetBuffs(state).StartingMoney + legacyMoney + 2000, "25% inheritance")
		if GamePack.IsEnabled("Relationships") then
			for _, rel in state.Relationships do
				if rel.Category == "Family" then
					expect.truthy(rel.Affection >= Paths.ById.Descendant.FamilyAffection[1], "high affection: " .. rel.Affection)
				end
			end
		end
		PlayerState.Track(player, nil)
	end)

	test("paths cost Karma unless free, and refuse when Karma is short", function()
		expect.skipUnless(GamePack.IsEnabled("Samsara"), "Samsara disabled")
		local player, state = deadCharacter("Poor", 10)
		WheelSystem.ChoosePath(player, state, "Past")
		local ok, reason = WheelSystem.Confirm(player, state)
		expect.falsy(ok, "not enough Karma")
		expect.truthy(state.Dead and reason and string.find(reason, PlayerState.Term("MetaCurrency"), 1, true), "still dead: " .. tostring(reason))
		state.Karma = 40
		expect.truthy(WheelSystem.Confirm(player, state), "reborn")
		expect.equal(state.Karma, 40 - Paths.ById.Past.Cost, "paid")
		expect.equal(SamsaraSystem.Data(state).Era, "Ancient", "ancient era")
		local withEra = PlayerState.GetBuffs(state).QiMult
		PlayerState.SetLifeBuff(state, "Era", nil, nil)
		expect.near(withEra / PlayerState.GetBuffs(state).QiMult, Paths.Eras.Ancient.Buffs.QiMult, 1e-6, "era buff")
		expect.truthy(Requirements.Check(state, { Era = "Ancient" }), "Era requirement")
		PlayerState.Track(player, nil)
	end)

	test("echoes from the past life can be met again; future rebirths hear their legend", function()
		expect.skipUnless(GamePack.IsEnabled("Samsara") and GamePack.IsEnabled("Relationships"), "Samsara/Relationships disabled")
		local player = { Name = "Echo" }
		local state = PlayerState.CreateState({}, nil)
		PlayerState.Track(player, state)
		PlayerState.CreateRelationship(state, "Friend", { Name = "Mei Lin", Age = 30, Affection = 90 })
		rebornNear(player, state, "Stranger")
		expect.truthy(Requirements.Check(state, { HasEcho = true }), "an echo exists")
		state.Age = 15
		local text = SamsaraSystem.Hooks.Effects.MeetEcho(player, state, 30)
		expect.truthy(text and string.find(text, "Mei Lin", 1, true), "met: " .. tostring(text))
		local met = nil
		for _, rel in state.Relationships do
			if rel.Name == "Mei Lin" then met = rel end
		end
		expect.truthy(met and met.Age == 45, "aged forward")
		expect.falsy(Requirements.Check(state, { HasEcho = true }), "no echoes left")
		-- Future: the legend of the old self
		local name = state.Name
		state.Alignment = 80
		PlayerState.Die(player, "test")
		state.Karma = 100
		WheelSystem.ChoosePath(player, state, "Future")
		WheelSystem.Confirm(player, state)
		local karma = state.Karma
		local legend = SamsaraSystem.Hooks.Effects.LegendOfSelf(player, state, true)
		expect.truthy(legend and string.find(legend, name, 1, true), "legend names the old self: " .. tostring(legend))
		expect.truthy(state.Karma > karma, "saintly legend grants Karma")
		PlayerState.Track(player, nil)
	end)

	test("your powerful old rival takes you as a disciple, teaches their art, and the feud ends", function()
		expect.skipUnless(GamePack.IsEnabled("Samsara") and GamePack.IsEnabled("Relationships"), "Samsara/Relationships disabled")
		local player = { Name = "Disciple" }
		local state = PlayerState.CreateState({}, nil)
		PlayerState.Track(player, state)
		local key = Training.ProficiencyOrder[1]
		state.Proficiencies[key].Level = 30
		state.RealmIndex = math.max(state.RealmIndex, 2)
		PlayerState.CreateRelationship(state, "Rival", { Name = "Bai Long", Age = 30, Affection = 5 })
		rebornNear(player, state, "Stranger")
		expect.truthy(Requirements.Check(state, { RivalMentorHere = true }), "the old rival lives on")
		local rivals = 0
		for age = 1, SamsaraSystem.Mentor.NewRivalAge do
			state.Age = age
			SamsaraSystem.YearTick(player, state)
		end
		for _, rel in state.Relationships do
			if rel.Type == "Rival" then rivals += 1 end
		end
		expect.equal(rivals, 1, "a new young rival of your own age")
		state.Age = 12
		local text = SamsaraSystem.Hooks.Effects.BecomeRivalDisciple(player, state, true)
		expect.truthy(text and string.find(text, "does not recognize you", 1, true), "accepted: " .. tostring(text))
		local mentor = SamsaraSystem.Data(state).Mentor
		expect.truthy(Requirements.Check(state, { IsRivalDisciple = true }), "disciple")
		-- A gifted disciple: the climax needs the signature art at ClimaxProficiency (or a glimpse).
		state.Proficiencies[key].Level = SamsaraSystem.Mentor.ClimaxProficiency
		local levelBefore = state.Proficiencies[key].Level
		for age = 13, 12 + SamsaraSystem.Mentor.ClimaxYears do
			state.Age = age
			SamsaraSystem.YearTick(player, state)
		end
		expect.truthy(mentor.Technique, "signature technique learned")
		expect.truthy(mentor.Climax, "climax once skilled enough")
		local queued = false
		for _, entry in state.EventQueue do
			if entry.Id == "rival_reckoning" then queued = true end
		end
		expect.truthy(queued, "reckoning queued")
		expect.truthy(state.Proficiencies[key].Level >= levelBefore, "lessons never cost levels")
		expect.truthy(SamsaraSystem.Hooks.Effects.RivalReckoning(player, state, "Revenge"), "revenge duel")
		expect.falsy(Requirements.Check(state, { IsRivalDisciple = true }), "the arc is over")
		expect.falsy(SamsaraSystem.Hooks.Effects.RivalReckoning(player, state, "Legacy"), "only once")
		PlayerState.Track(player, nil)
	end)

	test("past-life glimpses recover part of the old mastery and scale with Soul Retention", function()
		expect.skipUnless(GamePack.IsEnabled("Samsara"), "Samsara disabled")
		local key = Training.ProficiencyOrder[1]
		local function reborn(retention)
			local player = { Name = "Glimpse" .. retention }
			local state = PlayerState.CreateState({}, nil)
			PlayerState.Track(player, state)
			state.Upgrades = { SoulRetention = retention }
			state.Proficiencies[key].Level = 40
			PlayerState.Die(player, "test")
			WheelSystem.Confirm(player, state)
			state.Age = 6
			local before = state.Proficiencies[key].Level
			local text = SamsaraSystem.Glimpse(player, state)
			PlayerState.Track(player, nil)
			return state.Proficiencies[key].Level - before, text, state
		end
		local low, text, state = reborn(0)
		local high = reborn(5)
		expect.equal(low, math.floor(40 * Paths.Glimpse.BaseStrength), "15% of the old mastery")
		expect.truthy(high > low, "Soul Retention strengthens glimpses")
		expect.truthy(text and string.find(text, "Past-Life Glimpse", 1, true), "narrated")
		expect.truthy(Requirements.Check(state, { RemembersPastLife = true }), "unlocks past-life dialogue")
		local chance0 = SamsaraSystem.GlimpseOdds({ Upgrades = {} })
		local chance5 = SamsaraSystem.GlimpseOdds({ Upgrades = { SoulRetention = 5 } })
		expect.near(chance5 - chance0, 0.25, 1e-6, "+5% chance per rank")
	end)
end
