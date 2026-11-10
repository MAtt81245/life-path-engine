--[[
	Training / Attributes tab: quick actions for the year, attribute bars and
	weapon/power proficiencies.
]]

local Page = {}

local ctx, root, S, C, Config
local cards = {}
local statRows, profRows = {}, {}

local function scale(x, y) return UDim2.fromScale(x, y) end

-- Reward parts of an action ("+12 STR", "+1 knowledge", ...).
local function gainParts(action): { string }
	local parts = {}
	if action.StatXp then
		for _, stat in Config.Stats.Order do
			local xp = action.StatXp[stat]
			if xp then
				table.insert(parts, ("+%d %s"):format(xp, Config.Stats.Stats[stat].Short))
			end
		end
	end
	if action.Proficiency then
		local prof = Config.Training.Proficiencies[action.Proficiency]
		table.insert(parts, ("+%d %s"):format(action.ProficiencyXp, prof.Short or prof.Name))
	end
	if action.Knowledge then table.insert(parts, "+1 knowledge") end
	if action.MeetChance then table.insert(parts, "new friend?") end
	if action.SeekMaster then table.insert(parts, "discover a " .. string.lower(S.term("MentorName"))) end
	if action.Stress and action.Stress < 0 then table.insert(parts, ("%d stress"):format(action.Stress)) end
	if action.Happiness then table.insert(parts, ("+%d joy"):format(action.Happiness)) end
	return parts
end

local function gainText(action): string
	return table.concat(gainParts(action), "  ")
end

