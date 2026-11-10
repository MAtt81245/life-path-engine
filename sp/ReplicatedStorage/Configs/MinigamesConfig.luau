--[[
	MinigamesConfig: short games on the Today page (Modules/MinigameSystem,
	UIController/MinigameModal). Each once a year, free (no action).

	Motes  Catch the Light: Seconds of clicking fading motes (gold = Gold points).
	       Rewards scale with the score (capped at MaxScore): Max Mana bonus, Mana and
	       Luck XP, Magic skill XP; counts toward the Starlit Eyes hidden talent.
	Sneak  Sneak to the Study: hold to crawl while Mother hums; freeze when she turns.
	       Success / Fail effects (SkillSystem.ApplyEffects).
]]

return {
	Motes = {
		Name = "Catch the Reishi", Icon = "✨", MinAge = 3, Seconds = 15, MaxScore = 40, Gold = 2,
		Description = "Catch the drifting reishi motes before they fade.",
		ManaBonusPer = 12, MaxManaBonus = 3, ManaXpPer = 0.6, LuckXpPer = 0.3, MagicXpPer = 0.25,
	},
	Sneak = {
		Name = "Sneak to the Basement", Icon = "👣", MinAge = 4, MaxAge = 16,
		Description = "Crawl to the hidden basement while Mother hums. Freeze when she turns!",
		Success = { SkillXp = { Stealth = 12, Knowledge = 8 }, StatXp = { Intelligence = 10 }, Happiness = 4 },
		Fail = { Stress = 5, Happiness = -3 },
		CrawlSpeed = 0.12, -- progress per second while holding
	},
}
