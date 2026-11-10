--[[
	Content: resolves content modules for the active game pack.

	ReplicatedStorage.Configs is the base content library (and, on its own, the
	default game). A game pack is a folder ReplicatedStorage.GamePacks.<PackId>
	holding a GameManifest plus any content modules it overrides. The active pack
	is the `ActivePack` attribute of the GamePacks folder (empty = base Configs).

	Lookup order for a module name: the pack, the packs it `Extends` (manifest
	field), then Configs. A pack module can build on what it overrides:

		local Content = require(game.ReplicatedStorage.Shared.Content)
		return Content.Extend("YearlyEventsConfig", script.Parent, function(events)
			events.Events.my_event = { ... }
		end)

	The active pack is read when modules load; switching packs needs a new server.
]]

local ReplicatedStorage = script.Parent.Parent
local Configs = ReplicatedStorage:WaitForChild("Configs")

local Content = {}

Content.BaseName = "Configs"
-- Soul Path is a standalone game (no GamePacks folder): every lookup ends here.
Content.Folder = Configs

local function packsFolder()
	return ReplicatedStorage:FindFirstChild("GamePacks")
end

function Content.ActivePackId(): string?
	local packs = packsFolder()
	local id = packs and packs:GetAttribute("ActivePack")
	if type(id) == "string" and id ~= "" then
		return id
	end
	return nil
end

function Content.ListPacks(): { string }
	local ids = {}
	local packs = packsFolder()
	for _, folder in if packs then packs:GetChildren() else {} do
		if folder:IsA("Folder") then
			table.insert(ids, folder.Name)
		end
	end
	table.sort(ids)
	return ids
end

-- Folders searched for `packId` (nil = active pack, false = base Configs only),
-- ending with Configs. Returns (chain, problem) for a missing pack or a cycle.
function Content.Chain(packId: (string | boolean)?): ({ Instance }, string?)
	local chain, seen = {}, {}
	local id = if packId == nil then Content.ActivePackId() elseif packId == false then nil else packId
	local problem
	local packs = packsFolder()
	while id do
		if seen[id] then
			problem = ("Extends cycle at pack '%s'"):format(id)
			break
		end
		seen[id] = true
		local folder = packs and packs:FindFirstChild(id)
		if not folder then
			problem = ("pack '%s' not found in GamePacks"):format(id)
			break
		end
		table.insert(chain, folder)
		local manifestModule = folder:FindFirstChild("GameManifest")
		local extends = nil
		if manifestModule and manifestModule:IsA("ModuleScript") then
			local ok, manifest = pcall(require, manifestModule)
			extends = ok and type(manifest) == "table" and manifest.Extends or nil
		end
		id = extends
	end
	table.insert(chain, Configs)
	return chain, problem
end

-- Returns (ModuleScript?, folderItCameFrom?).
function Content.Resolve(name: string, packId: (string | boolean)?)
	local chain, problem = Content.Chain(packId)
	if problem and packId == nil then
		warn("[Content] " .. problem .. "; falling back along the chain")
	end
	for _, folder in chain do
		local module = folder:FindFirstChild(name)
		if module and module:IsA("ModuleScript") then
			return module, folder
		end
	end
	return nil, nil
end

function Content.Get(name: string, packId: (string | boolean)?)
	local module = Content.Resolve(name, packId)
	if not module then
		local label = if packId == false then Content.BaseName else tostring(packId or Content.ActivePackId() or Content.BaseName)
		error(("[Content] no content module '%s' for pack '%s'"):format(name, label), 2)
	end
	return require(module)
end

-- The ModuleScript `name` resolves to below `folder` in that pack's chain.
function Content.InheritedModule(name: string, folder: Instance): ModuleScript
	local chain = Content.Chain(folder.Name)
	local below = false
	for _, candidate in chain do
		if below then
			local module = candidate:FindFirstChild(name)
			if module and module:IsA("ModuleScript") then
				return module
			end
		elseif candidate == folder then
			below = true
		end
	end
	error(("[Content] nothing to inherit for '%s' below '%s'"):format(name, folder.Name), 3)
end

-- What `name` resolves to below `folder` in that pack's chain.
function Content.Inherited(name: string, folder: Instance)
	return require(Content.InheritedModule(name, folder))
end

-- Deep copy that keeps shared references (index tables such as ById keep pointing
-- at the copied entries) and keeps functions as-is.
function Content.DeepCopy(value, memo)
	if type(value) ~= "table" then
		return value
	end
	memo = memo or {}
	if memo[value] then
		return memo[value]
	end
	local copy = {}
	memo[value] = copy
	for key, item in value do
		copy[Content.DeepCopy(key, memo)] = Content.DeepCopy(item, memo)
	end
	return setmetatable(copy, getmetatable(value))
end

-- A fresh copy of the inherited module, optionally patched. Inherited data is never
-- mutated. The inherited module is re-run from a clone rather than deep-copied, so
-- its helper functions close over the copy: a patched RacesConfig.Get reads the
-- patched ById, not the base one (a deep copy kept the base closures).
function Content.Extend(name: string, folder: Instance, patch: ((any) -> ())?)
	local source = Content.InheritedModule(name, folder)
	local clone = source:Clone()
	clone.Name = source.Name .. "__Extend"
	clone.Parent = source.Parent -- pack modules resolve their own chain through script.Parent
	local ok, copy = pcall(require, clone)
	clone:Destroy()
	if not ok then
		error(copy, 2)
	end
	if patch then
		patch(copy)
	end
	return copy
end

return Content
