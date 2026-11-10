--[[
	WorldHubConfig: the World modal (Modules/WorldHubSystem, UIController/WorldModal).
	Rotations come from the clock (os.time), so every server shows the same event,
	posters and merchant stock without any storage.

	Events        a new global event every EventPeriod seconds, active for its first
	              EventActive seconds (Buffs for everyone online).
	Posters       per region, PosterCount Wanted Posters every EventPeriod: beat that
	              enemy for Seals bounty seals (once per poster).
	Merchant      MerchantCount offers from MerchantPool every MerchantPeriod, for gold.
	Drops         battle drops per enemy: { itemId = { min, max } }.
	Recipes       materials -> trinket (Inventory items).
	Friends       buffs while a Roblox friend plays in the same server.
	Group         GroupId (0 = not set yet): members get Buffs and the Guild Member title.
	Champions     weekly OrderedDataStore of combat power (top ChampionsShown).
]]

return {
	EventPeriod = 7200, EventActive = 1200,
	Events = {
		{ Id = "HuntersMoon", Name = "Hollow Moon", Text = "x2 loot and fight EXP", Buffs = { BattleRewardMult = 2, SkillXp = { Swordsmanship = 2, Magic = 2 } } },
		{ Id = "ScholarsDawn", Name = "Academy Exam Season", Text = "+30% study, x1.5 Research", Buffs = { StudyMult = 1.3, SkillXp = { Knowledge = 1.5 } } },
		{ Id = "ManaTide", Name = "Reishi Tide", Text = "Kido costs 30% less", Buffs = { ManaCostMult = 0.7 } },
		{ Id = "MerchantsFair", Name = "Candy Shop Sale", Text = "+25% money from everything", Buffs = { GoldMult = 1.25 } },
		{ Id = "SpiritBloom", Name = "Spirit Bloom", Text = "+20% all attribute XP", Buffs = { AllStatXp = 1.2 } },
		-- Content expansion (2026-11-02): 5 more world events.
		{ Id = "QiTide", Name = "Reiatsu Tide", Text = "+30% Reiatsu gain", Buffs = { QiMult = 1.3 } },
		{ Id = "LanternNight", Name = "Obon Lantern Night", Text = "+25% affection gains", Buffs = { RelationshipMult = 1.25 } },
		{ Id = "BloodMoon", Name = "Hollow Moon", Text = "+15% sword and Kido damage", Buffs = { SwordDamageMult = 1.15, MagicDamageMult = 1.15 } },
		{ Id = "HarvestFestival", Name = "Harvest Festival", Text = "+20% salary, +10% gold", Buffs = { SalaryMult = 1.2, GoldMult = 1.1 } },
		{ Id = "HeavenlyCalm", Name = "Inner World Calm", Text = "+5% awakening chance", Buffs = { BreakthroughBonus = 0.05 } },
	},
	PosterCount = 3, Seals = 2,
	MerchantPeriod = 10800, MerchantCount = 3,
	MerchantPool = {
		{ Item = "magic_crystal", Price = 450 },
		{ Item = "focus_tonic", Price = 220 },
		{ Item = "travelers_compass", Price = 900 },
		{ Item = "healing_salve", Price = 150 },
		{ Item = "lucky_charm", Price = 600 },
		{ Item = "energy_ginseng", Price = 500 },
		{ Item = "jade_dew", Price = 900 },
		{ Item = "dream_incense", Price = 260 },
		{ Item = "fox_tail_charm", Price = 1100 },
		{ Item = "thunder_talisman", Price = 1500 },
		{ Item = "beast_core", Price = 300 },
		{ Item = "fortune_cookie", Price = 60 },
	},
	Drops = {
		wild_boar = { boar_tusk = { 1, 2 } },
		bandit_scout = { rabbit_horn = { 0, 1 }, boar_tusk = { 0, 1 } },
		bamboo_viper = { spider_silk = { 1, 2 } },
		marsh_ghoul = { spider_silk = { 1, 3 } },
		slum_enforcer = { rabbit_horn = { 1, 2 } },
		rogue_mage = { spider_silk = { 1, 1 }, rabbit_horn = { 1, 1 } },
		snow_ape = { boar_tusk = { 2, 3 } },
		stray_wolf = { wolf_pelt = { 1, 2 } },
		lotus_assassin = { serpent_fang = { 1, 2 } },
		rogue_cultivator = { spirit_herb = { 1, 2 } },
		bog_witch = { spirit_herb = { 1, 3 }, ghost_lantern_wick = { 0, 1 } },
		frost_yeti = { wolf_pelt = { 2, 3 }, beast_core = { 0, 1 } },
		ruin_wraith = { ghost_lantern_wick = { 1, 1 } },
		nine_tailed_fox = { beast_core = { 2, 3 }, menos_mask_shard = { 0, 1 } },
	},
	Recipes = {
		{ Result = "hunters_token", Needs = { boar_tusk = 3 } },
		{ Result = "weavers_charm", Needs = { spider_silk = 3 } },
		{ Result = "guardsmans_badge", Needs = { bounty_seal = 2 } },
		{ Result = "survivors_totem", Needs = { rabbit_horn = 2, boar_tusk = 1 } },
		{ Result = "ancestral_bracer", Needs = { beast_core = 2, wolf_pelt = 2 } },
		{ Result = "fox_tail_charm", Needs = { serpent_fang = 2, spirit_herb = 2 } },
		{ Result = "thunder_talisman", Needs = { beast_core = 3, ghost_lantern_wick = 1 } },
		{ Result = "travelers_compass", Needs = { wolf_pelt = 2, bounty_seal = 1 } },
	},
	Friends = { Buffs = { AllStatXp = 1.1, SkillXpMult = 1.1 }, Text = "+10% growth: a friend is in this server" },
	Group = { GroupId = 0, Buffs = { SwordDamageMult = 1.05, MagicDamageMult = 1.05 }, Text = "+5% power: Division Member" },
	ChampionsShown = 10, ChampionsUpdate = 120,
}
