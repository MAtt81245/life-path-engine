--[[
	WorldModal: the World hub (WorldHubConfig; Modules/WorldHubSystem via WorldQuery /
	WorldAction, InventoryAction for selling). Four tabs:
	World (the global event and Wanted Posters), Merchant (three rotating offers),
	Crafting (materials -> trinkets, Sell +1 / Sell All), Friends (friend and group
	bonuses, Weekly Champions). A shielded popup; opened from the Today page.
	Init(ctx), Open(), Render(snapshot).
]]

local Modal = {}

local ctx, S, C, Hub, Items
local ui = {}
local state = nil
local info = nil
local tab = "World"

local function scale(x, y) return UDim2.fromScale(x, y) end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return ("%dh %02dm"):format(math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
end

local function row(order: number, text: string, buttonText: string?, enabled: boolean?, onClick, color: Color3?)
	local frame = S.panel("Frame", { LayoutOrder = order, Size = UDim2.new(1, -6, 0, 54), ZIndex = 64, Parent = ui.Body }, C.card1, C.card2, 8, color)
	S.padding(frame, 10, 5)
	S.label({ Text = text, RichText = true, Size = scale(if buttonText then 0.7 else 1, 1), ZIndex = 65, Parent = frame }, 14)
	if buttonText then
		local b = S.button({ Text = buttonText, Font = S.Fonts.Bold, Position = scale(0.72, 0.1), Size = scale(0.28, 0.8), ZIndex = 65, Parent = frame }, nil, nil, 13)
		S.setEnabled(b, enabled ~= false)
		b.Activated:Connect(function() if b.Active and onClick then onClick() end end)
	end
	return frame
end

local function note(order: number, text: string, color: Color3?)
	return S.autoLabel({ LayoutOrder = order, Text = text, RichText = true, TextColor3 = color or C.muted, ZIndex = 64, Parent = ui.Body }, 13)
end

local function refresh()
	task.spawn(function()
		local ok, result = pcall(function() return ctx.Remotes:WaitForChild("WorldQuery", 10):InvokeServer() end)
		if ok and result then
			info = result
			Modal.Draw()
		end
	end)
end

function Modal.Draw()
	if not ui.Overlay.Visible then return end
	for _, child in ui.Body:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	for name, b in ui.Tabs do
		S.paint(b, if name == tab then C.gold else C.card1, if name == tab then C.gold2 else C.card2)
		b.TextColor3 = if name == tab then C.dark else C.text
	end
	if not info or not state then
		note(1, "Asking the town crier...")
		return
	end
	local items = (state.Inventory and state.Inventory.Items) or {}
	if tab == "World" then
		row(1, ("<b>%s</b>  -  %s\n%s"):format(info.Event.Name, info.Event.Text,
			if info.Active then ("<font color=\"#%s\">ACTIVE for %s</font>"):format(C.green:ToHex(), clock(info.EndsIn)) else ("next event in %s"):format(clock(info.EndsIn))), nil, nil, nil, C.gold)
		note(2, "<b>WANTED POSTERS</b>  -  beat these foes for Bounty Seals (new posters every 2 hours)")
		for i, poster in info.Posters do
			row(2 + i, ("%s  <b>%s</b>\nReward: %d Bounty Seals"):format(poster.Icon, poster.Name, poster.Seals),
				if poster.Done then "Claimed" else "Hunt", not poster.Done and ctx.OpenBattles ~= nil, function()
					ui.Overlay.Visible = false
					ctx.OpenBattles()
				end, C.crimson1)
		end
	elseif tab == "Merchant" then
		note(1, ("<b>TRAVELING MERCHANT</b>  -  new wares in %s"):format(clock(info.Restock)))
		for i, offer in info.Merchant do
			row(1 + i, ("<b>%s</b>  -  %s\n%s"):format(offer.Name, S.money(offer.Price), offer.Description),
				if offer.Sold then "Sold out" else "Buy", not offer.Sold and (state.Money or 0) >= offer.Price and not state.Dead, function()
					ctx.Remotes.WorldAction:FireServer("Buy", i)
					task.delay(0.4, refresh)
				end)
		end
	elseif tab == "Crafting" then
		note(1, "<b>REGIONAL CRAFTING</b>  -  turn monster drops into trinkets")
		for i, recipe in Hub.Recipes do
			local parts, can = {}, true
			for itemId, count in recipe.Needs do
				local have = items[itemId] or 0
				if have < count then can = false end
				table.insert(parts, ("%s %d/%d"):format(Items.ById[itemId].Name, have, count))
			end
			local result = Items.ById[recipe.Result]
			row(1 + i, ("<b>%s</b>  -  %s\n%s"):format(result.Name, result.Description, table.concat(parts, ", ")), "Craft", can and not state.Dead, function()
				ctx.Remotes.WorldAction:FireServer("Craft", i)
			end)
		end
		note(10, "<b>MATERIALS</b>")
		local order = 10
		for _, item in Items.Items do
			local have = items[item.Id] or 0
			if item.Category == "Material" and have > 0 then
				order += 1
				local frame = row(order, ("<b>%s</b> x%d  -  sells for %s each"):format(item.Name, have, S.money(Items.SellPrice(item) or 0)), "Sell +1", not state.Dead, function()
					ctx.Remotes.InventoryAction:FireServer("Sell", item.Id)
				end)
				local all = S.ghostButton({ Text = "Sell All", Position = scale(0.44, 0.1), Size = scale(0.26, 0.8), ZIndex = 65, Parent = frame }, 13)
				all.Activated:Connect(function() ctx.Remotes.InventoryAction:FireServer("SellAll", item.Id) end)
			end
		end
		if order == 10 then note(11, ("No materials yet. %s drop them."):format(S.term("BattlesName"))) end
	else
		row(1, ("<b>Friends</b>  -  %s\n%s"):format(Hub.Friends.Text, if info.Friends then "<font color=\"#" .. C.green:ToHex() .. "\">Active: a friend is here!</font>" else "Invite a Roblox friend to this server to activate it."),
			nil, nil, nil, if info.Friends then C.green else nil)
		row(2, ("<b>Roblox group</b>  -  %s\n%s"):format(Hub.Group.Text, if info.Guild then "Active: thank you for joining!" elseif info.GroupSet then "Join the game's group to activate it (rejoin after joining)." else "The group is not set up yet."),
			nil, nil, nil, if info.Guild then C.green else nil)
		note(3, "<b>WEEKLY CHAMPIONS</b>  -  highest combat power this week")
		if #info.Champions == 0 then
			note(4, "No champions recorded yet this week.")
		end
		for i, champion in info.Champions do
			row(3 + i, ("#%d  <b>%s</b>  -  power %s"):format(champion.Rank, S.escape(tostring(champion.Name)), tostring(champion.Power)), nil, nil, nil, if i == 1 then C.gold else nil)
		end
	end
end

function Modal.Init(context)
	ctx = context
	S = ctx.Style
	C = S.C
	Hub = ctx.Content.Get("WorldHubConfig")
	Items = ctx.Config.Items
	local overlay = S.new("Frame", { Name = "WorldModal", Size = scale(1, 1), BackgroundColor3 = C.ink, BackgroundTransparency = 0.25, BorderSizePixel = 0,
		ZIndex = 62, Visible = false, Parent = ctx.Gui })
	ctx.Shield.Attach(overlay)
	-- Phones: a bigger card with taller header buttons sized here (44 px minimums covered
	-- the title and the event line).
	local phone = require(game:GetService("ReplicatedStorage").Shared.Responsive).Current().Kind == "Phone"
	local tabY, tabH = if phone then 0.11 else 0.1, if phone then 0.1 else 0.08
	local card = S.new("Frame", { Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = scale(0.5, 0.5), Size = if phone then scale(0.88, 0.94) else scale(0.7, 0.82), ZIndex = 63, Parent = overlay })
	S.padding(card, 16, 12)
	ctx.Theme.frame(card, 14, C.panel1, C.bg2)
	S.label({ Text = "The World", Font = S.Fonts.Title, TextColor3 = C.gold, Size = scale(0.4, 0.09), ZIndex = 64, Parent = card }, 26)
	local close = S.ghostButton({ Text = "Close", Position = scale(0.84, 0), Size = scale(0.16, if phone then 0.09 else 0.08), ZIndex = 64, Parent = card }, 14)
	close:SetAttribute("TouchSafe", true)
	close.Activated:Connect(function() overlay.Visible = false end)
	ui.Tabs = {}
	for i, name in { "World", "Merchant", "Crafting", "Friends" } do
		local b = S.ghostButton({ Text = name, Position = scale((i - 1) * 0.25, tabY), Size = scale(0.24, tabH), ZIndex = 64, Parent = card }, 15)
		b:SetAttribute("TouchSafe", true)
		b.Activated:Connect(function() tab = name; Modal.Draw() end)
		ui.Tabs[name] = b
	end
	local bodyY = tabY + tabH + 0.02
	ui.Body = S.new("ScrollingFrame", { Name = "Body", Position = scale(0, bodyY), Size = scale(1, 1 - bodyY), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = C.stroke, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 63, Parent = card })
	S.list(ui.Body, UDim.new(0, 6))
	ui.Overlay = overlay
end

function Modal.Open()
	ui.Overlay.Visible = true
	Modal.Draw()
	refresh()
end

function Modal.Render(s)
	state = s
	if ui.Overlay and ui.Overlay.Visible then
		Modal.Draw()
	end
end

return Modal
