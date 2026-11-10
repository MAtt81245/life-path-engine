--[[
	LineageMemory: how well a past life is remembered on the family tree ("the Mist of
	Time"). Shared by the Lineage tab (client) and the tests; tuning in FamilyTreeConfig.

	LineageMemory.Keep(upgrades) -> extra generations kept clear/fading
	LineageMemory.Tier(entry, generationsAgo, upgrades) -> "Clear" | "Fading" | "Forgotten", preservedBy?
	LineageMemory.Describe(entry, generationsAgo, upgrades, regions?) -> display fields
]]

local Content = require(script.Parent:WaitForChild("Content"))

local Tree = Content.Get("FamilyTreeConfig")
local Upgrades = Content.Get("SamsaraUpgradesConfig")

local LineageMemory = {}

local LOST = "Lost to time..."
LineageMemory.Lost = LOST

function LineageMemory.Keep(upgrades): number
	local keep = 0
	for _, upgrade in Upgrades.List do
		local rank = (upgrades and upgrades[upgrade.Id]) or 0
		if upgrade.Effect == "MemoryKeep" then
			keep += rank * (upgrade.PerRank or 0)
		end
		keep += rank * (upgrade.MemoryPerRank or 0)
	end
	return math.floor(keep)
end

-- Lives between that ancestor and the current one (1 = the previous life).
function LineageMemory.GenerationsAgo(entry, currentLife: number): number
	return math.max(1, currentLife - (entry.Life or currentLife - 1))
end

function LineageMemory.Tier(entry, generationsAgo: number, upgrades): (string, string?)
	local keep = LineageMemory.Keep(upgrades)
	if generationsAgo <= Tree.ClearGenerations + keep then
		return "Clear", nil
	elseif generationsAgo <= Tree.FadingGenerations + keep then
		return "Fading", nil
	elseif (entry.RealmIndex or 0) >= Tree.ImmortalRealm then
		return "Clear", "Immortal"
	elseif entry.Heirloom then
		return "Clear", "Heirloom"
	end
	return "Forgotten", nil
end

-- Display fields for a tree node / detail panel at its memory tier.
function LineageMemory.Describe(entry, generationsAgo: number, upgrades, regions)
	local tier, preserved = LineageMemory.Tier(entry, generationsAgo, upgrades)
	local regionName = entry.RegionName
	if not regionName and regions and entry.Region then
		local region = regions.ById[entry.Region]
		regionName = region and region.Name
	end
	regionName = regionName or "a forgotten land"
	local out = {
		Tier = tier, Preserved = preserved, GenerationsAgo = generationsAgo,
		Name = entry.Name, Region = regionName,
		Realm = ("%s %d/9"):format(entry.Realm or "Mortal", entry.SubLevel or 1),
		Age = tostring(entry.Age or "?"), Cause = entry.Cause or LOST, Occupation = entry.Occupation or "Commoner",
		Rival = entry.Rival or "None remembered", Heirloom = entry.Heirloom,
		Biography = entry.Biography or "",
		Dim = 0,
	}
	if preserved == "Immortal" then
		out.Title = "Immortal Ancestor"
		out.Biography = ("The myth of %s, who reached %s, is still told in %s."):format(entry.Name, entry.Realm or "the heavens", regionName)
		out.Cause, out.Occupation, out.Rival = "Ascended into legend", "Immortal", "Their enemies are long forgotten"
	elseif preserved == "Heirloom" then
		out.Title = "Inscribed Ancestor"
		out.Biography = ("The inscription on %s still names %s and their deeds in %s."):format(entry.Heirloom, entry.Name, regionName)
		out.Cause, out.Rival = LOST, LOST
	elseif tier == "Fading" then
		out.Title = "Oral History"
		out.Age = "?"
		out.Cause = "Rumored: " .. string.lower(string.sub(entry.Cause or "they simply vanished", 1, 40))
		out.Occupation, out.Rival = LOST, LOST
		out.Biography = ("Grandparents still tell stories of %s from %s, though the details change each time."):format(entry.Name, regionName)
		out.Dim = 0.35
	elseif tier == "Forgotten" then
		out.Title = "Forgotten"
		out.Name = "An Unknown Ancestor of " .. regionName
		out.Realm, out.Age, out.Cause, out.Occupation, out.Rival = "?", "?", LOST, LOST, LOST
		out.Biography = "Only a weathered stone remains. The rain has erased the name."
		out.Dim = 0.7
	else
		out.Title = if generationsAgo == 1 then "Previous Life" else "Remembered"
	end
	return out
end

return LineageMemory
