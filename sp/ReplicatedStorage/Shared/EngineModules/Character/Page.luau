--[[
	Character tab (client; Modules/CharacterSystem).
	Left: Your Path (Hero / Neutral / Villain and the morality bar), birthplace, social
	class, upbringing and echoes of the past life.
	Middle: Family Genetics: FATHER and MOTHER stat cards and what you inherited.
	Right: the 10 personality sliders, Trait Fusion (n/23 recipes) and 4 hidden talents.
]]

local Page = {}

local ctx, root, S, C, Character, Stats, Talents
local ui = {}
local state = nil
local picked = {}

local function scale(x, y) return UDim2.fromScale(x, y) end

local function column(name: string, x: number, w: number)
	local frame = S.panel("Frame", { Name = name, Position = scale(x, 0), Size = scale(w, 1), Parent = root }, C.panel1, C.panel2, 12)
	S.padding(frame, 10, 8)
	local scroll = S.new("ScrollingFrame", { Name = "Scroll", Size = scale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = C.stroke, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = frame })
	S.list(scroll, UDim.new(0, 6))
	return scroll
end

local function heading(parent, order: number, text: string)
	return S.autoLabel({ LayoutOrder = order, Text = text, Font = S.Fonts.Heavy, TextColor3 = C.gold, Parent = parent }, 12)
end

local function box(parent, order: number)
	local frame = S.panel("Frame", { LayoutOrder = order, Size = UDim2.new(1, -4, 0, 0), Parent = parent }, C.card1, C.card2, 8)
	S.fit(frame)
	local label = S.autoLabel({ Name = "Text", Text = "", RichText = true, Parent = frame }, 13)
	return label
end

local function buffLine(buffs): string
	local parts = {}
	for key, value in buffs or {} do
		if type(value) == "table" then
			for sub, mult in value do
				table.insert(parts, ("%s %s x%.2f"):format(sub, key == "SkillXp" and "skill" or "XP", mult))
			end
		elseif key:find("Mult") then
			table.insert(parts, ("%s x%.2f"):format(key:gsub("Mult", ""), value))
		else
			table.insert(parts, ("%s %+g"):format(key, value))
		end
	end
	return table.concat(parts, ", ")
end

