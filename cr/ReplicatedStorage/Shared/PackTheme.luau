--[[
	PackTheme: the game's look and vocabulary (Configs/UIThemeConfig), shared by the
	client UI (Shared/UIStyle, Shared/UITheme, IntroAndLoadingUI) and the server's
	messages (PlayerState.Term / PlayerState.Words).

	PackTheme.Get()         the theme table (Palette, Fonts, Corner, Pip, Terms)
	PackTheme.Term(key)     one word ("EnergyName" -> "Qi"); unknown keys return themselves
	                        (keys in DEFAULT_TERMS fall back to a genre-neutral default)
	PackTheme.Words(text)   fills {Key} tokens with terms ("+5 {MetaCurrency}" -> "+5 Karma");
	                        a lowercase first letter lowercases the word ("{raceName}" -> "bloodline")
	PackTheme.Font(role)    Enum.Font for Body / Bold / Heavy / Title (unknown names fall back)
]]

local Content = require(script.Parent:WaitForChild("Content"))

local PackTheme = {}

-- Engine message words a pack may leave out; packs override them in UIThemeConfig.Terms.
local DEFAULT_TERMS = {
	MentorName = "Mentor", StudentName = "Student", SectName = "Faction",
	PeakLine = "You stand at the peak.",
	ReviveLine = "You cheat death. You live on!",
	ReviveLog = "%s cheats death and draws breath again at age %d.",
	BirthLine = "A new story begins.",
	AscendRequirement = "Only at the peak, ninth level, can you ascend.",
	AscendLog = "%s ascends into legend. (Ascension #%d)",
	AscendDeath = "Ascended into legend.",
	AscendDone = "You have ascended!",
	AscendTitle = "Ascendant",
	LegacyBuffName = "Legacy",
	AscendOutro = "The Wheel turns once more. Your legend lives on.",
}

function PackTheme.Get()
	return Content.Get("UIThemeConfig")
end

local function lookup(terms, key: string): string?
	local value = terms[key]
	if type(value) ~= "string" then
		value = DEFAULT_TERMS[key]
	end
	return value
end

function PackTheme.Term(key: string): string
	return lookup(PackTheme.Get().Terms, key) or key
end

function PackTheme.Words(text: string): string
	local terms = PackTheme.Get().Terms
	return (string.gsub(text, "{(%w+)}", function(key)
		local exact = lookup(terms, key)
		if exact then
			return exact
		end
		local word = lookup(terms, string.upper(string.sub(key, 1, 1)) .. string.sub(key, 2))
		return if type(word) == "string" then string.lower(word) else nil
	end))
end

local DEFAULT_FONTS = { Body = Enum.Font.GothamMedium, Bold = Enum.Font.GothamBold, Heavy = Enum.Font.GothamBlack, Title = Enum.Font.Fondamento, Mono = Enum.Font.RobotoMono }

function PackTheme.Font(role: string): Enum.Font
	local name = PackTheme.Get().Fonts[role]
	local ok, font = pcall(function()
		return (Enum.Font :: any)[name]
	end)
	return if ok and font then font else DEFAULT_FONTS[role] or Enum.Font.GothamMedium
end

return PackTheme
