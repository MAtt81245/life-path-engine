--[[
	Raids tab (client; Modules/RaidSystem via RaidQuery / RaidAction).
	Left: the five difficulties (Create a party or Quick Join). Middle: your party
	(1-5 slots, Start for the leader, Leave) and the open parties lobby. Right: tickets,
	tokens and the Raid Shop.
]]

local Page = {}

local ctx, root, S, C, Raid
local ui = {}
local info = nil
local state = nil
local lastQuery = -math.huge

local function scale(x, y) return UDim2.fromScale(x, y) end

local function column(name: string, x: number, w: number, title: string)
	local frame = S.panel("Frame", { Name = name, Position = scale(x, 0), Size = scale(w, 1), Parent = root }, C.panel1, C.panel2, 12)
	S.padding(frame, 10, 8)
	S.label({ Name = "Title", Text = title, Font = S.Fonts.Title, TextColor3 = C.gold, Size = scale(1, 0.07), Parent = frame }, 20)
	local scroll = S.new("ScrollingFrame", { Name = "Scroll", Position = scale(0, 0.08), Size = scale(1, 0.92), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = C.stroke, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = frame })
	S.list(scroll, UDim.new(0, 5))
	return scroll
end

local function clear(parent)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
end

local function act(action, arg)
	ctx.Remotes.RaidAction:FireServer(action, arg)
	task.delay(0.5, function() Page.Query(true) end)
end

local function phone(): boolean
	return require(game:GetService("ReplicatedStorage").Shared.Responsive).Current().Kind == "Phone"
end

-- Phones: taller cards whose buttons are sized here (44 px minimums covered the text).
local function card(parent, order: number, text: string, color: Color3?)
	local frame = S.panel("Frame", { LayoutOrder = order, Size = UDim2.new(1, -4, 0, if phone() then 96 else 64), Parent = parent }, C.card1, C.card2, 8, color)
	S.padding(frame, 8, 5)
	S.label({ Text = text, RichText = true, TextYAlignment = Enum.TextYAlignment.Top, Size = scale(1, 0.55), Parent = frame }, 13)
	return frame
end

local function button(parent, text: string, x: number, w: number, enabled: boolean, onClick, c1, c2, textColor)
	local b = S.button({ Text = text, Font = S.Fonts.Bold, Position = scale(x, 0.6), Size = scale(w, 0.4), Parent = parent }, c1, c2, 12, textColor)
	b:SetAttribute("TouchSafe", phone())
	S.setEnabled(b, enabled)
	b.Activated:Connect(function() if b.Active then onClick() end end)
	return b
end