-- Dossier briefing cards show rewards as pill tags; rebuilt only when they change.
local function setPills(card, parts: { string })
	local pills = card:FindFirstChild("Pills")
	local key = table.concat(parts, "|")
	if not pills or pills:GetAttribute("Key") == key then
		return
	end
	pills:SetAttribute("Key", key)
	for _, child in pills:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for i, part in parts do
		local pill = S.new("TextLabel", {
			Name = "Pill" .. i, LayoutOrder = i, Text = part, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1),
			Font = S.Fonts.Mono, TextSize = 11, TextColor3 = if part:find(S.Terms.EnergyName, 1, true) or (S.Terms.EnergyShort and part:find(" " .. S.Terms.EnergyShort, 1, true)) then C.qi1 else C.text,
			BackgroundColor3 = C.card1, BorderSizePixel = 0, Parent = pills,
		})
		S.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pill })
		S.new("UIStroke", { Color = C.stroke, Thickness = 1, Transparency = 0.55, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = pill })
		S.new("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7), Parent = pill })
	end
end

function Page.Init(context, frame)
	ctx, root = context, frame
	S, Config = ctx.Style, ctx.Config
	C = S.C
	local bold = S.Fonts.Bold

	local grid = root.ActionsPanel.Grid
	for i, action in Config.Training.Actions do
		if action.Page == "Training" and ctx.GamePack.IsEnabled(action.Module) then
			local card = S.new("TextButton", { Name = action.Id, LayoutOrder = i, Text = "", AutoButtonColor = false, Parent = grid })
			S.decorate(card, C.panel1, C.panel2, C.stroke, 12)
			S.padding(card, 8)
			if S.Dossier then
				-- Mission briefing card: thick left accent bar (crimson for combat, violet
				-- otherwise), bold uppercase title, cost on the right, reward pills below.
				local combat = action.Proficiency ~= nil or (action.StatXp and action.StatXp.Strength ~= nil)
				S.new("Frame", { Name = "Accent", Position = UDim2.new(0, -8, 0, -8), Size = UDim2.new(0, 4, 1, 16),
					BackgroundColor3 = if combat then C.crimson1 else C.gold, BorderSizePixel = 0, Parent = card })
				S.label({ Name = "Title", Text = string.upper(action.Name), Font = S.Fonts.Heavy, TextColor3 = C.text, Position = scale(0.02, 0), Size = scale(0.6, 0.44), Parent = card }, 15)
				S.label({ Name = "Desc", Text = action.Description, TextColor3 = C.muted, Visible = false, Parent = card }, 12)
				S.label({ Name = "Gain", Text = gainText(action), Visible = false, Parent = card }, 12)
				S.label({ Name = "Cost", Text = "1 action", Font = S.Fonts.Mono, Position = scale(0.62, 0), Size = scale(0.38, 0.44), TextXAlignment = Enum.TextXAlignment.Right, Parent = card }, 11)
				local pills = S.new("Frame", { Name = "Pills", BackgroundTransparency = 1, Position = scale(0.02, 0.54), Size = scale(0.98, 0.46), ClipsDescendants = true, Parent = card })
				S.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center, Parent = pills })
				setPills(card, gainParts(action))
			else
				S.label({ Name = "Title", Text = action.Name, Font = bold, TextColor3 = C.gold, Size = scale(1, 0.24), Parent = card }, 16)
				-- One fixed size on every card (scaled text shrank long lines unevenly);
				-- a line too long for two rows ends in "...".
				local desc = S.label({ Name = "Desc", Text = action.Description, TextColor3 = C.muted, Position = scale(0, 0.26), Size = scale(1, 0.34), TextYAlignment = Enum.TextYAlignment.Top, Parent = card }, 12)
				desc.TextScaled, desc.TextSize, desc.TextTruncate = false, 12, Enum.TextTruncate.AtEnd
				S.label({ Name = "Gain", Text = gainText(action), Font = bold, TextColor3 = C.qi1, Position = scale(0, 0.62), Size = scale(1, 0.18), Parent = card }, 12)
				S.label({ Name = "Cost", Text = "1 action", Font = bold, Position = scale(0, 0.82), Size = scale(1, 0.18), Parent = card }, 12)
			end
			local stroke = card:FindFirstChildOfClass("UIStroke")
			card.MouseEnter:Connect(function() stroke.Transparency = 0.1 end)
			card.MouseLeave:Connect(function() stroke.Transparency = 0.65 end)
			card.Activated:Connect(function()
				ctx.Remotes.Train:FireServer(action.Id)
			end)
			cards[action.Id] = { Card = card, Action = action }
		end
	end

	-- Stat cards grow with their bonus text (S.fit) and the list scrolls, so nothing clips.
	local list = S.toScroller(root.AttributesPanel.StatsList)
	local listLayout = list:FindFirstChildOfClass("UIListLayout")
	if listLayout then
		listLayout.Padding = UDim.new(0, 6)
	end
	-- Grouped (Physical & Aura / Magical & Mental) when the pack defines Groups.
	local ordered = {}
	for _, group in Config.Stats.Groups or { { Stats = Config.Stats.Order } } do
		if group.Name then
			table.insert(ordered, { Header = group.Name })
		end
		for _, stat in group.Stats do
			if Config.Stats.Stats[stat] then
				table.insert(ordered, { Stat = stat })
			end
		end
	end
	local function ratingText(stat: string): string
		local def = Config.Stats.Stats[stat]
		local level = statRows[stat] and statRows[stat].LevelValue or 0
		local lines = { ("<b>%s</b>  ·  %s"):format(def.Name, def.Description or "") }
		if Config.Stats.Rating then
			local rating, band = Config.Stats.Rating(level)
			table.insert(lines, ("Rating <b>%d</b> (%s)  ·  adult average %d  ·  no upper cap"):format(rating, band, Config.Stats.AdultAverage or 50))
			local scale = {}
			for _, entry in Config.Stats.Ratings do
				table.insert(scale, ("%d+ %s"):format(entry.Min, entry.Name))
			end
			table.insert(lines, table.concat(scale, "  ·  "))
			table.insert(lines, ("Rating = level × %s"):format(tostring(Config.Stats.RatingScale or 1)))
		end
		return table.concat(lines, "\n")
	end
	for i, item in ordered do
		if item.Header then
			S.autoLabel({ Name = "Group" .. i, LayoutOrder = i, Text = string.upper(item.Header), Font = S.Fonts.Heavy, TextColor3 = C.gold, Parent = list }, 12)
			continue
		end
		local stat = item.Stat
		local def = Config.Stats.Stats[stat]
		local row = S.panel("Frame", { Name = stat, LayoutOrder = i, Size = UDim2.new(1, -6, 0, 0), Parent = list }, C.panel1, C.panel2, 10)
		S.fit(row)
		if S.Dossier then
			-- Student dossier row: a sharp accent strip in the stat colour on the left edge.
			S.new("Frame", { Name = "Accent", Position = UDim2.new(0, -S.FitPadding.X, 0, -S.FitPadding.Y), Size = UDim2.new(0, 3, 1, 2 * S.FitPadding.Y),
				BackgroundColor3 = def.Color, BorderSizePixel = 0, Parent = row })
		end
		local body = S.new("Frame", { Name = "Body", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = row })
		S.list(body, UDim.new(0, 4))
		local head = S.new("Frame", { Name = "Head", LayoutOrder = 1, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), Parent = body })
		S.label({ Name = "StatName", Text = def.Name, Font = bold, TextColor3 = def.Color, Size = scale(0.42, 1), Parent = head }, 15)
		local info = S.new("TextButton", { Name = "Info", Text = "(i)", Font = bold, TextScaled = true, TextColor3 = C.muted, BackgroundTransparency = 1,
			Position = scale(0.42, 0.1), Size = scale(0.1, 0.8), Parent = head })
		info:SetAttribute("TouchSafe", true) -- a tooltip hint inside the row; growing it would cover the level
		ctx.AttachTooltip(info, function() return ratingText(stat) end)
		local level = S.label({ Name = "Level", Text = "Lv 0", Font = if S.Dossier then S.Fonts.Mono else bold, Position = scale(0.52, 0), Size = scale(0.48, 1), TextXAlignment = Enum.TextXAlignment.Right, Parent = head }, 15)
		local bar = S.bar({ Name = "Bar", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, if S.Dossier then 5 else 8), Parent = body }, def.Color)
		local foot = S.new("Frame", { Name = "Foot", LayoutOrder = 3, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = body })
		local bonus = S.autoLabel({ Name = "Bonus", Text = "", TextColor3 = C.muted, Size = UDim2.fromScale(0.72, 0), Parent = foot }, 13)
		local mult = S.autoLabel({ Name = "Mult", Text = "", TextColor3 = C.qi1, Font = if S.Dossier then S.Fonts.Mono else nil, Position = scale(0.72, 0), Size = UDim2.fromScale(0.28, 0),
			TextXAlignment = Enum.TextXAlignment.Right, Parent = foot }, 12)
		statRows[stat] = { Row = row, Level = level, Bar = bar, Bonus = bonus, Mult = mult }
	end

	-- Proficiencies close the same scrolling list (their own strip under it left a stat
	-- card cut off right against the header, which read as an overlap).
	local panel = root.AttributesPanel
	panel.ProfHeader.Visible, panel.ProfList.Visible = false, false
	list.Size = UDim2.fromScale(list.Size.X.Scale, 1 - list.Position.Y.Scale)
	local profOrder = #ordered + 1
	if #Config.Training.ProficiencyOrder > 0 then
		S.autoLabel({ Name = "ProfGroup", LayoutOrder = profOrder, Text = string.upper(panel.ProfHeader.Text), Font = S.Fonts.Heavy, TextColor3 = C.gold, Parent = list }, 12)
	end
	for i, key in Config.Training.ProficiencyOrder do
		local def = Config.Training.Proficiencies[key]
		local row = S.new("Frame", { Name = key, BackgroundTransparency = 1, LayoutOrder = profOrder + i, Size = UDim2.new(1, -6, 0, 22), Parent = list })
		S.label({ Name = "ProfName", Text = def.Short or def.Name, Font = bold, TextColor3 = def.Color, Size = scale(0.26, 1), Parent = row }, 14)
		S.bar({ Name = "Bar", Position = scale(0.27, 0.3), Size = scale(0.55, 0.4), Parent = row }, def.Color)
		S.label({ Name = "Level", Text = "Lv 0", Font = bold, Position = scale(0.84, 0), Size = scale(0.16, 1), TextXAlignment = Enum.TextXAlignment.Right, Parent = row }, 14)
		profRows[key] = row
	end
