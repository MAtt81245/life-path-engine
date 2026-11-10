--[[
	Pack portability regressions found by the academy probe pack (different stats,
	no Meditate action): engine code must not assume the base game's content.
	- Stat roles (PlayerStatsConfig.Roles) instead of hard-coded Charisma/Intelligence.
	- Snapshot works without any Qi-gathering action.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = game:GetService("ServerScriptService").Modules

local PlayerState = require(Modules.PlayerState)
local MasterSystem = require(Modules.MasterSystem)
local Engine = require(Modules.LifeEventsEngine)
local Content = require(ReplicatedStorage.Shared.Content)
local ContentValidator = require(ReplicatedStorage.Shared.ContentValidator)

return function(test, expect)
	test("role stats resolve to real stats of the active pack", function()
		local stats = Content.Get("PlayerStatsConfig")
		for role in stats.Roles or {} do
			local stat = PlayerState.RoleStat(role)
			expect.truthy(stat and stats.Stats[stat], "role " .. role)
		end
		expect.equal(PlayerState.RoleStat("NoSuchRole"), nil, "unknown role")
	end)

	test("a character without the social stat can still seek masters and roll chances", function()
		local player = { Name = "RoleProbe" }
		local state = PlayerState.CreateState({}, "Human")
		state.Age = 20
		for _, role in { "Social", "Knowledge" } do
			local stat = PlayerState.RoleStat(role)
			if stat then
				state.Stats[stat] = nil
			end
		end
		PlayerState.Track(player, state)
		local buffs = PlayerState.GetBuffs(state)
		local ok, err = pcall(MasterSystem.Seek, player, state, buffs)
		PlayerState.Track(player, nil)
		expect.truthy(ok, "Seek: " .. tostring(err))
		expect.equal(PlayerState.RoleLevel(state, "Social"), 0, "missing role level")
		local chance = Engine.GetChance(state, { Chance = 0.5, ChanceStat = "Charisma" }, buffs)
		expect.near(chance, 0.5, 1e-9, "missing ChanceStat adds nothing")
		expect.truthy(select(2, PlayerState.RollChance(state, 0.5, "Charisma", buffs)) == 0.5, "RollChance ignores missing stat")
	end)

	test("validator rejects a role that names an unknown stat", function()
		local base = Content.Get("PlayerStatsConfig", false)
		local broken = table.clone(base)
		broken.Roles = { Social = "NotAStat" }
		local report = ContentValidator.Run({ PlayerStatsConfig = broken }, false)
		expect.contains(report.Errors, "role Social uses unknown stat 'NotAStat'", "errors")
	end)

	test("snapshots work in a pack with no Qi-gathering action", function()
		local training = Content.Get("TrainingConfig")
		local original = training.Actions
		local withoutQi = {}
		for _, action in original do
			if not action.QiFraction then
				table.insert(withoutQi, action)
			end
		end
		training.Actions = withoutQi
		local ok, snapshot = pcall(PlayerState.Snapshot, PlayerState.CreateState({}, "Human"))
		training.Actions = original
		expect.truthy(ok, "Snapshot: " .. tostring(snapshot))
		expect.equal(next(snapshot.QiGains), nil, "no Qi gains listed")
	end)

	test("every pack declares valid roles", function()
		for _, packId in { false, table.unpack(Content.ListPacks()) } do
			for _, message in ContentValidator.Run(nil, packId).Errors do
				expect.falsy(string.find(message, "role ", 1, true) and message, "pack " .. tostring(packId))
			end
		end
	end)
end
