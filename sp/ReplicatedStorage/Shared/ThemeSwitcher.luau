--[[
	ThemeSwitcher (client): live UI color themes and the background Color Changer.
	Apply(themeId) recolors every on-screen GUI color that matches the current palette
	to the new theme's palette (backgrounds, text, images, strokes, gradients), and
	recolors GUI created later, so the switch is instant and needs no rebuild.
	Moonlight is the pack's own palette. SetBackdrop(id) tints the backdrop.
]]

local Players = game:GetService("Players")

local S = require(script.Parent:WaitForChild("UIStyle"))

local ThemeSwitcher = {}

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

ThemeSwitcher.Keys = { "gold", "gold2", "stroke", "panel1", "panel2", "card1", "card2", "bg1", "bg2", "qi1", "qi2" }
ThemeSwitcher.Palettes = {
	Gilded = { gold = rgb(245, 205, 95), gold2 = rgb(170, 120, 30), stroke = rgb(232, 192, 92), panel1 = rgb(36, 29, 16), panel2 = rgb(20, 15, 8),
		card1 = rgb(46, 37, 21), card2 = rgb(28, 22, 12), bg1 = rgb(20, 16, 8), bg2 = rgb(10, 8, 4), qi1 = rgb(255, 225, 140), qi2 = rgb(180, 140, 60) },
	Crimson = { gold = rgb(236, 92, 92), gold2 = rgb(150, 30, 42), stroke = rgb(220, 92, 92), panel1 = rgb(40, 14, 18), panel2 = rgb(22, 8, 10),
		card1 = rgb(50, 20, 24), card2 = rgb(30, 10, 14), bg1 = rgb(22, 8, 10), bg2 = rgb(12, 4, 6), qi1 = rgb(255, 140, 120), qi2 = rgb(170, 60, 60) },
	Starlit = { gold = rgb(172, 192, 255), gold2 = rgb(90, 100, 200), stroke = rgb(152, 172, 255), panel1 = rgb(16, 18, 40), panel2 = rgb(8, 10, 24),
		card1 = rgb(24, 28, 56), card2 = rgb(14, 16, 36), bg1 = rgb(10, 12, 30), bg2 = rgb(5, 6, 18), qi1 = rgb(140, 220, 255), qi2 = rgb(70, 120, 200) },
}
ThemeSwitcher.Backdrops = {
	Void = rgb(5, 6, 9), Dusk = rgb(40, 20, 50), Forest = rgb(10, 30, 18), Ocean = rgb(8, 20, 40), Ember = rgb(40, 14, 8),
}

local base = {}
for _, key in ThemeSwitcher.Keys do base[key] = S.C[key] end
local current = table.clone(base)
local currentId = "Moonlight"
local watching = false

local function key(color: Color3): string
	return ("%d,%d,%d"):format(math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

local function recolor(inst: Instance, map)
	local function swap(color: Color3): Color3?
		return map[key(color)]
	end
	if inst:IsA("GuiObject") then
		local to = swap(inst.BackgroundColor3)
		if to then inst.BackgroundColor3 = to end
		if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
			to = swap(inst.TextColor3)
			if to then inst.TextColor3 = to end
		end
		if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
			to = swap(inst.ImageColor3)
			if to then inst.ImageColor3 = to end
		end
		if inst:IsA("ScrollingFrame") then
			to = swap(inst.ScrollBarImageColor3)
			if to then inst.ScrollBarImageColor3 = to end
		end
	elseif inst:IsA("UIStroke") then
		local to = swap(inst.Color)
		if to then inst.Color = to end
	elseif inst:IsA("UIGradient") then
		local points, changed = {}, false
		for _, point in inst.Color.Keypoints do
			local to = swap(point.Value)
			changed = changed or to ~= nil
			table.insert(points, ColorSequenceKeypoint.new(point.Time, to or point.Value))
		end
		if changed then inst.Color = ColorSequence.new(points) end
	end
end

local function mapFrom(from, to)
	local map = {}
	for _, k in ThemeSwitcher.Keys do
		if from[k] and to[k] and key(from[k]) ~= key(to[k]) then
			map[key(from[k])] = to[k]
		end
	end
	return map
end

local function guis()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	return playerGui:GetChildren(), playerGui
end

function ThemeSwitcher.Apply(themeId: string?)
	themeId = if themeId and ThemeSwitcher.Palettes[themeId] then themeId else "Moonlight"
	if themeId == currentId then return end
	local target = ThemeSwitcher.Palettes[themeId] or base
	local map = mapFrom(current, target)
	local list, playerGui = guis()
	for _, gui in list do
		for _, inst in gui:GetDescendants() do
			recolor(inst, map)
		end
	end
	current, currentId = table.clone(target), themeId
	if not watching then
		watching = true
		-- GUI built later uses the pack palette: bring it to the current theme.
		playerGui.DescendantAdded:Connect(function(inst)
			if currentId ~= "Moonlight" then
				task.defer(recolor, inst, mapFrom(base, current))
			end
		end)
	end
end

function ThemeSwitcher.Current(): string
	return currentId
end

function ThemeSwitcher.SetBackdrop(id: string?)
	local color = ThemeSwitcher.Backdrops[id or "Void"] or ThemeSwitcher.Backdrops.Void
	local backdrop = Players.LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("LifePathBackdrop")
	local frame = backdrop and backdrop:FindFirstChild("Backdrop")
	if frame then frame.BackgroundColor3 = color end
end

return ThemeSwitcher
