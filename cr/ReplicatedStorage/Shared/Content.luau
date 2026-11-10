--[[
	Content: resolves the game's content modules (ReplicatedStorage.Configs).

	This place is a single standalone game: Configs holds every content module, the
	GameManifest (which engine modules are on) and UIThemeConfig (look and vocabulary).
	To make another game from this engine, clone the place and edit Configs; engine
	code always goes through Content.Get, so nothing else needs to change.
]]

local ReplicatedStorage = script.Parent.Parent
local Configs = ReplicatedStorage:WaitForChild("Configs")

local Content = {}

Content.Folder = Configs

-- The content ModuleScript called `name`, or nil.
function Content.Resolve(name: string): ModuleScript?
	local module = Configs:FindFirstChild(name)
	return if module and module:IsA("ModuleScript") then module else nil
end

function Content.Get(name: string)
	local module = Content.Resolve(name)
	if not module then
		error(("[Content] no content module '%s' in Configs"):format(name), 2)
	end
	return require(module)
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

return Content
