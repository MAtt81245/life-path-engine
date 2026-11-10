--[[
	SystemRegistry: discovers gameplay systems and runs their hooks, so a new
	gameplay module plugs in by adding files (a Shared/EngineModules definition and
	a system ModuleScript here) instead of editing YearSystem, GameManager,
	GamePack or LifeEventsEngine.

	A system is any ModuleScript in this folder with the attribute System = true.
	It may export:

	System.Hooks = {
		YearTicks = { { Phase = "Systems" | "Growth", Order = 10, Module = id | { ids }, Run = fn(player, state, buffs) } },
		Remotes = { RemoteName = { Module = id | { ids }, Cooldown = 0.2, Validate = fn(...) -> boolean,
		                            Handle = fn(player, state, buffs, ...) -> (ok, message, kind) } },
		Effects = { EffectKey = fn(player, state, value, entry, buffs) -> summary? },
		AfterChange = { { Module = id, Run = fn(player, state) } },
	}

	Year phases (YearSystem): "Systems" runs right after aging, "Growth" after a
	buff refresh, before health and mood. Lower Order runs first.
	AfterChange runs after every successful action, resolved event and year.
	A hook runs only while its module is active (enabled, with its dependencies);
	no Module = core, always on; a list runs while any of its modules is active.
	GameManager creates a missing RemoteEvent for every registered remote.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GamePack = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GamePack"))
local Engine = require(script.Parent:WaitForChild("LifeEventsEngine"))

local SystemRegistry = {}

SystemRegistry.Phases = { "Systems", "Growth" }

local systems, ticks, remotes, afterChange = {}, {}, {}, {}

local function active(module): boolean
	if module == nil then
		return true
	end
	if type(module) == "table" then
		for _, id in module do
			if GamePack.IsActive(id) then
				return true
			end
		end
		return false
	end
	return GamePack.IsActive(module)
end
SystemRegistry.Active = active

local function checkModules(source: string, module)
	for _, id in if type(module) == "table" then module elseif module then { module } else {} do
		if not GamePack.Modules[id] then
			error(("[SystemRegistry] %s uses unknown module '%s' (add Shared/EngineModules/%s)"):format(source, tostring(id), tostring(id)), 0)
		end
	end
end

local found = {}
for _, child in script.Parent:GetChildren() do
	if child:IsA("ModuleScript") and child:GetAttribute("System") == true then
		table.insert(found, child)
	end
end
table.sort(found, function(a, b) return a.Name < b.Name end)

for _, moduleScript in found do
	local source = moduleScript.Name
	local hooks = require(moduleScript).Hooks or {}
	table.insert(systems, source)
	for _, tick in hooks.YearTicks or {} do
		local phase = tick.Phase or "Systems"
		assert(table.find(SystemRegistry.Phases, phase), ("[SystemRegistry] %s: unknown year phase '%s'"):format(source, tostring(phase)))
		checkModules(source, tick.Module)
		table.insert(ticks, { Phase = phase, Order = tick.Order or 100, Module = tick.Module, Run = tick.Run, Source = source })
	end
	for name, remote in hooks.Remotes or {} do
		assert(not remotes[name], ("[SystemRegistry] remote %s is registered twice (%s)"):format(name, source))
		checkModules(source, remote.Module)
		remote.Source = source
		remotes[name] = remote
	end
	for key, handler in hooks.Effects or {} do
		assert(not Engine.EffectHandlers[key], ("[SystemRegistry] effect %s is handled twice (%s)"):format(key, source))
		assert(GamePack.EffectKeys[key], ("[SystemRegistry] %s handles effect '%s' that no EngineModules definition declares"):format(source, key))
		Engine.EffectHandlers[key] = handler
	end
	for _, check in hooks.AfterChange or {} do
		checkModules(source, check.Module)
		table.insert(afterChange, { Module = check.Module, Run = check.Run, Source = source })
	end
end

table.sort(ticks, function(a, b)
	if a.Order ~= b.Order then
		return a.Order < b.Order
	end
	return a.Source < b.Source
end)

-- Runs the year ticks of one phase, in Order, for active modules.
function SystemRegistry.RunYear(phase: string, player, state, buffs)
	for _, tick in ticks do
		if tick.Phase == phase and active(tick.Module) then
			tick.Run(player, state, buffs)
		end
	end
end

-- Checks that follow any change (title unlocks, ...).
function SystemRegistry.AfterChange(player, state)
	for _, check in afterChange do
		if active(check.Module) then
			check.Run(player, state)
		end
	end
end

function SystemRegistry.Remotes()
	return remotes
end

function SystemRegistry.Systems(): { string }
	return table.clone(systems)
end

-- Ordered year ticks as { Phase, Order, Module, Source } (dev console, tests).
function SystemRegistry.Ticks()
	local list = {}
	for _, tick in ticks do
		table.insert(list, { Phase = tick.Phase, Order = tick.Order, Module = tick.Module, Source = tick.Source })
	end
	return list
end

return SystemRegistry
