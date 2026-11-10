--[[
	Skills tab (client): "What you do is what you become". Twelve skill cards with rank,
	level against the life-stage ceiling, progress, and the three mastery tiers
	(15 / 30 / 45): locked tiers show what they open, unlocked tiers are buttons for
	their yearly action (SkillAction remote); the tooltip shows effects and the passive.
]]

local Page = {}

local ctx, root, S, C, Skills
local cards = {}
local state = nil

local function scale(x, y) return UDim2.fromScale(x, y) end

local function effectsText(effects): string
	local parts = {}
	if effects.Money then
		table.insert(parts, if type(effects.Money) == "table" then ("money %d–%d"):format(effects.Money[1], effects.Money[2]) else ("money %+d"):format(effects.Money))
	end
	for _, key in { "Fame", "Happiness", "Stress", "Health" } do
		if effects[key] then
			table.insert(parts, ("%s %+d"):format(string.lower(key), effects[key]))
		end
	end
	for stat, xp in effects.StatXp or {} do
		table.insert(parts, ("+%d %s XP"):format(xp, stat))
	end
	for skill, xp in effects.SkillXp or {} do
		table.insert(parts, ("+%d %s"):format(xp, skill))
	end
	if effects.LifeBuff then
		table.insert(parts, effects.LifeBuff.Name)
	end
	return table.concat(parts, ", ")
end

local function buffsText(buffs): string
	local parts = {}
	for key, value in buffs or {} do
		if type(value) == "number" then
			table.insert(parts, if value < 3 and value > 0 and key:find("Mult") then ("%s x%.2f"):format(key, value) else ("%s %+g"):format(key, value))
		end
	end
	return table.concat(parts, ", ")
end

function Page.Init(context, frame)
	ctx, root = context, frame
	S = ctx.Style
	C = S.C
	Skills = ctx.Content.Get("SkillsConfig")
	-- Header and stage share the row without overlapping (the header box used to reach 0.7).
	S.label({ Name = "Header", Text = "Skills  ·  What you do is what you become", Font = S.Fonts.Title, TextColor3 = C.gold, Size = scale(0.49, 0.07), Parent = root }, 22)
	-- Phones: two cards a row (four left 120 px cards with cut names and stacked buttons).
	local phone = require(game:GetService("ReplicatedStorage").Shared.Responsive).Current().Kind == "Phone"
	Page.Stage = S.label({ Name = "Stage", Text = "", TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Right, Position = scale(0.5, 0.01), Size = scale(0.5, 0.05), Parent = root }, 13)
	local grid = S.new("ScrollingFrame", { Name = "Grid", Position = scale(0, 0.08), Size = scale(1, 0.92), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = C.stroke, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = root })
	S.new("UIGridLayout", { CellSize = UDim2.new(if phone then 0.495 else 0.245, -4, 0, 168), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	for i, skill in Skills.Skills do
		local card = S.panel("Frame", { Name = skill.Id, LayoutOrder = i, Parent = grid }, C.card1, C.card2, 10, skill.Color)
		S.padding(card, 8, 6)
		S.label({ Name = "Title", Text = skill.Icon .. "  " .. skill.Name, Font = S.Fonts.Bold, TextColor3 = skill.Color, Size = scale(0.62, 0.15), Parent = card }, 15)
		local rank = S.label({ Name = "Rank", Text = "", Font = S.Fonts.Heavy, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Right, Position = scale(0.62, 0), Size = scale(0.38, 0.15), Parent = card }, 13)
		local level = S.label({ Name = "Level", Text = "", TextColor3 = C.muted, Position = scale(0, 0.16), Size = scale(1, 0.11), Parent = card }, 12)
		local _, fill = S.bar({ Name = "Bar", Position = scale(0, 0.29), Size = scale(1, 0.05), Parent = card }, skill.Color)
		local tiers = {}
		for t, unlockLevel in Skills.UnlockLevels do
			local tier = skill.Unlocks[unlockLevel]
			local button = S.ghostButton({ Name = "Tier" .. unlockLevel, Text = "", Position = scale(0, 0.38 + (t - 1) * 0.21), Size = scale(1, 0.19), Parent = card }, 12)
			button.TextXAlignment = Enum.TextXAlignment.Left
			button:SetAttribute("TouchSafe", true) -- three stacked rows sized by the card
			S.new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = button })
			ctx.AttachTooltip(button, function()
				local action = tier.Action
				local lines = { ("<b>%s</b> (%s %d)"):format(action.Name, skill.Name, unlockLevel), action.Description or "", "Effects: " .. effectsText(action.Effects) }
				if action.Chance then
					table.insert(lines, ("⚠ Risky: about %d%% success; failure: %s"):format(math.floor(action.Chance * 100), effectsText(action.Fail or {})))
				end
				table.insert(lines, ("Passive <b>%s</b>: %s"):format(tier.Passive.Name, buffsText(tier.Passive.Buffs)))
				table.insert(lines, "Once a year, 1 action.")
				return table.concat(lines, "\n")
			end)
			button.Activated:Connect(function()
				if button:GetAttribute("Usable") then
					ctx.Remotes.SkillAction:FireServer(tier.Action.Id)
				end
			end)
			tiers[unlockLevel] = { Button = button, Tier = tier }
		end
		cards[skill.Id] = { Rank = rank, Level = level, Fill = fill, Tiers = tiers, Skill = skill }
	end
end

function Page.Render(s)
	state = s
	local data = (s.Modules and s.Modules.Skills) or {}
	local levels = data.Levels or {}
	local stage = Skills.Stage(s.Age)
	local open = Skills.CombatOpenAge - (s.TrainingAgeOffset or 0)
	Page.Stage.Text = ("%s  ·  ceiling %s  ·  sword & magic from age %d"):format(stage.Name,
		if stage.Cap == math.huge then "none" else tostring(stage.Cap), open)
	for id, card in cards do
		local entry = levels[id] or { Level = 0, Xp = 0 }
		local rank = Skills.Rank(entry.Level)
		card.Rank.Text = rank.Name
		local locked = Skills.CombatSkills[id] and s.Age < open
		card.Level.Text = if locked then ("Opens at age %d"):format(open)
			else ("Lv %d%s"):format(entry.Level, if entry.Level >= stage.Cap then "  ·  at your age's ceiling" else "")
		S.setBar(card.Fill, entry.Xp / Skills.XpForLevel(entry.Level))
		for unlockLevel, tier in card.Tiers do
			local action = tier.Tier.Action
			local unlocked = entry.Level >= unlockLevel
			local done = (data.Done or {})[action.Id] == s.Age
			local usable = unlocked and not done and not s.Dead and s.Age >= (action.MinAge or 12) and s.Actions > 0
			tier.Button:SetAttribute("Usable", usable)
			tier.Button.Text = if not unlocked then ("Lv %d  ·  %s"):format(unlockLevel, action.Name)
				elseif done then ("✔ %s  ·  done this year"):format(action.Name)
				else ("%s%s"):format(if action.Chance then "⚠ " else "▶ ", action.Name)
			if usable then
				S.paint(tier.Button, C.gold, C.gold2)
				tier.Button.TextColor3 = C.dark
			else
				S.paint(tier.Button, C.card1, C.card2)
				tier.Button.TextColor3 = if unlocked then C.text else C.muted
			end
		end
	end
end

return Page
