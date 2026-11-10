-- Academy: duels use Power, romance and peace-making use Charm.
local Content = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Content"))

local STATS = { Romance = "Charm", Challenge = "Power", Wager = "Power", BloodFeud = "Power", Reconcile = "Charm" }

return Content.Extend("RelationshipsConfig", script.Parent, function(rel)
	for _, interaction in rel.Interactions do
		interaction.ChanceStat = STATS[interaction.Id] or interaction.ChanceStat
	end
	rel.FirstNames = { "Izumi", "Katsu", "Ochaco", "Shoji", "Momo", "Tenya", "Eiji", "Kyoka", "Rin", "Haru", "Sora", "Yuki" }
	rel.Surnames = { "Midori", "Bakugo", "Uraraka", "Iida", "Yaoyo", "Kirishi", "Jiro", "Todo", "Aizawa", "Tokoya" }
end)
