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
				S.label({ Name = "Desc", Text = action.Description, TextColor3 = C.muted, Position = scale(0, 0.26), Size = scale(1, 0.34), TextYAlignment = Enum.TextYAlignment.Top, Parent = card }, 12)
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

	local list = root.AttributesPanel.StatsList
	for i, stat in Config.Stats.Order do
		local def = Config.Stats.Stats[stat]
		local row = S.panel("Frame", { Name = stat, LayoutOrder = i, Size = scale(1, 0.153), Parent = list }, C.panel1, C.panel2, 10)
		S.padding(row, 10, 4)
		if S.Dossier then
			-- Student dossier row: a sharp accent strip in the stat colour on the left edge.
			S.new("Frame", { Name = "Accent", Position = UDim2.new(0, -10, 0, -4), Size = UDim2.new(0, 3, 1, 8),
				BackgroundColor3 = def.Color, BorderSizePixel = 0, Parent = row })
		end
		S.label({ Name = "StatName", Text = def.Name, Font = bold, TextColor3 = def.Color, Size = scale(0.5, 0.42), Parent = row }, 15)
		S.label({ Name = "Level", Text = "Lv 0", Font = bold, Position = scale(0.5, 0), Size = scale(0.5, 0.42), TextXAlignment = Enum.TextXAlignment.Right, Parent = row }, 15)
		S.bar({ Name = "Bar", Position = scale(0, if S.Dossier then 0.5 else 0.46), Size = scale(1, if S.Dossier then 0.08 else 0.16), Parent = row }, def.Color)
		S.label({ Name = "Bonus", Text = "", TextColor3 = C.muted, Position = scale(0, 0.66), Size = scale(0.72, 0.34), Parent = row }, 13)
		S.label({ Name = "Mult", Text = "", TextColor3 = C.qi1, Font = if S.Dossier then S.Fonts.Mono else nil, Position = scale(0.72, 0.66), Size = scale(0.28, 0.34), TextXAlignment = Enum.TextXAlignment.Right, Parent = row }, 12)
		if S.Dossier then
			row.Level.Font = S.Fonts.Mono
		end
		statRows[stat] = row
	end

	local profList = root.AttributesPanel.ProfList
	for i, key in Config.Training.ProficiencyOrder do
		local def = Config.Training.Proficiencies[key]
		local row = S.new("Frame", { Name = key, BackgroundTransparency = 1, LayoutOrder = i, Size = scale(1, 0.3), Parent = profList })
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
		local shown = s.Age >= action.MinAge and s.Age <= (action.MaxAge or math.huge)
			and (not action.Requires or ctx.Requirements.Check(s, action.Requires))
		entry.Card.Visible = shown or s.Dead
		local reason
		if s.Dead then
			reason = "Deceased"
		elseif s.Age < action.MinAge then
			reason = ("Age %d+"):format(action.MinAge)
		elseif s.Actions < (action.Slots or 1) then
			reason = "No actions left"
		elseif (s.ActionCounts[action.Id] or 0) >= (action.MaxPerYear or Config.Training.DefaultMaxPerYear) then
			reason = "Done this year"
		elseif action.QiFraction and s.QiProgress >= 1 then
			reason = ctx.Style.Terms.EnergyName .. " at limit"
		end
		local limit = action.MaxPerYear or Config.Training.DefaultMaxPerYear
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
		row.Level.Text = ("Lv %d"):format(entry.Level)
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
