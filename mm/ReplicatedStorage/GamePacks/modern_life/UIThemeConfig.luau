-- Modern Life look: sleek slate and midnight blue, crisp cyan and emerald accents,
-- clean rounded badges, everyday vocabulary.
local Content = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Content"))

return Content.Extend("UIThemeConfig", script.Parent, function(theme)
	theme.Id = "modern"
	theme.Name = "Slate & Cyan"
	local p = theme.Palette
	p.bg1, p.bg2 = Color3.fromRGB(16, 22, 36), Color3.fromRGB(9, 13, 23)
	p.ink = Color3.fromRGB(6, 9, 16)
	p.panel1, p.panel2 = Color3.fromRGB(26, 36, 56), Color3.fromRGB(16, 23, 38)
	p.card1, p.card2 = Color3.fromRGB(36, 48, 70), Color3.fromRGB(22, 30, 46)
	p.inset = Color3.fromRGB(10, 14, 24)
	p.stroke = Color3.fromRGB(86, 196, 232)
	p.gold, p.gold2 = Color3.fromRGB(72, 204, 236), Color3.fromRGB(30, 120, 160) -- accent: cyan
	p.qi1, p.qi2 = Color3.fromRGB(70, 214, 140), Color3.fromRGB(30, 140, 90) -- emerald
	p.jade1, p.jade2 = Color3.fromRGB(70, 190, 150), Color3.fromRGB(30, 100, 80)
	p.crimson1, p.crimson2 = Color3.fromRGB(60, 110, 220), Color3.fromRGB(28, 50, 120)
	p.text, p.muted = Color3.fromRGB(232, 240, 250), Color3.fromRGB(140, 156, 180)
	p.dark = Color3.fromRGB(8, 22, 34)
	theme.Fonts = { Body = "GothamMedium", Bold = "GothamBold", Heavy = "GothamBlack", Title = "Montserrat" }
	theme.Corner = 1.4
	theme.Pip = { Shape = "Badge", Rotation = 0, Corner = 0.5 }
	local t = theme.Terms
	t.Genre = "modern"
	-- Loading screen and engine messages: never inherit the cultivation wording.
	t.LoadingEmblem, t.LoadingTitle, t.LoadingSubtitle = "●", "LIFE PATH", "A Modern Life"
	t.LoadingStage1, t.LoadingStage2, t.LoadingStage3 = "Loading your life...", "Gathering memories...", "Setting the table..."
	t.LoadingStage4, t.LoadingStage5, t.LoadingDone = "Painting the city...", "Ready.", "Here we go..."
	t.MentorName, t.StudentName, t.SectName = "Mentor", "Mentee", "Organization"
	t.PeakLine, t.BirthLine = "You are at the top of your field.", "A whole life lies ahead."
	t.ReviveLine, t.ReviveLog = "Against all odds, you pull through. You live on!", "%s pulls through against all odds at age %d."
	t.AscendRequirement, t.AscendLog = "Only someone at the very top can retire in glory.", "%s retires in glory. (Legacy #%d)"
	t.AscendDeath, t.AscendDone, t.AscendTitle = "Retired in glory.", "You retired in glory!", "Living Legend"
	t.LegacyBuffName, t.AscendOutro, t.MapTitle = "Family Legacy", "The Wheel turns once more. Your name lives on.", "The City"
	t.LadderTitle, t.TalentName = "Odds Ladder", "Natural Gift"
	t.EnergyName, t.EnergyHeader = "Focus", "FOCUS"
	t.TierHeader, t.TierName, t.TierDormant = "CAREER TIER", "Tier", "Career not started"
	t.AdvanceTierButton, t.AscendButton, t.AscendHint = "PROMOTE", "RETIRE", "A life well lived"
	t.AdvanceTierName = "Promotion"
	t.MentorsTab, t.RebirthTab, t.RebirthWheel = "Mentors", "Legacy", "Wheel of Fate"
	t.MetaCurrency, t.MetaCurrencyIcon = "Legacy Points", "★"
	t.RaceName, t.RaceNamePlural = "Background", "Backgrounds"
	t.Incarnation = "GENERATION"
	t.ActionPip, t.ActionsHeader, t.ActionsName = "●", "ACTIONS THIS YEAR", "Action Badges"
	t.DeceasedHint = "Open Legacy to start a new life"
	t.ShopName, t.ShopButton, t.ShopTagline = "Premium Store", "★ Store", "Boosts for a better life"
	t.ReviveTitle, t.ReviveButton, t.ReviveHint = "Last Chance", "Second Chance", "Recover at 50% health & keep this life"
	t.AcceptFate = "Let it end"
	t.CreationTutorial = "Spin for your starting Background & Family Legacy. Rare backgrounds pass down to your children!"
end)
