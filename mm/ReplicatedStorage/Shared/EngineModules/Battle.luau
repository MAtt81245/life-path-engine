-- Battle (2.0): turn-based fights against regional enemies with the VS banner, Guard,
-- Flee, a once-per-battle signature move and key-chant spell casting
-- (Configs/BattleConfig, Modules/BattleSystem, UIController/BattleModal).
return {
	Id = "Battle",
	Name = "Battle",
	Description = "Turn-based battles where sword and magic damage stay separate.",
	Optional = true,
	Requires = { "Skills" },
}
