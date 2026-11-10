-- Modern Life: drops titles that need cultivation or masters, adds a modern one.
local Content = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Content"))

local REMOVED = { initiate = true, chosen_one = true, sect_elder = true, demon_path = true, pure_qi_immortal = true }

return Content.Extend("TitlesConfig", script.Parent, function(titles)
	local list = {}
	for _, title in titles.List do
		if not REMOVED[title.Id] then
			table.insert(list, title)
		end
	end
	table.insert(list, {
		Id = "tech_founder", Name = "Tech Founder", Description = "+20% salary, +10% Focus XP.",
		Requires = { Employed = true, Stats = { Intelligence = 40, QiControl = 25 } },
		Buffs = { SalaryMult = 1.2, StatXp = { QiControl = 1.1 } },
	})

	titles.List = list
	titles.ById = {}
	for _, title in list do
		titles.ById[title.Id] = title
	end
end)
