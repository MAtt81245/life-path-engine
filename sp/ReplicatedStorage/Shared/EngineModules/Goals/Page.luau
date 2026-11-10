--[[
	Goals tab (client; Modules/JournalSystem through JournalAction, titles through
	ProgressionAction "Equip").
	Left: the 7-day login streak and today's three quests. Middle: Life Goals (n/43,
	reset every life). Right: the Title Book (every title, unlocked ones equippable).
]]

local Page = {}

local ctx, root, S, C, Journal, Titles
local ui = {}

local function scale(x, y) return UDim2.fromScale(x, y) end

local function column(name: string, x: number, w: number, title: string)
	local frame = S.panel("Frame", { Name = name, Position = scale(x, 0), Size = scale(w, 1), Parent = root }, C.panel1, C.panel2, 12)
	S.padding(frame, 10, 8)
	local header = S.label({ Name = "Title", Text = title, Font = S.Fonts.Title, TextColor3 = C.gold, Size = scale(1, 0.07), Parent = frame }, 20)
	local scroll = S.new("ScrollingFrame", { Name = "Scroll", Position = scale(0, 0.08), Size = scale(1, 0.92), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = C.stroke, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = frame })
	S.list(scroll, UDim.new(0, 4))
	return scroll, header
end

local function clear(parent)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
end

local function today(): number
	return math.floor(os.time() / 86400)
end

