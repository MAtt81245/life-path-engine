-- Academy: one human lineage (Lineages is off), with the academy stat set.
local Content = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Content"))

return Content.Extend("RacesConfig", script.Parent, function(races)
	races.Default = "Human"
	races.List = {
		{
			Id = "Human", Name = "Human", Rarity = "Common", Color = Color3.fromRGB(220, 210, 190),
			Description = "An ordinary kid with an extraordinary dream.",
			Passive = "Determined: +10% Spirit XP.",
			BaseStats = { Power = 1, Technique = 1, Speed = 1, Spirit = 2, Intellect = 2, Charm = 1 },
			Buffs = { StatXp = { Spirit = 1.1 } },
		},
	}
	races.ById = { Human = races.List[1] }
end)
