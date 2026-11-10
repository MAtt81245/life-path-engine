--[[
	MonetizationSystem: the Immortal Treasury (MonetizationConfig).

	Game passes: ownership is runtime only (state.Passes, never saved) and refreshed on
	join and after a purchase.
	- GamePassId > 0: MarketplaceService:UserOwnsGamePassAsync.
	- Studio only: ServerScriptService attribute DevPasses ("CelestialTimekeeper,ImmortalVIP"),
	  the dev console `pass <id> on|off`, or the shop's sandbox toggle grant passes.

	Developer products: MarketplaceService.ProcessReceipt -> GrantProduct. Each
	PurchaseId is remembered in state.Receipts (saved), so a retried receipt never
	grants twice; the receipt is confirmed once the save is written (Studio: always).

	ShopAction remote (client UIController/ShopModal): ("BuyPass" | "BuyProduct", id, sandbox).
	sandbox = true is honoured in Studio only and grants for free (Studio Test Purchase),
	as does any item whose id is still 0 in Studio. PassPrompt is the older pass-only remote.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
local GamePack = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GamePack"))
local BigNum = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("BigNum"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))

local Monetization = Content.Get("MonetizationConfig")

local MonetizationSystem = {}

MonetizationSystem.MaxReceipts = 60

-- Studio-only overrides set with the dev console or the sandbox: [player][passId] = true | false.
local devOverrides = setmetatable({}, { __mode = "k" })

local function devAttributePasses(): { [string]: boolean }
	local owned = {}
	if RunService:IsStudio() then
		for id in string.gmatch(tostring(ServerScriptService:GetAttribute("DevPasses") or ""), "[^,%s]+") do
			owned[id] = true
		end
	end
	return owned
end

local function ownsOnPlatform(player, pass): boolean
	if (pass.GamePassId or 0) <= 0 or typeof(player) ~= "Instance" then
		return false
	end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.GamePassId)
	return ok and owns == true
end

-- Whether the active pack can use an item (Module = engine module it needs).
function MonetizationSystem.Available(item): boolean
	return item.Module == nil or GamePack.IsActive(item.Module)
end

-- Recomputes state.Passes for a player. Returns the owned set.
function MonetizationSystem.Refresh(player)
	local state = PlayerState.Get(player)
	if not state then
		return {}
	end
	local fromAttribute = devAttributePasses()
	local overrides = devOverrides[player] or {}
	local owned = {}
	for _, pass in Monetization.Passes do
		local has = fromAttribute[pass.Id] or ownsOnPlatform(player, pass)
		if RunService:IsStudio() and overrides[pass.Id] ~= nil then
			has = overrides[pass.Id]
		end
		if has then
			owned[pass.Id] = true
		end
	end
	state.Passes = owned
	return owned
end

-- Studio testing toggle (dev console, shop sandbox). Returns (ok, message).
function MonetizationSystem.SetDevPass(player, passId: string, enabled: boolean): (boolean, string)
	if not RunService:IsStudio() then
		return false, "Dev passes only work in Studio."
	end
	if not Monetization.ById[passId] then
		local ids = {}
		for _, pass in Monetization.Passes do
			table.insert(ids, pass.Id)
		end
		return false, "Unknown pass. Passes: " .. table.concat(ids, ", ")
	end
	devOverrides[player] = devOverrides[player] or {}
	devOverrides[player][passId] = enabled
	MonetizationSystem.Refresh(player)
	return true, ("%s %s (Studio test)"):format(Monetization.ById[passId].Name, if enabled then "granted" else "removed")
end

-- Applies one developer product to a state. Returns (ok, message). Never fails
-- silently: a revival that can no longer apply refunds Karma instead.
function MonetizationSystem.GrantProduct(player, state, productId: string): (boolean, string)
	local product = Monetization.ProductsById[productId]
	if not product or not state then
		return false, "Unknown product."
	end
	local grant = product.Grant or {}
	if grant.Karma then
		state.Karma += grant.Karma
		return true, PlayerState.Words("+%d {MetaCurrency} flows into your soul."):format(grant.Karma)
	elseif grant.Revive then
		if PlayerState.Revive(player) then
			return true, PlayerState.Term("ReviveLine")
		end
		local refund = Monetization.ReviveFallbackKarma or 100
		state.Karma += refund
		return true, PlayerState.Words("The moment to revive has passed; +%d {MetaCurrency} instead."):format(refund)
	elseif grant.Pill then
		state.PillBonus = math.max(state.PillBonus or 0, grant.Pill)
		if GamePack.IsEnabled("Cultivation") and not state.Dead then
			local requirement = PlayerState.GetRequirement(state)
			if state.Qi:Lt(requirement) then
				state.Qi = BigNum.from(requirement)
			end
		end
		return true, PlayerState.Words("The Miracle Pill dissolves: {EnergyName} full, +%d%% to your next {advanceTierName}."):format(math.floor(grant.Pill * 100 + 0.5))
	end
	return false, "This product grants nothing."
end

-- Remembers a receipt. Returns false if it was already processed.
function MonetizationSystem.RecordReceipt(state, purchaseId: string): boolean
	state.Receipts = state.Receipts or {}
	if table.find(state.Receipts, purchaseId) then
		return false
	end
	table.insert(state.Receipts, purchaseId)
	while #state.Receipts > MonetizationSystem.MaxReceipts do
		table.remove(state.Receipts, 1)
	end
	return true
end