local function quests()
	local random = Random.new(today() * 31)
	local pool = table.clone(Journal.DailyPool)
	local list = {}
	for _ = 1, math.min(Journal.DailyCount, #pool) do
		table.insert(list, table.remove(pool, random:NextInteger(1, #pool)))
	end
	return list
end

local function rewardText(reward): string
	local parts = {}
	if reward.Money then table.insert(parts, S.money(reward.Money)) end
	if reward.Karma then table.insert(parts, ("%d %s"):format(reward.Karma, S.Terms.MetaCurrency or "Karma")) end
	if reward.Item then
		local item = ctx.Config.Items.ById[reward.Item]
		table.insert(parts, item and item.Name or reward.Item)
	end
	if reward.Ticket then table.insert(parts, "raid ticket") end
	return table.concat(parts, " + ")
end

function Page.Init(context, frame)
	ctx, root = context, frame
	S = ctx.Style
	C = S.C
	Journal = ctx.Content.Get("JournalConfig")
	Titles = ctx.Config.Titles
	ui.Daily = column("Daily", 0, 0.32, "Journal")
	ui.Goals, ui.GoalsHeader = column("LifeGoals", 0.33, 0.33, "Life Goals")
	ui.Titles, ui.TitlesHeader = column("TitleBook", 0.67, 0.33, "Title Book")
end

function Page.Render(s)
	local journal = s.Journal or {}
	-- Login streak.
	local list = ui.Daily
	clear(list)
	local claimed = journal.LoginDay == today()
	local streak = journal.Streak or 0
	local nextDay = if claimed then streak else (if journal.LoginDay == today() - 1 then (streak % #Journal.LoginRewards) + 1 else 1)
	S.autoLabel({ LayoutOrder = 0, Text = "7-DAY LOGIN STREAK", Font = S.Fonts.Heavy, TextColor3 = C.gold, Parent = list }, 12)
	-- Day cards in a 4 + 3 grid (seven in one row of a narrow column were unreadable).
	local perRow = 4
	local rows = math.ceil(#Journal.LoginRewards / perRow)
	local strip = S.new("Frame", { LayoutOrder = 1, Size = UDim2.new(1, -4, 0, rows * 50 + (rows - 1) * 4), BackgroundTransparency = 1, Parent = list })
	S.new("UIGridLayout", { CellSize = UDim2.new(1 / perRow, -4, 0, 50), CellPadding = UDim2.fromOffset(4, 4), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = strip })
	for day, reward in Journal.LoginRewards do
		local done = (claimed and day <= streak) or (not claimed and day < nextDay)
		local current = day == nextDay and not claimed
		local cell = S.new("Frame", { LayoutOrder = day, BackgroundColor3 = if done then C.gold2 elseif current then C.card2 else C.inset, BorderSizePixel = 0, Parent = strip })
		S.new("UICorner", { CornerRadius = UDim.new(0, 6), Parent = cell })
		S.new("UIStroke", { Color = if current then C.gold else C.stroke, Transparency = if current then 0.1 else 0.7, Thickness = if current then 1.5 else 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = cell })
		S.padding(cell, 4, 3)
		local ink = if done then C.dark else C.text
		S.label({ Text = ("DAY %d"):format(day), Font = S.Fonts.Heavy, TextColor3 = if done then C.dark else C.gold, TextXAlignment = Enum.TextXAlignment.Center,
			Size = scale(1, 0.36), Parent = cell }, 11)
		S.label({ Text = rewardText(reward), TextColor3 = ink, TextXAlignment = Enum.TextXAlignment.Center, Position = scale(0, 0.38), Size = scale(1, 0.62), Parent = cell }, 11)
	end
	local login = S.button({ LayoutOrder = 2, Text = if claimed then ("Day %d claimed - come back tomorrow"):format(streak) else ("Claim day %d reward"):format(nextDay),
		Font = S.Fonts.Heavy, Size = UDim2.new(1, -4, 0, 32), Parent = list }, nil, nil, 14)
	S.setEnabled(login, not claimed and not s.Dead)
	login.Activated:Connect(function() if login.Active then ctx.Remotes.JournalAction:FireServer("Login") end end)
	-- Daily quests.
	S.autoLabel({ LayoutOrder = 3, Text = ("DAILY QUESTS  -  finish all three for +%d %s"):format(Journal.DailyReward, S.Terms.MetaCurrency or "Karma"),
		Font = S.Fonts.Heavy, TextColor3 = C.gold, Parent = list }, 12)
	local daily = (journal.Daily and journal.Daily.Day == today()) and journal.Daily or { Progress = {} }
	local all = true
	for i, quest in quests() do
		local have = (daily.Progress or {})[quest.Id] or 0
		if have < quest.Need then all = false end
		local frame = S.panel("Frame", { LayoutOrder = 3 + i, Size = UDim2.new(1, -4, 0, 38), Parent = list }, C.card1, C.card2, 6, if have >= quest.Need then C.green else nil)
		S.padding(frame, 8, 4)
		local finished = have >= quest.Need
		local dot = S.new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = scale(0, 0.5), Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = if finished then C.green else C.inset, BorderSizePixel = 0, Parent = frame })
		S.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })
		S.new("UIStroke", { Color = if finished then C.green else C.stroke, Transparency = 0.3, Parent = dot })
		S.label({ Text = quest.Text, TextColor3 = if finished then C.green else C.text, Position = UDim2.new(0, 18, 0, 0), Size = UDim2.new(0.75, -18, 1, 0), Parent = frame }, 13)
		S.label({ Text = ("%d/%d"):format(have, quest.Need), Font = S.Fonts.Mono, TextXAlignment = Enum.TextXAlignment.Right, Position = scale(0.75, 0), Size = scale(0.25, 1), Parent = frame }, 13)
	end
	local claim = S.button({ LayoutOrder = 10, Text = if daily.Claimed then "Daily reward claimed" else "Claim daily reward", Font = S.Fonts.Heavy, Size = UDim2.new(1, -4, 0, 32), Parent = list }, nil, nil, 14)
	S.setEnabled(claim, all and not daily.Claimed and not s.Dead)
	claim.Activated:Connect(function() if claim.Active then ctx.Remotes.JournalAction:FireServer("Daily") end end)

	-- Life goals.
	local goals = ui.Goals
	clear(goals)
	local done = (s.Modules and s.Modules.Goals and s.Modules.Goals.Done) or {}
	local count = 0
	for _ in done do count += 1 end
	ui.GoalsHeader.Text = ("Life Goals  (%d/%d)"):format(count, #Journal.LifeGoals)
	-- One row per goal: a status dot (a frame, not a glyph) and the goal; open goals first.
	for i, entry in Journal.LifeGoals do
		local reached = done[entry.Id] == true
		local row = S.new("Frame", { LayoutOrder = (if reached then 100 else 0) + i, Size = UDim2.new(1, -6, 0, 24), BackgroundColor3 = if reached then C.card2 else C.card1,
			BackgroundTransparency = if i % 2 == 0 then 0.35 else 0.6, BorderSizePixel = 0, Parent = goals })
		S.new("UICorner", { CornerRadius = UDim.new(0, 5), Parent = row })
		local dot = S.new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = if reached then C.green else C.inset, BorderSizePixel = 0, Parent = row })
		S.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })
		S.new("UIStroke", { Color = if reached then C.green else C.stroke, Transparency = 0.3, Parent = dot })
		S.label({ Text = entry.Text, TextColor3 = if reached then C.green else C.text, Position = UDim2.new(0, 26, 0, 0), Size = UDim2.new(1, -30, 1, 0), Parent = row }, 13)
	end

	-- Title Book.
	local book = ui.Titles
	clear(book)
	local unlocked, equipped = (s.Titles and s.Titles.Unlocked) or {}, (s.Titles and s.Titles.Equipped) or {}
	local have = 0
	for _ in unlocked do have += 1 end
	ui.TitlesHeader.Text = ("Title Book  (%d/%d)"):format(have, #Titles.List)
	for i, title in Titles.List do
		local own = unlocked[title.Id] ~= nil
		local on = table.find(equipped, title.Id) ~= nil
		local frame = S.panel("Frame", { LayoutOrder = (if own then 0 else 100) + i, Size = UDim2.new(1, -4, 0, 48), Parent = book }, C.card1, C.card2, 6, if on then C.gold else nil)
		S.padding(frame, 8, 4)
		local _, items = ctx.Requirements.Evaluate(s, title.Requires)
		S.label({ Text = ("<b>%s</b>\n%s"):format(if own then title.Name else "???", if own then title.Description else ("Needs: " .. S.requirementText(items):gsub("<[^>]+>", ""))),
			RichText = true, TextColor3 = if own then C.text else C.muted, Size = scale(0.7, 1), Parent = frame }, 12)
		if own then
			local equip = S.ghostButton({ Text = if on then "Equipped" else "Equip", Position = scale(0.72, 0.15), Size = scale(0.28, 0.7), Parent = frame }, 12)
			S.setEnabled(equip, not on and not s.Dead)
			equip.Activated:Connect(function() if equip.Active then ctx.Remotes.ProgressionAction:FireServer("Equip", title.Id) end end)
		end
	end
end

return Page
