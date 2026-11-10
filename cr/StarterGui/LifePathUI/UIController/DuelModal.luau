--[[
	DuelModal: the Tactical Clash (Modules/DuelSystem, DuelConfig). Shows your fighter
	card against the opponent's (HP, power, weapon, technique, style), the exchange log,
	three stance buttons (Strike beats Channel, Channel beats Guard, Guard beats Strike)
	and Quick Resolve; when the duel ends, the result and Continue. Driven by the
	snapshot's PendingDuel; actions go through the DuelAction remote.
]]

local TweenService = game:GetService("TweenService")

local Modal = {}

local ctx, S, C, Duel
local ui = {}
local shownRound = -1

local function scale(x, y) return UDim2.fromScale(x, y) end

local function fighterCard(parent, name: string, x: number, accent: Color3)
	local card = S.new("Frame", { Name = name, Position = scale(x, 0.12), Size = scale(0.42, 0.36), ZIndex = 52, Parent = parent })
	S.decorate(card, C.card1, C.card2, accent, 12, 0.2)
	S.padding(card, 12, 8)
	local entry = { Card = card }
	entry.Name = S.label({ Name = "FighterName", Text = "", Font = S.Fonts.Title, TextColor3 = accent, Size = scale(1, 0.2), ZIndex = 53, Parent = card }, 20)
	S.label({ Name = "HPKey", Text = "HEALTH", Font = S.Fonts.Bold, TextColor3 = C.muted, Position = scale(0, 0.23), Size = scale(0.5, 0.1), ZIndex = 53, Parent = card }, 11)
	local _, hp = S.bar({ Name = "HPBar", Position = scale(0, 0.34), Size = scale(1, 0.09), ZIndex = 53, Parent = card }, C.rose1)
	S.label({ Name = "PowerKey", Text = "QI / POWER", Font = S.Fonts.Bold, TextColor3 = C.muted, Position = scale(0, 0.46), Size = scale(0.5, 0.1), ZIndex = 53, Parent = card }, 11)
	local _, power = S.bar({ Name = "PowerBar", Position = scale(0, 0.57), Size = scale(1, 0.09), ZIndex = 53, Parent = card }, C.qi1)
	entry.HP, entry.Power = hp, power
	entry.Weapon = S.label({ Name = "Weapon", Text = "", TextColor3 = C.text, Position = scale(0, 0.7), Size = scale(1, 0.14), ZIndex = 53, Parent = card }, 13)
	entry.Technique = S.label({ Name = "Technique", Text = "", TextColor3 = C.gold, Position = scale(0, 0.85), Size = scale(1, 0.14), ZIndex = 53, Parent = card }, 13)
	return entry
end

function Modal.Init(context)
	ctx = context
	S = ctx.Style
	C = S.C
	Duel = ctx.Content.Get("DuelConfig")
	local remote = ctx.Remotes:WaitForChild("DuelAction")
	local overlay = S.new("Frame", { Name = "DuelModal", Size = scale(1, 1), BackgroundColor3 = C.ink, BackgroundTransparency = 0.3,
		BorderSizePixel = 0, ZIndex = 50, Visible = false, Active = true, Parent = ctx.Gui })
	local card = S.new("Frame", { Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = scale(0.5, 0.5), Size = scale(0.62, 0.8), ZIndex = 51, Parent = overlay })
	S.padding(card, 20, 16) -- before the frame: the trim is placed relative to the padding
	if ctx.Theme then ctx.Theme.frame(card, 16) else S.decorate(card) end
	ui.Pop = S.new("UIScale", { Parent = card })
	ui.Title = S.label({ Name = "Title", Text = "", Font = S.Fonts.Title, TextColor3 = C.gold, Size = scale(0.62, 0.09), ZIndex = 52, Parent = card }, 26)
	ui.Score = S.label({ Name = "Score", Text = "", Font = S.Fonts.Bold, TextColor3 = C.text, Position = scale(0.62, 0), Size = scale(0.38, 0.09),
		TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 52, Parent = card }, 16)
	ui.You = fighterCard(card, "YouCard", 0, C.qi1)
	ui.Foe = fighterCard(card, "FoeCard", 0.58, C.rose1)
	S.label({ Name = "Versus", Text = "VS", Font = S.Fonts.Heavy, TextColor3 = C.gold, Position = scale(0.42, 0.24), Size = scale(0.16, 0.12),
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 52, Parent = card }, 30)
	ui.Log = S.label({ Name = "Log", Text = "", RichText = true, TextColor3 = C.text, Position = scale(0, 0.51), Size = scale(1, 0.12),
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 52, Parent = card }, 16)
	ui.Stances = {}
	for i, id in Duel.StanceOrder do
		local stance = Duel.Stances[id]
		local button = S.new("TextButton", { Name = id .. "Stance", Text = "", AutoButtonColor = false, Position = scale((i - 1) * 0.34, 0.66),
			Size = scale(0.32, 0.2), ZIndex = 52, Parent = card })
		S.decorate(button, C.card1, C.card2, C.gold, 10, 0.3)
		S.label({ Name = "Label", Text = stance.Icon .. "  " .. stance.Name, Font = S.Fonts.Bold, TextColor3 = C.gold, Position = scale(0.06, 0.06), Size = scale(0.88, 0.32),
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 53, Parent = button }, 16)
		S.label({ Name = "Beats", Text = ("Beats %s"):format(Duel.Stances[stance.Beats].Short or Duel.Stances[stance.Beats].Name), TextColor3 = C.muted, Position = scale(0.06, 0.4), Size = scale(0.88, 0.22),
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 53, Parent = button }, 12)
		local power = S.label({ Name = "Power", Text = "", Font = S.Fonts.Bold, TextColor3 = C.qi1, Position = scale(0.06, 0.66), Size = scale(0.88, 0.26),
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 53, Parent = button }, 13)
		local stroke = button:FindFirstChildOfClass("UIStroke")
		button.MouseEnter:Connect(function() stroke.Transparency = 0 end)
		button.MouseLeave:Connect(function() stroke.Transparency = 0.3 end)
		button.Activated:Connect(function()
			if button.Active then remote:FireServer("Stance", id) end
		end)
		ui.Stances[id] = { Button = button, Power = power }
	end
	ui.Quick = S.ghostButton({ Name = "QuickResolve", Text = "Quick Resolve", Position = scale(0, 0.89), Size = scale(0.36, 0.11), ZIndex = 52, Parent = card }, 15)
	ui.Quick.Activated:Connect(function() remote:FireServer("Quick") end)
	ui.Continue = S.button({ Name = "Continue", Text = "Continue  →", Position = scale(0.64, 0.89), Size = scale(0.36, 0.11), ZIndex = 52, Parent = card }, nil, nil, 16)
	ui.Continue.Activated:Connect(function() remote:FireServer("Close") end)
	ui.Overlay = overlay
