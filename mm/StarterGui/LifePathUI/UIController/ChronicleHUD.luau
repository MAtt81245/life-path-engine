--[[
	ChronicleHUD: the header bar across the top and the routine bar under the pages
	(ChronicleConfig, Modules/ChronicleSystem).

	Header: Name «Title» | Race · Gender · Age · Stage | Year · Era | City |
	Wealth · Social class | Fame tier | Life #. The sheet and main panels move down
	to make room (classic layout; Dossier themes place their own panels).
	Routine bar: four toggles (ChronicleConfig.Routines); the active one pays its gains
	on every AGE UP and the bar shows last year's result.

	Init(ctx), Render(snapshot).
]]

local HUD = {}

local ctx, S, C, Chronicle
local ui = {}

local function scale(x, y) return UDim2.fromScale(x, y) end

-- A root frame's layout size: StarterPlayerScripts/ResponsiveUI divides root sizes by its
-- UIScale and keeps the original in the BaseSize attribute.
local function baseSize(frame: GuiObject): UDim2
	local base = frame:GetAttribute("BaseSize")
	return if typeof(base) == "UDim2" then base else frame.Size
end

HUD.Header = { Y = 0.012, Height = 0.062 }
HUD.Panels = { Y = 0.084, Height = 0.79 }
HUD.Routine = { Y = 0.884, Height = 0.05 }

local SEGMENTS = {
	{ Key = "Name", Width = 0.13 },
	{ Key = "Identity", Width = 0.18 },
	{ Key = "Year", Width = 0.19 },
	{ Key = "City", Width = 0.12 },
	{ Key = "Wealth", Width = 0.13 },
	{ Key = "Fame", Width = 0.08 },
	{ Key = "Life", Width = 0.06 },
}
-- The last 0.11 of the header is the "Offer" slot (MenuModal docks the Starter Pack
-- chip there, so the offer never floats over a page).
HUD.OfferWidth = 0.11
-- Phones (ApplyProfile): the sheet already shows the name, so it leaves the header and
-- the rest widen; Fame stays hidden; the routine bar doubles in height (it uses the
-- free strip under it) and drops its caption and last-gain text.
local PHONE_SEGMENTS = { Name = 0, Identity = 0.25, Year = 0.23, City = 0.14, Wealth = 0.15, Fame = 0, Life = 0.07 }
local PHONE_OFFER = 0.16
local PHONE_ROUTINE_HEIGHT = 0.1

