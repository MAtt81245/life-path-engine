--[[
	PortraitFrames: 14 portrait frames built from plain GUI geometry (no images):
	gradient rings, a halo, rotated diamonds, spikes and gems in each frame's colors.
	Build(avatar, frameId) replaces the "PortraitFrame" decoration on an ImageLabel
	(nil / "None" removes it). Specs is the list the Trove and Settings preview.
]]

local PortraitFrames = {}

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

PortraitFrames.Specs = {
	guildbound = { Ring = rgb(120, 200, 255), Ring2 = rgb(40, 90, 200), Gems = 4, Gem = rgb(255, 255, 255) },
	moonlit_scholar = { Ring = rgb(220, 230, 255), Ring2 = rgb(110, 120, 180), Halo = rgb(180, 200, 255), Gems = 1, Gem = rgb(240, 240, 255) },
	galeborn = { Ring = rgb(150, 240, 210), Ring2 = rgb(40, 140, 120), Spikes = 8, Spike = rgb(170, 255, 230) },
	thunderclap = { Ring = rgb(255, 235, 90), Ring2 = rgb(150, 110, 20), Spikes = 6, Spike = rgb(255, 250, 160), Squares = true },
	demon_kings_eye = { Ring = rgb(200, 30, 50), Ring2 = rgb(40, 0, 10), Halo = rgb(255, 40, 60), Gems = 1, Gem = rgb(255, 210, 60), Squares = true },
	royal_asura = { Ring = rgb(255, 200, 90), Ring2 = rgb(150, 40, 160), Spikes = 12, Spike = rgb(255, 210, 120), Gems = 3, Gem = rgb(200, 80, 255) },
	ember_crown = { Ring = rgb(255, 140, 60), Ring2 = rgb(140, 30, 10), Spikes = 5, Spike = rgb(255, 180, 80) },
	frostbite = { Ring = rgb(190, 240, 255), Ring2 = rgb(60, 120, 200), Spikes = 6, Spike = rgb(220, 250, 255), Squares = true },
	verdant_oath = { Ring = rgb(120, 220, 120), Ring2 = rgb(30, 90, 40), Gems = 4, Gem = rgb(200, 255, 160) },
	starfall = { Ring = rgb(200, 190, 255), Ring2 = rgb(30, 20, 90), Halo = rgb(160, 140, 255), Gems = 6, Gem = rgb(255, 255, 220) },
	abyss_gaze = { Ring = rgb(90, 60, 140), Ring2 = rgb(10, 5, 25), Halo = rgb(120, 60, 200), Squares = true },
	sunwheel = { Ring = rgb(255, 220, 110), Ring2 = rgb(220, 120, 30), Spikes = 16, Spike = rgb(255, 230, 140) },
	jade_lotus = { Ring = rgb(110, 220, 180), Ring2 = rgb(30, 110, 90), Gems = 5, Gem = rgb(255, 190, 220), Squares = true },
	blood_moon = { Ring = rgb(220, 60, 60), Ring2 = rgb(90, 10, 20), Halo = rgb(255, 80, 60), Spikes = 4, Spike = rgb(255, 120, 100) },
}

local function new(className: string, props)
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then inst[key] = value end
	end
	inst.Parent = props.Parent
	return inst
end

function PortraitFrames.Build(avatar: GuiObject, frameId: string?)
	local old = avatar:FindFirstChild("PortraitFrame")
	if old then old:Destroy() end
	local spec = frameId and PortraitFrames.Specs[frameId]
	if not spec then return nil end
	local z = avatar.ZIndex + 2
	local root = new("Frame", { Name = "PortraitFrame", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.22, 1.22), BackgroundTransparency = 1, ZIndex = z, Parent = avatar })
	if spec.Halo then
		local halo = new("Frame", { Name = "Halo", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.08, 1.08),
			BackgroundColor3 = spec.Halo, BackgroundTransparency = 0.75, ZIndex = z - 3, Parent = root })
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = halo })
	end
	if spec.Squares then
		for i, rotation in { 0, 45 } do
			local square = new("Frame", { Name = "Square" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.9),
				Rotation = rotation, BackgroundTransparency = 1, ZIndex = z, Parent = root })
			new("UIStroke", { Color = spec.Ring, Thickness = 1.5, Transparency = 0.35, Parent = square })
		end
	end
	local ring = new("Frame", { Name = "Ring", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.86, 0.86),
		BackgroundTransparency = 1, ZIndex = z, Parent = root })
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
	local stroke = new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 4, Parent = ring })
	new("UIGradient", { Color = ColorSequence.new(spec.Ring, spec.Ring2), Rotation = 45, Parent = stroke })
	for i = 1, spec.Spikes or 0 do
		local angle = (i / spec.Spikes) * math.pi * 2 - math.pi / 2
		new("Frame", { Name = "Spike" .. i, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.47, 0.5 + math.sin(angle) * 0.47), Size = UDim2.fromScale(0.07, 0.07),
			Rotation = 45 + math.deg(angle), BackgroundColor3 = spec.Spike or spec.Ring, BorderSizePixel = 0, ZIndex = z + 1, Parent = root })
	end
	for i = 1, spec.Gems or 0 do
		local angle = -math.pi / 2 + (i - 1) * (math.pi * 2 / math.max(1, spec.Gems))
		local gem = new("Frame", { Name = "Gem" .. i, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.43, 0.5 + math.sin(angle) * 0.43), Size = UDim2.fromScale(0.1, 0.1),
			Rotation = 45, BackgroundColor3 = spec.Gem or spec.Ring, BorderSizePixel = 0, ZIndex = z + 2, Parent = root })
		new("UIStroke", { Color = spec.Ring2, Thickness = 1, Parent = gem })
	end
	return root
end

return PortraitFrames
