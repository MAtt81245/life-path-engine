--[[
	In-memory stand-in for a GlobalDataStore (GetAsync / SetAsync / UpdateAsync),
	for tests that cannot reach real DataStores from Studio. Values are deep-copied
	in and out like real serialization, and an UpdateAsync transform that returns
	nil cancels the write. Set `Failing = true` to make every call error.
]]

local MockDataStore = {}
MockDataStore.__index = MockDataStore

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in value do
		result[key] = copy(item)
	end
	return result
end

function MockDataStore.new()
	return setmetatable({ Data = {}, Writes = 0, Failing = false }, MockDataStore)
end

function MockDataStore:_check()
	if self.Failing then
		error("502: mock DataStore unavailable", 0)
	end
end

function MockDataStore:GetAsync(key: string)
	self:_check()
	return copy(self.Data[key])
end

function MockDataStore:SetAsync(key: string, value)
	self:_check()
	self.Data[key] = copy(value)
	self.Writes += 1
end

function MockDataStore:UpdateAsync(key: string, transform)
	self:_check()
	local result = transform(copy(self.Data[key]))
	if result == nil then
		return nil
	end
	self.Data[key] = copy(result)
	self.Writes += 1
	return copy(result)
end

return MockDataStore
