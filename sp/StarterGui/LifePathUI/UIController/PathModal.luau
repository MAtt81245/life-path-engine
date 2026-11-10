--[[
	PathModal: YOUR PATH, the full-screen constellation of this life's decisions
	(Modules/PathSystem through the PathQuery remote function).

	Left: the decisions as stars joined by a golden line, each with faint branches for
	the roads not taken. Right: the selected decision: WHAT HAPPENED, YOUR CHOICE, ROADS
	NOT TAKEN, HOW EVERYONE CHOSE (real counts; hidden below the sample minimum),
	CONSEQUENCES, HOW THE WORLD REMEMBERS IT, and the golden Return to This Path button
	(developer product PathRewind) for recent decisions of this session.

	Init(ctx), Open(), Close(), Render(snapshot).
]]

local RunService = game:GetService("RunService")

local Modal = {}

local ctx, S, C, Monetization
local ui = {}
local nodes = {}
local selected = nil
local state = nil
local queryToken = 0

local STEP_X = 150 -- canvas pixels between decisions
local ROW_Y = { 0.5, 0.3, 0.62, 0.38, 0.7, 0.45 } -- the constellation's gentle zig-zag

local function scale(x, y) return UDim2.fromScale(x, y) end

local function section(parent, order: number, title: string)
	S.autoLabel({ Name = title, Text = title, Font = S.Fonts.Heavy, TextColor3 = C.gold, LayoutOrder = order, Parent = parent }, 12)
	return S.autoLabel({ Name = title .. "Body", Text = "", RichText = true, LayoutOrder = order + 1, Parent = parent }, 14)
end

-- A straight golden line between two canvas points.
local function line(parent, a: Vector2, b: Vector2, color: Color3, transparency: number, thickness: number)
	local delta = b - a
	return S.new("Frame", {
		Name = "Line", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2),
		Size = UDim2.fromOffset(delta.Magnitude, thickness), Rotation = math.deg(math.atan2(delta.Y, delta.X)),
		BackgroundColor3 = color, BackgroundTransparency = transparency, BorderSizePixel = 0, ZIndex = 2, Parent = parent,
	})
end

function Modal.Init(context)
	ctx = context
	S = ctx.Style
	C = S.C
	Monetization = ctx.Config.Monetization
	local overlay = S.new("Frame", { Name = "PathModal", Size = scale(1, 1), BackgroundColor3 = C.ink, BackgroundTransparency = 0.12,
		BorderSizePixel = 0, ZIndex = 60, Visible = false, Parent = ctx.Gui })
	ctx.Shield.Attach(overlay)
	local card = S.new("Frame", { Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = scale(0.5, 0.5), Size = scale(0.96, 0.92), ZIndex = 61, Parent = overlay })
	S.padding(card, 18, 14)
	ctx.Theme.frame(card, 16, C.panel1, C.bg2)
	ui.Title = S.label({ Name = "Title", Text = "YOUR PATH", Font = S.Fonts.Title, TextColor3 = C.gold, Size = scale(0.5, 0.08), ZIndex = 62, Parent = card }, 30)
	ui.Sub = S.label({ Name = "Sub", Text = "", TextColor3 = C.muted, Position = scale(0, 0.08), Size = scale(0.6, 0.05), ZIndex = 62, Parent = card }, 14)
	local close = S.ghostButton({ Name = "Close", Text = "Close", Position = scale(0.86, 0), Size = scale(0.14, 0.07), ZIndex = 62, Parent = card }, 15)
	close:SetAttribute("TouchSafe", true) -- header button; a 44 px minimum covered the title on phones
	close.Activated:Connect(Modal.Close)

	-- The constellation (scrolls sideways as the life grows).
	local map = S.new("ScrollingFrame", { Name = "Constellation", Position = scale(0, 0.15), Size = scale(0.6, 0.85), BackgroundColor3 = C.ink,
		BackgroundTransparency = 0.3, BorderSizePixel = 0, ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 5,
		ScrollBarImageColor3 = C.gold, CanvasSize = UDim2.new(), ZIndex = 62, Parent = card })
	S.new("UICorner", { CornerRadius = UDim.new(0, S.radius(12)), Parent = map })
	S.new("UIStroke", { Color = C.stroke, Thickness = 1, Transparency = 0.6, Parent = map })
	ui.Map = map
	ui.Empty = S.label({ Name = "Empty", Text = "No decisions yet. Every life event you answer becomes a star here.", TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Center, Position = scale(0.1, 0.45), Size = scale(0.8, 0.1), ZIndex = 63, Visible = false, Parent = map }, 16)

	-- The node card.
	local detail = S.new("ScrollingFrame", { Name = "NodeCard", Position = scale(0.62, 0.15), Size = scale(0.38, 0.72), BackgroundColor3 = C.card2,
		BackgroundTransparency = 0.2, BorderSizePixel = 0, ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.gold, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 62, Parent = card })
	S.new("UICorner", { CornerRadius = UDim.new(0, S.radius(12)), Parent = detail })
	S.new("UIStroke", { Color = C.gold, Thickness = 1, Transparency = 0.45, Parent = detail })
	S.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = detail })
	S.list(detail, UDim.new(0, 4))
	ui.NodeTitle = S.autoLabel({ Name = "NodeTitle", Text = "", Font = S.Fonts.Title, TextColor3 = C.text, LayoutOrder = 0, Parent = detail }, 20)
	ui.Happened = section(detail, 10, "WHAT HAPPENED")
	ui.Choice = section(detail, 20, "YOUR CHOICE")
	ui.Choice.TextColor3 = C.gold
	ui.Roads = section(detail, 30, "ROADS NOT TAKEN")
	ui.Roads.TextColor3 = C.muted
	ui.Everyone = section(detail, 40, "HOW EVERYONE CHOSE")
	ui.Consequences = section(detail, 50, "CONSEQUENCES")
	ui.World = section(detail, 60, "HOW THE WORLD REMEMBERS IT")
	ui.World.Font = S.Fonts.Title
	for _, label in detail:GetChildren() do
		if label:IsA("TextLabel") then
			label.ZIndex = 63
		end
	end

	local offer = Monetization.ProductsById.PathRewind
	ui.Rewind = S.button({ Name = "Rewind", Text = ("«  Return to This Path  ·  %d R$"):format(offer and offer.Robux or 99), Font = S.Fonts.Heavy,
		Position = scale(0.62, 0.885), Size = scale(0.38, 0.075), ZIndex = 62, Parent = card }, nil, nil, 17)
	ui.RewindHint = S.label({ Name = "RewindHint", Text = "", TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Center,
		Position = scale(0.62, 0.962), Size = scale(0.38, 0.038), ZIndex = 62, Parent = card }, 12)
	ui.Rewind.Activated:Connect(function()
		if not selected or not ui.Rewind.Active then
			return
		end
		ctx.Remotes.PathAction:FireServer("SelectRewind", selected.Id)
		task.wait(0.25)
		ctx.Remotes.ShopAction:FireServer("BuyProduct", "PathRewind", RunService:IsStudio()) -- Studio: free test purchase
		Modal.Close()
	end)
	ui.Overlay = overlay
