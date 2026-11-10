--[[
	HistoryConfig: the world that outlives you (Modules/HistorySystem).

	History     account-wide World Chronicle (state.World.History, newest last, MaxEntries).
	            Every year one of Events may happen (YearlyChance); their text tokens:
	            {region}, {regionB}, {ruler}. Destroyed regions rise again after
	            RebuildYears. Deeds of past lives (bosses, thrones, raids, taught spells)
	            are written here too and greet every later life.
	Classes     the social class of a random soul (Weight; Money at birth, Buffs).
	            An heir keeps the family's class.
	Anomalies   rolled at birth, never chosen (Chance, checked in order): per-life stat
	            ceilings (StatCaps), birth level changes (Levels) and Buffs.
	Rebirth     the two organic choices on the death screen (no pre-birth menus).
]]

local HistoryConfig = {}

HistoryConfig.MaxEntries = 60
HistoryConfig.YearlyChance = 0.04
HistoryConfig.RebuildYears = { 12, 30 }

HistoryConfig.Events = {
	{ Id = "war", Weight = 3, Text = "War breaks out between {region} and {regionB}." },
	{ Id = "peace", Weight = 2, Text = "A peace treaty is signed in {region}. The roads are safe again." },
	{ Id = "invasion", Weight = 2, Text = "Beast tides sweep down on {region}.", Stress = 6 },
	{ Id = "succession", Weight = 2, Text = "{ruler} is crowned ruler of the realm.", Succession = true },
	{ Id = "destroyed", Weight = 1, Text = "{region} burns. Its people scatter to the winds.", Destroy = true, Stress = 10 },
	{ Id = "plague", Weight = 1, Text = "A grey plague creeps through {region}.", Health = -10 },
	{ Id = "golden_age", Weight = 1, Text = "A golden age of trade begins in {region}.", Money = 150 },
}

HistoryConfig.Classes = {
	{ Id = "Poor", Name = "Poor", Weight = 30, Money = 0, Buffs = { StressPerYear = 1, SkillXp = { Survival = 1.2 } } },
	{ Id = "Commoner", Name = "Commoner", Weight = 55, Money = 50, Buffs = {} },
	{ Id = "Noble", Name = "Noble", Weight = 15, Money = 2000, Buffs = { SocialBonus = 0.05, StudyMult = 1.05 } },
}

HistoryConfig.Anomalies = {
	{ Id = "HeavenlyRestriction", Name = "Zero-Energy Heavenly Restriction", Chance = 0.005,
		Description = "Born without a drop of mana. The body answers with impossible strength and speed.",
		StatCaps = { Mana = 0, MagicPower = 0, MagicControl = 0 },
		Buffs = { MaxManaMult = 0, StatXp = { Strength = 2, Agility = 2 }, SwordDamageMult = 1.5, DamageTakenMult = 0.85,
			SkillXp = { Swordsmanship = 1.5, Fitness = 1.5 } } },
	{ Id = "Blind", Name = "Born Blind (Mind's Eye)", Chance = 0.02,
		Description = "Your eyes see nothing; your mind sees everything. Perception and dodging grow past normal limits.",
		Buffs = { DodgeChance = 0.15, StatXp = { Intelligence = 1.3, Luck = 1.4, Agility = 1.2 } } },
	{ Id = "Frail", Name = "Born Frail (Glass Vessel)", Chance = 0.03,
		Description = "A body too weak to hold you, and a spirit far too big for it.",
		StatCaps = { Strength = 15, Vitality = 15 }, Levels = { Mana = 3, MagicPower = 2 },
		Buffs = { MaxManaMult = 1.5, MaxHealthBonus = -30, StatXp = { Mana = 1.5, MagicPower = 1.5, AuraPotential = 1.5 } } },
}
HistoryConfig.SecretBirthMult = 3 -- anomaly chances with the Secret Birth pass

HistoryConfig.Rebirth = {
	Heir = { Name = "Continue as your Child / Heir", Description = "Keep the family's city, wealth, Family Weapon, Grimoire and your bloodline." },
	Random = { Name = "Reincarnate as a Random Soul", Description = "A new region, social class, parents and lineage, rolled from scratch." },
}

HistoryConfig.ClassesById, HistoryConfig.AnomaliesById = {}, {}
for _, entry in HistoryConfig.Classes do HistoryConfig.ClassesById[entry.Id] = entry end
for _, entry in HistoryConfig.Anomalies do HistoryConfig.AnomaliesById[entry.Id] = entry end

return HistoryConfig
