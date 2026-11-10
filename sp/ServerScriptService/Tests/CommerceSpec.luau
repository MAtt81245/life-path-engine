--[[
	Commercial launch: Immortal Treasury passes and developer products (golden
	diamonds, auto-age speed, VIP badge, Karma packs, receipts, Miracle Revival,
	Miracle Pill, Bloodline Vault) and the Life 1 onboarding tutorial.
	Runs in Studio, so the shop's sandbox (free test purchase) is available.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = game:GetService("ServerScriptService").Modules

local PlayerState = require(Modules.PlayerState)
local MonetizationSystem = require(Modules.MonetizationSystem)
local TutorialSystem = require(Modules.TutorialSystem)
local WheelSystem = require(Modules.WheelSystem)
local CultivationSystem = require(Modules.CultivationSystem)
local Content = require(ReplicatedStorage.Shared.Content)
local GamePack = require(ReplicatedStorage.Shared.GamePack)

local Monetization = Content.Get("MonetizationConfig")
local Races = Content.Get("RacesConfig")
local Realms = Content.Get("RealmsConfig")

local function character(name: string, age: number?)
	local player = { Name = name }
	local state = PlayerState.CreateState({}, nil)
	state.Age = age or 30
	PlayerState.Track(player, state)
	return player, state
end

return function(test, expect)
	test("Celestial Timekeeper: golden diamond and 1.5 s auto-age; VIP badge", function()
		local player, state = character("Clock")
		expect.equal(PlayerState.GetAutoAgeSeconds(state, 4), 4, "default speed")
		expect.equal(#PlayerState.GetBadges(state), 0, "no badge")
		state.Passes = { CelestialTimekeeper = true }
		expect.equal(PlayerState.GetGoldenActions(state), 1, "golden diamond")
		expect.equal(PlayerState.GetAutoAgeSeconds(state, 4), 1.5, "faster auto-age")
		state.Passes = { ImmortalVIP = true }
		expect.equal(PlayerState.GetBadges(state)[1], "VIP", "VIP badge")
		expect.equal(PlayerState.Snapshot(state).Badges[1], "VIP", "badge in the snapshot")
		PlayerState.Track(player, nil)
	end)

	test("Studio test purchase of a pass grants it and its golden diamond this year", function()
		local player, state = character("Buyer")
		local before = state.Actions
		local ok = MonetizationSystem.Handle(player, state, "BuyPass", "CelestialTimekeeper", true)
		expect.truthy(ok, "sandbox purchase")
		expect.truthy(PlayerState.OwnsPass(state, "CelestialTimekeeper"), "owned")
		expect.equal(state.Actions, math.min(before + 1, PlayerState.GetMaxActions(state)), "usable this year")
		local again, reason = MonetizationSystem.Handle(player, state, "BuyPass", "CelestialTimekeeper", true)
		expect.falsy(again, "already owned")
		expect.truthy(string.find(reason or "", "already own", 1, true), "explains")
		expect.falsy(MonetizationSystem.Handle(player, state, "BuyPass", "Bogus", true), "unknown pass")
		MonetizationSystem.SetDevPass(player, "CelestialTimekeeper", false)
		PlayerState.Track(player, nil)
	end)

	test("Karmic Soul Packs add 50 / 200 / 600 Karma", function()
		local player, state = character("Packs")
		for id, amount in { KarmaSmall = 50, KarmaMedium = 200, KarmaHeavenly = 600 } do
			local before = state.Karma
			expect.truthy(MonetizationSystem.GrantProduct(player, state, id), id)
			expect.equal(state.Karma - before, amount, id .. " amount")
		end
		local before = state.Karma
		expect.truthy(MonetizationSystem.Handle(player, state, "BuyProduct", "KarmaSmall", true), "sandbox product")
		expect.equal(state.Karma - before, 50, "sandbox grants")
		expect.falsy(MonetizationSystem.GrantProduct(player, state, "Bogus"), "unknown product")
		PlayerState.Track(player, nil)
	end)

	test("receipts are remembered (saved) so a retried receipt never grants twice", function()
		local _, state = character("Receipt")
		expect.truthy(MonetizationSystem.RecordReceipt(state, "p1"), "first time")
		expect.falsy(MonetizationSystem.RecordReceipt(state, "p1"), "retry ignored")
		for i = 1, MonetizationSystem.MaxReceipts + 5 do
			MonetizationSystem.RecordReceipt(state, "bulk" .. i)
		end
		expect.equal(#state.Receipts, MonetizationSystem.MaxReceipts, "bounded")
		expect.truthy(PlayerState.Serialize(state).Receipts, "saved with the state")
		local unknown = MonetizationSystem.ProcessReceipt({ PlayerId = -1, ProductId = 12345, PurchaseId = "x" })
		expect.equal(unknown, Enum.ProductPurchaseDecision.NotProcessedYet, "unknown buyer waits")
	end)

	test("Miracle Revival restores an untimely death at 50% health, once per life", function()
		local player, state = character("Phoenix", 30)
		state.Karma = 10
		local lineage = #state.Lineage
		state.Health = 0
		expect.truthy(PlayerState.CheckDeath(player), "died of wounds")
		expect.truthy(PlayerState.CanRevive(state), "untimely: revivable")
		expect.truthy(PlayerState.Snapshot(state).Revivable, "offered to the client")
		expect.equal(#state.Lineage, lineage + 1, "recorded as a past life")
		local ok = MonetizationSystem.Handle(player, state, "BuyProduct", "MiracleRevival", true)
		expect.truthy(ok, "revival bought")
		expect.falsy(state.Dead, "alive again")
		expect.equal(state.Age, 30, "same life, same age")
		expect.equal(state.Karma, 10, "death Karma taken back")
		expect.equal(#state.Lineage, lineage, "no past-life entry")
		expect.near(state.Health, PlayerState.GetMaxHealth(state) * Monetization.ReviveHealth, 1, "half health")
		expect.truthy(state.Flags.Revived, "marked")
		state.Health = 0
		PlayerState.CheckDeath(player)
		expect.falsy(PlayerState.CanRevive(state), "only once per life")
		local refused = MonetizationSystem.Handle(player, state, "BuyProduct", "MiracleRevival", true)
		expect.falsy(refused, "nothing to defy")
		PlayerState.Track(player, nil)
	end)

	test("no revival for natural deaths, after a Wheel action, or once the moment passed", function()
		local player, state = character("Elder", 30)
		state.Age = PlayerState.GetMaxLifespan(state)
		PlayerState.CheckDeath(player)
		expect.truthy(state.Dead, "natural death")
		expect.falsy(PlayerState.CanRevive(state), "lifespan ran out: final")
		PlayerState.Track(player, nil)

		local p2, s2 = character("Gambler", 30)
		PlayerState.Die(p2, "test")
		expect.truthy(PlayerState.CanRevive(s2), "untimely")
		PlayerState.ClearRevival(s2) -- AgingSystem: any successful Wheel action
		expect.falsy(PlayerState.CanRevive(s2), "verdict accepted")
		local before = s2.Karma
		local ok = MonetizationSystem.GrantProduct(p2, s2, "MiracleRevival")
		expect.truthy(ok, "a late receipt still grants something")
		expect.equal(s2.Karma - before, Monetization.ReviveFallbackKarma, "Karma refund")
		expect.truthy(s2.Dead, "still dead")
		PlayerState.Track(p2, nil)
	end)

	test("Instant Miracle Pill fills Qi and adds +20% to the next breakthrough only", function()
		expect.skipUnless(GamePack.IsEnabled("Cultivation"), "no cultivation in this pack")
		local player, state = character("Pill", 20)
		state.RealmIndex, state.SubLevel = 2, 5 -- a low base chance, room under the cap
		state.LevelSince = -100
		local without = PlayerState.GetBreakthroughChance(state)
		expect.truthy(MonetizationSystem.Handle(player, state, "BuyProduct", "MiraclePill", true), "pill bought")
		expect.truthy(state.Qi:Ge(PlayerState.GetRequirement(state)), "Qi full")
		local with = PlayerState.GetBreakthroughChance(state)
		expect.near(with - without, math.min(0.2, Realms.MaxChance - without), 1e-6, "+20%")
		CultivationSystem.Breakthrough(player, state)
		expect.equal(state.PillBonus, nil, "spent by one attempt")
		PlayerState.Track(player, nil)
	end)

	test("Ancestral Bloodline Vault makes the bloodline lock free", function()
		expect.skipUnless(GamePack.IsEnabled("Lineages") and Races.Spin ~= nil, "no bloodline wheel")
		local player, state = character("Vault", 40)
		PlayerState.Die(player, "test")
		state.Karma = 0
		expect.falsy(WheelSystem.Lock(player, state), "costs Karma without the pass")
		state.Passes = { BloodlineVault = true }
		expect.equal(PlayerState.Snapshot(state).SpinCosts.Lock, 0, "shown as free")
		expect.truthy(WheelSystem.Lock(player, state), "free lock")
		expect.equal(state.Karma, 0, "no Karma spent")
		expect.truthy(state.Wheel.StoredRace, "bloodline kept for the next lives")
		PlayerState.Track(player, nil)
	end)

	test("products a pack cannot use are not sold", function()
		local pill = Monetization.ProductsById.MiraclePill
		expect.equal(MonetizationSystem.Available(pill), GamePack.IsActive("Cultivation"), "pill follows cultivation")
		expect.truthy(MonetizationSystem.Available(Monetization.ProductsById.KarmaSmall), "Karma everywhere")
	end)

	test("tutorial: steps in order, last step or skip completes, saved, Life 2+ never sees it", function()
		local player, state = character("Newbie", 0)
		expect.falsy(state.TutorialCompleted, "fresh Life 1")
		expect.truthy(TutorialSystem.Ack(state, 2), "step 2")
		expect.falsy(TutorialSystem.Ack(state, 1), "going back is ignored")
		expect.falsy(TutorialSystem.Ack(state, 9), "bad step")
		expect.falsy(TutorialSystem.Ack(state, 1.5), "not an integer")
		expect.truthy(TutorialSystem.Ack(state, TutorialSystem.LastStep()), "last step")
		expect.truthy(state.TutorialCompleted, "completed")
		expect.truthy(PlayerState.Serialize(state).TutorialCompleted, "saved")
		expect.truthy(PlayerState.Snapshot(state).TutorialCompleted, "client knows")
		PlayerState.Track(player, nil)

		local p2, s2 = character("Skipper", 0)
		expect.truthy(TutorialSystem.Skip(s2), "skip")
		expect.truthy(s2.TutorialCompleted, "skipped = completed")
		expect.falsy(TutorialSystem.Skip(s2), "once")
		PlayerState.Track(p2, nil)

		local p3, s3 = character("Veteran", 30)
		PlayerState.Die(p3, "test")
		PlayerState.Reincarnate(p3)
		expect.equal(s3.Lives, 2, "second life")
		expect.truthy(s3.TutorialCompleted, "veterans skip the guide")
		PlayerState.Track(p3, nil)
	end)
end
