--[[
	Legends tab (client; Modules/LegendsSystem through LegendsAction).
	Left: the Seven Thrones against your combat power (Encounter / Spar / Challenge).
	Middle: the Family Weapon, relic leads and relics, and the World Chronicle.
	Right: the Hall of Lives (your best past lives, Share) and the Community Hall feed.
]]

local Page = {}

local ctx, root, S, C, Legends, CombatMath
local ui = {}
local state = nil
local feed = {}

local function scale(x, y) return UDim2.fromScale(x, y) end

local function commas(n: number): string
	local text = tostring(math.floor(n))
	while true do
		local replaced, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		text = replaced
		if count == 0 then break end
	end
	return text
end

local function column(name: string, x: number, w: number, title: string)
	local frame = S.panel("Frame", { Name = name, Position = scale(x, 0), Size = scale(w, 1), Parent = root }, C.panel1, C.panel2, 12)
	S.padding(frame, 10, 8)
	S.label({ Name = "Title", Text = title, Font = S.Fonts.Title, TextColor3 = C.gold, Size = scale(1, 0.07), Parent = frame }, 20)
	local scroll = S.new("ScrollingFrame", { Name = "Scroll", Position = scale(0, 0.08), Size = scale(1, 0.92), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = C.stroke, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = frame })
	S.list(scroll, UDim.new(0, 5))
	return scroll
end

local function clear(parent)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
end

local function box(parent, order: number, text: string, color: Color3?)
	local frame = S.panel("Frame", { LayoutOrder = order, Size = UDim2.new(1, -4, 0, 0), Parent = parent }, C.card1, C.card2, 8, color)
	S.fit(frame)
	S.autoLabel({ Name = "Text", Text = text, RichText = true, Parent = frame }, 13)
	return frame
end

local function powerOf(s): number
	local levels, skills, affinity = {}, {}, 0
	for stat, entry in s.Stats do levels[stat] = entry.Level end
	for id, entry in (s.Modules.Skills and s.Modules.Skills.Levels) or {} do skills[id] = entry.Level end
	for _, value in (s.Modules.Arcana and s.Modules.Arcana.Affinity) or {} do affinity = math.max(affinity, value) end
	return CombatMath.Power(levels, skills, affinity)
end

function Page.Init(context, frame)
	ctx, root = context, frame
	S = ctx.Style
	C = S.C
	Legends = ctx.Content.Get("LegendsConfig")
	CombatMath = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("CombatMath"))
	ui.Thrones = column("Thrones", 0, 0.36, Legends.Header or "The Seven Great Thrones")
	ui.Family = column("Family", 0.37, 0.31, "Family & World")
	ui.Hall = column("Hall", 0.69, 0.31, "Hall of Lives")
	task.spawn(function()
		local ok, cards = pcall(function()
			return ctx.Remotes:WaitForChild("CommunityQuery", 10):InvokeServer()
		end)
		if ok and type(cards) == "table" then
			feed = cards
			if state then Page.Render(state) end
		end
	end)
	task.spawn(function()
		local event = ctx.Remotes:WaitForChild("CommunityHall", 10)
		if event then
			event.OnClientEvent:Connect(function(card)
				table.insert(feed, card)
				while #feed > Legends.CommunitySize do table.remove(feed, 1) end
				if state then Page.Render(state) end
			end)
		end
	end)
end

local function act(action, arg)
	ctx.Remotes.LegendsAction:FireServer(action, arg)
end

