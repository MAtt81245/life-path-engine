--[[
	Inventory tab: equipment slots, the bag (use / equip / sell) and the market.
]]

local Page = {}

local ctx, root, S, C, Items

local function scale(x, y) return UDim2.fromScale(x, y) end

local function categoryColor(item): Color3
	local category = Items.Categories[item.Category]
	return if category then category.Color else C.text
end

local function itemRow(parent, order: number, item, title: string, detail: string, strokeColor: Color3?)
	local row = S.panel("Frame", { Name = item.Id, LayoutOrder = order, Size = UDim2.new(1, -8, 0, 62), Parent = parent }, C.panel1, C.panel2, 10, strokeColor)
	S.padding(row, 8)
	S.label({ Name = "Title", Text = title, RichText = true, Font = S.Fonts.Bold, TextColor3 = categoryColor(item), Size = scale(0.6, 0.45), Parent = row }, 14)
	S.label({ Name = "Detail", Text = detail, RichText = true, TextColor3 = C.muted, Position = scale(0, 0.5), Size = scale(0.6, 0.5), Parent = row }, 12)
	return row
end

local function rowButton(row, text: string, slot: number, primary: boolean, enabled: boolean, onClick)
	local props = { Text = text, AnchorPoint = Vector2.new(0, 0.5), Position = scale(if slot == 1 then 0.62 else 0.815, 0.5), Size = scale(0.185, 0.78), Parent = row }
	local button = if primary then S.button(props, nil, nil, 13) else S.ghostButton(props, 13)
	S.setEnabled(button, enabled)
	button.Activated:Connect(function()
		if enabled then
			onClick()
		end
	end)
end

local function act(action: string, id: string)
	ctx.Remotes.InventoryAction:FireServer(action, id)
end

function Page.Init(context, frame)
	ctx, root = context, frame
	S = ctx.Style
	C = S.C
	Items = ctx.Content.Get("ItemsConfig")
end

local function renderSlots(s, inventory)
	local slots = root.ItemsPanel.Slots
	S.clear(slots)
	for i, slot in Items.SlotOrder do
		local itemId = inventory.Equipped[slot]
		local item = itemId and Items.ById[itemId]
		local card = S.new("TextButton", { Name = slot, LayoutOrder = i, Text = "", AutoButtonColor = false, Size = scale(0.32, 1), Parent = slots })
		S.decorate(card, C.panel1, C.panel2, if item then categoryColor(item) else C.stroke, 10, if item then 0.3 else 0.7)
		S.padding(card, 8)
		S.caption(card, "Slot", string.upper(Items.Slots[slot].Name), scale(0, 0), scale(1, 0.26))
		S.label({ Text = if item then item.Name else "Empty", Font = S.Fonts.Bold, TextColor3 = if item then C.text else C.muted, Position = scale(0, 0.28), Size = scale(1, 0.32), Parent = card }, 14)
		S.label({ Text = if item then item.Description .. "  (click to remove)" else "Equip an item from your bag.", TextColor3 = C.muted, Position = scale(0, 0.62), Size = scale(1, 0.38), Parent = card }, 11)
		card.Activated:Connect(function()
			if item and not s.Dead then
				act("Unequip", slot)
			end
		end)
	end
end

local function renderBag(s, inventory)
	local scroll = root.ItemsPanel.BagScroll
	S.clear(scroll)
	local owned = {}
	for itemId, count in inventory.Items do
		local item = Items.ById[itemId]
		if item and count > 0 then
			table.insert(owned, item)
		end
	end
	table.sort(owned, function(a, b)
		if a.Category ~= b.Category then return a.Category < b.Category end
		return a.Name < b.Name
	end)
	if #owned == 0 then
		S.label({ Text = "Your bag is empty. Buy something at the market, or let life surprise you.", TextColor3 = C.muted, Size = UDim2.new(1, -8, 0, 40), Parent = scroll }, 14)
		return
	end

	local usesThisYear = if inventory.UsesAge == s.Age then inventory.Uses else {}
	for i, item in owned do
		local count = inventory.Items[item.Id]
		local equipped = item.Equip and inventory.Equipped[item.Equip.Slot] == item.Id
		local moduleOn = ctx.GamePack.IsEnabled(item.Module)
		local title = if count > 1 then ("%s  <font color=\"#%s\">x%d</font>"):format(S.escape(item.Name), C.muted:ToHex(), count) else S.escape(item.Name)
		local detail = S.escape(item.Description)
		if equipped then
			detail = ("<font color=\"#%s\">Equipped</font>  ·  %s"):format(C.green:ToHex(), detail)
		end
		local row = itemRow(scroll, i, item, title, detail, if equipped then C.green else nil)

		local used = 0
		if item.Use then
			local limit = item.Use.UsesPerYear
			used = usesThisYear[item.Id] or 0
			local left = if limit then limit - used else nil
			rowButton(row, if left then ("Use (%d)"):format(math.max(0, left)) else "Use", 1, true,
				moduleOn and not s.Dead and (left == nil or left > 0), function() act("Use", item.Id) end)
		elseif item.Equip then
			rowButton(row, if equipped then "Unequip" else "Equip", 1, not equipped, moduleOn and not s.Dead, function()
				if equipped then act("Unequip", item.Equip.Slot) else act("Equip", item.Id) end
			end)
		end
		local price = Items.SellPrice(item)
		if price and item.Category == "Material" then
			-- Materials pile up: Sell +1 and Sell All side by side.
			rowButton(row, "Sell +1", 1, false, not s.Dead, function() act("Sell", item.Id) end)
			rowButton(row, "Sell All", 2, false, not s.Dead, function() act("SellAll", item.Id) end)
		elseif price then
			rowButton(row, "Sell " .. S.money(price), if item.Use or item.Equip then 2 else 1, false, not s.Dead, function() act("Sell", item.Id) end)
		end
	end
end

local function renderShop(s, inventory)
	local scroll = root.ShopPanel.ShopScroll
	S.clear(scroll)
	local order = 0
	for _, itemId in Items.Shop do
		local item = Items.ById[itemId]
		if item and item.Price and ctx.GamePack.IsEnabled(item.Module) then
			order += 1
			local requirement = table.clone(item.Requires or {})
			requirement.MinAge = item.MinAge
			local met, items = ctx.Requirements.Evaluate(s, requirement)
			local detail = S.escape(item.Description)
			if #items > 0 then
				detail ..= "  ·  " .. S.requirementText(items)
			end
			local title = ("%s  <font color=\"#%s\">%s</font>"):format(S.escape(item.Name), C.gold:ToHex(), S.money(item.Price))
			local row = itemRow(scroll, order, item, title, detail)
			local full = (inventory.Items[itemId] or 0) >= Items.MaxStack(item)
			local props = { Text = if full then "Owned" else "Buy", AnchorPoint = Vector2.new(1, 0.5), Position = scale(1, 0.5), Size = scale(0.22, 0.78), Parent = row }
			local button = S.button(props, nil, nil, 13)
			local enabled = met and not full and not s.Dead and s.Money >= item.Price
			S.setEnabled(button, enabled)
			button.Activated:Connect(function()
				if enabled then act("Buy", itemId) end
			end)
			row.Title.Size = scale(0.76, 0.45)
			row.Detail.Size = scale(0.76, 0.5)
		end
	end
end

function Page.Render(s)
	local inventory = s.Inventory or { Items = {}, Equipped = {}, Uses = {} }
	root.ItemsPanel.WealthLabel.Text = "Wallet " .. S.money(s.Money)
	renderSlots(s, inventory)
	renderBag(s, inventory)
	renderShop(s, inventory)
end

return Page
