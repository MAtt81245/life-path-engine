--[[
	MinigameModal: the Today page minigames (MinigamesConfig; Modules/MinigameSystem via
	the Minigame remote). A shielded full-screen popup.
	- Catch the Light: blue and gold motes appear and fade for 15 seconds; click them.
	- Sneak to the Study: hold to crawl while Mother hums; let go when she turns around.
	Init(ctx), Open(id), Render(snapshot).
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Modal = {}

local ctx, S, C, Config
local ui = {}
local session = 0

local function scale(x, y) return UDim2.fromScale(x, y) end

local function finish(token: number, id: string, result, text: string)
	if token ~= session then
		return
	end
	session += 1
	ui.Status.Text = text
	ctx.Remotes.Minigame:FireServer(id, result)
	task.delay(1.6, function()
		ui.Overlay.Visible = false
	end)
end

local function clearArena()
	for _, child in ui.Arena:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function playMotes()
	session += 1
	local token = session
	local def = Config.Motes
	local score, started = 0, os.clock()
	clearArena()
	ui.Title.Text = def.Icon .. "  " .. def.Name
	ui.Hold.Visible = false
	task.spawn(function()
		while token == session and os.clock() - started < def.Seconds do
			local gold = math.random() < 0.18
			local size = if gold then 34 else 42
			local mote = S.new("TextButton", { Name = "Mote", Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5),
				Position = scale(math.random() * 0.9 + 0.05, math.random() * 0.8 + 0.1), Size = UDim2.fromOffset(size, size),
				BackgroundColor3 = if gold then C.gold else C.qi1, BackgroundTransparency = 0.1, ZIndex = 64, Parent = ui.Arena })
			S.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = mote })
			S.new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 0.4, Parent = mote })
			local fade = TweenService:Create(mote, TweenInfo.new(1.4), { BackgroundTransparency = 1, Size = UDim2.fromOffset(size * 0.4, size * 0.4) })
			fade.Completed:Connect(function() mote:Destroy() end)
			fade:Play()
			mote.Activated:Connect(function()
				if token ~= session or not mote.Parent then return end
				score = math.min(def.MaxScore, score + (if gold then def.Gold else 1))
				mote:Destroy()
			end)
			task.wait(0.32)
		end
	end)
	task.spawn(function()
		while token == session and os.clock() - started < def.Seconds do
			ui.Status.Text = ("Score %d  ·  %d s left"):format(score, math.ceil(def.Seconds - (os.clock() - started)))
			task.wait(0.1)
		end
		if token == session then
			clearArena()
			finish(token, "Motes", score, ("Time! You caught %d motes of light."):format(score))
		end
	end)
end

local function playSneak()
	session += 1
	local token = session
	local def = Config.Sneak
	clearArena()
	ui.Title.Text = def.Icon .. "  " .. def.Name
	ui.Hold.Visible = true
	local floor = S.new("Frame", { Name = "Floor", Position = scale(0.05, 0.62), Size = scale(0.9, 0.08), BackgroundColor3 = C.inset, BorderSizePixel = 0, ZIndex = 64, Parent = ui.Arena })
	S.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = floor })
	S.label({ Name = "Door", Text = "📚 STUDY", Font = S.Fonts.Heavy, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Right, Position = scale(0.7, 0.45),
		Size = scale(0.25, 0.14), ZIndex = 64, Parent = ui.Arena }, 16)
	local kid = S.label({ Name = "You", Text = "🧒", TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 1),
		Position = scale(0.07, 0.62), Size = UDim2.fromOffset(40, 40), ZIndex = 65, Parent = ui.Arena }, 36)
	local mother = S.label({ Name = "Mother", Text = "", Font = S.Fonts.Title, TextXAlignment = Enum.TextXAlignment.Center, Position = scale(0, 0.1),
		Size = scale(1, 0.2), ZIndex = 64, Parent = ui.Arena }, 26)
	local progress, watching, phase, phaseEnds = 0, false, "humming", os.clock() + 2.5
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if token ~= session then
			conn:Disconnect()
			return
		end
		local now = os.clock()
		if now >= phaseEnds then
			if phase == "humming" then
				phase, phaseEnds = "pausing", now + 0.6
			elseif phase == "pausing" then
				phase, phaseEnds = "watching", now + math.random(12, 20) / 10
			else
				phase, phaseEnds = "humming", now + math.random(15, 35) / 10
			end
		end
		watching = phase == "watching"
		mother.Text = if phase == "humming" then "🎵 Mother is humming..." elseif phase == "pausing" then "Mother stops humming..." else "👀 MOTHER TURNS AROUND!"
		mother.TextColor3 = if watching then C.red elseif phase == "pausing" then C.gold else C.green
		if ui.Holding then
			if watching then
				conn:Disconnect()
				finish(token, "Sneak", false, "Caught! Mother saw you move.")
				return
			end
			progress = math.min(1, progress + def.CrawlSpeed * dt)
			kid.Position = scale(0.07 + progress * 0.8, 0.62)
			if progress >= 1 then
				conn:Disconnect()
				finish(token, "Sneak", true, "You made it into the study!")
				return
			end
		end
		ui.Status.Text = ("Progress %d%%  ·  hold to crawl, let go when she turns"):format(math.floor(progress * 100))
	end)
