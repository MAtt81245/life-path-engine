--[[
	Rules added while tuning the balance report's findings:
	- Realm stabilization (RealmsConfig YearsPerLevel) paces the late game: the end-game
	  used to be reached by ~165 because Qi gains scale with the requirement.
	- The training injury floor: actions that cost health cannot kill.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = game:GetService("ServerScriptService").Modules

local PlayerState = require(Modules.PlayerState)
local CultivationSystem = require(Modules.CultivationSystem)
local TrainingSystem = require(Modules.TrainingSystem)
local Content = require(ReplicatedStorage.Shared.Content)
local GamePack = require(ReplicatedStorage.Shared.GamePack)
local ContentValidator = require(ReplicatedStorage.Shared.ContentValidator)

local Realms = Content.Get("RealmsConfig")
local Training = Content.Get("TrainingConfig")

return function(test, expect)
	test("breakthroughs wait for the foundation to stabilize", function()
		expect.skipUnless(GamePack.IsEnabled("Cultivation"), "Cultivation is disabled")
		local realmIndex
		for i, realm in Realms.Realms do
			if (realm.YearsPerLevel or 0) > 0 and not Realms.IsMaxed(i, 1) then
				realmIndex = i
				break
			end
		end
		expect.skipUnless(realmIndex, "no realm has YearsPerLevel")
		local player = { Name = "Stabilize" }
		local state = PlayerState.CreateState({}, nil)
		PlayerState.Track(player, state)
		state.Age, state.RealmIndex, state.SubLevel, state.LevelSince = 50, realmIndex, 2, 50
		state.Qi = PlayerState.GetRequirement(state)
		local years = Realms.Get(realmIndex).YearsPerLevel
		expect.equal(PlayerState.GetBreakthroughWait(state), years, "wait")
		expect.equal(PlayerState.Snapshot(state).BreakthroughWait, years, "snapshot")
		local ok, message = CultivationSystem.Breakthrough(player, state)
		expect.falsy(ok, "refused while stabilizing")
		expect.truthy(string.find(message, "stabilize", 1, true), "message: " .. tostring(message))
		expect.equal(state.SubLevel, 2, "no progress")

		state.Age += years
		expect.equal(PlayerState.GetBreakthroughWait(state), 0, "stable after the wait")
		local _, after = CultivationSystem.Breakthrough(player, state)
		expect.falsy(after and string.find(after, "stabilize", 1, true), "attempt allowed")
		if state.SubLevel == 3 then
			expect.equal(state.LevelSince, state.Age, "success restarts the clock")
		end
		PlayerState.Track(player, nil)
	end)

	test("old saves without LevelSince are never blocked", function()
		local state = PlayerState.CreateState({}, nil)
		state.LevelSince = nil
		state.RealmIndex = #Realms.Realms
		expect.equal(PlayerState.GetBreakthroughWait(state), 0, "wait")
	end)

	test("training that costs health stops at the injury floor", function()
		local hurtful
		for _, action in Training.Actions do
			if (action.Health or 0) < 0 and GamePack.IsEnabled(action.Module) then
				hurtful = action
				break
			end
		end
		expect.skipUnless(hurtful, "no training action costs health")
		local player = { Name = "Injury" }
		local state = PlayerState.CreateState({}, nil)
		PlayerState.Track(player, state)
		state.Age = math.max(state.Age, hurtful.MinAge, 30)
		local maxHealth = PlayerState.GetMaxHealth(state)
		local floor = maxHealth * TrainingSystem.InjuryFloor
		for _ = 1, 200 do
			state.Actions, state.ActionCounts = 6, {}
			state.Stress = 0
			if not TrainingSystem.Perform(player, state, hurtful.Id) then
				break
			end
		end
		expect.truthy(state.Health >= floor - 1e-6, ("health %.1f stays above the floor %.1f"):format(state.Health, floor))
		local _, reason = TrainingSystem.Check(state, hurtful.Id)
		expect.truthy(reason and string.find(reason, "injured", 1, true), "explains why: " .. tostring(reason))
		state.Health = maxHealth
		state.Actions, state.ActionCounts = 6, {}
		local _, healthy = TrainingSystem.Check(state, hurtful.Id)
		expect.falsy(healthy, "allowed again when healthy")
		PlayerState.Track(player, nil)
	end)

	test("validator warns when a realm cannot be finished within its lifespan", function()
		local broken = Content.DeepCopy(Content.Get("RealmsConfig"))
		broken.GetLongevity = Content.Get("RealmsConfig").GetLongevity
		broken.Realms[2].YearsPerLevel = 1000
		local report = ContentValidator.Run({ RealmsConfig = broken })
		expect.contains(report.Warnings, "stabilizing takes at least", "warnings")
		broken.Realms[2].YearsPerLevel = -1
		expect.contains(ContentValidator.Run({ RealmsConfig = broken }).Errors, "YearsPerLevel must be", "errors")
	end)
end