local function renderThrones(s, world, power)
	local list = ui.Thrones
	clear(list)
	S.autoLabel({ LayoutOrder = 0, Text = ("Your combat power: <b>%s</b>"):format(commas(power)), RichText = true, TextColor3 = C.qi1, Parent = list }, 15)
	for seat, def in Legends.Thrones do
		local claimed = (world.Thrones or {})[seat]
		local holder = if claimed then claimed.Holder .. " (your past self)" elseif def.Vacant then "Vacant seat" else def.Holder
		local seatPower = if claimed then claimed.Power elseif def.Vacant then def.ClaimPower else def.Power
		local shown = if def.Hidden and not claimed then "???" else commas(seatPower)
		-- Phones: taller rows whose buttons are sized here (44 px minimums covered the holder).
		local phone = require(game:GetService("ReplicatedStorage").Shared.Responsive).Current().Kind == "Phone"
		local row = S.panel("Frame", { LayoutOrder = seat, Size = UDim2.new(1, -4, 0, if phone then 120 else 84), Parent = list }, C.card1, C.card2, 8,
			if claimed then C.gold elseif power >= seatPower then C.green else C.stroke)
		S.padding(row, 8, 5)
		S.label({ Text = ("#%d  %s"):format(seat, def.Title), Font = S.Fonts.Bold, TextColor3 = if claimed then C.gold else C.text, Size = scale(0.62, 0.3), Parent = row }, 15)
		S.label({ Text = ("power %s"):format(shown), Font = S.Fonts.Mono, TextColor3 = if power >= seatPower then C.green else C.muted, TextXAlignment = Enum.TextXAlignment.Right,
			Position = scale(0.62, 0), Size = scale(0.38, 0.3), Parent = row }, 13)
		S.label({ Text = holder .. (if def.Vacant and not claimed then ("  -  claim at power %s"):format(commas(def.ClaimPower)) else ""), TextColor3 = C.muted,
			Position = scale(0, 0.32), Size = scale(1, 0.22), Parent = row }, 12)
		local buttons = {
			{ "Encounter", 0, C.card1, C.card2, C.text },
			{ "Spar", 0.34, C.card1, C.card2, C.text },
			{ "Challenge", 0.68, C.crimson1, C.crimson2, C.text },
		}
		for _, spec in buttons do
			local b = S.button({ Text = if spec[1] == "Challenge" and def.Vacant and not claimed then "Claim" else spec[1], Font = S.Fonts.Bold,
				Position = scale(spec[2], 0.62), Size = scale(0.31, 0.38), Parent = row }, spec[3], spec[4], 13, spec[5])
			b:SetAttribute("TouchSafe", phone)
			local usable = not s.Dead and not (spec[1] == "Spar" and (def.Vacant or claimed)) and not (spec[1] == "Challenge" and s.Age < Legends.ChallengeAge)
			S.setEnabled(b, usable)
			b.Activated:Connect(function() if b.Active then act(spec[1], seat) end end)
		end
	end
	S.autoLabel({ LayoutOrder = 20, Text = ("Challenges from age %d, once a year. Sparring costs 1 action and teaches sword and magic."):format(Legends.ChallengeAge),
		TextColor3 = C.muted, Parent = list }, 11)
end

local function renderFamily(s, world, data)
	local list = ui.Family
	clear(list)
	local weapon = world.FamilyWeapon
	local rule = Legends.FamilyWeapon
	local crafting = (s.Modules.Skills and s.Modules.Skills.Levels and s.Modules.Skills.Levels.Crafting and s.Modules.Skills.Levels.Crafting.Level) or 0
	box(list, 1, if weapon then ("<b>FAMILY WEAPON</b>\n%s  -  tier %d\nForged by %s (life %d). Every heir carries it."):format(weapon.Name, weapon.Tier, weapon.ForgedBy or "?", weapon.Life or 0)
		else ("<b>FAMILY WEAPON</b>\nNone yet. Forge one at Crafting %d (you: %d) for %s and 1 action."):format(rule.CraftingLevel, crafting, S.money(rule.Cost)), C.gold)
	local forge = S.button({ LayoutOrder = 2, Text = if weapon then "Reforge (higher tier)" else "Forge the " .. S.term("FamilyWeaponName"), Font = S.Fonts.Heavy, Size = UDim2.new(1, -4, 0, 32), Parent = list }, nil, nil, 14)
	S.setEnabled(forge, crafting >= rule.CraftingLevel and not s.Dead and (not weapon or math.floor(crafting / rule.TierEvery) > weapon.Tier))
	forge.Activated:Connect(function() if forge.Active then act("ForgeWeapon") end end)
	local relics = {}
	for _, relic in Legends.Relics do
		table.insert(relics, if (world.Relics or {})[relic.Id] then ("<font color=\"#%s\">%s</font> - %s"):format(C.gold:ToHex(), relic.Name, relic.Description) else "??? (missing relic)")
	end
	box(list, 3, ("<b>RELIC LEADS  %d/%d</b> this life\nFind %d in one life to recover a relic for every generation.\n%s"):format(
		math.min(data.Leads or 0, Legends.LeadsNeeded), Legends.LeadsNeeded, Legends.LeadsNeeded, table.concat(relics, "\n")))
	S.autoLabel({ LayoutOrder = 4, Text = "WORLD CHRONICLE", Font = S.Fonts.Heavy, TextColor3 = C.gold, Parent = list }, 12)
	local history = world.History or {}
	if #history == 0 then
		S.autoLabel({ LayoutOrder = 5, Text = "The world is young. Its history begins with you.", TextColor3 = C.muted, Parent = list }, 12)
	end
	for i = #history, math.max(1, #history - 24), -1 do
		local entry = history[i]
		S.autoLabel({ LayoutOrder = 5 + (#history - i), RichText = true, Text = ("<font color=\"#%s\"><b>%d</b></font>  %s"):format(
			(if entry.Kind == "deed" then C.gold else C.muted):ToHex(), entry.Year or 0, S.escape(entry.Text or "")), Parent = list }, 12)
	end