end

function Page.Render(s)
	root.ActionsPanel.EnergyLabel.Text = ("%d / %d actions left"):format(s.Actions, s.MaxActions)
	for _, entry in cards do
		local action = entry.Action
		-- Progressive disclosure: actions outside their age window or not yet unlocked stay hidden.
		local minAge = action.MinAge - (if action.Prodigy then s.TrainingAgeOffset or 0 else 0)
		local shown = s.Age >= minAge and s.Age <= (action.MaxAge or math.huge)
			and (not action.Requires or ctx.Requirements.Check(s, action.Requires))
		entry.Card.Visible = shown or s.Dead
		local reason
		if s.Dead then
			reason = "Deceased"
		elseif s.Age < minAge then
			reason = ("Age %d+"):format(minAge)
		elseif s.Actions < (action.Slots or 1) then
			reason = "No actions left"
		elseif (s.ActionCounts[action.Id] or 0) >= (action.MaxPerYear or Config.Training.DefaultMaxPerYear) then
			reason = "Done this year"
		elseif action.QiFraction and s.QiProgress >= 1 then
			reason = ctx.Style.Terms.EnergyName .. " at limit"
		end
		local limit = action.MaxPerYear or Config.Training.DefaultMaxPerYear
		-- ⚠ badge: the action costs health (it can injure you).
		if (action.Health or 0) < 0 and not entry.Card:GetAttribute("RiskBadge") then
			entry.Card:SetAttribute("RiskBadge", true)
			entry.Card.Title.Text = "⚠ " .. entry.Card.Title.Text
		end
		entry.Card.Cost.Text = reason or ("1 action  ·  %d / %d this year"):format(s.ActionCounts[action.Id] or 0, limit)
		entry.Card.Cost.TextColor3 = if reason then C.red else C.text
		entry.Card.Title.TextColor3 = if reason then C.muted else (if S.Dossier then C.text else C.gold)
		local qiGain = s.QiGains and s.QiGains[action.Id]
		if qiGain then
			entry.Card.Gain.Text = ("+%s %s  %s"):format(qiGain, ctx.Style.Terms.EnergyName, gainText(action))
		end
		if S.Dossier then
			local parts = gainParts(action)
			if qiGain then
				table.insert(parts, 1, ("+%s %s"):format(qiGain, ctx.Style.Terms.EnergyShort or ctx.Style.Terms.EnergyName))
			end
			setPills(entry.Card, parts)
		end
	end
	for stat, row in statRows do
		local entry = s.Stats[stat]
		row.LevelValue = entry.Level
		local band = if Config.Stats.Rating then select(2, Config.Stats.Rating(entry.Level)) else nil
		row.Level.Text = if band then ("Lv %d  ·  %s"):format(entry.Level, band) else ("Lv %d"):format(entry.Level)
		S.setBar(row.Bar.Fill, entry.Xp / entry.Next)
		row.Bonus.Text = Config.Stats.Stats[stat].Describe(entry.Level)
		row.Mult.Text = ("x%.2f XP"):format(entry.XpMult)
	end
	for key, row in profRows do
		local entry = s.Proficiencies[key]
		row.Level.Text = ("Lv %d"):format(entry.Level)
		S.setBar(row.Bar.Fill, entry.Xp / entry.Next)
	end
	root.AttributesPanel.PointsLabel.Text = ("%d mastery pts"):format(s.MasteryPoints)
end

return Page
