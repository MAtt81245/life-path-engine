--[[
	UIThemeConfig: the game's look and vocabulary, read through Shared/PackTheme
	(Shared/UIStyle applies it to every page, Shared/UITheme to the static layout,
	IntroAndLoadingUI to the loading/creation screens, PlayerState.Words to server
	messages). To reskin a cloned place for another game, edit only this table.

	Palette   Color3 per UIStyle.C key (bg, panels, cards, accent "gold", energy "qi", ...)
	          Key names are engine roles kept from the first game: "gold" is the primary
	          accent, "qi" the energy colour, "jackpot" the Mythic / VIP highlight.
	Fonts     Enum.Font names for Body / Bold / Heavy / Title / Mono (numbers, money, stats)
	Corner    multiplier for panel corner radii
	Style     "Dossier" = modern tactical layout and glass panels (Shared/UITheme.Layout);
	          omitted = the classic tome layout with double trims and corner gems
	TabIcons  optional icon per tab key (labels: GameManifest.Interface.TabLabels)
	Pip       action pip shape: Shape (label), Rotation (degrees), Corner (UDim scale, 0.5 = round)
	Terms     every genre word the interface and server messages show; code never
	          hardcodes them (PackTheme.Term(key) / Words("{Key}"), "{key}" = lowercase)
]]

