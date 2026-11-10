--[[
	VoidScene: the 3D backdrop behind the HUD (client only, nothing replicates).
	A black void (Atmosphere + Bloom), a procedural spirit tree of Neon cylinders whose
	branches end in glowing blossoms, a magic-circle floor, drifting motes, and the
	player's avatar in front as a pure-black silhouette (Highlight: black fill, outline in
	the theme color). The camera breathes slowly between two framings.

	Configured by UIThemeConfig.Scene (Enabled, Seed, Depth, PanelTransparency,
	BackdropTransparency, BreathSeconds; colors from the palette).
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local S = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UIStyle"))
local C = S.C
local Scene = S.Theme.Scene or {}
if Scene.Enabled == false then
	return
end

local ORIGIN = Vector3.new(0, 2000, 0) -- far above any map; the fog hides the rest
local GLOW = Scene.Glow or C.gold
local BLOOM = Scene.Bloom or C.qi1
local rng = Random.new(Scene.Seed or 1016)

local folder = Instance.new("Folder")
folder.Name = "VoidScene"
folder.Parent = workspace

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for key, value in props do
		p[key] = value
	end
	p.Parent = props.Parent or folder
	return p
end

-- A Neon cylinder from a to b (cylinders run along X; turned to face b).
local function segment(a: Vector3, b: Vector3, radius: number, color: Color3, transparency: number?): Part
	local length = (b - a).Magnitude
	return part({
		Name = "Branch", Shape = Enum.PartType.Cylinder, Color = color, Transparency = transparency or 0,
		Size = Vector3.new(length, radius * 2, radius * 2),
		CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0),
	})
end

----------------------------------------------------------------------
-- Lighting: the void
----------------------------------------------------------------------

Lighting.ClockTime = 0
Lighting.Brightness = 0
Lighting.Ambient = Color3.new(0, 0, 0)
Lighting.OutdoorAmbient = Color3.fromRGB(8, 8, 14)
Lighting.GlobalShadows = false
for _, child in Lighting:GetChildren() do
	if child:IsA("Atmosphere") or child:IsA("Sky") or child:IsA("PostEffect") then
		child:Destroy()
	end
end
local atmosphere = Instance.new("Atmosphere")
atmosphere.Density, atmosphere.Offset, atmosphere.Glare, atmosphere.Haze = 0.42, 0, 0, 0
atmosphere.Color, atmosphere.Decay = Color3.new(0, 0, 0), Color3.new(0, 0, 0)
atmosphere.Parent = Lighting
local sky = Instance.new("Sky")
sky.CelestialBodiesShown = false
sky.StarCount = 2500
sky.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity, bloom.Size, bloom.Threshold = 1.1, 32, 0.85
bloom.Parent = Lighting
local grade = Instance.new("ColorCorrectionEffect")
grade.Contrast, grade.Saturation, grade.TintColor = 0.12, -0.05, Color3.fromRGB(235, 232, 255)
grade.Parent = Lighting

----------------------------------------------------------------------
-- The spirit tree
----------------------------------------------------------------------

local DEPTH = Scene.Depth or 6
local blossoms = {}

local function blossom(at: Vector3)
	local orb = part({ Name = "Blossom", Shape = Enum.PartType.Ball, Color = BLOOM, Size = Vector3.one * rng:NextNumber(0.5, 1.1), CFrame = CFrame.new(at) })
	table.insert(blossoms, orb)
end

local function grow(base: Vector3, dir: Vector3, length: number, radius: number, depth: number)
	local tip = base + dir * length
	-- Older wood glows fainter; young twigs burn brightest.
	segment(base, tip, radius, GLOW, 0.35 * (depth / DEPTH))
	if depth == 0 then
		blossom(tip)
		return
	end
	local count = if depth >= DEPTH - 1 then 2 else rng:NextInteger(2, 3)
	local turn = rng:NextNumber(0, math.pi * 2)
	for i = 1, count do
		local roll = turn + (i / count) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local pitch = rng:NextNumber(0.35, 0.8)
		local frame = CFrame.lookAt(Vector3.zero, dir)
		local nextDir = (frame * CFrame.Angles(0, 0, roll) * CFrame.Angles(pitch, 0, 0)).LookVector
		nextDir = (nextDir + Vector3.yAxis * 0.3).Unit -- reach for the sky
		grow(tip, nextDir, length * rng:NextNumber(0.66, 0.8), radius * 0.66, depth - 1)
	end
