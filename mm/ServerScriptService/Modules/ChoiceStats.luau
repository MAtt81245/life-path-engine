--[[
	ChoiceStats: how every player chose at each life event (YOUR PATH, "How everyone
	chose"). Real counts only: each resolved choice is counted in memory and added to
	the DataStore "ChoiceStats_v1" (one key per event id, option index -> count) every
	FlushSeconds and when the server closes. Nothing is invented: below MinSample
	players the client says there is not enough data yet.

	Record(eventId, index), Get(eventId) -> { [index] = count }, Flush(), SetStore(store)
	(tests pass a MockDataStore; false = memory only).
]]

local DataStoreService = game:GetService("DataStoreService")

local ChoiceStats = {}

ChoiceStats.StoreName = "ChoiceStats_v1"
ChoiceStats.MinSample = 50 -- fewer recorded players than this: no percentages shown
ChoiceStats.FlushSeconds = 60
ChoiceStats.CacheSeconds = 60

local store = nil -- nil = not opened yet, false = unavailable (memory only)
local pending = {} -- [eventId] = { [index] = count } not written yet
local cache = {} -- [eventId] = { Counts, At }

function ChoiceStats.SetStore(newStore)
	store = newStore
	pending, cache = {}, {}
end

local function getStore()
	if store == nil then
		local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, ChoiceStats.StoreName)
		store = if ok then result else false
	end
	return store
end

function ChoiceStats.Record(eventId: string, index: number)
	local adds = pending[eventId] or {}
	adds[index] = (adds[index] or 0) + 1
	pending[eventId] = adds
	local cached = cache[eventId]
	if cached then
		cached.Counts[index] = (cached.Counts[index] or 0) + 1
	end
end

-- Writes the pending counts (string keys: DataStore JSON has no sparse arrays).
function ChoiceStats.Flush(): boolean
	local target = getStore()
	if not target then
		return false
	end
	local all = true
	for eventId, adds in pending do
		pending[eventId] = nil
		local ok = pcall(function()
			target:UpdateAsync(eventId, function(old)
				old = if type(old) == "table" then old else {}
				for index, count in adds do
					local key = tostring(index)
					old[key] = (tonumber(old[key]) or 0) + count
				end
				return old
			end)
		end)
		if not ok then
			all = false
			local back = pending[eventId] or {}
			for index, count in adds do
				back[index] = (back[index] or 0) + count
			end
			pending[eventId] = back
		end
	end
	return all
end

-- Counts for one event: stored totals plus what this server has not written yet.
function ChoiceStats.Get(eventId: string): { [number]: number }
	local cached = cache[eventId]
	if cached and os.clock() - cached.At < ChoiceStats.CacheSeconds then
		return cached.Counts
	end
	local counts = {}
	local target = getStore()
	if target then
		local ok, data = pcall(function()
			return target:GetAsync(eventId)
		end)
		if ok and type(data) == "table" then
			for key, count in data do
				local index = tonumber(key)
				if index and type(count) == "number" then
					counts[index] = count
				end
			end
		end
	end
	for index, count in pending[eventId] or {} do
		counts[index] = (counts[index] or 0) + count
	end
	cache[eventId] = { Counts = counts, At = os.clock() }
	return counts
end

function ChoiceStats.Total(counts): number
	local total = 0
	for _, count in counts do
		total += count
	end
	return total
end

local started = false
function ChoiceStats.Start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		while true do
			task.wait(ChoiceStats.FlushSeconds)
			ChoiceStats.Flush()
		end
	end)
	game:BindToClose(function()
		ChoiceStats.Flush()
	end)
end

return ChoiceStats