return {
	Id = "jujutsu",
	Name = "Abyssal Curse",

	-- Abyssal curse black, midnight domain indigo, cursed violet, black-flash crimson,
	-- six-gaze cyan, jackpot gold.
	Palette = {
		bg1 = Color3.fromRGB(9, 8, 14), bg2 = Color3.fromRGB(5, 4, 9), -- #09080E
		ink = Color3.fromRGB(3, 2, 6),
		panel1 = Color3.fromRGB(16, 13, 28), panel2 = Color3.fromRGB(11, 9, 20), -- obsidian glass #0B0914
		card1 = Color3.fromRGB(24, 20, 38), card2 = Color3.fromRGB(16, 13, 26), -- #181426
		inset = Color3.fromRGB(7, 6, 12),
		stroke = Color3.fromRGB(157, 78, 221), -- #9D4EDD
		gold = Color3.fromRGB(157, 78, 221), gold2 = Color3.fromRGB(123, 44, 191), -- accent: cursed violet #9D4EDD / #7B2CBF
		qi1 = Color3.fromRGB(56, 189, 248), qi2 = Color3.fromRGB(14, 116, 170), -- energy: six-gaze cyan #38BDF8
		jade1 = Color3.fromRGB(120, 72, 210), jade2 = Color3.fromRGB(60, 30, 112),
		rose1 = Color3.fromRGB(244, 63, 94), rose2 = Color3.fromRGB(120, 16, 44),
		crimson1 = Color3.fromRGB(225, 29, 72), crimson2 = Color3.fromRGB(110, 10, 34), -- black-flash crimson #E11D48
		text = Color3.fromRGB(238, 234, 248), muted = Color3.fromRGB(152, 142, 176),
		dark = Color3.fromRGB(14, 6, 26),
		green = Color3.fromRGB(110, 220, 150), red = Color3.fromRGB(244, 80, 104),
		violet = Color3.fromRGB(196, 150, 255),
		jackpot = Color3.fromRGB(245, 158, 11), -- Mythic / VIP: jackpot gold #F59E0B
	},

	-- Modern urban-occult type: geometric sans for text and titles, mono for numbers.
	Fonts = { Body = "GothamMedium", Bold = "BuilderSansBold", Heavy = "GothamBlack", Title = "GothamBlack", Mono = "RobotoMono" },

	Corner = 0.34, -- 12 px panels -> 4 px

	Style = "Dossier", -- tactical sorcerer dossier layout, glass panels, no corner gems

	-- Cursed seal: a rotated diamond with sharper corners.
	Pip = { Shape = "CursedSeal", Rotation = 45, Corner = 0.04 },

	TabIcons = {
		Training = "⚔", Study = "🎒", Masters = "🥋", Social = "👥", Progression = "⚡",
		Inventory = "🗡", Journal = "📓", Family = "🩸", Lineage = "👁",
	},

	Terms = {
		Genre = "jujutsu",
		EnergyName = "Cursed Energy", -- the resource the progress bar fills
		EnergyShort = "CE",
		EnergyHeader = "CURSED ENERGY",
		TierSystemName = "Sorcerer Grade",
		TierHeader = "SORCERER GRADE",
		TierName = "Grade",
		TierDormant = "Cursed energy dormant",
		AdvanceTierButton = "PROMOTION",
		AdvanceTierName = "Grade Promotion", -- the act of advancing, in sentences
		AscendButton = "TRANSCEND",
		AscendHint = "Become a calamity of legend",
		MentorsTab = "Mentors",
		SectName = "Jujutsu Faction",
		MentorName = "Mentor",
		StudentName = "Student",
		RebirthTab = "Rebirth",
		RebirthName = "Cursed Reincarnation",
		WheelName = "Wheel of Curses",
		RebirthWheel = "Wheel of Curses",
		MetaCurrency = "Binding Vows",
		MetaCurrencyIcon = "❖", -- glyphs must exist in the UI fonts (✦ ✧ ⬢ do not)
		MoneyName = "Yen",
		MoneySymbol = "¥",
		RaceName = "Sorcerer Clan",
		RaceNamePlural = "Sorcerer Clans",
		LegacyName = "Innate Origin",
		HeirloomName = "Cursed Tool",
		GradeLabel = "Cursed Energy Trait", -- genetics grade shown on people
		GradeSuffix = "", -- after a grade name in short lines ("Standard Flow")
		Incarnation = "INCARNATION",
		ActionPip = "◆",
		ActionsHeader = "ACTIONS THIS YEAR",
		ActionsName = "Cursed Seals",
		DeceasedHint = "Turn the Wheel of Curses",
		ShopName = "Cursed Black Market",
		ShopButton = "💀 Black Market",
		ShopTagline = "Cursed objects, binding vows and forbidden arts",
		ReviveTitle = "Death's Threshold",
		ReviveButton = "Reverse Cursed Technique",
		ReviveHint = "Revive at 50% HP & keep your current life",
		AcceptFate = "Accept death",
		LoadingTitle = "CURSED PATH",
		LoadingSubtitle = "SORCERER LINEAGE",
		LoadingStage1 = "ENTERING THE VEIL...",
		LoadingStage2 = "CURSED ENERGY RESONATING...",
		LoadingStage3 = "BINDING YOUR SOUL...",
		LoadingStage4 = "DRAWING THE DOMAIN...",
		LoadingStage5 = "THE VEIL IS DOWN.",
		LoadingDone = "DESCENDING INTO THE VEIL...",
		ReviveLine = "Reverse Cursed Energy drags you back from death. You live on!",
		ReviveLog = "%s reverses death with Reverse Cursed Energy and draws breath again at age %d.",
		BirthLine = "Curses already feed on this world's fear.",
		PeakLine = "You stand at the peak of jujutsu.",
		AscendRequirement = "Only a Heian Calamity at the ninth level can transcend.",
		AscendLog = "%s transcends humanity and becomes a calamity of legend. (Transcendence #%d)",
		AscendDeath = "Transcended into a calamity of legend.",
		AscendDone = "You have transcended!",
		AscendTitle = "Calamity of Legend",
		LegacyBuffName = "Cursed Legacy",
		AscendOutro = "The Wheel of Curses turns once more. Your legend will outlive every curse.",
		SpiritRootTutorial = "Your cursed energy has awakened! Train it and earn Grade Promotions to extend your lifespan.",
		CreationTutorial = "Spin for your Sorcerer Clan & Innate Origin. Rare clans pass down to your children!",
	},
}
