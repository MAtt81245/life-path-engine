--[[
	Masters & Sects tab: every master's status and requirements, plus the active
	master's loyalty, legendary technique and loyalty quests.
]]

local Page = {}

local ctx, root, S, C, Config

local function scale(x, y) return UDim2.fromScale(x, y) end

function Page.Init(context, frame)
	ctx, root = context, frame
	S, Config = ctx.Style, ctx.Config
	C = S.C
	local active = root.ActivePanel
	active.SeekButton.Activated:Connect(function() ctx.Remotes.Train:FireServer("SeekMaster") end)
	active.LeaveButton.Activated:Connect(function() ctx.Remotes.MasterAction:FireServer("Leave") end)
	-- Three buttons share the bottom row: Seek, promotion Trial, Leave.
	active.SeekButton.Size = UDim2.fromScale(0.32, 0.08)
	active.SeekButton.Text = "Seek a " .. S.term("MentorName") -- 1 action (the old energy cost label is gone)
	active.LeaveButton.Position, active.LeaveButton.Size = UDim2.fromScale(0.68, 0.92), UDim2.fromScale(0.32, 0.08)
	local trial = active.LeaveButton:Clone()
	trial.Name = "TrialButton"
	trial.Position = UDim2.fromScale(0.34, 0.92)
	trial.Text = "Promotion Trial"
	trial.Parent = active
	trial.Activated:Connect(function() ctx.Remotes.MasterAction:FireServer("Trial") end)
end

local function regionNames(master): string?
	if not master.Regions or not ctx.GamePack.IsEnabled("World") then
		return nil
	end
	local regions = ctx.Content.Get("WorldRegionsConfig")
	local names = {}
	for _, id in master.Regions do
		table.insert(names, regions.Get(id).Name)
	end
	return table.concat(names, " / ")
end

local function masterCard(s, master, order: number)
	local list = root.ListPanel.Scroll
	local known = s.DiscoveredMasters[master.Id]
	-- Discovered masters first; unknown ones collapse into short rumor cards
	local card = S.panel("Frame", { Name = master.Id, LayoutOrder = if known then order else 100 + order,
		Size = UDim2.new(1, -8, 0, if known then 112 else 64), Parent = list },
		C.panel1, C.panel2, 12, if known then master.Color else C.stroke)
	S.padding(card, 10)
	local bold = S.Fonts.Bold

	if not known then
		S.label({ Text = "??? Unknown " .. S.term("MentorName"), Font = bold, TextColor3 = C.muted, Size = scale(0.7, 0.45), Parent = card }, 15)
		local where = regionNames(master)
		S.label({ Text = ("Rumors speak of a %s %s%s. Seek a %s there to find them."):format(master.Discipline, string.lower(S.term("MentorName")), if where then " in " .. where else "", S.term("MentorName")), TextColor3 = C.muted,
			Position = scale(0, 0.52), Size = scale(1, 0.48), Parent = card }, 13)
		return
	end

	local mine = s.Master.Id == master.Id
	local met, items = ctx.Requirements.Evaluate(s, master.Requires)
	S.label({ Text = master.Name .. "  ·  " .. master.Title, Font = bold, TextColor3 = master.Color, Size = scale(0.72, 0.26), Parent = card }, 16)
	S.label({ Text = master.Sect .. "  ·  " .. master.Discipline, TextColor3 = C.muted, Position = scale(0, 0.28), Size = scale(0.72, 0.2), Parent = card }, 13)
	S.label({ Text = "Requires: " .. S.requirementText(items), RichText = true, Position = scale(0, 0.52), Size = scale(0.72, 0.22), Parent = card }, 12)
	S.label({ Text = "Technique: " .. master.Technique.Name, TextColor3 = C.gold, Position = scale(0, 0.76), Size = scale(0.72, 0.24), Parent = card }, 12)

	local status, color
	if mine then
		status, color = "Your " .. string.lower(S.term("MentorName")), C.green
	elseif s.LearnedTechniques[master.Id] then
		status, color = "Technique learned", C.qi1
	elseif met then
		status, color = "Accepting " .. string.lower(S.term("StudentName")) .. "s", C.gold
	else
		status, color = "Requirements not met", C.red
	end
	S.label({ Text = status, Font = bold, TextColor3 = color, Position = scale(0.74, 0), Size = scale(0.26, 0.3), TextXAlignment = Enum.TextXAlignment.Right, Parent = card }, 12)

	local canJoin = met and not s.Master.Id and not s.Dead
	local button = S.button({ Text = if mine then "Joined" else "Join", AnchorPoint = Vector2.new(1, 1), Position = scale(1, 1), Size = scale(0.24, 0.42), Parent = card }, nil, nil, 14)
	S.setEnabled(button, canJoin)
	button.Activated:Connect(function()
		if canJoin then
			ctx.Remotes.MasterAction:FireServer("Join", master.Id)
		end
	end)
end

