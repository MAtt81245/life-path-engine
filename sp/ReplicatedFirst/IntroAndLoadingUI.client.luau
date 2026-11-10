--[[
	IntroAndLoadingUI: the cinematic loading screen (theme palette, an emblem seal with
	counter-rotating accent rings, DisplayOrder 100) replaces Roblox's
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
local GREEN = Color3.fromRGB(70, 190, 115) -- Robux reroll
local VIOLET = Color3.fromRGB(150, 96, 230) -- meta-currency reroll
local TITLE_FONT = Enum.Font.GothamBlack
local MONO_FONT = Enum.Font.RobotoMono
local CORNER = 1 -- theme corner multiplier
local MODERN = false -- any theme Style: crisp 1 px frames instead of double trims
local STYLE = nil
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
		GREEN, VIOLET = p.green or GREEN, p.violet or VIOLET
		TERMS = theme.Terms
		TITLE_FONT, MONO_FONT = packTheme.Font("Title"), packTheme.Font("Mono")
		CORNER = theme.Corner or 1
		MODERN = theme.Style ~= nil
		STYLE = theme.Style
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

-- Full-screen click blocker (Active + Modal): nothing behind an intro screen can be
-- clicked through it (same rule as Shared/ModalShield for the HUD popups).
local function shield(screen)
	new("TextButton", { Name = "ClickShield", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Active = true, Modal = true,
		Selectable = false, Size = UDim2.fromScale(1, 1), ZIndex = 0, Parent = screen })
end

----------------------------------------------------------------------
-- Loading screen
----------------------------------------------------------------------

local loading = new("CanvasGroup", { Name = "Loading", Size = UDim2.fromScale(1, 1), BackgroundColor3 = OBSIDIAN, ZIndex = 10, Parent = gui })
shield(loading)
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)), Parent = loading })
local border = new("Frame", { Name = "Border", Position = UDim2.fromScale(0.03, 0.04), Size = UDim2.fromScale(0.94, 0.92), BackgroundTransparency = 1, Parent = loading })
doubleFrame(border, 8)
-- Emblem seal (Terms.LoadingEmblem): an outer ring with tick marks (secondary accent) and an inner ring (primary accent)
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
if STYLE == "SoulPass" then
	-- Geometric spirit cross behind the emblem.
	for i, rotation in { 45, -45 } do
		new("Frame", { Name = "Cross" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Rotation = rotation,
			Size = UDim2.fromScale(0.9, 0.07), BackgroundColor3 = GOLD, BackgroundTransparency = 0.25, BorderSizePixel = 0, Parent = core })
	end
end
text({ Name = "Eye", Text = TERMS.LoadingEmblem or "👁", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.72, 0.72), Font = Enum.Font.GothamBold, ZIndex = 2, Parent = core }, 120)
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
barBack:SetAttribute("NoJuice", true) -- tweened here; StarterPlayerScripts/UIJuiceAnimator stays off it
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
	shield(screen)
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

local Talents = Content.Get("TalentsConfig")
local Monetization = Content.Get("MonetizationConfig")

-- The three birth cards: what they roll, what they show.
local CARDS = {
	Bloodline = { Config = Races, Label = function() return string.upper(TERMS.RaceName or "Bloodline") end,
		Current = function(s) return Races.Get(s.RaceId) end,
		Buffs = function(e) return e.Passive or e.Description or "" end,
		Signature = function(e) return e.Signature or (e.Passive and string.match(e.Passive, "^([^:]+):")) end },
	Legacy = { Config = Legacies, Label = function() return string.upper(TERMS.LegacyName or "Family Legacy") end,
		Current = function(s) return Legacies.Get(s.Legacy) end,
		Buffs = function(e) return e.Description or "" end,
		Signature = function(e) return e.Signature end },
	Talent = { Config = Talents, Label = function() return string.upper(TERMS.TalentName or "Innate Talent") end,
		Current = function(s) return s.Creation and s.Creation.Talent and Talents.Get(s.Creation.Talent) end,
		Buffs = function(e) return e.Description or "" end,
		Signature = function(e) return e.Signature end },
}
local CARD_ORDER = { "Bloodline", "Legacy", "Talent" }

-- Paid random items (the Robux reroll) follow PolicyService; unknown on a live server = hidden.
local function paidRandomAllowed(): boolean
	local ok, info = pcall(function()
		return game:GetService("PolicyService"):GetPolicyInfoForPlayerAsync(player)
	end)
	if ok and type(info) == "table" then
		return info.ArePaidRandomItemsRestricted ~= true
	end
	return RunService:IsStudio()
