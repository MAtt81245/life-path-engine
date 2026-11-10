--[[
	IntroAndLoadingUI: the cinematic loading screen (theme palette, a Cursed Eye domain
	seal with counter-rotating crimson/violet rings, DisplayOrder 100) replaces Roblox's
	default one. Title, subtitle and stage lines are Terms (LoadingTitle, LoadingSubtitle,
	LoadingStage1-5, LoadingDone); fonts and corners follow the theme. It fades out only when
	the game is ready (place loaded, character state received, interface drawn,
	assets preloaded; progress bar), after at least 5 s and at most 25 s. At the start of every life (age 0) the
	reincarnation prologue types itself out with the birth region from
	WorldRegionsConfig (World module), with Skip and Continue.
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

-- The active pack's palette and words (Shared/PackTheme); the cultivation defaults
-- stay if the shared modules are slow to arrive, so the loading screen never waits.
local OBSIDIAN = Color3.fromRGB(11, 13, 18)
local JADE = Color3.fromRGB(20, 30, 28)
local GOLD = Color3.fromRGB(200, 164, 93)
local PARCHMENT = Color3.fromRGB(238, 231, 214)
local MUTED = Color3.fromRGB(158, 150, 132)
local CRIMSON = Color3.fromRGB(225, 29, 72)
local INK = Color3.fromRGB(4, 5, 8)
local TITLE_FONT = Enum.Font.GothamBlack
local MONO_FONT = Enum.Font.RobotoMono
local CORNER = 1 -- theme corner multiplier
local MODERN = false -- theme Style "Dossier": crisp 1 px frames instead of double trims
local TERMS = { RaceName = "Bloodline" }
do
	local shared = ReplicatedStorage:WaitForChild("Shared", 5)
	local module = shared and shared:WaitForChild("PackTheme", 5)
	local ok, packTheme = pcall(require, module)
	local theme = ok and packTheme.Get()
	if theme then
		local p = theme.Palette
		OBSIDIAN, JADE, GOLD, PARCHMENT, MUTED = p.bg1, p.panel1, p.stroke, p.text, p.muted
		CRIMSON, INK = p.crimson1 or CRIMSON, p.ink or INK
		TERMS = theme.Terms
		TITLE_FONT, MONO_FONT = packTheme.Font("Title"), packTheme.Font("Mono")
		CORNER = theme.Corner or 1
		MODERN = theme.Style == "Dossier"
	end
end
local function radius(px: number): UDim
	return UDim.new(0, math.max(2, math.floor(px * CORNER + 0.5)))
end

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "IntroAndLoadingUI"
gui.DisplayOrder = 100
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function new(className: string, props)
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			inst[key] = value
		end
	end
	inst.Parent = props.Parent
	return inst
end

local function text(props, maxSize: number)
	props.BackgroundTransparency = 1
	props.TextScaled = true
	props.TextWrapped = true
	props.TextColor3 = props.TextColor3 or PARCHMENT
	props.Font = props.Font or Enum.Font.GothamMedium
	local label = new("TextLabel", props)
	new("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = 8, Parent = label })
	return label
end

-- Panel border: a double trim (classic themes) or a crisp 1 px line with four crimson
-- corner brackets (Dossier style).
local function doubleFrame(parent, inset: number)
	if MODERN then
		new("UIStroke", { Color = GOLD, Thickness = 1, Transparency = 0.35, Parent = parent })
		for name, at in { TL = Vector2.new(0, 0), TR = Vector2.new(1, 0), BL = Vector2.new(0, 1), BR = Vector2.new(1, 1) } do
			for _, horizontal in { true, false } do
				new("Frame", { Name = "Bracket" .. name .. (if horizontal then "H" else "V"), AnchorPoint = at,
					Position = UDim2.fromScale(at.X, at.Y), Size = if horizontal then UDim2.fromOffset(18, 2) else UDim2.fromOffset(2, 18),
					BackgroundColor3 = CRIMSON, BorderSizePixel = 0, ZIndex = 3, Parent = parent })
			end
		end
		return
	end
	new("UIStroke", { Color = GOLD, Thickness = 2, Parent = parent })
	local inner = new("Frame", { Name = "InnerTrim", Position = UDim2.fromOffset(inset, inset), Size = UDim2.new(1, -inset * 2, 1, -inset * 2),
		BackgroundTransparency = 1, Parent = parent })
	new("UIStroke", { Color = GOLD, Thickness = 1, Transparency = 0.45, Parent = inner })
end

----------------------------------------------------------------------
-- Loading screen
----------------------------------------------------------------------

local loading = new("CanvasGroup", { Name = "Loading", Size = UDim2.fromScale(1, 1), BackgroundColor3 = OBSIDIAN, ZIndex = 10, Parent = gui })
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)), Parent = loading })
local border = new("Frame", { Name = "Border", Position = UDim2.fromScale(0.03, 0.04), Size = UDim2.fromScale(0.94, 0.92), BackgroundTransparency = 1, Parent = loading })
doubleFrame(border, 8)
-- Cursed Eye domain seal: a crimson outer ring with tick marks and a violet inner ring
-- with notches turn in opposite directions around a pulsing eye.
local seal = new("Frame", { Name = "Seal", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromScale(0.3, 0.3),
	BackgroundTransparency = 1, Parent = loading })