local function renderActive(s)
	local active = root.ActivePanel
	local master = s.Master.Id and Config.Masters.ById[s.Master.Id]
	S.clear(active.QuestsList)

	if not master then
		active.LoyaltyKey.Text = "LOYALTY"
		local trial = active:FindFirstChild("TrialButton")
		if trial then
			trial.Text = "Promotion Trial"
			S.setEnabled(trial, false)
		end
		local learned = 0
		for _ in s.LearnedTechniques do learned += 1 end
		active.MasterName.Text = "No " .. string.lower(S.term("MentorName"))
		active.MasterName.TextColor3 = C.text
		local mentor = S.term("MentorName")
		active.MasterSect.Text = ("Find a %s with Seek a %s, meet their requirements and join to receive loyalty quests and a legendary technique."):format(string.lower(mentor), mentor)
		active.LoyaltyValue.Text = "—"
		S.setBar(active.LoyaltyBar.Fill, 0)
		active.TechniqueBox.TechName.Text = "Legendary Technique"
		active.TechniqueBox.TechDesc.Text = ("Each %s teaches a unique technique that multiplies your passive gains."):format(string.lower(S.term("MentorName")))
		active.TechniqueBox.TechStatus.Text = ("%d technique%s learned this life"):format(learned, if learned == 1 then "" else "s")
		active.TechniqueBox.TechStatus.TextColor3 = C.muted
		return
	end

	active.MasterName.Text = master.Name
	active.MasterName.TextColor3 = master.Color
	active.MasterSect.Text = ("%s of the %s. %s"):format(master.Title, master.Sect, master.Description)
	active.LoyaltyValue.Text = ("%d / %d"):format(s.Master.Loyalty, Config.Masters.MaxLoyalty)
	local ranks = Config.Masters.SectRanks or {}
	local rankIndex = s.Master.Rank or 1
	local rank, nextRank = ranks[rankIndex], ranks[rankIndex + 1]
	if rank then
		active.LoyaltyKey.Text = ("%s  ·  %s/yr"):format(string.upper(rank.Name), S.money(rank.Stipend or 0))
	end
	local trial = active:FindFirstChild("TrialButton")
	if trial then
		local met = nextRank and ctx.Requirements.Check(s, nextRank.Requires)
		trial.Text = if nextRank then ("Trial: %s"):format(nextRank.Name) else "Highest rank"
		S.setEnabled(trial, met and not s.Dead and s.Actions >= 1)
	end
	S.setBar(active.LoyaltyBar.Fill, s.Master.Loyalty / Config.Masters.MaxLoyalty)

	local learned = s.LearnedTechniques[master.Id]
	local tech = active.TechniqueBox
	tech.TechName.Text = master.Technique.Name
	tech.TechDesc.Text = master.Technique.Description
	tech.TechStatus.Text = if learned then "LEARNED  ·  active this life" else ("Unlocks at %d loyalty"):format(master.TechniqueLoyalty)
	tech.TechStatus.TextColor3 = if learned then C.green else C.muted

	for i, quest in master.Quests do
		local done = s.Master.QuestsDone[tostring(i)]
		local met, items = ctx.Requirements.Evaluate(s, quest.Requires)
		local row = S.panel("Frame", { Name = "Quest", LayoutOrder = i, Size = scale(1, 0.3), Parent = active.QuestsList }, C.panel1, C.panel2, 8)
		S.padding(row, 6)
		S.label({ Text = ("%s  (+%d)"):format(quest.Name, quest.Loyalty), Font = S.Fonts.Bold, TextColor3 = if done then C.green else C.text, Size = scale(0.7, 0.5), Parent = row }, 13)
		S.label({ Text = if done then "Completed" else S.requirementText(items), RichText = true, TextColor3 = C.muted, Position = scale(0, 0.5), Size = scale(0.7, 0.5), Parent = row }, 11)
		local enabled = not done and met and not s.Dead
		local button = S.button({ Text = if done then "Done" else "Complete", AnchorPoint = Vector2.new(1, 0.5), Position = scale(1, 0.5), Size = scale(0.28, 0.8), Parent = row }, nil, nil, 13)
		S.setEnabled(button, enabled)
		button.Activated:Connect(function()
			if enabled then
				ctx.Remotes.MasterAction:FireServer("Quest", i)
			end
		end)
	end
end

function Page.Render(s)
	S.clear(root.ListPanel.Scroll)
	local discovered = 0
	for i, master in Config.Masters.List do
		if s.DiscoveredMasters[master.Id] then
			discovered += 1
		end
		masterCard(s, master, i)
	end
	root.ListPanel.Hint.Text = ("Discovered %d / %d"):format(discovered, #Config.Masters.List)
	renderActive(s)

	local active = root.ActivePanel
	S.setEnabled(active.LeaveButton, s.Master.Id ~= nil and not s.Dead)
	S.setEnabled(active.SeekButton, not s.Dead and s.Age >= 12 and s.Actions >= 1 and (s.ActionCounts.SeekMaster or 0) < 1 and discovered < #Config.Masters.List)
end

return Page