end

-- Wrapped text of a fixed size that grows downward (never clipped).
local function autoText(props, size: number)
	props.BackgroundTransparency = 1
	props.TextScaled = false
	props.TextWrapped = true
	props.TextSize = size
	props.TextColor3 = props.TextColor3 or PARCHMENT
	props.Font = props.Font or Enum.Font.GothamMedium
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextYAlignment = Enum.TextYAlignment.Top
	props.AutomaticSize = Enum.AutomaticSize.Y
	props.Size = props.Size or UDim2.fromScale(1, 0)
	return new("TextLabel", props)
end

local function pill(name: string, label: string, color: Color3, textColor: Color3, props)
	local b = new("TextButton", { Name = name, Text = label, AutoButtonColor = true, Font = Enum.Font.GothamBlack, TextScaled = true,
		TextColor3 = textColor, BackgroundColor3 = color, Position = props.Position, Size = props.Size, AnchorPoint = props.AnchorPoint or Vector2.zero,
		Parent = props.Parent })
	new("UICorner", { CornerRadius = radius(8), Parent = b })
	new("UIStroke", { Color = PARCHMENT, Thickness = 1, Transparency = 0.55, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
	new("UITextSizeConstraint", { MaxTextSize = props.MaxText or 16, Parent = b })
	new("UIPadding", { PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = b })
	return b
end

local function setEnabled(button: TextButton, on: boolean)
	button.Active, button.AutoButtonColor = on, on
	button.BackgroundTransparency = if on then 0 else 0.55
	button.TextTransparency = if on then 0 else 0.35
end

local function percent(weight: number, total: number): string
	local p = weight / math.max(total, 1e-9) * 100
	return if p < 1 then ("%.1f%%"):format(p) else ("%g%%"):format(math.floor(p * 10 + 0.5) / 10)
end

local function showCreation(snapshot, onDone)
	local remote = Remotes:WaitForChild("CreationAction")
	local wheels = GamePack.CreationSpins()
	local metaCost = Monetization.BirthRerollMetaCost or 30
	local screen = new("CanvasGroup", { Name = "Creation", Size = UDim2.fromScale(1, 1), BackgroundColor3 = OBSIDIAN, BackgroundTransparency = 0.3,
		GroupTransparency = 1, ZIndex = 6, Parent = gui })
	shield(screen)
	-- Sits a little low: the Life 1 guide banner (UIController/TutorialGuide) goes above it.
	local phone = require(Shared:WaitForChild("Responsive")).Current().Kind == "Phone"
	local card = new("Frame", { Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, if phone then 0.62 else 0.6), Size = UDim2.fromScale(if phone then 0.96 else 0.86, if phone then 0.72 else 0.74),
		BackgroundColor3 = JADE, BackgroundTransparency = 0.12, Parent = screen })
	new("UICorner", { CornerRadius = radius(14), Parent = card })
	doubleFrame(card, 7)
	local content = new("Frame", { Name = "Content", Position = UDim2.fromOffset(20, 16), Size = UDim2.new(1, -40, 1, -32), BackgroundTransparency = 1, Parent = card })

	-- Top bar: heading, Robux reroll (green), meta-currency reroll (violet).
	text({ Name = "Heading", Text = "◆  BEFORE YOUR FIRST BREATH", Font = TITLE_FONT, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(0.5, 0.08), Parent = content }, 28)
	local robuxOffer = Monetization.ProductsById.BirthReroll
	local robux = pill("RerollRobux", ("REROLL (%d R$)"):format(robuxOffer and robuxOffer.Robux or 199), GREEN, OBSIDIAN,
		{ Position = UDim2.fromScale(0.535, 0), Size = UDim2.fromScale(0.225, 0.08), Parent = content, MaxText = 15 })
	robux.Visible = false
	task.spawn(function()
		robux.Visible = robuxOffer ~= nil and paidRandomAllowed()
	end)
	local meta = pill("RerollMeta", ("◆ REROLL (%d %s)"):format(metaCost, TERMS.MetaCurrency or "Karma"), VIOLET, PARCHMENT,
		{ Position = UDim2.fromScale(0.775, 0), Size = UDim2.fromScale(0.225, 0.08), Parent = content, MaxText = 15 })

	-- Quick Start: born now with what is rolled (free spins left roll instantly).
	local quick = pill("QuickStart", "⚡  QUICK START — BE BORN NOW", GOLD, OBSIDIAN,
		{ Position = UDim2.fromScale(0, 0.105), Size = UDim2.fromScale(1, 0.095), Parent = content, MaxText = 20 })
	new("UIGradient", { Rotation = 0, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 225, 160)), Parent = quick })

	-- Left: Your Trait Buffs (grows with its lines and scrolls).
	local buffsBox = new("ScrollingFrame", { Name = "TraitBuffs", Position = UDim2.fromScale(0, 0.225), Size = UDim2.fromScale(0.2, 0.62),
		BackgroundColor3 = OBSIDIAN, BackgroundTransparency = 0.25, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = GOLD,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = content })
	new("UICorner", { CornerRadius = radius(10), Parent = buffsBox })
	new("UIStroke", { Color = GOLD, Thickness = 1, Transparency = 0.5, Parent = buffsBox })
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = buffsBox })
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = buffsBox })
	autoText({ Name = "Header", Text = "YOUR TRAIT BUFFS", Font = Enum.Font.GothamBlack, TextColor3 = GOLD, LayoutOrder = 0, Parent = buffsBox }, 13)

	-- Center: the three trait cards.
	local holder = new("Frame", { Name = "Cards", Position = UDim2.fromScale(0.215, 0.225), Size = UDim2.fromScale(0.555, 0.62), BackgroundTransparency = 1, Parent = content })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0.02, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
	local cards = {}
	for i, kind in CARD_ORDER do
		local def = CARDS[kind]
		local frame = new("Frame", { Name = kind, LayoutOrder = i, Size = UDim2.fromScale(0.32, 1), BackgroundColor3 = OBSIDIAN, BackgroundTransparency = 0.3, Parent = holder })
		new("UICorner", { CornerRadius = radius(12), Parent = frame })
		local stroke = new("UIStroke", { Color = GOLD, Thickness = 1.5, Transparency = 0.2, Parent = frame })
		local pop = new("UIScale", { Parent = frame })
		text({ Name = "Kind", Text = def.Label(), Font = Enum.Font.GothamBold, TextColor3 = MUTED, Position = UDim2.fromScale(0, 0.03), Size = UDim2.fromScale(1, 0.06), Parent = frame }, 12)
		local gem = new("Frame", { Name = "Gem", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.19), Size = UDim2.fromScale(0.17, 0.17),
			Rotation = 45, BackgroundColor3 = GOLD, BorderSizePixel = 0, Parent = frame })
		new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = gem })
		new("UICorner", { CornerRadius = UDim.new(0.12, 0), Parent = gem })
		new("UIStroke", { Color = PARCHMENT, Thickness = 1.5, Transparency = 0.35, Parent = gem })
		new("Frame", { Name = "Facet", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.38, 0.38), Size = UDim2.fromScale(0.35, 0.35),
			BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55, BorderSizePixel = 0, Parent = gem })
		local rarity = text({ Name = "Rarity", Text = "", Font = Enum.Font.GothamBlack, Position = UDim2.fromScale(0, 0.3), Size = UDim2.fromScale(1, 0.06), Parent = frame }, 13)
		local title = text({ Name = "Title", Text = "", Font = TITLE_FONT, Position = UDim2.fromScale(0.05, 0.37), Size = UDim2.fromScale(0.9, 0.12), Parent = frame }, 24)
		local body = new("ScrollingFrame", { Name = "BuffsScroll", Position = UDim2.fromScale(0.06, 0.51), Size = UDim2.fromScale(0.88, 0.25), BackgroundTransparency = 1,
			BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = GOLD, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = frame })
		local buffs = autoText({ Name = "Buffs", Text = "", TextColor3 = PARCHMENT, TextXAlignment = Enum.TextXAlignment.Center, Parent = body }, if phone then 12 else 14)
		local signature = text({ Name = "Signature", Text = "", Font = Enum.Font.GothamBold, TextColor3 = GOLD, Position = UDim2.fromScale(0.05, 0.77), Size = UDim2.fromScale(0.9, 0.07), Parent = frame }, 13)
		local spin = pill("Spin", "Spin  (free)", GOLD, OBSIDIAN, { Position = UDim2.fromScale(0.08, 0.86), Size = UDim2.fromScale(0.84, 0.11), Parent = frame, MaxText = 15 })
		spin.Activated:Connect(function()
			if spin.Active then
				remote:FireServer(kind)
			end
		end)
		cards[kind] = { Frame = frame, Stroke = stroke, Pop = pop, Gem = gem, Rarity = rarity, Title = title, Buffs = buffs, Signature = signature, Spin = spin }
	end

	-- Right: the Blood Ladder (odds of the main wheel, names per tier, your roll in gold).
	local ladderKind = if wheels.Bloodline then "Bloodline" else "Legacy"
	local ladderConfig = CARDS[ladderKind].Config
	local ladder = new("ScrollingFrame", { Name = "BloodLadder", Position = UDim2.fromScale(0.785, 0.225), Size = UDim2.fromScale(0.215, 0.62),
		BackgroundColor3 = OBSIDIAN, BackgroundTransparency = 0.25, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = GOLD,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = content })
	new("UICorner", { CornerRadius = radius(10), Parent = ladder })
	new("UIStroke", { Color = GOLD, Thickness = 1, Transparency = 0.5, Parent = ladder })
	new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = ladder })
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = ladder })
	autoText({ Name = "Header", Text = string.upper(TERMS.LadderTitle or "Blood Ladder"), Font = Enum.Font.GothamBlack, TextColor3 = GOLD, LayoutOrder = 0, Parent = ladder }, 13)
	local ladderRows = {}
	do
		local spinConfig = ladderConfig.Spin
		local order = spinConfig.RarityOrder or {}
		local total = 0
		for _, key in order do
			total += spinConfig.Rarities[key].Weight
		end
		for i = #order, 1, -1 do
			local key = order[i]
			local info = spinConfig.Rarities[key]
			local names = {}
			for _, entry in ladderConfig.List do
				if entry.Rarity == key then
					table.insert(names, entry.Name)
				end
			end
			local row = new("Frame", { Name = key, LayoutOrder = #order - i + 1, Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = GOLD, BackgroundTransparency = 1, Parent = ladder })
			new("UICorner", { CornerRadius = radius(6), Parent = row })
			local rowStroke = new("UIStroke", { Color = GOLD, Thickness = 1.5, Transparency = 1, Parent = row })
			new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = row })
			new("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
			local head = autoText({ Name = "Odds", Text = ("%s  %s"):format(string.upper(info.Name or key), percent(info.Weight, total)), Font = Enum.Font.GothamBlack,
				TextColor3 = info.Color or PARCHMENT, LayoutOrder = 1, Parent = row }, 12)
			autoText({ Name = "Names", Text = if #names > 0 then table.concat(names, " · ") else "—", TextColor3 = MUTED, LayoutOrder = 2, Parent = row }, 11)
			ladderRows[key] = { Row = row, Stroke = rowStroke, Head = head, Base = head.Text }
		end
	end

	-- Bottom: free spins left and Begin Life.
	local spinsLeft = text({ Name = "SpinsLeft", Text = "", Font = Enum.Font.GothamBold, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromScale(0, 0.885), Size = UDim2.fromScale(0.5, 0.06), Parent = content }, 16)
	local caption = text({ Name = "Caption", Text = "Fate deals three cards.", Font = Enum.Font.GothamBold, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromScale(0, 0.945), Size = UDim2.fromScale(0.5, 0.05), Parent = content }, 13)
	local begin = pill("Begin", "Begin Life  →", GOLD, OBSIDIAN, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.fromScale(0.26, 0.095), Parent = content, MaxText = 18 })

	local spinning = {} -- [kind] = true while that card shuffles
	local latestSnapshot = snapshot
	local buffsKey = nil

	local function fillCard(kind: string, entry)
		local ui, def = cards[kind], CARDS[kind]
		local color = rarityColor(def.Config.Spin, entry and entry.Rarity)
		ui.Title.Text = if entry then entry.Name else "—"
		ui.Title.TextColor3, ui.Stroke.Color, ui.Gem.BackgroundColor3 = color, color, color
		ui.Rarity.Text = if entry then "◆ " .. string.upper(rarityName(def.Config.Spin, entry.Rarity)) .. " ◆" else "NOT ROLLED"
		ui.Rarity.TextColor3 = color
		ui.Buffs.Text = if entry then def.Buffs(entry) else "Spin to draw this card."
		local signature = entry and def.Signature(entry)
		ui.Signature.Text = if signature then "◆ Signature: " .. signature else ""
	end

	local function refresh(s)
		latestSnapshot = s
		local left = (s.Creation and s.Creation.Spins) or 0
		local busy = next(spinning) ~= nil
		for _, kind in CARD_ORDER do
			local ui = cards[kind]
			ui.Frame.Visible = wheels[kind] == true
			setEnabled(ui.Spin, left > 0 and not busy)
			ui.Spin.Text = if left > 0 then "Spin  (free)" else "No free spins"
			if not spinning[kind] then
				fillCard(kind, CARDS[kind].Current(s))
			end
		end
		spinsLeft.Text = ("◆ %d free spin%s left"):format(left, if left == 1 then "" else "s")
		setEnabled(meta, not busy and (s.Karma or 0) >= metaCost)
		setEnabled(robux, not busy)
		setEnabled(quick, not busy)
		setEnabled(begin, not busy)
		if busy then
			return
		end
		-- Your Trait Buffs: one line per card, rebuilt only when the cards change.
		local lines, key = {}, ""
		for _, kind in CARD_ORDER do
			local entry = wheels[kind] and CARDS[kind].Current(s)
			if entry then
				key ..= entry.Id .. "|"
				table.insert(lines, { Name = entry.Name, Text = CARDS[kind].Buffs(entry), Color = rarityColor(CARDS[kind].Config.Spin, entry.Rarity) })
			end
		end
		if key ~= buffsKey then
			buffsKey = key
			for _, child in buffsBox:GetChildren() do
				if child:IsA("TextLabel") and child.Name == "Line" then
					child:Destroy()
				end
			end
			for i, line in lines do
				autoText({ Name = "Line", RichText = true, LayoutOrder = i,
					Text = ('<font color="#%s"><b>%s</b></font>\n%s'):format(line.Color:ToHex(), line.Name, line.Text), Parent = buffsBox }, 12)
			end
		end
		-- The ladder lights your current tier in gold.
		local current = CARDS[ladderKind].Current(s)
		for rarityKey, row in ladderRows do
			local mine = current ~= nil and current.Rarity == rarityKey
			row.Row.BackgroundTransparency = if mine then 0.78 else 1
			row.Stroke.Transparency = if mine then 0 else 1
			row.Head.Text = if mine then row.Base .. "  ◀ YOU" else row.Base
		end
	end
	refresh(snapshot)

	-- A card shuffles through its deck and lands on the server's result.
	local function shuffle(result, speed: number?)
		local kind = result.Kind
		local ui, def = cards[kind], CARDS[kind]
		if not ui then
			return
		end
		spinning[kind] = true
		refresh(latestSnapshot)
		local list = def.Config.List
		local started, step = os.clock(), 0.04
		local duration = 1.3 / math.max(0.25, speed or 1)
		while os.clock() - started < duration and screen.Parent do
			local entry = list[math.random(1, #list)]
			local color = rarityColor(def.Config.Spin, entry.Rarity)
			ui.Title.Text, ui.Title.TextColor3, ui.Gem.BackgroundColor3 = entry.Name, color, color
			step = math.min(0.16, step * 1.1)
			task.wait(step)
		end
		spinning[kind] = nil
		fillCard(kind, def.Config.Get(result.Id))
		ui.Pop.Scale = 1.08
		TweenService:Create(ui.Pop, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		caption.Text = ("%s  ·  %s"):format(string.upper(rarityName(def.Config.Spin, result.Rarity)), result.Name or "")
		refresh(latestSnapshot)
	end

	robux.Activated:Connect(function()
		if robux.Active then
			local shop = Remotes:FindFirstChild("ShopAction")
			if shop then
				shop:FireServer("BuyProduct", "BirthReroll", RunService:IsStudio()) -- Studio: free test purchase
			end
		end
	end)
	meta.Activated:Connect(function()
		if meta.Active then
			remote:FireServer("RerollMeta")
		end
	end)

	local closed = false
	local function close(quickStart: boolean)
		if closed or next(spinning) then
			return
		end
		closed = true
		remote:FireServer(if quickStart then "Quick" else "Done")
		creation = nil
		local fade = TweenService:Create(screen, TweenInfo.new(if quickStart then 0.3 else 0.5), { GroupTransparency = 1 })
		fade.Completed:Connect(function()
			screen:Destroy()
			onDone(quickStart)
		end)
		fade:Play()
	end
	begin.Activated:Connect(function()
		close(false)
	end)
	quick.Activated:Connect(function()
		close(true)
	end)
	creation = {
		Update = refresh,
		Spin = function(result)
			if result.Kind == "Reroll" then
				caption.Text = "Fate reshuffles every card..."
				for _, one in result.Results or {} do
					task.spawn(shuffle, one, result.Speed)
				end
			else
				task.spawn(shuffle, result, result.Speed)
			end
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
			task.spawn(showCreation, snapshot, function(quick)
				if not quick then
					prologueFor(snapshot) -- Quick Start is born straight away
				end
			end)
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
