--[[
	Samsara tab, three columns:
	- Wheel of Reincarnation: spin a bloodline and two talent slots with Karma
	  (rarity odds with pity, lock a bloodline across lives). Results roll on a 3D
	  drum (Shared/WheelSpinner) driven by Remotes.SpinResult.
	- Rebirth path (Samsara module) and the permanent Karma upgrades.
	- Collection Codex, game passes and the record of past lives.
	The server owns every roll and purchase (Modules/WheelSystem via the Reincarnate
	remote, Modules/MonetizationSystem via PassPrompt); this page only displays and asks.
]]

local Page = {}

local ctx, root, S, C, Config, T
local ui = {}
local historyKey = nil

local function scale(x, y) return UDim2.fromScale(x, y) end

local function rarityInfo(spin, rarity)
	return spin and spin.Rarities and spin.Rarities[rarity]
end

local function pityText(spin, pity): string
	local parts = {}
	for _, rule in (spin and spin.Pity) or {} do
		table.insert(parts, ("%s+ within %d"):format(rule.Rarity, rule.Every - ((pity and pity[rule.Rarity]) or 0)))
	end
	return if #parts > 0 then "Pity: " .. table.concat(parts, "  ·  ") else ""
end

local function badge(parent, name: string, position)
	local label = S.label({ Name = name, Text = "", Font = S.Fonts.Bold, TextColor3 = C.dark, Position = position, Size = scale(0.3, 0.2),
		TextXAlignment = Enum.TextXAlignment.Center, Parent = parent }, 12)
	S.decorate(label, C.gold, C.gold2, C.ink, 6, 0.2)
	return label
end

local function slotCard(parent, name: string, position, size)
	local card = S.new("Frame", { Name = name, Position = position, Size = size, Parent = parent })
	S.decorate(card, C.card1, C.card2, C.stroke, 12, 0.4)
	S.padding(card, 10, 8)
	local entry = { Card = card }
	entry.Rarity = badge(card, "Rarity", scale(0, 0))
	entry.Name = S.label({ Name = "SlotName", Text = "", Font = S.Fonts.Title, TextColor3 = C.text, Position = scale(0, 0.24), Size = scale(0.62, 0.34), Parent = card }, 20)
	entry.Desc = S.label({ Name = "Desc", Text = "", TextColor3 = C.muted, Position = scale(0, 0.6), Size = scale(0.62, 0.38),
		TextYAlignment = Enum.TextYAlignment.Top, Parent = card }, 13)
	return entry
end

local function panel(name: string, x: number, width: number)
	local frame = S.new("Frame", { Name = name, Position = scale(x, 0), Size = scale(width, 1), Parent = root })
	S.padding(frame, 12, 10)
	if ctx.Theme then ctx.Theme.frame(frame, 14) else S.decorate(frame) end
	return frame
end

local function header(parent, name: string, text: string, y: number, height: number)
	return S.label({ Name = name, Text = text, Font = S.Fonts.Title, TextColor3 = C.gold, Position = scale(0, y), Size = scale(1, height), Parent = parent }, 20)
end

-- A selectable/buyable row: title + detail on the left, an action on the right.
local function shopRow(parent, name: string, y: number, height: number, buttonText: string)
	local row = S.new("Frame", { Name = name, Position = scale(0, y), Size = scale(1, height), Parent = parent })
	S.decorate(row, C.card1, C.card2, C.stroke, 8, 0.6)
	S.padding(row, 8, 4)
	local entry = { Row = row }
	entry.Title = S.label({ Name = "Title", Text = "", Font = S.Fonts.Bold, TextColor3 = C.text, Size = scale(0.7, 0.5), Parent = row }, 14)
	entry.Detail = S.label({ Name = "Detail", Text = "", TextColor3 = C.muted, Position = scale(0, 0.5), Size = scale(0.7, 0.5), Parent = row }, 11)
	entry.Button = S.ghostButton({ Name = "Action", Text = buttonText, Position = scale(0.72, 0.1), Size = scale(0.28, 0.8), Parent = row }, 12)
	return entry