end

-- Trunk: three gently bending sections, then the crown.
local trunkTop = ORIGIN
local trunkDir = Vector3.yAxis
for i = 1, 3 do
	local nextTop = trunkTop + trunkDir * 4.5
	segment(trunkTop, nextTop, 1.5 - i * 0.18, GLOW, 0.4)
	trunkTop = nextTop
	trunkDir = (trunkDir + Vector3.new(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15))).Unit
end
grow(trunkTop, trunkDir, 7, 0.95, DEPTH)

-- Roots spreading over the floor.
for i = 1, 7 do
	local angle = (i / 7) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
	local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local mid = ORIGIN + out * rng:NextNumber(3, 5) + Vector3.new(0, 0.2, 0)
	segment(ORIGIN + Vector3.new(0, 1.2, 0), mid, 0.5, GLOW, 0.45)
	segment(mid, mid + out * rng:NextNumber(3, 6) + Vector3.new(0, -0.1, 0), 0.25, GLOW, 0.55)
end

-- Floor: black glass with a glowing magic circle (two rings and a hexagram).
part({ Name = "Floor", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Glass, Color = Color3.fromRGB(4, 4, 8), Transparency = 0.05,
	Size = Vector3.new(0.4, 120, 120), CFrame = CFrame.new(ORIGIN - Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2) })
local function ring(radius: number, thickness: number, transparency: number)
	local sides = 40
	for i = 0, sides - 1 do
		local a0, a1 = (i / sides) * math.pi * 2, ((i + 1) / sides) * math.pi * 2
		segment(ORIGIN + Vector3.new(math.cos(a0) * radius, 0.05, math.sin(a0) * radius),
			ORIGIN + Vector3.new(math.cos(a1) * radius, 0.05, math.sin(a1) * radius), thickness, GLOW, transparency).Name = "Circle"
	end
end
ring(15, 0.09, 0.25)
ring(12.5, 0.06, 0.45)
for triangle = 0, 1 do
	for i = 0, 2 do
		local a0 = triangle * math.pi / 3 + (i / 3) * math.pi * 2
		local a1 = triangle * math.pi / 3 + ((i + 1) / 3) * math.pi * 2
		segment(ORIGIN + Vector3.new(math.cos(a0) * 12.5, 0.05, math.sin(a0) * 12.5),
			ORIGIN + Vector3.new(math.cos(a1) * 12.5, 0.05, math.sin(a1) * 12.5), 0.05, GLOW, 0.5).Name = "Circle"
	end
end

-- A soft light under the crown and drifting motes.
local heart = part({ Name = "Heart", Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(trunkTop + Vector3.new(0, 6, 0)) })
local light = Instance.new("PointLight")
light.Color, light.Range, light.Brightness = GLOW, 40, 1.4
light.Parent = heart
local motes = Instance.new("ParticleEmitter")
motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
motes.Color = ColorSequence.new(BLOOM, GLOW)
motes.LightEmission, motes.LightInfluence = 1, 0
motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(1, 0) })
motes.Transparency = NumberSequence.new(0.2)
motes.Lifetime = NumberRange.new(6, 10)
motes.Rate = 10
motes.Speed = NumberRange.new(0.4, 1.4)
motes.SpreadAngle = Vector2.new(180, 180)
motes.Acceleration = Vector3.new(0, 0.15, 0)
motes.Parent = heart

-- Blossoms breathe in and out of phase.
for i, orb in blossoms do
	if i % 3 == 0 then
		TweenService:Create(orb, TweenInfo.new(rng:NextNumber(1.6, 3), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.6 }):Play()
	end
