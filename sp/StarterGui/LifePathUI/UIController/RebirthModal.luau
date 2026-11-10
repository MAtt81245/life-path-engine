--[[
	RebirthModal: the death screen's two organic choices (HistoryConfig.Rebirth;
	Modules/HistorySystem via the Reincarnate remote, action "Organic").
	- Continue as your Child / Heir: the family's city, wealth, Family Weapon, Grimoire
	  and bloodline.
	- Reincarnate as a Random Soul: region, social class, parents and lineage rolled anew.
	No region, class or faction is ever picked from a menu. "Visit the Wheel first"
	closes it for talent spins; the Today page offers it again while dead.
	Init(ctx), Open(), Render(snapshot).
]]

local Modal = {}

local ctx, S, C, History
local ui = {}
local state = nil
local dismissedLife = nil

local function scale(x, y) return UDim2.fromScale(x, y) end

local function card(parent, x: number, title: string, color: Color3, onClick)
	local frame = S.panel("TextButton", { Name = title, Text = "", AutoButtonColor = false, Position = scale(x, 0.2), Size = scale(0.48, 0.62),
		ZIndex = 66, Parent = parent }, C.card1, C.card2, 14, color)
	S.padding(frame, 16, 12)
	S.label({ Name = "Title", Text = title, Font = S.Fonts.Title, TextColor3 = color, Size = scale(1, 0.18), ZIndex = 67, Parent = frame }, 24)
	local body = S.label({ Name = "Body", Text = "", RichText = true, TextYAlignment = Enum.TextYAlignment.Top, Position = scale(0, 0.22),
		Size = scale(1, 0.58), ZIndex = 67, Parent = frame }, 15)
	local go = S.button({ Name = "Go", Text = "Choose this", Font = S.Fonts.Heavy, Position = scale(0.15, 0.84), Size = scale(0.7, 0.16), ZIndex = 67, Parent = frame }, nil, nil, 17)
	go.Activated:Connect(onClick)
	frame.Activated:Connect(onClick)
	return body
end

function Modal.Init(context)
	ctx = context
	S = ctx.Style
	C = S.C
	History = ctx.Content.Get("HistoryConfig")
	local overlay = S.new("Frame", { Name = "RebirthModal", Size = scale(1, 1), BackgroundColor3 = C.ink, BackgroundTransparency = 0.15, BorderSizePixel = 0,
		ZIndex = 64, Visible = false, Parent = ctx.Gui })
	ctx.Shield.Attach(overlay)
	local panel = S.new("Frame", { Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = scale(0.5, 0.5), Size = scale(0.78, 0.78), ZIndex = 65, Parent = overlay })
	S.padding(panel, 18, 14)
	ctx.Theme.frame(panel, 16, C.panel1, C.bg2)
	ui.Title = S.label({ Name = "Title", Text = "Your story ends here", Font = S.Fonts.Title, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Center,
		Size = scale(1, 0.1), ZIndex = 66, Parent = panel }, 30)
	ui.Sub = S.label({ Name = "Sub", Text = "", TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Center, Position = scale(0, 0.1), Size = scale(1, 0.07), ZIndex = 66, Parent = panel }, 15)
	local function choose(choice: string)
		return function()
			ctx.Remotes.Reincarnate:FireServer("Organic", choice)
			overlay.Visible = false
		end
	end
	ui.Heir = card(panel, 0, History.Rebirth.Heir.Name, C.gold, choose("Heir"))
	ui.Random = card(panel, 0.52, History.Rebirth.Random.Name, C.qi1, choose("Random"))
	local wheel = S.ghostButton({ Name = "Wheel", Text = "Visit the Wheel first (talent spins)", Position = scale(0.3, 0.88), Size = scale(0.4, 0.1), ZIndex = 66, Parent = panel }, 14)
	wheel.Activated:Connect(function()
		dismissedLife = state and state.Lives
		overlay.Visible = false
		ctx.SelectTab("Lineage")
	end)
	ui.Overlay = overlay
end

function Modal.Render(s)
	state = s
	if not ui.Overlay then return end
	if not s.Dead then
		ui.Overlay.Visible = false
		dismissedLife = nil
		return
	end
	if dismissedLife ~= s.Lives and not (ctx.IsShopOpen and ctx.IsShopOpen()) then
		ui.Overlay.Visible = true
	end
	local heir, wealth = nil, 0
	for _, rel in s.Relationships or {} do
		if rel.Alive and rel.Type == "Child" and (not heir or rel.Age > heir.Age) then heir = rel end
	end
	local paths = ctx.Content.Get("RebirthPathsConfig")
	local share = (paths.ById.Descendant and paths.ById.Descendant.WealthShare) or 0.25
	wealth = math.floor((s.Money or 0) * share)
	local world = s.Modules and s.Modules.World
	local regions = ctx.Config.Regions
	local region = world and world.Region and regions and regions.Get and regions.Get(world.Region)
	local weapon = s.World and s.World.FamilyWeapon
	ui.Sub.Text = ("%s died at %d: %s"):format(S.escape(s.Name), s.Age, s.DeathCause or "")
	ui.Heir.Text = table.concat({
		if heir then ("You become <b>%s</b>, your child (age %d)."):format(S.escape(heir.Name), heir.Age) else "You are born into your own house again.",
		("City: <b>%s</b>"):format(if region then region.Name else "your home"),
		("Wealth carried on: <b>%s</b>"):format(S.money(wealth)),
		("Family Weapon: <b>%s</b>"):format(if weapon then weapon.Name else "none yet"),
		("Family Grimoire: <b>%d</b> spell%s"):format(#(s.Grimoire or {}), if #(s.Grimoire or {}) == 1 then "" else "s"),
		"Blended genetics of your bloodline.",
	}, "\n")
	ui.Random.Text = table.concat({
		"A stranger's cradle somewhere in the world.",
		"Region: <b>rolled</b>",
		"Social class: <b>Poor, Commoner or Noble</b>",
		"Parents and lineage: <b>new</b>",
		"Rare birth anomalies can appear in any birth.",
		"Your Grimoire, Legacy upgrades and World Chronicle stay with your soul.",
	}, "\n")
end

function Modal.Open()
	dismissedLife = nil
	if state then Modal.Render(state) end
end

return Modal
