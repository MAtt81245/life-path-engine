--[[
	ModalShield: no click ever passes through a popup.
	Attach(frame) puts a full-screen invisible TextButton (Active + Modal) behind the
	frame's content, so taps outside the card land on the shield, not on the HUD below.
	AnyOpen() / Changed let overlays that must yield to modals (tutorial spotlight,
	tooltips) hide while one is up.
]]

local GuiService = game:GetService("GuiService")

local ModalShield = {}

local attached = {} -- [frame] = shield
local changed = Instance.new("BindableEvent")
ModalShield.Changed = changed.Event

local function shown(frame: GuiObject): boolean
	local node: Instance? = frame
	while node and node:IsA("GuiObject") do
		if not node.Visible then
			return false
		end
		node = node.Parent
	end
	if node and node:IsA("LayerCollector") then
		return node.Enabled and node:IsDescendantOf(game)
	end
	return false
end

function ModalShield.AnyOpen(): boolean
	for frame in attached do
		if frame.Parent and shown(frame) then
			return true
		end
	end
	return false
end

-- Screen rect of every open modal's card (tutorial highlights must not cover their headers).
function ModalShield.OpenRects(): { { Position: Vector2, Size: Vector2 } }
	local rects = {}
	for frame in attached do
		if frame.Parent and shown(frame) then
			local card = frame:FindFirstChild("Card") or frame
			if card:IsA("GuiObject") then
				table.insert(rects, { Position = card.AbsolutePosition, Size = card.AbsoluteSize })
			end
		end
	end
	return rects
end

-- `frame` should cover the screen (an overlay). The shield is its lowest child, so the
-- card still receives clicks and everything outside the card is swallowed.
function ModalShield.Attach(frame: GuiObject): TextButton
	if attached[frame] then
		return attached[frame]
	end
	frame.Active = true
	local shield = Instance.new("TextButton")
	shield.Name = "ClickShield"
	shield.Text = ""
	shield.AutoButtonColor = false
	shield.BackgroundTransparency = 1
	shield.BorderSizePixel = 0
	shield.Active = true
	shield.Modal = true -- frees the mouse in first person while the popup is up
	shield.Selectable = false
	shield.Size = UDim2.fromScale(1, 1)
	shield.ZIndex = math.max(0, frame.ZIndex - 1)
	shield.Parent = frame
	attached[frame] = shield
	local function fire()
		changed:Fire(ModalShield.AnyOpen())
	end
	frame:GetPropertyChangedSignal("Visible"):Connect(fire)
	frame.AncestryChanged:Connect(function()
		if not frame:IsDescendantOf(game) then
			attached[frame] = nil
		end
		fire()
	end)
	fire()
	return shield
end

-- Viewport clamping for tooltips and tutorial highlights: nothing drawn off-screen.
ModalShield.Margin = 8

-- A screen rect (pixels, top-left origin) pushed inside the camera viewport.
function ModalShield.ClampRect(position: Vector2, size: Vector2, margin: number?): (Vector2, Vector2)
	local m = margin or ModalShield.Margin
	local camera = workspace.CurrentCamera
	if not camera then
		return position, size
	end
	local viewport = camera.ViewportSize
	local w = math.min(size.X, viewport.X - 2 * m)
	local h = math.min(size.Y, viewport.Y - 2 * m)
	local x = math.clamp(position.X, m, math.max(m, viewport.X - m - w))
	local y = math.clamp(position.Y, m, math.max(m, viewport.Y - m - h))
	return Vector2.new(x, y), Vector2.new(w, h)
end

-- Nudges a GuiObject's Position offset so its on-screen rect stays inside the viewport.
function ModalShield.Clamp(frame: GuiObject, margin: number?)
	local screen = frame:FindFirstAncestorWhichIsA("ScreenGui")
	local inset = if screen and not screen.IgnoreGuiInset then GuiService:GetGuiInset() else Vector2.zero
	local position = frame.AbsolutePosition + inset
	local clamped = ModalShield.ClampRect(position, frame.AbsoluteSize, margin)
	local delta = clamped - position
	if delta.Magnitude > 0.5 then
		frame.Position += UDim2.fromOffset(delta.X, delta.Y)
	end
end

function ModalShield.IsAttached(frame: GuiObject): boolean
	return attached[frame] ~= nil
end

return ModalShield