end

local function renderHall(s)
	local list = ui.Hall
	clear(list)
	local lives = {}
	for index, entry in s.Lineage or {} do
		table.insert(lives, { Index = index, Entry = entry })
	end
	table.sort(lives, function(a, b) return (a.Entry.Score or 0) > (b.Entry.Score or 0) end)
	if #lives == 0 then
		S.autoLabel({ LayoutOrder = 0, Text = "Your first life is still being written.", TextColor3 = C.muted, Parent = list }, 12)
	end
	for rank = 1, math.min(Legends.HallSize, #lives) do
		local entry, index = lives[rank].Entry, lives[rank].Index
		local frame = box(list, rank, ("<b>%d. %s</b> \"%s\"\nLife %d  -  age %d  -  score %s\n<i>%s</i>"):format(rank, S.escape(entry.Name or "?"),
			S.escape(entry.Title or "the Wanderer"), entry.Life or 0, entry.Age or 0, commas(entry.Score or 0), S.escape(entry.Epitaph or entry.Cause or "")), C.gold)
		local share = S.ghostButton({ Name = "Share", Text = if entry.Shared then "Shared" else "Share", Size = UDim2.new(0.4, 0, 0, 26), LayoutOrder = 9, Parent = frame }, 12)
		S.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4), Parent = frame })
		S.setEnabled(share, not entry.Shared)
		share.Activated:Connect(function()
			if not share.Active then return end
			if s.Dead then ctx.Remotes.Reincarnate:FireServer("Share", index) else act("Share", index) end
		end)
	end
	S.autoLabel({ LayoutOrder = 10, Text = "COMMUNITY HALL", Font = S.Fonts.Heavy, TextColor3 = C.gold, Parent = list }, 12)
	if #feed == 0 then
		S.autoLabel({ LayoutOrder = 11, Text = "No one has shared a life yet. Be the first.", TextColor3 = C.muted, Parent = list }, 12)
	end
	for i = #feed, 1, -1 do
		local card = feed[i]
		box(list, 11 + (#feed - i), ("<b>%s</b> \"%s\"  -  score %s\n<font color=\"#%s\">shared by %s</font>\n<i>%s</i>"):format(S.escape(card.Name or "?"),
			S.escape(card.Title or ""), commas(card.Score or 0), C.muted:ToHex(), S.escape(card.Player or "?"), S.escape(card.Epitaph or "")))
	end
end

function Page.Render(s)
	state = s
	local world = s.World or {}
	local data = (s.Modules and s.Modules.Legends) or {}
	renderThrones(s, world, powerOf(s))
	renderFamily(s, world, data)
	renderHall(s)
end

return Page
