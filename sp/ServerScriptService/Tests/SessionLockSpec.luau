--[[
	Cross-server session locking. Two servers are simulated by switching
	PlayerState.SessionId while two player stand-ins share one UserId, against
	an in-memory DataStore with UpdateAsync semantics.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local PlayerState = require(ServerScriptService.Modules.PlayerState)
local MockDataStore = require(script.Parent.MockDataStore)

local USER_ID = 424242
local KEY = "u_" .. USER_ID

-- Runs `body(mock, onServer)` with a mock store and fast retries, restoring everything after.
local function withServers(body)
	local mock = MockDataStore.new()
	local previousStore = PlayerState.SetStore(mock)
	local saved = { PlayerState.SessionId, PlayerState.LockAttempts, PlayerState.LockRetryDelay }
	PlayerState.LockAttempts, PlayerState.LockRetryDelay = 2, 0
	local players = {}
	local function onServer(id: string)
		PlayerState.SessionId = id
		players[id] = players[id] or { UserId = USER_ID, Name = "Player@" .. id }
		return players[id]
	end
	local ok, err = pcall(body, mock, onServer)
	for _, player in players do
		PlayerState.Remove(player)
	end
	PlayerState.SetStore(previousStore)
	PlayerState.SessionId, PlayerState.LockAttempts, PlayerState.LockRetryDelay = table.unpack(saved)
	if not ok then
		error(err, 0)
	end
end

return function(test, expect)
	test("only one server can hold a save at a time", function()
		withServers(function(mock, onServer)
			local playerA = onServer("server-A")
			local stateA = PlayerState.Load(playerA)
			expect.truthy(stateA, "server A loads")
			expect.equal(mock.Data[KEY]._Lock.Owner, "server-A", "A owns the lock")
			stateA.Karma = 77
			expect.truthy(PlayerState.Save(playerA), "A autosaves")
			expect.equal(mock.Data[KEY]._Lock.Owner, "server-A", "autosave keeps the lock")

			local playerB = onServer("server-B")
			expect.falsy(PlayerState.Load(playerB), "server B is refused while A holds the lock")
			expect.equal(mock.Data[KEY].Karma, 77, "A's data untouched")

			onServer("server-A")
			expect.truthy(PlayerState.Save(playerA, true), "A saves on leave")
			expect.falsy(mock.Data[KEY]._Lock, "lock released")

			onServer("server-B")
			local stateB = PlayerState.Load(playerB)
			expect.truthy(stateB, "B loads after A left")
			expect.equal(stateB.Karma, 77, "B sees A's progress")
			expect.equal(mock.Data[KEY]._Lock.Owner, "server-B", "B owns the lock")
			expect.falsy(stateB._Lock, "lock data never leaks into the game state")
		end)
	end)

	test("a stale lock is taken over and the old server stops writing", function()
		withServers(function(mock, onServer)
			local playerA = onServer("server-A")
			local stateA = PlayerState.Load(playerA)
			stateA.Karma = 5
			PlayerState.Save(playerA)
			mock.Data[KEY]._Lock.Time -= PlayerState.LockTimeout + 60 -- server A stopped refreshing (crashed)

			local playerB = onServer("server-B")
			local stateB = PlayerState.Load(playerB)
			expect.truthy(stateB, "B takes over the expired lock")
			stateB.Karma = 9
			expect.truthy(PlayerState.Save(playerB), "B saves")

			onServer("server-A")
			stateA.Karma = 1
			expect.falsy(PlayerState.Save(playerA), "A's late save is refused")
			expect.truthy(stateA.ReadOnly, "A stops saving")
			expect.equal(mock.Data[KEY].Karma, 9, "B's newer data survives")
			expect.equal(mock.Data[KEY]._Lock.Owner, "server-B", "B keeps the lock")
			PlayerState.Save(playerA, true)
			expect.equal(mock.Data[KEY]._Lock.Owner, "server-B", "A cannot release B's lock")
		end)
	end)

	test("a brand-new player gets a lock and a fresh life", function()
		withServers(function(mock, onServer)
			local player = onServer("server-A")
			local state = PlayerState.Load(player)
			expect.equal(state.Lives, 1, "first life")
			expect.equal(mock.Data[KEY]._Lock.Owner, "server-A", "locked on first join")
			expect.truthy(PlayerState.Save(player, true), "saved")
			expect.equal(mock.Data[KEY].Lives, 1, "progress stored")
		end)
	end)

	test("legacy saves without a lock still load", function()
		withServers(function(mock, onServer)
			local legacy = PlayerState.CreateState({}, "Human")
			local stored = table.clone(legacy)
			stored.Qi = legacy.Qi:Serialize()
			stored.Version, stored.Karma = PlayerState.SaveVersion, 33
			mock.Data[KEY] = stored
			local state = PlayerState.Load(onServer("server-A"))
			expect.equal(state.Karma, 33, "legacy progress kept")
			expect.equal(mock.Data[KEY]._Lock.Owner, "server-A", "lock added")
		end)
	end)

	test("read-only sessions release the lock without overwriting", function()
		withServers(function(mock, onServer)
			mock.Data[KEY] = { Version = PlayerState.SaveVersion + 1, Lives = 3, Karma = 50 }
			local player = onServer("server-A")
			local state = PlayerState.Load(player)
			expect.truthy(state.ReadOnly, "newer save opens read-only")
			PlayerState.Save(player, true)
			expect.equal(mock.Data[KEY].Karma, 50, "newer save untouched")
			expect.equal(mock.Data[KEY].Version, PlayerState.SaveVersion + 1, "version untouched")
			expect.falsy(mock.Data[KEY]._Lock, "lock released")
		end)
	end)

	test("an unreachable DataStore never overwrites the real save", function()
		withServers(function(mock, onServer)
			mock.Data[KEY] = { Version = PlayerState.SaveVersion, Lives = 4, Karma = 12 }
			mock.Failing = true
			local player = onServer("server-A")
			local state = PlayerState.Load(player)
			expect.truthy(state and state.ReadOnly, "plays read-only")
			mock.Failing = false
			expect.falsy(PlayerState.Save(player, true), "no save from a read-only session")
			expect.equal(mock.Data[KEY].Karma, 12, "real save intact")
		end)
	end)
end