function HUD.Init(context)
	ctx = context
	S = ctx.Style
	C = S.C
	Chronicle = ctx.Content.Get("ChronicleConfig")
	local gui = ctx.Gui
	local sheet, main = gui:WaitForChild("Sheet"), gui:WaitForChild("Main")
	local classic = not ctx.Theme.Dossier
	local sheetSize, mainSize = baseSize(sheet), baseSize(main)

	-- Header bar.
	local header = S.new("Frame", { Name = "ChronicleHeader", Position = scale(sheet.Position.X.Scale, HUD.Header.Y),
		Size = scale(main.Position.X.Scale + mainSize.X.Scale - sheet.Position.X.Scale, HUD.Header.Height), Parent = gui })
	S.padding(header, 12, 4)
	-- The row layout first: a laid-out frame gets no trim (it would be laid out as content).
	S.list(header, UDim.new(0, 0), true).VerticalAlignment = Enum.VerticalAlignment.Center
	ctx.Theme.frame(header, 10, C.panel1, C.bg2)
	local scene = S.Theme.Scene
	if scene and scene.Enabled ~= false then
		header.BackgroundTransparency = scene.PanelTransparency or 0.12
	end
	ui.Segments = {}
	for i, segment in SEGMENTS do
		local label = S.label({ Name = segment.Key, LayoutOrder = i, Text = "", RichText = true, Font = if i == 1 then S.Fonts.Title else S.Fonts.Bold,
			TextColor3 = if i == 1 then C.gold else C.text, TextXAlignment = Enum.TextXAlignment.Center, Size = scale(segment.Width, 1), Parent = header }, if i == 1 then 18 else 14)
		if i > 1 then
			S.new("Frame", { Name = "Divider", AnchorPoint = Vector2.new(0, 0.5), Position = scale(0, 0.5), Size = UDim2.new(0, 1, 0.7, 0),
				BackgroundColor3 = C.stroke, BackgroundTransparency = 0.6, BorderSizePixel = 0, Parent = label })
		end
		ui.Segments[segment.Key] = label
	end
	ui.Offer = S.new("Frame", { Name = "Offer", LayoutOrder = #SEGMENTS + 1, BackgroundTransparency = 1, Size = scale(HUD.OfferWidth, 1), Parent = header })
	ui.Header = header

	-- Routine bar.
	local bar = S.new("Frame", { Name = "RoutineBar", Position = scale(main.Position.X.Scale, HUD.Routine.Y),
		Size = scale(mainSize.X.Scale, HUD.Routine.Height), Parent = gui })
	S.padding(bar, 10, 4)
	ctx.Theme.frame(bar, 10, C.panel1, C.bg2)
	if scene and scene.Enabled ~= false then
		bar.BackgroundTransparency = scene.PanelTransparency or 0.12
	end
	ui.Caption = S.label({ Name = "Caption", Text = "DAILY ROUTINE", Font = S.Fonts.Heavy, TextColor3 = C.gold, Size = scale(0.13, 1), Parent = bar }, 13)
	ui.Routines = {}
	-- Columns: caption 0-0.13 | routines 0.135-0.62 | last gain 0.625-0.8 | menu 0.81-1.
	local width = 0.485 / #Chronicle.Routines
	for i, routine in Chronicle.Routines do
		local button = S.ghostButton({ Name = routine.Id, Text = routine.Icon .. "  " .. routine.Name, Position = scale(0.135 + (i - 1) * width, 0.06),
			Size = scale(width - 0.006, 0.88), Parent = bar }, 14)
		button.Activated:Connect(function()
			ctx.Remotes.ChronicleAction:FireServer("Routine", routine.Id)
		end)
		ui.Routines[routine.Id] = { Button = button, Routine = routine }
	end
	ui.Gain = S.label({ Name = "LastGain", Text = "", TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Right,
		Position = scale(0.625, 0), Size = scale(0.175, 1), Parent = bar }, 12)
	-- Menu shortcuts: Codes, Characters (save slots), Settings.
	for i, entry in { { "Codes", "Codes" }, { "Chars", "Characters" }, { "Settings", "Settings" } } do
		local b = S.ghostButton({ Name = entry[2] .. "Button", Text = entry[1], Position = scale(0.81 + (i - 1) * 0.0635, 0.06), Size = scale(0.06, 0.88), Parent = bar }, 12)
		b.Activated:Connect(function() if ctx.OpenMenu then ctx.OpenMenu(entry[2]) end end)
		ui.Menu = ui.Menu or {}
		ui.Menu[i] = b
	end
	ui.Bar = bar

	if classic then
		-- Panels move down under the header and stop above the routine bar.
		-- (ResponsiveUI notices the new sizes and rescales them.)
		main.Position = scale(main.Position.X.Scale, HUD.Panels.Y)
		main.Size = scale(mainSize.X.Scale, HUD.Panels.Height)
		-- The routine bar sits under the main panel only; the sheet keeps its full column.
		sheet.Position = scale(sheet.Position.X.Scale, HUD.Panels.Y)
		sheet.Size = scale(sheetSize.X.Scale, HUD.Routine.Y + HUD.Routine.Height - HUD.Panels.Y)
	end
end

-- Phone or wide layout of the header and routine bar (UIController calls it on every
-- layout pass). Every bar button is sized here, so ResponsiveUI leaves it alone.
function HUD.ApplyProfile(phone: boolean)
	if not ui.Bar then
		return
	end
	ui.Phone = phone
	for _, segment in SEGMENTS do
		local label = ui.Segments[segment.Key]
		local width = if phone then PHONE_SEGMENTS[segment.Key] else segment.Width
		label.Size = scale(width, 1)
		if segment.Key == "Name" then
			label.Visible = not phone
		end
	end
	ui.Offer.Size = scale(if phone then PHONE_OFFER else HUD.OfferWidth, 1)
	-- A docked offer may carry a short label for phones (MenuModal's Starter Pack chip).
	for _, button in ui.Offer:GetDescendants() do
		if button:IsA("TextButton") and button:GetAttribute("PhoneText") then
			local full = button:GetAttribute("FullText") or button.Text
			button:SetAttribute("FullText", full)
			button.Text = if phone then button:GetAttribute("PhoneText") else full
		end
	end
	local bar = ui.Bar
	bar.Size = scale(baseSize(bar).X.Scale, if phone then PHONE_ROUTINE_HEIGHT else HUD.Routine.Height)
	ui.Caption.Visible, ui.Gain.Visible = not phone, not phone
	local first, span = if phone then 0 else 0.135, if phone then 0.7 else 0.485
	local count, i = #Chronicle.Routines, 0
	for _, routine in Chronicle.Routines do
		i += 1
		local button = ui.Routines[routine.Id].Button
		button:SetAttribute("TouchSafe", true)
		button.Position = scale(first + (i - 1) * span / count, 0.06)
		button.Size = scale(span / count - 0.006, 0.88)
	end
	for index, button in ui.Menu or {} do
		button:SetAttribute("TouchSafe", true)
		button.Position = scale((if phone then 0.71 else 0.81) + (index - 1) * (if phone then 0.097 else 0.0635), 0.06)
		button.Size = scale(if phone then 0.093 else 0.06, 0.88)
	end
end

local function setActive(button, active: boolean)
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if active then
		S.paint(button, C.gold, C.gold2)
		button.TextColor3 = C.dark
	else
		S.paint(button, C.card1, C.card2)
		button.TextColor3 = C.text
	end
	if stroke then
		stroke.Color = if active then C.text else C.stroke
		stroke.Transparency = if active then 0.2 else 0.6
	end
end

function HUD.Render(s)
	local data = (s.Modules and s.Modules.Chronicle) or {}
	local titles = ctx.Config.Titles
	local title = nil
	for _, id in (s.Titles and s.Titles.Equipped) or {} do
		local def = titles.ById[id]
		if def then
			title = def.Name
			break
		end
	end
	local seg = ui.Segments
	seg.Name.Text = S.escape(s.Name) .. (if title then (' <font color="#%s">«%s»</font>'):format(C.text:ToHex(), S.escape(title)) else "")
	local gender = nil
	for _, g in Chronicle.Genders do
		if g.Id == data.Gender then
			gender = g
		end
	end
	local stage = Chronicle.Stage(s.Age)
	-- Phones get the short forms (the long ones wrapped onto two lines).
	local year = (data.BirthYear or Chronicle.StartYear) + s.Age
	if ui.Phone then
		seg.Identity.Text = ("%s  ·  %s  ·  Age %d"):format(s.Race, if gender then gender.Icon else "—", s.Age)
		seg.Year.Text = ("Year %d"):format(year)
	else
		seg.Identity.Text = ("%s  ·  %s  ·  Age %d  ·  %s"):format(s.Race, if gender then gender.Icon .. " " .. gender.Name else "—", s.Age, stage.Name)
		seg.Year.Text = ("Year %d  ·  %s"):format(year, Chronicle.Era(year))
	end
	seg.Year.TextColor3 = C.gold
	local world = s.Modules and s.Modules.World
	local regions = ctx.Config.Regions
	local region = world and world.Region and regions and regions.Get and regions.Get(world.Region)
	seg.City.Text = "📍 " .. (if region then region.Name else "Home")
	local birth = s.Modules and s.Modules.Birth
	local history = ctx.Content.Get("HistoryConfig")
	local class = birth and history.ClassesById[birth.Class or ""]
	-- Birth class until school or work gives you a social status of your own.
	local status = if (s.Career and s.Career.Id) or next(s.Graduated or {}) then s.SocialStatus elseif class then class.Name else s.SocialStatus
	seg.Wealth.Text = ("%s  ·  %s"):format(S.money(s.Money), status or "-")
	local fame = s.Modules and s.Modules.Fame
	seg.Fame.Visible = ctx.GamePack.IsActive("Fame") and not ui.Phone
	seg.Fame.Text = "★ " .. Chronicle.FameTier(if fame then fame.Points or 0 else 0)
	seg.Life.Text = ("Life #%d"):format(s.Lives)

	local current = data.Routine or Chronicle.DefaultRoutine
	for id, entry in ui.Routines do
		entry.Button.Text = entry.Routine.Icon .. "  " .. Chronicle.RoutineName(entry.Routine, s.Age)
		-- Painted here, not with S.setEnabled (it would restore the first-seen colors).
		entry.Button.Active = not s.Dead
		entry.Button.TextTransparency = if s.Dead then 0.4 else 0
		setActive(entry.Button, id == current and not s.Dead)
	end
	ui.Gain.Text = if data.LastRoutineGain and data.LastRoutineGain ~= "" then "Last year: " .. data.LastRoutineGain else "Pays out on every AGE UP"
end

return HUD
