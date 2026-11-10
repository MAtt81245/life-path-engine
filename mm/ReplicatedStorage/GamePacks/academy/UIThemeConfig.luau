-- Hero Academy look: dark crimson and charcoal, arcane violet and silver accents,
-- slanted crest pips, academy vocabulary.
local Content = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Content"))

return Content.Extend("UIThemeConfig", script.Parent, function(theme)
	theme.Id = "academy"
	theme.Name = "Crimson & Arcane"
	local p = theme.Palette
	p.bg1, p.bg2 = Color3.fromRGB(24, 14, 18), Color3.fromRGB(12, 7, 10)
	p.ink = Color3.fromRGB(8, 4, 6)
	p.panel1, p.panel2 = Color3.fromRGB(44, 22, 28), Color3.fromRGB(26, 13, 17)
	p.card1, p.card2 = Color3.fromRGB(46, 40, 48), Color3.fromRGB(28, 24, 30)
	p.inset = Color3.fromRGB(12, 8, 11)
	p.stroke = Color3.fromRGB(190, 192, 206)
	p.gold, p.gold2 = Color3.fromRGB(206, 208, 222), Color3.fromRGB(120, 122, 140) -- accent: silver
	p.qi1, p.qi2 = Color3.fromRGB(170, 120, 250), Color3.fromRGB(96, 56, 170) -- arcane violet
	p.jade1, p.jade2 = Color3.fromRGB(150, 110, 230), Color3.fromRGB(80, 50, 140)
	p.crimson1, p.crimson2 = Color3.fromRGB(176, 30, 48), Color3.fromRGB(86, 10, 22)
	p.text, p.muted = Color3.fromRGB(240, 234, 240), Color3.fromRGB(164, 150, 162)
	p.dark = Color3.fromRGB(22, 14, 24)
	p.violet = Color3.fromRGB(196, 150, 255)
	theme.Fonts = { Body = "GothamMedium", Bold = "GothamBold", Heavy = "GothamBlack", Title = "Bodoni" }
	theme.Corner = 0.6
	theme.Pip = { Shape = "Crest", Rotation = 15, Corner = 0.22 }
	local t = theme.Terms
	t.Genre = "academy"
	-- Loading screen and engine messages: never inherit the cultivation wording.
	t.LoadingEmblem, t.LoadingTitle, t.LoadingSubtitle = "⚜", "LIFE PATH", "Academy Days"
	t.LoadingStage1, t.LoadingStage2, t.LoadingStage3 = "Opening the academy gates...", "Waking your power...", "Assigning your class..."
	t.LoadingStage4, t.LoadingStage5, t.LoadingDone = "Drawing the campus...", "Ready.", "First day of school..."
	t.MentorName, t.StudentName, t.SectName = "Mentor", "Student", "Club"
	t.PeakLine, t.BirthLine = "You are the academy's legend.", "Your story starts today."
	t.ReviveLine, t.ReviveLog = "Your power flares and you survive. You live on!", "%s survives against all odds at age %d."
	t.AscendRequirement, t.AscendLog = "Only the top rank at the ninth level can graduate as a legend.", "%s graduates as a legend. (Graduation #%d)"
	t.AscendDeath, t.AscendDone, t.AscendTitle = "Graduated as a legend.", "You graduated as a legend!", "Academy Legend"
	t.LegacyBuffName, t.AscendOutro, t.MapTitle = "Alumni Legacy", "The Wheel turns once more. Your legend lives on.", "The Campus"
	t.LadderTitle, t.TalentName = "Lineage Ladder", "Natural Gift"
	t.EnergyName, t.EnergyHeader = "Mana", "MANA"
	t.TierHeader, t.TierName, t.TierDormant = "RANK", "Rank", "Quirk dormant"
	t.AdvanceTierButton, t.AscendButton, t.AscendHint = "AWAKEN", "GRADUATE", "Become a legend"
	t.AdvanceTierName = "Awakening"
	t.MentorsTab, t.RebirthTab, t.RebirthWheel = "Mentors", "Legacy", "Wheel of Destiny"
	t.MetaCurrency, t.MetaCurrencyIcon = "Renown", "⚜"
	t.RaceName, t.RaceNamePlural = "Lineage", "Lineages"
	t.Incarnation = "GENERATION"
	t.ActionPip, t.ActionsHeader, t.ActionsName = "❖", "ACTIONS THIS TERM", "Action Crests"
	t.DeceasedHint = "Open Legacy to enroll again"
	t.ShopName, t.ShopButton, t.ShopTagline = "Academy Vault", "⚜ Vault", "Relics of legendary heroes"
	t.ReviveTitle, t.ReviveButton, t.ReviveHint = "Final Stand", "Plus Ultra Revival", "Rise at 50% HP & keep this life"
	t.AcceptFate = "Stay down"
	t.CreationTutorial = "Spin for your starting Lineage & Family Legacy. Rare lineages pass down to your children!"
end)
