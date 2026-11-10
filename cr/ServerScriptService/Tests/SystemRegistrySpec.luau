--[[
	SystemRegistry and Shared/EngineModules: gameplay modules plug in by files.
	Fame (an optional add-on module) is the proof: definition + system module only.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = game:GetService("ServerScriptService").Modules

local SystemRegistry = require(Modules.SystemRegistry)
local PlayerState = require(Modules.PlayerState)
local Engine = require(Modules.LifeEventsEngine)
local FameSystem = require(Modules.FameSystem)
local GamePack = require(ReplicatedStorage.Shared.GamePack)
local Requirements = require(ReplicatedStorage.Shared.Requirements)
local ContentValidator = require(ReplicatedStorage.Shared.ContentValidator)

-- Runs fn with a manifest module flag temporarily changed.
local function withModule(id: string, enabled: boolean, fn)
	local flags = GamePack.Manifest.Modules
	local saved = flags[id]
	flags[id] = enabled
	local ok, err = pcall(fn)
	flags[id] = saved
	if not ok then
		error(err, 0)
	end
end

local function order(phase: string): string
	local names = {}
	for _, tick in SystemRegistry.Ticks() do
		if tick.Phase == phase then
			table.insert(names, tick.Source)
		end
	end
	return table.concat(names, ",")
end

return function(test, expect)
	test("year ticks keep the original order", function()
		expect.equal(order("Systems"), "DuelSystem,MilestoneSystem,CareerSystem,RegionSystem,MasterSystem,RelationshipSystem,NpcSystem,FameSystem,DynastySystem", "Systems phase")
		expect.equal(order("Growth"), "CultivationSystem,SamsaraSystem", "Growth phase (glimpses after cultivation)")
	end)

	test("every gameplay remote is registered and exists", function()
		local remotes = SystemRegistry.Remotes()
		for _, name in { "Train", "Breakthrough", "MasterAction", "CareerAction", "RelationshipAction", "ProgressionAction", "InventoryAction", "FameAction" } do
			expect.truthy(remotes[name] and type(remotes[name].Handle) == "function", "registered " .. name)
			local event = ReplicatedStorage.Remotes:FindFirstChild(name)
			expect.truthy(event and event:IsA("RemoteEvent"), "RemoteEvent " .. name)
		end
	end)

	test("a module is only active with its dependencies", function()
		expect.skipUnless(GamePack.IsEnabled("NpcAutonomy"), "NpcAutonomy off in this pack")
		expect.truthy(SystemRegistry.Active("NpcAutonomy"), "active")
		withModule("Relationships", false, function()
			expect.falsy(SystemRegistry.Active("NpcAutonomy"), "inactive without Relationships")
		end)
		expect.truthy(SystemRegistry.Active(nil), "core hooks always run")
	end)

	test("module definitions extend the engine contracts", function()
		local fame = GamePack.Modules.Fame
		expect.truthy(fame and fame.Optional, "Fame is an optional module")
		expect.equal(GamePack.EffectKeys.Fame, "Fame", "effect owned by Fame")
		expect.equal(GamePack.RequirementModules.MinFame, "Fame", "requirement owned by Fame")
		expect.truthy(Requirements.Fields.MinFame, "requirement field known")
		expect.truthy(GamePack.BuffKeys.FameMult, "buff key known")
		expect.equal(PlayerState.NewBuffs().FameMult, 1, "multiplicative buff starts at 1")
		expect.truthy(Engine.EffectHandlers.Fame, "effect handler registered")
		expect.truthy(Requirements.Check({ Modules = { Fame = { Points = 50 } } }, { MinFame = 40 }), "requirement met")
		local met, items = Requirements.Evaluate({}, { MinFame = 40 })
		expect.falsy(met, "no fame data counts as 0")
		expect.equal(Requirements.UnmetText(items), "Fame 40", "requirement text")
	end)

	test("modules can ship their own UI tab", function()
		local fame = GamePack.Modules.Fame
		expect.truthy(fame.Tab and fame.Tab.Label, "Fame declares a tab")
		local page = GamePack.Pages.Fame
		expect.truthy(page and page:IsA("ModuleScript"), "page module found inside the definition")
		expect.truthy(GamePack.TabKeys.Fame, "manifests may relabel the tab")
		local module = require(page)
		expect.truthy(type(module.Init) == "function" and type(module.Render) == "function", "page contract")
		for id, def in GamePack.Modules do
			expect.equal(def.Tab ~= nil, GamePack.Pages[id] ~= nil, "tab and page go together for " .. id)
		end
	end)

	test("optional modules do not warn when a pack leaves them out", function()
		local report = ContentValidator.Run()
		for _, warning in report.Warnings do
			expect.falsy(string.find(warning, "module 'Fame'", 1, true) and warning, "warning")
		end
	end)

	test("module effects, ticks and data follow the module flag", function()
		local player = { Name = "FameProbe" }
		local state = PlayerState.CreateState({}, nil)
		state.Age = 20
		PlayerState.Track(player, state)
		withModule("Fame", true, function()
			Engine.ApplyEffects(player, state, { Id = "probe" }, { Fame = 30 })
			expect.equal(FameSystem.Data(state).Points, 30, "effect applied")
			SystemRegistry.RunYear("Systems", player, state, PlayerState.GetBuffs(state))
			expect.equal(FameSystem.Data(state).Points, 27, "yearly decay ran")
			expect.equal(PlayerState.Snapshot(state).Modules.Fame.Points, 27, "sent to the client")
		end)
		withModule("Fame", false, function()
			Engine.ApplyEffects(player, state, { Id = "probe" }, { Fame = 30 })
			SystemRegistry.RunYear("Systems", player, state, PlayerState.GetBuffs(state))
			expect.equal(FameSystem.Data(state).Points, 27, "ignored while the module is off")
		end)
		PlayerState.Track(player, nil)
		local reborn = PlayerState.CreateState({}, nil)
		-- Only birth data (the World region) exists in a new life; per-life module data is reset.
		expect.equal(reborn.Modules.Fame, nil, "a new life starts with empty module data")
	end)
end