end

----------------------------------------------------------------------
-- The silhouette: the player's avatar in black, facing the tree
----------------------------------------------------------------------

local STAND = ORIGIN + Vector3.new(0, 0, 17)
local FACING = CFrame.lookAt(STAND, Vector3.new(ORIGIN.X, STAND.Y, ORIGIN.Z))
local player = Players.LocalPlayer

-- Block figure for players whose character never spawns (UI-only places).
local function mannequin(): Model
	local model = Instance.new("Model")
	model.Name = "Silhouette"
	local function block(name, size, offset, shape)
		local p = part({ Name = name, Material = Enum.Material.SmoothPlastic, Color = Color3.new(0, 0, 0), Size = size,
			Shape = shape or Enum.PartType.Block, CFrame = FACING * CFrame.new(offset), Parent = model })
		return p
	end
	model.PrimaryPart = block("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0))
	block("Head", Vector3.new(1.3, 1.3, 1.3), Vector3.new(0, 4.7, 0), Enum.PartType.Ball)
	block("LeftArm", Vector3.new(0.9, 2, 0.9), Vector3.new(-1.5, 3, 0))
	block("RightArm", Vector3.new(0.9, 2, 0.9), Vector3.new(1.5, 3, 0))
	block("LeftLeg", Vector3.new(0.95, 2, 0.95), Vector3.new(-0.5, 1, 0))
	block("RightLeg", Vector3.new(0.95, 2, 0.95), Vector3.new(0.5, 1, 0))
	return model
end

local function avatarCopy(): Model?
	local character = player.Character or (Players.CharacterAutoLoads and player.CharacterAdded:Wait())
	if not character then
		return nil
	end
	character:WaitForChild("HumanoidRootPart", 5)
	task.wait(0.5) -- accessories arrive a moment later
	character.Archivable = true
	local copy = character:Clone()
	if not copy then
		return nil
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
		end
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	copy.Name = "Silhouette"
	local root = copy:FindFirstChild("HumanoidRootPart")
	if root then
		copy.PrimaryPart = root
		local height = if humanoid then humanoid.HipHeight + root.Size.Y / 2 else 3
		copy:PivotTo(FACING * CFrame.new(0, height, 0))
	end
	return copy
end

task.spawn(function()
	local ok, figure = pcall(avatarCopy)
	if not ok or not figure then
		figure = mannequin()
	end
	figure.Parent = folder
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.new(0, 0, 0)
	highlight.FillTransparency = 0
	highlight.OutlineColor = GLOW
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = figure
	highlight.Parent = figure
end)

----------------------------------------------------------------------
-- Camera: a slow breath between two framings
----------------------------------------------------------------------

local camera = workspace.CurrentCamera
local LOOK = ORIGIN + Vector3.new(0, 13, 0)
local FROM = CFrame.lookAt(ORIGIN + Vector3.new(-2.5, 6.5, 31), LOOK)
local TO = CFrame.lookAt(ORIGIN + Vector3.new(2.5, 7.8, 28.5), LOOK + Vector3.new(0, 0.8, 0))
local breath = Instance.new("NumberValue")
TweenService:Create(breath, TweenInfo.new(Scene.BreathSeconds or 5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Value = 1 }):Play()

RunService:BindToRenderStep("VoidSceneCamera", Enum.RenderPriority.Camera.Value + 1, function()
	camera = workspace.CurrentCamera
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	camera.FieldOfView = 55
	camera.CFrame = FROM:Lerp(TO, breath.Value)
end)

-- The flat backdrop thins to a vignette so the scene shows through.
task.spawn(function()
	local backdrop = player:WaitForChild("PlayerGui"):WaitForChild("LifePathBackdrop", 10)
	local frame = backdrop and backdrop:FindFirstChild("Backdrop")
	if frame then
		frame.BackgroundTransparency = Scene.BackdropTransparency or 0.6
	end
end)
