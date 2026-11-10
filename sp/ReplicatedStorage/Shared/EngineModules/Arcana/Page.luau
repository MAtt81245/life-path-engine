--[[
	Magic & Sword tab (client; Modules/ArcanaSystem through ArcanaAction).
	Left: mana and affinities (base elements, special schools n/5).
	Middle: the selected element's spellbook: 7 ranked spells, mastery 0-5, chantless.
	Right: the sword side (Swordsmanship, Battle Aura, Aura Potential) with sword and
	spell damage previews from Shared/CombatMath, the Silent Casting Trial, the Spell
	Forge, Battles and the Family Grimoire. Trial and Forge are shielded popups.
]]

local RunService = game:GetService("RunService")

local Page = {}

local ctx, root, S, C, Arcana, Skills, CombatMath
local ui = {}
local state = nil
local selected = "Fire"

local function scale(x, y) return UDim2.fromScale(x, y) end

local function panel(name: string, x: number, w: number)
	local frame = S.panel("Frame", { Name = name, Position = scale(x, 0), Size = scale(w, 1), Parent = root }, C.panel1, C.panel2, 12)
	S.padding(frame, 10, 8)
	return frame
end

local function scroller(parent, y: number, h: number)
	local frame = S.new("ScrollingFrame", { Position = scale(0, y), Size = scale(1, h), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = C.stroke, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = parent })
	S.list(frame, UDim.new(0, 4))
	return frame
end

-- Genre words come from the theme (PackTheme terms); skill and stat names from config.
local function term(key: string): string
	return S.term(key)
end

local function skillName(id: string): string
	local skill = Skills.ById[id]
	return if skill then skill.Name else id
end

local function statName(id: string): string
	local stat = ctx.Config.Stats.Stats[id]
	return if stat then stat.Name else id
end

local function levelsOf(s)
	local levels = {}
	for stat, entry in s.Stats do
		levels[stat] = entry.Level
	end
	return levels
end

local function skillsOf(s)
	local out = {}
	for id, entry in (s.Modules.Skills and s.Modules.Skills.Levels) or {} do
		out[id] = entry.Level
	end
	return out
end

local function overlay(name: string, w: number, h: number)
	local shade = S.new("Frame", { Name = name, Size = scale(1, 1), BackgroundColor3 = C.ink, BackgroundTransparency = 0.3, BorderSizePixel = 0,
		ZIndex = 55, Visible = false, Parent = ctx.Gui })
	ctx.Shield.Attach(shade)
	local card = S.new("Frame", { Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = scale(0.5, 0.5), Size = scale(w, h), ZIndex = 56, Parent = shade })
	S.padding(card, 16, 12)
	ctx.Theme.frame(card, 14, C.panel1, C.bg2)
	local close = S.ghostButton({ Name = "Close", Text = "Close", Position = scale(0.82, 0), Size = scale(0.18, 0.1), ZIndex = 57, Parent = card }, 14)
	close:SetAttribute("TouchSafe", true) -- header button; a 44 px minimum covered the title on phones
	close.Activated:Connect(function() shade.Visible = false end)
	return shade, card
end

----------------------------------------------------------------------
-- Silent Casting Trial: press CAST while the spark is inside the glowing zone.
----------------------------------------------------------------------

