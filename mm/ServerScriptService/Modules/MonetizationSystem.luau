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
-- Gifts: a product bought for another player in this server ([buyer] = { Product, Target }).
local pendingGift = setmetatable({}, { __mode = "k" })

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
	MonetizationSystem.ApplyPasses(state)
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
	elseif grant.BirthReroll then
		local CreationSystem = require(script.Parent:WaitForChild("CreationSystem"))
		if CreationSystem.Reroll(player, state) then
			return true, "Fate rerolled: new cards are on the table."
		end
		-- Born already (receipt arrived late): never lose the purchase.
		local refund = (Monetization.BirthRerollMetaCost or 30) * 2
		state.Karma += refund
		return true, PlayerState.Words("You were already born; +%d {MetaCurrency} instead."):format(refund)
	elseif grant.Rewind then
		local PathSystem = require(script.Parent:WaitForChild("PathSystem"))
		local ok = PathSystem.Rewind(player, state, PathSystem.Target(player))
		if ok then
			PlayerState.Push(player, true) -- the chronicle was trimmed: resend the log
			return true, "You returned to this path. Choose again."
		end
		-- The moment faded before the receipt arrived: never lose the purchase.
		local refund = Monetization.ReviveFallbackKarma or 100
		state.Karma += refund
		return true, PlayerState.Words("That moment has faded; +%d {MetaCurrency} instead."):format(refund)
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
	-- 3.0 micro-impulse grants (any mix of these keys).
	local parts = {}
	if grant.Money then
		state.Money += grant.Money
		table.insert(parts, "+" .. PlayerState.FormatMoney(grant.Money))
	end
	if grant.Actions and not state.Dead then
		state.Actions += grant.Actions
		table.insert(parts, ("+%d actions this year"):format(grant.Actions))
	end
	if grant.HealFull and not state.Dead then
		state.Health = PlayerState.GetMaxHealth(state)
		table.insert(parts, "full health")
	end
	if grant.Lifespan then
		state.BonusLifespan = (state.BonusLifespan or 0) + grant.Lifespan
		table.insert(parts, ("+%d years of lifespan"):format(grant.Lifespan))
	end
	if grant.SkillXpAll and GamePack.IsActive("Skills") then
		local SkillSystem = require(script.Parent:WaitForChild("SkillSystem"))
		for _, skill in Content.Get("SkillsConfig").Order do
			SkillSystem.Grant(player, state, skill, grant.SkillXpAll)
		end
		table.insert(parts, ("+%d XP to every skill"):format(grant.SkillXpAll))
	end
	for itemId, count in grant.Items or {} do
		if GamePack.IsActive("Inventory") and PlayerState.AddItem(state, itemId, count) > 0 then
			table.insert(parts, ("%dx %s"):format(count, Content.Get("ItemsConfig").ById[itemId].Name))
		end
	end
	if grant.Frame then
		state.Cosmetics = state.Cosmetics or {}
		state.Cosmetics.Frames = state.Cosmetics.Frames or {}
		state.Cosmetics.Frames[grant.Frame] = true
		table.insert(parts, "a new portrait frame")
	end
	if grant.MaxAffinity and GamePack.IsActive("Arcana") then
		local ArcanaSystem = require(script.Parent:WaitForChild("ArcanaSystem"))
		local data = ArcanaSystem.Data(state)
		for element in data.Affinity do
			if ArcanaSystem.ElementOpen(state, element) then data.Affinity[element] = 100 end
		end
		table.insert(parts, "every open element at affinity 100")
	end
	if #parts > 0 then
		if product.OneTime then
			state.Purchases = state.Purchases or {}
			state.Purchases[product.Id] = true
		end
		return true, product.Name .. ": " .. table.concat(parts, ", ")
	end
	return false, "This product grants nothing."
end

-- Per-life buff sources of owned passes ("Pass:<id>") and their birth gifts.
function MonetizationSystem.ApplyPasses(state)
	for _, pass in Monetization.Passes do
		if pass.Buffs then
			PlayerState.SetLifeBuff(state, "Pass:" .. pass.Id, pass.Name, if PlayerState.OwnsPass(state, pass.Id) then pass.Buffs else nil)
		end
	end
end

function MonetizationSystem.BirthGifts(state)
	for _, pass in Monetization.Passes do
		if PlayerState.OwnsPass(state, pass.Id) and MonetizationSystem.Available(pass) then
			local birth = pass.Birth or {}
			if birth.SkillLevels and GamePack.IsActive("Skills") then
				local data = require(script.Parent:WaitForChild("SkillSystem")).Data(state)
				for skill, level in birth.SkillLevels do
					data.Levels[skill].Level = math.max(data.Levels[skill].Level, level)
				end
			end
			if birth.Affinity and GamePack.IsActive("Arcana") then
				local data = require(script.Parent:WaitForChild("ArcanaSystem")).Data(state)
				for element, value in data.Affinity do
					data.Affinity[element] = math.min(100, value + birth.Affinity)
				end
			end
			if pass.CreationSpins and state.Creation and not state.Creation.Done then
				state.Creation.Spins = (state.Creation.Spins or 0) + pass.CreationSpins
			end
		end
	end
end

table.insert(PlayerState.NewLifeHooks, function(state)
	MonetizationSystem.ApplyPasses(state)
	MonetizationSystem.BirthGifts(state)
end)

