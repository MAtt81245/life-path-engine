--[[
	Relationships tab: family, friends, rivals and partner with affection bars
	and per-category interactions.
]]

local Page = {}

local ctx, root, S, C, Config
local Npc, personalityNames, goalNames, GeneticsText

local function scale(x, y) return UDim2.fromScale(x, y) end

function Page.Init(context, frame)
	ctx, root = context, frame
	S, Config = ctx.Style, ctx.Config
	C = S.C
	Npc = ctx.Content.Get("NpcBehaviorConfig")
	personalityNames, goalNames = {}, {}
	for _, personality in Npc.Personalities do personalityNames[personality.Id] = personality.Name end
	for _, goal in Npc.Goals do goalNames[goal.Id] = goal.Name end
	GeneticsText = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GeneticsText"))
	root.MeetButton.Activated:Connect(function()
		ctx.Remotes.Train:FireServer("Socialize")
	end)
end

local function canUse(s, rel, interaction): boolean
	if s.Dead or s.Age < 3 or (s.Social or 0) <= 0 then return false end
	if (s.SocialDone or {})[rel.Id] and s.SocialDone[rel.Id][interaction.Id] then return false end
	if rel.Away and interaction.Id == "SpendTime" then return false end
	if interaction.MinAffection and rel.Affection < interaction.MinAffection then return false end
	if interaction.MinAge and s.Age < interaction.MinAge then return false end
	if interaction.OncePerYear and rel.LastHelpAge == s.Age then return false end
	if interaction.MoneyCost and s.Money < interaction.MoneyCost then return false end
	if interaction.MinMoney and s.Money < interaction.MinMoney then return false end
	if interaction.Upbringing and ((rel.Genetics and rel.Genetics.Upbringing) or rel.Age > (interaction.MaxChildAge or math.huge)) then return false end
	if interaction.Id == "Romance" and GeneticsText.RomanceBlock(s, rel) then return false end
	return true
end

-- "Merchant", "Student", "Retired"... from the NPC profile (NpcSystem).
local function lifeLabel(rel): string
	if rel.Occupation then
		return rel.Occupation
	elseif rel.Retired then
		return "Retired"
	end
	for _, stage in Npc.Stages do
		if rel.Age <= stage.MaxAge then
			return if stage.Id == "Adult" then "Between jobs" else stage.Id
		end
	end
	return ""
end

local function infoText(rel): string
	local parts = { ("Age %d"):format(rel.Age), lifeLabel(rel) }
	if rel.Personality and personalityNames[rel.Personality] then
		table.insert(parts, personalityNames[rel.Personality])
	end
	if rel.Married and rel.Category ~= "Partner" and rel.Type ~= "Mother" and rel.Type ~= "Father" then
		table.insert(parts, if (rel.Children or 0) > 0 then ("Married, %d kid%s"):format(rel.Children, if rel.Children == 1 then "" else "s") else "Married")
	end
	if rel.Away then
		table.insert(parts, "Lives far away")
	end
	return table.concat(parts, "  ·  ")
end

local function memoryText(rel): string
	-- Genetics first (spirit root, bloodline, hereditary trait / inherited talents).
	if rel.Genetics then
		local text = GeneticsText.Short(rel.Genetics)
		if rel.Type == "Child" and rel.Genetics.Upbringing then
			text ..= "  ·  " .. rel.Genetics.Upbringing .. " upbringing"
		end
		return "◈ " .. text
	end
	local memory = rel.Memories and rel.Memories[1]
	if memory then
		return ("Remembers: %s (age %d)"):format(memory.Text, memory.Age)
	end
	if rel.Goal and goalNames[rel.Goal] then
		return "Goal: " .. goalNames[rel.Goal]
	end
	return ""
end