new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = seal })
local function ring(name: string, size: number, color: Color3, thickness: number)
	local frame = new("Frame", { Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(size, size),
		BackgroundTransparency = 1, Parent = seal })
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = frame })
	new("UIStroke", { Color = color, Thickness = thickness, Parent = frame })
	return frame
end
local outer = ring("OuterRing", 0.96, CRIMSON, 3)
for i = 1, 24 do
	local angle = (i - 1) / 24 * math.pi * 2
	local long = i % 3 == 1
	new("Frame", { Name = "Tick" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Rotation = math.deg(angle),
		Position = UDim2.fromScale(0.5 + math.sin(angle) * 0.455, 0.5 - math.cos(angle) * 0.455),
		Size = UDim2.fromScale(0.012, if long then 0.07 else 0.035), BackgroundColor3 = CRIMSON, BorderSizePixel = 0, Parent = outer })
end
local inner = ring("InnerRing", 0.7, GOLD, 2)
for i = 1, 6 do
	local angle = (i - 1) / 6 * math.pi * 2
	new("Frame", { Name = "Notch" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45,
		Position = UDim2.fromScale(0.5 + math.sin(angle) * 0.5, 0.5 - math.cos(angle) * 0.5),
		Size = UDim2.fromScale(0.06, 0.06), BackgroundColor3 = GOLD, BorderSizePixel = 0, Parent = inner })
end
local glow = new("Frame", { Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = CRIMSON, BackgroundTransparency = 0.8, Parent = seal })
new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = glow })
local core = new("Frame", { Name = "Core", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.42, 0.42),
	BackgroundColor3 = INK, Parent = seal })
new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = core })
new("UIStroke", { Color = GOLD, Thickness = 1, Parent = core })
text({ Name = "Eye", Text = "👁", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.72, 0.72), Font = Enum.Font.GothamBold, Parent = core }, 120)
text({ Name = "Title", Text = TERMS.LoadingTitle or "LIFE PATH", Font = TITLE_FONT, TextColor3 = PARCHMENT, AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.63), Size = UDim2.fromScale(0.6, 0.08), Parent = loading }, 56)
text({ Name = "Subtitle", Text = TERMS.LoadingSubtitle or "", Font = TITLE_FONT, TextColor3 = CRIMSON, AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.71), Size = UDim2.fromScale(0.6, 0.045), Parent = loading }, 26)
local status = text({ Name = "Status", Text = TERMS.LoadingStage1 or "Loading...", Font = MONO_FONT, TextColor3 = MUTED, AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.82), Size = UDim2.fromScale(0.6, 0.035), Parent = loading }, 18)

-- Progress: a thin crimson-to-violet bar under the status line, filled stage by stage.
local barBack = new("Frame", { Name = "ProgressBack", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.875),
	Size = UDim2.fromScale(0.34, 0.006), BackgroundColor3 = JADE, BorderSizePixel = 0, Parent = loading })