end

local function stanceText(id: string): string
	local stance = Duel.Stances[id]
	return stance and (stance.Icon .. " " .. (stance.Short or stance.Name)) or id
end

function Modal.Render(s)
	local duel = s.PendingDuel
	if not duel then
		ui.Overlay.Visible = false
		shownRound = -1
		return
	end
	if not ui.Overlay.Visible then
		ui.Overlay.Visible = true
		ui.Pop.Scale = 0.9
		TweenService:Create(ui.Pop, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	ui.Title.Text = duel.Title
	ui.Score.Text = ("Exchange %d / 3   ·   %d - %d"):format(math.min(duel.Round + (if duel.Done then 0 else 1), 3), duel.Wins, duel.Losses)
	local function avg(powers)
		local total = 0
		for _, id in Duel.StanceOrder do total += powers[id] or 0 end
		return total / #Duel.StanceOrder
	end
	local top = math.max(avg(duel.You.Powers), avg(duel.Foe.Powers), 1)
	for key, entry in { You = ui.You, Foe = ui.Foe } do
		local fighter = duel[key]
		entry.Name.Text = fighter.Name
		S.setBar(entry.HP, fighter.HP / 100)
		S.setBar(entry.Power, avg(fighter.Powers) / top)
		entry.Weapon.Text = "Weapon: " .. tostring(fighter.Weapon)
		entry.Technique.Text = if key == "Foe" then ("Art: %s  ·  favors %s"):format(fighter.Technique, stanceText(fighter.Style)) else "Art: " .. tostring(fighter.Technique)
	end
	local last = duel.Log[#duel.Log]
	if duel.Done then
		ui.Log.Text = ('<font color="#%s"><b>%s</b></font>\n%s'):format((if duel.Won then C.green else C.red):ToHex(), if duel.Won then "VICTORY" else "DEFEAT", S.escape(duel.Result or ""))
	elseif last then
		ui.Log.Text = ("%s (%d)  vs  %s (%d)\n%s"):format(stanceText(last.Yours), last.YourPower, stanceText(last.Theirs), last.FoePower,
			if last.Won then "You win the exchange!" else "The exchange goes to your opponent.")
	else
		ui.Log.Text = "Choose your stance. Strike beats Channel, Channel beats Guard, Guard beats Strike."
	end
	for id, entry in ui.Stances do
		entry.Power.Text = ("Power %d"):format(duel.You.Powers[id] or 0)
		S.setEnabled(entry.Button, not duel.Done)
	end
	ui.Quick.Visible = not duel.Done
	ui.Continue.Visible = duel.Done
	-- A little shake on every new exchange.
	if duel.Round ~= shownRound then
		shownRound = duel.Round
		if duel.Round > 0 then
			local card = ui.Pop.Parent
			local base = card.Position
			for i = 1, 4 do
				task.delay(i * 0.03, function()
					card.Position = base + UDim2.fromOffset(if i % 2 == 0 then -6 else 6, 0)
				end)
			end
			task.delay(0.15, function() card.Position = base end)
		end
	end
end

return Modal
