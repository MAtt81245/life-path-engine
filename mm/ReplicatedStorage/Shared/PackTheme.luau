--[[
	PackTheme: resolves the active pack's UIThemeConfig (look + vocabulary) with the
	base Configs.UIThemeConfig as the fallback for anything a pack leaves out.

	PackTheme.Get(packId?)       merged theme (nil = active pack, false = base)
	PackTheme.Term(key, packId?) one interface word ("EnergyName" -> "Qi" / "Focus" / "Mana");
	                             keys in DEFAULT_TERMS fall back to a genre-neutral default
	PackTheme.Words(text, packId?) fills {Key} tokens ("+5 {MetaCurrency}" -> "+5 Karma"); a
	                             lowercase first letter lowercases it ("{raceName}" -> "bloodline").
	                             Server messages use it through PlayerState.Words.
	PackTheme.Font(role, packId?) Enum.Font for Body / Bold / Heavy / Title (unknown names fall back)
]]

local Content = require(script.Parent:WaitForChild("Content"))

local PackTheme = {}

-- Engine message words a game may leave out; themes override them in UIThemeConfig.Terms.
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
	MapTitle = "The Known World",
	LegacyName = "Family Legacy",
	HeirloomName = "Heirloom",
	-- 2.0 magic, sword and battle vocabulary (Arcana page, battles, Legends).
	ManaName = "Mana", SpellbookName = "spellbook", SpellForgeName = "Spell Forge",
	SilentTrialName = "Silent Casting Trial", SilentMasteredName = "Silent Casting mastered",
	SwordAuraTitle = "Sword & Aura", BattlesName = "Battles", SpecialSchoolsName = "SPECIAL SCHOOLS",
	FamilyWeaponName = "Family Weapon", GrimoireName = "Family Grimoire",
}

local cache = {}

local function lookup(terms, key: string): string?
	local value = terms[key]
	if type(value) ~= "string" then
		value = DEFAULT_TERMS[key]
	end
	return value
end

local function merge(base, over)
	local out = table.clone(base)
	for key, value in over or {} do
		if type(value) == "table" and type(base[key]) == "table" then
			out[key] = merge(base[key], value)
		else
			out[key] = value
		end
	end
	return out
end

function PackTheme.Get(packId: (string | boolean)?)
	local cacheKey = if packId == nil then (Content.ActivePackId() or "") elseif packId == false then "" else packId
	if cache[cacheKey] then
		return cache[cacheKey]
	end
	local base = Content.Get("UIThemeConfig", false)
	local theme = if cacheKey == "" then merge(base, {}) else merge(base, Content.Get("UIThemeConfig", cacheKey))
	cache[cacheKey] = theme
	return theme
end

function PackTheme.Term(key: string, packId: (string | boolean)?): string
	return lookup(PackTheme.Get(packId).Terms, key) or key
end

function PackTheme.Words(text: string, packId: (string | boolean)?): string
	local terms = PackTheme.Get(packId).Terms
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

function PackTheme.Font(role: string, packId: (string | boolean)?): Enum.Font
	local name = PackTheme.Get(packId).Fonts[role]
	local ok, font = pcall(function()
		return (Enum.Font :: any)[name]
	end)
	return if ok and font then font else DEFAULT_FONTS[role] or Enum.Font.GothamMedium
end

return PackTheme
