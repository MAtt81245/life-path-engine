--[[
	LegendsConfig: the Legends tab (Modules/LegendsSystem).

	Thrones      the seven strongest beings in the world, ranked. Power = combat power
	             (Shared/CombatMath.Power); Hidden shows "???"; Vacant seats are claimed
	             by reaching ClaimPower. Encounter / Spar / Challenge (once a year, from
	             ChallengeAge). A won challenge claims the seat, its title and Buffs for the
	             life, and the seat stays yours in the World Chronicle after you die.
	             Names are content: rename them freely.
	FamilyWeapon forged at Crafting Skill level; passed to every heir (rebirth as Heir).
	             Tier = floor(Crafting / 20); reforging at a higher tier upgrades it.
	Relics       finding LeadsNeeded relic leads in one life unlocks the next missing relic
	             for every later life (its Buffs apply from birth). LeadSources: chances.
	Hall         the score of a finished life and its epitaph; Share posts the card to
	             the Community Hall feed (this server, and every server through
	             MessagingService when available).
]]

local LegendsConfig = {}

LegendsConfig.Header = "The Seven Seats of Legend" -- Legends page column title

LegendsConfig.ChallengeAge = 16
LegendsConfig.Thrones = {
	{ Seat = 1, Title = "Shadow of the Soul King", Holder = "The Unseen Hand", Power = 600000, Hidden = true, Buffs = { SkillXpMult = 1.3, MagicDamageMult = 1.2, SwordDamageMult = 1.2 } },
	{ Seat = 2, Title = "First Sword of the Gotei", Holder = "Genjuro Akatsuki", Power = 360000, Buffs = { DamageTakenMult = 0.8, SwordDamageMult = 1.2 } },
	{ Seat = 3, Title = "Sovereign of Hueco Mundo", Holder = "Dravos the Hollow King", Power = 192000, Buffs = { MaxHealthBonus = 150, SwordDamageMult = 1.15 } },
	{ Seat = 4, Title = "Throne of the Shattered Mask", Vacant = true, ClaimPower = 100000, Buffs = { MagicDamageMult = 1.2, DamageTakenMult = 0.9 } },
	{ Seat = 5, Title = "Envoy of Death", Holder = "Sereth the Pale", Power = 114000, Buffs = { SwordDamageMult = 1.15, DodgeChance = 0.05 } },
	{ Seat = 6, Title = "Sword Sage of the West", Holder = "Ryuga Tenjo", Power = 84000, Buffs = { SwordDamageMult = 1.2 } },
	{ Seat = 7, Title = "Frost Captain", Holder = "Hyoe Shirogane", Power = 66000, Buffs = { SwordDamageMult = 1.1, MaxHealthBonus = 50 } },
}
LegendsConfig.Spar = { SkillXp = 12, Health = -8 }
LegendsConfig.ChallengeLoss = { HealthShare = 0.5, Stress = 10 }

LegendsConfig.FamilyWeapon = { CraftingLevel = 20, Cost = 500, TierEvery = 20,
	PerTier = { SwordDamageMult = 0.08, MagicDamageMult = 0.05 } }

LegendsConfig.LeadsNeeded = 2
LegendsConfig.LeadSources = { Boss = 1, Battle = 0.06, SkillAction = 0.15, Encounter = 0.25, Raid = 0.5 }
LegendsConfig.Relics = {
	{ Id = "crown", Name = "Crown of the Nameless Soul King", Description = "Nobles bow to a name no one remembers.", Buffs = { SocialBonus = 0.1, GoldMult = 1.15 } },
	{ Id = "wyrm_heart", Name = "Heart of an Ancient Menos", Description = "It still beats, slowly, for its bearer.", Buffs = { MaxHealthBonus = 80, DamageTakenMult = 0.9 } },
	{ Id = "mirror", Name = "Mirror of Unmasking", Description = "No lie, no blade, no fate hides from it.", Buffs = { DodgeChance = 0.08, SkillXpMult = 1.1 } },
	-- Content expansion (2026-11-02): 3 more relics.
	{ Id = "jade_seal", Name = "Seal of the First Gotei", Description = "The first thirteen captains swore on it. It remembers.", Buffs = { SalaryMult = 1.2, KarmaMult = 1.15 } },
	{ Id = "phoenix_feather", Name = "Undying Phoenix Feather", Description = "Warm to the touch, even in winter.", Buffs = { LifespanBonus = 25, StressPerYear = -1 } },
	{ Id = "star_chart", Name = "Map of the Precipice World", Description = "Every path through the Dangai, drawn by someone who never came back.", Buffs = { QiMult = 1.2, BreakthroughBonus = 0.04 } },
}

LegendsConfig.HallSize = 5
LegendsConfig.CommunitySize = 30
LegendsConfig.Epitaphs = {
	"%s lived as they chose, and died as they lived.",
	"Here lies %s. The world was louder for a while.",
	"%s walked further than most dared to dream.",
	"Remember %s when the Hell Butterflies fly at dusk.",
	"%s owed the world nothing and gave it everything.",
	"The Gotei still argues about what %s did that day.",
	"%s laughed at fate, and fate, for once, laughed back.",
	"Somewhere a lantern still floats down the river for %s.",
	"%s was a storm that chose to be gentle.",
	"Ask the old captains about %s. Then bring tea; it is a long story.",
}

LegendsConfig.RelicsById = {}
for _, relic in LegendsConfig.Relics do LegendsConfig.RelicsById[relic.Id] = relic end

-- Score of a finished life (Hall of Lives).
function LegendsConfig.Score(entry): number
	return math.floor((entry.Age or 0) + (entry.RealmIndex or 1) * 25 + (entry.Fame or 0) / 10 + (entry.TopSkill or 0) * 2
		+ (entry.Karma or 0) * 3 + (if entry.Throne then 300 else 0))
end

return LegendsConfig