-- Second Life: once per life, an untimely death becomes a narrow escape.
table.insert(PlayerState.DeathEscapeHooks, function(player, state, cause, options)
	local pass = Monetization.ById.SecondLife
	if not pass or not PlayerState.OwnsPass(state, pass.Id) or (options and options.Final) or (state.Flags and state.Flags.SecondLifeUsed) then
		return false
	end
	state.Flags.SecondLifeUsed = true
	state.Health = math.max(1, math.floor(PlayerState.GetMaxHealth(state) * 0.3))
	PlayerState.Log(player, ("Death reached for you (%s), and missed. Second Life spent for this life."):format(tostring(cause)), "realm")
	return true
end)

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
		-- A pending gift goes to its recipient (if still here); otherwise the buyer keeps it.
		local gift = pendingGift[player]
		local target = gift and gift.Product == product.Id and Players:GetPlayerByUserId(gift.Target)
		local targetState = target and PlayerState.Get(target)
		pendingGift[player] = nil
		if targetState then
			local _, message = MonetizationSystem.GrantProduct(target, targetState, product.Id)
			celebrate(target, product.Name, ("A gift from %s! %s"):format(player.DisplayName, message or ""))
			PlayerState.Notify(player, ("Your gift reached %s."):format(target.DisplayName), "good")
			PlayerState.Push(target)
		else
			local _, message = MonetizationSystem.GrantProduct(player, state, product.Id)
			celebrate(player, product.Name, message)
		end
		PlayerState.Push(player)
	end
	-- Confirm once the grant is persisted; a failed save is retried by Roblox (the
	-- remembered receipt keeps the retry from granting twice).
	if RunService:IsStudio() or PlayerState.Save(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Paid random items (MonetizationConfig RandomItem) follow PolicyService. Tests and
-- Studio sessions without a real player are allowed; a failed lookup on a live server
-- counts as restricted.
local policyCache = setmetatable({}, { __mode = "k" })
function MonetizationSystem.PaidRandomAllowed(player): boolean
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return true
	end
	if policyCache[player] == nil then
		local ok, info = pcall(function()
			return game:GetService("PolicyService"):GetPolicyInfoForPlayerAsync(player)
		end)
		if ok and type(info) == "table" then
			policyCache[player] = info.ArePaidRandomItemsRestricted ~= true
		else
			policyCache[player] = RunService:IsStudio()
		end
	end
	return policyCache[player]
end

-- Studio Test Purchase: sandbox requested in Studio, or the item has no real id yet.
local function sandboxed(requested: boolean, platformId: number?): boolean
	return RunService:IsStudio() and (requested or (platformId or 0) <= 0)
end

function MonetizationSystem.Gift(player, state, productId: string, targetUserId, sandbox: boolean?)
	local product = Monetization.ProductsById[productId]
	if not product or not product.Giftable or not MonetizationSystem.Available(product) then
		return false, "That cannot be gifted.", "warn"
	end
	local target = typeof(targetUserId) == "number" and Players:GetPlayerByUserId(targetUserId)
	local targetState = target and PlayerState.Get(target)
	if not target or target == player or not targetState then
		return false, "Pick another player in this server.", "warn"
	end
	if sandboxed(sandbox == true, product.DevProductId) then
		MonetizationSystem.RecordReceipt(state, "studio_gift_" .. game:GetService("HttpService"):GenerateGUID(false))
		local _, message = MonetizationSystem.GrantProduct(target, targetState, product.Id)
		celebrate(target, product.Name, ("A gift from %s! %s"):format(player.DisplayName, message or ""))
		PlayerState.Push(target)
		return true, ("You gifted %s to %s (Studio test purchase)."):format(product.Name, target.DisplayName), "good"
	elseif (product.DevProductId or 0) > 0 then
		pendingGift[player] = { Product = product.Id, Target = target.UserId }
		MarketplaceService:PromptProductPurchase(player, product.DevProductId)
		return true
	end
	return false, product.Name .. " is not on sale yet.", "warn"
end

-- ShopAction entry. Returns (ok, message?, kind?).
function MonetizationSystem.Handle(player, state, action: string, id: string, sandbox: boolean?, target)
	if action == "Gift" then
		return MonetizationSystem.Gift(player, state, id, target, sandbox)
	end
	if action == "BuyPass" then
		local pass = Monetization.ById[id]
		if not pass or not MonetizationSystem.Available(pass) then
			return false
		end
		if PlayerState.OwnsPass(state, pass.Id) then
			return false, "You already own " .. pass.Name .. ".", "warn"
		end
		if pass.RandomItem and not MonetizationSystem.PaidRandomAllowed(player) then
			return false, "This item is not available in your region.", "warn"
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
		if product.Grant and product.Grant.Rewind then
			local PathSystem = require(script.Parent:WaitForChild("PathSystem"))
			local can, reason = PathSystem.CanRewind(player, state, PathSystem.Target(player))
			if not can then
				return false, reason, "warn"
			end
		end
		if product.RandomItem and not MonetizationSystem.PaidRandomAllowed(player) then
			return false, "This item is not available in your region.", "warn"
		end
		if product.OneTime and state.Purchases and state.Purchases[product.Id] then
			return false, product.Name .. " was already bought on this account.", "warn"
		end
		if product.Grant and product.Grant.BirthReroll then
			local CreationSystem = require(script.Parent:WaitForChild("CreationSystem"))
			if not CreationSystem.Open(state) then
				return false, "You can only reroll before your first breath.", "warn"
			end
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
	shop.OnServerEvent:Connect(function(player, action, id, sandbox, target)
		local state = PlayerState.Get(player)
		if not state or type(action) ~= "string" or type(id) ~= "string" then
			return
		end
		local now = os.clock()
		if last[player] and now - last[player] < 0.5 then
			return
		end
		last[player] = now
		local _, message, kind = MonetizationSystem.Handle(player, state, action, id, sandbox == true, target)
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
