--[[
	Responsive: screen profile and UI scale for phones, tablets and desktops.

	Responsive.Profile(viewport, touch) -> { Kind, Scale, Touch, Viewport, TouchTarget }
		Kind   "Phone" (touch, short side < PhoneMaxShortSide), "Tablet" (other touch)
		       or "Desktop"
		Scale  viewport relative to BaseResolution (the smaller ratio), clamped to
		       [MinScale, MaxScale]; StarterPlayerScripts/ResponsiveUI puts it in a
		       UIScale on every screen root, so pixel paddings, strokes and text caps
		       follow the screen while the scale-based layout keeps its proportions
	Responsive.Current() reads the camera viewport and UserInputService (client only).
	Pure functions: tests check the profiles of real device sizes.
]]

local Responsive = {}

Responsive.BaseResolution = Vector2.new(1280, 720)
Responsive.MinScale = 0.75
Responsive.MaxScale = 1.6
Responsive.PhoneMaxShortSide = 500 -- GUI pixels (points): every phone, no tablet
Responsive.TouchTarget = 44 -- minimum touch target in screen pixels (Apple HIG 44 pt)
Responsive.MinReadableText = 9 -- smallest text size on touch screens, in screen pixels
Responsive.TouchSpacing = 6 -- minimum gap between list items on touch screens

function Responsive.Profile(viewport: Vector2, touch: boolean)
	local base = Responsive.BaseResolution
	local ratio = math.min(viewport.X / base.X, viewport.Y / base.Y)
	local scale = math.clamp(ratio, Responsive.MinScale, Responsive.MaxScale)
	local short = math.min(viewport.X, viewport.Y)
	local kind = if touch and short < Responsive.PhoneMaxShortSide then "Phone" elseif touch then "Tablet" else "Desktop"
	return { Kind = kind, Scale = scale, Touch = touch, Viewport = viewport, TouchTarget = Responsive.TouchTarget }
end

function Responsive.Current()
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Responsive.BaseResolution
	local UserInputService = game:GetService("UserInputService")
	-- Touch decides (phones in Studio's emulator also report a mouse); a touch laptop
	-- counts as a tablet, which only means bigger targets.
	return Responsive.Profile(viewport, UserInputService.TouchEnabled)
end

-- Calls fn(profile) now and whenever the viewport changes size (rotation, window resize).
function Responsive.Watch(fn)
	local last
	local function update()
		local profile = Responsive.Current()
		local key = ("%s|%.3f"):format(profile.Kind, profile.Scale)
		if key ~= last then
			last = key
			fn(profile)
		end
	end
	update()
	local connection
	local function bind()
		if connection then
			connection:Disconnect()
		end
		if workspace.CurrentCamera then
			connection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
		update()
	end
	bind()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bind)
end

return Responsive
