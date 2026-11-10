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

LegendsConfig.ChallengeAge = 16
LegendsConfig.Thrones = {
	{ Seat = 1, Title = "Weaver God", Holder = "The Unseen Hand", Power = 600000, Hidden = true, Buffs = { SkillXpMult = 1.3, MagicDamageMult = 1.2, SwordDamageMult = 1.2 } },
	{ Seat = 2, Title = "Dragon God", Holder = "Vaelor of the Scale", Power = 360000, Buffs = { DamageTakenMult = 0.8, SwordDamageMult = 1.2 } },
	{ Seat = 3, Title = "War God", Holder = "Brannoc the Unbroken", Power = 192000, Buffs = { MaxHealthBonus = 150, SwordDamageMult = 1.15 } },
	{ Seat = 4, Title = "Demon God", Vacant = true, ClaimPower = 100000, Buffs = { MagicDamageMult = 1.2, DamageTakenMult = 0.9 } },
	{ Seat = 5, Title = "Reaper God", Holder = "Sereth the Pale", Power = 114000, Buffs = { SwordDamageMult = 1.15, DodgeChance = 0.05 } },
	{ Seat = 6, Title = "Sword God", Holder = "Aldric Vane", Power = 84000, Buffs = { SwordDamageMult = 1.2 } },
	{ Seat = 7, Title = "Frost God", Holder = "Hroth of the Frozen Pass", Power = 66000, Buffs = { SwordDamageMult = 1.1, MaxHealthBonus = 50 } },
}
LegendsConfig.Spar = { SkillXp = 12, Health = -8 }
LegendsConfig.ChallengeLoss = { HealthShare = 0.5, Stress = 10 }

LegendsConfig.FamilyWeapon = { CraftingLevel = 20, Cost = 500, TierEvery = 20,
	PerTier = { SwordDamageMult = 0.08, MagicDamageMult = 0.05 } }

LegendsConfig.LeadsNeeded = 2
LegendsConfig.LeadSources = { Boss = 1, Battle = 0.06, SkillAction = 0.15, Encounter = 0.25, Raid = 0.5 }
LegendsConfig.Relics = {
	{ Id = "crown", Name = "Crown of the Nameless King", Description = "Kings bow to a name no one remembers.", Buffs = { SocialBonus = 0.1, GoldMult = 1.15 } },
	{ Id = "wyrm_heart", Name = "Heart of the Old Wyrm", Description = "It still beats, slowly, for its bearer.", Buffs = { MaxHealthBonus = 80, DamageTakenMult = 0.9 } },
	{ Id = "mirror", Name = "Mirror of Unmasking", Description = "No lie, no blade, no fate hides from it.", Buffs = { DodgeChance = 0.08, SkillXpMult = 1.1 } },
	-- Content expansion (2026-11-02): 3 more relics.
	{ Id = "jade_seal", Name = "Jade Seal of the First Dynasty", Description = "The empire was founded with it. It remembers.", Buffs = { SalaryMult = 1.2, KarmaMult = 1.15 } },
	{ Id = "phoenix_feather", Name = "Undying Phoenix Feather", Description = "Warm to the touch, even in winter.", Buffs = { LifespanBonus = 25, StressPerYear = -1 } },
	{ Id = "star_chart", Name = "Chart of Fallen Stars", Description = "Every star on it fell somewhere. Some are still waiting.", Buffs = { QiMult = 1.2, BreakthroughBonus = 0.04 } },
}

LegendsConfig.HallSize = 5
LegendsConfig.CommunitySize = 30
LegendsConfig.Epitaphs = {
	"%s lived as they chose, and died as they lived.",
	"Here lies %s. The world was louder for a while.",
	"%s walked further than most dared to dream.",
	"Remember %s when the bells ring at dusk.",
	"%s owed the world nothing and gave it everything.",
	"The mountains remember %s. The rivers still argue about it.",
	"%s laughed at fate, and fate, for once, laughed back.",
	"Somewhere a lantern still burns for %s.",
	"%s was a storm that chose to be gentle.",
	"Ask the old ones about %s. Then bring tea; it is a long story.",
}

LegendsConfig.RelicsById = {}
for _, relic in LegendsConfig.Relics do LegendsConfig.RelicsById[relic.Id] = relic end

-- Score of a finished life (Hall of Lives).
function LegendsConfig.Score(entry): number
	return math.floor((entry.Age or 0) + (entry.RealmIndex or 1) * 25 + (entry.Fame or 0) / 10 + (entry.TopSkill or 0) * 2
		+ (entry.Karma or 0) * 3 + (if entry.Throne then 300 else 0))
end

return LegendsConfig
