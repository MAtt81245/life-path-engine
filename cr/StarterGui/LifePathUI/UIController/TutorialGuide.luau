--[[
	TutorialGuide: the Life 1 onboarding spotlight (server side: Modules/TutorialSystem).

	Four short banners, each shown once when its moment comes, with a pulsing ring on
	the element it talks about:
		1 Creation    the pre-birth wheel (IntroAndLoadingUI) is open
		2 Actions     first turn: the action pips
		3 Advance     out of actions: the Advance Year medallion
		4 SpiritRoot  the energy bar wakes (cultivation packs only): train + breakthrough
	"Got it" (or doing the thing) moves on; "Skip tutorial" ends it for good. Progress is
	saved on the server (TutorialStep / TutorialCompleted), so veterans and Life 2+
	never see it. Texts use the pack's Terms.

	Init(ctx, refs), Render(snapshot).
]]

local GuiService = game:GetService("GuiService")
local Responsive = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Responsive"))
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Guide = {}

Guide.MaxAge = 12 -- older Life 1 saves (before the guide existed) are left alone

local ctx, S, C, T, remote, refs
local ui = {}
local state = nil
local acked = 0 -- furthest step acknowledged locally (ahead of the server push)
local skipped = false
local current = nil -- { Index, Targets, Since }

local function scale(x, y) return UDim2.fromScale(x, y) end

local function intro(): ScreenGui?
	return ctx.Gui.Parent:FindFirstChild("IntroAndLoadingUI") :: ScreenGui?
end

-- The intro (loading, creation, prologue) is on screen. Its screens are destroyed when
-- they close, so one that exists counts even while it fades in or out (counting only
-- opaque ones let step 2 slip in between the loading screen and the creation wheel).
local function introBusy(except: string?): boolean
	local gui = intro()
	for _, child in if gui then gui:GetChildren() else {} do
		if child:IsA("GuiObject") and child.Visible and child.Name ~= except then
			return true
		end
	end
	return false
end

-- The creation wheel is actually showing: built, faded in, and the loading screen gone
-- (it is created invisible while the loading screen still covers everything).
local function creationOnScreen(): boolean
	local gui = intro()
	local creation = gui and gui:FindFirstChild("Creation")
	if not creation or gui:FindFirstChild("Loading") then
		return false
	end
	return not (creation:IsA("CanvasGroup") and creation.GroupTransparency > 0.5)
end

local function findText(root: Instance?, needle: string): GuiObject?
	for _, d in if root then root:GetDescendants() else {} do
		if d:IsA("TextLabel") and string.find(d.Text, needle, 1, true) then
			return d.Parent :: GuiObject
		end
	end
	return nil
end

local function awakened(s): boolean
	local gates = ctx.Config.Gates
	return (s.Flags and s.Flags[gates.StripFlag or ""]) or s.Age >= (gates.StripAge or 0)
end

-- Steps: When(s) -> show now; Done(s, since) -> the player already did it.
local STEPS = {
	{
		Id = "Creation", Text = function() return T.CreationTutorial end,
		When = function(s) return ctx.GamePack.IsEnabled("Lineages") and s.Age == 0 and s.Creation ~= nil and not s.Creation.Done and creationOnScreen() end,
		Done = function(s) return s.Creation == nil or s.Creation.Done == true end,
		Targets = function() return {} end,
	},
	{
		Id = "Actions",
		Text = function() return ("You have limited %s each year (%s). Spend them on Childhood Actions to grow your stats."):format(T.ActionsName, T.ActionPip .. " " .. T.ActionPip) end,
		When = function(s) return s.Actions > 0 and not introBusy() end,
		Done = function(s, since) return s.Actions < since.Actions or s.Age > since.Age end,
		Targets = function() return { refs.Sheet:FindFirstChild("ActionGems") } end,
	},
	{
		Id = "Advance", Text = function() return "Out of actions! Click Advance Year to grow older and face life events." end,
		When = function(s) return s.Actions == 0 and not introBusy() end,
		Done = function(s, since) return s.Age > since.Age end,
		Targets = function() return { refs.Sheet:FindFirstChild("AdvanceButton") } end,
	},
	{
		Id = "SpiritRoot", Text = function() return T.SpiritRootTutorial end,
		When = function(s) return ctx.GamePack.IsEnabled("Cultivation") and awakened(s) and not introBusy() end,
		Done = function() return false end,
		Targets = function()
			local training = refs.Pages:FindFirstChild("TrainingPage", true) -- may sit in its scroller
			return { findText(training, "Meditat"), refs.Strip:FindFirstChild("BreakthroughButton") }
		end,
	},
}

