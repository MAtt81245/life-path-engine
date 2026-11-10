--!strict
--[[
	UIJuiceAnimator: motion polish for every screen of the game, existing and future
	(DescendantAdded). No dependencies; reads layout only, never content.

	- Bars: a frame named "Fill" (or ending in "Fill", or attribute JuiceBar = true)
	  glides to every new Size (Quart Out, 0.28 s) instead of snapping. Code keeps
	  writing Size as before (UIStyle.setBar); the animator puts the old size back and
	  eases toward the new one from a single Heartbeat loop that only runs while a bar
	  is moving. A write it did not make is a new target, even mid-glide.
	- Popups: when a modal, panel, popup, window, dialog, overlay, menu, shop or
	  inventory frame (by name, or attribute JuicePop = true) turns visible, it pops
	  from 0.82 to 1 (Back Out, 0.22 s) through a UIScale named "Juice". A frame that
	  covers its parent (a modal root or dimmer) is not scaled; its centered children
	  (AnchorPoint 0.5, 0.5: the card) pop instead. Frames created already visible pop
	  only with JuicePop = true, so page rebuilds stay still.
	- Buttons: TextButton / ImageButton grow to 1.04 on hover and dip to 0.92 on
	  press, then spring back. Touch presses skip the hover size. Buttons that cover
	  their parent (click shields, dimmers) stay still.
	Anything that already owns a UIScale (ResponsiveUI roots, hand-animated cards,
	wheel rows) keeps it untouched, since Roblox applies one UIScale per object.
	A ScreenGui or object with attribute NoJuice = true (and its descendants) is
	left alone.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BAR_TIME = 0.28
local POP_TIME = 0.22
local POP_FROM = 0.82
local HOVER_SCALE = 1.04
local PRESS_SCALE = 0.92
local SCALE_NAME = "Juice"

local POP_NAMES = { "Modal", "Popup", "Panel", "Window", "Dialog", "Overlay", "Menu", "Shop", "Inventory" }
-- Engine and tool GUIs. Self-animated parts of game screens carry NoJuice instead
-- (the loading bar in ReplicatedFirst/IntroAndLoadingUI).
local SKIP_GUIS = { TouchGui = true, Freecam = true, DevConsole = true, BubbleChat = true, Chat = true }

local PRESS_INFO = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RELEASE_INFO = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local HOVER_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP_INFO = TweenInfo.new(POP_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CENTER = Vector2.new(0.5, 0.5)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

----------------------------------------------------------------------
-- Shared helpers
----------------------------------------------------------------------

local function excluded(object: Instance): boolean
	local gui = object:FindFirstAncestorWhichIsA("ScreenGui")
	if not gui or SKIP_GUIS[gui.Name] or gui:GetAttribute("NoJuice") == true then
		return true
	end
	local node: Instance? = object
	while node and node ~= gui do
		if node:GetAttribute("NoJuice") == true then
			return true
		end
		node = node.Parent
	end
	return false
end

-- The animator's own UIScale, or nil when the object already has someone else's.
local function juiceScale(object: GuiObject): UIScale?
	local existing = object:FindFirstChildOfClass("UIScale")
	if existing then
		return if existing.Name == SCALE_NAME then existing else nil
	end
	local scale = Instance.new("UIScale")
	scale.Name = SCALE_NAME
	scale.Parent = object
	return scale
end

local function coversParent(object: GuiObject): boolean
	return object.Size.X.Scale >= 0.95 and object.Size.Y.Scale >= 0.95
end

----------------------------------------------------------------------
-- Bars
----------------------------------------------------------------------

type Glide = { From: UDim2, To: UDim2, Start: number, Written: UDim2 }

local glides: { [GuiObject]: Glide } = setmetatable({}, { __mode = "k" }) :: any
local moving: { [GuiObject]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local heartbeat: RBXScriptConnection? = nil

local function step()
	local now = os.clock()
	for fill in moving do
		local glide = glides[fill]
		if not glide or not fill.Parent then
			moving[fill] = nil
			continue
		end
		local alpha = math.min(1, (now - glide.Start) / BAR_TIME)
		local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		local size = if alpha >= 1 then glide.To else glide.From:Lerp(glide.To, eased)
		glide.Written = size
		fill.Size = size
		if alpha >= 1 then
			moving[fill] = nil
		end
	end
	if next(moving) == nil and heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
end

local function isBar(object: Instance): boolean
	if not object:IsA("GuiObject") or object:IsA("GuiButton") then
		return false
	end
	return object:GetAttribute("JuiceBar") == true or string.sub(object.Name, -4) == "Fill"
end

local function hookBar(fill: GuiObject)
	if glides[fill] or excluded(fill) then
		return
	end
	local glide: Glide = { From = fill.Size, To = fill.Size, Start = 0, Written = fill.Size }
	glides[fill] = glide
	fill:GetPropertyChangedSignal("Size"):Connect(function()
		local target = fill.Size
		if target == glide.Written then
			return -- our own write
		end
		glide.From, glide.To, glide.Start = glide.Written, target, os.clock()
		glide.Written = glide.From
		fill.Size = glide.From
		moving[fill] = true
		if not heartbeat then
			heartbeat = RunService.Heartbeat:Connect(step)
		end
	end)
end

----------------------------------------------------------------------
-- Popups
----------------------------------------------------------------------

local function isPopup(object: GuiObject): boolean
	if object:IsA("GuiButton") and not coversParent(object) then
		return false
	end
	if object:GetAttribute("JuicePop") == true then
		return true
	end
	for _, word in POP_NAMES do
		if string.find(object.Name, word, 1, true) then
			return true
		end
	end
	return false
end

local function popOne(target: GuiObject)
	local scale = juiceScale(target)
	if not scale then
		return -- someone else animates or scales it
	end
	scale.Scale = POP_FROM
	TweenService:Create(scale, POP_INFO, { Scale = 1 }):Play()
end

local function pop(frame: GuiObject)
	if not coversParent(frame) then
		popOne(frame)
		return
	end
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") and child.Visible and child.AnchorPoint == CENTER and not coversParent(child) then
			popOne(child)
		end
	end
end

local popHooked: { [GuiObject]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function hookPopup(frame: GuiObject, fresh: boolean)
	if popHooked[frame] or excluded(frame) then
		return
	end
	popHooked[frame] = true
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if frame.Visible then
			pop(frame)
		end
	end)
	if fresh and frame.Visible and frame:GetAttribute("JuicePop") == true then
		pop(frame)
	end
end

----------------------------------------------------------------------
-- Buttons
----------------------------------------------------------------------

local buttonHooked: { [GuiButton]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function hookButton(button: GuiButton)
	if buttonHooked[button] or coversParent(button) or excluded(button) then
		return
	end
	buttonHooked[button] = true
	local hovered, pressed = false, false
	local scale: UIScale? = nil
	local function to(value: number, info: TweenInfo)
		if not button.Interactable or not button.Active then
			value = 1
		end
		scale = scale or juiceScale(button)
		if scale then
			TweenService:Create(scale, info, { Scale = value }):Play()
		end
	end
	button.MouseEnter:Connect(function()
		hovered = true
		if not pressed then
			to(HOVER_SCALE, HOVER_INFO)
		end
	end)
	button.MouseLeave:Connect(function()
		hovered, pressed = false, false
		to(1, HOVER_INFO)
	end)
	button.InputBegan:Connect(function(input: InputObject)
		if isPress(input) then
			pressed = true
			to(PRESS_SCALE, PRESS_INFO)
		end
	end)
	button.InputEnded:Connect(function(input: InputObject)
		if isPress(input) then
			pressed = false
			if input.UserInputType == Enum.UserInputType.Touch then
				hovered = false
			end
			to(if hovered then HOVER_SCALE else 1, RELEASE_INFO)
		end
	end)
end

----------------------------------------------------------------------
-- Wiring
----------------------------------------------------------------------

local function consider(object: Instance, fresh: boolean)
	if not object:IsA("GuiObject") then
		return
	end
	if object:IsA("GuiButton") then
		hookButton(object)
	end
	if isBar(object) then
		hookBar(object)
	elseif isPopup(object) then
		hookPopup(object, fresh)
	end
end

for _, object in playerGui:GetDescendants() do
	consider(object, false)
end
playerGui.DescendantAdded:Connect(function(object: Instance)
	-- Deferred one step so builders finish naming and sizing before we look.
	task.defer(function()
		if object.Parent then
			consider(object, true)
		end
	end)
end)
