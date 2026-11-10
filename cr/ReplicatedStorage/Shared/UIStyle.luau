--[[
	Shared visual language for LifePathUI: palette, fonts and element factories.
	Shared/UITheme applies the bespoke frames (double borders, tabs, ledger) to the
	static layout; these factories style the content pages build at runtime.
	Used by the client page modules (and by the layout builder in Studio).

	Note: a UIGradient tints its own object's text too. To keep text bright, the base
	color goes in BackgroundColor3 and the gradient runs from white to a shade.
]]

local BigNum = require(script.Parent.Parent:WaitForChild("Configs"):WaitForChild("BigNum"))
local PackTheme = require(script.Parent:WaitForChild("PackTheme"))

local UIStyle = {}

-- The game's look (Configs/UIThemeConfig). Key names keep their cultivation roots:
-- "gold" is the accent, "qi" the energy color, "jade" the panels.
UIStyle.Theme = PackTheme.Get()
local C = table.clone(UIStyle.Theme.Palette)
UIStyle.C = C

-- Interface vocabulary ("EnergyName" -> "Qi"); edit Configs/UIThemeConfig.Terms to rename.
UIStyle.Terms = UIStyle.Theme.Terms
function UIStyle.term(key: string): string
	return PackTheme.Term(key)
end

-- Corner radius scaled by the theme (modern rounder, academy sharper).
function UIStyle.radius(pixels: number): number
	return math.floor(pixels * (UIStyle.Theme.Corner or 1) + 0.5)
end

UIStyle.KindColors = {
	info = C.text, good = C.green, bad = C.red, event = C.gold, realm = C.qi1, death = C.violet, warn = C.gold,
}

UIStyle.Fonts = {
	Body = PackTheme.Font("Body"),
	Bold = PackTheme.Font("Bold"),
	Heavy = PackTheme.Font("Heavy"),
	Title = PackTheme.Font("Title"),
	Mono = PackTheme.Font("Mono"),
}

-- Theme Style "Dossier": modern tactical layout, 1 px glass panels (Shared/UITheme).
UIStyle.Dossier = UIStyle.Theme.Style == "Dossier"

-- A true two-colour gradient (paint() only darkens one colour): crimson -> violet.
function UIStyle.gradient(inst, c1: Color3, c2: Color3, rotation: number?)
	inst.BackgroundColor3 = Color3.new(1, 1, 1)
	local gradient = inst:FindFirstChildOfClass("UIGradient")
	if not gradient then
		gradient = UIStyle.new("UIGradient", { Parent = inst })
	end
	gradient.Rotation = rotation or 0
	gradient.Color = ColorSequence.new(c1, c2)
end

function UIStyle.new(className: string, props)
	local inst = Instance.new(className)
	local parent
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		else
			inst[key] = value
		end
	end
	inst.Parent = parent
	return inst
end

function UIStyle.shade(c1: Color3, c2: Color3): ColorSequence
	return ColorSequence.new(Color3.new(1, 1, 1), Color3.new(
		math.min(1, c2.R / math.max(c1.R, 1e-3)),
		math.min(1, c2.G / math.max(c1.G, 1e-3)),
		math.min(1, c2.B / math.max(c1.B, 1e-3))
	))
end

-- Base color + white-to-shade gradient (keeps text readable).
function UIStyle.paint(inst, c1: Color3, c2: Color3, rotation: number?)
	inst.BackgroundColor3 = c1
	local gradient = inst:FindFirstChildOfClass("UIGradient")
	if not gradient then
		gradient = UIStyle.new("UIGradient", { Rotation = rotation or 90, Parent = inst })
	end
	gradient.Color = UIStyle.shade(c1, c2)
end

-- Corner + soft stroke + gradient.
function UIStyle.decorate(inst, c1: Color3?, c2: Color3?, strokeColor: Color3?, radius: number?, strokeTransparency: number?)
	inst.BorderSizePixel = 0
	inst.BackgroundTransparency = 0
	UIStyle.new("UICorner", { CornerRadius = UDim.new(0, UIStyle.radius(radius or 12)), Parent = inst })
	UIStyle.new("UIStroke", {
		Color = strokeColor or C.stroke,
		Transparency = strokeTransparency or 0.65,
		Thickness = if UIStyle.Dossier then 1 else 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = inst,
	})
	UIStyle.paint(inst, c1 or C.panel1, c2 or C.panel2)
	return inst
end

function UIStyle.panel(className: string, props, c1: Color3?, c2: Color3?, radius: number?, strokeColor: Color3?)
	local inst = UIStyle.new(className, props)
	return UIStyle.decorate(inst, c1, c2, strokeColor, radius)
end

function UIStyle.padding(inst, x: number, y: number?)
	return UIStyle.new("UIPadding", {
		PaddingLeft = UDim.new(0, x), PaddingRight = UDim.new(0, x),
		PaddingTop = UDim.new(0, y or x), PaddingBottom = UDim.new(0, y or x),
		Parent = inst,
	})
end

