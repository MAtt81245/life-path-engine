--[[
	RaidConfig: multiplayer raids in this server (Modules/RaidSystem, Raids tab).

	Difficulties  MinLevel = adventurer level (CombatMath.Level of combat power);
	              BossPower vs the party's summed power (+PartyBonus per extra member)
	              sets the odds; Rewards go to every member (Money, Tokens).
	              Conquer = the first clear is written into the World Chronicle.
	Parties       1-MaxParty players; Quick Join fills the first open party of a
	              difficulty or opens a new one.
	Tickets       one per raid per member; +TicketsPerDay each real day, up to MaxTickets.
	Shop          Raid Tokens buy items, tickets or the meta currency.
]]

return {
	MaxParty = 5, PartyBonus = 0.1, MinAge = 14,
	Difficulties = {
		{ Id = "Normal", Name = "Normal", MinLevel = 5, BossPower = 4000, Rewards = { Money = 300, Tokens = 5 }, Boss = "Alpha of the Hollow Pack" },
		{ Id = "Hard", Name = "Hard", MinLevel = 15, BossPower = 30000, Rewards = { Money = 900, Tokens = 12 }, Boss = "The Drowned Hollow of District 80" },
		{ Id = "Expert", Name = "Expert", MinLevel = 30, BossPower = 110000, Rewards = { Money = 2500, Tokens = 25 }, Boss = "Arrancar Fraccion Captain" },
		{ Id = "Nightmare", Name = "Nightmare", MinLevel = 50, BossPower = 300000, Rewards = { Money = 6000, Tokens = 50 }, Boss = "Ashen Gillian Colossus" },
		{ Id = "Calamity", Name = "Calamity", MinLevel = 75, BossPower = 700000, Rewards = { Money = 15000, Tokens = 120 }, Boss = "The Calamity Beneath Hueco Mundo", Conquer = true },
	},
	MaxTickets = 3, TicketsPerDay = 1, StartTickets = 3,
	Failure = { HealthShare = 0.3, Stress = 8 },
	Shop = {
		{ Name = "Raid Ticket", Cost = 30, Ticket = 1 },
		{ Name = "Reiryoku Crystal", Cost = 20, Item = "magic_crystal" },
		{ Name = "Hollow Hunter's Token", Cost = 25, Item = "hunters_token" },
		{ Name = "Gotei Patrol Badge", Cost = 40, Item = "guardsmans_badge" },
		{ Name = "Offering (+25 Hogyoku Shards)", Cost = 60, Karma = 25 },
		{ Name = "Hollow Core", Cost = 15, Item = "beast_core" },
		{ Name = "Lightning Kido Talisman", Cost = 55, Item = "thunder_talisman" },
		{ Name = "Ancestral Gauntlet", Cost = 45, Item = "ancestral_bracer" },
		{ Name = "Reiokyu Dew", Cost = 35, Item = "jade_dew" },
		{ Name = "Grand Offering (+60 Hogyoku Shards)", Cost = 130, Karma = 60 },
	},
}
