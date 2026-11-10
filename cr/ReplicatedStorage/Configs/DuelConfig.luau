--[[
	Tactical Clash duels (Modules/DuelSystem, UIController/DuelModal): best of 3 exchanges.
	Each exchange both fighters pick a stance; the stance that Beats the other gets
	AdvantageMult. Stance power = sum(stat level x weight) + the extras below, times a
	random spread. First to WinsNeeded exchanges wins; each lost exchange costs HitDamage
	of the duel HP bar. Used by blood feuds, wagers, sect promotion trials and heirloom
	reclamation fights. "Quick Resolve" picks your strongest stance every exchange.
	Short (optional) is the compact stance name for the "Beats ..." line and the round log.
]]

local DuelConfig = {}

DuelConfig.WinsNeeded = 2
DuelConfig.AdvantageMult = 1.35
DuelConfig.Spread = 0.15
DuelConfig.HitDamage = 34

DuelConfig.StanceOrder = { "Strike", "Channel", "Guard" }
DuelConfig.Stances = {
	Strike = { Name = "Black Flash Blitz", Short = "Black Flash", Icon = "⚡", Beats = "Channel", Hint = "Crushes Technique Release, loses to Simple Domain. Cursed tool, Strength and Agility",
		Stats = { Strength = 1, Agility = 0.7 }, ProficiencyWeight = 0.6, WeaponBonus = 6 },
	Channel = { Name = "Technique Release / Domain Amp", Short = "Technique Release", Icon = "👁", Beats = "Guard", Hint = "Overwhelms Simple Domain, disrupted by Black Flash. CE Manipulation, techniques and Intelligence",
		Stats = { QiControl = 1, Intelligence = 0.6 }, RealmWeight = 6, TechniqueBonus = 6 },
	Guard = { Name = "Simple Domain / Falling Blossom", Short = "Simple Domain", Icon = "🛡", Beats = "Strike", Hint = "Parries Black Flash, pierced by Technique Release. Vitality, uniform and charms",
		Stats = { Vitality = 1.4, Strength = 0.3 }, ArmorBonus = 5 },
}

-- Opponent strength as a multiple of your average stance power.
DuelConfig.Difficulty = {
	BloodFeud = 1.0, -- + rival spirit-root grade x GradeStep
	Wager = 0.95,
	Trial = 0.85, -- + next rank index x RankStep
	Heirloom = 0.95,
}
DuelConfig.GradeStep = 0.06
DuelConfig.RankStep = 0.07

return DuelConfig
