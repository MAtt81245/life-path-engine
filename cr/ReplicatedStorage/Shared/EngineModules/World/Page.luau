--[[
	Map tab (client) of the World engine module: an ancient cartography canvas with
	drawn roads between neighboring regions, the current region marked in jade, and a
	side panel with the selected region's lore, Qi density, modifiers and the Travel
	button (TravelAction remote; Modules/RegionSystem validates and rolls the road
	encounter). Travel reasons mirror RegionSystem.Check for instant feedback.
]]

local TweenService = game:GetService("TweenService")

local Page = {}

local ctx, root, S, C, Regions
local ui = { Nodes = {}, Roads = {} }
local selected = nil
local latest = nil

local function scale(x, y) return UDim2.fromScale(x, y) end

local PARCHMENT1, PARCHMENT2 = Color3.fromRGB(46, 38, 26), Color3.fromRGB(24, 19, 12)
local INK = Color3.fromRGB(200, 164, 93)

local function roadKey(a: string, b: string): string
	return if a < b then a .. "|" .. b else b .. "|" .. a
end

-- Roads are rotated frames sized in pixels, so they are redrawn when the canvas resizes.
local function drawRoads()
	local size = ui.Canvas.AbsoluteSize
	if size.X < 1 then
		return
	end
	for key, road in ui.Roads do
		local a, b = road.A.MapPosition, road.B.MapPosition
		local pa, pb = Vector2.new(a.X * size.X, a.Y * size.Y), Vector2.new(b.X * size.X, b.Y * size.Y)
		local delta = pb - pa
		road.Line.Position = UDim2.fromScale((a.X + b.X) / 2, (a.Y + b.Y) / 2)
		road.Line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
		road.Length = delta.Magnitude
		road.Line.Size = UDim2.new(0, road.Length, 0, road.Line.Size.Y.Offset)
	end
end

local function travelReason(s, region): (string?, number)
	local here = s.Modules and s.Modules.World and s.Modules.World.Region
	local fee = region.TravelFee or 0
	if s.Dead then
		return "The dead do not travel.", fee
	elseif here == region.Id then
		return "You are here.", fee
	elseif s.Age < Regions.TravelMinAge then
		return ("You must be %d to travel alone."):format(Regions.TravelMinAge), fee
	elseif not Regions.AreNeighbors(here or "", region.Id) then
		return "No road leads there from here.", fee
	end
	local met, items = ctx.Requirements.Evaluate(s, region.Requires)
	if not met and region.AltRequires and ctx.Requirements.Check(s, region.AltRequires) then
		met, fee = true, region.AltFee or fee -- the sect toll instead of the realm
	end
	if not met then
		local alt = if region.AltRequires then (" (or age %d + %s toll)"):format(region.AltRequires.MinAge or 0, S.money(region.AltFee or 0)) else ""
		return "Requires " .. ctx.Requirements.UnmetText(items) .. alt, fee
	elseif s.Actions < Regions.TravelSlots then
		return "No actions left this year.", fee
	elseif s.Money < fee then
		return "Not enough money for the journey.", fee
	end
	return nil, fee
end

local function modifierText(region): string
	local parts = {}
	local buffs = region.Buffs or {}
	table.insert(parts, ("Qi density x%.2f"):format(buffs.QiMult or 1))
	if buffs.StudyMult then table.insert(parts, ("Study +%d%%"):format(math.floor((buffs.StudyMult - 1) * 100 + 0.5))) end
	if buffs.SalaryMult then table.insert(parts, ("Salary +%d%%"):format(math.floor((buffs.SalaryMult - 1) * 100 + 0.5))) end
	for key, mult in buffs.StatXp or {} do
		local stat = ctx.Config.Stats.Stats[key]
		table.insert(parts, ("%s XP +%d%%"):format(stat and stat.Name or key, math.floor((mult - 1) * 100 + 0.5)))
	end
	for key, mult in buffs.ProficiencyXp or {} do
		local prof = ctx.Config.Training.Proficiencies[key]
		table.insert(parts, ("%s XP +%d%%"):format(prof and prof.Name or key, math.floor((mult - 1) * 100 + 0.5)))
	end
	for _, feature in region.Features or {} do
		table.insert(parts, feature)
	end
	return "• " .. table.concat(parts, "\n• ")
end

