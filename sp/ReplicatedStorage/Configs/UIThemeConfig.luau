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
	Id = "bleach",
	Name = "Shihakusho & Reiatsu",

	-- Garganta pitch black, Seireitei slate, reiatsu sky cyan, bone white, bankai flame.
	-- Role keys stay engine roles: "gold" = primary accent (cyan), "crimson" = secondary
	-- accent (flame orange), "qi" = the energy bar (light reiatsu cyan).
	Palette = {
		bg1 = Color3.fromRGB(6, 8, 13), bg2 = Color3.fromRGB(3, 4, 7), -- Garganta #06080D
		ink = Color3.fromRGB(2, 3, 5),
		panel1 = Color3.fromRGB(19, 27, 40), panel2 = Color3.fromRGB(13, 19, 28), -- panel #131B28 / Seireitei slate #0D131C
		card1 = Color3.fromRGB(24, 34, 50), card2 = Color3.fromRGB(17, 24, 36),
		inset = Color3.fromRGB(8, 11, 17),
		stroke = Color3.fromRGB(56, 189, 248), -- reiatsu sky cyan #38BDF8
		gold = Color3.fromRGB(56, 189, 248), gold2 = Color3.fromRGB(14, 116, 170), -- accent: reiatsu cyan
		qi1 = Color3.fromRGB(125, 211, 252), qi2 = Color3.fromRGB(14, 116, 170), -- energy: light reiatsu
		jade1 = Color3.fromRGB(94, 234, 212), jade2 = Color3.fromRGB(13, 148, 136),
		rose1 = Color3.fromRGB(251, 113, 133), rose2 = Color3.fromRGB(136, 19, 55),
		crimson1 = Color3.fromRGB(249, 115, 22), crimson2 = Color3.fromRGB(154, 52, 18), -- bankai flame #F97316
		text = Color3.fromRGB(248, 250, 252), muted = Color3.fromRGB(148, 163, 184), -- bone white #F8FAFC
		dark = Color3.fromRGB(6, 10, 18),
		green = Color3.fromRGB(110, 220, 150), red = Color3.fromRGB(248, 90, 90),
		violet = Color3.fromRGB(165, 180, 252),
		jackpot = Color3.fromRGB(245, 158, 11), -- Mythic / VIP gold
	},

	-- Sharp anime typography: Michroma headers, Gotham buttons, RobotoMono numbers.
	Fonts = { Body = "GothamMedium", Bold = "GothamBold", Heavy = "GothamBlack", Title = "Michroma", Mono = "RobotoMono" },

	Corner = 0.17, -- 12 px panels -> 2 px angular corners

	Style = "SoulPass", -- Soul Pass card, twin-wing pages, right mastery pillar, bottom command deck

	-- Spirit seal: a sharp diamond.
	Pip = { Shape = "SpiritSeal", Rotation = 45, Corner = 0 },

	TabIcons = {
		Training = "⚔", Study = "🎓", Masters = "🥋", Social = "👥", Progression = "⚡",
		Inventory = "🎒", Journal = "📜", Family = "🩸", Lineage = "🦋",
	},

	-- 3D backdrop (StarterPlayerScripts/VoidScene): a glowing reishi tree in the dark,
	-- tinted by the palette accent (reiatsu cyan).
	Scene = {
		Enabled = true,
		Seed = 1016, -- same tree for everyone
		Depth = 6, -- branch generations
		PanelTransparency = 0.12,
		BackdropTransparency = 0.6, -- the 2D gradient left over the 3D scene
		BreathSeconds = 5,
	},

	Terms = {
		Genre = "bleach",
		LadderTitle = "Soul Origin Ladder", -- birth screen odds column
		TalentName = "Innate Soul Gift", -- third birth card
		-- Kido, Zanjutsu and hunt vocabulary (Arcana page, battles, Legends).
		ManaName = "Reiryoku", SpellbookName = "Kido scrolls", SpellForgeName = "Kido Forge",
		SilentTrialName = "Chantless Kido Trial", SilentMasteredName = "Chantless Kido mastered",
		SwordAuraTitle = "Zanpakuto & Reiatsu", BattlesName = "Hollow Hunts", SpecialSchoolsName = "FORBIDDEN SCHOOLS",
		FamilyWeaponName = "Clan Blade", GrimoireName = "Clan Kido Grimoire",
		EnergyName = "Reiatsu", -- the resource the progress bar fills
		EnergyShort = "SP",
		EnergyHeader = "REIATSU",
		TierSystemName = "Spiritual Class",
		TierHeader = "SPIRITUAL CLASS",
		TierName = "Class",
		TierDormant = "Spiritual power dormant",
		AdvanceTierButton = "AWAKEN",
		AdvanceTierName = "Soul Awakening", -- the act of advancing, in sentences
		AscendButton = "ASCEND",
		AscendHint = "Ascend to the Soul King's palace",
		MentorsTab = "Mentors",
		SectName = "Division / Faction",
		MentorName = "Mentor",
		StudentName = "Student",
		RebirthTab = "Rebirth",
		RebirthName = "Samsara Senkaimon",
		WheelName = "Wheel of Souls",
		RebirthWheel = "Wheel of Souls",
		MetaCurrency = "Hogyoku Shards",
		MetaCurrencyIcon = "●", -- glyphs must exist in the UI fonts (✦ ✧ ⬢ do not)
		MoneyName = "Kan",
		MoneySymbol = "Kan ",
		RaceName = "Soul Origin",
		RaceNamePlural = "Soul Origins",
		LegacyName = "Spiritual Heritage",
		HeirloomName = "Inherited Zanpakuto",
		GradeLabel = "Inner World Resonance", -- genetics grade shown on people
		GradeSuffix = "", -- after a grade name in short lines
		Incarnation = "INCARNATION",
		ActionPip = "◆",
		ActionsHeader = "ACTIONS THIS YEAR",
		ActionsName = "Spirit Seals",
		DeceasedHint = "Pass through the Senkaimon",
		ShopName = "Urahara Shop",
		ShopButton = "🏮 Urahara Shop",
		ShopTagline = "Soul candy, gigai and suspiciously cheap miracles",
		ReviveTitle = "Soul Chain Severed",
		ReviveButton = "Reject Fate",
		ReviveHint = "Revive at 50% HP & keep your current life",
		AcceptFate = "Pass on",
		LoadingEmblem = "⚔",
		MapTitle = "The Three Worlds",
		LoadingTitle = "SOUL PATH",
		LoadingSubtitle = "ZANPAKUTO DYNASTY",
		LoadingStage1 = "SPIRITUAL PRESSURE AWAKENING...",
		LoadingStage2 = "TUNING INTO THE REISHI...",
		LoadingStage3 = "BINDING YOUR SOUL CHAIN...",
		LoadingStage4 = "OPENING THE SENKAIMON...",
		LoadingStage5 = "THE GATE IS OPEN.",
		LoadingDone = "CROSSING INTO THE WORLD OF THE LIVING...",
		ReviveLine = "You reject your fate and your soul chain mends. You live on!",
		ReviveLog = "%s rejects fate, mends the soul chain and draws breath again at age %d.",
		BirthLine = "Hollows already hunger for souls like yours.",
		PeakLine = "You stand at the peak of the three worlds.",
		AscendRequirement = "Only a Transcendent Hybrid at the ninth level can ascend.",
		AscendLog = "%s ascends to the Soul King's palace. (Ascension #%d)",
		AscendDeath = "Ascended to the Soul King's palace.",
		AscendDone = "You have ascended!",
		AscendTitle = "Royal Ascendant",
		LegacyBuffName = "Royal Legacy",
		AscendOutro = "The Wheel of Souls turns once more. Your name is carved into the Royal Palace.",
		SpiritRootTutorial = "Your spiritual pressure has awakened! Train your Reiatsu and earn Soul Awakenings to extend your lifespan.",
		CreationTutorial = "Spin for your Soul Origin & Spiritual Heritage. Rare origins pass down to your children!",
	},
}
