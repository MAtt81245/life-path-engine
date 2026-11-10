--[[
	WheelSpinner: the Wheel of Reincarnation as a 3D cylindrical drum that rolls
	vertically and lands on the server's result (Remotes.SpinResult).

	Every visible row sits at an angle on the drum; its normalized distance d from
	the center line (|sin angle|) drives the perspective:
		d = 0    UIScale 1.15, TextTransparency 0, rarity glow behind the row
		d = 0.5  UIScale 0.82, TextTransparency 0.35
		d -> 1   UIScale 0.55, TextTransparency 0.75
	The roll decelerates with a cubic ease-out; a tick plays each time a row
	crosses the center line and Epic+ results flash with a fanfare.

	local drum = WheelSpinner.new(parent)
	drum:Spin(entries, targetIndex, { Speed = 1, OnDone = fn })  -- client (RenderStepped)
	drum:Pose(entries, position)                                  -- static frame (edit preview)
	entries = { { Name, Rarity, Color } }
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local S = require(script.Parent:WaitForChild("UIStyle"))
local C = S.C

local WheelSpinner = {}
WheelSpinner.__index = WheelSpinner

WheelSpinner.VisibleRows = 7 -- rows drawn on the front half of the drum
WheelSpinner.Duration = 3.2 -- seconds at Speed 1
WheelSpinner.FlashRarities = { Epic = true, Legendary = true, Mythic = true }
WheelSpinner.TickSound = "rbxasset://sounds/switch.wav"
WheelSpinner.FanfareSound = "rbxasset://sounds/electronicpingshort.wav"

-- Perspective for a normalized distance d in [0, 1] -> (scale, transparency).
function WheelSpinner.Perspective(d: number): (number, number)
	d = math.clamp(d, 0, 1)
	if d <= 0.5 then
		local t = d / 0.5
		return 1.15 + (0.82 - 1.15) * t, 0.35 * t
	end
	local t = (d - 0.5) / 0.5
	return 0.82 + (0.55 - 0.82) * t, 0.35 + (0.75 - 0.35) * t
end

function WheelSpinner.EaseOutCubic(t: number): number
	t = math.clamp(t, 0, 1)
	return 1 - (1 - t) ^ 3
end

local function sound(parent, name: string, id: string, volume: number)
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Volume = volume
	s.Parent = parent
	return s
end

function WheelSpinner.new(parent: Instance, props)
	local self = setmetatable({}, WheelSpinner)
	local root = S.new("Frame", {
		Name = "Drum", BackgroundColor3 = C.inset, BorderSizePixel = 0, ClipsDescendants = true,
		Position = (props and props.Position) or UDim2.fromScale(0, 0), Size = (props and props.Size) or UDim2.fromScale(1, 1),
		ZIndex = 20, Parent = parent,
	})
	S.new("UICorner", { CornerRadius = UDim.new(0, S.radius(12)), Parent = root })
	S.new("UIStroke", { Color = C.stroke, Thickness = 1.5, Transparency = 0.2, Parent = root })
	-- Cylinder shading: dark at the rims, lit at the center.
	S.new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 70, 70)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 70, 70)),
		}),
		Parent = root,
	})
	local glow = S.new("Frame", {
		Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.94, 0.17),
		BackgroundColor3 = C.gold, BackgroundTransparency = 0.8, BorderSizePixel = 0, ZIndex = 21, Parent = root,
	})
	S.new("UICorner", { CornerRadius = UDim.new(0, 8), Parent = glow })
	for _, y in { 0.405, 0.595 } do
		S.new("Frame", {
			Name = "Rail", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, y), Size = UDim2.new(0.98, 0, 0, 2),
			BackgroundColor3 = C.gold, BorderSizePixel = 0, ZIndex = 24, Parent = root,
		})
	end
	for _, side in { { 0, 0, "▶" }, { 1, 1, "◀" } } do
		S.label({
			Name = "Pointer", Text = side[3], AnchorPoint = Vector2.new(side[2], 0.5), Position = UDim2.fromScale(side[1], 0.5), Size = UDim2.fromScale(0.06, 0.14),
			TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 25, Parent = root,
		}, 18)
	end
	self.Rows = {}
	for i = 1, WheelSpinner.VisibleRows + 2 do
		local row = S.label({
			Name = "Row" .. i, Text = "", Font = S.Fonts.Title, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.14),
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 22, Parent = root,
		}, 22)
		S.new("UIScale", { Parent = row })
		self.Rows[i] = row
	end
	self.Flash = S.new("Frame", {
		Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1,
		BorderSizePixel = 0, ZIndex = 30, Parent = root,
	})
	self.Tick = sound(root, "Tick", WheelSpinner.TickSound, 0.35)
	self.Fanfare = sound(root, "Fanfare", WheelSpinner.FanfareSound, 0.8)
	self.Root, self.Glow = root, glow
	return self
