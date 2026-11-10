--[[
	Lineage tab: the living Dynasty & Reincarnation tree, drawn on a draggable canvas
	with zoom (- / Fit / + buttons, mouse wheel, pinch); node text never leaves its card.
	- Family units: a person or a couple plus the units of their children. Each unit
	  measures its subtree (width = max(members, sum of children widths)) and children
	  are laid out side by side beneath it, so new generations (grandchildren) widen only
	  their own branch and nothing ever overlaps.
	- Orthogonal connectors (no rotation): a marriage line between a couple, a stem down
	  from its middle to a horizontal bus, and a drop from the bus to each child.
	- Rows: 0 grandparents, 1 parents (+ uncles/aunts), 2 past lives -> you (+ spouse),
	  siblings, cousins, 3 your children (+ their spouses), 4 your grandchildren.
	  Gold = bloodline, cyan = soul leap, rose = marriage.
	- Past lives fade with "the Mist of Time" (Shared/LineageMemory).
	- Side panel: the selected record, a child's genetics with the heir choices between
	  lives (Reincarnate ChooseHeir: take over at their age, or be reborn as their newborn),
	  and the Ancestral Heirloom controls (DynastyAction).
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Page = {}

local ctx, root, S, C, Config, Memory, Genetics
local ui = {}
local treeKey = nil
local latest = nil
local selectedNode = nil

-- Grid units (design pixels; a UIScale fits the height to the canvas).
local NODE_W, NODE_H = 168, 88
local COL_W, ROW_H = 190, 128
local PAD = 24
local LINE = 3
local SOUL, BLOOD, BOND = Color3.fromRGB(88, 214, 220), Color3.fromRGB(214, 178, 104), Color3.fromRGB(230, 130, 190)
local TAKEOVER_CAP = 25 -- adults are taken over at this age snapshot (WheelSystem)

local function scale(x, y) return UDim2.fromScale(x, y) end

local function initials(name: string?): string
	local out = ""
	for word in string.gmatch(name or "?", "%a+") do
		out ..= string.sub(word, 1, 1)
		if #out >= 2 then break end
	end
	return if out == "" then "?" else out
end

local rowBase = 0
local function cellTopLeft(col: number, row: number): Vector2
	return Vector2.new(PAD + col * COL_W, PAD + (row - rowBase) * ROW_H)
end
local function cellCenter(col: number, row: number): Vector2
	return cellTopLeft(col, row) + Vector2.new(NODE_W / 2, NODE_H / 2)
end

-- Axis-aligned connector segments (never rotated, so they cannot drift).
local function segment(x1: number, y1: number, x2: number, y2: number, color: Color3, delay: number)
	local horizontal = math.abs(y2 - y1) < 0.5
	local left, top = math.min(x1, x2), math.min(y1, y2)
	local width = if horizontal then math.abs(x2 - x1) + LINE else LINE
	local height = if horizontal then LINE else math.abs(y2 - y1) + LINE
	local line = S.new("Frame", {
		Name = "Link", Position = UDim2.fromOffset(left - LINE / 2, top - LINE / 2), Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = color, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1, Parent = ui.Content,
	})
	line:SetAttribute("From", Vector2.new(x1, y1))
	line:SetAttribute("To", Vector2.new(x2, y2))
	TweenService:Create(line, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, delay), { BackgroundTransparency = 0 }):Play()
	return line
end

local function showDetail(node)
	selectedNode = node
	local d = node.Detail
	ui.DName.Text = d.Name
	ui.DTitle.Text = d.Title or ""
	ui.DTitle.TextColor3 = node.Accent or C.gold
	local lines = {}
	for _, field in { { "Region", d.Region }, { ctx.Style.Terms.TierName, d.Realm }, { "Age", d.Age }, { "Occupation", d.Occupation }, { "Cause of death", d.Cause },
		{ "Old rival", d.Rival }, { "Heirloom", d.Heirloom } } do
		if field[2] then
			table.insert(lines, ("<b>%s:</b> %s"):format(field[1], S.escape(tostring(field[2]))))
		end
	end
	for _, line in d.Extra or {} do
		table.insert(lines, line)
	end
	ui.DFields.Text = table.concat(lines, "\n")
	ui.DBio.Text = d.Biography or ""
	-- Heir choices (your living children, between lives).
	local s = latest
	local child = node.Child
	local canChoose = child ~= nil and s ~= nil and s.Dead and ctx.GamePack.IsEnabled("Samsara")
	local wheel = (s and s.Wheel) or {}
	ui.HeirButton.Visible = child ~= nil
	ui.GrandButton.Visible = child ~= nil and child.Age > 18
	if child then
		local takeAge = math.min(child.Age, TAKEOVER_CAP)
		local chosenTake = wheel.Heir == child.Id and wheel.HeirMode ~= "Grandchild"
		local chosenGrand = wheel.Heir == child.Id and wheel.HeirMode == "Grandchild"
		ui.HeirButton.Text = if chosenTake then ("✓ You will continue as %s at %d"):format(child.Name, takeAge)
			elseif canChoose then ("☸  Take over %s at age %d"):format(child.Name, takeAge) else "☸  Heir (choose after death)"
		S.setEnabled(ui.HeirButton, canChoose and not chosenTake)
		ui.GrandButton.Text = if chosenGrand then "✓ You will be their newborn" else ("☸  Be reborn as %s's newborn"):format(child.Name)
		S.setEnabled(ui.GrandButton, canChoose and not chosenGrand)
	end
	for _, other in ui.Nodes do
		local stroke = other.Frame:FindFirstChildOfClass("UIStroke")
		stroke.Thickness = if other == node then 3 else 1.5
	end
end

-- One node at a grid cell: portrait seal, name, two detail lines; dim = memory fade.
local function makeNode(col: number, row: number, detail, accent: Color3, opts)
	opts = opts or {}
	local pos = cellTopLeft(col, row)
	local frame = S.new("TextButton", { Name = opts.Name or "Node", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(pos.X, pos.Y),
		Size = UDim2.fromOffset(NODE_W, NODE_H), ZIndex = 3, Parent = ui.Content })
	local stone = detail.Tier == "Forgotten"
	S.decorate(frame, if stone then Color3.fromRGB(58, 58, 56) else C.card1, if stone then Color3.fromRGB(30, 30, 29) else C.card2, accent, 10, if stone then 0.6 else 0.15)
	local dim = detail.Dim or 0
	frame.BackgroundTransparency = dim * 0.5
	local seal = S.new("Frame", { Name = "Portrait", Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(38, 38), BackgroundColor3 = accent:Lerp(C.ink, 0.55), ZIndex = 4, Parent = frame })
	S.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = seal })
	S.new("UIStroke", { Color = accent, Thickness = 1.5, Transparency = dim, Parent = seal })
	S.label({ Name = "Glyph", Text = if stone then "?" else initials(detail.Name), Font = S.Fonts.Heavy, TextColor3 = accent, Size = scale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = dim * 0.6, ZIndex = 5, Parent = seal }, 16)
	-- Node text has fixed design sizes (the tree's UIScale zooms it) and ends in "..."
	-- when too long, so it can never spill out of the box at any zoom.
	local function nodeText(name: string, text: string, font, color: Color3, position: UDim2, size: UDim2, textSize: number, transparency: number)
		return S.new("TextLabel", {
			Name = name, Text = text, Font = font, TextColor3 = color, Position = position, Size = size, TextSize = textSize,
			TextScaled = false, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center, BackgroundTransparency = 1, TextTransparency = transparency, ZIndex = 4, Parent = frame,
		})
	end
	nodeText("Role", opts.Role or detail.Title or "", S.Fonts.Bold, accent, UDim2.fromOffset(52, 6), UDim2.new(1, -58, 0, 14), 12, dim * 0.5)
	nodeText("NodeName", detail.Name, S.Fonts.Bold, if stone then C.muted else C.text, UDim2.fromOffset(52, 21), UDim2.new(1, -58, 0, 26), 19, dim * 0.6)
	nodeText("Line1", opts.Line1 or detail.Realm or "", S.Fonts.Body, C.muted, UDim2.fromOffset(8, 52), UDim2.new(1, -16, 0, 15), 13, dim * 0.6)
	nodeText("Line2", opts.Line2 or "", S.Fonts.Body, C.muted, UDim2.fromOffset(8, 68), UDim2.new(1, -16, 0, 15), 13, dim * 0.6)
	frame.ClipsDescendants = true -- last line of defence: nothing drawn outside the card
	local node = { Frame = frame, Detail = detail, Accent = accent, Col = col, Row = row, Center = cellCenter(col, row), Child = opts.Child }
	frame.Activated:Connect(function() showDetail(node) end)
	frame.InputBegan:Connect(ui.BeginDrag)
	table.insert(ui.Nodes, node)
	local grow = S.new("UIScale", { Scale = 0.6, Parent = frame })
	TweenService:Create(grow, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, opts.Delay or 0), { Scale = 1 }):Play()
	return node