local function buildTrial()
	local shade, card = overlay("SilentTrial", 0.5, 0.5)
	S.label({ Name = "Title", Text = "Silent Casting Trial", Font = S.Fonts.Title, TextColor3 = C.gold, Size = scale(0.8, 0.12), ZIndex = 57, Parent = card }, 24)
	local info = S.label({ Name = "Info", Text = "", TextColor3 = C.muted, Position = scale(0, 0.14), Size = scale(1, 0.14), ZIndex = 57, Parent = card }, 14)
	local track = S.new("Frame", { Name = "Track", Position = scale(0.05, 0.36), Size = scale(0.9, 0.12), BackgroundColor3 = C.inset, BorderSizePixel = 0, ZIndex = 57, Parent = card })
	S.new("UICorner", { CornerRadius = UDim.new(0, 6), Parent = track })
	local zone = S.new("Frame", { Name = "Zone", Size = scale(0.18, 1), BackgroundColor3 = C.qi1, BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 58, Parent = track })
	S.new("UIStroke", { Color = C.qi1, Thickness = 2, Parent = zone })
	local spark = S.new("Frame", { Name = "Spark", AnchorPoint = Vector2.new(0.5, 0.5), Position = scale(0, 0.5), Size = UDim2.new(0, 6, 1.4, 0),
		BackgroundColor3 = C.gold, BorderSizePixel = 0, ZIndex = 59, Parent = track })
	local tally = S.label({ Name = "Tally", Text = "", Font = S.Fonts.Heavy, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Center,
		Position = scale(0, 0.53), Size = scale(1, 0.12), ZIndex = 57, Parent = card }, 18)
	local cast = S.button({ Name = "Cast", Text = "CAST", Font = S.Fonts.Heavy, Position = scale(0.3, 0.72), Size = scale(0.4, 0.18), ZIndex = 57, Parent = card }, nil, nil, 20)
	local run = { Active = false }
	local function placeZone()
		zone.Position = scale(math.random() * 0.78 + 0.02, 0)
	end
	local function finish()
		run.Active = false
		ctx.Remotes.ArcanaAction:FireServer("SilentTrial", run.Hits)
		tally.Text = ("%d / %d landed"):format(run.Hits, Arcana.SilentTrial.Hits)
		task.delay(1.2, function() shade.Visible = false end)
	end
	cast.Activated:Connect(function()
		if not run.Active then
			return
		end
		local x = spark.Position.X.Scale
		local z = zone.Position.X.Scale
		if x >= z and x <= z + zone.Size.X.Scale then
			run.Hits += 1
		end
		run.Tries += 1
		tally.Text = ("%d hit%s  ·  %d tr%s left"):format(run.Hits, if run.Hits == 1 then "" else "s", 5 - run.Tries, if 5 - run.Tries == 1 then "y" else "ies")
		placeZone()
		if run.Hits >= Arcana.SilentTrial.Hits or run.Tries >= 5 then
			finish()
		end
	end)
	RunService.RenderStepped:Connect(function()
		if run.Active then
			local t = (os.clock() - run.Start) * (1.1 + run.Hits * 0.25)
			spark.Position = UDim2.fromScale((math.sin(t * math.pi) + 1) / 2, 0.5)
		end
	end)
	function ui.OpenTrial()
		info.Text = ("Land %d casts inside the glowing zone (5 tries). Success: %s cost -30%%, %s damage +20%% for life. One attempt a year."):format(
			Arcana.SilentTrial.Hits, string.lower(term("ManaName")), string.lower(skillName("Magic")))
		run = { Active = true, Hits = 0, Tries = 0, Start = os.clock() }
		tally.Text = "Focus..."
		placeZone()
		shade.Visible = true
	end
end

----------------------------------------------------------------------
-- Spell Forge
----------------------------------------------------------------------