local function celebrate(player, name: string, message: string)
	PlayerState.Feedback(player, "Purchase", { Name = name, Message = message })
	PlayerState.Notify(player, message, "realm")
end

-- A new pass's golden diamonds are usable this very year.
local function passGranted(state, pass)
	if pass.GoldenActions and not state.Dead then
		state.Actions = math.min(state.Actions + pass.GoldenActions, PlayerState.GetMaxActions(state))
	end
end

local function productByDevId(devProductId: number)
	for _, product in Monetization.Products do
		if product.DevProductId == devProductId and devProductId > 0 then
			return product
		end
	end
	return nil
end

-- Roblox receipt callback (also called by tests with a fake receipt).
function MonetizationSystem.ProcessReceipt(info)
	local product = productByDevId(info.ProductId)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local state = player and PlayerState.Get(player)
	if not product or not state then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(info.PurchaseId)
	if MonetizationSystem.RecordReceipt(state, purchaseId) then
		local _, message = MonetizationSystem.GrantProduct(player, state, product.Id)
		celebrate(player, product.Name, message)
		PlayerState.Push(player)
	end
	-- Confirm once the grant is persisted; a failed save is retried by Roblox (the
	-- remembered receipt keeps the retry from granting twice).
	if RunService:IsStudio() or PlayerState.Save(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Studio Test Purchase: sandbox requested in Studio, or the item has no real id yet.
local function sandboxed(requested: boolean, platformId: number?): boolean
	return RunService:IsStudio() and (requested or (platformId or 0) <= 0)
end

-- ShopAction entry. Returns (ok, message?, kind?).
function MonetizationSystem.Handle(player, state, action: string, id: string, sandbox: boolean?)
	if action == "BuyPass" then
		local pass = Monetization.ById[id]
		if not pass or not MonetizationSystem.Available(pass) then
			return false
		end
		if PlayerState.OwnsPass(state, pass.Id) then
			return false, "You already own " .. pass.Name .. ".", "warn"
		end
		if sandboxed(sandbox == true, pass.GamePassId) then
			MonetizationSystem.SetDevPass(player, pass.Id, true)
			passGranted(state, pass)
			celebrate(player, pass.Name, pass.Name .. " unlocked (Studio test purchase).")
			return true
		elseif (pass.GamePassId or 0) > 0 then
			MarketplaceService:PromptGamePassPurchase(player, pass.GamePassId)
			return true
		end
		return false, pass.Name .. " is not on sale yet.", "warn"
	elseif action == "BuyProduct" then
		local product = Monetization.ProductsById[id]
		if not product or not MonetizationSystem.Available(product) then
			return false
		end
		if product.Grant and product.Grant.Revive and not PlayerState.CanRevive(state) then
			return false, "There is no verdict to defy right now.", "warn"
		end
		if sandboxed(sandbox == true, product.DevProductId) then
			MonetizationSystem.RecordReceipt(state, "studio_" .. game:GetService("HttpService"):GenerateGUID(false))
			local _, message = MonetizationSystem.GrantProduct(player, state, product.Id)
			celebrate(player, product.Name, message .. " (Studio test purchase)")
			return true
		elseif (product.DevProductId or 0) > 0 then
			MarketplaceService:PromptProductPurchase(player, product.DevProductId)
			return true
		end
		return false, product.Name .. " is not on sale yet.", "warn"
	end
	return false
end

local started = false
function MonetizationSystem.Start(remotes: Instance)
	if started then
		return
	end
	started = true
	MarketplaceService.ProcessReceipt = MonetizationSystem.ProcessReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
		if purchased then
			MonetizationSystem.Refresh(player)
			for _, pass in Monetization.Passes do
				if pass.GamePassId == gamePassId then
					local state = PlayerState.Get(player)
					if state then
						passGranted(state, pass)
					end
					celebrate(player, pass.Name, pass.Name .. " unlocked. Thank you!")
				end
			end
			PlayerState.Push(player)
		end
	end)
	local prompt = remotes:FindFirstChild("PassPrompt")
	if prompt then
		prompt.OnServerEvent:Connect(function(player, passId)
			local state = PlayerState.Get(player)
			if state and type(passId) == "string" then
				local _, message, kind = MonetizationSystem.Handle(player, state, "BuyPass", passId, false)
				if message then
					PlayerState.Notify(player, message, kind or "warn")
				end
				PlayerState.Push(player)
			end
		end)
	end
	local shop = remotes:FindFirstChild("ShopAction")
	if not shop then
		shop = Instance.new("RemoteEvent")
		shop.Name = "ShopAction"
		shop.Parent = remotes
	end
	local last = setmetatable({}, { __mode = "k" })
	shop.OnServerEvent:Connect(function(player, action, id, sandbox)
		local state = PlayerState.Get(player)
		if not state or type(action) ~= "string" or type(id) ~= "string" then
			return
		end
		local now = os.clock()
		if last[player] and now - last[player] < 0.5 then
			return
		end
		last[player] = now
		local _, message, kind = MonetizationSystem.Handle(player, state, action, id, sandbox == true)
		if message then
			PlayerState.Notify(player, message, kind or "bad")
		end
		PlayerState.Push(player)
	end)
	ServerScriptService:GetAttributeChangedSignal("DevPasses"):Connect(function()
		for _, player in Players:GetPlayers() do
			MonetizationSystem.Refresh(player)
			PlayerState.Push(player)
		end
	end)
end

return MonetizationSystem
