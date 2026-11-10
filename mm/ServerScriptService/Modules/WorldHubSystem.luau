--[[
	WorldHubSystem: the World modal's server side (WorldHubConfig; WorldHub module,
	requires Inventory).

	- Global event, Wanted Posters and Traveling Merchant rotate with the clock.
	- A refresh loop keeps every online player's per-life buff sources current:
	  "WorldEvent", "Friends" (a Roblox friend in this server), "Guild" (group member).
	- Battle drops and bounty seals (BattleSystem.WinHooks), crafting, merchant buys.
	- Weekly Champions: an OrderedDataStore of combat power per week (pcall; empty in
	  Studio without API access).
	Per-life ModuleData(state, "WorldHub"): { Bounties = { posterKey = true }, Bought = { offerKey = true } }.
	WorldAction remote: ("Buy", offerIndex) | ("Craft", recipeIndex).
	WorldQuery remote function -> { Event, Active, EndsIn, Posters, Merchant, Champions, Friends, Guild }.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
local GamePack = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GamePack"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local BattleSystem = require(script.Parent:WaitForChild("BattleSystem"))
local Rng = require(script.Parent:WaitForChild("Rng"))

local Hub = Content.Get("WorldHubConfig")
local Items = Content.Get("ItemsConfig")
local Battle = Content.Get("BattleConfig")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local WorldHubSystem = {}

local groupCache = setmetatable({}, { __mode = "k" })
local champions = { List = {}, At = -math.huge }

local function active(): boolean
	return GamePack.IsActive("WorldHub")
end

function WorldHubSystem.Data(state)
	local data = PlayerState.ModuleData(state, "WorldHub", {})
	data.Bounties = data.Bounties or {}
	data.Bought = data.Bought or {}
	return data
end

-- A seeded pick that every server agrees on.
local function seeded(seed: number, count: number, size: number): { number }
	local random = Random.new(seed)
	local pool, picks = {}, {}
	for i = 1, size do pool[i] = i end
	for _ = 1, math.min(count, size) do
		table.insert(picks, table.remove(pool, random:NextInteger(1, #pool)))
	end
	return picks
end

function WorldHubSystem.Event(now: number?)
	now = now or os.time()
	local slot = math.floor(now / Hub.EventPeriod)
	local event = Hub.Events[seeded(slot, 1, #Hub.Events)[1]]
	local into = now - slot * Hub.EventPeriod
	return event, into < Hub.EventActive, (if into < Hub.EventActive then Hub.EventActive - into else Hub.EventPeriod - into), slot
end

-- Wanted Posters for a region: enemies that fight there, rotated with the event slot.
function WorldHubSystem.Posters(regionId: string?, now: number?)
	local _, _, _, slot = WorldHubSystem.Event(now)
	local pool = {}
	for _, enemy in Battle.Enemies do
		if enemy.Region == nil or enemy.Region == regionId then
			table.insert(pool, enemy)
		end
	end
	local posters = {}
	for _, index in seeded(slot * 7 + #(regionId or ""), Hub.PosterCount, #pool) do
		local enemy = pool[index]
		table.insert(posters, { Key = ("%d:%s"):format(slot, enemy.Id), EnemyId = enemy.Id, Name = enemy.Name, Icon = enemy.Icon, Seals = Hub.Seals })
	end
	return posters
end

function WorldHubSystem.Merchant(now: number?)
	now = now or os.time()
	local slot = math.floor(now / Hub.MerchantPeriod)
	local offers = {}
	for _, index in seeded(slot * 13, Hub.MerchantCount, #Hub.MerchantPool) do
		local offer = Hub.MerchantPool[index]
		local item = Items.ById[offer.Item]
		table.insert(offers, { Key = ("%d:%s"):format(slot, offer.Item), Item = offer.Item, Name = item and item.Name or offer.Item,
			Description = item and item.Description or "", Price = offer.Price })
	end
	return offers, (slot + 1) * Hub.MerchantPeriod - now
end

local function region(state): string?
	return state.Modules and state.Modules.World and state.Modules.World.Region
end

function WorldHubSystem.Buy(player, state, index)
	local offer = WorldHubSystem.Merchant()[math.floor(tonumber(index) or 0)]
	local data = WorldHubSystem.Data(state)
	if not offer then
		return false
	elseif data.Bought[offer.Key] then
		return false, "The merchant has no more of that until the next caravan.", "warn"
	elseif state.Money < offer.Price then
		return false, "You can't afford that.", "warn"
	end
	if PlayerState.AddItem(state, offer.Item, 1) <= 0 then
		return false, "Your bag is full.", "warn"
	end
	state.Money -= offer.Price
	data.Bought[offer.Key] = true
	return true, ("Bought %s from the Traveling Merchant."):format(offer.Name), "good"
end

function WorldHubSystem.Craft(player, state, index)
	local recipe = Hub.Recipes[math.floor(tonumber(index) or 0)]
	if not recipe then
		return false
	end
	local inventory = PlayerState.Inventory(state)
	for itemId, count in recipe.Needs do
		if (inventory.Items[itemId] or 0) < count then
			return false, "Missing materials.", "warn"
		end
	end
	if PlayerState.AddItem(state, recipe.Result, 1) <= 0 then
		return false, "You can't carry another one.", "warn"
	end
	for itemId, count in recipe.Needs do
		PlayerState.AddItem(state, itemId, -count)
	end
	return true, ("Crafted: %s"):format(Items.ById[recipe.Result].Name), "good"
end

-- Drops and bounties after a won battle.
table.insert(BattleSystem.WinHooks, function(player, state, enemy)
	if not active() or not GamePack.IsActive("Inventory") then return end
	local parts = {}
	for itemId, range in Hub.Drops[enemy.Id] or {} do
		local count = Rng:NextInteger(range[1], range[2])
		if count > 0 and PlayerState.AddItem(state, itemId, count) > 0 then
			table.insert(parts, ("%d %s"):format(count, Items.ById[itemId].Name))
		end
	end
	local data = WorldHubSystem.Data(state)
	for _, poster in WorldHubSystem.Posters(region(state)) do
		if poster.EnemyId == enemy.Id and not data.Bounties[poster.Key] then
			data.Bounties[poster.Key] = true
			PlayerState.AddItem(state, "bounty_seal", poster.Seals)
			table.insert(parts, ("%d Bounty Seals (Wanted Poster)"):format(poster.Seals))
		end
	end
	if #parts > 0 then
		PlayerState.Log(player, "Spoils: " .. table.concat(parts, ", "), "good")
	end
end)

local function inGroup(player): boolean
	if Hub.Group.GroupId <= 0 or typeof(player) ~= "Instance" then
		return false
	end
	if groupCache[player] == nil then
		local ok, member = pcall(player.IsInGroup, player, Hub.Group.GroupId)
		groupCache[player] = ok and member == true
	end
	return groupCache[player]
end
WorldHubSystem.InGroup = inGroup

local function friendHere(player): boolean
	if typeof(player) ~= "Instance" then return false end
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local ok, friends = pcall(player.IsFriendsWith, player, other.UserId)
			if ok and friends then return true end
		end
	end
	return false
end

-- Keeps the world buff sources of one player current.
function WorldHubSystem.Refresh(player, state)
	if not active() or state.Dead then return end
	local event, on = WorldHubSystem.Event()
	PlayerState.SetLifeBuff(state, "WorldEvent", if on then event.Name else nil, if on then event.Buffs else nil)
	PlayerState.SetLifeBuff(state, "Friends", "Friend in this server", if friendHere(player) then Hub.Friends.Buffs else nil)
	local member = inGroup(player)
	PlayerState.SetLifeBuff(state, "Guild", "Guild Member", if member then Hub.Group.Buffs else nil)
	if member then
		state.Flags.GuildMember = true
	end
end

local function week(): number
	return math.floor((os.time() - 345600) / 604800) -- weeks start on Monday (UTC)
end

function WorldHubSystem.ReportPower(player, power: number)
	if typeof(player) ~= "Instance" then return end
	pcall(function()
		local store = DataStoreService:GetOrderedDataStore("Champions_" .. week())
		store:UpdateAsync(tostring(player.UserId), function(old)
			return math.max(tonumber(old) or 0, math.floor(power))
		end)
	end)
end

function WorldHubSystem.Champions()
	if os.clock() - champions.At < Hub.ChampionsUpdate then
		return champions.List
	end
	champions.At = os.clock()
	pcall(function()
		local store = DataStoreService:GetOrderedDataStore("Champions_" .. week())
		local page = store:GetSortedAsync(false, Hub.ChampionsShown):GetCurrentPage()
		local list = {}
		for rank, entry in page do
			local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, tonumber(entry.key))
			table.insert(list, { Rank = rank, Name = if ok then name else entry.key, Power = entry.value })
		end
		champions.List = list
	end)
	return champions.List
end

function WorldHubSystem.Query(player, state)
	local event, on, endsIn = WorldHubSystem.Event()
	local merchant, restock = WorldHubSystem.Merchant()
	local data = state and WorldHubSystem.Data(state) or { Bounties = {}, Bought = {} }
	local posters = WorldHubSystem.Posters(state and region(state))
	for _, poster in posters do poster.Done = data.Bounties[poster.Key] == true end
	for _, offer in merchant do offer.Sold = data.Bought[offer.Key] == true end
	return {
		Event = { Name = event.Name, Text = event.Text }, Active = on, EndsIn = endsIn, Posters = posters, Merchant = merchant, Restock = restock,
		Champions = WorldHubSystem.Champions(), Friends = friendHere(player), Guild = inGroup(player),
		GroupSet = Hub.Group.GroupId > 0,
	}
end

local started = false
function WorldHubSystem.Start()
	if started then return end
	started = true
	local query = Remotes:FindFirstChild("WorldQuery") or Instance.new("RemoteFunction")
	query.Name = "WorldQuery"
	query.Parent = Remotes
	local last = setmetatable({}, { __mode = "k" })
	query.OnServerInvoke = function(player)
		if last[player] and os.clock() - last[player] < 0.5 then return nil end
		last[player] = os.clock()
		return WorldHubSystem.Query(player, PlayerState.Get(player))
	end
	local reported = setmetatable({}, { __mode = "k" })
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				local state = PlayerState.Get(player)
				if state then
					WorldHubSystem.Refresh(player, state)
					if GamePack.IsActive("Legends") and (not reported[player] or os.clock() - reported[player] > Hub.ChampionsUpdate) then
						reported[player] = os.clock()
						local power = require(script.Parent:WaitForChild("LegendsSystem")).Power(state)
						task.spawn(WorldHubSystem.ReportPower, player, power)
					end
				end
			end
			task.wait(30)
		end
	end)
end

WorldHubSystem.Hooks = {
	Remotes = {
		WorldAction = {
			Module = "WorldHub",
			Cooldown = 0.3,
			Validate = function(action, index)
				return (action == "Buy" or action == "Craft") and type(index) == "number"
			end,
			Handle = function(player, state, _, action, index)
				if action == "Buy" then
					return WorldHubSystem.Buy(player, state, index)
				end
				return WorldHubSystem.Craft(player, state, index)
			end,
		},
	},
}

return WorldHubSystem
