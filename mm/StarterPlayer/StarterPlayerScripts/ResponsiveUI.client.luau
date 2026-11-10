--[[
	ResponsiveUI: makes every screen of the game fit phones, tablets and desktops.

	- Core GUI stays enabled and the screen is landscape (LandscapeSensor), so a phone
	  can be turned either way without breaking the three-column layout.
	- Centralized scaling: every root frame of the game's ScreenGuis gets a UIScale
	  ("ResponsiveScale") with Shared/Responsive's Scale, and its Size is divided by
	  it, so the frame still covers the same part of the screen while pixel paddings,
	  strokes and text caps grow on big screens and shrink on small ones.
	- Touch screens: text renders at MinReadableText where its box allows, every button
	  (except grid cells) gets a TouchTarget x TouchTarget screen-pixel minimum, and list
	  spacing gets a minimum gap. Layout-specific phone changes (taller tabs, Advance /
	  Auto-age row, scrolling pages) live in UIController, ShopModal and TutorialGuide.
	Profile attributes on PlayerGui: UIProfile, UIScaleFactor (for other scripts).
	A ScreenGui or root frame with attribute NoAutoScale = true is left alone.
	Works with every game pack: it only reads layout, never content.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Responsive = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Responsive"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
end)
playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor

-- Engine and tool GUIs this script must not touch.
local SKIP = { TouchGui = true, Freecam = true, DevConsole = true, BubbleChat = true, Chat = true }

local profile = Responsive.Current()

local function managed(gui: Instance): boolean
	return gui:IsA("ScreenGui") and not SKIP[gui.Name] and gui:GetAttribute("NoAutoScale") ~= true
end

----------------------------------------------------------------------
-- Root scaling
----------------------------------------------------------------------

-- The Size this script last gave each root (signals may fire deferred, so a flag
-- around the assignment is not enough to recognise our own change).
local applied = setmetatable({}, { __mode = "k" })

local function divided(size: UDim2, s: number): UDim2
	return UDim2.new(size.X.Scale / s, size.X.Offset / s, size.Y.Scale / s, size.Y.Offset / s)
end

local function same(a: UDim2?, b: UDim2): boolean
	return a ~= nil and math.abs(a.X.Scale - b.X.Scale) < 1e-4 and math.abs(a.Y.Scale - b.Y.Scale) < 1e-4
		and math.abs(a.X.Offset - b.X.Offset) < 1 and math.abs(a.Y.Offset - b.Y.Offset) < 1
end

local function setSize(root: GuiObject, size: UDim2)
	root.Size = size
	applied[root] = root.Size -- read back: the engine stores float32
end

local function scaleRoot(root: GuiObject)
	if root:GetAttribute("NoAutoScale") then
		return
	end
	local base = root:GetAttribute("BaseSize")
	if typeof(base) ~= "UDim2" then
		base = root.Size
		root:SetAttribute("BaseSize", base)
		-- Code that resizes the root later sets a new base.
		root:GetPropertyChangedSignal("Size"):Connect(function()
			if not same(applied[root], root.Size) then
				root:SetAttribute("BaseSize", root.Size)
				setSize(root, divided(root.Size, profile.Scale))
			end
		end)
	end
	local s = profile.Scale
	setSize(root, divided(base, s))
	local uiScale = root:FindFirstChild("ResponsiveScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Name = "ResponsiveScale"
		uiScale.Parent = root
	end
	uiScale.Scale = s
end

----------------------------------------------------------------------
-- Touch readability and targets
----------------------------------------------------------------------

-- A free-positioned button grows around its centre: AnchorPoint becomes (0.5, 0.5) and
-- Position moves to the old centre, so the 44-pixel minimum never shifts it sideways
-- or pushes it off the bottom of its card. Code that moves the button later sets a
-- new base. Buttons in list/grid layouts keep their slot. TouchSafe = true opts out
-- (UIController sizes its phone controls itself).
local centred = setmetatable({}, { __mode = "k" }) -- [button] = Position we applied

local function inLayout(button: GuiObject): boolean
	local parent = button.Parent
	return parent ~= nil and parent:FindFirstChildWhichIsA("UIGridStyleLayout") ~= nil
end

local function centre(button: GuiObject, on: boolean)
	local baseAnchor, basePosition = button:GetAttribute("BaseAnchor"), button:GetAttribute("BasePosition")
	if typeof(baseAnchor) ~= "Vector2" then
		if not on then
			return
		end
		baseAnchor, basePosition = button.AnchorPoint, button.Position
		button:SetAttribute("BaseAnchor", baseAnchor)
		button:SetAttribute("BasePosition", basePosition)
		button:GetPropertyChangedSignal("Position"):Connect(function()
			local ours = centred[button]
			if ours and button.Position ~= ours then
				-- Moved by its own code (written for the original anchor).
				button:SetAttribute("BasePosition", button.Position)
				centre(button, true)
			end
		end)
	end
	if on then
		local size, dx, dy = button.Size, 0.5 - baseAnchor.X, 0.5 - baseAnchor.Y
		local position = basePosition + UDim2.new(size.X.Scale * dx, size.X.Offset * dx, size.Y.Scale * dy, size.Y.Offset * dy)
		button.AnchorPoint = Vector2.new(0.5, 0.5)
		button.Position = position
		centred[button] = button.Position
	else
		centred[button] = nil
		button.AnchorPoint, button.Position = baseAnchor, basePosition
	end
end

local safeWatched = setmetatable({}, { __mode = "k" })

local function touchTarget(button: GuiButton)
	if not safeWatched[button] then
		-- Owners may mark a button TouchSafe after it was grown: undo the growth then.
		safeWatched[button] = true
		button:GetAttributeChangedSignal("TouchSafe"):Connect(function()
			touchTarget(button)
		end)
	end
	local constraint = button:FindFirstChild("TouchTarget")
	if button:GetAttribute("TouchSafe") or button.Parent and button.Parent:FindFirstChildWhichIsA("UIGridLayout") then
		-- Sized by its owner, or a grid cell (action cards are large already).
		if constraint then
			constraint:Destroy()
			centre(button, false)
		end
		return
	end
	if not constraint and button:FindFirstChildOfClass("UISizeConstraint") then
		return -- the button sizes itself
	end
	if not profile.Touch then
		if constraint then
			constraint:Destroy()
		end
		centre(button, false)
		return
	end
	local target = Responsive.TouchTarget / profile.Scale
	-- Never larger than the container: a target that spills out of a thin bar or row
	-- covers its neighbours, which is worse than a slightly small target.
	local maxX, maxY = target, target
	local parent = button.Parent
	if parent and parent:IsA("GuiObject") and parent.AbsoluteSize.X > 0 and parent.AbsoluteSize.Y > 0 then
		maxX = math.min(target, parent.AbsoluteSize.X / profile.Scale)
		maxY = math.min(target, parent.AbsoluteSize.Y / profile.Scale)
	end
	constraint = constraint or Instance.new("UISizeConstraint")
	constraint.Name = "TouchTarget"
	constraint.MinSize = Vector2.new(maxX, maxY)
	constraint.Parent = button
	if not inLayout(button) and button.Parent and button.Parent:IsA("GuiObject") then
		centre(button, true)
	end
end

-- Touch screens: text renders at MinReadableText where its box has room for it,
-- never below FLOOR_TEXT screen pixels and never taller than the box (so labels do not
-- spill over their neighbours). Re-fitted when the box changes size.
local FLOOR_TEXT = 7
local fitted = setmetatable({}, { __mode = "k" })

local function fitText(constraint: UITextSizeConstraint)
	local baseMin = constraint:GetAttribute("BaseMin")
	if baseMin == nil then
		baseMin = constraint.MinTextSize
		constraint:SetAttribute("BaseMin", baseMin)
	end
	local label = constraint.Parent
	local s = profile.Scale
	local min = baseMin
	if profile.Touch and label and label:IsA("GuiObject") then
		local room = label.AbsoluteSize.Y * 0.85 -- screen pixels
		local screenMin = math.clamp(room, FLOOR_TEXT, Responsive.MinReadableText)
		min = math.max(baseMin, math.floor(screenMin / s))
		if not fitted[constraint] then
			fitted[constraint] = true
			local function refit()
				if constraint.Parent == label then
					fitText(constraint)
				end
			end
			label:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
			if label:IsA("TextLabel") or label:IsA("TextButton") then
				label:GetPropertyChangedSignal("Text"):Connect(refit)
			end
		end
	end
	local baseMax = constraint:GetAttribute("BaseMax")
	if baseMax == nil then
		baseMax = constraint.MaxTextSize
		constraint:SetAttribute("BaseMax", baseMax)
	end
	constraint.MaxTextSize = math.max(baseMax, min)
	if constraint.MinTextSize ~= min then
		constraint.MinTextSize = min
	end
	-- The readable minimum must not cut or mangle text. A frame later: (1) cap the size so
	-- the longest word stays on one line ("Train Togeth|er"), measured once in the label's
	-- own font (width grows linearly with size); (2) while the engine still says the text
	-- does not fit ("BREAKTHROUG", "Study Hard - 20 EN" on two clipped lines), step the
	-- minimum down, as far as FLOOR_TEXT screen pixels if need be.
	if profile.Touch and label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
		local floorUnits = math.ceil(FLOOR_TEXT / s)
		task.defer(function()
			RunService.Heartbeat:Wait()
			if constraint.Parent ~= label then
				return
			end
			local word = ""
			for w in string.gmatch(string.gsub(label.Text, "<[^>]+>", ""), "%S+") do
				if #w > #word then word = w end
			end
			local width = label.AbsoluteSize.X / s
			local pad = label:FindFirstChildOfClass("UIPadding")
			if pad then
				width -= pad.PaddingLeft.Offset + pad.PaddingRight.Offset + (pad.PaddingLeft.Scale + pad.PaddingRight.Scale) * width
			end
			if #word >= 4 and width > 0 then
				local params = Instance.new("GetTextBoundsParams")
				params.Text, params.Font, params.Size, params.Width = word, label.FontFace, 20, 1e4
				local ok, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
				if ok and bounds.X > 0 and constraint.Parent == label then
					-- 0.8: the engine wraps a little inside the box (measured: "Together" broke
					-- at ~88% of the reported width).
					local cap = math.max(floorUnits, math.floor(20 * width * 0.8 / bounds.X))
					if cap < constraint.MaxTextSize then
						constraint.MinTextSize = math.min(constraint.MinTextSize, cap)
						constraint.MaxTextSize = cap
					end
				end
			end
			for _ = 1, 16 do
				RunService.Heartbeat:Wait()
				if constraint.Parent ~= label or label.TextFits or constraint.MinTextSize <= floorUnits then
					return
				end
				constraint.MinTextSize -= 1
			end
		end)
	end
end

local function tune(inst: Instance)
	local s = profile.Scale
	if inst:IsA("UITextSizeConstraint") then
		fitText(inst)
	elseif inst:IsA("UIListLayout") then
		local base = inst:GetAttribute("BasePadding")
		if typeof(base) ~= "UDim" then
			base = inst.Padding
			inst:SetAttribute("BasePadding", base)
		end
		-- Pixel gaps between tappable rows; scale gaps already follow the screen.
		local gap = math.ceil(Responsive.TouchSpacing / s)
		inst.Padding = if profile.Touch and base.Scale == 0 and base.Offset > 0 and base.Offset < gap then UDim.new(0, gap) else base
	elseif inst:IsA("GuiButton") then
		touchTarget(inst)
	end
end

----------------------------------------------------------------------
-- Wiring
----------------------------------------------------------------------

local function applyGui(gui: ScreenGui)
	for _, child in gui:GetChildren() do
		if child:IsA("GuiObject") then
			scaleRoot(child)
		end
	end
	for _, inst in gui:GetDescendants() do
		tune(inst)
	end
end

local watched = setmetatable({}, { __mode = "k" })
local function watch(gui: Instance)
	if not managed(gui) or watched[gui] then
		return
	end
	watched[gui] = true
	applyGui(gui :: ScreenGui)
	gui.ChildAdded:Connect(function(child)
		if child:IsA("GuiObject") then
			scaleRoot(child)
		end
	end)
	gui.DescendantAdded:Connect(function(inst)
		-- Wait a frame: builders set properties and constraints right after parenting.
		task.defer(function()
			if inst.Parent then
				tune(inst)
			end
		end)
	end)
end

Responsive.Watch(function(newProfile)
	profile = newProfile
	playerGui:SetAttribute("UIProfile", profile.Kind)
	playerGui:SetAttribute("UIScaleFactor", profile.Scale)
	for gui in watched do
		if gui.Parent then
			applyGui(gui)
		end
	end
end)

for _, gui in playerGui:GetChildren() do
	watch(gui)
end
playerGui.ChildAdded:Connect(watch)
