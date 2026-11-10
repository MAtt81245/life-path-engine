--[[
	Life Journal tab: chronological log of the current life.
]]

local Page = {}

local ctx, root, S, C
local entryOrder = 0
local MAX_ENTRIES = 80

function Page.Init(context, frame)
	ctx, root = context, frame
	S = ctx.Style
	C = S.C
end

function Page.AddEntry(entry)
	local scroll = root.LogScroll
	entryOrder += 1
	local color = S.KindColors[entry.Kind] or C.text
	local frame = S.new("Frame", {
		Name = "Entry",
		LayoutOrder = entryOrder,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	S.decorate(frame, C.card1, C.card2, color, 10, 0.6)
	S.fit(frame) -- grows with its text: 6 px top/bottom, 10 px left/right, never clipped
	S.new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = S.Fonts.Body,
		TextSize = 16,
		TextWrapped = true,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = color,
		Text = ('<font color="#%s"><b>Age %d</b></font>   %s'):format(C.gold:ToHex(), entry.Age, S.escape(entry.Text)),
		Parent = frame,
	})
	frame.Parent = scroll

	local entries = {}
	for _, child in scroll:GetChildren() do
		if child.Name == "Entry" then
			table.insert(entries, child)
		end
	end
	if #entries > MAX_ENTRIES then
		table.sort(entries, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
		for i = 1, #entries - MAX_ENTRIES do
			entries[i]:Destroy()
		end
	end
	task.defer(function()
		scroll.CanvasPosition = Vector2.new(0, math.max(0, scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteWindowSize.Y))
	end)
end

function Page.Rebuild(log)
	for _, child in root.LogScroll:GetChildren() do
		if child.Name == "Entry" then
			child:Destroy()
		end
	end
	for _, entry in log do
		Page.AddEntry(entry)
	end
end

function Page.Render()
end

return Page