end

local function everyoneText(node, counts, minSample): string
	local total = 0
	for _, count in counts or {} do
		total += count
	end
	if total < minSample then
		return ("Not enough players have faced this yet (%d so far). Percentages appear at %d."):format(total, minSample)
	end
	local lines = {}
	for i, text in node.Options do
		local count = counts[i] or 0
		local pct = math.floor(count / total * 100 + 0.5)
		local mine = i == node.ChoiceIndex
		table.insert(lines, ('%s<b>%d%%</b> chose "%s"%s'):format(if mine then ("<font color=\"#%s\">"):format(C.gold:ToHex()) else "",
			pct, S.escape(text), if mine then "</font>" else ""))
	end
	table.insert(lines, ("(%s players)"):format(S.commas and S.commas(total) or tostring(total)))
	return table.concat(lines, "\n")
end

local function paintStars()
	for _, entry in ui.Stars or {} do
		local on = selected and entry.Node.Id == selected.Id
		entry.Star.BackgroundColor3 = if on then C.gold else (if entry.Node.Success then C.qi1 else C.rose1)
		entry.Glow.Size = if on then UDim2.fromOffset(40, 40) else UDim2.fromOffset(28, 28)
	end
end

local function selectNode(node)
	selected = node
	paintStars()
	ui.NodeTitle.Text = ("Age %d  ·  Year %d  ·  %s"):format(node.Age, node.Year or 0, S.escape(node.Title or ""))
	ui.Happened.Text = S.escape(node.Text or "")
	ui.Choice.Text = '"' .. S.escape(node.Choice or "?") .. '"'
	local roads = {}
	for i, text in node.Options or {} do
		if i ~= node.ChoiceIndex then
			table.insert(roads, "·  " .. S.escape(text))
		end
	end
	ui.Roads.Text = if #roads > 0 then table.concat(roads, "\n") else "There was no other road."
	ui.Consequences.Text = S.escape(node.Result or "") .. (if node.Summary and node.Summary ~= "" then "\n" .. S.escape(node.Summary) else "")
	ui.Consequences.TextColor3 = if node.Success then C.text else C.red
	ui.World.Text = S.escape(node.Remembered or "")
	ui.Everyone.Text = "Counting the choices of every player..."
	S.setEnabled(ui.Rewind, false)
	ui.RewindHint.Text = ""
	queryToken += 1
	local token = queryToken
	task.spawn(function()
		local ok, info = pcall(function()
			return ctx.Remotes:WaitForChild("PathQuery"):InvokeServer(node.Id)
		end)
		if token ~= queryToken or not ui.Overlay.Visible then
			return
		end
		if not ok or not info then
			ui.Everyone.Text = "The world's records are out of reach right now."
			return
		end
		ui.Everyone.Text = everyoneText(node, info.Counts, info.MinSample or 50)
		local alive = state ~= nil and not state.Dead
		S.setEnabled(ui.Rewind, info.Rewindable == true and alive)
		ui.RewindHint.Text = if info.Rewindable and alive then "Choose this decision again. Your account progress is kept."
			else "Only your latest decisions of this session can be revisited."
	end)
