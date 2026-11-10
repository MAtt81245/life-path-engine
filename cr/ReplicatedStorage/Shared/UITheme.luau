--[[
	UITheme: the bespoke "tome and jade tablet" look of LifePathUI (obsidian panels,
	burnished gold trim, smoked jade highlights, parchment text).

	Apply(gui, { Preview = true }) restyles the static layout in place and is
	idempotent (find-or-create, then set). It runs once in Studio edit mode so the
	place itself looks right, and again from UIController at startup. Preview adds
	placeholder cards so empty panels never show in edit mode; ClearPreviews removes
	them before the pages build real content.

	UITheme.frame(inst) gives any panel the double border (ink outer frame, gold inner
	trim, corner gems); pages may use it through ctx.Theme. Add the panel's UIPadding
	BEFORE calling it: the trim is placed relative to the padding.

	Theme Style "Dossier" (UIThemeConfig.Style) switches to the modern tactical look:
	obsidian glass panels with a crisp 1 px neon border and 4 px corners (no trim or
	gems), a square ID portrait with corner brackets and a grade stamp, crimson tab
	underlines, a crimson -> violet Advance button, and UITheme.Layout: an ID banner on
	top, tabs + pages in the middle, a docked command bar (action seals, grade / energy
	strip, +1 YEAR) at the bottom. Instance names never change, only geometry and style.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local S = require(script.Parent:WaitForChild("UIStyle"))
local C = S.C
local T = S.Terms -- pack vocabulary (Configs/UIThemeConfig.Terms)
local PIP = S.Theme.Pip or { Rotation = 45, Corner = 0.08 }
local DOSSIER = S.Dossier

local UITheme = {}
UITheme.Dossier = DOSSIER

UITheme.TabIcons = S.Theme.TabIcons or {
	Training = "⚔", Study = "📜", Masters = "⛩", Social = "👥", Progression = "✨",
	Inventory = "🎒", Journal = "📖", Lineage = "☸", Family = "🌳",
}
-- Default labels shown in edit mode (UIController applies pack relabels at runtime).
UITheme.TabLabels = {
	Training = "Train", Study = "Study", Masters = T.MentorsTab, Social = "Bonds", Progression = "Talents",
	Inventory = "Bag", Journal = "Chronicle", Lineage = T.RebirthTab,
}

local function set(inst, props)
	for key, value in props or {} do
		inst[key] = value
	end
	return inst
end

-- Named child: created once, then updated in place.
local function ensure(parent, className: string, name: string, props)
	local inst = parent:FindFirstChild(name)
	if not inst or inst.ClassName ~= className then
		if inst then
			inst:Destroy()
		end
		inst = Instance.new(className)
		inst.Name = name
		inst.Parent = parent
	end
	return set(inst, props)
end

-- First child of a class (decorations created without names).
local function ofClass(parent, className: string, props)
	local inst = parent:FindFirstChildOfClass(className)
	if not inst then
		inst = Instance.new(className)
		inst.Parent = parent
	end
	return set(inst, props)
end

local function strip(inst)
	for _, className in { "UIStroke", "UICorner", "UIGradient" } do
		local found = inst:FindFirstChildOfClass(className)
		if found then
			found:Destroy()
		end
	end
end

local function hasLayout(inst): boolean
	return inst:FindFirstChildWhichIsA("UIGridStyleLayout") ~= nil
end

local function circle(inst)
	ofClass(inst, "UICorner", { CornerRadius = UDim.new(1, 0) })
end

local function sharp(inst, px: number?)
	ofClass(inst, "UICorner", { CornerRadius = UDim.new(0, px or 4) })
end

-- Four L-shaped corner brackets (tactical ID frame, command deck).
local function brackets(inst, color: Color3, length: number?)
	length = length or 10
	for name, at in { TL = Vector2.new(0, 0), TR = Vector2.new(1, 0), BL = Vector2.new(0, 1), BR = Vector2.new(1, 1) } do
		for _, horizontal in { true, false } do
			ensure(inst, "Frame", "Bracket" .. name .. (if horizontal then "H" else "V"), {
				AnchorPoint = at, Position = UDim2.new(at.X, if at.X == 0 then -3 else 3, at.Y, if at.Y == 0 then -3 else 3),
				Size = if horizontal then UDim2.fromOffset(length, 2) else UDim2.fromOffset(2, length),
				BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = inst.ZIndex + 3,
			})
		end
	end
end

-- Dossier panel: obsidian glass, a crisp 1 px neon border, 4 px corners, no trim or gems.
function UITheme.glass(inst, fill1: Color3?, fill2: Color3?, strokeColor: Color3?)
	inst.BorderSizePixel = 0
	inst.BackgroundTransparency = 0.04
	sharp(inst)
	ofClass(inst, "UIStroke", { Color = strokeColor or C.stroke, Thickness = 1, Transparency = 0.45, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	S.paint(inst, fill1 or C.panel1, fill2 or C.panel2, 90)
	local trim = inst:FindFirstChild("Trim")
	if trim then
		trim:Destroy()
	end
	return inst
end

-- An invisible container (dossier roots: the sheet and main frames hold separate panels).
local function bare(inst)
	inst.BackgroundTransparency = 1
	inst.ClipsDescendants = false
	-- Children are placed in screen rectangles (UITheme.Layout): padding would squeeze them.
	local padding = inst:FindFirstChildOfClass("UIPadding")
	if padding then
		padding:Destroy()
	end
	local stroke = inst:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = 1
	end
	local trim = inst:FindFirstChild("Trim")
	if trim then
		trim:Destroy()
	end
end

-- Double-bordered panel: ink outer frame, gold inner trim and four corner gems.
function UITheme.frame(inst, radius: number?, fill1: Color3?, fill2: Color3?)
	if DOSSIER then
		return UITheme.glass(inst, fill1, fill2)
	end
	radius = S.radius(radius or 12)
	inst.BorderSizePixel = 0
	inst.BackgroundTransparency = 0
	ofClass(inst, "UICorner", { CornerRadius = UDim.new(0, radius) })
	ofClass(inst, "UIStroke", { Color = C.ink, Thickness = 2, Transparency = 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	S.paint(inst, fill1 or C.panel1, fill2 or C.panel2, 90)
	if hasLayout(inst) then
		return inst -- trim would be laid out like content
	end
	local padding = inst:FindFirstChildOfClass("UIPadding")
	local l = padding and padding.PaddingLeft.Offset or 0
	local r = padding and padding.PaddingRight.Offset or 0
	local t = padding and padding.PaddingTop.Offset or 0
	local b = padding and padding.PaddingBottom.Offset or 0
	local trim = ensure(inst, "Frame", "Trim", {
		BackgroundTransparency = 1, Active = false, ZIndex = inst.ZIndex,
		Position = UDim2.new(0, 4 - l, 0, 4 - t), Size = UDim2.new(1, l + r - 8, 1, t + b - 8),
	})
	ofClass(trim, "UICorner", { CornerRadius = UDim.new(0, math.max(2, radius - 3)) })
	ofClass(trim, "UIStroke", { Color = C.stroke, Thickness = 1, Transparency = 0.55, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	for name, at in { GemTL = Vector2.new(0, 0), GemTR = Vector2.new(1, 0), GemBL = Vector2.new(0, 1), GemBR = Vector2.new(1, 1) } do
		ensure(trim, "Frame", name, {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(at.X, at.Y), Size = UDim2.fromOffset(7, 7),
			Rotation = 45, BackgroundColor3 = C.gold, BorderSizePixel = 0, ZIndex = inst.ZIndex + 2,
		})
	end
	return inst
end

local function gold(inst, radius: number?)
	inst.BorderSizePixel = 0
	inst.BackgroundTransparency = 0
	if DOSSIER then
		-- Crimson -> violet command button.
		sharp(inst)
		ofClass(inst, "UIStroke", { Color = C.text, Thickness = 1, Transparency = 0.7, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		S.gradient(inst, C.crimson1, C.gold2, 0)
		return
	end
	ofClass(inst, "UICorner", { CornerRadius = UDim.new(0, S.radius(radius or 10)) })
	ofClass(inst, "UIStroke", { Color = C.ink, Thickness = 2, Transparency = 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	S.paint(inst, C.gold, C.gold2, 90)
end

local function bar(barBack, color: Color3)
	barBack.BackgroundColor3 = C.inset
	barBack.BorderSizePixel = 0
	barBack.ClipsDescendants = true
	local corner = if DOSSIER then 1 else 5 -- dossier: thin flat bars
	ofClass(barBack, "UICorner", { CornerRadius = UDim.new(0, corner) })
	ofClass(barBack, "UIStroke", { Color = C.ink, Thickness = if DOSSIER then 1 else 2, Transparency = if DOSSIER then 0.4 else 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	local fill = barBack:FindFirstChild("Fill")
	if fill then
		ofClass(fill, "UICorner", { CornerRadius = UDim.new(0, corner) })
		S.paint(fill, color, color:Lerp(C.ink, 0.45), 90)
	end
end

----------------------------------------------------------------------
-- Character sheet
----------------------------------------------------------------------

local METERS = {
	HealthMeter = { Key = "♥  HEALTH", Color = C.rose1 },
	HappinessMeter = { Key = "☀  HAPPINESS", Color = C.gold },
	StressMeter = { Key = "⚡  STRESS", Color = C.violet },
}

local LEDGER = {
	{ Row = "WealthRow", Key = "💰  WEALTH" },
	{ Row = "IntelligenceRow", Key = "📖  KNOWLEDGE" },
	{ Row = "KarmaRow", Key = T.MetaCurrencyIcon .. "  " .. string.upper(T.MetaCurrency) },
	{ Row = "AlignmentRow", Key = "⚖  REPUTATION" },
	{ Row = "OccupationRow", Key = "⚒  OCCUPATION" },
	{ Row = "LivesRow", Key = "🌀  " .. T.Incarnation },
}

-- One action pip: a square holder (layouts ignore Rotation on their direct children)
-- carrying a soft glow, the gem and a highlight facet. Shape from the theme's Pip:
-- rotated diamond (cultivation), round badge (modern), slanted crest (academy).
local function gemPip(row, i: number)
	local holder = ensure(row, "Frame", "Pip" .. i, { LayoutOrder = i, BackgroundTransparency = 1, Size = UDim2.fromScale(0, 1) })
	ofClass(holder, "UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height, AspectType = Enum.AspectType.ScaleWithParentSize })
	local glow = ensure(holder, "Frame", "Glow", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.86, 0.86),
		Rotation = PIP.Rotation, BorderSizePixel = 0, BackgroundColor3 = C.qi1, BackgroundTransparency = 0.78, ZIndex = 1,
	})
	ofClass(glow, "UICorner", { CornerRadius = UDim.new(math.max(0.2, PIP.Corner), 0) })
	local gem = ensure(holder, "Frame", "Gem", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.64, 0.64),
		Rotation = PIP.Rotation, BorderSizePixel = 0, BackgroundColor3 = C.qi1, ZIndex = 2,
	})
	ofClass(gem, "UICorner", { CornerRadius = UDim.new(PIP.Corner, 0) })
	ofClass(gem, "UIGradient", {
		Rotation = 0,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 200, 200)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(95, 95, 95)),
		}),
	})
	ofClass(gem, "UIStroke", { Color = C.qi1, Thickness = 1.6, Transparency = 0.1 })
	local facet = ensure(gem, "Frame", "Facet", {
		Position = UDim2.fromScale(0.14, 0.14), Size = UDim2.fromScale(0.34, 0.34), BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.55, ZIndex = 3,
	})
	ofClass(facet, "UICorner", { CornerRadius = UDim.new(PIP.Corner, 0) })
	return holder
end

-- Action diamonds above the Advance Year medallion (UIController.renderSheet paints
-- them: jade = free slot, gold = game-pass slot, dark socket = spent).
local function actionGems(sheet)
	local gems = ensure(sheet, "Frame", "ActionGems", {
		BackgroundTransparency = 1, Position = UDim2.fromScale(0, 0.695), Size = UDim2.fromScale(1, 0.125),
	})
	local header = ensure(gems, "TextLabel", "Header", {
		BackgroundTransparency = 1, Position = UDim2.fromScale(0.02, 0), Size = UDim2.fromScale(0.6, 0.3),
		Text = T.ActionPip .. "  " .. T.ActionsHeader, Font = S.Fonts.Bold, TextScaled = true, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Left,
	})
	ofClass(header, "UITextSizeConstraint", { MaxTextSize = 12, MinTextSize = 7 })
	local count = ensure(gems, "TextLabel", "Count", {
		BackgroundTransparency = 1, Position = UDim2.fromScale(0.6, 0), Size = UDim2.fromScale(0.38, 0.3),
		Text = "2 / 2", Font = S.Fonts.Bold, TextScaled = true, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Right,
	})
	ofClass(count, "UITextSizeConstraint", { MaxTextSize = 12, MinTextSize = 7 })
	local row = ensure(gems, "Frame", "Row", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.02, 0.34), Size = UDim2.fromScale(0.7, 0.66) })
	ofClass(row, "UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center })
	for i = 1, 6 do
		gemPip(row, i).Visible = i <= 2
	end
	local social = ensure(gems, "TextLabel", "Social", {
		BackgroundTransparency = 1, Position = UDim2.fromScale(0.72, 0.4), Size = UDim2.fromScale(0.26, 0.5),
		Text = "👥 3/3", Font = S.Fonts.Bold, TextScaled = true, TextColor3 = C.qi1, TextXAlignment = Enum.TextXAlignment.Right,
	})
	ofClass(social, "UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 7 })
end

local function styleSheet(sheet)
	if DOSSIER then
		-- The sheet is a bare container: an ID banner and a command deck sit behind its parts.
		bare(sheet)
		local banner = UITheme.glass(ensure(sheet, "Frame", "Banner", { ZIndex = 0, Active = false }))
		ensure(banner, "Frame", "Accent", { Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = C.crimson1, BorderSizePixel = 0, ZIndex = 1 })
		local deck = UITheme.glass(ensure(sheet, "Frame", "CommandDeck", { ZIndex = 0, Active = false }), C.panel2, C.ink)
		brackets(deck, C.crimson1, 14)
	else
		UITheme.frame(sheet, 16)
	end

	local avatar = sheet:FindFirstChild("Avatar")
	if avatar and DOSSIER then
		-- Tactical ID frame: square portrait, corner brackets and a bold grade stamp.
		avatar.BackgroundColor3 = C.ink
		avatar.BackgroundTransparency = 0
		sharp(avatar, 2)
		ofClass(avatar, "UIStroke", { Color = C.stroke, Thickness = 1, Transparency = 0.2 })
		ofClass(avatar, "UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height })
		brackets(avatar, C.crimson1, 12)
		local seal = ensure(avatar, "Frame", "Seal", {
			AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1.1, 1.06), Size = UDim2.fromScale(0.66, 0.3),
			BackgroundColor3 = C.crimson1, BorderSizePixel = 0, ZIndex = avatar.ZIndex + 4,
		})
		sharp(seal, 2)
		ofClass(seal, "UIStroke", { Color = C.text, Thickness = 1, Transparency = 0.35 })
		local glyph = ensure(seal, "TextLabel", "Glyph", {
			BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "[G4]", Font = S.Fonts.Heavy,
			TextScaled = true, TextColor3 = C.text, ZIndex = avatar.ZIndex + 5,
		})
		ofClass(glyph, "UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 8 })
		ofClass(glyph, "UIPadding", { PaddingLeft = UDim.new(0.06, 0), PaddingRight = UDim.new(0.06, 0), PaddingTop = UDim.new(0.1, 0), PaddingBottom = UDim.new(0.1, 0) })
	elseif avatar then
		avatar.BackgroundColor3 = C.ink
		avatar.BackgroundTransparency = 0
		circle(avatar)
		ofClass(avatar, "UIStroke", { Color = C.gold, Thickness = 3, Transparency = 0 })
		-- Sits on the portrait's rim without reaching the meters below it.
		local seal = ensure(avatar, "Frame", "Seal", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.88), Size = UDim2.fromScale(0.32, 0.32),
			BackgroundColor3 = C.crimson1, BorderSizePixel = 0, ZIndex = avatar.ZIndex + 2,
		})
		circle(seal)
		ofClass(seal, "UIStroke", { Color = C.gold, Thickness = 2, Transparency = 0 })
		local glyph = ensure(seal, "TextLabel", "Glyph", {
			BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "M", Font = S.Fonts.Title,
			TextScaled = true, TextColor3 = C.text, ZIndex = avatar.ZIndex + 3,
		})
		ofClass(glyph, "UITextSizeConstraint", { MaxTextSize = 22, MinTextSize = 8 })
	end

	local function retext(name, props)
		local label = sheet:FindFirstChild(name)
		if label then
			set(label, props)
		end
	end
	retext("NameLabel", { Font = S.Fonts.Title, TextColor3 = if DOSSIER then C.text else C.gold })
	retext("RaceLabel", { TextColor3 = C.muted })
	retext("TitleLabel", { TextColor3 = C.qi1 })
	retext("AgeLabel", { TextColor3 = C.text, Font = if DOSSIER then S.Fonts.Mono else nil })
	for _, name in { "NameLabel", "RaceLabel", "TitleLabel", "AgeLabel" } do
		local label = sheet:FindFirstChild(name)
		if label and DOSSIER then
			label.TextXAlignment = Enum.TextXAlignment.Left
		end
	end

	local meters = sheet:FindFirstChild("Meters")
	if meters then
		local energy = meters:FindFirstChild("EnergyMeter")
		if energy then
			energy.Name = "ActionsMeter"
		end
		for name, spec in METERS do
			local meter = meters:FindFirstChild(name)
			if meter then
				meter.Key.Text = spec.Key
				meter.Key.Font = S.Fonts.Bold
				meter.Key.TextColor3 = C.muted
				meter.Value.TextColor3 = C.text
				if DOSSIER then
					meter.Value.Font = S.Fonts.Mono
				end
				-- Label row, a clear gap, then the bar: the label never runs into the bar.
				meter.Key.Size = UDim2.fromScale(0.62, if DOSSIER then 0.58 else 0.44)
				meter.Value.Position, meter.Value.Size = UDim2.fromScale(0.62, 0), UDim2.fromScale(0.38, if DOSSIER then 0.58 else 0.44)
				meter.Key.TextYAlignment, meter.Value.TextYAlignment = Enum.TextYAlignment.Top, Enum.TextYAlignment.Top
				meter.Bar.Position = UDim2.fromScale(0, if DOSSIER then 0.7 else 0.56)
				meter.Bar.Size = UDim2.fromScale(1, if DOSSIER then 0.2 else 0.4)
				bar(meter.Bar, spec.Color)
			end
		end
		local actions = meters:FindFirstChild("ActionsMeter")
		if actions then
			actions.Key.Text = "◆  ACTIONS THIS YEAR"
			actions.Key.Font = S.Fonts.Bold
			actions.Key.TextColor3 = C.muted
			actions.Value.TextColor3 = C.text
			actions.Bar.Visible = false
			actions.Value.Text = "4 / 4 left"
			actions.Key.Size = UDim2.fromScale(0.62, 0.4)
			actions.Value.Size = UDim2.fromScale(0.38, 0.4)
			actions.Value.Position = UDim2.fromScale(0.62, 0)
			local pips = ensure(actions, "Frame", "Pips", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.03, 0.42), Size = UDim2.fromScale(0.67, 0.58) })
			ofClass(pips, "UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center })
			-- Action orbs: crisp diamonds (filled = available, outlined = spent).
			for i = 1, 6 do
				local pip = ensure(pips, "Frame", "Pip" .. i, {
					LayoutOrder = i, Size = UDim2.fromScale(0, 0.82), Rotation = 45, BorderSizePixel = 0,
					BackgroundColor3 = C.gold, BackgroundTransparency = 0, Visible = i <= 4,
				})
				ofClass(pip, "UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height, AspectType = Enum.AspectType.ScaleWithParentSize })
				ofClass(pip, "UIStroke", { Color = C.gold, Thickness = 1.5, Transparency = 0 })
				ofClass(pip, "UICorner", { CornerRadius = UDim.new(0, 2) })
			end
			local social = ensure(actions, "TextLabel", "Social", {
				BackgroundTransparency = 1, Position = UDim2.fromScale(0.72, 0.46), Size = UDim2.fromScale(0.28, 0.54), Text = "👥 4/4",
				Font = S.Fonts.Bold, TextScaled = true, TextColor3 = C.qi1, TextXAlignment = Enum.TextXAlignment.Right,
			})
			ofClass(social, "UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 7 })
			-- Superseded by the ActionGems row above the Advance Year button.
			actions.Visible = false
		end
		-- Three meters fill the band the actions meter used to share, starting below
		-- the avatar seal.
		meters.Position = UDim2.fromScale(0, 0.215)
		meters.Size = UDim2.fromScale(1, 0.19)
		for name in METERS do
			local meter = meters:FindFirstChild(name)
			if meter then
				meter.Size = UDim2.fromScale(1, 0.3)
			end
		end
	end
	actionGems(sheet)

	-- Secondary stats: a two-column ledger with hairline rules, no boxes.
	local info = sheet:FindFirstChild("Info")
	if info then
		local list = info:FindFirstChildOfClass("UIListLayout")
		if list then
			list:Destroy()
		end
		info.Position = UDim2.fromScale(0, 0.415)
		info.Size = UDim2.fromScale(1, 0.27)
		-- Dossier: three columns x two rows across the ID banner.
		ofClass(info, "UIGridLayout", { CellSize = if DOSSIER then UDim2.fromScale(1 / 3, 0.46) else UDim2.fromScale(0.5, 0.3),
			CellPadding = UDim2.fromScale(0, if DOSSIER then 0.06 else 0.03), SortOrder = Enum.SortOrder.LayoutOrder })
		local template = info:FindFirstChild("WealthRow")
		for order, spec in LEDGER do
			local row = info:FindFirstChild(spec.Row)
			if not row and template then
				row = template:Clone()
				row.Name = spec.Row
				row.Parent = info
			end
			if row then
				strip(row)
				row.LayoutOrder = order
				row.BackgroundTransparency = 1
				ofClass(row, "UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) })
				set(row.Key, { Text = spec.Key, Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 0.42), Font = S.Fonts.Bold, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Left })
				set(row.Value, { Position = UDim2.fromScale(0, 0.45), Size = UDim2.fromScale(1, 0.52), Font = if DOSSIER then S.Fonts.Mono else S.Fonts.Bold, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left })
				ensure(row, "Frame", "Rule", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 2), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.stroke, BackgroundTransparency = 0.72, BorderSizePixel = 0 })
			end
		end
	end

	-- Advance Year: a gold plaque with a crimson +1 medallion (pulses when out of actions).
	local advance = sheet:FindFirstChild("AdvanceButton")
	if advance then
		gold(advance, 14)
		local medallion = ensure(advance, "Frame", "Medallion", {
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.035, 0.5), Size = UDim2.fromScale(0.2, 0.84),
			BackgroundColor3 = C.crimson1, BorderSizePixel = 0,
		})
		ofClass(medallion, "UIAspectRatioConstraint", { AspectRatio = 1 })
		if DOSSIER then
			sharp(medallion, 2)
			medallion.BackgroundColor3, medallion.BackgroundTransparency = C.ink, 0.45
			ofClass(medallion, "UIStroke", { Color = C.text, Thickness = 1, Transparency = 0.5 })
		else
			circle(medallion)
			ofClass(medallion, "UIStroke", { Color = C.ink, Thickness = 2, Transparency = 0 })
		end
		local glyph = ensure(medallion, "TextLabel", "Glyph", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "+1", Font = S.Fonts.Heavy, TextScaled = true, TextColor3 = if DOSSIER then C.text else C.gold })
		ofClass(glyph, "UITextSizeConstraint", { MaxTextSize = 24, MinTextSize = 8 })
		ofClass(glyph, "UIPadding", { PaddingLeft = UDim.new(0.18, 0), PaddingRight = UDim.new(0.18, 0), PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.2, 0) })
		set(advance.Title, { Position = UDim2.fromScale(0.28, 0.12), Size = UDim2.fromScale(0.68, 0.5), TextXAlignment = Enum.TextXAlignment.Left, Font = S.Fonts.Heavy })
		set(advance.Sub, { Position = UDim2.fromScale(0.28, 0.62), Size = UDim2.fromScale(0.68, 0.28), TextXAlignment = Enum.TextXAlignment.Left })
		advance.Title.Text = "+1 YEAR"
		advance.Sub.Text = "Advance age  ·  next 1"
		ensure(advance, "UIScale", "Pulse", nil)
	end
	local auto = sheet:FindFirstChild("AutoButton")
	if auto then
		auto.BorderSizePixel = 0
		ofClass(auto, "UICorner", { CornerRadius = UDim.new(0, if DOSSIER then 4 else 8) })
		ofClass(auto, "UIStroke", { Color = C.stroke, Thickness = 1, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		S.paint(auto, C.card1, C.card2, 90)
		auto.TextColor3 = C.muted
	end
end

----------------------------------------------------------------------
-- Realm banner, tabs, pages, modal
----------------------------------------------------------------------

local function styleStrip(strip)
	strip.Size = UDim2.fromScale(0.955, strip.Size.Y.Scale) -- right margin (viewport gizmos)
	local realm = strip:FindFirstChild("RealmBox")
	if realm then
		UITheme.frame(realm, 12)
		local emblem = ensure(realm, "Frame", "Emblem", {
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromScale(0.26, 0.86),
			BackgroundColor3 = C.ink, BorderSizePixel = 0,
		})
		ofClass(emblem, "UIAspectRatioConstraint", { AspectRatio = 1 })
		if DOSSIER then
			sharp(emblem, 2)
			ofClass(emblem, "UIStroke", { Color = C.gold, Thickness = 1, Transparency = 0 })
		else
			circle(emblem)
			ofClass(emblem, "UIStroke", { Color = C.gold, Thickness = 2, Transparency = 0 })
		end
		local glyph = ensure(emblem, "TextLabel", "Glyph", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = T.MetaCurrencyIcon, Font = S.Fonts.Title, TextScaled = true, TextColor3 = C.gold })
		ofClass(glyph, "UITextSizeConstraint", { MaxTextSize = 26, MinTextSize = 8 })
		ofClass(glyph, "UIPadding", { PaddingLeft = UDim.new(0.18, 0), PaddingRight = UDim.new(0.18, 0), PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0) })
		for _, name in { "Label", "Value", "Sub" } do
			local label = realm:FindFirstChild(name)
			if label then
				label.Position = UDim2.fromScale(0.3, label.Position.Y.Scale)
				label.Size = UDim2.fromScale(0.7, label.Size.Y.Scale)
			end
		end
		set(realm.Label, { TextColor3 = C.muted, Font = S.Fonts.Bold, Text = T.TierHeader })
		set(realm.Value, { Font = S.Fonts.Title })
		if DOSSIER then
			set(realm.Sub, { Font = S.Fonts.Mono })
		end
	end
	local qi = strip:FindFirstChild("QiBox")
	if qi then
		UITheme.frame(qi, 12)
		local back = qi:FindFirstChild("BarBack")
		if back then
			back.ZIndex = 3
			bar(back, C.qi1)
			local fill = back:FindFirstChild("Fill")
			if fill then
				S.paint(fill, C.qi1, C.jade2, 0)
			end
			ensure(qi, "Frame", "Glow", {
				Position = UDim2.new(back.Position.X.Scale, -4, back.Position.Y.Scale, -4), Size = UDim2.new(back.Size.X.Scale, 8, back.Size.Y.Scale, 8),
				BackgroundColor3 = C.qi1, BackgroundTransparency = 0.84, BorderSizePixel = 0, ZIndex = 2,
			})
			ofClass(qi.Glow, "UICorner", { CornerRadius = UDim.new(0, 9) })
		end
		set(qi.Label, { TextColor3 = C.muted, Font = S.Fonts.Bold, Text = T.EnergyHeader })
		set(qi.Rate, { TextColor3 = C.qi1, Font = if DOSSIER then S.Fonts.Mono else qi.Rate.Font })
		local barText = back and back:FindFirstChild("BarText")
		if barText and DOSSIER then
			barText.Font = S.Fonts.Mono
		end
		if DOSSIER and qi:FindFirstChild("Glow") then
			qi.Glow.Visible = false
		end
	end
	local button = strip:FindFirstChild("BreakthroughButton")
	if button then
		button.BorderSizePixel = 0
		ofClass(button, "UICorner", { CornerRadius = UDim.new(0, if DOSSIER then 4 else 12) })
		ofClass(button, "UIStroke", { Color = if DOSSIER then C.text else C.gold, Thickness = if DOSSIER then 1 else 2,
			Transparency = if DOSSIER then 0.6 else 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		S.paint(button, C.crimson1, C.crimson2, 90)
		set(button.Title, { Font = S.Fonts.Heavy, TextColor3 = C.text, Text = T.AdvanceTierButton })
		if DOSSIER then
			-- Narrow command-bar slot on phones: the label shrinks instead of clipping.
			button.Title.TextScaled = true
			ofClass(button.Title, "UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 8 })
		end
		set(button.Chance, { Font = S.Fonts.Bold, TextColor3 = C.gold })
	end
end

local function styleTabs(tabBar)
	tabBar.BackgroundTransparency = if DOSSIER then 0.04 else 0
	tabBar.BackgroundColor3 = C.panel2
	tabBar.BorderSizePixel = 0
	ofClass(tabBar, "UICorner", { CornerRadius = UDim.new(0, if DOSSIER then 4 else 8) })
	ofClass(tabBar, "UIStroke", { Color = if DOSSIER then C.stroke else C.ink, Thickness = if DOSSIER then 1 else 2,
		Transparency = if DOSSIER then 0.55 else 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	local layout = tabBar:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.Padding = UDim.new(0, 0)
	end
	-- Gold base rule under the bar (a sibling, so it never joins the tab row).
	ensure(tabBar.Parent, "Frame", "TabBaseRule", {
		Position = UDim2.new(tabBar.Position.X.Scale, 0, tabBar.Position.Y.Scale + tabBar.Size.Y.Scale, -2),
		Size = UDim2.new(tabBar.Size.X.Scale, 0, 0, 2),
		BackgroundColor3 = if DOSSIER then C.crimson1 else C.stroke, BackgroundTransparency = if DOSSIER then 0.2 else 0.45,
		BorderSizePixel = 0, ZIndex = tabBar.ZIndex + 1,
	})
	for _, button in tabBar:GetChildren() do
		if button:IsA("TextButton") then
			UITheme.tab(button)
			local key = string.gsub(button.Name, "Tab$", "")
			if UITheme.TabLabels[key] then
				button.Text = ("%s  %s"):format(UITheme.TabIcons[key], UITheme.TabLabels[key])
			end
			UITheme.setTabActive(button, key == "Training")
		end
	end
end

-- A connected tab: no pill, gold underline + top glow when active (UIController).
function UITheme.tab(button)
	strip(button)
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = S.Fonts.Bold
	button.TextColor3 = C.muted
	-- Dossier: a sharp full-width crimson highlight bar instead of a gold underline.
	ensure(button, "Frame", "Underline", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(if DOSSIER then 1 else 0.82, 0, 0, 3),
		BackgroundColor3 = if DOSSIER then C.crimson1 else C.gold, BorderSizePixel = 0, Visible = false,
	})
	local glow = ensure(button, "Frame", "Glow", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = if DOSSIER then C.crimson1 else C.gold, BackgroundTransparency = 0, BorderSizePixel = 0, Visible = false, ZIndex = button.ZIndex,
	})
	ofClass(glow, "UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.82), NumberSequenceKeypoint.new(0.7, 1), NumberSequenceKeypoint.new(1, 1) }),
	})
	return button
end

function UITheme.setTabActive(button, active: boolean)
	button.TextColor3 = if active then (if DOSSIER then C.text else C.gold) else C.muted
	local underline, glow = button:FindFirstChild("Underline"), button:FindFirstChild("Glow")
	if underline then underline.Visible = active end
	if glow then glow.Visible = active end
end

-- Dossier panel header: bold uppercase white title over a short crimson rule.
local function dossierHeader(header)
	header.Font = S.Fonts.Heavy
	header.TextColor3 = C.text
	header.Text = string.upper(header.Text)
	ensure(header, "Frame", "Rule", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(0.22, 0, 0, 2),
		BackgroundColor3 = C.crimson1, BorderSizePixel = 0,
	})
end

local function stylePages(pages)
	local training = pages:FindFirstChild("TrainingPage")
	local energy = training and training:FindFirstChild("ActionsPanel") and training.ActionsPanel:FindFirstChild("EnergyLabel")
	if energy then
		energy.Text = "4 / 4 actions left"
		energy.TextColor3 = C.qi1
		if DOSSIER then
			energy.Font = S.Fonts.Mono
		end
	end
	if training and DOSSIER then
		-- Student dossier on the left, the mission deck (2 columns of briefing cards) on the right.
		local attributes, actions = training:FindFirstChild("AttributesPanel"), training:FindFirstChild("ActionsPanel")
		if attributes and actions then
			attributes.Position, attributes.Size = UDim2.fromScale(0, 0), UDim2.fromScale(0.36, 1)
			actions.Position, actions.Size = UDim2.fromScale(0.375, 0), UDim2.fromScale(0.625, 1)
			local grid = actions:FindFirstChild("Grid") and actions.Grid:FindFirstChildOfClass("UIGridLayout")
			if grid then
				grid.CellSize = UDim2.fromScale(0.49, 0.18)
				grid.CellPadding = UDim2.fromScale(0.02, 0.02)
			end
		end
	end
	for _, page in pages:GetChildren() do
		if page:IsA("Frame") then
			for _, panel in page:GetChildren() do
				if panel:IsA("Frame") and panel:FindFirstChildOfClass("UIStroke") and not panel:GetAttribute("Preview") then
					UITheme.frame(panel, 14)
					local header = panel:FindFirstChild("Header")
					if header and header:IsA("TextLabel") then
						if DOSSIER then
							dossierHeader(header)
						else
							header.Font = S.Fonts.Title
							header.TextColor3 = C.gold
						end
					end
				end
			end
			local header = page:FindFirstChild("Header")
			if header and header:IsA("TextLabel") then
				header.Font = S.Fonts.Title
				header.TextColor3 = C.gold
			end
		end
	end
end

local function styleModal(gui)
	local modal = gui:FindFirstChild("EventModal")
	local card = modal and modal:FindFirstChild("Card")
	if card then
		UITheme.frame(card, 16)
		if card:FindFirstChild("EventTitle") then card.EventTitle.Font = S.Fonts.Title end
		if card:FindFirstChild("Story") then card.Story.TextColor3 = C.text end
	end
	local toast = gui:FindFirstChild("Toast")
	if toast then
		toast.BorderSizePixel = 0
		ofClass(toast, "UICorner", { CornerRadius = UDim.new(0, S.radius(10)) })
		ofClass(toast, "UIStroke", { Color = C.stroke, Thickness = 1.5, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		S.paint(toast, C.panel1, C.panel2, 90)
	end
end

----------------------------------------------------------------------
-- Edit-mode previews
----------------------------------------------------------------------

local function previews(gui)
	local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
	local page = gui.Main.Pages:FindFirstChild("TrainingPage")
	local grid = page and page:FindFirstChild("ActionsPanel") and page.ActionsPanel:FindFirstChild("Grid")
	if grid and not grid:FindFirstChild("PreviewCard1") then
		for i, action in Content.Get("TrainingConfig").Actions do
			if i > 6 then break end
			local card = S.new("Frame", { Name = "PreviewCard" .. i, LayoutOrder = i, Parent = grid })
			card:SetAttribute("Preview", true)
			S.decorate(card, C.card1, C.card2, C.stroke, 12)
			S.padding(card, 8)
			S.label({ Text = action.Name, Font = S.Fonts.Bold, TextColor3 = C.gold, Size = UDim2.fromScale(1, 0.26), Parent = card }, 16)
			S.label({ Text = action.Description, TextColor3 = C.muted, Position = UDim2.fromScale(0, 0.28), Size = UDim2.fromScale(1, 0.34), TextYAlignment = Enum.TextYAlignment.Top, Parent = card }, 12)
			S.label({ Text = "1 action  ·  0 / 2 this year", Font = S.Fonts.Bold, Position = UDim2.fromScale(0, 0.8), Size = UDim2.fromScale(1, 0.2), Parent = card }, 12)
		end
	end
	local list = page and page:FindFirstChild("AttributesPanel") and page.AttributesPanel:FindFirstChild("StatsList")
	if list and not list:FindFirstChild("PreviewStat1") then
		local stats = Content.Get("PlayerStatsConfig")
		for i, stat in stats.Order do
			local def = stats.Stats[stat]
			local row = S.panel("Frame", { Name = "PreviewStat" .. i, LayoutOrder = i, Size = UDim2.fromScale(1, 0.153), Parent = list }, C.card1, C.card2, 10)
			row:SetAttribute("Preview", true)
			S.padding(row, 10, 4)
			S.label({ Text = def.Name, Font = S.Fonts.Bold, TextColor3 = def.Color, Size = UDim2.fromScale(0.5, 0.42), Parent = row }, 15)
			S.label({ Text = "Lv 1", Font = S.Fonts.Bold, Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.5, 0.42), TextXAlignment = Enum.TextXAlignment.Right, Parent = row }, 15)
			local _, fill = S.bar({ Position = UDim2.fromScale(0, 0.46), Size = UDim2.fromScale(1, 0.16), Parent = row }, def.Color)
			S.setBar(fill, 0.35)
			S.label({ Text = def.Description, TextColor3 = C.muted, Position = UDim2.fromScale(0, 0.66), Size = UDim2.fromScale(1, 0.34), Parent = row }, 13)
		end
	end
	local profs = page and page:FindFirstChild("AttributesPanel") and page.AttributesPanel:FindFirstChild("ProfList")
	if profs and not profs:FindFirstChild("PreviewProf1") then
		local training = Content.Get("TrainingConfig")
		for i, key in training.ProficiencyOrder do
			local def = training.Proficiencies[key]
			local row = S.new("Frame", { Name = "PreviewProf" .. i, BackgroundTransparency = 1, LayoutOrder = i, Size = UDim2.fromScale(1, 0.3), Parent = profs })
			row:SetAttribute("Preview", true)
			S.label({ Text = def.Name, Font = S.Fonts.Bold, TextColor3 = def.Color, Size = UDim2.fromScale(0.26, 1), Parent = row }, 14)
			local _, fill = S.bar({ Position = UDim2.fromScale(0.27, 0.3), Size = UDim2.fromScale(0.55, 0.4), Parent = row }, def.Color)
			S.setBar(fill, 0.2)
			S.label({ Text = "Lv 0", Font = S.Fonts.Bold, Position = UDim2.fromScale(0.84, 0), Size = UDim2.fromScale(0.16, 1), TextXAlignment = Enum.TextXAlignment.Right, Parent = row }, 14)
		end
	end
end

function UITheme.ClearPreviews(gui)
	for _, inst in gui:GetDescendants() do
		if inst:GetAttribute("Preview") then
			inst:Destroy()
		end
	end
end

-- Old purple dashboard palette -> new palette, for static elements nobody restyles.
local OLD = {
	{ Color3.fromRGB(16, 11, 30), C.bg1 }, { Color3.fromRGB(5, 4, 10), C.bg2 },
	{ Color3.fromRGB(30, 24, 52), C.panel1 }, { Color3.fromRGB(16, 12, 30), C.panel2 },
	{ Color3.fromRGB(44, 35, 72), C.card1 }, { Color3.fromRGB(26, 20, 46), C.card2 },
	{ Color3.fromRGB(10, 8, 20), C.inset }, { Color3.fromRGB(150, 120, 230), C.stroke },
	{ Color3.fromRGB(238, 234, 248), C.text }, { Color3.fromRGB(160, 150, 190), C.muted },
	{ Color3.fromRGB(236, 196, 104), C.gold }, { Color3.fromRGB(190, 128, 50), C.gold2 },
	{ Color3.fromRGB(96, 206, 255), C.qi1 }, { Color3.fromRGB(150, 100, 255), C.qi2 },
	-- First obsidian panels -> smoked jade.
	{ Color3.fromRGB(22, 26, 34), C.panel1 }, { Color3.fromRGB(13, 16, 21), C.panel2 },
	-- The template's obsidian / jade / gold palette baked into the layout -> this game's.
	{ Color3.fromRGB(11, 13, 18), C.bg1 }, { Color3.fromRGB(5, 6, 9), C.bg2 }, { Color3.fromRGB(4, 5, 8), C.ink },
	{ Color3.fromRGB(20, 30, 28), C.panel1 }, { Color3.fromRGB(10, 15, 14), C.panel2 },
	{ Color3.fromRGB(30, 35, 45), C.card1 }, { Color3.fromRGB(17, 20, 27), C.card2 }, { Color3.fromRGB(7, 9, 12), C.inset },
	{ Color3.fromRGB(200, 164, 93), C.stroke }, { Color3.fromRGB(214, 178, 104), C.gold }, { Color3.fromRGB(142, 108, 52), C.gold2 },
	{ Color3.fromRGB(88, 214, 182), C.qi1 }, { Color3.fromRGB(46, 139, 120), C.qi2 },
	{ Color3.fromRGB(238, 231, 214), C.text }, { Color3.fromRGB(158, 150, 132), C.muted },
}

local function mapped(color: Color3): Color3?
	for _, pair in OLD do
		local old = pair[1]
		if math.abs(old.R - color.R) < 0.01 and math.abs(old.G - color.G) < 0.01 and math.abs(old.B - color.B) < 0.01 then
			return pair[2]
		end
	end
	return nil
end

local function retint(root)
	for _, inst in root:GetDescendants() do
		if inst:IsA("GuiObject") then
			inst.BackgroundColor3 = mapped(inst.BackgroundColor3) or inst.BackgroundColor3
			if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
				inst.TextColor3 = mapped(inst.TextColor3) or inst.TextColor3
			end
			if inst:IsA("ScrollingFrame") then
				inst.ScrollBarImageColor3 = C.stroke
			end
		elseif inst:IsA("UIStroke") then
			inst.Color = mapped(inst.Color) or inst.Color
		end
	end
end

UITheme.Retint = retint

----------------------------------------------------------------------
-- Dossier layout (UIController calls it on start and on every resize)
----------------------------------------------------------------------

-- Screen rectangles { x, y, w, h } in fractions of the screen. Phones get taller rows
-- (touch targets of 44 px+); desktops and tablets share the wide layout.
local LAYOUTS = {
	Wide = {
		Banner = { 0.01, 0.015, 0.98, 0.18 }, Avatar = { 0.02, 0.03, 0.12, 0.15 },
		NameLabel = { 0.1, 0.028, 0.23, 0.05 }, RaceLabel = { 0.1, 0.08, 0.23, 0.032 },
		TitleLabel = { 0.1, 0.114, 0.23, 0.03 }, AgeLabel = { 0.1, 0.146, 0.23, 0.036 },
		Meters = { 0.345, 0.026, 0.24, 0.16 }, Info = { 0.6, 0.03, 0.38, 0.156 },
		TabBar = { 0.01, 0.207, 0.82, 0.062 }, TreasuryButton = { 0.835, 0.207, 0.155, 0.062 },
		Pages = { 0.01, 0.283, 0.98, 0.579 },
		CommandDeck = { 0.01, 0.875, 0.98, 0.11 }, ActionGems = { 0.022, 0.882, 0.215, 0.096 },
		Strip = { 0.25, 0.882, 0.475, 0.096 }, AdvanceButton = { 0.735, 0.884, 0.165, 0.092 },
		AutoButton = { 0.906, 0.884, 0.076, 0.092 },
	},
	Phone = {
		Banner = { 0.01, 0.01, 0.98, 0.17 }, Avatar = { 0.018, 0.022, 0.1, 0.146 },
		NameLabel = { 0.09, 0.02, 0.24, 0.05 }, RaceLabel = { 0.09, 0.07, 0.24, 0.032 },
		TitleLabel = { 0.09, 0.104, 0.24, 0.03 }, AgeLabel = { 0.09, 0.136, 0.24, 0.036 },
		Meters = { 0.34, 0.02, 0.26, 0.15 }, Info = { 0.61, 0.02, 0.375, 0.15 },
		TabBar = { 0.01, 0.19, 0.82, 0.12 }, TreasuryButton = { 0.835, 0.19, 0.155, 0.12 },
		Pages = { 0.01, 0.32, 0.98, 0.535 },
		CommandDeck = { 0.01, 0.86, 0.98, 0.13 }, ActionGems = { 0.018, 0.866, 0.17, 0.116 },
		Strip = { 0.195, 0.866, 0.5, 0.116 }, AdvanceButton = { 0.702, 0.866, 0.19, 0.116 },
		AutoButton = { 0.898, 0.866, 0.088, 0.116 },
	},
}

-- A child of `root` (whose screen rectangle is `rect`) placed at a screen rectangle.
local function place(child, rect, at)
	if not child or not at then
		return
	end
	child.AnchorPoint = Vector2.zero
	child.Position = UDim2.fromScale((at[1] - rect[1]) / rect[3], (at[2] - rect[2]) / rect[4])
	child.Size = UDim2.fromScale(at[3] / rect[3], at[4] / rect[4])
end

-- Dossier screen: ID banner (sheet), tabs + pages (main), docked command bar (sheet and
-- main parts placed below both). Returns false when the theme does not use it.
function UITheme.Layout(gui, profile): boolean
	if not DOSSIER then
		return false
	end
	local L = if profile and profile.Kind == "Phone" then LAYOUTS.Phone else LAYOUTS.Wide
	local sheet, main = gui:FindFirstChild("Sheet"), gui:FindFirstChild("Main")
	if not sheet or not main then
		return false
	end
	local sheetRect = L.Banner
	sheet.Position = UDim2.fromScale(sheetRect[1], sheetRect[2])
	sheet.Size = UDim2.fromScale(sheetRect[3], sheetRect[4])
	for _, name in { "Banner", "Avatar", "NameLabel", "RaceLabel", "TitleLabel", "AgeLabel", "Meters", "Info", "CommandDeck", "ActionGems", "AdvanceButton", "AutoButton" } do
		place(sheet:FindFirstChild(name), sheetRect, L[name])
	end
	local mainRect = { L.TabBar[1], L.TabBar[2], L.Pages[1] + L.Pages[3] - L.TabBar[1], L.Pages[2] + L.Pages[4] - L.TabBar[2] }
	main.Position = UDim2.fromScale(mainRect[1], mainRect[2])
	main.Size = UDim2.fromScale(mainRect[3], mainRect[4])
	for _, name in { "TabBar", "TreasuryButton", "Pages", "Strip" } do
		place(main:FindFirstChild(name), mainRect, L[name])
	end
	-- Tabs are already full touch targets; long labels wrap onto two lines.
	local tabBar = main:FindFirstChild("TabBar")
	for _, button in if tabBar then tabBar:GetChildren() else {} do
		if button:IsA("TextButton") then
			button:SetAttribute("TouchSafe", true)
			button.TextWrapped = true
		end
	end
	local rule = main:FindFirstChild("TabBaseRule")
	if rule then
		local tab = L.TabBar
		rule.Position = UDim2.new((tab[1] - mainRect[1]) / mainRect[3], 0, (tab[2] + tab[4] - mainRect[2]) / mainRect[4], -2)
		rule.Size = UDim2.new(tab[3] / mainRect[3], 0, 0, 2)
	end
	return true
end

function UITheme.Apply(gui, options)
	retint(gui)
	styleSheet(gui:WaitForChild("Sheet"))
	local main = gui:WaitForChild("Main")
	if DOSSIER then
		bare(main)
	else
		UITheme.frame(main, 18, C.bg1, C.bg2)
	end
	styleStrip(main:WaitForChild("Strip"))
	styleTabs(main:WaitForChild("TabBar"))
	stylePages(main:WaitForChild("Pages"))
	styleModal(gui)
	if options and options.Preview then
		previews(gui)
	end
end

return UITheme