function Page.Init(context, frame)
	ctx, root = context, frame
	S = ctx.Style
	C = S.C
	Raid = ctx.Content.Get("RaidConfig")
	ui.Difficulties = column("Difficulties", 0, 0.34, "Raids")
	ui.Party = column("Party", 0.35, 0.34, "Party & Lobby")
	ui.Shop = column("Shop", 0.7, 0.3, "Raid Shop")
	-- Fresh lobby whenever the tab opens (other players' parties are not in the snapshot).
	root:GetPropertyChangedSignal("Visible"):Connect(function()
		if root.Visible then Page.Query(true) end
	end)
end

function Page.Draw()
	if not info or not state then return end
	local list = ui.Difficulties
	clear(list)
	S.autoLabel({ LayoutOrder = 0, RichText = true, Text = ("Adventurer level <b>%d</b>  -  power %d\nTickets <b>%d/%d</b> (+%d a day)"):format(info.Level, info.Power,
		info.Tickets, Raid.MaxTickets, Raid.TicketsPerDay), TextColor3 = C.qi1, Parent = list }, 13)
	for i, entry in Raid.Difficulties do
		local ok = info.Level >= entry.MinLevel and info.Tickets > 0 and not state.Dead and state.Age >= Raid.MinAge
		local frame = card(list, i, ("<b>%s</b>  -  Lv %d+  -  %s\nReward %s, %d tokens"):format(entry.Name, entry.MinLevel, entry.Boss, S.money(entry.Rewards.Money), entry.Rewards.Tokens),
			if info.Level >= entry.MinLevel then C.crimson1 else nil)
		button(frame, "Create party", 0, 0.48, ok, function() act("Create", entry.Id) end)
		button(frame, "Quick Join", 0.52, 0.48, ok, function() act("QuickJoin", entry.Id) end, C.crimson1, C.crimson2, C.text)
	end
	if state.Age < Raid.MinAge then
		S.autoLabel({ LayoutOrder = 10, Text = ("Raids open at age %d."):format(Raid.MinAge), TextColor3 = C.muted, Parent = list }, 12)
	end

	local party = ui.Party
	clear(party)
	if info.Party then
		local entry = nil
		for _, d in Raid.Difficulties do if d.Id == info.Party.Difficulty then entry = d end end
		local names = {}
		for slot = 1, Raid.MaxParty do
			local member = info.Party.Members[slot]
			table.insert(names, if member then ("%d. %s (Lv %d)%s"):format(slot, S.escape(member.Name), member.Level, if member.Leader then "  - leader" else "") else ("%d. (open slot)"):format(slot))
		end
		local frame = S.panel("Frame", { LayoutOrder = 1, Size = UDim2.new(1, -4, 0, 150), Parent = party }, C.card1, C.card2, 8, C.gold)
		S.padding(frame, 8, 6)
		S.label({ Text = ("<b>%s raid</b>\n%s"):format(entry and entry.Name or "?", table.concat(names, "\n")), RichText = true, TextYAlignment = Enum.TextYAlignment.Top,
			Size = scale(1, 0.72), Parent = frame }, 13)
		local start = S.button({ Text = "START RAID", Font = S.Fonts.Heavy, Position = scale(0, 0.76), Size = scale(0.62, 0.24), Parent = frame }, C.crimson1, C.crimson2, 14, C.text)
		S.setEnabled(start, info.Leader == true)
		start.Activated:Connect(function() if start.Active then act("Start") end end)
		local leave = S.ghostButton({ Text = "Leave", Position = scale(0.65, 0.76), Size = scale(0.35, 0.24), Parent = frame }, 13)
		leave.Activated:Connect(function() act("Leave") end)
	else
		S.autoLabel({ LayoutOrder = 1, Text = "You are not in a party. Create one, Quick Join, or join an open party below. Solo raids are allowed.", TextColor3 = C.muted, Parent = party }, 12)
	end
	S.autoLabel({ LayoutOrder = 2, Text = "OPEN PARTIES IN THIS SERVER", Font = S.Fonts.Heavy, TextColor3 = C.gold, Parent = party }, 12)
	if #info.Lobby == 0 then
		S.autoLabel({ LayoutOrder = 3, Text = "None yet.", TextColor3 = C.muted, Parent = party }, 12)
	end
	for i, open in info.Lobby do
		local leader = open.Members[1] and open.Members[1].Name or "?"
		local frame = card(party, 3 + i, ("<b>%s</b> raid  -  %d/%d  -  led by %s"):format(open.Difficulty, #open.Members, Raid.MaxParty, S.escape(leader)))
		button(frame, "Join", 0, 1, not state.Dead, function() act("Join", open.Id) end)
	end

	local shop = ui.Shop
	clear(shop)
	S.autoLabel({ LayoutOrder = 0, RichText = true, Text = ("Raid Tokens: <b>%d</b>"):format(info.Tokens), TextColor3 = C.gold, Parent = shop }, 14)
	for i, offer in Raid.Shop do
		local frame = card(shop, i, ("<b>%s</b>\n%d tokens"):format(offer.Name, offer.Cost))
		button(frame, "Buy", 0, 1, info.Tokens >= offer.Cost and not state.Dead, function() act("Buy", i) end)
	end
end

function Page.Query(force: boolean?)
	if not force and os.clock() - lastQuery < 1 then return end
	lastQuery = os.clock()
	task.spawn(function()
		local ok, result = pcall(function() return ctx.Remotes:WaitForChild("RaidQuery", 10):InvokeServer() end)
		if ok and result then
			info = result
			Page.Draw()
		end
	end)
end

function Page.Render(s)
	state = s
	if root.Visible or (root.Parent and root.Parent:IsA("ScrollingFrame") and root.Parent.Visible) then
		Page.Query()
	end
	Page.Draw()
end

return Page