end

-- Draws the drum with `position` (in entries, fractional) at the center line.
function WheelSpinner:Pose(entries, position: number)
	local count = #entries
	if count == 0 then
		return
	end
	local half = (WheelSpinner.VisibleRows + 1) / 2
	local step = (math.pi / 2) / half -- angle between rows; the rim is at 90 degrees
	local base = math.floor(position)
	local frac = position - base
	for i, row in self.Rows do
		local offset = (i - 1) - half -- rows above (-) and below (+) the center
		local angle = (offset - frac) * step
		local entry = entries[((base + offset) % count) + 1]
		local visible = math.abs(angle) < math.pi / 2
		row.Visible = visible and entry ~= nil
		if row.Visible then
			local d = math.abs(math.sin(angle))
			local rowScale, transparency = WheelSpinner.Perspective(d)
			row.Position = UDim2.fromScale(0.5, 0.5 + 0.46 * math.sin(angle))
			row.UIScale.Scale = rowScale
			row.TextTransparency = transparency
			row.Text = entry.Name
			row.TextColor3 = entry.Color or C.text
			row.ZIndex = if d < 0.2 then 23 else 22
		end
	end
	local centered = entries[(math.floor(position + 0.5) % count) + 1]
	self.Glow.BackgroundColor3 = (centered and centered.Color) or C.gold
end

function WheelSpinner:Stop()
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
end

-- Rolls from the current spot to entries[targetIndex] (1-based) and calls OnDone.
function WheelSpinner:Spin(entries, targetIndex: number, options)
	options = options or {}
	self:Stop()
	local count = #entries
	local duration = WheelSpinner.Duration / math.max(0.25, options.Speed or 1)
	local from = self.Position or 0
	-- Land exactly on the target after at least two full turns of the strip.
	local to = (targetIndex - 1) + count * 2
	while to - from < count * 2 do
		to += count
	end
	local started = os.clock()
	local lastRow = math.floor(from + 0.5)
	self.Connection = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - started) / duration
		local position = from + (to - from) * WheelSpinner.EaseOutCubic(t)
		self.Position = position
		self:Pose(entries, position)
		local row = math.floor(position + 0.5)
		if row ~= lastRow then
			lastRow = row
			self.Tick.TimePosition = 0
			self.Tick:Play()
		end
		if t >= 1 then
			self:Stop()
			self.Position = (targetIndex - 1)
			local landed = entries[targetIndex]
			if landed and WheelSpinner.FlashRarities[landed.Rarity] then
				self.Fanfare:Play()
				self.Flash.BackgroundColor3 = landed.Color or Color3.new(1, 1, 1)
				self.Flash.BackgroundTransparency = 0.15
				TweenService:Create(self.Flash, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
			end
			if options.OnDone then
				options.OnDone(landed)
			end
		end
	end)
end

function WheelSpinner:Destroy()
	self:Stop()
	self.Root:Destroy()
end

return WheelSpinner
