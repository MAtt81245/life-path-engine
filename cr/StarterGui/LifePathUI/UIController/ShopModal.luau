--[[
	ShopModal: the Immortal Treasury (MonetizationConfig), the purchase celebration and
	the death prompt that offers a Miracle Revival. Names and words come from the
	pack's Terms (Treasury / Store / Vault ...).

	The server owns every grant (Modules/MonetizationSystem via the ShopAction remote).
	In Studio a "Studio Test Purchase (Free)" toggle (on by default) makes every
	button a free test purchase, so passes, Karma and revivals can be checked in a
	playtest; live games always go through Roblox's purchase prompt.

	Init(ctx), Render(snapshot), Open(), Close(). UIController adds the header button.
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local PackTheme = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("PackTheme"))
local Responsive = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Responsive"))

local Shop = {}

local ctx, S, C, T, Config, remote
local ui = {}
local state = nil
local sandbox = RunService:IsStudio()
local dismissedDeath = nil -- death key whose verdict prompt was closed

local function scale(x, y) return UDim2.fromScale(x, y) end

-- "{MetaCurrency}" -> the pack's word (MonetizationConfig texts use Terms tokens).
local function words(text: string?): string
	return PackTheme.Words(text or "")
end

local function price(robux: number?): string
	return if sandbox then "Test  ·  Free" else ("R$ %d"):format(robux or 0)
end

local function buy(kind: string, id: string)
	remote:FireServer(kind, id, sandbox)
end

-- One offer card: icon, name, description, optional tag, buy button.
local function offerCard(parent, item, order: number, kind: string)
	local card = S.new("Frame", { Name = item.Id, LayoutOrder = order, Size = scale(0.3, 1), Parent = parent })
	S.decorate(card, C.card1, C.card2, C.stroke, 12, 0.45)
	S.padding(card, 10, 8)
	S.label({ Name = "Icon", Text = words(item.Icon or "{ActionPip}"), TextXAlignment = Enum.TextXAlignment.Center, Size = scale(1, 0.24), Parent = card }, 30)
	S.label({ Name = "ItemName", Text = item.Name, Font = S.Fonts.Title, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Center,
		Position = scale(0, 0.25), Size = scale(1, 0.15), Parent = card }, 18)
	S.label({ Name = "Desc", Text = words(item.Description), TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top, Position = scale(0, 0.41), Size = scale(1, 0.33), Parent = card }, 12)
	if item.Tag then
		local tag = S.label({ Name = "Tag", Text = string.upper(item.Tag), Font = S.Fonts.Bold, TextColor3 = C.dark, TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 4, 0, -4), Size = scale(0.44, 0.1), ZIndex = 3, Parent = card }, 11)
		S.decorate(tag, C.qi1, C.qi2, C.ink, 6, 0.3)
	end
	local button = S.button({ Name = "Buy", Text = price(item.Robux), Font = S.Fonts.Heavy, Position = scale(0, 0.78), Size = scale(1, 0.22), Parent = card }, nil, nil, 15)
	button.Activated:Connect(function()
		buy(kind, item.Id)
	end)
	return { Card = card, Button = button, Item = item }
end

local function row(parent, name: string, y: number, height: number)
	local frame = S.new("Frame", { Name = name, BackgroundTransparency = 1, Position = scale(0, y), Size = scale(1, height), Parent = parent })
	local layout = S.list(frame, UDim.new(0.025, 0), true)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	return frame
end

local function available(item): boolean
	return item.Module == nil or ctx.GamePack.IsActive(item.Module)
end

