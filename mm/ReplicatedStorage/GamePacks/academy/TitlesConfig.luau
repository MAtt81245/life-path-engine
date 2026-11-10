-- Academy: titles earned through rivals and tournaments.
local Content = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Content"))

return Content.Extend("TitlesConfig", script.Parent, function(titles)
	titles.List = {
		{ Id = "hothead", Name = "Hothead", Description = "+15% Power XP.",
			Requires = { Counters = { Fights = 3 } }, Buffs = { StatXp = { Power = 1.15 } } },
		{ Id = "tournament_champion", Name = "Sports Festival Champion", Description = "+20% all attribute XP.",
			Requires = { Counters = { TournamentWins = 1 } }, Buffs = { AllStatXp = 1.2 } },
		{ Id = "class_rep", Name = "Class Representative", Description = "+20% affection gains.",
			Requires = { Friends = { Count = 3, Affection = 60 } }, Buffs = { RelationshipMult = 1.2 } },
		{ Id = "rising_star", Name = "Rising Star", Description = "+25% fame gains.",
			Requires = { MinFame = 40 }, Buffs = { FameMult = 1.25 } },
		{ Id = "pro_hero", Name = "Pro Hero", Description = "+10 happiness per year.",
			Requires = { Flag = "ProHero" }, Buffs = { HappinessPerYear = 10 } },
	}
	titles.ById = {}
	for _, title in titles.List do
		titles.ById[title.Id] = title
	end
end)