local function lastStep(): number
	return if ctx.GamePack.IsEnabled("Cultivation") then 4 else 3
end

local function ack(index: number)
	if index > acked then
		acked = index
		remote:FireServer("Step", index)
	end
	current = nil
	ui.Banner.Visible = false
end

local function active(s): boolean
	if ctx.IsShopOpen and ctx.IsShopOpen() then
		return false -- out of the way while the Treasury is open
	end
	return s ~= nil and not skipped and not s.TutorialCompleted and s.Lives == 1 and not s.Dead and s.Age <= Guide.MaxAge
		and acked < lastStep()
end

local function show(index: number, s)
	local step = STEPS[index]
	current = { Index = index, Since = { Actions = s.Actions, Age = s.Age } }
	ui.Counter.Text = ("GUIDE  %d / %d"):format(index, lastStep())
	-- The creation card fills the middle: its banner sits above it, the rest below.
	-- Phones get a taller, wider banner so the text stays readable and "Got it" is a
	-- full touch target (Shared/Responsive).
	local phone = Responsive.Current().Kind == "Phone"
	if index == 1 then
		ui.Banner.AnchorPoint = Vector2.new(0.5, 0)
		ui.Banner.Position = UDim2.new(0.5, 0, 0, GuiService:GetGuiInset().Y + 4)
		ui.Banner.Size = if phone then scale(0.66, 0.135) else scale(0.56, 0.1)
	else
		ui.Banner.AnchorPoint, ui.Banner.Position = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, if phone then -8 else -54) -- above the toast
		ui.Banner.Size = if phone then scale(0.66, 0.26) else scale(0.5, 0.13)
	end
	ui.TextSize.MinTextSize = if phone then Responsive.MinReadableText + 1 else 7
	-- Phones: "Got it" and "Skip" side by side, each a full-height touch target.
	ui.Text.Size = if phone then scale(0.52, 0.7) else scale(0.72, 0.7)
	ui.GotIt.Position, ui.GotIt.Size = if phone then scale(0.55, 0.12) else scale(0.75, 0.08), if phone then scale(0.21, 0.76) else scale(0.25, 0.48)
	ui.Skip.Position, ui.Skip.Size = if phone then scale(0.78, 0.12) else scale(0.75, 0.62), if phone then scale(0.22, 0.76) else scale(0.25, 0.32)
	ui.Text.Text = step.Text()
	ui.Banner.Visible = true
	ui.Pop.Scale = 0.9
	TweenService:Create(ui.Pop, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function evaluate()
	local s = state
	if not active(s) then
		ui.Banner.Visible = false
		if not (ctx.IsShopOpen and ctx.IsShopOpen()) then
			current = nil
		end
		return
	end
	acked = math.max(acked, s.TutorialStep or 0)
	if refs.Modal and refs.Modal.Visible then
		ui.Banner.Visible = false -- a life event has the stage; come back after it
		return
	end
	if current then
		local step = STEPS[current.Index]
		if step.Done(s, current.Since) then
			ack(current.Index)
		elseif current.Index > 1 and introBusy() then
			ui.Banner.Visible = false -- wait under the intro, then come back
			return
		else
			ui.Banner.Visible = true
			return
		end
	end
	for index = acked + 1, lastStep() do
		if STEPS[index].When(s) then
			show(index, s)
			return
		end
	end
end

-- Rings follow their targets every frame (layouts and tweens move them).
local function track()
	local targets = if current and ui.Banner.Visible then STEPS[current.Index].Targets() else {}
	local inset = GuiService:GetGuiInset()
	for i, ring in ui.Rings do
		local target = targets[i]
		local visible = target ~= nil and target.Parent ~= nil and target.Visible and target.AbsoluteSize.X > 0
		ring.Visible = visible
		if visible then
			local screen = target:FindFirstAncestorWhichIsA("ScreenGui")
			local offset = if screen and screen.IgnoreGuiInset then Vector2.zero else inset
			ring.Position = UDim2.fromOffset(target.AbsolutePosition.X + offset.X - 6, target.AbsolutePosition.Y + offset.Y - 6)
			ring.Size = UDim2.fromOffset(target.AbsoluteSize.X + 12, target.AbsoluteSize.Y + 12)
		end
	end
end

function Guide.Init(context, references)
	ctx, refs = context, references
	S = ctx.Style
	C, T = S.C, S.Terms
	remote = ctx.Remotes:WaitForChild("TutorialAction")
	local screen = S.new("ScreenGui", { Name = "TutorialUI", ResetOnSpawn = false, DisplayOrder = 110, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	-- Rings follow targets in screen pixels; the banner sizes itself per profile below.
	screen:SetAttribute("NoAutoScale", true)
	screen.Parent = ctx.Gui.Parent
	ui.Rings = {}
	for i = 1, 2 do
		local ring = S.new("Frame", { Name = "Spotlight" .. i, BackgroundTransparency = 1, Visible = false, Parent = screen })
		S.new("UICorner", { CornerRadius = UDim.new(0, S.radius(12)), Parent = ring })
		local stroke = S.new("UIStroke", { Color = C.gold, Thickness = 4, Transparency = 0, Parent = ring })
		TweenService:Create(stroke, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.75, Thickness = 2 }):Play()
		ui.Rings[i] = ring
	end

	local banner = S.new("Frame", { Name = "Banner", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -54), Size = scale(0.5, 0.13),
		Visible = false, Parent = screen })
	S.padding(banner, 16, 10)
	ctx.Theme.frame(banner, 14, C.panel1, C.bg2)
	local stroke = banner:FindFirstChildOfClass("UIStroke")
	stroke.Color, stroke.Thickness = C.gold, 2
	S.new("UISizeConstraint", { MinSize = Vector2.new(360, 54), Parent = banner })
	ui.Pop = S.new("UIScale", { Parent = banner })
	ui.Counter = S.label({ Name = "Counter", Text = "", Font = S.Fonts.Heavy, TextColor3 = C.gold, Size = scale(0.5, 0.26), Parent = banner }, 12)
	ui.Text = S.label({ Name = "Text", Text = "", TextColor3 = C.text, Font = S.Fonts.Bold, TextYAlignment = Enum.TextYAlignment.Top,
		Position = scale(0, 0.3), Size = scale(0.72, 0.7), Parent = banner }, 16)
	ui.TextSize = ui.Text:FindFirstChildOfClass("UITextSizeConstraint")
	local gotIt = S.button({ Name = "GotIt", Text = "Got it", Font = S.Fonts.Heavy, Position = scale(0.75, 0.08), Size = scale(0.25, 0.48), Parent = banner }, nil, nil, 15)
	ui.GotIt = gotIt
	gotIt.Activated:Connect(function()
		if current then
			ack(current.Index)
		end
	end)
	local skip = S.label({ Name = "Skip", Text = "Skip tutorial", TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Center,
		Position = scale(0.75, 0.62), Size = scale(0.25, 0.32), Parent = banner }, 12)
	local skipButton = S.new("TextButton", { Name = "SkipButton", Text = "", BackgroundTransparency = 1, Size = scale(1, 1), Parent = skip })
	ui.Skip = skip
	skipButton.Activated:Connect(function()
		skipped = true
		remote:FireServer("Skip")
		current = nil
		banner.Visible = false
	end)
	ui.Banner = banner

	RunService.RenderStepped:Connect(track)
	task.spawn(function()
		while screen.Parent do
			task.wait(0.5)
			evaluate() -- the intro closing is not a snapshot
		end
	end)
end

function Guide.Render(s)
	state = s
	evaluate()
end

return Guide
