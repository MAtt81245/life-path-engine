--[[
	DevConsoleClient: F2 toggles the Studio-only developer console. Builds no UI
	outside Studio or when the server did not create Remotes.DevCommand.
	Up/Down recall earlier commands.
]]

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DevCommand", 15)
if not remote then
	return
end

local S = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UIStyle"))
local C = S.C

local TOGGLE_KEY = Enum.KeyCode.F2
local MAX_LINES = 300

local gui = S.new("ScreenGui", {
	Name = "DevConsole", ResetOnSpawn = false, DisplayOrder = 50, Enabled = false,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
})

local panel = S.panel("Frame", {
	Name = "Panel", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8),
	Size = UDim2.new(0.64, 0, 0.52, 0), Parent = gui,
}, C.panel1, C.panel2, 12)
S.padding(panel, 10, 8)

S.new("TextLabel", {
	Name = "Title", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20),
	Font = S.Fonts.Bold, TextSize = 14, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Left,
	Text = "DEV CONSOLE  ·  Studio only  ·  F2 to close  ·  type help", Parent = panel,
})

local output = S.new("ScrollingFrame", {
	Name = "Output", Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, 0, 1, -66),
	BackgroundColor3 = C.inset, BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = C.stroke,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = panel,
})
S.new("UICorner", { CornerRadius = UDim.new(0, 8), Parent = output })
S.padding(output, 8, 6)
S.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1), Parent = output })

local input = S.new("TextBox", {
	Name = "Input", Position = UDim2.new(0, 0, 1, -34), Size = UDim2.new(1, 0, 0, 34),
	BackgroundColor3 = C.card2, BorderSizePixel = 0, ClearTextOnFocus = false, Text = "",
	PlaceholderText = "state  ·  why action Meditate  ·  year 5 auto  ·  event lost_wallet",
	PlaceholderColor3 = C.muted, TextColor3 = C.text, Font = Enum.Font.Code, TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Left, Parent = panel,
})
S.new("UICorner", { CornerRadius = UDim.new(0, 8), Parent = input })
S.new("UIStroke", { Color = C.stroke, Transparency = 0.5, Parent = input })
S.padding(input, 10, 0)

local lineCount = 0

local function append(text: string, color: Color3?)
	lineCount += 1
	S.new("TextLabel", {
		Name = "Line", LayoutOrder = lineCount, BackgroundTransparency = 1,
		Size = UDim2.new(1, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true,
		Font = Enum.Font.Code, TextSize = 14, TextColor3 = color or C.text,
		TextXAlignment = Enum.TextXAlignment.Left, Text = text, Parent = output,
	})
	local lines = {}
	for _, child in output:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(lines, child)
		end
	end
	if #lines > MAX_LINES then
		table.sort(lines, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
		for i = 1, #lines - MAX_LINES do
			lines[i]:Destroy()
		end
	end
	task.defer(function()
		output.CanvasPosition = Vector2.new(0, math.max(0, output.AbsoluteCanvasSize.Y - output.AbsoluteWindowSize.Y))
	end)
end

local history, cursor = {}, 0

local function run(line: string)
	append("> " .. line, C.gold)
	table.insert(history, line)
	cursor = #history + 1
	local ok, result = pcall(remote.InvokeServer, remote, line)
	if not ok or type(result) ~= "table" then
		append("Request failed: " .. tostring(result), C.red)
		return
	end
	for _, text in result do
		local bad = type(text) == "string" and (string.find(text, "^Error") or string.find(text, "^Unknown"))
		append(tostring(text), if bad then C.red else C.text)
	end
end

input.FocusLost:Connect(function(enterPressed)
	if not enterPressed then
		return
	end
	local line = string.gsub(input.Text, "^%s+", "")
	input.Text = ""
	if line ~= "" then
		task.spawn(run, line)
	end
	task.defer(function()
		if gui.Enabled then
			input:CaptureFocus()
		end
	end)
end)

local greeted = false
UserInputService.InputBegan:Connect(function(event)
	if event.KeyCode == TOGGLE_KEY then
		gui.Enabled = not gui.Enabled
		if gui.Enabled then
			if not greeted then
				greeted = true
				append("Developer console. Commands run on the server against your character. Type help.", C.muted)
			end
			task.defer(function()
				input:CaptureFocus()
			end)
		else
			input:ReleaseFocus()
		end
	elseif input:IsFocused() and (event.KeyCode == Enum.KeyCode.Up or event.KeyCode == Enum.KeyCode.Down) and #history > 0 then
		cursor = math.clamp(cursor + (if event.KeyCode == Enum.KeyCode.Up then -1 else 1), 1, #history + 1)
		input.Text = history[cursor] or ""
		input.CursorPosition = #input.Text + 1
	end
end)