end

local function build(list)
	for _, child in ui.Map:GetChildren() do
		if child:IsA("GuiObject") and child ~= ui.Empty then
			child:Destroy()
		end
	end
	nodes = list or {}
	ui.Stars = {}
	ui.Empty.Visible = #nodes == 0
	local height = math.max(200, ui.Map.AbsoluteSize.Y)
	local width = math.max(ui.Map.AbsoluteSize.X, 80 + #nodes * STEP_X)
	ui.Map.CanvasSize = UDim2.fromOffset(width, 0)
	local points = {}
	for i, node in nodes do
		points[i] = Vector2.new(60 + (i - 1) * STEP_X, ROW_Y[(i - 1) % #ROW_Y + 1] * height)
	end
	for i, node in nodes do
		local at = points[i]
		if points[i + 1] then
			line(ui.Map, at, points[i + 1], C.gold, 0.15, 3)
		end
		-- Roads not taken: faint branches ending in hollow stars.
		local other = 0
		for optionIndex in node.Options or {} do
			if optionIndex ~= node.ChoiceIndex then
				other += 1
				local up = if other % 2 == 1 then -1 else 1
				local tip = at + Vector2.new(34 + other * 6, up * (38 + other * 10))
				line(ui.Map, at, tip, C.muted, 0.7, 1)
				local ghost = S.new("Frame", { Name = "Road", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(tip.X, tip.Y),
					Size = UDim2.fromOffset(9, 9), BackgroundTransparency = 1, ZIndex = 3, Parent = ui.Map })
				S.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ghost })
				S.new("UIStroke", { Color = C.muted, Thickness = 1, Transparency = 0.4, Parent = ghost })
			end
		end
		local glow = S.new("Frame", { Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(at.X, at.Y),
			Size = UDim2.fromOffset(28, 28), BackgroundColor3 = C.gold, BackgroundTransparency = 0.8, BorderSizePixel = 0, ZIndex = 4, Parent = ui.Map })
		S.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = glow })
		local star = S.new("TextButton", { Name = "Star" .. node.Id, Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(at.X, at.Y), Size = UDim2.fromOffset(16, 16), Rotation = 45, BorderSizePixel = 0, ZIndex = 5, Parent = ui.Map })
		S.new("UIStroke", { Color = C.text, Thickness = 1, Transparency = 0.3, Parent = star })
		S.label({ Name = "Age", Text = ("Age %d"):format(node.Age), TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(at.X, at.Y + 16), Size = UDim2.fromOffset(110, 16), ZIndex = 5, Parent = ui.Map }, 12)
		S.label({ Name = "Caption", Text = node.Title or "", Font = S.Fonts.Bold, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(at.X, at.Y - 14), Size = UDim2.fromOffset(130, 30), ZIndex = 5, Parent = ui.Map }, 12)
		star.Activated:Connect(function()
			selectNode(node)
		end)
		table.insert(ui.Stars, { Node = node, Star = star, Glow = glow })
	end
	if #nodes > 0 then
		selectNode(nodes[#nodes])
		ui.Map.CanvasPosition = Vector2.new(math.max(0, width - ui.Map.AbsoluteSize.X), 0)
	else
		selected = nil
		ui.NodeTitle.Text = "Your path begins here."
		for _, label in { ui.Happened, ui.Choice, ui.Roads, ui.Everyone, ui.Consequences, ui.World } do
			label.Text = "—"
		end
		S.setEnabled(ui.Rewind, false)
		ui.RewindHint.Text = ""
	end
end

function Modal.Open()
	ui.Overlay.Visible = true
	ui.Sub.Text = "Reading the stars..."
	task.spawn(function()
		local ok, info = pcall(function()
			return ctx.Remotes:WaitForChild("PathQuery"):InvokeServer("List")
		end)
		if not ui.Overlay.Visible then
			return
		end
		if not ok or not info then
			ui.Sub.Text = "The stars are clouded. Try again in a moment."
			return
		end
		ui.Sub.Text = ("%s  ·  Life #%d  ·  born in the year %d  ·  %d decision%s"):format(info.Name or "", info.Lives or 1, info.BirthYear or 0,
			#(info.Nodes or {}), if #(info.Nodes or {}) == 1 then "" else "s")
		build(info.Nodes)
	end)
end

function Modal.Close()
	ui.Overlay.Visible = false
end

function Modal.IsOpen(): boolean
	return ui.Overlay ~= nil and ui.Overlay.Visible
end

function Modal.Render(s)
	state = s
end

return Modal