function UIStyle.list(parent, padding: UDim, horizontal: boolean?)
	return UIStyle.new("UIListLayout", {
		Padding = padding,
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

-- Scaled text that never overflows its box.
function UIStyle.text(className: string, props, maxSize: number?)
	if props.BackgroundTransparency == nil then
		props.BackgroundTransparency = 1
	end
	props.BorderSizePixel = 0
	props.Font = props.Font or UIStyle.Fonts.Body
	props.TextColor3 = props.TextColor3 or C.text
	props.TextScaled = true
	if props.TextWrapped == nil then
		props.TextWrapped = true
	end
	if props.TextXAlignment == nil and className == "TextLabel" then
		props.TextXAlignment = Enum.TextXAlignment.Left
	end
	local inst = UIStyle.new(className, props)
	UIStyle.new("UITextSizeConstraint", { MaxTextSize = maxSize or 16, MinTextSize = 7, Parent = inst })
	return inst
end

function UIStyle.label(props, maxSize: number?)
	return UIStyle.text("TextLabel", props, maxSize)
end

function UIStyle.caption(parent, name: string, str: string, position: UDim2, size: UDim2, align)
	return UIStyle.label({
		Name = name, Text = str, Font = UIStyle.Fonts.Bold, TextColor3 = C.muted,
		Position = position, Size = size, TextXAlignment = align, Parent = parent,
	}, 13)
end

function UIStyle.button(props, c1: Color3?, c2: Color3?, maxSize: number?, textColor: Color3?)
	props.AutoButtonColor = false
	props.Font = props.Font or UIStyle.Fonts.Bold
	props.TextColor3 = textColor or C.dark
	local button = UIStyle.text("TextButton", props, maxSize or 16)
	UIStyle.decorate(button, c1 or C.gold, c2 or C.gold2, C.gold, 10, 0.5)
	return button
end

-- Secondary (dark) button with light text.
function UIStyle.ghostButton(props, maxSize: number?)
	return UIStyle.button(props, C.card1, C.card2, maxSize, C.text)
end

-- Disabled buttons are repainted dark; the original look is remembered in attributes.
function UIStyle.setEnabled(button, enabled: boolean)
	local gradient = button:FindFirstChildOfClass("UIGradient")
	if button:GetAttribute("BaseColor") == nil then
		button:SetAttribute("BaseColor", button.BackgroundColor3)
		button:SetAttribute("BaseText", button.TextColor3)
		if gradient then
			local keypoints = gradient.Color.Keypoints
			button:SetAttribute("BaseShade", keypoints[#keypoints].Value)
		end
	end
	button.Active = enabled
	button.AutoButtonColor = false
	if enabled then
		button.BackgroundColor3 = button:GetAttribute("BaseColor")
		button.TextColor3 = button:GetAttribute("BaseText")
		if gradient and button:GetAttribute("BaseShade") then
			gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), button:GetAttribute("BaseShade"))
		end
	else
		UIStyle.paint(button, C.card2, C.panel2)
		button.TextColor3 = C.muted
	end
	button.TextTransparency = if enabled then 0 else 0.25
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = if enabled then 0.5 else 0.85
	end
end

-- Progress bar: returns (back, fill).
function UIStyle.bar(props, c1: Color3, c2: Color3?)
	props.BackgroundColor3 = C.inset
	props.BorderSizePixel = 0
	props.ClipsDescendants = true
	local back = UIStyle.new("Frame", props)
	UIStyle.new("UICorner", { CornerRadius = UDim.new(0, 6), Parent = back })
	UIStyle.new("UIStroke", { Color = c1, Transparency = 0.7, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = back })
	local fill = UIStyle.new("Frame", { Name = "Fill", Size = UDim2.fromScale(0.5, 1), BorderSizePixel = 0, Parent = back })
	UIStyle.new("UICorner", { CornerRadius = UDim.new(0, 6), Parent = fill })
	UIStyle.paint(fill, c1, c2 or c1:Lerp(Color3.new(0, 0, 0), 0.35), 0)
	return back, fill
end

function UIStyle.setBar(fill, ratio: number)
	ratio = math.clamp(ratio, 0, 1)
	fill.Size = UDim2.fromScale(ratio, 1)
	fill.Visible = ratio > 0.001
end

-- Destroys dynamic children, keeping layouts, paddings and constraints.
function UIStyle.clear(container)
	for _, child in container:GetChildren() do
		if not child:IsA("UIComponent") then
			child:Destroy()
		end
	end
end

function UIStyle.escape(s: string): string
	s = string.gsub(s, "&", "&amp;")
	s = string.gsub(s, "<", "&lt;")
	s = string.gsub(s, ">", "&gt;")
	return s
end

function UIStyle.hex(color: Color3): string
	return color:ToHex()
end

function UIStyle.money(amount: number): string
	local symbol = UIStyle.Terms.MoneySymbol or "$" -- "¥" for yen
	if amount < 0 then
		return "-" .. symbol .. BigNum.from(-amount):ToString()
	end
	return symbol .. BigNum.from(math.floor(amount)):ToString()
end

-- Rich text list of requirement items: green when met, red when not.
function UIStyle.requirementText(items): string
	if #items == 0 then
		return "No requirements"
	end
	local parts = {}
	for _, item in items do
		local color = if item.Met then C.green else C.red
		table.insert(parts, ('<font color="#%s">%s</font>'):format(color:ToHex(), UIStyle.escape(item.Text)))
	end
	return table.concat(parts, "  ·  ")
end

function UIStyle.alignmentText(alignment: number): string
	local name = if alignment >= 60 then "Righteous"
		elseif alignment >= 20 then "Upright"
		elseif alignment > -20 then "Neutral"
		elseif alignment > -60 then "Shady"
		else "Demonic"
	return ("%s (%+d)"):format(name, alignment)
end

return UIStyle