function Page.Init(context, frame)
	ctx, root = context, frame
	S = ctx.Style
	C = S.C
	Character = ctx.Content.Get("CharacterConfig")
	Stats = ctx.Config.Stats
	Talents = ctx.Config.Talents

	-- Left: path, origins, upbringing, echoes.
	local left = column("Path", 0, 0.3)
	heading(left, 1, "YOUR PATH")
	ui.PathName = S.autoLabel({ LayoutOrder = 2, Text = "", Font = S.Fonts.Title, Parent = left }, 26)
	local meter = S.new("Frame", { LayoutOrder = 3, Size = UDim2.new(1, -4, 0, 12), BackgroundColor3 = C.inset, BorderSizePixel = 0, Parent = left })
	S.new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.red), ColorSequenceKeypoint.new(0.5, C.muted), ColorSequenceKeypoint.new(1, C.green) }), Parent = meter })
	S.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = meter })
	ui.PathMarker = S.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = scale(0.5, 0.5), Size = UDim2.fromOffset(6, 18), BackgroundColor3 = C.text, BorderSizePixel = 0, Parent = meter })
	ui.PathText = S.autoLabel({ LayoutOrder = 4, Text = "", TextColor3 = C.muted, Parent = left }, 12)
	heading(left, 5, "ORIGINS")
	ui.Origins = box(left, 6)
	heading(left, 7, "UPBRINGING")
	ui.Upbringing = box(left, 8)
	heading(left, 9, "ECHOES OF A PAST LIFE")
	ui.Echoes = box(left, 10)
	heading(left, 11, "BONDS")
	ui.Bonds = box(left, 12)

	-- Middle: parents.
	local middle = column("Genetics", 0.31, 0.34)
	heading(middle, 1, "FAMILY GENETICS")
	ui.Father = box(middle, 2)
	ui.Mother = box(middle, 3)
	heading(middle, 4, "WHAT YOU INHERITED")
	ui.Inherited = box(middle, 5)

	-- Right: personality, fusion, hidden talents.
	local right = column("Personality", 0.66, 0.34)
	heading(right, 1, "PERSONALITY")
	ui.Sliders = {}
	for i, slider in Character.Sliders do
		local row = S.new("Frame", { LayoutOrder = 1 + i, Size = UDim2.new(1, -4, 0, 30), BackgroundTransparency = 1, Parent = right })
		local left = S.label({ Text = slider.Left or "", TextColor3 = C.muted, Size = scale(0.3, 0.5), Parent = row }, 11)
		local rightLabel = S.label({ Text = slider.Right, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Right, Position = scale(0.7, 0), Size = scale(0.3, 0.5), Parent = row }, 11)
		local track = S.new("Frame", { Position = scale(0, 0.6), Size = scale(1, 0.25), BackgroundColor3 = C.inset, BorderSizePixel = 0, Parent = row })
		S.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
		if not slider.Unipolar then
			S.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = scale(0.5, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = C.muted, BorderSizePixel = 0, Parent = track })
		end
		local marker = S.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = scale(0.5, 0.5), Size = UDim2.fromOffset(8, 14), BackgroundColor3 = C.gold, BorderSizePixel = 0, Parent = track })
		S.new("UICorner", { CornerRadius = UDim.new(0, 3), Parent = marker })
		ui.Sliders[slider.Id] = { Left = left, Right = rightLabel, Marker = marker, Slider = slider }
	end
	heading(right, 20, "TRAIT FUSION")
	ui.FusionInfo = S.autoLabel({ LayoutOrder = 21, Text = "", TextColor3 = C.muted, Parent = right }, 12)
	ui.Traits = S.new("Frame", { LayoutOrder = 22, Size = UDim2.new(1, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = right })
	S.new("UIGridLayout", { CellSize = UDim2.new(0.5, -3, 0, 30), CellPadding = UDim2.fromOffset(4, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = ui.Traits })
	ui.Fuse = S.button({ LayoutOrder = 23, Name = "Fuse", Text = "🧪 Fuse the two selected traits", Font = S.Fonts.Heavy, Size = UDim2.new(1, -4, 0, 34), Parent = right }, nil, nil, 14)
	ui.Fuse.Activated:Connect(function()
		if ui.Fuse.Active and #picked == 2 then
			ctx.Remotes.CharacterAction:FireServer("Fuse", picked[1], picked[2])
			picked = {}
		end
	end)
	heading(right, 30, "HIDDEN TALENTS")
	ui.Hidden = box(right, 31)
end

local function statCard(label, title: string, parent)
	if not parent then
		label.Text = title .. "\n—"
		return
	end
	local lines = { ("<b>%s</b>  ·  %s"):format(title, S.escape(parent.Name or "?")) }
	local row = {}
	for _, stat in Stats.Order do
		local def = Stats.Stats[stat]
		local level = parent.Attributes[stat] or 0
		table.insert(row, ("<font color=\"#%s\">%s</font> %d"):format(def.Color:ToHex(), def.Short or stat, level))
		if #row == 3 then
			table.insert(lines, table.concat(row, "   "))
			row = {}
		end
	end
	if #row > 0 then table.insert(lines, table.concat(row, "   ")) end
	label.Text = table.concat(lines, "\n")
end

function Page.Render(s)
	state = s
	local data = (s.Modules and s.Modules.Character) or {}
	local alignment = s.Alignment or 0
	local path = Character.PathName(alignment)
	ui.PathName.Text = path
	ui.PathName.TextColor3 = if path == "Hero" then C.green elseif path == "Villain" then C.red else C.text
	ui.PathMarker.Position = scale(math.clamp((alignment + 20) / 40, 0, 1), 0.5)
	ui.PathText.Text = ("Morality %+d  ·  Hero at %+d, Villain at %d"):format(alignment, Character.Path.HeroAt, Character.Path.VillainAt)

	local world = s.Modules and s.Modules.World
	local regions = ctx.Config.Regions
	local region = world and world.Region and regions and regions.Get and regions.Get(world.Region)
	local history = ctx.Content.Get("HistoryConfig")
	local birth = s.Modules and s.Modules.Birth or {}
	local class = history.ClassesById[birth.Class or ""]
	local anomaly = history.AnomaliesById[birth.Anomaly or ""]
	ui.Origins.Text = ("Birthplace: <b>%s</b>\nBorn: <b>%s</b>  ·  now %s\n%s%s"):format(if region then region.Name else "Home",
		if class then class.Name else "-", s.SocialStatus or "-", s.Race,
		if anomaly then ("\n<font color=\"#%s\"><b>%s</b></font>\n%s"):format(C.gold:ToHex(), anomaly.Name, anomaly.Description) else "")
	local upbringing = Character.UpbringingsById[data.Upbringing or ""]
	ui.Upbringing.Text = if upbringing then ("<b>%s</b>\n%s\n<font color=\"#%s\">%s</font>"):format(upbringing.Name, upbringing.Description, C.qi1:ToHex(), buffLine(upbringing.Buffs)) else "—"
	local last = s.Lineage and s.Lineage[1] -- newest first
	ui.Echoes.Text = if last then ("<b>%s</b> (life %s) died at %s: %s"):format(S.escape(last.Name or "?"), tostring(last.Life or "?"), tostring(last.Age or "?"), S.escape(last.Cause or ""))
		else "No echoes yet. This is your first life."

	-- Bonds grow by talking, training together and gifts (Social points, Bonds tab).
	local bonds = {}
	for _, rel in s.Relationships or {} do
		if rel.Alive ~= false and rel.Bond and rel.Bond.Level > 0 then
			table.insert(bonds, ("%s (%s)  -  bond %d"):format(S.escape(rel.Name), rel.Type, rel.Bond.Level))
		end
	end
	ui.Bonds.Text = if #bonds > 0 then table.concat(bonds, "\n") .. "\nFamily bonds speed growth, friends help socially, partner and children add health."
		else ("No bonds yet. Spend Social points (%d/%d) to talk, train together or give gifts."):format(s.Social or 0, s.MaxSocial or 0)
	statCard(ui.Father, "FATHER", data.Parents and data.Parents.Father)
	statCard(ui.Mother, "MOTHER", data.Parents and data.Parents.Mother)
	local inherited = {}
	for _, stat in Stats.Order do
		local entry = (data.Inherited or {})[stat]
		if entry and entry.Levels and entry.Levels > 0 then
			table.insert(inherited, ("%s +%d levels at birth"):format(Stats.Stats[stat].Name, entry.Levels))
		elseif entry and entry.Mult and entry.Mult ~= 1 then
			table.insert(inherited, ("<font color=\"#%s\">%s XP x%.2f</font>"):format((if entry.Mult > 1 then C.green else C.red):ToHex(), Stats.Stats[stat].Name, entry.Mult))
		end
	end
	ui.Inherited.Text = if #inherited > 0 then table.concat(inherited, "\n") else "Nothing remarkable."

	local threshold = Character.Threshold
	for id, row in ui.Sliders do
		local value = (data.Personality or {})[id] or 0
		local slider = row.Slider
		row.Marker.Position = scale(if slider.Unipolar then value / 100 else (value + 100) / 200, 0.5)
		row.Right.TextColor3 = if value >= threshold then C.gold else C.muted
		row.Left.TextColor3 = if not slider.Unipolar and value <= -threshold then C.gold else C.muted
	end

	-- Trait Fusion: traits as toggles (two at a time).
	local discovered = 0
	for _ in s.FusionDiscovered or {} do discovered += 1 end
	local minAge = Character.Fusion.MinAge
	ui.FusionInfo.Text = ("%d/%d recipes discovered  ·  once a year from age %d  ·  same rarity without a recipe = wild fusion"):format(discovered, #Character.Recipes, minAge)
	for _, child in ui.Traits:GetChildren() do
		if child:IsA("GuiButton") then child:Destroy() end
	end
	local traits = {}
	for _, id in s.Talents or {} do
		local talent = Talents.Get(id)
		if talent then table.insert(traits, { Key = "T:" .. id, Name = talent.Name, Rarity = talent.Rarity }) end
	end
	for _, slot in data.Hidden or {} do
		local def = Character.HiddenById[slot.Id]
		if def and slot.Revealed and not slot.Fused then table.insert(traits, { Key = "H:" .. def.Id, Name = def.Name, Rarity = def.Rarity }) end
	end
	for i = #picked, 1, -1 do
		local still = false
		for _, trait in traits do if trait.Key == picked[i] then still = true end end
		if not still then table.remove(picked, i) end
	end
	for i, trait in traits do
		local on = table.find(picked, trait.Key) ~= nil
		local chip = S.button({ LayoutOrder = i, Text = ("%s  ·  %s"):format(trait.Name, trait.Rarity), Font = S.Fonts.Bold, Parent = ui.Traits },
			if on then C.gold else C.card1, if on then C.gold2 else C.card2, 12, if on then C.dark else C.text)
		chip.Activated:Connect(function()
			local at = table.find(picked, trait.Key)
			if at then table.remove(picked, at) elseif #picked < 2 then table.insert(picked, trait.Key) end
			Page.Render(state)
		end)
	end
	if #traits == 0 then
		S.autoLabel({ Text = "No traits to fuse yet: talents and revealed hidden talents appear here.", TextColor3 = C.muted, Parent = ui.Traits }, 11)
	end
	local can = #picked == 2 and s.Age >= minAge and data.FusionAge ~= s.Age and not s.Dead
	S.setEnabled(ui.Fuse, can)
	ui.Fuse.Text = if s.Age < minAge then ("Trait Fusion opens at age %d"):format(minAge)
		elseif data.FusionAge == s.Age then "Fused this year"
		else ("🧪 Fuse the two selected traits (%d/2)"):format(#picked)

	local hidden = {}
	for _, slot in data.Hidden or {} do
		local def = Character.HiddenById[slot.Id]
		if slot.Revealed and def then
			table.insert(hidden, ("<b>%s</b>%s  ·  %s"):format(def.Name, if slot.Fused then " (fused)" else "", def.Description))
		else
			table.insert(hidden, "????????")
		end
	end
	local fused = {}
	for _, entry in data.Fused or {} do table.insert(fused, entry.Name) end
	ui.Hidden.Text = table.concat(hidden, "\n") .. (if #fused > 0 then "\n\nFused this life: " .. table.concat(fused, ", ") else "")
end

return Page
