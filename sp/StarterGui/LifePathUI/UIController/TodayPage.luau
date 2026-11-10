--[[
	Today tab (the living chronicle's front page):
	- Today's Omen banner: one free omen a real day (ChronicleAction "Omen").
	- CURRENT GOAL: the next milestone for this stage of life (and its progress).
	- 3 THINGS TO DO ◆: the most useful moves right now; each card acts or opens a tab.
	- The story so far: the latest chronicle line, typed out (typewriter toggle; the
	  life event modal follows the same setting through ctx.Typewriter).
]]

local Page = {}

local ctx, root, S, C, T, Config, Chronicle
local ui = {}
local state = nil
local lastEntry = nil
local typing = 0

local function scale(x, y) return UDim2.fromScale(x, y) end

-- Types `label`'s text out; any later call (or turning the setting off) finishes it.
function Page.Type(label: TextLabel, text: string)
	typing += 1
	local token = typing
	label.Text = text
	if not ctx.Typewriter.On then
		label.MaxVisibleGraphemes = -1
		return
	end
	label.MaxVisibleGraphemes = 0
	task.spawn(function()
		local total = utf8.len(label.ContentText) or #label.ContentText
		local shown = 0
		while token == typing and shown < total and ctx.Typewriter.On do
			shown += 2
			label.MaxVisibleGraphemes = shown
			task.wait(0.03)
		end
		label.MaxVisibleGraphemes = -1
	end)
end

local function card(parent, name: string, props)
	local frame = S.panel("TextButton", { Name = name, Text = "", AutoButtonColor = false, Position = props.Position, Size = props.Size,
		LayoutOrder = props.LayoutOrder, Parent = parent }, C.card1, C.card2, 12, props.Stroke)
	S.padding(frame, 12, 8)
	return frame
end

function Page.Init(context, frame)
	ctx, root = context, frame
	S, Config = ctx.Style, ctx.Config
	C, T = S.C, S.Terms
	Chronicle = ctx.Content.Get("ChronicleConfig")

	-- Omen banner.
	local omen = card(root, "OmenBanner", { Position = scale(0, 0), Size = scale(1, 0.15), Stroke = C.gold })
	ui.OmenIcon = S.label({ Name = "Icon", Text = "🔮", TextXAlignment = Enum.TextXAlignment.Center, Size = scale(0.08, 1), Parent = omen }, 30)
	ui.OmenTitle = S.label({ Name = "Title", Text = "", Font = S.Fonts.Title, TextColor3 = C.gold, Position = scale(0.09, 0), Size = scale(0.7, 0.55), Parent = omen }, 22)
	ui.OmenText = S.label({ Name = "Text", Text = "", TextColor3 = C.muted, Position = scale(0.09, 0.55), Size = scale(0.7, 0.45), Parent = omen }, 14)
	ui.OmenButton = S.button({ Name = "Read", Text = "Read it", Font = S.Fonts.Heavy, Position = scale(0.8, 0.12), Size = scale(0.2, 0.76), Parent = omen }, nil, nil, 16)
	local function claim()
		if state and not ui.OmenClaimed then
			ctx.Remotes.ChronicleAction:FireServer("Omen")
		end
	end
	ui.OmenButton.Activated:Connect(claim)
	omen.Activated:Connect(claim)
	ui.Omen = omen

	-- Current goal.
	local goal = card(root, "Goal", { Position = scale(0, 0.18), Size = scale(1, 0.17) })
	S.label({ Name = "Kicker", Text = "CURRENT GOAL", Font = S.Fonts.Heavy, TextColor3 = C.gold, Size = scale(0.5, 0.3), Parent = goal }, 12)
	ui.GoalText = S.label({ Name = "Text", Text = "", Font = S.Fonts.Title, TextColor3 = C.text, Position = scale(0, 0.3), Size = scale(1, 0.4), Parent = goal }, 22)
	local pathButton = S.button({ Name = "YourPath", Text = "◆  YOUR PATH", Font = S.Fonts.Heavy, Position = scale(0.78, 0), Size = scale(0.22, 0.62), Parent = goal }, nil, nil, 15)
	if ctx.GamePack.IsActive("WorldHub") then
		ui.GoalText.Size = scale(0.52, 0.4)
		local worldButton = S.button({ Name = "WorldHub", Text = "THE WORLD", Font = S.Fonts.Heavy, Position = scale(0.55, 0), Size = scale(0.21, 0.62), Parent = goal },
			C.qi2, C.jade2, 15, C.text)
		worldButton.Activated:Connect(function() if ctx.OpenWorld then ctx.OpenWorld() end end)
	end
	pathButton.Activated:Connect(function()
		if ctx.OpenPath then
			ctx.OpenPath()
		end
	end)
	ui.GoalText.Size = if ctx.GamePack.IsActive("WorldHub") then scale(0.52, 0.4) else scale(0.76, 0.4)
	local back, fill = S.bar({ Name = "Progress", Position = scale(0, 0.78), Size = scale(1, 0.14), Parent = goal }, C.qi1)
	ui.GoalBar, ui.GoalFill = back, fill

	-- Three things to do.
	S.label({ Name = "TodoHeader", Text = "3 THINGS TO DO  ◆", Font = S.Fonts.Heavy, TextColor3 = C.gold, Position = scale(0, 0.375), Size = scale(0.6, 0.05), Parent = root }, 14)
	ui.Todo = {}
	for i = 1, 3 do
		local todo = card(root, "Todo" .. i, { Position = scale((i - 1) * 0.34, 0.435), Size = scale(0.32, 0.25) })
		local icon = S.label({ Name = "Icon", Text = "◆", TextXAlignment = Enum.TextXAlignment.Left, Size = scale(0.25, 0.36), Parent = todo }, 24)
		local title = S.label({ Name = "Title", Text = "", Font = S.Fonts.Bold, TextColor3 = C.gold, Position = scale(0, 0.38), Size = scale(1, 0.3), Parent = todo }, 16)
		local why = S.label({ Name = "Why", Text = "", TextColor3 = C.muted, Position = scale(0, 0.7), Size = scale(1, 0.3), Parent = todo }, 12)
		local stroke = todo:FindFirstChildOfClass("UIStroke")
		todo.MouseEnter:Connect(function() stroke.Transparency = 0.1 end)
		todo.MouseLeave:Connect(function() stroke.Transparency = 0.65 end)
		local entry = { Card = todo, Icon = icon, Title = title, Why = why }
		todo.Activated:Connect(function()
			if entry.Run then
				entry.Run()
			end
		end)
		ui.Todo[i] = entry
	end

	-- The story so far (latest chronicle line, typed out).
	local story = card(root, "Story", { Position = scale(0, 0.72), Size = scale(1, 0.28) })
	S.label({ Name = "Kicker", Text = "THE STORY SO FAR", Font = S.Fonts.Heavy, TextColor3 = C.gold, Size = scale(0.5, 0.2), Parent = story }, 12)
	ui.StoryText = S.label({ Name = "Text", Text = "", RichText = true, TextColor3 = C.text, TextYAlignment = Enum.TextYAlignment.Top,
		Position = scale(0, 0.24), Size = scale(1, 0.76), Parent = story }, 17)
	ui.Typewriter = S.ghostButton({ Name = "TypewriterToggle", Text = "", Position = scale(0.72, 0), Size = scale(0.28, 0.2), Parent = story }, 12)
	local function paintToggle()
		ui.Typewriter.Text = ("⌨ Typewriter: %s"):format(if ctx.Typewriter.On then "On" else "Off")
	end
	paintToggle()
	ui.Typewriter.Activated:Connect(function()
		ctx.Typewriter.Set(not ctx.Typewriter.On)
		paintToggle()
		ui.StoryText.MaxVisibleGraphemes = -1
	end)
	story.Activated:Connect(function()
		typing += 1 -- a tap finishes the line at once
		ui.StoryText.MaxVisibleGraphemes = -1
	end)
end

local function trainingSuggestion(s)
	for _, action in Config.Training.Actions do
		local open = action.Page == "Training" and ctx.GamePack.IsEnabled(action.Module) and s.Age >= action.MinAge and s.Age <= (action.MaxAge or math.huge)
			and (not action.Requires or ctx.Requirements.Check(s, action.Requires))
			and (s.ActionCounts[action.Id] or 0) < (action.MaxPerYear or Config.Training.DefaultMaxPerYear)
			and (action.Health or 0) >= 0
		if open then
			return action
		end
	end
	return nil
end

local function goalFor(s): (string, number?)
	if s.Dead then
		return "Your story has ended. Choose the next life.", nil
	end
	local gates = Config.Gates
	if ctx.GamePack.IsEnabled("Cultivation") then
		local awakened = (s.Flags and s.Flags[gates.StripFlag or ""]) or s.Age >= (gates.StripAge or 0)
		if not awakened then
			return ("Grow up: your power wakes at age %d"):format(gates.StripAge or 0), s.Age / math.max(1, gates.StripAge or 1)
		end
		if not s.IsMaxed then
			local realms = Config.Realms.Realms
			local nextRealm = realms and realms[(s.RealmIndex or 1) + 1]
			if s.SubLevel < s.SubLevels or not nextRealm then
				return ("Reach %s level %d"):format(s.Realm, math.min(s.SubLevel + 1, s.SubLevels)), s.QiProgress
			end
			return ("%s into %s"):format(T.AdvanceTierButton or "Advance", nextRealm.Name), s.QiProgress
		end
		return T.AscendHint or "Ascend", 1
	end
	if s.Education and s.Education.Enrolled then
		local tier = Config.Studies.TiersById[s.Education.Tier]
		return ("Finish %s"):format(if tier then tier.Name else "school"), (s.Education.Performance or 0) / 100
	end
	if s.Age < 6 then
		return "Grow up healthy and happy", s.Happiness / 100
	elseif s.Career and s.Career.Id then
		return "Earn your next promotion", (s.Career.Performance or 0) / 100
	elseif s.Age >= 18 then
		return "Find your first job", nil
	end
	return "Discover what you are good at", nil
end

local function setTodo(i: number, icon: string, title: string, why: string, run)
	local entry = ui.Todo[i]
	entry.Icon.Text, entry.Title.Text, entry.Why.Text, entry.Run = icon, title, why, run
end

function Page.Render(s)
	state = s
	local data = (s.Modules and s.Modules.Chronicle) or {}
	local today = Chronicle.Day(os.time())
	ui.OmenClaimed = data.OmenDay == today
	if ui.OmenClaimed then
		local omen = data.LastOmen and Chronicle.OmensById[data.LastOmen]
		ui.OmenTitle.Text = "Today's omen has spoken"
		ui.OmenText.Text = if omen then omen.Text .. "  A new omen comes tomorrow." else "A new omen comes tomorrow."
		ui.OmenButton.Visible = false
	else
		ui.OmenTitle.Text = "Today's Omen is waiting"
		ui.OmenText.Text = "One free sign from the heavens every day. Tap to read it."
		ui.OmenButton.Visible = not s.Dead
	end

	local goal, progress = goalFor(s)
	ui.GoalText.Text = goal
	ui.GoalBar.Visible = progress ~= nil
	if progress then
		S.setBar(ui.GoalFill, math.clamp(progress, 0, 1))
	end

	-- Three things to do, most useful first.
	local list = {}
	local function add(icon, title, why, run)
		if #list < 3 then
			table.insert(list, { icon, title, why, run })
		end
	end
	if s.Dead then
		add("♻", "Choose how to return", "Continue as your heir, or as a random soul.", function() if ctx.OpenRebirth then ctx.OpenRebirth() end end)
		add("*", "Visit the Wheel", "Spin talents before you return.", function() ctx.SelectTab("Lineage") end)
	else
		if s.HasPendingEvent then
			add("❗", "Resolve your life event", "Something is waiting for your choice.", nil)
		end
		if not ui.OmenClaimed then
			add("🔮", "Read today's omen", "A free boon, once a day.", function() ctx.Remotes.ChronicleAction:FireServer("Omen") end)
		end
		local games = ctx.Content.Get("MinigamesConfig")
		for _, id in (ctx.MinigamesAvailable and ctx.MinigamesAvailable(s)) or {} do
			add(games[id].Icon, games[id].Name, games[id].Description, function() ctx.OpenMinigame(id) end)
		end
		local action = s.Actions > 0 and trainingSuggestion(s)
		if action then
			add("⚡", action.Name, ("Uses 1 action  ·  %d / %d left"):format(s.Actions, s.MaxActions), function() ctx.Remotes.Train:FireServer(action.Id) end)
		end
		if (s.Social or 0) > 0 and ctx.GamePack.IsEnabled("Relationships") then
			add("👥", "Spend time with someone", ("Social %d / %d left this year"):format(s.Social, s.MaxSocial or 0), function() ctx.SelectTab("Social") end)
		end
		if s.Actions == 0 and not s.HasPendingEvent then
			add("▶", "AGE UP", "Your actions are spent: live the next year.", function() ctx.Remotes.AdvanceYear:FireServer() end)
		end
		add("📜", "Read your chronicle", "Every year of this life, written down.", function() ctx.SelectTab("Journal") end)
		add("💪", "Train your body and mind", "Open the training grounds.", function() ctx.SelectTab("Training") end)
	end
	for i = 1, 3 do
		local item = list[i]
		ui.Todo[i].Card.Visible = item ~= nil
		if item then
			setTodo(i, item[1], item[2], item[3], item[4])
		end
	end
end

-- Chronicle feed (UIController forwards the journal's entries).
function Page.AddEntry(entry)
	if entry == lastEntry then
		return
	end
	lastEntry = entry
	Page.Type(ui.StoryText, ('<font color="#%s"><b>Age %d</b></font>   %s'):format(C.gold:ToHex(), entry.Age, S.escape(entry.Text)))
end

function Page.Rebuild(log)
	local entry = log and log[#log]
	if entry then
		lastEntry = entry
		ui.StoryText.MaxVisibleGraphemes = -1
		ui.StoryText.Text = ('<font color="#%s"><b>Age %d</b></font>   %s'):format(C.gold:ToHex(), entry.Age, S.escape(entry.Text))
	end
end

return Page