new("UIStroke", { Color = GOLD, Thickness = 1, Transparency = 0.6, Parent = barBack })
local barFill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = barBack })
new("UIGradient", { Color = ColorSequence.new(CRIMSON, GOLD), Parent = barFill })

local spin = RunService.RenderStepped:Connect(function(dt)
	outer.Rotation = (outer.Rotation + dt * 22) % 360
	inner.Rotation = (inner.Rotation - dt * 34) % 360
	local pulse = 0.5 + 0.5 * math.sin(os.clock() * 2.4)
	glow.Size = UDim2.fromScale(0.5 + pulse * 0.12, 0.5 + pulse * 0.12)
	glow.BackgroundTransparency = 0.72 + pulse * 0.18
end)

local function progress(fraction: number, message: string)
	status.Text = message
	TweenService:Create(barFill, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1) }):Play()
end

-- The screen stays until the game is really ready, in stages (each with a time limit
-- so a slow asset can never trap the player): the place has loaded, the character
-- state has arrived, the interface has drawn it once, and its fonts, images and
-- sounds are preloaded. It also stays at least MIN_SHOW seconds.
local MIN_SHOW = 5
local STAGE_TIMEOUT = 8
local MAX_WAIT = 25 -- absolute ceiling (see the fallback at the end of the script)
local shownAt = os.clock()
local loaded = false
local loadingGone = false
local snapshotArrived = false

local function waitUntil(check: () -> boolean, timeout: number)
	local deadline = os.clock() + timeout
	while not check() and os.clock() < deadline do
		task.wait(0.1)
	end
end

local function preloadGame()
	local ContentProvider = game:GetService("ContentProvider")
	local playerGui = player:WaitForChild("PlayerGui")
	local targets = {}
	for _, name in { "LifePathUI", "LifePathBackdrop", "TreasuryUI" } do
		local screen = playerGui:FindFirstChild(name)
		if screen then
			table.insert(targets, screen)
		end
	end
	for _, sound in game:GetService("SoundService"):GetDescendants() do
		if sound:IsA("Sound") then
			table.insert(targets, sound)
		end
	end
	local done = false
	task.spawn(function()
		pcall(ContentProvider.PreloadAsync, ContentProvider, targets)
		done = true
	end)
	waitUntil(function() return done end, STAGE_TIMEOUT)
end

local function finishLoading()
	if loaded then
		return
	end
	loaded = true
	progress(0.15, TERMS.LoadingStage1 or "Loading...")
	if not game:IsLoaded() then
		waitUntil(function() return game:IsLoaded() end, STAGE_TIMEOUT)
	end
	progress(0.35, TERMS.LoadingStage2 or "Connecting...")
	waitUntil(function() return snapshotArrived end, STAGE_TIMEOUT)
	progress(0.55, TERMS.LoadingStage3 or "Building your character...")
	waitUntil(function()
		local ui = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("LifePathUI")
		return ui ~= nil and ui:GetAttribute("Ready") == true
	end, STAGE_TIMEOUT)
	progress(0.75, TERMS.LoadingStage4 or "Drawing the interface...")
	preloadGame()
	progress(1, TERMS.LoadingStage5 or "Ready.")
	local wait = MIN_SHOW - (os.clock() - shownAt)
	if wait > 0 then
		task.wait(wait)
	end
	-- Studio UI checks can hold the screen with the workspace attribute HoldLoadingScreen.
	while RunService:IsStudio() and workspace:GetAttribute("HoldLoadingScreen") do
		task.wait(0.2)
	end
	status.Text = TERMS.LoadingDone or "Starting..."
	local fade = TweenService:Create(loading, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 1 })
	fade.Completed:Connect(function()
		spin:Disconnect()
		loading:Destroy()
		loadingGone = true
	end)
	fade:Play()
end

----------------------------------------------------------------------
-- Reincarnation prologue
----------------------------------------------------------------------