end

----------------------------------------------------------------------
-- Drum spinner
----------------------------------------------------------------------

-- A strip of random pool entries with the result at a known index.
local function drumEntries(kind: string, resultId: string)
	local list = if kind == "Bloodline" then Config.Races.List elseif kind == "Legacy" then Config.Legacies.List else Config.Talents.List
	local spin = if kind == "Bloodline" then Config.Races.Spin elseif kind == "Legacy" then Config.Legacies.Spin else Config.Talents.Spin
	local entries, target = {}, 1
	local random = Random.new()
	for i = 1, 24 do
		local item = list[random:NextInteger(1, #list)]
		if i == 18 then
			item = (kind == "Bloodline" and Config.Races.ById[resultId]) or (kind == "Legacy" and Config.Legacies.ById[resultId])
				or (kind == "Talent" and Config.Talents.Get(resultId)) or item
			target = i
		end
		local info = rarityInfo(spin, item.Rarity)
		table.insert(entries, { Name = item.Name, Rarity = item.Rarity, Color = (info and info.Color) or C.text })
	end
	return entries, target
end

local function showDrum(result)
	if result.Creation then
		return -- Life 1 starter spins roll on the creation screen (IntroAndLoadingUI)
	end
	local entries, target = drumEntries(result.Kind, result.Id)
	ui.DrumLayer.Visible = true
	ui.DrumCaption.Text = ("Spinning %s..."):format(if result.Kind == "Bloodline" then "a " .. string.lower(S.Terms.RaceName) elseif result.Kind == "Legacy" then "a " .. string.lower(S.Terms.LegacyName) else "talent slot " .. tostring(result.Slot))
	ui.Drum:Spin(entries, target, {
		Speed = result.Speed or 1,
		OnDone = function(landed)
			ui.DrumCaption.Text = ("%s  ·  %s%s"):format(string.upper(result.Rarity or ""), result.Name or (landed and landed.Name) or "", if result.Forced then "  (pity)" else "")
			task.delay(1.4, function()
				if ui.Drum.Connection == nil then
					ui.DrumLayer.Visible = false
				end
			end)
		end,
	})
end

function Page.Init(context, frame)
	ctx, root = context, frame
	S, Config = ctx.Style, ctx.Config
	C, T = S.C, S.Terms
	for _, child in root:GetChildren() do
		child:Destroy()
	end
	local remote = ctx.Remotes:WaitForChild("Reincarnate")
	local WheelSpinner = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("WheelSpinner"))

	-- Left: the Wheel
	local left = panel("WheelPanel", 0, 0.37)
	S.label({ Name = "Header", Text = T.RebirthWheel, Font = S.Fonts.Title, TextColor3 = C.gold, Size = scale(0.66, 0.075), Parent = left }, 22)
	ui.Karma = S.label({ Name = "Karma", Text = "", Font = S.Fonts.Bold, TextColor3 = C.gold, Position = scale(0.66, 0), Size = scale(0.34, 0.075),
		TextXAlignment = Enum.TextXAlignment.Right, Parent = left }, 15)
	ui.Status = S.label({ Name = "Status", Text = "", TextColor3 = C.muted, Position = scale(0, 0.085), Size = scale(1, 0.075), Parent = left }, 12)

	ui.Blood = slotCard(left, "Bloodline", scale(0, 0.165), scale(1, 0.17))
	-- Compact card: badge beside the name, passive underneath (like the talent slots).
	ui.Blood.Rarity.Position, ui.Blood.Rarity.Size = scale(0, 0.04), scale(0.22, 0.3)
	ui.Blood.Name.Position, ui.Blood.Name.Size = scale(0.24, 0), scale(0.4, 0.4)
	ui.Blood.Desc.Position, ui.Blood.Desc.Size = scale(0, 0.44), scale(0.63, 0.56)
	ui.BloodSpin = S.button({ Name = "SpinButton", Text = "Spin", Position = scale(0.65, 0.04), Size = scale(0.35, 0.42), Parent = ui.Blood.Card }, nil, nil, 13)
	ui.BloodLock = S.ghostButton({ Name = "LockButton", Text = "Lock", Position = scale(0.65, 0.54), Size = scale(0.35, 0.42), Parent = ui.Blood.Card }, 12)
	ui.BloodPity = S.label({ Name = "BloodPity", Text = "", TextColor3 = C.muted, Position = scale(0, 0.338), Size = scale(1, 0.035), Parent = left }, 11)
	-- Family legacy of the next life (Dynasty module).
	ui.Legacy = slotCard(left, "Legacy", scale(0, 0.378), scale(1, 0.125))
	ui.Legacy.Rarity.Position, ui.Legacy.Rarity.Size = scale(0, 0.06), scale(0.22, 0.4)
	ui.Legacy.Name.Position, ui.Legacy.Name.Size = scale(0.24, 0), scale(0.4, 0.52)
	ui.Legacy.Desc.Position, ui.Legacy.Desc.Size = scale(0, 0.56), scale(0.64, 0.44)
	ui.LegacySpin = S.button({ Name = "SpinButton", Text = "Spin", Position = scale(0.67, 0.15), Size = scale(0.33, 0.7), Parent = ui.Legacy.Card }, nil, nil, 13)
	ui.LegacySpin.Activated:Connect(function() remote:FireServer("SpinLegacy") end)
	ui.BloodSpin.Activated:Connect(function() remote:FireServer("SpinBloodline") end)
	ui.BloodLock.Activated:Connect(function()
		remote:FireServer(if ui.Locked then "Unlock" else "Lock")
	end)

	S.label({ Name = "TalentHeader", Text = "Innate Talents", Font = S.Fonts.Title, TextColor3 = C.gold, Position = scale(0, 0.512), Size = scale(1, 0.048), Parent = left }, 16)
	ui.Talents = {}
	for slot = 1, 2 do
		local entry = slotCard(left, "Talent" .. slot, scale(0, 0.565 + (slot - 1) * 0.14), scale(1, 0.13))
		-- Short card: badge beside the name, description underneath.
		entry.Rarity.Position, entry.Rarity.Size = scale(0, 0.06), scale(0.22, 0.4)
		entry.Name.Position, entry.Name.Size = scale(0.24, 0), scale(0.4, 0.52)
		entry.Desc.Position, entry.Desc.Size = scale(0, 0.56), scale(0.64, 0.44)
		entry.Spin = S.button({ Name = "SpinButton", Text = "Spin", Position = scale(0.67, 0.15), Size = scale(0.33, 0.7), Parent = entry.Card }, nil, nil, 13)
		entry.Spin.Activated:Connect(function() remote:FireServer("SpinTalent", slot) end)
		ui.Talents[slot] = entry
	end
	ui.TalentPity = S.label({ Name = "TalentPity", Text = "", TextColor3 = C.muted, Position = scale(0, 0.85), Size = scale(1, 0.04), Parent = left }, 11)
	ui.Reborn = S.button({ Name = "ReincarnateButton", Text = "☸  REINCARNATE", Font = S.Fonts.Heavy, Position = scale(0, 0.905), Size = scale(1, 0.095), Parent = left }, nil, nil, 18)
	ui.Reborn.Activated:Connect(function() remote:FireServer("Confirm") end)

	-- The drum covers the slot cards while a spin rolls.
	ui.DrumLayer = S.new("Frame", { Name = "DrumLayer", Position = scale(0, 0.165), Size = scale(1, 0.74), BackgroundColor3 = C.ink,
		BackgroundTransparency = 0.04, BorderSizePixel = 0, ZIndex = 19, Visible = false, Parent = left })
	S.new("UICorner", { CornerRadius = UDim.new(0, S.radius(12)), Parent = ui.DrumLayer })
	ui.Drum = WheelSpinner.new(ui.DrumLayer, { Position = scale(0.04, 0.03), Size = scale(0.92, 0.8) })
	ui.DrumCaption = S.label({ Name = "Caption", Text = "", Font = S.Fonts.Bold, TextColor3 = C.gold, Position = scale(0, 0.86), Size = scale(1, 0.12),
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 26, Parent = ui.DrumLayer }, 16)
	local spinResult = ctx.Remotes:FindFirstChild("SpinResult")
	if spinResult then
		spinResult.OnClientEvent:Connect(showDrum)
	end

	-- Middle: rebirth path + Karma upgrades
	local middle = panel("SamsaraPanel", 0.38, 0.31)
	header(middle, "PathHeader", "Rebirth Path", 0, 0.07)
	ui.Era = S.label({ Name = "Era", Text = "", Font = S.Fonts.Bold, TextColor3 = C.qi1, Position = scale(0.4, 0), Size = scale(0.6, 0.07),
		TextXAlignment = Enum.TextXAlignment.Right, Parent = middle }, 12)
	ui.Paths = {}
	for i, path in Config.RebirthPaths.Paths do
		local entry = shopRow(middle, path.Id, 0.08 + (i - 1) * 0.1, 0.092, "Choose")
		entry.Path = path
		entry.Title.Text = path.Icon .. "  " .. path.Name
		entry.Detail.Text = path.Description
		entry.Button.Activated:Connect(function() remote:FireServer("ChoosePath", path.Id) end)
		ui.Paths[i] = entry
	end
	header(middle, "UpgradeHeader", T.MetaCurrency .. " Upgrades", 0.49, 0.07)
	S.label({ Name = "Permanent", Text = "permanent", TextColor3 = C.muted, Position = scale(0.5, 0.49), Size = scale(0.5, 0.07),
		TextXAlignment = Enum.TextXAlignment.Right, Parent = middle }, 11)
	ui.Upgrades = {}
	for i, upgrade in Config.Upgrades.List do
		local entry = shopRow(middle, upgrade.Id, 0.565 + (i - 1) * 0.087, 0.08, "Buy")
		entry.Upgrade = upgrade
		entry.Button.Activated:Connect(function() remote:FireServer("BuyUpgrade", upgrade.Id) end)
		ui.Upgrades[i] = entry
	end

	-- Right: Codex, passes, past lives
	local right = panel("CodexPanel", 0.70, 0.30)
	header(right, "Header", "Collection Codex", 0, 0.07)
	ui.Bonus = S.label({ Name = "Bonus", Text = "", Font = S.Fonts.Bold, TextColor3 = C.qi1, Position = scale(0, 0.07), Size = scale(1, 0.045), Parent = right }, 12)
	ui.Codex = {}
	local groups = {
		{ Key = "Races", Name = T.RaceNamePlural, Total = #Config.Races.List, Color = C.gold },
		{ Key = "Talents", Name = "Talents", Total = #Config.Talents.List, Color = C.violet },
		{ Key = "Titles", Name = "Titles", Total = #Config.Titles.List, Color = C.qi1 },
		{ Key = "Techniques", Name = "Techniques", Total = if ctx.GamePack.IsEnabled("Masters") then #Config.Masters.List else 0, Color = C.rose1 },
	}
	local row = 0
	for _, group in groups do
		if group.Total > 0 then
			local y = 0.125 + row * 0.064
			row += 1
			local label = S.label({ Name = group.Key, Text = group.Name, Font = S.Fonts.Bold, TextColor3 = C.text, Position = scale(0, y), Size = scale(0.6, 0.036), Parent = right }, 12)
			local count = S.label({ Name = group.Key .. "Count", Text = "", Font = S.Fonts.Bold, TextColor3 = C.muted, Position = scale(0.6, y), Size = scale(0.4, 0.036),
				TextXAlignment = Enum.TextXAlignment.Right, Parent = right }, 11)
			local _, fill = S.bar({ Name = group.Key .. "Bar", Position = scale(0, y + 0.04), Size = scale(1, 0.016), Parent = right }, group.Color)
			ui.Codex[group.Key] = { Label = label, Count = count, Fill = fill, Total = group.Total }
		end
	end
	-- The Immortal Treasury (UIController/ShopModal): passes, Karma packs, pills.
	header(right, "PassHeader", T.ShopName, 0.39, 0.065)
	ui.ShopOpen = S.button({ Name = "TreasuryButton", Text = T.ShopButton .. "  ·  open", Font = S.Fonts.Heavy, Position = scale(0, 0.46), Size = scale(1, 0.085), Parent = right }, nil, nil, 16)
	ui.ShopOpen.Activated:Connect(function()
		if ctx.OpenShop then ctx.OpenShop() end
	end)
	ui.Owned = S.label({ Name = "OwnedPasses", Text = "", TextColor3 = C.muted, Position = scale(0, 0.555), Size = scale(1, 0.11),
		TextYAlignment = Enum.TextYAlignment.Top, Parent = right }, 12)
	header(right, "PastHeader", "Past Lives", 0.68, 0.06)
	ui.History = S.new("ScrollingFrame", { Name = "History", Position = scale(0, 0.745), Size = scale(1, 0.255), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 5, ScrollBarImageColor3 = C.stroke, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = right })
	S.list(ui.History, UDim.new(0, 6))
end

local function buildHistory(s)
	S.clear(ui.History)
	if #s.Lineage == 0 then
		S.label({ Text = "This is your first life. Every death adds a page here.", TextColor3 = C.muted, Size = UDim2.new(1, -6, 0, 30), Parent = ui.History }, 12)
		return
	end
	for i, life in s.Lineage do
		local entry = S.new("Frame", { Name = "Life", LayoutOrder = i, Size = UDim2.new(1, -8, 0, 40), BackgroundTransparency = 1, Parent = ui.History })
		S.label({ Text = ("Life %d  ·  %s  ·  age %d"):format(life.Life, life.Name, life.Age), Font = S.Fonts.Bold, Size = scale(1, 0.5), Parent = entry }, 13)
		S.label({ Text = ("%s  ·  %s %d/9  ·  +%d %s"):format(life.Race or "Human", life.Realm, life.SubLevel, life.Karma, T.MetaCurrency), TextColor3 = C.muted,
			Position = scale(0, 0.5), Size = scale(1, 0.45), Parent = entry }, 11)
		S.new("Frame", { Name = "Rule", AnchorPoint = Vector2.new(0, 1), Position = scale(0, 1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.stroke,
			BackgroundTransparency = 0.75, BorderSizePixel = 0, Parent = entry })
	end
end

local function paintSlot(entry, name: string, description: string, rarity, color: Color3?)
	local info = rarity
	entry.Name.Text = name
	entry.Desc.Text = description
	entry.Rarity.Visible = info ~= nil
	if info then
		entry.Rarity.Text = string.upper(info.Name or "")
		S.paint(entry.Rarity, info.Color, info.Color:Lerp(C.ink, 0.35))
	end
	entry.Name.TextColor3 = color or (info and info.Color) or C.text
	local stroke = entry.Card:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = (info and info.Color) or C.stroke
		stroke.Transparency = if info then 0.15 else 0.6
	end
end

local function highlight(entry, on: boolean, color: Color3?)
	local stroke = entry.Row:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if on then (color or C.gold) else C.stroke
		stroke.Transparency = if on then 0.05 else 0.6
	end
end

local function rankPips(rank: number, max: number): string
	return string.rep("◆", rank) .. string.rep("◇", max - rank)
end

local function renderSamsara(s)
	local dead = s.Dead
	local samsara = ctx.GamePack.IsEnabled("Samsara")
	local wheel = s.Wheel or {}
	local chosen = wheel.Path or Config.RebirthPaths.Default
	local moduleData = s.Modules and s.Modules.Samsara
	local era = Config.RebirthPaths.Eras[(moduleData and moduleData.Era) or "Present"]
	ui.Era.Text = if samsara then ("Now: %s"):format(era and era.Name or "Present Era") else "Fixed in this game"
	for _, entry in ui.Paths do
		local path = entry.Path
		local free = path.FreeIfFlag and s.Flags and s.Flags[path.FreeIfFlag]
		local cost = if free then 0 else (path.Cost or 0)
		local selected = path.Id == chosen
		if path.Id == "Descendant" then
			local hasChild = false
			for _, rel in s.Relationships or {} do
				if rel.Type == "Child" and rel.Alive then hasChild = true end
			end
			entry.Detail.Text = if hasChild then "Pick a child in the Lineage tab: inherit their genes, free, no spin." else path.Description
			if wheel.Heir then cost = 0 end
		end
		entry.Button.Text = if selected then "✓ Chosen" elseif cost > 0 then ("%d " .. T.MetaCurrencyIcon):format(cost) else "Free"
		S.setEnabled(entry.Button, samsara and dead and not selected)
		highlight(entry, selected and samsara)
	end
	for _, entry in ui.Upgrades do
		local upgrade = entry.Upgrade
		local rank = (s.Upgrades and s.Upgrades[upgrade.Id]) or 0
		local maxed = rank >= upgrade.MaxRank
		entry.Title.Text = ("%s  %s"):format(upgrade.Icon or "", upgrade.Name)
		entry.Detail.Text = rankPips(rank, upgrade.MaxRank) .. "  " .. upgrade.Description
		entry.Button.Text = if maxed then "Max" else ("%d " .. T.MetaCurrencyIcon):format(upgrade.Costs[rank + 1])
		S.setEnabled(entry.Button, dead and not maxed and s.Karma >= upgrade.Costs[rank + 1])
		highlight(entry, rank > 0, C.qi1)
	end
	local owned = {}
	for _, pass in Config.Monetization.Passes do
		if s.Passes and s.Passes[pass.Id] then
			table.insert(owned, pass.Name)
		end
	end
	ui.Owned.Text = if #owned > 0 then "Owned: " .. table.concat(owned, "  ·  ")
		else ("Passes, %s packs and miracle pills."):format(T.MetaCurrency)
end

function Page.Render(s)
	local wheel = s.Wheel or { Talents = {}, Pity = {} }
	local costs = s.SpinCosts or {}
	local dead = s.Dead
	local lineages = ctx.GamePack.IsEnabled("Lineages") and Config.Races.Spin ~= nil
	ui.Locked = wheel.StoredRace ~= nil
	ui.Karma.Text = ("%s %d %s"):format(T.MetaCurrencyIcon, s.Karma, T.MetaCurrency)
	ui.Status.Text = if dead then ("%s died at age %d. %s Spin, pick a path, then reincarnate."):format(s.Name, s.Age, s.DeathCause or "")
		else ("Life #%d. The Wheel turns when this life ends; %s carries over."):format(s.Lives, T.MetaCurrency)

	-- An heir chosen in the Lineage tab: their genetics replace the wheel (no spins).
	local heir
	for _, rel in s.Relationships or {} do
		if dead and wheel.Heir and rel.Id == wheel.Heir then
			heir = rel
		end
	end
	if heir then
		ui.Status.Text = ("You will be reborn as %s, your child: bloodline, talents and legacy are inherited."):format(heir.Name)
	end
	local raceId = if heir and heir.Genetics then heir.Genetics.Race elseif dead then wheel.Race else s.RaceId
	local race = Config.Races.Get(raceId)
	paintSlot(ui.Blood, race.Name .. (if heir then "  ·  inherited" elseif ui.Locked then "  🔒" else ""), race.Passive or race.Description or "", rarityInfo(Config.Races.Spin, race.Rarity), race.Badge)
	ui.BloodSpin.Visible, ui.BloodLock.Visible, ui.BloodPity.Visible = lineages, lineages, lineages
	ui.BloodSpin.Text = ("Spin  ·  %d " .. T.MetaCurrencyIcon):format(costs.Bloodline or 0)
	S.setEnabled(ui.BloodSpin, dead and lineages and not heir and not ui.Locked and s.Karma >= (costs.Bloodline or math.huge))
	local legacies = ctx.GamePack.IsEnabled("Dynasty")
	ui.Legacy.Card.Visible = legacies
	if legacies then
		local legacy = Config.Legacies.Get(if heir then s.Legacy elseif dead then wheel.Legacy else s.Legacy)
		paintSlot(ui.Legacy, legacy.Name, legacy.Description or "", rarityInfo(Config.Legacies.Spin, legacy.Rarity))
		ui.LegacySpin.Text = ("Spin  ·  %d " .. T.MetaCurrencyIcon):format(Config.Legacies.Spin.Cost)
		S.setEnabled(ui.LegacySpin, dead and not heir and s.Karma >= Config.Legacies.Spin.Cost)
	end
	ui.BloodLock.Text = if ui.Locked then "Unlock" else ("Lock  ·  %d " .. T.MetaCurrencyIcon):format(costs.Lock or 0)
	S.setEnabled(ui.BloodLock, dead and lineages and not heir and (ui.Locked or s.Karma >= (costs.Lock or math.huge)))
	ui.BloodPity.Text = pityText(Config.Races.Spin, wheel.Pity and wheel.Pity.Bloodline)

	for slot, entry in ui.Talents do
		local id = if heir then (heir.Genetics and heir.Genetics.Talents or {})[slot] elseif dead then wheel.Talents[slot] else s.Talents[slot]
		local talent = id and Config.Talents.Get(id)
		if talent then
			paintSlot(entry, talent.Name, talent.Description or "", rarityInfo(Config.Talents.Spin, talent.Rarity))
		else
			paintSlot(entry, "Empty slot", if heir then "No talent inherited in this slot." elseif dead then "Spin to roll an innate talent." else "No talent in this life.", nil)
			entry.Name.TextColor3 = C.muted
		end
		entry.Spin.Text = ("Spin  ·  %d " .. T.MetaCurrencyIcon):format(costs.Talent or 0)
		S.setEnabled(entry.Spin, dead and not heir and s.Karma >= (costs.Talent or math.huge))
	end
	ui.TalentPity.Text = pityText(Config.Talents.Spin, wheel.Pity and wheel.Pity.Talent)
	ui.Reborn.Text = if dead then "☸  REINCARNATE" else ("☸  LIFE #%d IN PROGRESS"):format(s.Lives)
	S.setEnabled(ui.Reborn, dead)

	renderSamsara(s)

	local codex = s.Codex or {}
	for key, entry in ui.Codex do
		local count = 0
		for _ in codex[key] or {} do
			count += 1
		end
		entry.Count.Text = ("%d / %d"):format(count, entry.Total)
		S.setBar(entry.Fill, count / math.max(1, entry.Total))
	end
	ui.Bonus.Text = ("%d entries  ·  +%d%% XP & " .. T.EnergyName):format(s.CodexCount or 0, math.floor((s.CodexBonus or 0) * 100 + 0.5))

	local key = #s.Lineage .. "#" .. s.Lives
	if key ~= historyKey then
		historyKey = key
		buildHistory(s)
	end
end

-- Edit-mode preview: the drum posed mid-spin over the wheel.
function Page.PreviewDrum()
	local entries = drumEntries("Bloodline", Config.Races.List[#Config.Races.List].Id)
	ui.DrumLayer.Visible = true
	ui.DrumCaption.Text = "Spinning a bloodline..."
	ui.Drum:Pose(entries, 16.4)
end

return Page
