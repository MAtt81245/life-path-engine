--[[
	Wheel of Reincarnation: bloodline / talent spins (Shared/Gacha) with pity, the
	bloodline lock, rebirth from the wheel and the permanent Collection Codex.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = game:GetService("ServerScriptService").Modules

local PlayerState = require(Modules.PlayerState)
local WheelSystem = require(Modules.WheelSystem)
local Gacha = require(ReplicatedStorage.Shared.Gacha)
local Content = require(ReplicatedStorage.Shared.Content)
local GamePack = require(ReplicatedStorage.Shared.GamePack)

local Races = Content.Get("RacesConfig")
local Talents = Content.Get("TalentsConfig")

local function deadCharacter(name: string, karma: number)
	local player = { Name = name }
	local state = PlayerState.CreateState({}, nil)
	PlayerState.Track(player, state)
	state.Age = 70
	state.Health = 0
	PlayerState.CheckDeath(player)
	state.Karma = karma
	return player, state
end

local function rank(spin, rarity)
	return table.find(spin.RarityOrder, rarity)
end

return function(test, expect)
	test("pity never breaks a pool that lacks the guaranteed rarity", function()
		local spin = Races.Spin
		local pool = { { Id = "only_common", Rarity = spin.RarityOrder[1] } }
		local pity = {}
		for _, rule in spin.Pity do
			pity[rule.Rarity] = rule.Every - 1
		end
		local entry = Gacha.Roll(spin, pool, pity, Random.new(1))
		expect.equal(entry and entry.Id, "only_common", "falls back to what the pool has")
	end)

	test("rarity odds follow the configured weights", function()
		expect.skipUnless(GamePack.IsEnabled("Lineages"), "Lineages disabled (no bloodline pool)")
		local spin = Races.Spin
		local rng, counts, n = Random.new(7), {}, 20000
		for _ = 1, n do
			local _, rarity = Gacha.Roll(spin, Races.List, nil, rng)
			counts[rarity] = (counts[rarity] or 0) + 1
		end
		local total = 0
		for _, name in spin.RarityOrder do
			total += spin.Rarities[name].Weight
		end
		for _, name in spin.RarityOrder do
			local expected = spin.Rarities[name].Weight / total
			expect.near((counts[name] or 0) / n, expected, math.max(0.01, expected * 0.35), name)
		end
	end)

	test("pity guarantees the configured rarities", function()
		expect.skipUnless(GamePack.IsEnabled("Lineages"), "Lineages disabled (no bloodline pool)")
		local spin = Races.Spin
		for _, rule in spin.Pity do
			local pity = { [rule.Rarity] = rule.Every - 1 }
			local _, rarity, forced = Gacha.Roll(spin, Races.List, pity, Random.new(1))
			expect.truthy(rank(spin, rarity) >= rank(spin, rule.Rarity), ("spin %d gives %s+"):format(rule.Every, rule.Rarity))
			expect.truthy(forced, "marked as pity")
			expect.equal(pity[rule.Rarity], 0, "counter reset")
		end
		-- Over many spins, no streak without Epic+ is longer than the pity window.
		local pity, streak, worst = {}, 0, 0
		local rng = Random.new(3)
		for _ = 1, 3000 do
			local _, rarity = Gacha.Roll(spin, Races.List, pity, rng)
			streak = if rank(spin, rarity) >= rank(spin, "Epic") then 0 else streak + 1
			worst = math.max(worst, streak)
		end
		expect.truthy(worst < 15, "longest streak without Epic+: " .. worst)
	end)

	test("spins cost karma, fill the wheel and enter the codex", function()
		local player, state = deadCharacter("Spinner", 100)
		local before = PlayerState.CodexCount(state)
		expect.truthy(WheelSystem.SpinTalent(player, state, 1), "talent spin")
		expect.truthy(WheelSystem.SpinTalent(player, state, 2), "second slot")
		expect.equal(state.Karma, 100 - 2 * Talents.Spin.Cost, "karma spent")
		expect.truthy(state.Wheel.Talents[1] and state.Wheel.Talents[2] and state.Wheel.Talents[1] ~= state.Wheel.Talents[2], "two different talents")
		expect.truthy(PlayerState.CodexCount(state) > before, "codex grew")
		state.Karma = 0
		local ok, reason = WheelSystem.SpinTalent(player, state, 1)
		expect.falsy(ok, "no karma, no spin")
		expect.truthy(string.find(reason, PlayerState.Term("MetaCurrency"), 1, true), "explains in the pack's currency: " .. tostring(reason))
		PlayerState.Track(player, nil)
	end)

	test("rebirth uses the wheel; locked bloodlines carry over", function()
		expect.skipUnless(GamePack.IsEnabled("Lineages"), "Lineages disabled")
		local player, state = deadCharacter("Reborn", 500)
		expect.truthy(WheelSystem.SpinBloodline(player, state), "bloodline spin")
		WheelSystem.SpinTalent(player, state, 1)
		local race, talent = state.Wheel.Race, state.Wheel.Talents[1]
		expect.truthy(WheelSystem.Lock(player, state), "locked")
		expect.equal(state.Wheel.StoredRace, race, "stored")
		local ok, reason = WheelSystem.SpinBloodline(player, state)
		expect.falsy(ok, "no spins while locked")
		expect.truthy(string.find(reason, "locked", 1, true), "explains")
		local codex = PlayerState.CodexCount(state)
		expect.truthy(PlayerState.Reincarnate(player), "reborn")
		expect.equal(state.Race, race, "born with the spun bloodline")
		expect.equal(state.Talents[1], talent, "born with the spun talent")
		expect.equal(PlayerState.CodexCount(state), codex, "codex survives rebirth")
		state.Health = 0
		PlayerState.CheckDeath(player)
		expect.equal(state.Wheel.Race, race, "next wheel starts from the locked bloodline")
		expect.equal(next(state.Wheel.Talents), nil, "talents must be spun again")
		expect.truthy(WheelSystem.Unlock(player, state), "unlock is free")
		expect.equal(state.Wheel.StoredRace, nil, "unlocked")
		PlayerState.Track(player, nil)
	end)

	test("bloodline spins need the Lineages module", function()
		local flags = GamePack.Manifest.Modules
		local saved = flags.Lineages
		flags.Lineages = false
		local player, state = deadCharacter("NoLineage", 100)
		local ok = WheelSystem.SpinBloodline(player, state)
		flags.Lineages = saved
		expect.falsy(ok, "refused")
		expect.equal(state.Karma, 100, "nothing spent")
		PlayerState.Track(player, nil)
	end)

	test("each codex entry adds a permanent bonus", function()
		local state = PlayerState.CreateState({}, nil)
		local before = PlayerState.GetBuffs(state)
		local count = PlayerState.CodexCount(state)
		PlayerState.CodexAdd(state, "Titles", "codex_probe_a")
		PlayerState.CodexAdd(state, "Titles", "codex_probe_b")
		expect.falsy(PlayerState.CodexAdd(state, "Titles", "codex_probe_a"), "duplicates do not count")
		local after = PlayerState.GetBuffs(state)
		local per = Talents.Codex.BonusPerEntry
		for _, key in Talents.Codex.Buffs do
			expect.near(after[key] / before[key], (1 + (count + 2) * per) / (1 + count * per), 1e-9, key)
		end
	end)
end