local function buildForge()
	local shade, card = overlay("SpellForge", 0.62, 0.74)
	S.label({ Name = "Title", Text = "🔨 " .. term("SpellForgeName"), Font = S.Fonts.Title, TextColor3 = C.gold, Size = scale(0.7, 0.09), ZIndex = 57, Parent = card }, 24)
	S.label({ Name = "Hint", Text = ("Fuse one or two elements, choose a shape and a rank. Your spell enters the %s for every later generation."):format(term("GrimoireName")),
		TextColor3 = C.muted, Position = scale(0, 0.1), Size = scale(1, 0.08), ZIndex = 57, Parent = card }, 13)
	local pick = { Elements = {}, Shape = "Bolt", Rank = 1 }
	local rows = {}
	local function row(label: string, y: number)
		S.label({ Text = label, Font = S.Fonts.Heavy, TextColor3 = C.gold, Position = scale(0, y), Size = scale(0.16, 0.08), ZIndex = 57, Parent = card }, 12)
		local holder = S.new("Frame", { Position = scale(0.17, y), Size = scale(0.83, 0.08), BackgroundTransparency = 1, ZIndex = 57, Parent = card })
		S.list(holder, UDim.new(0, 4), true)
		return holder
	end
	local elementRow = row("ELEMENTS", 0.21)
	local elementRow2 = row("", 0.3)
	local shapeRow = row("SHAPE", 0.41)
	local rankRow = row("RANK", 0.52)
	local preview = S.label({ Name = "Preview", Text = "", RichText = true, TextColor3 = C.text, Position = scale(0, 0.63), Size = scale(1, 0.08), ZIndex = 57, Parent = card }, 15)
	local nameBox = S.new("TextBox", { Name = "Name", PlaceholderText = "Name your spell (optional)", Text = "", ClearTextOnFocus = false, Font = S.Fonts.Bold,
		TextScaled = true, TextColor3 = C.text, PlaceholderColor3 = C.muted, BackgroundColor3 = C.inset, Position = scale(0, 0.74), Size = scale(0.6, 0.09), ZIndex = 57, Parent = card })
	S.new("UICorner", { CornerRadius = UDim.new(0, 6), Parent = nameBox })
	S.new("UITextSizeConstraint", { MaxTextSize = 16, Parent = nameBox })
	local forge = S.button({ Name = "Forge", Text = "FORGE  ·  1 action", Font = S.Fonts.Heavy, Position = scale(0.62, 0.74), Size = scale(0.38, 0.09), ZIndex = 57, Parent = card }, nil, nil, 17)
	local status = S.label({ Name = "Status", Text = "", TextColor3 = C.red, Position = scale(0, 0.86), Size = scale(1, 0.08), ZIndex = 57, Parent = card }, 13)
	local function chip(parent, text: string, color: Color3?)
		local b = S.ghostButton({ Text = text, Size = UDim2.new(0.135, 0, 1, 0), ZIndex = 58, Parent = parent }, 13)
		if color then b.TextColor3 = color end
		return b
	end
	local function refresh()
		if not state then return end
		local data = state.Modules.Arcana or {}
		local magic = skillsOf(state).Magic or 0
		for _, entry in rows do
			local on
			if entry.Kind == "Element" then
				on = table.find(pick.Elements, entry.Id) ~= nil
			elseif entry.Kind == "Shape" then
				on = pick.Shape == entry.Id
			else
				on = pick.Rank == entry.Id
			end
			S.paint(entry.Button, if on then C.gold else C.card1, if on then C.gold2 else C.card2)
			entry.Button.TextColor3 = if on then C.dark elseif entry.Disabled then C.muted else (entry.Color or C.text)
		end
		local need = Arcana.RankAffinity[pick.Rank]
		local problems = {}
		if #pick.Elements == 0 then table.insert(problems, "pick an element") end
		if magic < need then table.insert(problems, ("needs %s %d"):format(skillName("Magic"), need)) end
		for _, id in pick.Elements do
			if ((data.Affinity or {})[id] or 0) < need then table.insert(problems, ("%s affinity %d"):format(id, need)) end
		end
		preview.Text = ("<b>%s %s of %s</b>%s"):format(Arcana.RankNames[pick.Rank], pick.Shape, if #pick.Elements > 0 then table.concat(pick.Elements, " & ") else "?",
			if #pick.Elements > 1 then ("  ·  fused x%.2f"):format(Arcana.Forge.FusionBonus) else "")
		status.Text = if #problems > 0 then "Not yet: " .. table.concat(problems, ", ") else ""
		S.setEnabled(forge, #problems == 0)
	end
	local i = 0
	for _, element in Arcana.AllElements do
		i += 1
		local b = chip(if i <= 5 then elementRow else elementRow2, element.Name, element.Color)
		local entry = { Kind = "Element", Id = element.Id, Button = b, Color = element.Color }
		table.insert(rows, entry)
		b.Activated:Connect(function()
			if entry.Disabled then return end
			local at = table.find(pick.Elements, element.Id)
			if at then
				table.remove(pick.Elements, at)
			elseif #pick.Elements < Arcana.Forge.MaxElements then
				table.insert(pick.Elements, element.Id)
			end
			refresh()
		end)
	end
	for _, shape in Arcana.Forge.Shapes do
		local b = chip(shapeRow, shape.Name)
		table.insert(rows, { Kind = "Shape", Id = shape.Id, Button = b })
		b.Activated:Connect(function() pick.Shape = shape.Id; refresh() end)
	end
	for rank, name in Arcana.RankNames do
		local b = chip(rankRow, name)
		table.insert(rows, { Kind = "Rank", Id = rank, Button = b })
		b.Activated:Connect(function() pick.Rank = rank; refresh() end)
	end
	forge.Activated:Connect(function()
		if forge.Active then
			ctx.Remotes.ArcanaAction:FireServer("Forge", { Elements = pick.Elements, Shape = pick.Shape, Rank = pick.Rank, Name = nameBox.Text })
			shade.Visible = false
		end
	end)
	function ui.OpenForge()
		local data = state and state.Modules.Arcana or {}
		for _, entry in rows do
			if entry.Kind == "Element" then
				local element = Arcana.ElementsById[entry.Id]
				entry.Disabled = element.Special and not (data.Special or {})[entry.Id]
			end
		end
		pick.Elements = {}
		refresh()
		shade.Visible = true
	end
end

----------------------------------------------------------------------

function Page.Init(context, frame)
	ctx, root = context, frame
	S = ctx.Style
	C = S.C
	Arcana = ctx.Content.Get("ArcanaConfig")
	Skills = ctx.Content.Get("SkillsConfig")
	CombatMath = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("CombatMath"))

	-- Left: mana and affinities.
	local left = panel("Affinities", 0, 0.3)
	ui.ManaText = S.label({ Name = "Mana", Text = "", Font = S.Fonts.Bold, TextColor3 = C.qi1, Size = scale(1, 0.06), Parent = left }, 14)
	local _, manaFill = S.bar({ Name = "ManaBar", Position = scale(0, 0.065), Size = scale(1, 0.03), Parent = left }, C.qi1)
	ui.ManaFill = manaFill
	ui.Collapse = S.label({ Name = "Collapse", Text = "", TextColor3 = C.muted, Position = scale(0, 0.1), Size = scale(1, 0.05), Parent = left }, 11)
	local list = scroller(left, 0.16, 0.84)
	ui.Elements = {}
	for i, element in Arcana.AllElements do
		if i == #Arcana.Elements + 1 then
			ui.SpecialHeader = S.autoLabel({ Name = "SpecialHeader", LayoutOrder = i, Text = "", Font = S.Fonts.Heavy, TextColor3 = C.gold, Parent = list }, 12)
		end
		local button = S.new("TextButton", { Name = element.Id, LayoutOrder = i + (if element.Special then 1 else 0), Text = "", AutoButtonColor = false,
			Size = UDim2.new(1, -4, 0, 34), BackgroundColor3 = C.card1, Parent = list })
		S.new("UICorner", { CornerRadius = UDim.new(0, 6), Parent = button })
		local stroke = S.new("UIStroke", { Color = element.Color, Thickness = 1, Transparency = 0.7, Parent = button })
		local label = S.label({ Name = "Label", Text = element.Icon .. "  " .. element.Name, Font = S.Fonts.Bold, TextColor3 = element.Color,
			Position = scale(0.04, 0.05), Size = scale(0.6, 0.5), Parent = button }, 13)
		local value = S.label({ Name = "Value", Text = "", TextXAlignment = Enum.TextXAlignment.Right, Position = scale(0.6, 0.05), Size = scale(0.36, 0.5), Parent = button }, 12)
		local _, fill = S.bar({ Name = "Bar", Position = scale(0.04, 0.66), Size = scale(0.92, 0.18), Parent = button }, element.Color)
		button.Activated:Connect(function()
			selected = element.Id
			if state then Page.Render(state) end
		end)
		ui.Elements[element.Id] = { Button = button, Stroke = stroke, Label = label, Value = value, Fill = fill, Element = element }
	end

	-- Middle: the spellbook.
	local middle = panel("Spellbook", 0.31, 0.36)
	ui.BookTitle = S.label({ Name = "Title", Text = "", Font = S.Fonts.Title, TextColor3 = C.gold, Size = scale(1, 0.07), Parent = middle }, 20)
	ui.BookHint = S.label({ Name = "Hint", Text = "Practice costs mana, not actions. Mastery 5 = chantless.", TextColor3 = C.muted, Position = scale(0, 0.075), Size = scale(1, 0.05), Parent = middle }, 11)
	local book = scroller(middle, 0.14, 0.86)
	ui.Spells = {}
	for rank = 1, #Arcana.RankNames do
		local row = S.panel("Frame", { Name = "Rank" .. rank, LayoutOrder = rank, Size = UDim2.new(1, -4, 0, 46), Parent = book }, C.card1, C.card2, 8)
		S.padding(row, 8, 4)
		local name = S.label({ Name = "Name", Text = "", Font = S.Fonts.Bold, Size = scale(0.66, 0.5), Parent = row }, 14)
		local sub = S.label({ Name = "Sub", Text = "", TextColor3 = C.muted, Position = scale(0, 0.52), Size = scale(0.66, 0.48), Parent = row }, 11)
		local practice = S.button({ Name = "Practice", Text = "Practice", Font = S.Fonts.Heavy, Position = scale(0.68, 0.08), Size = scale(0.32, 0.84), Parent = row }, nil, nil, 13)
		practice.Activated:Connect(function()
			if practice.Active then
				ctx.Remotes.ArcanaAction:FireServer("Practice", selected .. rank)
			end
		end)
		ui.Spells[rank] = { Name = name, Sub = sub, Practice = practice }
	end

	-- Right: the sword side, previews, trial, forge, battles, grimoire.
	local right = panel("Sword", 0.68, 0.32)
	S.label({ Name = "Title", Text = "⚔ " .. term("SwordAuraTitle"), Font = S.Fonts.Title, TextColor3 = C.gold, Size = scale(1, 0.07), Parent = right }, 20)
	ui.Sword = S.label({ Name = "SwordStats", Text = "", RichText = true, TextYAlignment = Enum.TextYAlignment.Top, Position = scale(0, 0.08), Size = scale(1, 0.2), Parent = right }, 13)
	ui.Trial = S.button({ Name = "Trial", Text = "", Font = S.Fonts.Bold, Position = scale(0, 0.3), Size = scale(1, 0.08), Parent = right }, nil, nil, 13)
	ui.Forge = S.button({ Name = "ForgeButton", Text = "🔨 " .. term("SpellForgeName"), Font = S.Fonts.Bold, Position = scale(0, 0.4), Size = scale(0.49, 0.08), Parent = right }, nil, nil, 13)
	ui.Battles = S.button({ Name = "Battles", Text = "⚔ " .. term("BattlesName"), Font = S.Fonts.Bold, Position = scale(0.51, 0.4), Size = scale(0.49, 0.08), Parent = right }, C.crimson1, C.crimson2, 13, C.text)
	ui.Trial.Activated:Connect(function() if ui.Trial.Active then ui.OpenTrial() end end)
	ui.Forge.Activated:Connect(function() if ui.Forge.Active then ui.OpenForge() end end)
	ui.Battles.Activated:Connect(function() if ctx.OpenBattles then ctx.OpenBattles() end end)
	ui.ForgeHint = S.label({ Name = "ForgeHint", Text = "", TextColor3 = C.muted, Position = scale(0, 0.49), Size = scale(1, 0.05), Parent = right }, 11)
	S.label({ Name = "GrimoireTitle", Text = string.upper(term("GrimoireName")), Font = S.Fonts.Heavy, TextColor3 = C.gold, Position = scale(0, 0.55), Size = scale(1, 0.05), Parent = right }, 12)
	ui.Grimoire = scroller(right, 0.61, 0.39)

	buildTrial()
	buildForge()
end

local function renderGrimoire(s, data)
	for _, child in ui.Grimoire:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local entries = s.Grimoire or {}
	if #entries == 0 then
		S.autoLabel({ Text = "Empty. Spells you forge are kept here for every later generation.", TextColor3 = C.muted, Parent = ui.Grimoire }, 12)
		return
	end
	for i = #entries, 1, -1 do
		local entry = entries[i]
		local known = (data.Custom or {})[entry.Id] or (data.Learned or {})[entry.Id]
		local row = S.panel("Frame", { LayoutOrder = #entries - i, Size = UDim2.new(1, -4, 0, 40), Parent = ui.Grimoire }, C.card1, C.card2, 6)
		S.padding(row, 6, 3)
		S.label({ Text = entry.Name .. (if entry.Taught then "  ★" else ""), Font = S.Fonts.Bold, TextColor3 = if entry.Taught then C.gold else C.text, Size = scale(0.66, 0.5), Parent = row }, 12)
		S.label({ Text = ("%s · by %s, life %d%s"):format(Arcana.RankNames[entry.Rank] or "?", entry.Creator or "?", entry.Life or 0, if entry.Taught then " · taught in academies" else ""),
			TextColor3 = C.muted, Position = scale(0, 0.5), Size = scale(0.66, 0.5), Parent = row }, 10)
		local learn = S.button({ Text = if known then "Known" elseif entry.Taught then "Learn (free)" else "Learn · 1 action", Font = S.Fonts.Bold,
			Position = scale(0.68, 0.1), Size = scale(0.32, 0.8), Parent = row }, nil, nil, 11)
		S.setEnabled(learn, not known and not s.Dead)
		learn.Activated:Connect(function()
			if learn.Active then ctx.Remotes.ArcanaAction:FireServer("Learn", entry.Id) end
		end)
	end
end

function Page.Render(s)
	state = s
	local data = (s.Modules and s.Modules.Arcana) or {}
	local affinity = data.Affinity or {}
	local levels, skills = levelsOf(s), skillsOf(s)
	local open = Skills.CombatOpenAge - (s.TrainingAgeOffset or 0)
	ui.ManaText.Text = ("%s  %d / %d"):format(string.upper(term("ManaName")), math.floor(data.Mana or 0), data.MaxMana or 0)
	S.setBar(ui.ManaFill, (data.Mana or 0) / math.max(1, data.MaxMana or 1))
	local mana = string.lower(term("ManaName"))
	ui.Collapse.Text = if data.CollapseAge == s.Age then ("Collapsed this year: %s returns next year."):format(mana)
		else ("Empty your %s in practice to Collapse: max %s +%d at your age."):format(mana, mana, Arcana.CollapseGain(s.Age))
	local openSchools = 0
	for id, entry in ui.Elements do
		local element = entry.Element
		local isOpen = not element.Special or (data.Special or {})[id]
		if element.Special and isOpen then openSchools += 1 end
		entry.Value.Text = if isOpen then tostring(math.floor(affinity[id] or 0)) else ("%s %d"):format(skillName("Knowledge"), element.Knowledge)
		S.setBar(entry.Fill, if isOpen then (affinity[id] or 0) / 100 else 0)
		entry.Label.TextColor3 = if isOpen then element.Color else C.muted
		entry.Stroke.Transparency = if id == selected then 0 else 0.7
		entry.Button.BackgroundColor3 = if id == selected then C.card2 else C.card1
	end
	ui.SpecialHeader.Text = ("%s  (%d/%d)"):format(term("SpecialSchoolsName"), openSchools, #Arcana.SpecialSchools)

	local element = Arcana.ElementsById[selected]
	local elementOpen = not element.Special or (data.Special or {})[selected]
	ui.BookTitle.Text = element.Icon .. "  " .. element.Name .. " " .. term("SpellbookName")
	ui.BookTitle.TextColor3 = element.Color
	local buffs = { ManaCostMult = if data.SilentCasting then Arcana.SilentTrial.Buffs.ManaCostMult else 1,
		MagicDamageMult = if data.SilentCasting then Arcana.SilentTrial.Buffs.MagicDamageMult else 1 }
	for rank, row in ui.Spells do
		local spell = Arcana.SpellsById[selected .. rank]
		local can = elementOpen and (affinity[selected] or 0) >= spell.Affinity
		local mastery = (data.Mastery or {})[spell.Id]
		local level = mastery and mastery.Level or 0
		local chantless = level >= Arcana.MaxMastery
		local cost = CombatMath.ManaCost(spell.ManaCost, levels, buffs)
		row.Name.Text = ("%s  ·  %s"):format(spell.RankName, spell.Name)
		row.Name.TextColor3 = if can then (if chantless then C.gold else C.text) else C.muted
		row.Sub.Text = if not can then ("Needs %s affinity %d"):format(element.Name, spell.Affinity)
			else ("Mastery %d/%d%s  ·  %d %s  ·  %s %d"):format(level, Arcana.MaxMastery, if chantless then "  ·  CHANTLESS" else "", cost, string.lower(term("ManaName")),
				if spell.Heals then "heals" else "hits", CombatMath.MagicDamage(levels, skills, rank, affinity[selected] or 0, buffs))
		S.setEnabled(row.Practice, can and not s.Dead and s.Age >= open and (data.Mana or 0) > 0)
		row.Practice.Text = if s.Age < open then ("Age %d"):format(open) else "Practice"
	end

	local sword = CombatMath.SwordDamage(levels, skills)
	local swordSkill = skills.Swordsmanship or 0
	ui.Sword.Text = ("%s <b>%s</b> (Lv %d)\n%s %d  ·  %s %d\n<font color=\"#%s\">Sword hit ~%d</font>  (%s, %s, %s, skill)\n<font color=\"#%s\">Best spell ~%d</font>  (%s, %s, %s, affinity)"):format(
		skillName("Swordsmanship"), Skills.Rank(swordSkill).Name, swordSkill, statName("BattleAura"), levels.BattleAura or 0, statName("AuraPotential"), levels.AuraPotential or 0, C.gold:ToHex(), sword,
		statName("Strength"), statName("Agility"), statName("BattleAura"), C.qi1:ToHex(),
		CombatMath.MagicDamage(levels, skills, 1, affinity[data.Favored or "Fire"] or 0, buffs), statName("MagicPower"), statName("MagicControl"), skillName("Magic"))
	local control = levels.MagicControl or 0
	local trial = Arcana.SilentTrial
	local trialName = term("SilentTrialName")
	ui.Trial.Text = if data.SilentCasting then "✔ " .. term("SilentMasteredName")
		elseif control < trial.MagicControl then ("%s  ·  %s %d/%d"):format(trialName, statName("MagicControl"), control, trial.MagicControl)
		elseif data.SilentTrialAge == s.Age then trialName .. "  ·  next year"
		else "▶ " .. trialName
	S.setEnabled(ui.Trial, not data.SilentCasting and control >= trial.MagicControl and data.SilentTrialAge ~= s.Age and not s.Dead)
	local forge = Arcana.Forge
	local reasons = {}
	if s.Age < forge.Age then table.insert(reasons, ("age %d"):format(forge.Age)) end
	if (skills.Magic or 0) < forge.MagicSkill then table.insert(reasons, ("%s %d"):format(skillName("Magic"), forge.MagicSkill)) end
	if (skills.Knowledge or 0) < forge.KnowledgeSkill then table.insert(reasons, ("%s %d"):format(skillName("Knowledge"), forge.KnowledgeSkill)) end
	S.setEnabled(ui.Forge, #reasons == 0 and data.ForgeAge ~= s.Age and not s.Dead)
	ui.ForgeHint.Text = if #reasons > 0 then term("SpellForgeName") .. " needs " .. table.concat(reasons, ", ") elseif data.ForgeAge == s.Age then "The forge cools until next year." else "The forge is ready."
	ui.Battles.Visible = ctx.GamePack.IsActive("Battle")
	renderGrimoire(s, data)
end

return Page
