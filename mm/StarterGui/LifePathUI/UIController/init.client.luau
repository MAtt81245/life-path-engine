--[[
	UIController: renders server snapshots and forwards player intentions.
	All game logic is validated on the server (GameManager / AgingSystem).
	Each tab is a child ModuleScript exposing Init(ctx, pageFrame) and Render(state).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Content = require(Shared:WaitForChild("Content"))
local UITheme = require(Shared:WaitForChild("UITheme"))
local S = require(Shared:WaitForChild("UIStyle"))
local Requirements = require(Shared:WaitForChild("Requirements"))
local GamePack = require(Shared:WaitForChild("GamePack"))
local ModalShield = require(Shared:WaitForChild("ModalShield"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local C = S.C
local T = S.Terms -- pack vocabulary (Configs/UIThemeConfig.Terms); never hardcode genre words

local Config = {
	Stats = Content.Get("PlayerStatsConfig"),
	Training = Content.Get("TrainingConfig"),
	Masters = Content.Get("MastersConfig"),
	Masteries = Content.Get("MasteriesConfig"),
	Titles = Content.Get("TitlesConfig"),
	Studies = Content.Get("StudiesAndCareerConfig"),
	Relationships = Content.Get("RelationshipsConfig"),
	Races = Content.Get("RacesConfig"),
	Talents = Content.Get("TalentsConfig"),
	Upgrades = Content.Get("SamsaraUpgradesConfig"),
	RebirthPaths = Content.Get("RebirthPathsConfig"),
	Monetization = Content.Get("MonetizationConfig"),
	Legacies = Content.Get("FamilyLegacyConfig"),
	Genetics = Content.Get("GeneticsConfig"),
	Regions = Content.Get("WorldRegionsConfig"),
	Gates = Content.Get("ProgressionGatesConfig"),
	FamilyTree = Content.Get("FamilyTreeConfig"),
	Items = Content.Get("ItemsConfig"),
	Realms = Content.Get("RealmsConfig"),
}

local gui = script.Parent
local sheet = gui:WaitForChild("Sheet")
local main = gui:WaitForChild("Main")
local modal = gui:WaitForChild("EventModal")
local toast = gui:WaitForChild("Toast")
local strip = main:WaitForChild("Strip")
local tabBar = main:WaitForChild("TabBar")
local pages = main:WaitForChild("Pages")

-- Bespoke theme (idempotent): edit-mode preview cards out, frames and tabs in.
UITheme.ClearPreviews(gui)
UITheme.Apply(gui)
UITheme.SceneGlass(gui) -- translucent panels over the 3D void (StarterPlayerScripts/VoidScene)

local state = nil
local wasDead = false
local compact = false -- phone layout (set by the responsive block below)

----------------------------------------------------------------------
-- Toast
----------------------------------------------------------------------

local toastToken = 0
local function showToast(message: string, kind: string?)
	toastToken += 1
	local token = toastToken
	toast.Text = message
	toast.TextColor3 = S.KindColors[kind or "info"] or C.text
	toast.Visible = true
	task.delay(3, function()
		if token == toastToken then
			toast.Visible = false
		end
	end)
end

----------------------------------------------------------------------
-- Tabs and page modules
----------------------------------------------------------------------

-- `Modules`: the tab is shown when any of them is enabled in the game manifest.
local TABS = {
	-- The living chronicle's front page (omen, goal, things to do); opens first.
	{ Key = "Today", Tab = "TodayTab", Page = "TodayPage", Label = "Today", Icon = "☀", Dynamic = true, Source = script:WaitForChild("TodayPage") },
	{ Key = "Training", Tab = "TrainingTab", Page = "TrainingPage", Label = "Train" },
	{ Key = "Study", Tab = "StudyTab", Page = "StudyPage", Label = "Education", Modules = { "Education", "Careers" } },
	{ Key = "Masters", Tab = "MastersTab", Page = "MastersPage", Label = T.MentorsTab, Modules = { "Masters" } },
	{ Key = "Social", Tab = "SocialTab", Page = "SocialPage", Label = "Bonds", Modules = { "Relationships" } },
	{ Key = "Progression", Tab = "ProgressionTab", Page = "ProgressionPage", Label = "Talents", Modules = { "Masteries", "Titles" } },
	{ Key = "Inventory", Tab = "InventoryTab", Page = "InventoryPage", Label = "Bag", Modules = { "Inventory" } },
	{ Key = "Journal", Tab = "JournalTab", Page = "JournalPage", Label = "Chronicle" },
	-- Built in code like a module tab (no static button/page in the layout).
	{ Key = "Family", Tab = "FamilyTab", Page = "FamilyPage", Label = "Lineage", Dynamic = true, Source = script:WaitForChild("FamilyTreePage") },
	{ Key = "Lineage", Tab = "LineageTab", Page = "LineagePage", Label = T.RebirthTab },
}

-- Engine modules can add their own tab (Shared/EngineModules: Tab + a Page module).
-- Their button and page frame are created here, so a new module edits nothing in this file.
for i, def in TABS do
	def.Order = i * 10
end
for _, id in GamePack.ModuleOrder do
	local moduleDef, page = GamePack.Modules[id], GamePack.Pages[id]
	if moduleDef.Tab and page then
		table.insert(TABS, {
			Key = id, Tab = id .. "Tab", Page = id .. "Page", Module = id, Source = page,
			Label = moduleDef.Tab.Label or moduleDef.Name, Order = moduleDef.Tab.Order or 65, Icon = moduleDef.Tab.Icon,
		})
	end
end

local modules = {}
local currentTab = nil
-- [pageName] = ScrollingFrame around the page (phones draw dense pages taller and scroll).
local pageScrollers = {}
local pageFrames = {} -- [pageName] = the page frame (it may live inside its scroller)
local enabledTabs = {} -- [key] = true when the game uses the tab at all

local function selectTab(key: string)
	currentTab = key
	for _, def in TABS do
		local active = def.Key == key
		local button = tabBar:FindFirstChild(def.Tab)
		if not button or not modules[def.Key] then
			continue
		end
		pageFrames[def.Page].Visible = active
		local scroller = pageScrollers[def.Page]
		if scroller then
			scroller.Visible = active
			if active then
				scroller.CanvasPosition = Vector2.zero
			end
		end
		UITheme.setTabActive(button, active)
	end
end

local ctx = {
	Gui = gui,
	Remotes = Remotes,
	Style = S,
	Config = Config,
	Requirements = Requirements,
	GamePack = GamePack,
	Content = Content,
	Toast = showToast,
	SelectTab = selectTab,
	Theme = UITheme,
	Shield = ModalShield, -- every popup overlay is shielded (Shared/ModalShield)
	-- Story text types itself out (Today page, life events); the player can turn it off.
	Typewriter = {
		On = Players.LocalPlayer:GetAttribute("Typewriter") ~= false,
		Set = nil,
	},
}
function ctx.Typewriter.Set(on: boolean)
	ctx.Typewriter.On = on
	Players.LocalPlayer:SetAttribute("Typewriter", on)
end

-- Hover tooltips (stat ratings, skills): kept 8 px inside the viewport, hidden by popups.
do
	local tipGui = S.new("ScreenGui", { Name = "TooltipUI", ResetOnSpawn = false, DisplayOrder = 115, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	tipGui:SetAttribute("NoAutoScale", true)
	tipGui.Parent = gui.Parent
	local tip = S.new("Frame", { Name = "Tooltip", Size = UDim2.fromOffset(300, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, Parent = tipGui })
	S.decorate(tip, C.panel1, C.bg2, C.gold, 8, 0.2)
	S.fit(tip)
	local tipText = S.autoLabel({ Name = "Text", Text = "", RichText = true, Parent = tip }, 13)
	local owner = nil
	function ctx.ShowTooltip(target: GuiObject, text: string)
		if ModalShield.AnyOpen() then
			return
		end
		owner = target
		tipText.Text = text
		local at = target.AbsolutePosition + game:GetService("GuiService"):GetGuiInset()
		tip.Position = UDim2.fromOffset(at.X + target.AbsoluteSize.X + 6, at.Y)
		tip.Visible = true
		task.defer(function()
			if owner == target then
				ModalShield.Clamp(tip)
			end
		end)
	end
	function ctx.HideTooltip(target: GuiObject?)
		if target == nil or owner == target then
			owner = nil
			tip.Visible = false
		end
	end
	ModalShield.Changed:Connect(function(open)
		if open then
			ctx.HideTooltip()
		end
	end)
	-- Hover on desktop, tap on touch screens.
	function ctx.AttachTooltip(target: GuiObject, getText: () -> string)
		target.MouseEnter:Connect(function() ctx.ShowTooltip(target, getText()) end)
		target.MouseLeave:Connect(function() ctx.HideTooltip(target) end)
		local function toggle()
			if owner == target then ctx.HideTooltip(target) else ctx.ShowTooltip(target, getText()) end
		end
		if target:IsA("GuiButton") then
			target.Activated:Connect(toggle)
		else
			-- Plain frames (badges) toggle on tap too.
			target.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Touch then
					toggle()
				end
			end)
		end
	end
end

-- Button and page frame for a module tab, styled like the built-in ones.
local function buildModuleTab(def)
	local button = tabBar.JournalTab:Clone()
	button.Name = def.Tab
	button.Text = def.Label
	button.Parent = tabBar
	UITheme.tab(button)
	S.new("Frame", { Name = def.Page, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = pages })
end

local labels = GamePack.Manifest.Interface and GamePack.Manifest.Interface.TabLabels
for _, def in TABS do
	local visible = if def.Module then GamePack.IsActive(def.Module) else GamePack.AnyEnabled(def.Modules)
	if def.Module and not visible then
		continue -- inactive module tabs are never built
	end
	if def.Module or def.Dynamic then
		buildModuleTab(def)
	end
	enabledTabs[def.Key] = visible
	local module = require(def.Source or script:WaitForChild(def.Page))
	pageFrames[def.Page] = pages:WaitForChild(def.Page)
	module.Init(ctx, pageFrames[def.Page])
	modules[def.Key] = module
	local button = tabBar[def.Tab]
	button.LayoutOrder = def.Order
	button.Visible = visible
	button.Activated:Connect(function()
		selectTab(def.Key)
	end)
	button.Text = ("%s  %s"):format(def.Icon or UITheme.TabIcons[def.Key] or "✨", (labels and labels[def.Key]) or def.Label or button.Text)
end

-- Visible tabs share the bar evenly, however many modules add their own. Past
-- TAB_ROW_MAX they wrap into two rows: the bar grows (TWO_ROW_GROWTH, phones
-- PHONE_TWO_ROW_GROWTH with icon-only tabs) and the pages give up the same height,
-- so labels never squeeze into each other.
local TAB_ROW_MAX = 9
local TWO_ROW_GROWTH = 1.65
local PHONE_TWO_ROW_GROWTH = 1.3 -- the phone bar is tall already; two icon rows need a little more
local tabBase = nil -- { BarY, BarH, PagesY, PagesH } from the last layout pass (applyLayout)
local function layoutTabs()
	local layout = tabBar:FindFirstChildOfClass("UIListLayout")
	local gap = if layout then layout.Padding.Scale else 0
	local shown = {}
	for _, def in TABS do
		local button = tabBar:FindFirstChild(def.Tab)
		if button and button.Visible then
			table.insert(shown, button)
		end
	end
	local rows = if #shown > TAB_ROW_MAX then 2 else 1
	local perRow = math.max(1, math.ceil(#shown / rows))
	local width = (1 - gap * (perRow - 1)) / perRow - 1e-4 -- the epsilon keeps a full row from wrapping early
	for _, button in shown do
		button.Size = UDim2.new(width, 0, 1 / rows, 0)
		-- The bar sizes its tabs (ResponsiveUI's 44 px minimum would push row two out).
		button:SetAttribute("TouchSafe", true)
		-- Phones with two rows show icons only ("icon  label" text), restored on wide screens.
		local full = button:GetAttribute("FullText") or button.Text
		button:SetAttribute("FullText", full)
		button.Text = if compact and rows > 1 then (string.match(full, "^(.-)  ") or full) else full
	end
	if layout then
		layout.Wraps = rows > 1
	end
	if tabBase then
		local h = tabBase.BarH * (if rows <= 1 then 1 elseif compact then PHONE_TWO_ROW_GROWTH else TWO_ROW_GROWTH)
		tabBar.Size = UDim2.fromScale(tabBar.Size.X.Scale, h)
		local treasury = main:FindFirstChild("TreasuryButton")
		if treasury then
			treasury.Size = UDim2.fromScale(treasury.Size.X.Scale, h)
		end
		local rule = main:FindFirstChild("TabBaseRule")
		if rule then
			rule.Position = UDim2.new(rule.Position.X.Scale, 0, tabBase.BarY + h, -2)
		end
		local extra = h - tabBase.BarH
		pages.Position = UDim2.fromScale(pages.Position.X.Scale, tabBase.PagesY + extra)
		pages.Size = UDim2.fromScale(pages.Size.X.Scale, tabBase.PagesH - extra)
	end
end
layoutTabs()

-- Progressive disclosure (ProgressionGatesConfig): tabs appear as the character grows up.
local gateKey = nil
local function applyGates(s)
	local tabGates = Config.Gates.Tabs or {}
	local key = ("%d|%s"):format(s.Age, tostring(s.Dead))
	if key == gateKey then
		return
	end
	gateKey = key
	for _, def in TABS do
		local button = tabBar:FindFirstChild(def.Tab)
		if button and modules[def.Key] then
			button.Visible = enabledTabs[def.Key] == true and s.Age >= (tabGates[def.Key] or 0)
		end
	end
	layoutTabs()
	local current = currentTab and tabBar:FindFirstChild((function()
		for _, def in TABS do
			if def.Key == currentTab then return def.Tab end
		end
		return ""
	end)())
	if current and not current.Visible then
		selectTab("Training")
	end
end

-- Without cultivation the realm / Qi strip disappears and the tabs move up.
if not GamePack.IsEnabled("Cultivation") then
	strip.Visible = false
	tabBar.Position = UDim2.fromScale(0.015, 0.025)
	local rule = main:FindFirstChild("TabBaseRule")
	if rule then
		rule.Position = UDim2.new(0.015, 0, 0.025 + tabBar.Size.Y.Scale, -2)
	end
	pages.Position = UDim2.fromScale(0.015, 0.11)
	pages.Size = UDim2.fromScale(0.97, 0.87)
end

----------------------------------------------------------------------
-- Character sheet and cultivation strip
----------------------------------------------------------------------

task.spawn(function()
	local player = Players.LocalPlayer
	local ok, image = pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	end)
	if ok then
		sheet.Avatar.Image = image
	end
end)

local function setMeter(row, value: number, max: number)
	row.Value.Text = ("%d / %d"):format(value, max)
	S.setBar(row.Bar.Fill, value / math.max(1, max))
end

local function occupation(s): string
	if s.Career.Id then
		local career = Config.Studies.CareersById[s.Career.Id]
		return if career then career.Name else "Working"
	end
	if s.Education.Enrolled then
		local tier = Config.Studies.TiersById[s.Education.Tier]
		return if tier then tier.Name else "Student"
	end
	return if s.Age < 3 then "Toddler" else "Unemployed"
end

-- "Nascent Soul" -> "NS" (seal and emblem glyphs).
local function initials(name: string?): string
	local out = ""
	for word in string.gmatch(name or "", "%a+") do
		out ..= string.sub(word, 1, 1)
		if #out >= 2 then
			break
		end
	end
	return if out ~= "" then string.upper(out) else "?"
end

-- Seal tooltip: what the badge stands for, and the next tier when there is one.
local function sealTooltip(): string
	if not state then
		return ""
	end
	if not GamePack.IsEnabled("Cultivation") then
		return ("<b>%s</b>"):format(state.Race or "?")
	end
	local realms = Config.Realms.Realms
	local index = state.RealmIndex or 0
	local tier, nextTier = realms[index], realms[index + 1]
	local name = if tier then tier.Name else (state.Realm or "?")
	local stamp = if tier and tier.Stamp then ("[%s] "):format(tier.Stamp) else ""
	local text = ("<b>%s%s</b>\nYour %s (%d of %d)."):format(stamp, name, T.TierSystemName or T.TierName or "tier", index, #realms)
	if nextTier then
		text ..= ("\nNext: %s (%s)."):format(nextTier.Name, T.AdvanceTierName or "advance")
	end
	return text
end

-- The Advance Year medallion pulses once the year's actions are spent.
local pulseTween
local function setPulse(on: boolean)
	local scale = sheet.AdvanceButton:FindFirstChild("Pulse")
	if not scale then
		return
	end
	if on and not pulseTween then
		pulseTween = TweenService:Create(scale, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.035 })
		pulseTween:Play()
	elseif not on and pulseTween then
		pulseTween:Cancel()
		pulseTween = nil
		scale.Scale = 1
	end
end

local function renderSheet(s)
	-- Seal on the avatar: realm initials, bordered in the bloodline's rarity color.
	local seal = sheet.Avatar:FindFirstChild("Seal")
	if seal and not seal:GetAttribute("HasTip") then
		seal:SetAttribute("HasTip", true)
		ctx.AttachTooltip(seal, sealTooltip)
	end
	if seal then
		local race = Config.Races.ById[s.RaceId]
		local spin = Config.Races.Spin
		local rarity = race and spin and spin.Rarities[race.Rarity]
		local cultivation = GamePack.IsEnabled("Cultivation")
		if UITheme.Dossier then
			-- Grade stamp: the tier's Stamp ("[G4]", "[SG]") on a crimson badge.
			local tier = cultivation and Config.Realms.Realms[s.RealmIndex or 0]
			seal.Glyph.Text = ("[%s]"):format(tier and tier.Stamp or initials(if cultivation then s.Realm else s.Race))
			seal.BackgroundColor3 = C.crimson1
		else
			seal.Glyph.Text = initials(if cultivation then s.Realm else s.Race)
			seal.BackgroundColor3 = (s.RealmColor or C.gold):Lerp(C.ink, 0.6)
		end
		seal:FindFirstChildOfClass("UIStroke").Color = (race and race.Badge) or (rarity and rarity.Color) or C.gold
	end
	-- Pass badges (Fate Weaver VIP) ride after the name in gold.
	local badges = ""
	for _, badge in s.Badges or {} do
		badges ..= (' <font color="#%s">[%s]</font>'):format((C.jackpot or C.gold):ToHex(), badge)
	end
	sheet.NameLabel.RichText = true
	sheet.NameLabel.Text = S.escape(s.Name) .. badges
	sheet.RaceLabel.Text = ("%s  ·  %s"):format(s.Race, s.SocialStatus)
	local names = {}
	for _, id in s.Titles.Equipped do
		local title = Config.Titles.ById[id]
		if title then
			table.insert(names, title.Name)
		end
	end
	sheet.TitleLabel.Text = if #names > 0 then table.concat(names, "  ·  ") else "No title equipped"
	sheet.AgeLabel.Text = ("Age %d  ·  Lifespan %d"):format(s.Age, s.MaxLifespan)
	sheet.AgeLabel.TextColor3 = if s.Age >= s.MaxLifespan * 0.8 then C.red else C.text

	local meters = sheet.Meters
	setMeter(meters.HealthMeter, s.Health, s.MaxHealth)
	setMeter(meters.HappinessMeter, s.Happiness, 100)
	setMeter(meters.StressMeter, s.Stress, 100)
	local actions = meters:FindFirstChild("ActionsMeter")
	if actions then
		actions.Value.Text = ("%d / %d left"):format(s.Actions, s.MaxActions)
		for i = 1, 6 do
			local pip = actions.Pips:FindFirstChild("Pip" .. i)
			if pip then
				pip.Visible = i <= s.MaxActions
				pip.BackgroundTransparency = if i <= s.Actions then 0 else 1
				local stroke = pip:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Color = if i <= s.Actions then C.gold else C.muted
				end
			end
		end
		actions.Social.Text = ("👥 %d/%d"):format(s.Social or 0, s.MaxSocial or 0)
	end
	-- Action diamonds: golden (game-pass) slots first, spent slots dim from the right.
	local gems = sheet:FindFirstChild("ActionGems")
	if gems then
		-- Dual bar: actions and social interactions left this year.
		-- Phones: the count is the label ("ACTIONS THIS YEAR" and "ACTIONS 2/2" collided).
		if gems:FindFirstChild("Header") then
			gems.Header.Visible = not compact
		end
		gems.Count.TextXAlignment = if compact then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
		gems.Count.Position = UDim2.fromScale(if compact then 0.02 else 0.6, 0)
		gems.Count.Size = UDim2.fromScale(if compact then 0.96 else 0.38, 0.3)
		gems.Count.Text = (if compact then "ACTIONS THIS YEAR  %d/%d" else "ACTIONS %d/%d"):format(s.Actions, s.MaxActions)
		gems.Social.Text = ("👥 SOCIAL %d/%d"):format(s.Social or 0, s.MaxSocial or 0)
		local golden = math.min(s.GoldenActions or 0, s.MaxActions)
		for i = 1, 6 do
			local pip = gems.Row:FindFirstChild("Pip" .. i)
			if pip then
				pip.Visible = i <= s.MaxActions
				local available = i <= s.Actions
				local tone = if i <= golden then C.gold else C.qi1
				pip.Gem.BackgroundColor3 = if available then tone else C.inset
				pip.Gem.UIStroke.Color = if available then tone:Lerp(Color3.new(1, 1, 1), 0.25) else C.muted
				pip.Gem.UIStroke.Transparency = if available then 0.1 else 0.55
				pip.Gem.Facet.Visible = available
				pip.Glow.BackgroundColor3 = tone
				pip.Glow.Visible = available
			end
		end
	end

	local info = sheet.Info
	info.WealthRow.Value.Text = S.money(s.Money)
	info.WealthRow.Value.TextColor3 = if s.Money < 0 then C.red else C.text
	local knowledge = Config.Stats.Roles and Config.Stats.Roles.Knowledge
	local knowledgeStat = knowledge and s.Stats[knowledge]
	info.IntelligenceRow.Visible = knowledgeStat ~= nil
	if knowledgeStat then
		info.IntelligenceRow.Key.Text = "📖  " .. string.upper(Config.Stats.Stats[knowledge].Name)
		info.IntelligenceRow.Value.Text = ("Level %d"):format(knowledgeStat.Level)
	end
	info.KarmaRow.Value.Text = tostring(s.Karma)
	info.KarmaRow.Value.TextColor3 = C.gold
	info.AlignmentRow.Value.Text = S.alignmentText(s.Alignment)
	info.OccupationRow.Value.Text = occupation(s)
	if info:FindFirstChild("LivesRow") then
		info.LivesRow.Value.Text = ("Life #%d"):format(s.Lives)
	end

	local advance = sheet.AdvanceButton
	local blocked = s.Dead or s.HasPendingEvent
	advance.Title.Text = if s.Dead then "DECEASED" else "AGE UP  ▶"
	advance.Sub.Text = if s.Dead then T.DeceasedHint
		elseif s.HasPendingEvent then "Resolve your life event first"
		else ("Advance age  ·  next %d"):format(s.Age + 1)
	if blocked then
		S.paint(advance, C.card1, C.card2)
	elseif UITheme.Dossier then
		S.gradient(advance, C.crimson1, C.gold2, 0) -- crimson -> violet command button
	else
		S.paint(advance, C.gold, C.gold2)
	end
	local onAccent = if UITheme.Dossier then C.text else C.dark
	advance.Title.TextColor3 = if blocked then C.muted else onAccent
	advance.Sub.TextColor3 = if blocked then C.muted else onAccent
	setPulse(not blocked and s.Actions == 0)

	sheet.AutoButton.Text = (if compact or UITheme.Dossier then "Auto\n%s" else "Auto-age: %s"):format(if s.AutoAge then "On" else "Off")
	sheet.AutoButton.TextColor3 = if s.AutoAge then C.green else C.text
end

local duelModal = require(script:WaitForChild("DuelModal"))
duelModal.Init(ctx)

-- The Immortal Treasury (passes, packs, Miracle Revival on death) and its gold
-- header button at the end of the tab row.
local shopModal = require(script:WaitForChild("ShopModal"))
shopModal.Init(ctx)
ctx.OpenShop = shopModal.Open
ctx.IsShopOpen = shopModal.IsOpen
do
	local width = 0.15
	tabBar.Size = UDim2.fromScale(tabBar.Size.X.Scale - width - 0.006, tabBar.Size.Y.Scale)
	local rule = main:FindFirstChild("TabBaseRule")
	if rule then
		rule.Size = UDim2.new(tabBar.Size.X.Scale, 0, 0, 2)
	end
	local treasury = S.button({ Name = "TreasuryButton", Text = T.ShopButton, Font = S.Fonts.Heavy,
		Position = UDim2.fromScale(tabBar.Position.X.Scale + tabBar.Size.X.Scale + 0.006, tabBar.Position.Y.Scale),
		Size = UDim2.fromScale(width, tabBar.Size.Y.Scale), ZIndex = tabBar.ZIndex + 1, Parent = main }, nil, nil, 16)
	local shine = treasury:FindFirstChildOfClass("UIStroke")
	shine.Color, shine.Transparency, shine.Thickness = C.text, 0.35, 1.5
	if UITheme.Dossier then
		-- Black market: dark glass with a crimson edge, not a gold plaque.
		UITheme.glass(treasury, C.panel1, C.panel2, C.crimson1)
		treasury:FindFirstChildOfClass("UIStroke").Transparency = 0.1
		treasury.TextColor3 = C.text
	end
	treasury.Activated:Connect(shopModal.Open)
	layoutTabs()
end

-- Header bar (name, year & era, city, wealth, fame, life) and the routine bar.
local chronicleHud = require(script:WaitForChild("ChronicleHUD"))
chronicleHud.Init(ctx)

-- Minigames (Catch the Light, Sneak to the Study), offered on the Today page.
local minigameModal = require(script:WaitForChild("MinigameModal"))
minigameModal.Init(ctx)
ctx.OpenMinigame = minigameModal.Open
ctx.MinigamesAvailable = minigameModal.Available

-- Codes, Characters (save slots), Settings (themes, background, frames) and the Starter Pack card.
local menuModal = require(script:WaitForChild("MenuModal"))
menuModal.Init(ctx)
ctx.OpenMenu = menuModal.Open

-- The World hub: events, Wanted Posters, merchant, crafting, friends.
local worldModal = require(script:WaitForChild("WorldModal"))
worldModal.Init(ctx)
ctx.OpenWorld = worldModal.Open

-- Death screen: Continue as your Heir / Reincarnate as a Random Soul.
local rebirthModal = require(script:WaitForChild("RebirthModal"))
rebirthModal.Init(ctx)
ctx.OpenRebirth = rebirthModal.Open

-- Battles (opened from the Magic & Sword tab; reopens by itself while a fight is on).
local battleModal = require(script:WaitForChild("BattleModal"))
battleModal.Init(ctx)
ctx.OpenBattles = battleModal.Open

-- YOUR PATH: the constellation of this life's decisions (opened from the Today page).
local pathModal = require(script:WaitForChild("PathModal"))
pathModal.Init(ctx)
ctx.OpenPath = pathModal.Open

-- Touch screens (Shared/Responsive): phones get a side-by-side Advance / Auto-age row,
-- a taller tab row and scrolling pages; tablets a taller Auto-age button. Desktops
-- keep the desktop layout. Re-applied when the screen rotates or resizes.
local Responsive = require(Shared:WaitForChild("Responsive"))
do
	local treasury = main:WaitForChild("TreasuryButton")
	local rule = main:FindFirstChild("TabBaseRule")
	local tabY, tabH = tabBar.Position.Y.Scale, tabBar.Size.Y.Scale
	local pagesBottom = pages.Position.Y.Scale + pages.Size.Y.Scale
	local pagesGap = pages.Position.Y.Scale - (tabY + tabH)
	local desktop = {}
	for _, name in { "Info", "ActionGems", "AdvanceButton", "AutoButton" } do
		local item = sheet:FindFirstChild(name)
		if item then
			desktop[item] = { item.Position, item.Size }
		end
	end
	-- Every page sits in a vertical ScrollingFrame; on phones its canvas is
	-- PHONE_PAGE_HEIGHT times the visible height, so dense pages (Samsara, Bonds...)
	-- keep tappable rows and scroll. Pages that scroll on their own are left alone.
	local PHONE_PAGE_HEIGHT = 2.5
	local OWN_SCROLL = { FamilyPage = true, JournalPage = true }
	for _, def in TABS do
		local page = pageFrames[def.Page]
		if page and modules[def.Key] and not OWN_SCROLL[def.Page] then
			local scroller = S.new("ScrollingFrame", {
				Name = def.Page .. "Scroll", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
				ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = C.stroke,
				CanvasSize = UDim2.fromScale(0, 1), ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
				Visible = page.Visible, Parent = pages,
			})
			page.Size = UDim2.fromScale(1, 1)
			page.Position = UDim2.new()
			page.Parent = scroller
			pageScrollers[def.Page] = scroller
		end
	end
	local PHONE_SHEET = {
		Info = { UDim2.fromScale(0, 0.415), UDim2.fromScale(1, 0.235) },
		ActionGems = { UDim2.fromScale(0, 0.655), UDim2.fromScale(1, 0.135) },
		AdvanceButton = { UDim2.fromScale(0, 0.8), UDim2.fromScale(0.68, 0.2) },
		AutoButton = { UDim2.fromScale(0.7, 0.8), UDim2.fromScale(0.3, 0.2) },
	}
	-- Tablets: the desktop sheet with a full-height (44 px+) Auto-age button.
	local TABLET_SHEET = {
		AdvanceButton = { UDim2.fromScale(0, 0.825), UDim2.fromScale(1, 0.1) },
		AutoButton = { UDim2.fromScale(0, 0.935), UDim2.fromScale(1, 0.065) },
	}
	for _, button in { treasury, sheet.AdvanceButton, sheet.AutoButton } do
		button:SetAttribute("TouchSafe", true) -- sized here, not by ResponsiveUI
	end
	local function applyLayoutBase(profile)
		-- Phones: Advance / Auto-age side by side and a taller tab row; tablets: a
		-- taller Auto-age button. Both make every main control a full touch target.
		local phone = profile.Kind == "Phone"
		compact = phone
		chronicleHud.ApplyProfile(phone)
		-- Dossier themes place everything themselves (ID banner, tabs + pages, command bar).
		if UITheme.Layout(gui, profile) then
			for _, scroller in pageScrollers do
				scroller.CanvasSize = UDim2.fromScale(0, if phone then PHONE_PAGE_HEIGHT else 1)
			end
			if state then
				renderSheet(state)
			end
			return
		end
		local h = if phone then 0.15 else tabH
		tabBar.Size = UDim2.fromScale(tabBar.Size.X.Scale, h)
		treasury.Size = UDim2.fromScale(treasury.Size.X.Scale, h)
		if rule then
			rule.Position = UDim2.new(rule.Position.X.Scale, 0, tabY + h, -2)
		end
		local top = tabY + h + (if phone then 0.012 else pagesGap)
		pages.Position = UDim2.fromScale(pages.Position.X.Scale, top)
		pages.Size = UDim2.fromScale(pages.Size.X.Scale, pagesBottom - top)
		for _, scroller in pageScrollers do
			scroller.CanvasSize = UDim2.fromScale(0, if phone then PHONE_PAGE_HEIGHT else 1)
		end
		local sheetLayout = if phone then PHONE_SHEET elseif profile.Touch then TABLET_SHEET else {}
		for item, layout in desktop do
			local chosen = sheetLayout[item.Name] or layout
			item.Position, item.Size = chosen[1], chosen[2]
		end
		if state then
			renderSheet(state)
		end
	end
	-- Phones: pages built from three or more side-by-side full-height columns stack them
	-- full width down the taller phone canvas (columns of ~90 px cut every title).
	-- Wider screens get the original rectangles back (kept in attributes).
	local STACK_ON_PHONE = { LineagePage = true, GoalsPage = true, LegendsPage = true, RaidsPage = true, ArcanaPage = true, CharacterPage = true }
	local function stackColumns(phone: boolean)
		for pageName in STACK_ON_PHONE do
			local page = pageFrames[pageName]
			local columns = {}
			for _, child in if page then page:GetChildren() else {} do
				if child:IsA("GuiObject") then
					if typeof(child:GetAttribute("DeskSize")) ~= "UDim2" then
						child:SetAttribute("DeskPosition", child.Position)
						child:SetAttribute("DeskSize", child.Size)
					end
					local size = child:GetAttribute("DeskSize")
					if size.Y.Scale >= 0.9 and size.X.Scale > 0 and size.X.Scale < 0.5 then
						table.insert(columns, child)
					end
				end
			end
			table.sort(columns, function(a, b) return a:GetAttribute("DeskPosition").X.Scale < b:GetAttribute("DeskPosition").X.Scale end)
			local stack = phone and #columns >= 3
			-- Each stacked column gets twice the visible page height of canvas to scroll through.
			local scroller = pageScrollers[pageName]
			if scroller and stack then
				scroller.CanvasSize = UDim2.fromScale(0, #columns * 2)
			end
			for i, column in columns do
				if stack then
					column.Position = UDim2.fromScale(0, (i - 1) / #columns)
					column.Size = UDim2.fromScale(1, 1 / #columns - 0.008)
				else
					column.Position, column.Size = column:GetAttribute("DeskPosition"), column:GetAttribute("DeskSize")
				end
			end
		end
	end
	-- Every layout pass sets the one-row geometry; layoutTabs then grows the bar if needed.
	local function applyLayout(profile)
		tabBase = nil
		applyLayoutBase(profile)
		stackColumns(profile.Kind == "Phone")
		tabBase = { BarY = tabBar.Position.Y.Scale, BarH = tabBar.Size.Y.Scale,
			PagesY = pages.Position.Y.Scale, PagesH = pages.Size.Y.Scale }
		layoutTabs()
	end
	Responsive.Watch(applyLayout)
end

-- Life 1 onboarding spotlight.
local tutorialGuide = require(script:WaitForChild("TutorialGuide"))
tutorialGuide.Init(ctx, { Sheet = sheet, Strip = strip, Pages = pages, Modal = modal })

local function renderStrip(s)
	local realmBox, qiBox, button = strip.RealmBox, strip.QiBox, strip.BreakthroughButton
	-- The Qi bar and Breakthrough seal wake with the Spirit Root (or at StripAge).
	local gates = Config.Gates
	local awakened = s.Dead or (s.Flags and s.Flags[gates.StripFlag or ""]) or s.Age >= (gates.StripAge or 0)
	qiBox.Visible, button.Visible = awakened, awakened
	if not awakened then
		realmBox.Value.Text = s.Realm
		realmBox.Sub.Text = T.TierDormant
		return
	end
	realmBox.Value.Text = s.Realm
	realmBox.Value.TextColor3 = s.RealmColor
	realmBox.Sub.Text = ("Level %d / %d"):format(s.SubLevel, s.SubLevels)
	local emblem = realmBox:FindFirstChild("Emblem")
	if emblem then
		emblem.Glyph.Text = initials(s.Realm)
		emblem.Glyph.TextColor3 = s.RealmColor
		emblem:FindFirstChildOfClass("UIStroke").Color = s.RealmColor
	end

	local wait = s.BreakthroughWait or 0
	local ready = s.QiProgress >= 1 and not s.IsMaxed and not s.Dead and wait == 0
	local full = s.QiProgress >= 1 and not s.IsMaxed
	qiBox.BarBack.BarText.Text = if full then ("%s / %s  ·  LIMIT REACHED"):format(s.Qi, s.QiRequired) else ("%s / %s"):format(s.Qi, s.QiRequired)
	S.setBar(qiBox.BarBack.Fill, s.QiProgress)
	qiBox.Rate.Text = ("+%s %s per year  ·  x%s multiplier"):format(s.QiPerYear, T.EnergyName, s.QiMultiplier)

	button.Chance.Text = if wait > 0 then ("Stabilizing  ·  %d yr"):format(wait)
		else ("Success %d%%"):format(math.floor(s.BreakthroughChance * 100 + 0.5))
	-- The peak of the Dao: the seal turns golden and offers Ascension (AscensionSystem).
	if s.IsMaxed and not s.Dead then
		button.Title.Text = T.AscendButton
		button.Chance.Text = T.AscendHint
		S.paint(button, C.gold, C.gold2)
		button.Title.TextColor3, button.Chance.TextColor3 = C.dark, C.dark
		local ascendStroke = button:FindFirstChildOfClass("UIStroke")
		ascendStroke.Color, ascendStroke.Transparency, ascendStroke.Thickness = C.text, 0, 2.5
		return
	end
	button.Title.Text = T.AdvanceTierButton
	if (s.PillBonus or 0) > 0 then
		button.Chance.Text ..= "  ·  💊"
	end
	-- Ritual seal: crimson and gold when ready, dormant stone otherwise.
	if ready then
		S.paint(button, C.crimson1, C.crimson2)
	else
		S.paint(button, C.card1, C.card2)
	end
	button.Title.TextColor3 = if ready then C.text else C.muted
	button.Chance.TextColor3 = if ready then C.gold else C.muted
	local stroke = button:FindFirstChildOfClass("UIStroke")
	stroke.Color = if ready then C.gold else C.stroke
	stroke.Transparency = if ready then 0 else 0.6
	stroke.Thickness = if ready then 2.5 else 1.5
end

sheet.AdvanceButton.Activated:Connect(function()
	Remotes.AdvanceYear:FireServer()
end)

sheet.AutoButton.Activated:Connect(function()
	if state then
		Remotes.SetAutoAge:FireServer(not state.AutoAge)
	end
end)

strip.BreakthroughButton.Activated:Connect(function()
	if state and state.IsMaxed and Remotes:FindFirstChild("AscendAction") then
		Remotes.AscendAction:FireServer()
	else
		Remotes.Breakthrough:FireServer()
	end
end)

----------------------------------------------------------------------
-- Life event modal
----------------------------------------------------------------------

local card = modal.Card
ModalShield.Attach(modal)
local promptQueue = {}
local showingResult = false
local waitingChoice = false

-- The event story types itself out (ctx.Typewriter); a tap on the card finishes it.
local storyToken = 0
local function typeStory(text: string)
	storyToken += 1
	local token = storyToken
	card.Story.Text = text
	card.Story.MaxVisibleGraphemes = if ctx.Typewriter.On then 0 else -1
	if not ctx.Typewriter.On then
		return
	end
	task.spawn(function()
		local total = utf8.len(card.Story.ContentText) or #card.Story.ContentText
		local shown = 0
		while token == storyToken and shown < total do
			shown += 2
			card.Story.MaxVisibleGraphemes = shown
			task.wait(0.025)
		end
		if token == storyToken then
			card.Story.MaxVisibleGraphemes = -1
		end
	end)
end
card.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		storyToken += 1
		card.Story.MaxVisibleGraphemes = -1
	end
end)

local function showPrompt(data)
	showingResult = false
	waitingChoice = false
	card.AgeTag.Text = ("Age %d"):format(data.Age)
	card.QueueLabel.Text = if data.Remaining > 0 then ("%d more this year"):format(data.Remaining) else ""
	card.EventTitle.Text = data.Title
	card.EventTitle.TextColor3 = C.gold
	typeStory(data.Text)
	card.ContinueButton.Visible = false
	card.Options.Visible = true
	S.clear(card.Options)

	for i, option in data.Options do
		-- Gold choice buttons; a ⚠ badge marks a choice that can fail.
		local text = if option.Hint then option.Text .. "  ·  " .. option.Hint else option.Text
		if option.Risky and not option.Locked then
			text = "⚠  " .. text
		end
		local button = S.button({ Name = "Option", LayoutOrder = i, Text = text, Size = UDim2.fromScale(1, 0.3), Parent = card.Options }, nil, nil, 17)
		S.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = button })
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if option.Locked then
			S.setEnabled(button, false)
		elseif stroke then
			button.MouseEnter:Connect(function() stroke.Transparency = 0.05 end)
			button.MouseLeave:Connect(function() stroke.Transparency = 0.5 end)
		end
		button.Activated:Connect(function()
			if option.Locked or waitingChoice then
				return
			end
			waitingChoice = true
			Remotes.EventChoice:FireServer(data.Id, i)
		end)
	end

	if not modal.Visible then
		modal.Visible = true
		card.Pop.Scale = 0.92
		TweenService:Create(card.Pop, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
end

Remotes.EventPrompt.OnClientEvent:Connect(function(data)
	if modal.Visible and showingResult then
		table.insert(promptQueue, data)
	else
		showPrompt(data)
	end
end)

Remotes.EventResult.OnClientEvent:Connect(function(data)
	showingResult = true
	waitingChoice = false
	card.EventTitle.TextColor3 = if data.Success then C.green else C.red
	typeStory(if data.Summary ~= "" then data.Text .. "\n\n" .. data.Summary else data.Text)
	card.Options.Visible = false
	card.ContinueButton.Visible = true
end)

card.ContinueButton.Activated:Connect(function()
	showingResult = false
	if #promptQueue > 0 then
		showPrompt(table.remove(promptQueue, 1))
	else
		modal.Visible = false
	end
end)

----------------------------------------------------------------------
-- Network
----------------------------------------------------------------------

local function apply(snapshot, log)
	state = snapshot
	renderSheet(snapshot)
	renderStrip(snapshot)
	applyGates(snapshot)
	duelModal.Render(snapshot)
	shopModal.Render(snapshot)
	pathModal.Render(snapshot)
	pcall(worldModal.Render, snapshot)
	local menuOk, menuErr = pcall(menuModal.Render, snapshot)
	if not menuOk then
		warn("[UIController] MenuModal render failed: " .. tostring(menuErr))
	end
	local rebirthOk, rebirthErr = pcall(rebirthModal.Render, snapshot)
	if not rebirthOk then
		warn("[UIController] RebirthModal render failed: " .. tostring(rebirthErr))
	end
	local battleOk, battleErr = pcall(battleModal.Render, snapshot)
	if not battleOk then
		warn("[UIController] BattleModal render failed: " .. tostring(battleErr))
	end
	local hudOk, hudErr = pcall(chronicleHud.Render, snapshot)
	if not hudOk then
		warn("[UIController] ChronicleHUD render failed: " .. tostring(hudErr))
	end
	for _, def in TABS do
		local ok, err = true, nil
		if modules[def.Key] then
			ok, err = pcall(modules[def.Key].Render, snapshot)
		end
		if not ok then
			warn("[UIController] " .. def.Page .. " render failed: " .. tostring(err))
		end
	end
	if log then
		modules.Journal.Rebuild(log)
		modules.Today.Rebuild(log)
	end
	if snapshot.Dead and not wasDead then
		modal.Visible = false
		promptQueue = {}
		selectTab("Lineage")
	elseif not snapshot.Dead and wasDead then
		selectTab("Today")
	end
	wasDead = snapshot.Dead
	-- The loading screen (ReplicatedFirst/IntroAndLoadingUI) waits for the first full render.
	gui:SetAttribute("Ready", true)
	tutorialGuide.Render(snapshot)
end

Remotes.StateUpdate.OnClientEvent:Connect(apply)
Remotes.LogEntry.OnClientEvent:Connect(function(entry)
	modules.Journal.AddEntry(entry)
	modules.Today.AddEntry(entry)
end)
Remotes.Notify.OnClientEvent:Connect(showToast)

selectTab("Today")
modal.Visible = false
-- Studio UI checks: the workspace attribute StartTab (e.g. "World") opens that tab.
if game:GetService("RunService"):IsStudio() then
	local function startTab()
		local key = workspace:GetAttribute("StartTab")
		if type(key) == "string" and modules[key] then
			selectTab(key)
		end
	end
	workspace:GetAttributeChangedSignal("StartTab"):Connect(startTab)
	startTab()
	-- OpenMinigame = "Motes" | "Sneak" starts that game (UI checks without clicking).
	workspace:GetAttributeChangedSignal("OpenMinigame"):Connect(function()
		local id = workspace:GetAttribute("OpenMinigame")
		if id == "Motes" or id == "Sneak" then
			minigameModal.Open(id)
		end
	end)
	-- OpenPath = true opens YOUR PATH (UI checks without clicking).
	workspace:GetAttributeChangedSignal("OpenPath"):Connect(function()
		if workspace:GetAttribute("OpenPath") then
			pathModal.Open()
		else
			pathModal.Close()
		end
	end)
end
task.spawn(function()
	local snapshot, log = Remotes.GetState:InvokeServer()
	if snapshot then
		apply(snapshot, log)
	end
end)