local function showInfo()
	local s = latest
	local region = Regions.ById[selected or ""] or Regions.Get(nil)
	ui.Name.Text = region.Icon .. "  " .. region.Name
	ui.Name.TextColor3 = region.Color
	ui.Tagline.Text = "“" .. region.Tagline .. "”"
	ui.Lore.Text = region.Lore
	ui.Safety.Text = ("Safety: %s%s"):format(region.Safety or "?", if region.Starter then "  ·  birthplace" else "")
	ui.Mods.Text = modifierText(region)
	if not s then
		return
	end
	local reason, fee = travelReason(s, region)
	ui.Fee.Text = ("Journey: 1 action  ·  %s"):format(S.money(fee))
	ui.Reason.Text = reason or "The road is open. A journey always has its surprises."
	ui.Reason.TextColor3 = if reason then C.muted else C.green
	ui.Travel.Text = if reason == "You are here." then "◆  You are here" else "Travel  →"
	S.setEnabled(ui.Travel, reason == nil)
end

local function paintMap(s)
	local here = s.Modules and s.Modules.World and s.Modules.World.Region
	for id, node in ui.Nodes do
		local region = node.Region
		local isHere = id == here
		local reachable = travelReason(s, region) == nil
		local stroke = node.Button:FindFirstChildOfClass("UIStroke")
		stroke.Color = if isHere then C.qi1 elseif id == selected then C.gold else INK
		stroke.Thickness = if isHere or id == selected then 3 else 1.5
		node.Button.BackgroundColor3 = if isHere then C.jade2 else PARCHMENT2
		node.Button.TextTransparency = if isHere or reachable or s.Age >= Regions.TravelMinAge then 0 else 0.35
		node.Here.Visible = isHere
		node.Label.TextColor3 = if isHere then C.qi1 else C.text
	end
	for _, road in ui.Roads do
		local fromHere = road.A.Id == here or road.B.Id == here
		road.Line.BackgroundColor3 = if fromHere then C.qi1 else INK
		road.Line.BackgroundTransparency = if fromHere then 0.1 else 0.55
	end
end

