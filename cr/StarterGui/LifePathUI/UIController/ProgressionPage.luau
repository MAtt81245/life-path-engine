--[[
	Progression tab: mastery trees (Intellect, Physical, Social, Artifacts) and titles.
]]

local Page = {}

local ctx, root, S, C, Config
local nodeButtons = {}

local function scale(x, y) return UDim2.fromScale(x, y) end

function Page.Init(context, frame)
	ctx, root = context, frame
	S, Config = ctx.Style, ctx.Config
	C = S.C
	local center = Enum.TextXAlignment.Center

	local hasMasteries, hasTitles = ctx.GamePack.IsEnabled("Masteries"), ctx.GamePack.IsEnabled("Titles")
	root.MasteriesPanel.Visible = hasMasteries
	root.TitlesPanel.Visible = hasTitles
	if hasTitles and not hasMasteries then
		root.TitlesPanel.Position, root.TitlesPanel.Size = UDim2.fromScale(0, 0), UDim2.fromScale(1, 1)
	elseif hasMasteries and not hasTitles then
		root.MasteriesPanel.Size = UDim2.fromScale(1, 1)
	end

	local branches = root.MasteriesPanel.Branches
	for i, branch in Config.Masteries.Branches do
		local column = S.panel("Frame", { Name = branch.Id, LayoutOrder = i, Size = scale(0.235, 1), Parent = branches }, C.panel1, C.panel2, 12, branch.Color)
		S.padding(column, 8)
		S.label({ Name = "BranchName", Text = branch.Name, Font = S.Fonts.Bold, TextColor3 = branch.Color, Size = scale(1, 0.07), TextXAlignment = center, Parent = column }, 16)
		local list = S.new("Frame", { Name = "Nodes", BackgroundTransparency = 1, Position = scale(0, 0.09), Size = scale(1, 0.91), Parent = column })
		S.list(list, UDim.new(0.025, 0))
		for j, node in branch.Nodes do
			local button = S.new("TextButton", { Name = node.Id, LayoutOrder = j, Text = "", AutoButtonColor = false, Size = scale(1, 0.23), Parent = list })
			S.decorate(button, C.card1, C.card2, C.stroke, 10)
			S.padding(button, 6)
			S.label({ Name = "NodeName", Text = node.Name, Font = S.Fonts.Bold, Size = scale(1, 0.3), TextXAlignment = center, Parent = button }, 13)
			S.label({ Name = "Desc", Text = node.Description, TextColor3 = C.muted, Position = scale(0, 0.32), Size = scale(1, 0.42), TextXAlignment = center, Parent = button }, 11)
			S.label({ Name = "Status", Text = "", Font = S.Fonts.Bold, Position = scale(0, 0.76), Size = scale(1, 0.24), TextXAlignment = center, Parent = button }, 11)
			button.Activated:Connect(function()
				ctx.Remotes.ProgressionAction:FireServer("Unlock", node.Id)
			end)
			nodeButtons[node.Id] = { Button = button, Node = node, Branch = branch }
		end
	end
end

local function renderTitles(s)
	local panel = root.TitlesPanel
	S.clear(panel.Scroll)
	for i, title in Config.Titles.List do
		local unlocked = s.Titles.Unlocked[title.Id] == true
		local equipped = table.find(s.Titles.Equipped, title.Id) ~= nil
		local row = S.panel("Frame", { Name = title.Id, LayoutOrder = if unlocked then i else 100 + i, Size = UDim2.new(1, -8, 0, 64), Parent = panel.Scroll },
			C.panel1, C.panel2, 10, if equipped then C.gold else C.stroke)
		S.padding(row, 8)
		S.label({ Text = title.Name, Font = S.Fonts.Bold, TextColor3 = if unlocked then C.gold else C.muted, Size = scale(0.7, 0.36), Parent = row }, 14)
		S.label({ Text = title.Description, Position = scale(0, 0.38), Size = scale(0.7, 0.3), Parent = row }, 12)
		if not unlocked then
			local _, items = ctx.Requirements.Evaluate(s, title.Requires)
			S.label({ Text = S.requirementText(items), RichText = true, Position = scale(0, 0.7), Size = scale(0.7, 0.3), Parent = row }, 11)
		end
		local props = { Text = if equipped then "Unequip" elseif unlocked then "Equip" else "Locked",
			AnchorPoint = Vector2.new(1, 0.5), Position = scale(1, 0.5), Size = scale(0.27, 0.6), Parent = row }
		local button = if unlocked then S.button(props, nil, nil, 13) else S.ghostButton(props, 13)
		local enabled = unlocked and not s.Dead
		S.setEnabled(button, enabled)
		button.Activated:Connect(function()
			if enabled then
				ctx.Remotes.ProgressionAction:FireServer("Equip", title.Id)
			end
		end)
	end
	panel.EquippedLabel.Text = ("Equipped %d / %d"):format(#s.Titles.Equipped, s.MaxEquippedTitles)
end

function Page.Render(s)
	root.MasteriesPanel.PointsLabel.Text = ("%d point%s"):format(s.MasteryPoints, if s.MasteryPoints == 1 then "" else "s")
	for id, entry in nodeButtons do
		local node, branch, button = entry.Node, entry.Branch, entry.Button
		local unlocked = s.Masteries[id] == true
		local available = not unlocked and (not node.Previous or s.Masteries[node.Previous]) and s.MasteryPoints >= node.Cost
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if unlocked then
			stroke.Color, stroke.Transparency = branch.Color, 0.1
			button.Status.Text, button.Status.TextColor3 = "UNLOCKED", branch.Color
			button.NodeName.TextColor3 = branch.Color
		else
			stroke.Color = if available then C.gold else C.stroke
			stroke.Transparency = if available then 0.2 else 0.7
			button.Status.Text = ("Cost %d"):format(node.Cost)
			button.Status.TextColor3 = if available then C.gold else C.muted
			button.NodeName.TextColor3 = if available then C.text else C.muted
		end
	end
	renderTitles(s)
end

return Page