function Page.Render(s)
	local RelConfig = Config.Relationships
	local scroll = root.Scroll
	S.clear(scroll)

	local rank = {}
	for i, category in RelConfig.CategoryOrder do
		rank[category] = i
	end
	setmetatable(rank, { __index = function() return #RelConfig.CategoryOrder + 1 end })
	local sorted = table.clone(s.Relationships)
	table.sort(sorted, function(a, b)
		if rank[a.Category] ~= rank[b.Category] then
			return rank[a.Category] < rank[b.Category]
		end
		return a.Affection > b.Affection
	end)

	-- Cards grow with their action rows: a fixed 84 px header (name, info, bar, memory)
	-- over rows of at most five actions (three on phones), so long action lists wrap
	-- instead of shrinking into slivers. Every card in the grid takes the tallest height.
	local phone = require(game:GetService("ReplicatedStorage").Shared.Responsive).Current().Kind == "Phone"
	local rowPx = if phone then 40 else 30
	local function available(rel)
		local list = {}
		for _, interaction in RelConfig.Interactions do
			if interaction.Categories[rel.Category] and ctx.GamePack.IsEnabled(interaction.Module) then
				table.insert(list, interaction)
			end
		end
		return list
	end
	local function perRowFor(n: number): number
		return math.max(1, math.min(n, if phone then 3 else 5))
	end
	local maxRows = 1
	for _, rel in sorted do
		local n = #available(rel)
		maxRows = math.max(maxRows, math.ceil(n / perRowFor(n)))
	end
	local grid = scroll:FindFirstChildOfClass("UIGridLayout")
	if grid then
		grid.CellSize = UDim2.new(grid.CellSize.X.Scale, grid.CellSize.X.Offset, 0, 20 + 84 + maxRows * rowPx + (maxRows - 1) * 6)
	end

	local counts = {}
	for i, rel in sorted do
		counts[rel.Category] = (counts[rel.Category] or 0) + 1
		local category = RelConfig.Categories[rel.Category] or RelConfig.Categories.Family
		local card = S.panel("Frame", { Name = rel.Id, LayoutOrder = i, Parent = scroll }, C.panel1, C.panel2, 12, category.Color)
		S.padding(card, 10)
		S.label({ Text = rel.Name, Font = S.Fonts.Bold, Size = UDim2.new(0.66, 0, 0, 22), Parent = card }, 16)
		local badge = S.label({ Text = RelConfig.Types[rel.Type].Name, Font = S.Fonts.Bold, TextColor3 = C.dark, Position = scale(0.7, 0), Size = UDim2.new(0.3, 0, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Center, Parent = card }, 12)
		S.decorate(badge, category.Color, category.Color:Lerp(Color3.new(0, 0, 0), 0.3), category.Color, 6, 0.3)
		S.label({ Name = "Info", Text = infoText(rel), TextColor3 = C.muted, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(0.72, 0, 0, 17), Parent = card }, 13)
		S.label({ Text = ("%d  ·  %s"):format(rel.Affection, RelConfig.GetLabel(rel.Affection)), Font = S.Fonts.Bold, Position = UDim2.new(0.72, 0, 0, 26), Size = UDim2.new(0.28, 0, 0, 17),
			TextXAlignment = Enum.TextXAlignment.Right, Parent = card }, 13)
		local _, fill = S.bar({ Name = "Affection", Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 9), Parent = card }, category.Color)
		S.setBar(fill, rel.Affection / 100)
		S.label({ Name = "Memory", Text = memoryText(rel), Font = Enum.Font.GothamMedium, TextColor3 = C.violet, Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 16), Parent = card }, 12)

		local interactions = available(rel)
		local perRow = perRowFor(#interactions)
		local rows = math.ceil(#interactions / perRow)
		local row = S.new("Frame", { Name = "Actions", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 84),
			Size = UDim2.new(1, 0, 0, rows * rowPx + (rows - 1) * 6), Parent = card })
		S.list(row, UDim.new(0.015, 0), true)
		row:FindFirstChildOfClass("UIListLayout").Wraps = rows > 1
		local width = (1 - 0.015 * (perRow - 1)) / perRow - 1e-4
		local height = (1 - 0.06 * (rows - 1)) / rows
		-- TextScaled wraps when the label is too wide, so crowded rows use a smaller cap.
		local maxText = if perRow >= 5 then 10 else 12
		for j, interaction in interactions do
			local doneThisYear = (s.SocialDone or {})[rel.Id] and s.SocialDone[rel.Id][interaction.Id]
			local button = S.ghostButton({ Text = if doneThisYear then "Done this year" else interaction.Name, LayoutOrder = j, Size = scale(width, height), TextWrapped = false, Parent = row }, maxText)
			local enabled = canUse(s, rel, interaction)
			S.setEnabled(button, enabled)
			button.Activated:Connect(function()
				if enabled then
					ctx.Remotes.RelationshipAction:FireServer(rel.Id, interaction.Id)
				end
			end)
		end
	end

	if #sorted == 0 then
		S.label({ Text = "No one is in your life right now. Go meet people!", TextColor3 = C.muted, Parent = scroll }, 15)
	end
	root.SummaryLabel.Text = ("%d family  ·  %d friends  ·  %d rivals%s%s  ·  %d/%d social"):format(counts.Family or 0, counts.Friend or 0, counts.Rival or 0,
		if counts.Partner then "  ·  1 partner" else "", if counts.Child then ("  ·  %d children"):format(counts.Child) else "", s.Social or 0, s.MaxSocial or 0)
	local meet = Config.Training.ById.Socialize
	root.MeetButton.Text = if meet then ("Meet People  ·  %d / %d this year"):format(s.ActionCounts.Socialize or 0, meet.MaxPerYear or Config.Training.DefaultMaxPerYear) else "Meet People"
	S.setEnabled(root.MeetButton, meet ~= nil and not s.Dead and s.Age >= meet.MinAge and s.Actions >= 1
		and (s.ActionCounts.Socialize or 0) < (meet.MaxPerYear or Config.Training.DefaultMaxPerYear))
end

return Page
