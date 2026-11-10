--[[
	BattleModal: battles (BattleConfig; Modules/BattleSystem via BattleAction).
	List view: only enemies you can fight here (or beat already) and the single next
	target. Fight view: your HP and mana against the enemy, the battle log, and Attack
	(sword), Cast (spell picker; a spell that is not chantless asks for a Z / X / C / V
	key chant, tappable on touch screens), Guard, Flee and the once-per-battle signature
	move. A diagonal VS banner with speed lines opens every fight.
	Init(ctx), Open(), Render(snapshot).
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Modal = {}

local ctx, S, C, Battle, Arcana, CombatMath
local ui = {}
local state = nil
local shownFight = nil -- enemy id whose VS banner already played
local chant = nil -- { Keys, At, Deadline, SpellId }

local function scale(x, y) return UDim2.fromScale(x, y) end

local function act(action, arg, chantOk)
	ctx.Remotes.BattleAction:FireServer(action, arg, chantOk)
end

----------------------------------------------------------------------
-- VS banner
----------------------------------------------------------------------

local function playBanner(enemy)
	local banner = ui.Banner
	banner.Visible = true
	ui.BannerLeft.Text = S.escape(state and state.Name or "You")
	ui.BannerRight.Text = enemy.Icon .. "  " .. enemy.Name
	ui.Band.Position = scale(-0.6, 0.5)
	TweenService:Create(ui.Band, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = scale(0.5, 0.5) }):Play()
	ui.VS.TextTransparency, ui.VSScale.Scale = 1, 2.4
	TweenService:Create(ui.VS, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
	TweenService:Create(ui.VSScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	for i, line in ui.Speed do
		line.Position = scale(1.2 + (i % 4) * 0.1, (i / #ui.Speed))
		TweenService:Create(line, TweenInfo.new(0.45 + (i % 3) * 0.12, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 2), { Position = scale(-0.4, i / #ui.Speed) }):Play()
	end
	task.delay(1.4, function()
		TweenService:Create(ui.Band, TweenInfo.new(0.25), { Position = scale(1.6, 0.5) }):Play()
		task.wait(0.25)
		banner.Visible = false
	end)
end

local function buildBanner(parent)
	local banner = S.new("Frame", { Name = "VSBanner", Size = scale(1, 1), BackgroundColor3 = C.ink, BackgroundTransparency = 0.4, ZIndex = 80,
		ClipsDescendants = true, Visible = false, Parent = parent })
	ui.Speed = {}
	for i = 1, 14 do
		ui.Speed[i] = S.new("Frame", { Name = "Speed" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0.5, 0, 0, 2), Rotation = -12,
			BackgroundColor3 = C.text, BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 81, Parent = banner })
	end
	local band = S.new("Frame", { Name = "Band", AnchorPoint = Vector2.new(0.5, 0.5), Position = scale(0.5, 0.5), Size = scale(1.6, 0.3), Rotation = -12,
		BackgroundColor3 = C.crimson1, BorderSizePixel = 0, ZIndex = 82, Parent = banner })
	S.new("UIGradient", { Color = ColorSequence.new(C.crimson1, C.crimson2), Parent = band })
	S.new("UIStroke", { Color = C.gold, Thickness = 3, Parent = band })
	ui.BannerLeft = S.label({ Name = "Left", Text = "", Font = S.Fonts.Title, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Right,
		Position = scale(0.32, 0.25), Size = scale(0.14, 0.5), ZIndex = 83, Parent = band }, 34)
	ui.BannerRight = S.label({ Name = "Right", Text = "", Font = S.Fonts.Title, TextColor3 = C.text, Position = scale(0.54, 0.25),
		Size = scale(0.16, 0.5), ZIndex = 83, Parent = band }, 34)
	ui.VS = S.label({ Name = "VS", Text = "VS", Font = S.Fonts.Heavy, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Center,
		Position = scale(0.465, 0.05), Size = scale(0.07, 0.9), ZIndex = 84, Parent = band }, 90)
	S.new("UIStroke", { Color = C.ink, Thickness = 3, Parent = ui.VS })
	ui.VSScale = S.new("UIScale", { Parent = ui.VS })
	ui.Band, ui.Banner = band, banner
end

----------------------------------------------------------------------
-- Key chant
----------------------------------------------------------------------

local function endChant(ok: boolean)
	if not chant then return end
	local spellId = chant.SpellId
	chant = nil
	ui.Chant.Visible = false
	act("Cast", spellId, ok)
end

local function pressKey(key: string)
	if not chant then return end
	if chant.Keys[chant.At] == key then
		chant.At += 1
		if chant.At > #chant.Keys then
			endChant(true)
			return
		end
	else
		endChant(false)
		return
	end
	local shown = {}
	for i, k in chant.Keys do
		table.insert(shown, if i < chant.At then ("<font color=\"#%s\">%s</font>"):format(C.green:ToHex(), k) else k)
	end
	ui.ChantKeys.Text = table.concat(shown, "  ")
end

local function startChant(spellId: string)
	local keys = {}
	for i = 1, Battle.Chant.Length do
		keys[i] = Battle.Chant.Keys[math.random(1, #Battle.Chant.Keys)]
	end
	chant = { Keys = keys, At = 1, Deadline = os.clock() + Battle.Chant.Seconds, SpellId = spellId }
	ui.ChantKeys.Text = table.concat(keys, "  ")
	ui.Chant.Visible = true
	ui.Spells.Visible = false
	local token = chant
	task.spawn(function()
		while chant == token and os.clock() < token.Deadline do
			ui.ChantTime.Text = ("Chant!  %.1fs"):format(token.Deadline - os.clock())
			task.wait(0.05)
		end
		if chant == token then endChant(false) end
	end)
end

----------------------------------------------------------------------

local function bar(parent, name: string, y: number, color: Color3)
	local label = S.label({ Name = name .. "Text", Text = "", Font = S.Fonts.Bold, Position = scale(0, y), Size = scale(1, 0.12), ZIndex = 63, Parent = parent }, 14)
	local _, fill = S.bar({ Name = name, Position = scale(0, y + 0.13), Size = scale(1, 0.08), ZIndex = 63, Parent = parent }, color)
	return label, fill
end

function Modal.Init(context)
	ctx = context
	S = ctx.Style
	C = S.C
	Battle = ctx.Content.Get("BattleConfig")
	Arcana = ctx.Content.Get("ArcanaConfig")
	CombatMath = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("CombatMath"))
	local overlay = S.new("Frame", { Name = "BattleModal", Size = scale(1, 1), BackgroundColor3 = C.ink, BackgroundTransparency = 0.2, BorderSizePixel = 0,
		ZIndex = 60, Visible = false, Parent = ctx.Gui })
	ctx.Shield.Attach(overlay)
	local card = S.new("Frame", { Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = scale(0.5, 0.5), Size = scale(0.8, 0.84), ZIndex = 61, Parent = overlay })
	S.padding(card, 16, 12)
	ctx.Theme.frame(card, 14, C.panel1, C.bg2)
	ui.Title = S.label({ Name = "Title", Text = "⚔ " .. S.term("BattlesName"), Font = S.Fonts.Title, TextColor3 = C.gold, Size = scale(0.7, 0.08), ZIndex = 62, Parent = card }, 26)
	ui.Close = S.ghostButton({ Name = "Close", Text = "Close", Position = scale(0.84, 0), Size = scale(0.16, 0.08), ZIndex = 62, Parent = card }, 14)
	ui.Close:SetAttribute("TouchSafe", true) -- header button; a 44 px minimum covered the title on phones
	ui.Close.Activated:Connect(function()
		if not (state and state.Modules.Battle and state.Modules.Battle.Active) then overlay.Visible = false end
	end)

	-- List view.
	ui.List = S.new("ScrollingFrame", { Name = "Enemies", Position = scale(0, 0.1), Size = scale(1, 0.9), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = C.stroke, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 62, Parent = card })
	S.list(ui.List, UDim.new(0, 6))

	-- Fight view.
	local fight = S.new("Frame", { Name = "Fight", Position = scale(0, 0.1), Size = scale(1, 0.9), BackgroundTransparency = 1, Visible = false, ZIndex = 62, Parent = card })
	local you = S.panel("Frame", { Name = "You", Size = scale(0.42, 0.34), ZIndex = 62, Parent = fight }, C.card1, C.card2, 10, C.qi1)
	S.padding(you, 10, 8)
	ui.YouName = S.label({ Text = "", Font = S.Fonts.Title, TextColor3 = C.qi1, Size = scale(1, 0.2), ZIndex = 63, Parent = you }, 18)
	ui.YouHP, ui.YouHPFill = bar(you, "HP", 0.25, C.green)
	ui.YouMana, ui.YouManaFill = bar(you, "Mana", 0.6, C.qi1) -- instance name; the text uses the ManaName term
	local foe = S.panel("Frame", { Name = "Enemy", Position = scale(0.58, 0), Size = scale(0.42, 0.34), ZIndex = 62, Parent = fight }, C.card1, C.card2, 10, C.crimson1)
	S.padding(foe, 10, 8)
	ui.FoeName = S.label({ Text = "", Font = S.Fonts.Title, TextColor3 = C.red, Size = scale(1, 0.2), ZIndex = 63, Parent = foe }, 18)
	ui.FoeHP, ui.FoeHPFill = bar(foe, "EnemyHP", 0.25, C.red)
	S.label({ Text = "VS", Font = S.Fonts.Heavy, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Center, Position = scale(0.42, 0.08), Size = scale(0.16, 0.18), ZIndex = 63, Parent = fight }, 34)
	ui.Log = S.label({ Name = "Log", Text = "", RichText = true, TextYAlignment = Enum.TextYAlignment.Top, Position = scale(0, 0.37), Size = scale(1, 0.3), ZIndex = 63, Parent = fight }, 14)
	local function cmd(name: string, text: string, x: number, w: number, c1, c2, textColor)
		local b = S.button({ Name = name, Text = text, Font = S.Fonts.Heavy, Position = scale(x, 0.7), Size = scale(w, 0.13), ZIndex = 63, Parent = fight }, c1, c2, 15, textColor)
		return b
	end
	ui.Attack = cmd("Attack", "⚔ Attack", 0, 0.19)
	ui.Cast = cmd("Cast", "✨ Cast", 0.2, 0.19, C.qi2, C.jade2, C.text)
	ui.Guard = cmd("Guard", "🛡 Guard", 0.4, 0.19, C.card1, C.card2, C.text)
	ui.Flee = cmd("Flee", "Flee", 0.6, 0.12, C.card1, C.card2, C.text)
	ui.Signature = cmd("Signature", "", 0.73, 0.27, C.crimson1, C.crimson2, C.text)
	ui.Hint = S.label({ Name = "Hint", Text = "", TextColor3 = C.muted, Position = scale(0, 0.85), Size = scale(1, 0.06), ZIndex = 63, Parent = fight }, 12)
	ui.Attack.Activated:Connect(function() act("Attack") end)
	ui.Guard.Activated:Connect(function() act("Guard") end)
	ui.Flee.Activated:Connect(function() act("Flee") end)
	ui.Signature.Activated:Connect(function() if ui.Signature.Active then act("Signature") end end)
	ui.Cast.Activated:Connect(function() if ui.Cast.Active then ui.Spells.Visible = not ui.Spells.Visible end end)

	-- Spell picker and chant overlay.
	ui.Spells = S.new("ScrollingFrame", { Name = "Spells", Position = scale(0.2, 0.15), Size = scale(0.6, 0.53), BackgroundColor3 = C.bg2, BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false, ZIndex = 70, Parent = fight })
	S.new("UIStroke", { Color = C.qi1, Thickness = 1.5, Parent = ui.Spells })
	S.list(ui.Spells, UDim.new(0, 4))
	S.new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 6), Parent = ui.Spells })
	ui.Chant = S.panel("Frame", { Name = "Chant", Position = scale(0.2, 0.2), Size = scale(0.6, 0.45), Visible = false, ZIndex = 72, Parent = fight }, C.panel1, C.bg2, 12, C.gold)
	ui.ChantTime = S.label({ Text = "", Font = S.Fonts.Heavy, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Center, Size = scale(1, 0.22), ZIndex = 73, Parent = ui.Chant }, 20)
	ui.ChantKeys = S.label({ Text = "", RichText = true, Font = S.Fonts.Heavy, TextXAlignment = Enum.TextXAlignment.Center, Position = scale(0, 0.22), Size = scale(1, 0.4), ZIndex = 73, Parent = ui.Chant }, 48)
	for i, key in Battle.Chant.Keys do
		local b = S.ghostButton({ Text = key, Font = S.Fonts.Heavy, Position = scale(0.04 + (i - 1) * 0.24, 0.68), Size = scale(0.2, 0.26), ZIndex = 73, Parent = ui.Chant }, 22)
		b.Activated:Connect(function() pressKey(key) end)
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if chant and not processed and input.KeyCode then
			local name = input.KeyCode.Name
			if table.find(Battle.Chant.Keys, name) then pressKey(name) end
		end
	end)
	ui.Fight = fight
	buildBanner(overlay)
	ui.Overlay = overlay
end

local function region(s): string?
	local world = s.Modules and s.Modules.World
	return world and world.Region
end

local function renderList(s, data)
	for _, child in ui.List:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	for i, entry in Battle.Visible(region(s), data.Defeated) do
		local enemy = entry.Enemy
		local row = S.panel("Frame", { LayoutOrder = i, Size = UDim2.new(1, -6, 0, 56), ZIndex = 62, Parent = ui.List }, C.card1, C.card2, 8,
			if entry.State == "Next" then C.muted else C.crimson1)
		S.padding(row, 10, 6)
		if entry.State == "Next" then
			local need = Battle.ById[enemy.Unlock]
			S.label({ Text = "❓  Next: ???", Font = S.Fonts.Bold, TextColor3 = C.muted, Size = scale(0.7, 0.5), ZIndex = 63, Parent = row }, 16)
			S.label({ Text = ("Defeat the %s to find out what waits here."):format(need and need.Name or "?"), TextColor3 = C.muted,
				Position = scale(0, 0.5), Size = scale(0.75, 0.5), ZIndex = 63, Parent = row }, 12)
		else
			S.label({ Text = ("%s  %s%s"):format(enemy.Icon, enemy.Name, if entry.State == "Beaten" then "  ✔" else ""), Font = S.Fonts.Bold, Size = scale(0.7, 0.5), ZIndex = 63, Parent = row }, 16)
			S.label({ Text = ("HP %d  ·  Power %d%s"):format(enemy.HP, enemy.Power, if enemy.Region then "  ·  local foe" else ""), TextColor3 = C.muted,
				Position = scale(0, 0.5), Size = scale(0.75, 0.5), ZIndex = 63, Parent = row }, 12)
			local fight = S.button({ Text = ("Fight  ·  %d action"):format(Battle.StartCost), Font = S.Fonts.Heavy, Position = scale(0.76, 0.1), Size = scale(0.24, 0.8), ZIndex = 63, Parent = row },
				C.crimson1, C.crimson2, 14, C.text)
			S.setEnabled(fight, s.Actions >= Battle.StartCost and s.Age >= Battle.MinAge and not s.Dead)
			fight.Activated:Connect(function()
				if fight.Active then act("Start", enemy.Id) end
			end)
		end
	end
	if s.Age < Battle.MinAge then
		S.autoLabel({ LayoutOrder = 0, Text = ("%s open at age %d."):format(S.term("BattlesName"), Battle.MinAge), TextColor3 = C.muted, ZIndex = 63, Parent = ui.List }, 14)
	end
end

local function renderSpells(s, mana)
	for _, child in ui.Spells:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local data = s.Modules.Arcana or {}
	local levels = {}
	for stat, entry in s.Stats do levels[stat] = entry.Level end
	local buffs = { ManaCostMult = if data.SilentCasting then Arcana.SilentTrial.Buffs.ManaCostMult else 1 }
	local order = 0
	for _, element in Arcana.AllElements do
		local open = not element.Special or (data.Special or {})[element.Id]
		for rank = 1, #Arcana.RankNames do
			local spell = Arcana.SpellsById[element.Id .. rank]
			if open and ((data.Affinity or {})[element.Id] or 0) >= spell.Affinity then
				order += 1
				local mastery = (data.Mastery or {})[spell.Id]
				local chantless = (mastery and mastery.Level or 0) >= Arcana.MaxMastery
				local cost = CombatMath.ManaCost(spell.ManaCost, levels, buffs)
				local b = S.ghostButton({ LayoutOrder = order, Text = ("%s %s  ·  %d %s%s"):format(element.Icon, spell.Name, cost, string.lower(S.term("ManaName")), if chantless then "  ·  CHANTLESS" else ""),
					Size = UDim2.new(1, -4, 0, 30), ZIndex = 71, Parent = ui.Spells }, 13)
				S.setEnabled(b, mana >= cost)
				b.Activated:Connect(function()
					if not b.Active then return end
					ui.Spells.Visible = false
					if chantless then act("Cast", spell.Id, true) else startChant(spell.Id) end
				end)
			end
		end
	end
	for id in data.Custom or {} do
		for _, entry in s.Grimoire or {} do
			if entry.Id == id then
				order += 1
				local b = S.ghostButton({ LayoutOrder = order, Text = ("★ %s"):format(entry.Name), Size = UDim2.new(1, -4, 0, 30), ZIndex = 71, Parent = ui.Spells }, 13)
				b.Activated:Connect(function() ui.Spells.Visible = false; startChant(id) end)
			end
		end
	end
	if order == 0 then
		S.autoLabel({ Text = "You know no spells yet.", TextColor3 = C.muted, ZIndex = 71, Parent = ui.Spells }, 13)
	end
end

function Modal.Render(s)
	state = s
	if not ui.Overlay then return end
	local data = (s.Modules and s.Modules.Battle) or { Defeated = {} }
	local active = data.Active
	if active and not ui.Overlay.Visible then
		ui.Overlay.Visible = true
	end
	if not ui.Overlay.Visible then
		shownFight = nil
		return
	end
	ui.List.Visible = active == nil
	ui.Fight.Visible = active ~= nil
	ui.Close.Visible = active == nil
	if not active then
		ui.Title.Text = "⚔ " .. S.term("BattlesName")
		shownFight = nil
		renderList(s, data)
		return
	end
	local enemy = Battle.ById[active.EnemyId]
	if shownFight ~= active.EnemyId then -- snapshots are fresh tables: key by enemy
		shownFight = active.EnemyId
		playBanner(enemy)
	end
	local arcana = s.Modules.Arcana or {}
	local mana = arcana.Mana or 0
	ui.Title.Text = ("⚔ Turn %d"):format(active.Turn)
	ui.YouName.Text = S.escape(s.Name)
	ui.YouHP.Text = ("HP %d / %d"):format(active.HP, active.MaxHP)
	S.setBar(ui.YouHPFill, active.HP / math.max(1, active.MaxHP))
	ui.YouMana.Text = ("%s %d / %d"):format(S.term("ManaName"), math.floor(mana), arcana.MaxMana or 0)
	S.setBar(ui.YouManaFill, mana / math.max(1, arcana.MaxMana or 1))
	ui.FoeName.Text = enemy.Icon .. "  " .. enemy.Name
	ui.FoeHP.Text = ("HP %d / %d"):format(active.EnemyHP, active.EnemyMax)
	S.setBar(ui.FoeHPFill, active.EnemyHP / math.max(1, active.EnemyMax))
	ui.Log.Text = table.concat(active.Log or {}, "\n")
	ui.Signature.Text = if active.SignatureUsed then "Signature used" else ("Use %s!"):format(active.Signature or "?")
	S.setEnabled(ui.Signature, not active.SignatureUsed)
	S.setEnabled(ui.Cast, ctx.GamePack.IsActive("Arcana"))
	ui.Hint.Text = ("Guard blocks %d%% and restores %d%% " .. string.lower(S.term("ManaName")) .. "  ·  chant Z / X / C / V for x%.2f  ·  chantless spells always hit full"):format(
		Battle.Guard.Block * 100, Battle.Guard.ManaRestore * 100, Battle.Chant.Bonus)
	renderSpells(s, mana)
end

function Modal.Open()
	ui.Overlay.Visible = true
	if state then Modal.Render(state) end
end

return Modal
