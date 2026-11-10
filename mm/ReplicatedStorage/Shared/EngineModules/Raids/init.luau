-- Raids (3.0): parties of 1-5 players in this server against five difficulties
-- (Configs/RaidConfig, Modules/RaidSystem). The "Raids" tab.
return {
	Id = "Raids",
	Name = "Raids",
	Description = "Multiplayer raids with parties, tickets and a raid shop.",
	Optional = true,
	Requires = { "Skills" },
	Tab = { Label = "Raids", Order = 96, Icon = "⚔" },
}
