--[[
	GeneticsText: readable genetics for relationship cards and the family tree, and the
	romance gate shared by the client (button state) and RelationshipSystem (rules).
]]

local Content = require(script.Parent:WaitForChild("Content"))
local PackTheme = require(script.Parent:WaitForChild("PackTheme"))

local Genetics = Content.Get("GeneticsConfig")
local Races = Content.Get("RacesConfig")
local Talents = Content.Get("TalentsConfig")

local GeneticsText = {}

local function grade(g)
	return Genetics.Grades[Genetics.GradeIndex[g.Grade or ""] or 1]
end
GeneticsText.Grade = grade

-- "Rare root" in the cultivation game, "Standard Flow" when GradeSuffix is empty.
local function gradeShort(gr): string
	local suffix = PackTheme.Get().Terms.GradeSuffix
	suffix = if suffix == nil then "root" else suffix
	return if suffix ~= "" then gr.Name .. " " .. suffix else gr.Name
end

-- The rarity name players see ("Epic" key -> its display Name).
local function rarityName(key: string?): string
	local info = key and Races.Spin and Races.Spin.Rarities[key]
	return if info then info.Name else tostring(key or "")
end

-- "Rare root · Beastkin · Sword Heart"
function GeneticsText.Short(g, _config): string
	if not g then
		return ""
	end
	local parts = { gradeShort(grade(g)) }
	local race = g.Race and Races.ById[g.Race]
	if race then
		table.insert(parts, race.Name)
	end
	local trait = g.Trait and Genetics.TraitsById[g.Trait]
	if trait then
		table.insert(parts, trait.Name)
	end
	return table.concat(parts, "  ·  ")
end

-- Rich-text lines for detail panels.
function GeneticsText.Lines(g, _config): { string }
	local lines = {}
	if not g then
		return lines
	end
	local gr = grade(g)
	local terms = PackTheme.Get().Terms
	table.insert(lines, ('<b>%s:</b> <font color="#%s">%s</font>'):format(terms.GradeLabel or "Spirit root", gr.Color:ToHex(), gr.Name))
	local race = g.Race and Races.ById[g.Race]
	if race then
		table.insert(lines, ("<b>%s:</b> %s (%s)%s"):format(terms.RaceName or "Bloodline", race.Name, rarityName(race.Rarity), if g.Mutated then "  ↑ awakened" else ""))
	end
	local names = {}
	for _, id in g.Talents or {} do
		local talent = Talents.Get(id)
		if talent then
			table.insert(names, talent.Name)
		end
	end
	if #names > 0 then
		table.insert(lines, "<b>Talents (from you):</b> " .. table.concat(names, ", "))
	end
	local trait = g.Trait and Genetics.TraitsById[g.Trait]
	if trait then
		table.insert(lines, ("<b>Hereditary:</b> %s (%s)"):format(trait.Name, trait.Description))
	end
	if g.Upbringing then
		table.insert(lines, "<b>Upbringing:</b> " .. g.Upbringing)
	end
	return lines
end

-- Why you cannot court this person yet (nil = you may try). view = state or snapshot.
function GeneticsText.RomanceBlock(view, rel): string?
	local g = rel.Genetics
	if not g then
		return nil
	end
	local gr = grade(g)
	local stats = view.Stats or {}
	local charisma = (stats.Charisma and stats.Charisma.Level) or 0
	if charisma < gr.RomanceCharisma then
		return ("A %s suitor wants Charisma %d."):format(gradeShort(gr), gr.RomanceCharisma)
	elseif (view.RealmIndex or 1) < gr.RomanceRealm then
		return PackTheme.Words(("A %s suitor ignores anyone below {tierName} %d."):format(gradeShort(gr), gr.RomanceRealm))
	end
	return nil
end

return GeneticsText