end

local function personDetail(name: string, role: string, extra)
	return {
		Tier = "Clear", Dim = 0, Name = name, Title = role, Realm = extra and extra.Line or nil, Age = extra and extra.Age,
		Biography = extra and extra.Bio or "", Extra = extra and extra.Extra,
	}
end

local function currentRegionName(s): string?
	local world = s.Modules and s.Modules.World
	local region = world and world.Region and Config.Regions.ById[world.Region]
	return region and region.Name
end

local function geneticsLines(g): ({ string }, string)
	if not g or not Genetics then
		return {}, ""
	end
	return Genetics.Lines(g, Config), Genetics.Short(g, Config)
end

----------------------------------------------------------------------
-- Family units and the tidy layout
----------------------------------------------------------------------

-- member = { Detail, Accent, Opts }; unit = { Members, Children, Row, Width, Cols }
local function member(detail, accent, opts)
	return { Detail = detail, Accent = accent, Opts = opts or {} }
end

local function unit(members, children, row)
	return { Members = members, Children = children or {}, Row = row }
end

local function measure(u): number
	local sum = 0
	for _, child in u.Children do
		sum += measure(child)
	end
	u.Width = math.max(#u.Members, sum, 1)
	return u.Width
end

-- Members centered over their span; children side by side beneath it.
local function place(u, x0: number)
	u.Cols = {}
	local start = x0 + (u.Width - #u.Members) / 2
	for i in u.Members do
		u.Cols[i] = start + i - 1
	end
	local sum = 0
	for _, child in u.Children do
		sum += child.Width
	end
	local cx = x0 + (u.Width - sum) / 2
	for _, child in u.Children do
		place(child, cx)
		cx += child.Width
	end
end

-- Nodes, marriage line, stem, bus and drops for a unit and its descendants.
local function draw(u, delay: number)
	local nodes = {}
	for i, m in u.Members do
		nodes[i] = makeNode(u.Cols[i], u.Row, m.Detail, m.Accent, { Name = m.Opts.Name, Role = m.Opts.Role, Line1 = m.Opts.Line1,
			Line2 = m.Opts.Line2, Child = m.Opts.Child, Delay = delay })
		m.Node = nodes[i]
	end
	if #nodes == 2 then
		segment(nodes[1].Center.X + NODE_W / 2, nodes[1].Center.Y, nodes[2].Center.X - NODE_W / 2, nodes[2].Center.Y, BOND, delay + 0.05)
	end
	if #u.Children > 0 and #nodes > 0 then
		local stemX = if #nodes == 2 then (nodes[1].Center.X + nodes[2].Center.X) / 2 else nodes[1].Center.X
		local stemTop = if #nodes == 2 then nodes[1].Center.Y else nodes[1].Center.Y + NODE_H / 2
		local childTop = cellTopLeft(0, u.Row + 1).Y
		local busY = childTop - (ROW_H - NODE_H) / 2
		segment(stemX, stemTop, stemX, busY, BLOOD, delay + 0.1)
		local minX, maxX = stemX, stemX
		for _, child in u.Children do
			-- The drop lands on the blood relative (the first member of the child unit).
			local x = cellCenter(child.Cols[1], child.Row).X
			minX, maxX = math.min(minX, x), math.max(maxX, x)
			segment(x, busY, x, childTop, BLOOD, delay + 0.15)
		end
		if maxX - minX > 0.5 then
			segment(minX, busY, maxX, busY, BLOOD, delay + 0.12)
		end
	end
	for _, child in u.Children do
		draw(child, delay + 0.08)
	end
end

local function relativeMember(relative, info)
	return member(personDetail(relative.Name, info and info.Name or relative.Role, { Bio = "You met at age " .. tostring(relative.Age or "?") .. "." }), BLOOD,
		{ Role = info and info.Name or relative.Role, Line1 = "Met at age " .. tostring(relative.Age or "?") })
end

local function relMember(rel, role: string, accent: Color3, opts)
	opts = opts or {}
	local lines, short = geneticsLines(rel.Genetics)
	local detail = personDetail(rel.Name, role, { Age = rel.Age, Extra = lines, Bio = opts.Bio })
	return member(detail, accent, {
		Name = opts.Name, Role = role, Line1 = ("Age %d"):format(rel.Age), Child = opts.Child,
		Line2 = opts.Line2 or (if short ~= "" then short elseif rel.Alive == false then "Passed away" else ("Affection %d"):format(math.floor(rel.Affection or 0))),
	})
end

-- Zoom. The content is laid out in design pixels and drawn through ui.Scale. Until the
-- player zooms, the factor keeps nodes readable (AUTO_MIN..AUTO_MAX of a 400 px band);
-- zooming (buttons, Ctrl/mouse wheel, pinch) picks any factor in ZOOM_MIN..ZOOM_MAX and
-- "Fit" shows the whole tree. The canvas always covers the real tree size, so every
-- row (grandchildren included) can be scrolled to.
local designH = 400
local AUTO_MIN, AUTO_MAX = 0.62, 0.78
local ZOOM_MIN, ZOOM_MAX, ZOOM_STEP = 0.15, 1.4, 1.25
local zoom = nil -- nil = automatic, otherwise the chosen factor

local function contentSize(): Vector2
	return Vector2.new(ui.Content.Size.X.Offset, ui.Content.Size.Y.Offset)
end

-- The visible window in the canvas's own pixels. AbsoluteSize is in screen pixels,
-- which include the screen-wide UIScale (StarterPlayerScripts/ResponsiveUI); the
-- canvas, its CanvasPosition and the content work in local pixels.
local function windowSize(): Vector2
	local ratio = 1
	local localWidth = ui.Content.Size.X.Offset * ui.Scale.Scale
	if localWidth > 0 and ui.Content.AbsoluteSize.X > 0 then
		ratio = ui.Content.AbsoluteSize.X / localWidth
	end
	return ui.Canvas.AbsoluteSize / ratio
end

-- The factor that shows the whole tree in the window.
local function fitFactor(): number
	local window, size = windowSize(), contentSize()
	if window.X < 10 or size.X < 1 then
		return AUTO_MAX
	end
	return math.clamp(math.min((window.X - 12) / size.X, (window.Y - 12) / size.Y), ZOOM_MIN, ZOOM_MAX)
end

-- Applies a factor; keepFocus keeps the design point under the window centre in place.
local function applyScale(factor: number, keepFocus: boolean?)
	local window = windowSize()
	local old = ui.Scale.Scale
	local offset = Vector2.new(ui.Content.Position.X.Offset, ui.Content.Position.Y.Offset)
	local focus = (ui.Canvas.CanvasPosition + window / 2 - offset) / math.max(old, 1e-3)
	ui.Scale.Scale = factor
	local size = contentSize() * factor
	ui.Canvas.CanvasSize = UDim2.fromOffset(math.ceil(size.X), math.ceil(size.Y))
	-- Trees smaller than the window sit in its middle.
	local newOffset = Vector2.new(math.max(0, (window.X - size.X) / 2), math.max(0, (window.Y - size.Y) / 2))
	ui.Content.Position = UDim2.fromOffset(newOffset.X, newOffset.Y)
	if keepFocus then
		local target = focus * factor + newOffset - window / 2
		local maxX, maxY = math.max(0, size.X - window.X), math.max(0, size.Y - window.Y)
		ui.Canvas.CanvasPosition = Vector2.new(math.clamp(target.X, 0, maxX), math.clamp(target.Y, 0, maxY))
	end
	if ui.ZoomLabel then
		ui.ZoomLabel.Text = ("%d%%"):format(math.floor(factor * 100 + 0.5))
	end
end

local function fitScale()
	local height = windowSize().Y
	local auto = if height > 10 then math.clamp((height - 8) / designH, AUTO_MIN, AUTO_MAX) else AUTO_MAX
	local factor = zoom or auto
	applyScale(factor, false)
	return factor
end

-- Zoom by a ratio (buttons, wheel, pinch), or to an exact factor.
local function zoomTo(factor: number)
	zoom = math.clamp(factor, ZOOM_MIN, ZOOM_MAX)
	applyScale(zoom, true)
end
local function zoomBy(ratio: number)
	zoomTo(ui.Scale.Scale * ratio)
end

local function buildTree(s)
	S.clear(ui.Content)
	ui.Nodes = {}
	local lives = {}
	for i = #s.Lineage, 1, -1 do
		-- Between lives the ended life is already recorded; the "You" node shows it.
		if s.Lineage[i].Life ~= s.Lives then
			table.insert(lives, s.Lineage[i]) -- oldest first
		end
	end
	local parents, siblings, children, grandRels, partner = {}, {}, {}, {}, nil
	for _, rel in s.Relationships or {} do
		if rel.Type == "Mother" or rel.Type == "Father" or rel.Type == "Parent" then
			table.insert(parents, rel)
		elseif rel.Type == "Sibling" then
			table.insert(siblings, rel)
		elseif rel.Type == "Child" then
			table.insert(children, rel)
		elseif rel.Type == "Grandparent" then
			table.insert(grandRels, rel)
		elseif rel.Type == "Partner" and not partner then
			partner = rel
		end
	end
	local dynasty = s.Modules and s.Modules.Dynasty
	local grands, elders, cousins = {}, {}, {}
	for _, relative in (dynasty and dynasty.Met) or {} do
		local info = Config.FamilyTree.Relatives[relative.Role]
		local above = info and info.Above or 0
		table.insert(if above >= 2 then grands elseif above == 1 then elders else cousins, { Relative = relative, Info = info })
	end

	-- You (+ spouse) with your children; each child (+ their spouse) with grandchildren.
	local selfDetail = personDetail(s.Name, if s.Dead then "This life (ended)" else "You", {
		Line = if ctx.GamePack.IsEnabled("Cultivation") then ("%s %d/%d"):format(s.Realm, s.SubLevel, s.SubLevels) else s.Race,
		Age = s.Age, Bio = ("Life #%d of your soul, born in %s."):format(s.Lives, currentRegionName(s) or "a quiet village"),
	})
	selfDetail.Region = currentRegionName(s)
	local selfMember = member(selfDetail, C.qi1, { Name = "SelfNode", Role = "◆ You  ·  Life " .. s.Lives, Line1 = selfDetail.Realm, Line2 = ("Age %d"):format(s.Age) })
	local selfMembers = { selfMember }
	if partner then
		table.insert(selfMembers, relMember(partner, if s.Flags and s.Flags.Married then "Spouse" else "Partner", BOND, { Name = "SpouseNode" }))
	end
	local childUnits = {}
	for _, rel in children do
		local members = { relMember(rel, "Child", BLOOD, { Name = "ChildNode", Child = rel,
			Bio = "Born to " .. s.Name .. (if partner then " and " .. partner.Name else "") .. "." }) }
		if rel.Spouse then
			table.insert(members, member(personDetail(rel.Spouse, "In-law", { Bio = ("Married to %s."):format(rel.Name) }), BOND,
				{ Name = "InLawNode", Role = "Spouse of " .. (string.match(rel.Name, "^(%S+)") or rel.Name), Line1 = "In-law" }))
		end
		local grandUnits = {}
		for _, kid in rel.Offspring or {} do
			local lines, short = geneticsLines(kid.Genetics)
			table.insert(grandUnits, unit({ member(personDetail(kid.Name, "Grandchild", { Age = kid.Age, Extra = lines, Bio = ("Child of %s."):format(rel.Name) }), BLOOD,
				{ Name = "GrandchildNode", Role = "Grandchild", Line1 = ("Age %d"):format(kid.Age), Line2 = short }) }, {}, 4))
		end
		table.insert(childUnits, unit(members, grandUnits, 3))
	end
	local selfUnit = unit(selfMembers, childUnits, 2)

	-- Parents with you first (past lives join you from the left), then your siblings.
	local row2 = { selfUnit }
	for _, rel in siblings do
		table.insert(row2, unit({ relMember(rel, "Sibling", BLOOD) }, {}, 2))
	end
	local roots
	if #parents > 0 then
		local members = {}
		for i = 1, math.min(2, #parents) do
			table.insert(members, relMember(parents[i], parents[i].Type, BLOOD))
		end
		local parentUnit = unit(members, row2, 1)
		-- Uncles and aunts are the parents' siblings; cousins hang from the first of them.
		local tops = { parentUnit }
		for i, entry in elders do
			local cousinUnits = {}
			if i == 1 then
				for _, cousin in cousins do
					table.insert(cousinUnits, unit({ relativeMember(cousin.Relative, cousin.Info) }, {}, 2))
				end
			end
			table.insert(tops, unit({ relativeMember(entry.Relative, entry.Info) }, cousinUnits, 1))
		end
		local grandMembers = {}
		for _, entry in grands do
			table.insert(grandMembers, relativeMember(entry.Relative, entry.Info))
		end
		for _, rel in grandRels do
			table.insert(grandMembers, relMember(rel, "Grandparent", BLOOD))
		end
		while #grandMembers > 2 do
			table.remove(grandMembers)
		end
		roots = if #grandMembers > 0 then { unit(grandMembers, tops, 0) } else tops
	else
		roots = row2
	end

	-- Layout: measure, place once, then shift so the past lives fit left of you.
	local total = 0
	for _, r in roots do
		total += measure(r)
	end
	local function placeAll(offset)
		local x = offset
		for _, r in roots do
			place(r, x)
			x += r.Width
		end
	end
	placeAll(0)
	local selfCol = selfUnit.Cols[1]
	local shift = math.max(0, #lives - selfCol)
	if shift > 0 then
		placeAll(shift)
		selfCol = selfUnit.Cols[1]
	end
	local topRow, lastRow = 2, 2
	local function rows(u)
		topRow, lastRow = math.min(topRow, u.Row), math.max(lastRow, u.Row)
		for _, child in u.Children do rows(child) end
	end
	for _, r in roots do rows(r) end
	rowBase = topRow
	designH = PAD * 2 + (lastRow - rowBase) * ROW_H + NODE_H

	-- Past lives on your row, oldest first, linked by bloodline or soul leap.
	local delay = 0
	local previous = nil
	for i, entry in lives do
		local col = selfCol - #lives + i - 1
		local generations = Memory.GenerationsAgo(entry, s.Lives)
		local detail = Memory.Describe(entry, generations, s.Upgrades, Config.Regions)
		local accent = if detail.Preserved == "Immortal" then C.gold elseif detail.Preserved == "Heirloom" then BLOOD
			elseif detail.Tier == "Forgotten" then C.muted elseif detail.Tier == "Fading" then SOUL:Lerp(C.muted, 0.55) else SOUL
		local node = makeNode(col, 2, detail, accent, {
			Role = ("Life %d  ·  %s"):format(entry.Life or 0, detail.Title or ""),
			Line1 = detail.Realm, Line2 = if detail.Tier == "Forgotten" then detail.Region else ("Age %s  ·  %s"):format(detail.Age, detail.Region),
			Delay = delay,
		})
		if previous then
			segment(previous.Node.Center.X + NODE_W / 2, previous.Node.Center.Y, node.Center.X - NODE_W / 2, node.Center.Y,
				if previous.Entry.NextPath == "Descendant" then BLOOD else SOUL, delay)
		end
		previous = { Node = node, Entry = entry }
		delay += 0.06
	end
	for _, r in roots do
		draw(r, delay)
	end
	ui.SelfNode = selfMember.Node
	if previous then
		segment(previous.Node.Center.X + NODE_W / 2, previous.Node.Center.Y, ui.SelfNode.Center.X - NODE_W / 2, ui.SelfNode.Center.Y,
			if previous.Entry.NextPath == "Descendant" then BLOOD else SOUL, delay)
	end

	local maxCol = 0
	for _, node in ui.Nodes do
		maxCol = math.max(maxCol, node.Col + 1)
	end
	-- The real height: deep trees (grandchildren) are taller than the 400 px band.
	local bottom = designH
	for _, node in ui.Nodes do
		bottom = math.max(bottom, node.Frame.Position.Y.Offset + NODE_H + PAD)
	end
	ui.Content.Size = UDim2.fromOffset(math.max(PAD * 2 + maxCol * COL_W, 600), bottom)
	local factor = fitScale()
	-- Open on the present with the most recent past lives leading into it.
	local window = windowSize()
	local selfY = ui.SelfNode.Center.Y * factor - window.Y * 0.4
	ui.Canvas.CanvasPosition = Vector2.new(math.max(0, (ui.SelfNode.Center.X + NODE_W) * factor - window.X * 0.65), math.max(0, selfY))
	showDetail(ui.SelfNode)
end

local function renderHeirlooms(s)
	local enabled = ctx.GamePack.IsEnabled("Dynasty")
	ui.HeirloomPanel.Visible = enabled
	if not enabled then
		return
	end
	local dynasty = s.Modules and s.Modules.Dynasty
	local consecrated = dynasty and dynasty.Consecrated
	local item = consecrated and Config.Items.ById[consecrated]
	local held = {}
	for _, heirloom in s.Heirlooms or {} do
		local stacks = math.floor((heirloom.Generations or 0) * Config.FamilyTree.Heirloom.SoulStackPerGeneration * 100 + 0.5)
		local where = if heirloom.Holder == "Player" then "yours" elseif heirloom.Lost then "held by your old family" else "waiting for you at " .. Config.FamilyTree.Heirloom.InheritAge
		table.insert(held, ("%s (%s, +%d%% soul, %s)"):format(heirloom.Name, heirloom.Creator, stacks, where))
	end
	ui.HeirloomText.Text = ("Consecrated: %s\n%s"):format(if item then item.Name else "nothing yet",
		if #held > 0 then table.concat(held, "\n") else "No heirlooms in the family yet.")
	local equipped = (s.Inventory and s.Inventory.Equipped) or {}
	for slot, button in ui.SlotButtons do
		local itemId = equipped[slot]
		local slotItem = itemId and Config.Items.ById[itemId]
		button.Text = if slotItem then "Consecrate " .. slotItem.Name else ("No %s equipped"):format(Config.Items.Slots and Config.Items.Slots[slot] and Config.Items.Slots[slot].Name or slot)
		S.setEnabled(button, slotItem ~= nil and not s.Dead and consecrated ~= itemId)
	end
end

function Page.Init(context, frame)
	ctx, root = context, frame
	S, Config = ctx.Style, ctx.Config
	C = S.C
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	Memory = require(Shared:WaitForChild("LineageMemory"))
	Genetics = require(Shared:WaitForChild("GeneticsText"))

	local left = S.new("Frame", { Name = "TreePanel", Size = scale(0.66, 1), Parent = root })
	-- Padding first: UITheme.frame places the gold trim relative to it (trim after
	-- padding sat inside the content and ran through the title and buttons).
	S.padding(left, 16, 14)
	if ctx.Theme then ctx.Theme.frame(left, 14) else S.decorate(left) end
	-- Row 1: title and legend. Row 2: zoom controls (left) and Older / Newer (right).
	-- The canvas starts below both rows, so no control ever covers the title or the box.
	S.label({ Name = "Header", Text = "Dynasty & Reincarnation", Font = S.Fonts.Title, TextColor3 = C.gold, Position = scale(0, 0.03), Size = scale(0.56, 0.06), Parent = left }, 22)
	local legend = ('<font color="#%s">━ blood</font>  <font color="#%s">━ soul</font>  <font color="#%s">━ marriage</font>'):format(BLOOD:ToHex(), SOUL:ToHex(), BOND:ToHex())
	S.label({ Name = "Legend", Text = legend, RichText = true, TextColor3 = C.muted, Position = scale(0.58, 0.03), Size = scale(0.42, 0.06),
		TextXAlignment = Enum.TextXAlignment.Right, Parent = left }, 12)
	-- Zoom controls: out, current zoom (tap = fit the whole tree), in.
	local ROW2_Y, ROW2_H = 0.105, 0.065
	local zoomOut = S.ghostButton({ Name = "ZoomOut", Text = "−", Position = scale(0, ROW2_Y), Size = scale(0.07, ROW2_H), Parent = left }, 16)
	local zoomFit = S.ghostButton({ Name = "ZoomFit", Text = "Fit", Position = scale(0.08, ROW2_Y), Size = scale(0.11, ROW2_H), Parent = left }, 12)
	local zoomIn = S.ghostButton({ Name = "ZoomIn", Text = "+", Position = scale(0.2, ROW2_Y), Size = scale(0.07, ROW2_H), Parent = left }, 16)
	ui.ZoomLabel = S.label({ Name = "ZoomLevel", Text = "", TextColor3 = C.muted, Position = scale(0.285, ROW2_Y), Size = scale(0.1, ROW2_H), Parent = left }, 12)
	zoomOut.Activated:Connect(function() zoomBy(1 / ZOOM_STEP) end)
	zoomIn.Activated:Connect(function() zoomBy(ZOOM_STEP) end)
	zoomFit.Activated:Connect(function() zoomTo(fitFactor()) end)
	local function pan(direction: number)
		local window = windowSize()
		local target = ui.Canvas.CanvasPosition + Vector2.new(direction * window.X * 0.6, 0)
		local maxX = math.max(0, ui.Canvas.CanvasSize.X.Offset - window.X)
		TweenService:Create(ui.Canvas, TweenInfo.new(0.35, Enum.EasingStyle.Quad),
			{ CanvasPosition = Vector2.new(math.clamp(target.X, 0, maxX), ui.Canvas.CanvasPosition.Y) }):Play()
	end
	local older = S.ghostButton({ Name = "OlderButton", Text = "◀ Older", Position = scale(0.71, ROW2_Y), Size = scale(0.14, ROW2_H), Parent = left }, 12)
	local newer = S.ghostButton({ Name = "NewerButton", Text = "Newer ▶", Position = scale(0.86, ROW2_Y), Size = scale(0.14, ROW2_H), Parent = left }, 12)
	older.Activated:Connect(function() pan(-1) end)
	newer.Activated:Connect(function() pan(1) end)
	ui.Canvas = S.new("ScrollingFrame", { Name = "Canvas", Position = scale(0, 0.175), Size = scale(1, 0.825), BackgroundColor3 = C.inset, BackgroundTransparency = 0.35,
		BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = C.stroke, ScrollingDirection = Enum.ScrollingDirection.XY,
		CanvasSize = UDim2.fromOffset(600, 0), Active = true, Parent = left })
	S.new("UICorner", { CornerRadius = UDim.new(0, S.radius(10)), Parent = ui.Canvas })
	ui.Content = S.new("Frame", { Name = "Content", Size = UDim2.fromOffset(600, designH), BackgroundTransparency = 1, Parent = ui.Canvas })
	-- Phones: the panel is short and buttons are 44 px touch targets, so the controls get
	-- one tall row of their own (title and legend hidden) and the canvas starts below it.
	local header, legendLabel = left:FindFirstChild("Header"), left:FindFirstChild("Legend")
	local LAYOUTS = {
		Desktop = {
			[header] = { 0, 0.03, 0.56, 0.06 }, [zoomOut] = { 0, ROW2_Y, 0.07, ROW2_H }, [zoomFit] = { 0.08, ROW2_Y, 0.11, ROW2_H },
			[zoomIn] = { 0.2, ROW2_Y, 0.07, ROW2_H }, [ui.ZoomLabel] = { 0.285, ROW2_Y, 0.1, ROW2_H },
			[older] = { 0.71, ROW2_Y, 0.14, ROW2_H }, [newer] = { 0.86, ROW2_Y, 0.14, ROW2_H }, [ui.Canvas] = { 0, 0.19, 1, 0.81 },
		},
		Phone = {
			[header] = { 0, 0, 0.3, 0.24 }, [zoomOut] = { 0, 0, 0.14, 0.24 }, [zoomFit] = { 0.155, 0, 0.17, 0.24 },
			[zoomIn] = { 0.34, 0, 0.14, 0.24 }, [ui.ZoomLabel] = { 0.31, 0.24, 0.31, 0.0 },
			[older] = { 0.585, 0, 0.2, 0.24 }, [newer] = { 0.8, 0, 0.2, 0.24 }, [ui.Canvas] = { 0, 0.27, 1, 0.73 },
		},
	}
	local Responsive = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Responsive"))
	Responsive.Watch(function(profile)
		local phone = profile.Kind == "Phone"
		for item, box in if phone then LAYOUTS.Phone else LAYOUTS.Desktop do
			item.Position, item.Size = scale(box[1], box[2]), scale(box[3], box[4])
		end
		legendLabel.Visible = not phone
		header.Visible = not phone -- the tab already says Lineage; the buttons need the width
		ui.ZoomLabel.Visible = not phone
		for _, button in { zoomOut, zoomFit, zoomIn, older, newer } do
			button:SetAttribute("TouchSafe", phone) -- the phone row is already 44 px tall
		end
	end)
	ui.Scale = S.new("UIScale", { Parent = ui.Content })
	ui.Canvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitScale)
	local dragging, last = false, nil
	ui.BeginDrag = function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging, last = true, input.Position
		end
	end
	ui.Canvas.InputBegan:Connect(ui.BeginDrag)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement and last then
			local delta = input.Position - last
			last = input.Position
			ui.Canvas.CanvasPosition -= Vector2.new(delta.X, delta.Y)
		end
	end)
	-- Mouse wheel over the tree zooms (dragging pans); the wheel no longer scrolls it.
	ui.Canvas.ScrollingEnabled = UserInputService.TouchEnabled -- touch keeps native panning
	ui.Canvas.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			zoomBy(if input.Position.Z > 0 then ZOOM_STEP else 1 / ZOOM_STEP)
		end
	end)
	-- Pinch to zoom on touch screens.
	local pinchStart = nil
	UserInputService.TouchPinch:Connect(function(_, pinchScale, _, inputState)
		if not root.Visible or not ui.Canvas.Visible then
			return
		end
		if inputState == Enum.UserInputState.Begin then
			pinchStart = ui.Scale.Scale
		elseif inputState == Enum.UserInputState.Change and pinchStart then
			zoomTo(pinchStart * pinchScale)
		else
			pinchStart = nil
		end
	end)

	local right = S.new("Frame", { Name = "DetailPanel", Position = scale(0.67, 0), Size = scale(0.33, 1), Parent = root })
	S.padding(right, 16, 14)
	if ctx.Theme then ctx.Theme.frame(right, 14) else S.decorate(right) end
	-- Details scroll: on phones the column is drawn taller so fields, heir buttons and
	-- heirloom slots keep their space instead of piling up.
	local body = S.new("ScrollingFrame", { Name = "DetailBody", Size = scale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = C.stroke, CanvasSize = scale(0, 1), Parent = right })
	Responsive.Watch(function(profile)
		body.CanvasSize = scale(0, if profile.Kind == "Phone" then 2.6 else 1)
	end)
	ui.DName = S.label({ Name = "DName", Text = "", Font = S.Fonts.Title, TextColor3 = C.text, Size = scale(1, 0.08), Parent = body }, 18)
	ui.DTitle = S.label({ Name = "DTitle", Text = "", Font = S.Fonts.Bold, TextColor3 = C.gold, Position = scale(0, 0.08), Size = scale(1, 0.05), Parent = body }, 12)
	ui.DFields = S.label({ Name = "DFields", Text = "", RichText = true, TextColor3 = C.text, Position = scale(0, 0.14), Size = scale(1, 0.24),
		TextYAlignment = Enum.TextYAlignment.Top, Parent = body }, 12)
	ui.DBio = S.label({ Name = "DBio", Text = "", TextColor3 = C.muted, Position = scale(0, 0.385), Size = scale(1, 0.06), TextYAlignment = Enum.TextYAlignment.Top, Parent = body }, 12)
	ui.HeirButton = S.button({ Name = "HeirButton", Text = "", Position = scale(0, 0.45), Size = scale(1, 0.06), Visible = false, Parent = body }, nil, nil, 12)
	ui.GrandButton = S.ghostButton({ Name = "GrandButton", Text = "", Position = scale(0, 0.515), Size = scale(1, 0.06), Visible = false, Parent = body }, 12)
	local function choose(mode: string)
		if selectedNode and selectedNode.Child and latest and latest.Dead then
			ctx.Remotes:WaitForChild("Reincarnate"):FireServer("ChooseHeir", selectedNode.Child.Id, mode)
		end
	end
	ui.HeirButton.Activated:Connect(function() choose("TakeOver") end)
	ui.GrandButton.Activated:Connect(function() choose("Grandchild") end)

	ui.HeirloomPanel = S.new("Frame", { Name = "HeirloomPanel", Position = scale(0, 0.56), Size = scale(1, 0.4), BackgroundTransparency = 1, Parent = body })
	S.label({ Name = "HeirloomHeader", Text = "⚔  Ancestral " .. (S.Terms.HeirloomName or "Heirloom"), Font = S.Fonts.Title, TextColor3 = C.gold, Size = scale(1, 0.14), Parent = ui.HeirloomPanel }, 16)
	ui.HeirloomText = S.label({ Name = "HeirloomText", Text = "", TextColor3 = C.muted, Position = scale(0, 0.15), Size = scale(1, 0.31),
		TextYAlignment = Enum.TextYAlignment.Top, Parent = ui.HeirloomPanel }, 11)
	ui.SlotButtons = {}
	local remote = ctx.Remotes:FindFirstChild("DynastyAction")
	for i, slot in { "Weapon", "Armor", "Accessory" } do
		local button = S.ghostButton({ Name = slot .. "Consecrate", Text = slot, Position = scale(0, 0.46 + (i - 1) * 0.175), Size = scale(1, 0.15), Parent = ui.HeirloomPanel }, 12)
		button.Activated:Connect(function()
			remote = remote or ctx.Remotes:FindFirstChild("DynastyAction")
			if remote then remote:FireServer("Consecrate", slot) end
		end)
		ui.SlotButtons[slot] = button
	end
	ui.Nodes = {}
end

function Page.Render(s)
	latest = s
	local dynasty = s.Modules and s.Modules.Dynasty
	local family = {}
	for _, rel in s.Relationships or {} do
		if rel.Category == "Family" or rel.Category == "Partner" or rel.Category == "Child" then
			table.insert(family, rel.Id .. ":" .. tostring(rel.Spouse) .. ":" .. #(rel.Offspring or {}) .. ":" .. tostring(rel.Genetics and rel.Genetics.Upbringing))
		end
	end
	local key = table.concat({ s.Lives, #s.Lineage, table.concat(family, ","), #((dynasty and dynasty.Met) or {}),
		tostring(s.Flags and s.Flags.Married), tostring(s.Dead), tostring((s.Upgrades or {}).AncestralChronicler) }, "|")
	if key ~= treeKey then
		treeKey = key
		buildTree(s)
	elseif ui.SelfNode then
		ui.SelfNode.Frame.Line2.Text = ("Age %d"):format(s.Age)
		ui.SelfNode.Detail.Age = s.Age
	end
	if selectedNode then
		showDetail(selectedNode)
	end
	renderHeirlooms(s)
end

return Page