end

function Modal.Init(context)
	ctx = context
	S = ctx.Style
	C = S.C
	Config = ctx.Content.Get("MinigamesConfig")
	local overlay = S.new("Frame", { Name = "MinigameModal", Size = scale(1, 1), BackgroundColor3 = C.ink, BackgroundTransparency = 0.25, BorderSizePixel = 0,
		ZIndex = 62, Visible = false, Parent = ctx.Gui })
	ctx.Shield.Attach(overlay)
	local card = S.new("Frame", { Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = scale(0.5, 0.5), Size = scale(0.66, 0.74), ZIndex = 63, Parent = overlay })
	S.padding(card, 16, 12)
	ctx.Theme.frame(card, 14, C.panel1, C.bg2)
	ui.Title = S.label({ Name = "Title", Text = "", Font = S.Fonts.Title, TextColor3 = C.gold, Size = scale(0.8, 0.1), ZIndex = 64, Parent = card }, 24)
	local close = S.ghostButton({ Name = "Close", Text = "Close", Position = scale(0.84, 0), Size = scale(0.16, 0.09), ZIndex = 64, Parent = card }, 14)
	close:SetAttribute("TouchSafe", true) -- header button; a 44 px minimum covered the title on phones
	close.Activated:Connect(function()
		session += 1 -- abandoning a game spends nothing
		overlay.Visible = false
	end)
	ui.Arena = S.new("Frame", { Name = "Arena", Position = scale(0, 0.12), Size = scale(1, 0.66), BackgroundColor3 = C.bg2, BackgroundTransparency = 0.2,
		ClipsDescendants = true, ZIndex = 63, Parent = card })
	S.new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = ui.Arena })
	ui.Status = S.label({ Name = "Status", Text = "", Font = S.Fonts.Bold, TextXAlignment = Enum.TextXAlignment.Center, Position = scale(0, 0.8), Size = scale(1, 0.07), ZIndex = 64, Parent = card }, 16)
	ui.Hold = S.button({ Name = "Hold", Text = "HOLD TO CRAWL", Font = S.Fonts.Heavy, Position = scale(0.3, 0.88), Size = scale(0.4, 0.12), ZIndex = 64, Parent = card }, nil, nil, 18)
	ui.Hold.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			ui.Holding = true
		end
	end)
	ui.Hold.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			ui.Holding = false
		end
	end)
	ui.Overlay = overlay
end

function Modal.Open(id: string)
	ui.Holding = false
	ui.Overlay.Visible = true
	if id == "Motes" then
		playMotes()
	else
		playSneak()
	end
end

-- Which games can be played now (Today page cards).
function Modal.Available(s): { string }
	local list = {}
	if not ctx.GamePack.IsActive("Minigames") or s.Dead then
		return list
	end
	local played = (s.Modules.Minigames and s.Modules.Minigames.Played) or {}
	for _, id in { "Motes", "Sneak" } do
		local def = Config[id]
		if played[id] ~= s.Age and s.Age >= def.MinAge and s.Age <= (def.MaxAge or math.huge) then
			table.insert(list, id)
		end
	end
	return list
end

return Modal
