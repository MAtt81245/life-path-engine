--[[
	Fame tab (client). Declared by the Fame engine module definition (Tab field);
	UIController creates the tab button and an empty page frame, this module fills it.
	Left: renown, decay and the Perform action. Right: titles that need fame.
]]

local Page = {}

local ctx, root, S, C
local settings
local widgets = {}
local titleRows = {}

local function scale(x, y)
	return UDim2.fromScale(x, y)
end

local function socialLevel(s): number
	local roles = ctx.Config.Stats.Roles
	local stat = roles and roles.Social
	local entry = stat and s.Stats[stat]
	return if entry then entry.Level else 0
end

function Page.Init(context, frame)
	ctx, root = context, frame
	S = ctx.Style
	C = S.C
	settings = ctx.GamePack.Modules.Fame.Settings
	local bold = S.Fonts.Bold

	-- Left: fame and the Perform action
	local left = S.panel("Frame", { Name = "FamePanel", Size = scale(0.49, 1), Parent = root }, C.panel1, C.panel2, 14)
	S.padding(left, 16, 14)
	if ctx.Theme then ctx.Theme.frame(left, 14) end
	S.label({ Name = "Header", Text = "Fame", Font = S.Fonts.Title, TextColor3 = C.gold, Size = scale(0.6, 0.11), Parent = left }, 26)
	widgets.Peak = S.label({ Name = "Peak", Text = "", TextColor3 = C.muted, Position = scale(0.6, 0.02), Size = scale(0.4, 0.08), TextXAlignment = Enum.TextXAlignment.Right, Parent = left }, 14)
	widgets.Points = S.label({ Name = "Points", Text = "0", Font = S.Fonts.Heavy, TextColor3 = C.text, Position = scale(0, 0.13), Size = scale(1, 0.16), Parent = left }, 40)
	local back, fill = S.bar({ Name = "Bar", Position = scale(0, 0.31), Size = scale(1, 0.05), Parent = left }, C.gold, C.gold2)
	widgets.Fill = fill
	widgets.Goal = S.label({ Name = "Goal", Text = "", TextColor3 = C.muted, Position = scale(0, 0.37), Size = scale(1, 0.07), Parent = left }, 13)
	S.label({
		Name = "Decay", TextColor3 = C.muted, Position = scale(0, 0.45), Size = scale(1, 0.08), Parent = left,
		Text = ("Fame fades %d%% every year unless you keep earning it."):format(math.floor(settings.YearlyDecay * 100 + 0.5)),
	}, 13)

	local card = S.new("TextButton", { Name = "PerformCard", Text = "", AutoButtonColor = false, Position = scale(0, 0.58), Size = scale(1, 0.4), Parent = left })
	S.decorate(card, C.card1, C.card2, C.stroke, 12)
	S.padding(card, 12, 10)
	S.label({ Name = "Title", Text = "Perform in Public", Font = bold, TextColor3 = C.gold, Size = scale(1, 0.26), Parent = card }, 18)
	S.label({ Name = "Desc", Text = "Show off in front of a crowd. Social skill draws a bigger audience.", TextColor3 = C.muted, Position = scale(0, 0.28), Size = scale(1, 0.3), TextYAlignment = Enum.TextYAlignment.Top, Parent = card }, 13)
	widgets.Gain = S.label({ Name = "Gain", Text = "", Font = bold, TextColor3 = C.qi1, Position = scale(0, 0.6), Size = scale(1, 0.18), Parent = card }, 14)
	widgets.Cost = S.label({ Name = "Cost", Text = "", Font = bold, Position = scale(0, 0.8), Size = scale(1, 0.2), Parent = card }, 14)
	local stroke = card:FindFirstChildOfClass("UIStroke")
	card.MouseEnter:Connect(function() stroke.Transparency = 0.1 end)
	card.MouseLeave:Connect(function() stroke.Transparency = 0.65 end)
	card.Activated:Connect(function()
		ctx.Remotes:WaitForChild("FameAction"):FireServer("Perform")
	end)
	widgets.Card = card

	-- Right: titles gated by fame (read from the pack's TitlesConfig)
	local right = S.panel("Frame", { Name = "UnlocksPanel", Position = scale(0.51, 0), Size = scale(0.49, 1), Parent = root }, C.panel1, C.panel2, 14)
	S.padding(right, 16, 14)
	if ctx.Theme then ctx.Theme.frame(right, 14) end
	S.label({ Name = "Header", Text = "Fame Unlocks", Font = S.Fonts.Title, TextColor3 = C.gold, Size = scale(1, 0.11), Parent = right }, 24)
	local list = S.new("Frame", { Name = "List", BackgroundTransparency = 1, Position = scale(0, 0.14), Size = scale(1, 0.86), Parent = right })
	S.list(list, UDim.new(0.02, 0))
	local order = 0
	for _, title in ctx.Config.Titles.List do
		if title.Requires and title.Requires.MinFame then
			order += 1
			local row = S.panel("Frame", { Name = title.Id, LayoutOrder = title.Requires.MinFame, Size = scale(1, 0.2), Parent = list }, C.card1, C.card2, 10)
			S.padding(row, 12, 6)
			S.label({ Name = "TitleName", Text = title.Name, Font = bold, Size = scale(0.65, 0.5), Parent = row }, 16)
			S.label({ Name = "Need", Text = ("Fame %d"):format(title.Requires.MinFame), Font = bold, TextColor3 = C.muted, Position = scale(0.65, 0), Size = scale(0.35, 0.5), TextXAlignment = Enum.TextXAlignment.Right, Parent = row }, 14)
			S.label({ Name = "Desc", Text = title.Description or "", TextColor3 = C.muted, Position = scale(0, 0.52), Size = scale(1, 0.48), Parent = row }, 13)
			titleRows[title.Id] = { Row = row, Title = title }
		end
	end
	if order == 0 then
		S.label({ Name = "Empty", Text = "No titles in this game need fame.", TextColor3 = C.muted, Size = scale(1, 0.1), Parent = list }, 14)
	end
end

function Page.Render(s)
	local data = (s.Modules and s.Modules.Fame) or { Points = 0, Peak = 0 }
	widgets.Points.Text = ("%d"):format(data.Points)
	widgets.Peak.Text = ("Peak %d"):format(data.Peak)

	-- Progress toward the next fame-gated title.
	local goal
	for _, entry in titleRows do
		local need = entry.Title.Requires.MinFame
		if need > data.Points and (not goal or need < goal.Need) then
			goal = { Need = need, Name = entry.Title.Name }
		end
	end
	if goal then
		S.setBar(widgets.Fill, data.Points / goal.Need)
		widgets.Goal.Text = ("%d / %d to %s"):format(data.Points, goal.Need, goal.Name)
	else
		S.setBar(widgets.Fill, 1)
		widgets.Goal.Text = if next(titleRows) then "Every fame title within reach" else ""
	end

	local unlocked = (s.Titles and s.Titles.Unlocked) or {}
	for id, entry in titleRows do
		local owned = unlocked[id]
		local met = data.Points >= entry.Title.Requires.MinFame
		entry.Row.TitleName.TextColor3 = if owned then C.green elseif met then C.gold else C.text
		entry.Row.Need.Text = if owned then "Unlocked" else ("Fame %d"):format(entry.Title.Requires.MinFame)
		entry.Row.Need.TextColor3 = if owned then C.green else C.muted
	end

	local gain = settings.PerformBase + socialLevel(s) * settings.PerformPerSocialLevel
	widgets.Gain.Text = ("+%d fame  ·  +3 stress"):format(math.floor(gain + 0.5))
	local reason
	if s.Dead then
		reason = "Deceased"
	elseif s.Age < settings.PerformMinAge then
		reason = ("Age %d+"):format(settings.PerformMinAge)
	elseif s.Actions < settings.PerformSlots then
		reason = "No actions left"
	elseif ((s.ActionCounts or {}).FamePerform or 0) >= settings.PerformMaxPerYear then
		reason = "Done this year"
	end
	widgets.Cost.Text = reason or ("1 action  ·  %d / %d this year"):format((s.ActionCounts or {}).FamePerform or 0, settings.PerformMaxPerYear)
	widgets.Cost.TextColor3 = if reason then C.red else C.text
end

return Page
