--[[
	SoundFX: audio and juice for gameplay cues. The server sends cues through
	Remotes.Feedback (PlayerState.Feedback); the Advance Year button clicks locally.
	- BreakthroughFail shakes the main panel; Ascend plays the ascension ending screen.
	- Sound ids are Roblox built-in sounds (verified to load in Studio); swap any for
	  your own rbxassetid:// audio in CUES.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local PackTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PackTheme"))

local CUES = {
	Advance = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.5 },
	BreakthroughSuccess = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6 },
	BreakthroughMajor = { Id = "rbxasset://sounds/victory.wav", Volume = 0.7 },
	BreakthroughFail = { Id = "rbxasset://sounds/glassbreak.wav", Volume = 0.6 },
	Milestone = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5 },
	DuelStart = { Id = "rbxasset://sounds/unsheath.wav", Volume = 0.6 },
	Clash = { Id = "rbxasset://sounds/swordslash.wav", Volume = 0.7 },
	DuelWin = { Id = "rbxasset://sounds/victory.wav", Volume = 0.7 },
	DuelLose = { Id = "rbxasset://sounds/uuhhh.mp3", Volume = 0.6 },
	Ascend = { Id = "rbxasset://sounds/victory.wav", Volume = 0.9 },
	Purchase = { Id = "rbxasset://sounds/victory.wav", Volume = 0.7 },
	Revive = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.8 },
}

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local sounds = {}
for cue, spec in CUES do
	local sound = Instance.new("Sound")
	sound.Name = "Cue_" .. cue
	sound.SoundId = spec.Id
	sound.Volume = spec.Volume
	sound.Parent = SoundService
	sounds[cue] = sound
end

local function play(cue: string)
	local sound = sounds[cue]
	if sound then
		sound.TimePosition = 0
		sound:Play()
	end
end

local function shake()
	local gui = player.PlayerGui:FindFirstChild("LifePathUI")
	local main = gui and gui:FindFirstChild("Main")
	if not main then
		return
	end
	local base = main.Position
	for i = 1, 6 do
		task.delay(i * 0.035, function()
			local dx = (if i % 2 == 0 then -1 else 1) * (8 - i)
			main.Position = base + UDim2.fromOffset(dx, if i % 3 == 0 then 3 else -2)
		end)
	end
	task.delay(0.25, function() main.Position = base end)
end

-- The ascension ending: a golden radiance, the soul's name and the rewards.
local function ascensionScreen(data)
	data = data or {}
	local gui = Instance.new("ScreenGui")
	gui.Name = "AscensionScreen"
	gui.DisplayOrder = 95
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Parent = player.PlayerGui
	local screen = Instance.new("CanvasGroup")
	screen.Size = UDim2.fromScale(1, 1)
	screen.BackgroundColor3 = Color3.fromRGB(255, 236, 180)
	screen.GroupTransparency = 1
	screen.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.fromRGB(255, 250, 230), Color3.fromRGB(200, 150, 60))
	gradient.Parent = screen
	local function label(text: string, y: number, h: number, size: number, color: Color3)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.fromScale(0.5, y)
		l.Size = UDim2.fromScale(0.8, h)
		l.Font = PackTheme.Font("Title")
		l.TextScaled = true
		l.TextWrapped = true
		l.TextColor3 = color
		l.Text = text
		local c = Instance.new("UITextSizeConstraint")
		c.MaxTextSize = size
		c.Parent = l
		l.Parent = screen
		return l
	end
	label(string.upper(PackTheme.Term("AscendTitle")), 0.22, 0.12, 72, Color3.fromRGB(110, 70, 10))
	label(("%s  ·  %s"):format(tostring(data.Name or "Your soul"), PackTheme.Term("AscendHint")), 0.38, 0.07, 32, Color3.fromRGB(60, 40, 10))
	label(PackTheme.Words("{AscendTitle}  ·  +%d {MetaCurrency}  ·  {LegacyBuffName} x%d for every future life"):format(data.Karma or 0, data.Ascensions or 1),
		0.48, 0.06, 24, Color3.fromRGB(90, 60, 20))
	label(PackTheme.Term("AscendOutro"), 0.58, 0.05, 20, Color3.fromRGB(110, 80, 30))
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.fromScale(0.5, 0.72)
	button.Size = UDim2.fromScale(0.22, 0.08)
	button.BackgroundColor3 = Color3.fromRGB(110, 70, 10)
	button.TextColor3 = Color3.fromRGB(255, 240, 200)
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.Text = "Continue  →"
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	local padding = Instance.new("UIPadding")
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0.22, 0), UDim.new(0.22, 0)
	padding.Parent = button
	button.Parent = screen
	TweenService:Create(screen, TweenInfo.new(1.4, Enum.EasingStyle.Quad), { GroupTransparency = 0 }):Play()
	button.Activated:Connect(function()
		local fade = TweenService:Create(screen, TweenInfo.new(0.8), { GroupTransparency = 1 })
		fade.Completed:Connect(function() gui:Destroy() end)
		fade:Play()
	end)
end

Remotes:WaitForChild("Feedback").OnClientEvent:Connect(function(cue, data)
	play(cue)
	if cue == "BreakthroughFail" then
		shake()
	elseif cue == "Ascend" then
		ascensionScreen(data)
	end
end)

-- The Advance Year medallion clicks locally (no round trip needed).
task.spawn(function()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("LifePathUI", 30)
	local advance = gui and gui:WaitForChild("Sheet"):WaitForChild("AdvanceButton")
	if advance then
		advance.Activated:Connect(function() play("Advance") end)
	end
end)