local function buildShop(screen)
	ui.Overlay = S.new("TextButton", { Name = "TreasuryOverlay", Text = "", AutoButtonColor = false, Size = scale(1, 1), BackgroundColor3 = C.ink,
		BackgroundTransparency = 0.35, BorderSizePixel = 0, Visible = false, Parent = screen })
	-- Phones (Shared/Responsive): a wider card whose offers scroll in a taller body
	-- (applied in Shop.Init and again whenever the screen changes).
	local card = S.new("Frame", { Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = scale(0.5, 0.5),
		Size = scale(0.76, 0.86), Parent = ui.Overlay })
	S.padding(card, 18, 14)
	ctx.Theme.frame(card, 16, C.panel1, C.bg2)
	ui.Pop = S.new("UIScale", { Parent = card })
	ui.Card = card

	S.label({ Name = "Title", Text = ("%s  %s  %s"):format(T.ActionPip, string.upper(T.ShopName), T.ActionPip), Font = S.Fonts.Title, TextColor3 = C.gold,
		TextXAlignment = Enum.TextXAlignment.Center, Size = scale(1, 0.08), Parent = card }, 30)
	S.label({ Name = "Tagline", Text = T.ShopTagline, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Center,
		Position = scale(0, 0.08), Size = scale(1, 0.045), Parent = card }, 14)
	ui.Balance = S.label({ Name = "Balance", Text = "", Font = S.Fonts.Bold, TextColor3 = C.gold, Position = scale(0, 0.01), Size = scale(0.3, 0.05), Parent = card }, 15)
	local close = S.ghostButton({ Name = "Close", Text = "×", AnchorPoint = Vector2.new(1, 0), Position = scale(1, 0), Size = scale(0.05, 0.07), Parent = card }, 18)
	close.Activated:Connect(Shop.Close)
	ui.Overlay.Activated:Connect(function() end) -- swallow clicks behind the card

	local body = S.new("ScrollingFrame", { Name = "Body", Position = scale(0, 0.14), Size = scale(1, 0.86), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = C.stroke,
		CanvasSize = scale(0, 1), Parent = card })
	ui.Body = body
	S.label({ Name = "PassHeader", Text = "Permanent Passes", Font = S.Fonts.Title, TextColor3 = C.text, Position = scale(0, 0), Size = scale(1, 0.058), Parent = body }, 19)
	local passes = row(body, "Passes", 0.07, 0.384)
	ui.Passes = {}
	for i, pass in Config.Monetization.Passes do
		if available(pass) then
			table.insert(ui.Passes, offerCard(passes, pass, i, "BuyPass"))
		end
	end

	S.label({ Name = "ProductHeader", Text = ("%s Packs & Miracles"):format(T.MetaCurrency), Font = S.Fonts.Title, TextColor3 = C.text,
		Position = scale(0, 0.477), Size = scale(1, 0.058), Parent = body }, 19)
	local products = row(body, "Products", 0.547, 0.349)
	ui.Products = {}
	local shown = {}
	for _, product in Config.Monetization.Products do
		if not product.Hidden and available(product) then
			table.insert(shown, product)
		end
	end
	for i, product in shown do
		local entry = offerCard(products, product, i, "BuyProduct")
		entry.Card.Size = scale((1 - 0.025 * (#shown - 1)) / #shown, 1)
		table.insert(ui.Products, entry)
	end

	-- Studio Test Purchase toggle (never shown in a live game).
	ui.Sandbox = S.ghostButton({ Name = "SandboxToggle", Text = "", Position = scale(0, 0.924), Size = scale(0.42, 0.076), Visible = RunService:IsStudio(), Parent = body }, 13)
	ui.Sandbox.Activated:Connect(function()
		sandbox = not sandbox
		Shop.Render(state)
	end)
	ui.Footer = S.label({ Name = "Footer", Text = "Purchases are processed by Roblox. Passes are permanent; packs can be bought again.", TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Right, Position = scale(0.44, 0.924), Size = scale(0.56, 0.076), Parent = body }, 11)
end

-- The purchase celebration: a golden banner that pops in and fades.
local celebrateToken = 0
local function celebrate(data)
	celebrateToken += 1
	local token = celebrateToken
	ui.CelebrateName.Text = ("%s  %s  %s"):format(T.ActionPip, data.Name or T.ShopName, T.ActionPip)
	ui.CelebrateText.Text = data.Message or ""
	ui.Celebrate.Visible = true
	ui.CelebratePop.Scale = 0.6
	TweenService:Create(ui.CelebratePop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(3, function()
		if token == celebrateToken then
			ui.Celebrate.Visible = false
		end
	end)
end

local function buildCelebration(screen)
	local banner = S.new("Frame", { Name = "Celebration", AnchorPoint = Vector2.new(0.5, 0), Position = scale(0.5, 0.06), Size = scale(0.42, 0.14),
		Visible = false, ZIndex = 20, Parent = screen })
	S.decorate(banner, C.gold, C.gold2, C.text, 14, 0)
	S.padding(banner, 14, 8)
	ui.CelebratePop = S.new("UIScale", { Parent = banner })
	S.label({ Name = "Kicker", Text = "PURCHASE COMPLETE", Font = S.Fonts.Heavy, TextColor3 = C.dark, TextXAlignment = Enum.TextXAlignment.Center,
		Size = scale(1, 0.24), ZIndex = 21, Parent = banner }, 13)
	ui.CelebrateName = S.label({ Name = "ItemName", Text = "", Font = S.Fonts.Title, TextColor3 = C.dark, TextXAlignment = Enum.TextXAlignment.Center,
		Position = scale(0, 0.24), Size = scale(1, 0.4), ZIndex = 21, Parent = banner }, 24)
	ui.CelebrateText = S.label({ Name = "Message", Text = "", Font = S.Fonts.Bold, TextColor3 = C.dark, TextXAlignment = Enum.TextXAlignment.Center,
		Position = scale(0, 0.66), Size = scale(1, 0.34), ZIndex = 21, Parent = banner }, 13)
	ui.Celebrate = banner
end

-- Death prompt: Heaven's Verdict with the Miracle Revival offer.
local function buildVerdict(screen)
	local overlay = S.new("Frame", { Name = "VerdictOverlay", Size = scale(1, 1), BackgroundColor3 = C.ink, BackgroundTransparency = 0.3,
		BorderSizePixel = 0, Active = true, Visible = false, ZIndex = 10, Parent = screen })
	local card = S.new("Frame", { Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = scale(0.5, 0.5),
		Size = scale(0.44, 0.5), ZIndex = 10, Parent = overlay })
	ui.VerdictCard = card
	S.padding(card, 18, 14)
	ctx.Theme.frame(card, 16, C.panel1, C.bg2)
	ui.VerdictPop = S.new("UIScale", { Parent = card })
	S.label({ Name = "Title", Text = T.ReviveTitle, Font = S.Fonts.Title, TextColor3 = C.red, TextXAlignment = Enum.TextXAlignment.Center,
		Size = scale(1, 0.16), ZIndex = 11, Parent = card }, 30)
	ui.VerdictCause = S.label({ Name = "Cause", Text = "", TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top,
		Position = scale(0, 0.18), Size = scale(1, 0.26), ZIndex = 11, Parent = card }, 15)
	local offer = Config.Monetization.ProductsById.MiracleRevival
	ui.ReviveButton = S.button({ Name = "Revive", Text = "", Font = S.Fonts.Heavy, Position = scale(0.06, 0.47), Size = scale(0.88, 0.2), ZIndex = 11, Parent = card }, nil, nil, 18)
	ui.ReviveButton.Activated:Connect(function()
		buy("BuyProduct", offer.Id)
	end)
	ui.ReviveHint = S.label({ Name = "Hint", Text = "", TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Center,
		Position = scale(0, 0.69), Size = scale(1, 0.09), ZIndex = 11, Parent = card }, 13)
	local accept = S.ghostButton({ Name = "Accept", Text = T.AcceptFate, Position = scale(0.3, 0.83), Size = scale(0.4, 0.15), ZIndex = 11, Parent = card }, 14)
	accept.Activated:Connect(function()
		dismissedDeath = ui.DeathKey
		overlay.Visible = false
	end)
	ui.Verdict = overlay
end

function Shop.Init(context)
	ctx = context
	S, Config = ctx.Style, ctx.Config
	C, T = S.C, S.Terms
	remote = ctx.Remotes:WaitForChild("ShopAction")
	local screen = S.new("ScreenGui", { Name = "TreasuryUI", ResetOnSpawn = false, DisplayOrder = 40, IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = ctx.Gui.Parent })
	ui.Screen = screen
	buildShop(screen)
	buildVerdict(screen)
	buildCelebration(screen)
	Responsive.Watch(function(profile)
		local phone = profile.Kind == "Phone"
		ui.Card.Size = if phone then scale(0.94, 0.96) else scale(0.76, 0.86)
		ui.Body.CanvasSize = scale(0, if phone then 1.9 else 1)
		ui.VerdictCard.Size = if phone then scale(0.66, 0.86) else scale(0.44, 0.5)
	end)
	local feedback = ctx.Remotes:FindFirstChild("Feedback")
	if feedback then
		feedback.OnClientEvent:Connect(function(cue, data)
			if cue == "Purchase" then
				celebrate(data or {})
			end
		end)
	end
end

function Shop.Open()
	ui.Overlay.Visible = true
	ui.Pop.Scale = 0.92
	TweenService:Create(ui.Pop, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	Shop.Render(state)
end

function Shop.Close()
	ui.Overlay.Visible = false
end

function Shop.IsOpen(): boolean
	return ui.Overlay ~= nil and ui.Overlay.Visible
end

function Shop.Render(s)
	state = s
	if not s then
		return
	end
	ui.Balance.Text = ("%s %d %s"):format(T.MetaCurrencyIcon, s.Karma, T.MetaCurrency)
	for _, entry in ui.Passes do
		local owned = s.Passes and s.Passes[entry.Item.Id]
		entry.Button.Text = if owned then "Owned  ✓" else price(entry.Item.Robux)
		S.setEnabled(entry.Button, not owned)
		local stroke = entry.Card:FindFirstChildOfClass("UIStroke")
		stroke.Color, stroke.Transparency = if owned then C.qi1 else C.stroke, if owned then 0.1 else 0.45
	end
	for _, entry in ui.Products do
		entry.Button.Text = price(entry.Item.Robux)
		local pill = entry.Item.Grant and entry.Item.Grant.Pill
		S.setEnabled(entry.Button, not (pill and s.Dead))
	end
	ui.Sandbox.Text = ("%s  Studio Test Purchase (Free)"):format(if sandbox then "☑" else "☐")
	ui.Sandbox.TextColor3 = if sandbox then C.green else C.muted

	-- Heaven's Verdict: once per untimely death, until a Wheel action accepts it.
	local key = ("%d|%d|%s"):format(s.Lives, s.Age, tostring(s.DeathCause))
	ui.DeathKey = key
	local offer = Config.Monetization.ProductsById.MiracleRevival
	local show = s.Dead and s.Revivable and dismissedDeath ~= key
	if show and not ui.Verdict.Visible then
		Shop.Close()
		ui.VerdictPop.Scale = 0.9
		TweenService:Create(ui.VerdictPop, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	ui.Verdict.Visible = show == true
	if show then
		ui.VerdictCause.Text = ("%s fell at age %d.\n%s"):format(s.Name, s.Age, s.DeathCause or "")
		ui.ReviveButton.Text = ("%s  ·  %s"):format(T.ReviveButton, price(offer and offer.Robux))
		ui.ReviveHint.Text = T.ReviveHint .. "  ·  once per life"
	end
end

return Shop
