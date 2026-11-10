--[[
	UIThemeConfig: the look and vocabulary of LifePathUI for this pack, read through
	Shared/PackTheme (Shared/UIStyle applies it to every page, Shared/UITheme to the
	static layout). A pack overrides it with its own UIThemeConfig, usually through
	Content.Extend so it only lists what changes:

		return Content.Extend("UIThemeConfig", script.Parent, function(theme)
			theme.Terms.EnergyName = "Mana"
		end)

	Palette   Color3 per UIStyle.C key (bg, panels, cards, accent "gold", energy "qi", ...)
	Fonts     Enum.Font names for Body / Bold / Heavy / Title
	Corner    multiplier for panel corner radii
	Pip       action pip shape: Shape (label), Rotation (degrees), Corner (UDim scale, 0.5 = round)
	Terms     every genre word the interface and server messages show; code never
	          hardcodes them (PackTheme.Term(key) / Words("{Key}"), "{key}" = lowercase;
	          a pack's missing terms fall back to these base terms)
]]

return {
	Id = "cultivation",
	Name = "Obsidian & Jade",

	-- Obsidian, smoked jade, burnished gold and parchment.
	Palette = {
		bg1 = Color3.fromRGB(11, 13, 18), bg2 = Color3.fromRGB(5, 6, 9),
		ink = Color3.fromRGB(4, 5, 8),
		panel1 = Color3.fromRGB(20, 30, 28), panel2 = Color3.fromRGB(10, 15, 14),
		card1 = Color3.fromRGB(30, 35, 45), card2 = Color3.fromRGB(17, 20, 27),
		inset = Color3.fromRGB(7, 9, 12),
		stroke = Color3.fromRGB(200, 164, 93),
		gold = Color3.fromRGB(214, 178, 104), gold2 = Color3.fromRGB(142, 108, 52),
		qi1 = Color3.fromRGB(88, 214, 182), qi2 = Color3.fromRGB(46, 139, 120),
		jade1 = Color3.fromRGB(64, 170, 146), jade2 = Color3.fromRGB(28, 90, 78),
		rose1 = Color3.fromRGB(206, 76, 66), rose2 = Color3.fromRGB(110, 28, 30),
		crimson1 = Color3.fromRGB(168, 36, 40), crimson2 = Color3.fromRGB(78, 12, 18),
		text = Color3.fromRGB(238, 231, 214), muted = Color3.fromRGB(158, 150, 132),
		dark = Color3.fromRGB(26, 18, 6),
		green = Color3.fromRGB(118, 208, 150), red = Color3.fromRGB(226, 104, 92),
		violet = Color3.fromRGB(176, 140, 236),
	},

	Fonts = { Body = "GothamMedium", Bold = "GothamBold", Heavy = "GothamBlack", Title = "Fondamento" },

	Corner = 1,

	Pip = { Shape = "Diamond", Rotation = 45, Corner = 0.08 },

	-- 3D backdrop (StarterPlayerScripts/VoidScene): a dark void with a glowing branching
	-- spirit tree, a magic-circle floor and the player's black silhouette in front.
	-- Colors default to the palette (Glow = gold, Bloom = qi); Enabled = false keeps the
	-- flat 2D backdrop. PanelTransparency is the HUD glass (Main / Sheet).
	Scene = {
		Enabled = true,
		Seed = 1016, -- same tree for everyone
		Depth = 6, -- branch generations
		PanelTransparency = 0.12,
		BackdropTransparency = 0.6, -- the 2D gradient left over the 3D scene
		BreathSeconds = 5,
	},

	Terms = {
		Genre = "cultivation",
		-- Loading screen and engine messages (packs override these; see PackTheme DEFAULT_TERMS).
		LoadingEmblem = "☯",
		LoadingTitle = "LIFE PATH",
		LoadingSubtitle = "Chasing Immortality",
		LoadingStage1 = "The Wheel of Reincarnation turns...",
		LoadingStage2 = "Gathering the threads of fate...",
		LoadingStage3 = "Awakening your soul...",
		LoadingStage4 = "Painting the heavens...",
		LoadingStage5 = "Your path is ready.",
		LoadingDone = "Your soul descends...",
		MentorName = "Master",
		StudentName = "Disciple",
		SectName = "Sect",
		PeakLine = "You stand at the peak of the Dao.",
		ReviveLine = "Heaven's verdict is defied. You live on!",
		ReviveLog = "%s defies Heaven's verdict and draws breath again at age %d.",
		BirthLine = "The road to immortality is long.",
		AscendRequirement = "Only a True Immortal at the ninth level can ascend.",
		AscendLog = "%s ascends beyond the mortal plane. The heavens open. (Ascension #%d)",
		AscendDeath = "Ascended beyond the mortal plane.",
		AscendDone = "You have ascended!",
		AscendTitle = "Heavenly Ascendant",
		LegacyBuffName = "Divine Legacy",
		AscendOutro = "The Wheel turns once more. Your legend will outlive the heavens.",
		MapTitle = "The Known World",
		LadderTitle = "Blood Ladder", -- birth screen odds column
		TalentName = "Innate Talent", -- third birth card
		LegacyName = "Family Legacy",
		HeirloomName = "Heirloom",
		EnergyName = "Qi", -- the resource the progress bar fills
		EnergyHeader = "QI",
		TierHeader = "CULTIVATION REALM",
		TierName = "Realm",
		TierDormant = "Spirit Root dormant",
		AdvanceTierButton = "BREAKTHROUGH",
		AdvanceTierName = "Breakthrough", -- the act of advancing, in sentences
		AscendButton = "ASCEND",
		AscendHint = "Beyond the mortal plane",
		MentorsTab = "Masters",
		RebirthTab = "Samsara",
		RebirthWheel = "Wheel of Reincarnation",
		MetaCurrency = "Karma",
		MetaCurrencyIcon = "☯",
		RaceName = "Bloodline",
		RaceNamePlural = "Bloodlines",
		Incarnation = "INCARNATION",
		ActionPip = "◆",
		ActionsHeader = "ACTIONS THIS YEAR",
		ActionsName = "Action Diamonds",
		DeceasedHint = "Turn the Wheel in Samsara",
		ShopName = "Immortal Treasury",
		ShopButton = "❖ Treasury", -- glyphs must exist in the UI fonts (✦ ✧ ⬢ do not)
		ShopTagline = "Treasures gathered from the nine heavens",
		ReviveTitle = "Heaven's Verdict",
		ReviveButton = "Defy Heaven's Verdict",
		ReviveHint = "Revive at 50% HP & keep your current life",
		AcceptFate = "Accept fate",
		SpiritRootTutorial = "Your Spirit Root has awakened! Cultivate Qi and Breakthrough realms to extend your lifespan.",
		CreationTutorial = "Spin for your starting Bloodline & Family Legacy. Rare bloodlines pass down to your children!",
	},
}
