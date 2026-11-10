-- Arcana (2.0): elemental affinities, the ranked spellbook, chantless mastery, Mana
-- Collapse, the Silent Casting Trial and the Spell Forge with the Family Grimoire
-- (Configs/ArcanaConfig, Modules/ArcanaSystem). The "Magic & Sword" tab.
return {
	Id = "Arcana",
	Name = "Magic & Sword",
	Description = "Affinities, spells, mana, the Spell Forge and the sword side of combat.",
	Optional = true,
	Requires = { "Skills" },
	EffectKeys = { "ManaBonus" },
	Tab = { Label = "Magic & Sword", Order = 27, Icon = "🔮" },
}
