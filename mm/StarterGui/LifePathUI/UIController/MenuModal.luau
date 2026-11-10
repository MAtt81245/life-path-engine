--[[
	MenuModal: Codes, Characters (the save-slot tarot carousel) and Settings (themes,
	the background Color Changer, portrait frames and the ULTIMATE stat chooser), plus
	the dismissible Starter Pack card on the HUD. Server: Modules/CosmeticSystem
	(CosmeticAction) and MonetizationSystem (ShopAction).
	Init(ctx), Open(tab), Render(snapshot).
]]

local RunService = game:GetService("RunService")

local Modal = {}

local ctx, S, C, Monetization, Frames, Stats
local ui = {}
local state = nil
local tab = "Codes"
local starterDismissed = false

local function scale(x, y) return UDim2.fromScale(x, y) end

local function act(action, arg)
	ctx.Remotes.CosmeticAction:FireServer(action, arg)
end

local function clear()
	for _, child in ui.Body:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
end

local function heading(order: number, text: string)
	return S.autoLabel({ LayoutOrder = order, Text = text, RichText = true, Font = S.Fonts.Heavy, TextColor3 = C.gold, ZIndex = 64, Parent = ui.Body }, 13)
end

local function chips(order: number, list, isOn, onClick)
	local holder = S.new("Frame", { LayoutOrder = order, Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 64, Parent = ui.Body })
	S.new("UIGridLayout", { CellSize = UDim2.new(0.24, 0, 0, 36), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
	for i, entry in list do
		local on, locked = isOn(entry)
		local b = S.button({ LayoutOrder = i, Text = entry.Label .. (if locked then " (locked)" else ""), Font = S.Fonts.Bold, ZIndex = 65, Parent = holder },
			if on then C.gold else C.card1, if on then C.gold2 else C.card2, 13, if on then C.dark else (if locked then C.muted else C.text))
		b.Activated:Connect(function() if not locked then onClick(entry) end end)
	end
	return holder
end

function Modal.Draw()
	if not ui.Overlay.Visible or not state then return end
	clear()
	for name, b in ui.Tabs do
		S.paint(b, if name == tab then C.gold else C.card1, if name == tab then C.gold2 else C.card2)
		b.TextColor3 = if name == tab then C.dark else C.text
	end
	local cosmetics = state.Cosmetics or {}
	if tab == "Codes" then
		local group = S.panel("Frame", { LayoutOrder = 1, Size = UDim2.new(1, -6, 0, 50), ZIndex = 64, Parent = ui.Body }, C.card1, C.card2, 8, C.green)
		S.padding(group, 10, 5)
		S.label({ Text = "<b>Join the Group</b>  -  +5% power and the Guild Member title (and the free Guildbound frame).", RichText = true, ZIndex = 65, Parent = group, Size = scale(1, 1) }, 13)
		local like = S.panel("Frame", { LayoutOrder = 2, Size = UDim2.new(1, -6, 0, 50), ZIndex = 64, Parent = ui.Body }, C.card1, C.card2, 8, C.gold)
		S.padding(like, 10, 5)
		S.label({ Text = "<b>Enjoying the game?</b>  -  a like helps others find it. Codes work either way.", RichText = true, ZIndex = 65, Parent = like, Size = scale(1, 1) }, 13)
		heading(3, "ENTER A CODE")
		local row = S.new("Frame", { LayoutOrder = 4, Size = UDim2.new(1, -6, 0, 40), BackgroundTransparency = 1, ZIndex = 64, Parent = ui.Body })
		local box = S.new("TextBox", { Text = "", PlaceholderText = "Type a code...", ClearTextOnFocus = false, Font = S.Fonts.Bold, TextScaled = true, TextColor3 = C.text,
			PlaceholderColor3 = C.muted, BackgroundColor3 = C.inset, Size = scale(0.68, 1), ZIndex = 65, Parent = row })
		S.new("UICorner", { CornerRadius = UDim.new(0, 6), Parent = box })
		S.new("UITextSizeConstraint", { MaxTextSize = 18, Parent = box })
		local redeem = S.button({ Text = "Redeem", Font = S.Fonts.Heavy, Position = scale(0.7, 0), Size = scale(0.3, 1), ZIndex = 65, Parent = row }, nil, nil, 16)
		redeem.Activated:Connect(function()
			if box.Text ~= "" then act("Code", box.Text); box.Text = "" end
		end)
		local used = {}
		for code in state.CodesUsed or {} do table.insert(used, code) end
		S.autoLabel({ LayoutOrder = 5, Text = if #used > 0 then "Redeemed: " .. table.concat(used, ", ") else "No codes redeemed yet.", TextColor3 = C.muted, ZIndex = 64, Parent = ui.Body }, 12)
	elseif tab == "Characters" then
		heading(1, "YOUR CHARACTERS  -  every slot shares your Legacy, Grimoire and World Chronicle")
		local holder = S.new("Frame", { LayoutOrder = 2, Size = UDim2.new(1, -6, 0, 230), BackgroundTransparency = 1, ZIndex = 64, Parent = ui.Body })
		local layout = S.list(holder, UDim.new(0.03, 0), true)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		for n, info in state.SlotCards or {} do
			-- A tarot card: tall, framed, tilted a little.
			local tarot = S.panel("Frame", { LayoutOrder = n, Size = scale(0.28, 1), Rotation = (n - 2) * 3, ZIndex = 65, Parent = holder },
				if info.Active then C.panel1 else C.card2, C.bg2, 14, if info.Active then C.gold else C.stroke)
			S.padding(tarot, 10, 10)
			S.label({ Text = ("%s"):format(({ "I", "II", "III" })[n]), Font = S.Fonts.Title, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Center, Size = scale(1, 0.16), ZIndex = 66, Parent = tarot }, 26)
			local body = if not info.Owned then "Locked\nSave Slot " .. n .. "\n99 R$ in the Trove"
				elseif info.Empty then "An empty fate\nwaiting to be lived"
				else ("%s\nAge %s%s"):format(S.escape(info.Name or "?"), tostring(info.Age or 0), if info.Dead then "\n(deceased)" else "")
			S.label({ Text = body, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = if info.Owned then C.text else C.muted, Position = scale(0, 0.2), Size = scale(1, 0.55), ZIndex = 66, Parent = tarot }, 16)
			local b = S.button({ Text = if info.Active then "Playing" elseif not info.Owned then "Unlock" elseif info.Empty then "Begin" else "Play", Font = S.Fonts.Heavy,
				Position = scale(0.05, 0.8), Size = scale(0.9, 0.2), ZIndex = 66, Parent = tarot }, nil, nil, 15)
			S.setEnabled(b, not info.Active)
			b.Activated:Connect(function()
				if info.Active then return end
				if not info.Owned then
					if ctx.OpenShop then ctx.OpenShop() end
				else
					act("Slot", n)
				end
			end)
		end
	else
		heading(1, "INTERFACE THEME")
		local themes = {}
		for _, theme in Monetization.Themes do
			table.insert(themes, { Label = theme.Name, Id = theme.Id, Pass = theme.Pass })
		end
		chips(2, themes, function(entry)
			return (cosmetics.Theme or "Moonlight") == entry.Id, entry.Pass ~= nil and not (state.Passes and state.Passes[entry.Pass])
		end, function(entry) act("Theme", entry.Id) end)
		heading(3, "BACKGROUND COLOR CHANGER (free)")
		local backdrops = {}
		for _, id in Monetization.Backdrops do table.insert(backdrops, { Label = id, Id = id }) end
		chips(4, backdrops, function(entry) return (cosmetics.Backdrop or "Void") == entry.Id, false end, function(entry) act("Backdrop", entry.Id) end)
		heading(5, "PORTRAIT FRAME")
		local frames = { { Label = "None", Id = "None" } }
		for _, frame in Monetization.Frames do
			local owned = (cosmetics.Frames or {})[frame.Id] == true or (frame.Free == "Group" and state.Flags and state.Flags.GuildMember)
			table.insert(frames, { Label = frame.Name, Id = frame.Id, Locked = not owned })
		end
		chips(6, frames, function(entry) return (cosmetics.Frame or "None") == entry.Id, entry.Locked end, function(entry) act("Frame", entry.Id) end)
		local ultimate = Monetization.ById.Ultimate
		if ultimate and state.Passes and state.Passes.Ultimate and state.Age == 0 and not (state.Modules.Birth and state.Modules.Birth.StatsChosen) then
			heading(7, ("ULTIMATE: CHOOSE YOUR STARTING ATTRIBUTES (%d-%d)"):format(ultimate.ChooseStats.Min, ultimate.ChooseStats.Max))
			local picks = {}
			for i, stat in Stats.Order do
				local row = S.new("Frame", { LayoutOrder = 7 + i, Size = UDim2.new(1, -6, 0, 30), BackgroundTransparency = 1, ZIndex = 64, Parent = ui.Body })
				S.label({ Text = Stats.Stats[stat].Name, Size = scale(0.5, 1), ZIndex = 65, Parent = row }, 13)
				local box = S.new("TextBox", { Text = tostring(ultimate.ChooseStats.Min), Font = S.Fonts.Bold, TextScaled = true, TextColor3 = C.text, BackgroundColor3 = C.inset,
					Position = scale(0.55, 0.1), Size = scale(0.2, 0.8), ZIndex = 65, Parent = row })
				picks[stat] = box
			end
			local confirm = S.button({ LayoutOrder = 40, Text = "Set my starting attributes", Font = S.Fonts.Heavy, Size = UDim2.new(1, -6, 0, 36), ZIndex = 64, Parent = ui.Body }, nil, nil, 15)
			confirm.Activated:Connect(function()
				local levels = {}
				for stat, box in picks do levels[stat] = tonumber(box.Text) end
				act("ChooseStats", levels)
			end)
		end
	end
end

function Modal.Init(context)
	ctx = context
	S = ctx.Style
	C = S.C
	Monetization = ctx.Config.Monetization
	Stats = ctx.Config.Stats
	Frames = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("PortraitFrames"))
	local overlay = S.new("Frame", { Name = "MenuModal", Size = scale(1, 1), BackgroundColor3 = C.ink, BackgroundTransparency = 0.25, BorderSizePixel = 0,
		ZIndex = 62, Visible = false, Parent = ctx.Gui })
	ctx.Shield.Attach(overlay)
	-- Phones: a bigger card with taller tabs sized here (44 px minimums ran into the body).
	local phone = require(game:GetService("ReplicatedStorage").Shared.Responsive).Current().Kind == "Phone"
	local tabH, bodyY = if phone then 0.11 else 0.08, if phone then 0.14 else 0.11
	local card = S.new("Frame", { Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = scale(0.5, 0.5), Size = if phone then scale(0.86, 0.92) else scale(0.66, 0.8), ZIndex = 63, Parent = overlay })
	S.padding(card, 16, 12)
	ctx.Theme.frame(card, 14, C.panel1, C.bg2)
	local close = S.ghostButton({ Text = "Close", Position = scale(0.84, 0), Size = scale(0.16, tabH), ZIndex = 64, Parent = card }, 14)
	close:SetAttribute("TouchSafe", true)
	close.Activated:Connect(function() overlay.Visible = false end)
	ui.Tabs = {}
	for i, name in { "Codes", "Characters", "Settings" } do
		local b = S.ghostButton({ Text = name, Position = scale((i - 1) * 0.27, 0), Size = scale(0.26, tabH), ZIndex = 64, Parent = card }, 15)
		b:SetAttribute("TouchSafe", true)
		b.Activated:Connect(function() tab = name; Modal.Draw() end)
		ui.Tabs[name] = b
	end
	ui.Body = S.new("ScrollingFrame", { Name = "Body", Position = scale(0, bodyY), Size = scale(1, 1 - bodyY), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 63, Parent = card })
	S.list(ui.Body, UDim.new(0, 8))
	ui.Overlay = overlay

	-- Starter Pack chip (dismissible; gone once bought), docked in the header's Offer
	-- slot (ChronicleHUD) so it never covers a page; details show on hover / tap-hold.
	local starter = Monetization.ProductsById.StarterPack
	local slot = ctx.Gui:FindFirstChild("ChronicleHeader") and ctx.Gui.ChronicleHeader:FindFirstChild("Offer")
	if starter and slot then
		local cardFrame = S.new("Frame", { Name = "StarterCard", BackgroundTransparency = 1, Size = scale(1, 1), Visible = false, Parent = slot })
		local buy = S.button({ Name = "Buy", Text = ("<b>Starter Pack</b>  %d R$"):format(starter.Robux), RichText = true, Font = S.Fonts.Bold,
			AnchorPoint = Vector2.new(0, 0.5), Position = scale(0.04, 0.5), Size = scale(0.76, 0.86), Parent = cardFrame }, nil, nil, 12)
		buy.Activated:Connect(function()
			ctx.Remotes.ShopAction:FireServer("BuyProduct", starter.Id, RunService:IsStudio())
		end)
		if ctx.AttachTooltip then
			ctx.AttachTooltip(cardFrame, function()
				return ("%s (%d R$, once per account): Elixir of Prodigy, draughts and 300 gold."):format(starter.Name, starter.Robux)
			end)
		end
		local dismiss = S.ghostButton({ Name = "Dismiss", Text = "x", AnchorPoint = Vector2.new(0, 0.5), Position = scale(0.83, 0.5), Size = scale(0.16, 0.7), Parent = cardFrame }, 12)
		-- The header slot sizes both (a 44 px touch minimum would spill out of the header).
		buy:SetAttribute("TouchSafe", true)
		dismiss:SetAttribute("TouchSafe", true)
		buy:SetAttribute("PhoneText", ("<b>Starter</b> %d R$"):format(starter.Robux)) -- ChronicleHUD.ApplyProfile
		dismiss.Activated:Connect(function()
			starterDismissed = true
			cardFrame.Visible = false
		end)
		ui.Starter = cardFrame
	end
end

function Modal.Open(name: string?)
	tab = name or tab
	ui.Overlay.Visible = true
	Modal.Draw()
end

local lastTheme, lastBackdrop, lastFrame = nil, nil, nil
function Modal.Render(s)
	state = s
	local cosmetics = s.Cosmetics or {}
	-- Cosmetics follow the server: theme, background tint, portrait frame.
	local Switcher = require(game:GetService("ReplicatedStorage").Shared.ThemeSwitcher)
	if cosmetics.Theme ~= lastTheme then
		lastTheme = cosmetics.Theme
		Switcher.Apply(cosmetics.Theme)
	end
	if cosmetics.Backdrop ~= lastBackdrop then
		lastBackdrop = cosmetics.Backdrop
		Switcher.SetBackdrop(cosmetics.Backdrop)
	end
	if cosmetics.Frame ~= lastFrame then
		lastFrame = cosmetics.Frame
		local avatar = ctx.Gui:FindFirstChild("Sheet") and ctx.Gui.Sheet:FindFirstChild("Avatar")
		if avatar then Frames.Build(avatar, cosmetics.Frame) end
	end
	if ui.Starter then
		ui.Starter.Visible = not starterDismissed and not (s.Purchases and s.Purchases.StarterPack) and not s.Dead
	end
	Modal.Draw()
end

return Modal