local prologueOpen = false
local function showPrologue(regionName: string, tagline: string, template: string)
	if prologueOpen then
		return
	end
	prologueOpen = true
	local screen = new("CanvasGroup", { Name = "Prologue", Size = UDim2.fromScale(1, 1), BackgroundColor3 = OBSIDIAN, BackgroundTransparency = 0.08,
		GroupTransparency = 1, ZIndex = 5, Parent = gui })
	local card = new("Frame", { Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.66),
		BackgroundColor3 = JADE, Parent = screen })
	new("UICorner", { CornerRadius = radius(14), Parent = card })
	-- The trim sits on the card; all content lives in an inner frame inset well inside
	-- the trim, so padding never moves the ornament and text can never cross it.
	doubleFrame(card, 7)
	local content = new("Frame", { Name = "Content", Position = UDim2.fromOffset(22, 18), Size = UDim2.new(1, -44, 1, -36), BackgroundTransparency = 1, Parent = card })
	text({ Name = "Heading", Text = "◆  PROLOGUE  ◆", Font = TITLE_FONT, TextColor3 = GOLD, Size = UDim2.fromScale(1, 0.1), Parent = content }, 30)
	local body = string.gsub(string.gsub(template, "{region}", regionName), "{tagline}", tagline)
	local storyFrame = new("Frame", { Name = "StoryFrame", Position = UDim2.fromScale(0, 0.13), Size = UDim2.fromScale(1, 0.68),
		BackgroundTransparency = 1, ClipsDescendants = true, Parent = content })
	new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = storyFrame })
	local story = new("TextLabel", { Name = "Story", Text = body, RichText = true, Font = TITLE_FONT, TextColor3 = PARCHMENT,
		BackgroundTransparency = 1, TextScaled = true, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.fromScale(1, 1), MaxVisibleGraphemes = 0, Parent = storyFrame })
	new("UITextSizeConstraint", { MaxTextSize = 20, MinTextSize = 12, Parent = story })
	local function button(name: string, label: string, x: number, filled: boolean)
		local b = new("TextButton", { Name = name, Text = label, AutoButtonColor = true, Font = Enum.Font.GothamBold, TextScaled = true,
			TextColor3 = if filled then OBSIDIAN else PARCHMENT, BackgroundColor3 = if filled then GOLD else OBSIDIAN,
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(x, 1), Size = UDim2.fromScale(0.26, 0.12), Parent = content })
		new("UICorner", { CornerRadius = radius(8), Parent = b })
		new("UIStroke", { Color = GOLD, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
		new("UITextSizeConstraint", { MaxTextSize = 18, Parent = b })
		new("UIPadding", { PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.2, 0), Parent = b })
		return b
	end
	local skip = button("Skip", "Skip", 0.3, false)
	local continue = button("Continue", "Continue  →", 0.7, true)
	continue.Visible = false
	TweenService:Create(screen, TweenInfo.new(0.6), { GroupTransparency = 0 }):Play()

	local closed = false
	local function close()
		if closed then return end
		closed = true
		local fade = TweenService:Create(screen, TweenInfo.new(0.6), { GroupTransparency = 1 })
		fade.Completed:Connect(function()
			screen:Destroy()
			prologueOpen = false
		end)
		fade:Play()
	end
	local total = utf8.len(story.ContentText) or #story.ContentText
	local finished = false
	local function reveal()
		finished = true
		story.MaxVisibleGraphemes = -1
		continue.Visible = true
		skip.Text = "Close"
	end
	skip.Activated:Connect(function()
		if finished then close() else reveal() end
	end)
	continue.Activated:Connect(close)
	task.spawn(function()
		-- The story starts once the loading screen has faded away.
		while not loadingGone and not finished do
			task.wait(0.1)
		end
		local shown = 0
		while not finished and shown < total do
			shown += 2
			story.MaxVisibleGraphemes = shown
			task.wait(0.035)
		end
		if not finished then reveal() end
	end)
end

----------------------------------------------------------------------
-- Wiring
----------------------------------------------------------------------

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Content = require(Shared:WaitForChild("Content"))
local GamePack = require(Shared:WaitForChild("GamePack"))
local Regions = GamePack.IsEnabled("World") and Content.Get("WorldRegionsConfig") or nil
local Races = Content.Get("RacesConfig")
local Legacies = Content.Get("FamilyLegacyConfig")

----------------------------------------------------------------------
-- Life 1 creation: 3 free spins for bloodline and family legacy (CreationSystem)
----------------------------------------------------------------------

local creation = nil -- { Update = fn(snapshot), Spin = fn(result) } while open

-- The rarity name players see (a spin's Rarities[key].Name, e.g. "Epic" key -> "Rare").
local function rarityName(spin, rarity): string
	local info = spin and spin.Rarities and spin.Rarities[rarity]
	return (info and info.Name) or tostring(rarity)
end

local function rarityColor(spin, rarity): Color3
	local info = spin and spin.Rarities and spin.Rarities[rarity]
	return (info and info.Color) or PARCHMENT
end

local function showCreation(snapshot, onDone)
	local WheelSpinner = require(Shared:WaitForChild("WheelSpinner"))
	local remote = Remotes:WaitForChild("CreationAction")
	local screen = new("CanvasGroup", { Name = "Creation", Size = UDim2.fromScale(1, 1), BackgroundColor3 = OBSIDIAN, BackgroundTransparency = 0.04,
		GroupTransparency = 1, ZIndex = 6, Parent = gui })
	-- Sits a little low: the Life 1 guide banner (UIController/TutorialGuide) goes above it.
	-- Phones (Shared/Responsive): lower still, and the slot descriptions make way for
	-- full-size Spin buttons.
	local phone = require(Shared:WaitForChild("Responsive")).Current().Kind == "Phone"
	local card = new("Frame", { Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, if phone then 0.635 else 0.59), Size = UDim2.fromScale(if phone then 0.8 else 0.74, if phone then 0.71 else 0.76),
		BackgroundColor3 = JADE, Parent = screen })
	new("UICorner", { CornerRadius = radius(14), Parent = card })
	doubleFrame(card, 7)
	local content = new("Frame", { Name = "Content", Position = UDim2.fromOffset(22, 18), Size = UDim2.new(1, -44, 1, -36), BackgroundTransparency = 1, Parent = card })
	text({ Name = "Heading", Text = "◆  BEFORE YOUR FIRST BREATH  ◆", Font = TITLE_FONT, TextColor3 = GOLD, Size = UDim2.fromScale(1, 0.09), Parent = content }, 30)
	text({ Name = "Sub", Text = ("The Wheel grants a new soul three free spins. Roll the %s and the house you are born into."):format(string.lower(TERMS.RaceName)),
		TextColor3 = MUTED, Position = UDim2.fromScale(0, 0.1), Size = UDim2.fromScale(1, 0.06), Parent = content }, 16)

	local function slot(name: string, y: number, label: string)
		local frame = new("Frame", { Name = name, Position = UDim2.fromScale(0, y), Size = UDim2.fromScale(0.4, 0.3), BackgroundColor3 = OBSIDIAN, Parent = content })
		new("UICorner", { CornerRadius = radius(10), Parent = frame })
		local stroke = new("UIStroke", { Color = GOLD, Thickness = 1.5, Transparency = 0.3, Parent = frame })
		new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = frame })
		text({ Name = "Label", Text = label, Font = Enum.Font.GothamBold, TextColor3 = MUTED, Size = UDim2.fromScale(0.6, 0.18), TextXAlignment = Enum.TextXAlignment.Left, Parent = frame }, 13)
		local rarity = text({ Name = "Rarity", Text = "", Font = Enum.Font.GothamBold, Position = UDim2.fromScale(0.6, 0), Size = UDim2.fromScale(0.4, 0.18), TextXAlignment = Enum.TextXAlignment.Right, Parent = frame }, 13)
		local title = text({ Name = "Title", Text = "", Font = TITLE_FONT, Position = UDim2.fromScale(0, 0.2), Size = UDim2.fromScale(1, 0.26), TextXAlignment = Enum.TextXAlignment.Left, Parent = frame }, 26)
		local desc = text({ Name = "Desc", Text = "", TextColor3 = MUTED, Position = UDim2.fromScale(0, 0.48), Size = UDim2.fromScale(1, 0.24), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = frame }, 14)
		desc.Visible = not phone
		local button = new("TextButton", { Name = "Spin", Text = "Spin", Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = OBSIDIAN, BackgroundColor3 = GOLD,
			AutoButtonColor = true, Position = UDim2.fromScale(0, if phone then 0.48 else 0.76), Size = UDim2.fromScale(1, if phone then 0.52 else 0.24), Parent = frame })
		new("UICorner", { CornerRadius = radius(8), Parent = button })
		new("UITextSizeConstraint", { MaxTextSize = 16, Parent = button })
		new("UIPadding", { PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0), Parent = button })
		return { Frame = frame, Stroke = stroke, Rarity = rarity, Title = title, Desc = desc, Button = button }
	end
	local blood = slot("Bloodline", 0.19, string.upper(TERMS.RaceName))
	local legacy = slot("Legacy", 0.52, string.upper(TERMS.LegacyName or "Family Legacy"))
	local spinsLeft = text({ Name = "SpinsLeft", Text = "", Font = Enum.Font.GothamBold, TextColor3 = GOLD, Position = UDim2.fromScale(0, 0.84), Size = UDim2.fromScale(0.4, 0.05), Parent = content }, 16)

	local drumHolder = new("Frame", { Name = "DrumHolder", Position = UDim2.fromScale(0.44, 0.19), Size = UDim2.fromScale(0.56, 0.63), BackgroundTransparency = 1, Parent = content })
	local drum = WheelSpinner.new(drumHolder)
	local caption = text({ Name = "Caption", Text = "The Wheel awaits.", Font = Enum.Font.GothamBold, TextColor3 = GOLD, Position = UDim2.fromScale(0.44, 0.84), Size = UDim2.fromScale(0.56, 0.05), Parent = content }, 16)
	local begin = new("TextButton", { Name = "Begin", Text = "Begin Life  →", Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = OBSIDIAN, BackgroundColor3 = GOLD,
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(0.3, 0.085), Parent = content })
	new("UICorner", { CornerRadius = radius(8), Parent = begin })
	new("UIStroke", { Color = PARCHMENT, Thickness = 1, Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = begin })
	new("UITextSizeConstraint", { MaxTextSize = 18, Parent = begin })
	new("UIPadding", { PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.2, 0), Parent = begin })

	local function entries(kind: string, resultId: string?)
		local list = if kind == "Legacy" then Legacies.List else Races.List
		local spin = if kind == "Legacy" then Legacies.Spin else Races.Spin
		local out, target = {}, 1
		local random = Random.new()
		for i = 1, 24 do
			local item = list[random:NextInteger(1, #list)]
			if i == 18 and resultId then
				item = (if kind == "Legacy" then Legacies.ById[resultId] else Races.ById[resultId]) or item
				target = i
			end
			table.insert(out, { Name = item.Name, Rarity = item.Rarity, Color = rarityColor(spin, item.Rarity) })
		end
		return out, target
	end
	drum:Pose((entries("Bloodline")), 10.4)

	local spinning, latestSnapshot = false, snapshot
	local function refresh(s)
		latestSnapshot = s
		local left = (s.Creation and s.Creation.Spins) or 0
		local can = left > 0 and not spinning
		for _, b in { blood.Button, legacy.Button } do
			b.Active, b.AutoButtonColor = can, can
			b.BackgroundTransparency = if can then 0 else 0.6
			b.Text = if left > 0 then "Spin  (free)" else "No spins left"
		end
		spinsLeft.Text = ("◆ %d free spin%s left"):format(left, if left == 1 then "" else "s")
		if spinning then
			return -- the cards change only when the drum lands (no spoilers)
		end
		local race = Races.Get(s.RaceId)
		blood.Title.Text, blood.Desc.Text = race.Name, race.Passive or race.Description or ""
		blood.Rarity.Text, blood.Rarity.TextColor3 = string.upper(rarityName(Races.Spin, race.Rarity)), rarityColor(Races.Spin, race.Rarity)
		blood.Title.TextColor3, blood.Stroke.Color = rarityColor(Races.Spin, race.Rarity), rarityColor(Races.Spin, race.Rarity)
		local fam = Legacies.Get(s.Legacy)
		legacy.Title.Text, legacy.Desc.Text = fam.Name, fam.Description or ""
		legacy.Rarity.Text, legacy.Rarity.TextColor3 = string.upper(rarityName(Legacies.Spin, fam.Rarity)), rarityColor(Legacies.Spin, fam.Rarity)
		legacy.Title.TextColor3, legacy.Stroke.Color = rarityColor(Legacies.Spin, fam.Rarity), rarityColor(Legacies.Spin, fam.Rarity)
		local wheels = GamePack.CreationSpins()
		blood.Button.Visible = wheels.Bloodline
		legacy.Button.Visible = wheels.Legacy
	end
	refresh(snapshot)
	blood.Button.Activated:Connect(function()
		if not spinning and (latestSnapshot.Creation.Spins or 0) > 0 then remote:FireServer("Bloodline") end
	end)
	legacy.Button.Activated:Connect(function()
		if not spinning and (latestSnapshot.Creation.Spins or 0) > 0 then remote:FireServer("Legacy") end
	end)
	local closed = false
	begin.Activated:Connect(function()
		if closed or spinning then return end
		closed = true
		remote:FireServer("Done")
		creation = nil
		local fade = TweenService:Create(screen, TweenInfo.new(0.5), { GroupTransparency = 1 })
		fade.Completed:Connect(function()
			screen:Destroy()
			onDone()
		end)
		fade:Play()
	end)
	creation = {
		Update = refresh,
		Spin = function(result)
			local list, target = entries(result.Kind, result.Id)
			spinning = true
			refresh(latestSnapshot)
			caption.Text = ("Spinning a %s..."):format(if result.Kind == "Legacy" then string.lower(TERMS.LegacyName or "family legacy") else string.lower(TERMS.RaceName))
			drum:Spin(list, target, { Speed = result.Speed or 1, OnDone = function()
				spinning = false
				caption.Text = ("%s  ·  %s"):format(string.upper(result.Rarity or ""), result.Name or "")
				refresh(latestSnapshot)
			end })
		end,
	}
	while not loadingGone do
		task.wait(0.1)
	end
	TweenService:Create(screen, TweenInfo.new(0.6), { GroupTransparency = 0 }):Play()
end

Remotes:WaitForChild("SpinResult").OnClientEvent:Connect(function(result)
	if creation and type(result) == "table" and result.Creation then
		creation.Spin(result)
	end
end)

local function prologueFor(snapshot)
	if Regions then
		local world = snapshot.Modules and snapshot.Modules.World
		local region = Regions.Get(world and world.Region)
		showPrologue(region.Name, region.Tagline, Regions.Prologue)
	end
end

local function creationWheels()
	local ok, wheels = pcall(function()
		return require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GamePack")).CreationSpins()
	end)
	return if ok then wheels else { Any = false }
end

local lastLives = nil
local creationShown = false
local function onSnapshot(snapshot)
	if type(snapshot) ~= "table" then
		return
	end
	snapshotArrived = true
	if creation then
		creation.Update(snapshot)
	end
	local newLife = snapshot.Lives ~= lastLives
	lastLives = snapshot.Lives
	-- Studio UI checks can skip the creation wheel and prologue (workspace attribute SkipIntro).
	if RunService:IsStudio() and workspace:GetAttribute("SkipIntro") then
		return
	end
	if newLife and snapshot.Age == 0 and not snapshot.Dead then
		local c = snapshot.Creation
		-- The screen only exists when a bloodline or legacy wheel has entries to roll.
		if c and not c.Done and snapshot.Lives == 1 and not creationShown and creationWheels().Any then
			-- Pre-birth rolls first, then the prologue.
			creationShown = true
			task.spawn(showCreation, snapshot, function() prologueFor(snapshot) end)
		else
			prologueFor(snapshot)
		end
	end
end

Remotes:WaitForChild("StateUpdate").OnClientEvent:Connect(onSnapshot)
task.spawn(function()
	local ok, snapshot = pcall(function()
		return Remotes:WaitForChild("GetState"):InvokeServer()
	end)
	if ok then
		onSnapshot(snapshot)
	end
end)
task.spawn(finishLoading) -- runs the readiness stages from the first frame
-- Never trap the player: whatever happens, the screen lifts after MAX_WAIT seconds.
task.delay(MAX_WAIT, function()
	if not loadingGone and loading.Parent then
		spin:Disconnect()
		loading:Destroy()
		loadingGone = true
	end
end)