function Page.Init(context, frame)
	ctx, root = context, frame
	S = ctx.Style
	C = S.C
	Regions = ctx.Content.Get("WorldRegionsConfig")
	selected = Regions.Default

	-- Left: the cartography canvas
	local mapPanel = S.new("Frame", { Name = "MapPanel", Size = scale(0.64, 1), Parent = root })
	S.padding(mapPanel, 14, 10) -- before the frame: the trim is placed relative to the padding
	if ctx.Theme then ctx.Theme.frame(mapPanel, 14, PARCHMENT1, PARCHMENT2) else S.decorate(mapPanel, PARCHMENT1, PARCHMENT2) end
	S.label({ Name = "Title", Text = "The Known World", Font = S.Fonts.Title, TextColor3 = C.gold, Size = scale(0.6, 0.08), Parent = mapPanel }, 22)
	S.label({ Name = "Compass", Text = "N ↑", Font = S.Fonts.Title, TextColor3 = INK, Position = scale(0.8, 0), Size = scale(0.2, 0.08),
		TextXAlignment = Enum.TextXAlignment.Right, Parent = mapPanel }, 18)
	ui.Canvas = S.new("Frame", { Name = "Canvas", Position = scale(0, 0.1), Size = scale(1, 0.9), BackgroundTransparency = 1, Parent = mapPanel })
	-- Faint ink grid, like an old survey chart.
	for i = 1, 3 do
		S.new("Frame", { Name = "GridV" .. i, Position = scale(i / 4, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = INK, BackgroundTransparency = 0.9, BorderSizePixel = 0, Parent = ui.Canvas })
		S.new("Frame", { Name = "GridH" .. i, Position = scale(0, i / 4), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = INK, BackgroundTransparency = 0.9, BorderSizePixel = 0, Parent = ui.Canvas })
	end
	for _, region in Regions.Regions do
		for _, otherId in region.Neighbors do
			local other = Regions.ById[otherId]
			local key = roadKey(region.Id, otherId)
			if other and not ui.Roads[key] then
				local line = S.new("Frame", { Name = "Road_" .. key, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 0, 0, 3),
					BackgroundColor3 = INK, BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 2, Parent = ui.Canvas })
				S.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = line })
				ui.Roads[key] = { A = region, B = other, Line = line }
			end
		end
	end
	for _, region in Regions.Regions do
		local holder = S.new("Frame", { Name = region.Id, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(region.MapPosition.X, region.MapPosition.Y),
			Size = UDim2.new(0, 120, 0, 74), BackgroundTransparency = 1, ZIndex = 3, Parent = ui.Canvas })
		local button = S.new("TextButton", { Name = "Seal", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0, 44, 0, 44),
			Text = region.Icon, TextScaled = true, Font = S.Fonts.Bold, TextColor3 = C.text, BackgroundColor3 = PARCHMENT2, AutoButtonColor = false, ZIndex = 4, Parent = holder })
		S.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = button })
		S.new("UIStroke", { Color = INK, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = button })
		S.new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = button })
		-- A dark ribbon behind the name keeps it readable over the roads.
		local label = S.label({ Name = "Label", Text = region.Name, Font = S.Fonts.Bold, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 47),
			Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, BackgroundColor3 = PARCHMENT2, BackgroundTransparency = 0.25, ZIndex = 4, Parent = holder }, 12)
		S.new("UICorner", { CornerRadius = UDim.new(0, 6), Parent = label })
		S.new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2), Parent = label })
		local hereTag = S.label({ Name = "Here", Text = "▼ you", Font = S.Fonts.Bold, TextColor3 = C.qi1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -2),
			Size = UDim2.new(0, 60, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Visible = false, Parent = holder }, 11)
		button.Activated:Connect(function()
			selected = region.Id
			if latest then paintMap(latest) end
			showInfo()
		end)
		ui.Nodes[region.Id] = { Region = region, Holder = holder, Button = button, Label = label, Here = hereTag }
	end
	ui.Canvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(drawRoads)
	task.defer(drawRoads)

	-- Right: region details and travel
	local info = S.new("Frame", { Name = "RegionPanel", Position = scale(0.65, 0), Size = scale(0.35, 1), Parent = root })
	S.padding(info, 14, 12)
	if ctx.Theme then ctx.Theme.frame(info, 14) else S.decorate(info) end
	ui.Name = S.label({ Name = "RegionName", Text = "", Font = S.Fonts.Title, TextColor3 = C.gold, Size = scale(1, 0.09), Parent = info }, 20)
	ui.Tagline = S.label({ Name = "Tagline", Text = "", Font = Enum.Font.GothamMedium, TextColor3 = C.gold, Position = scale(0, 0.1), Size = scale(1, 0.1), Parent = info }, 12)
	ui.Lore = S.label({ Name = "Lore", Text = "", TextColor3 = C.muted, Position = scale(0, 0.21), Size = scale(1, 0.15), TextYAlignment = Enum.TextYAlignment.Top, Parent = info }, 12)
	ui.Safety = S.label({ Name = "Safety", Text = "", Font = S.Fonts.Bold, TextColor3 = C.text, Position = scale(0, 0.37), Size = scale(1, 0.05), Parent = info }, 12)
	ui.Mods = S.label({ Name = "Modifiers", Text = "", TextColor3 = C.qi1, Position = scale(0, 0.43), Size = scale(1, 0.3), TextYAlignment = Enum.TextYAlignment.Top, Parent = info }, 12)
	ui.Fee = S.label({ Name = "Fee", Text = "", Font = S.Fonts.Bold, TextColor3 = C.gold, Position = scale(0, 0.74), Size = scale(1, 0.05), Parent = info }, 12)
	ui.Reason = S.label({ Name = "Reason", Text = "", TextColor3 = C.muted, Position = scale(0, 0.8), Size = scale(1, 0.08), Parent = info }, 12)
	ui.Travel = S.button({ Name = "TravelButton", Text = "Travel  →", Position = scale(0, 0.89), Size = scale(1, 0.11), Parent = info }, nil, nil, 16)
	ui.Travel.Activated:Connect(function()
		if latest and selected and travelReason(latest, Regions.ById[selected]) == nil then
			ctx.Remotes:WaitForChild("TravelAction"):FireServer("Travel", selected)
		end
	end)
	showInfo()
end

local lastHere = nil
function Page.Render(s)
	latest = s
	local here = s.Modules and s.Modules.World and s.Modules.World.Region
	if here ~= lastHere then
		-- After a journey (or a new life) the map recenters on where you are.
		lastHere = here
		selected = here or selected
		local node = here and ui.Nodes[here]
		if node then
			local pulse = node.Button:FindFirstChildOfClass("UIStroke")
			pulse.Transparency = 1
			TweenService:Create(pulse, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Transparency = 0 }):Play()
		end
	end
	paintMap(s)
	showInfo()
end

return Page
