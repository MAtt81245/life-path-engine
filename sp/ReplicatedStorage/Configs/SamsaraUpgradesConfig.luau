--[[
	Permanent Karma meta-upgrades, bought on the Wheel of Reincarnation between lives
	(Modules/WheelSystem, action BuyUpgrade). Ranks persist across every life.
	Effect keys read by the engine:
		ActionSlots    +PerRank yearly action diamonds (still capped by TrainingConfig.FreeActionCap)
		SpinLuck       +PerRank weight on every rarity above the lowest (Shared/Gacha)
		GlimpseChance  +PerRank chance and strength of Past-Life Glimpses (SamsaraSystem)
		SocialSlots    +PerRank yearly NPC interactions
		MemoryKeep     +PerRank generations ancestors stay remembered on the family tree
		               (Shared/LineageMemory; Soul Retention also adds MemoryPerRank)
]]

local SamsaraUpgradesConfig = {}

SamsaraUpgradesConfig.List = {
	{ Id = "TemporalAwareness", Name = "Temporal Awareness", Icon = "⌛", Effect = "ActionSlots", PerRank = 1, MaxRank = 2,
		Costs = { 40, 120 }, Description = "+1 action diamond every year per rank." },
	{ Id = "KarmicFortune", Name = "Soul Fortune", Icon = "🦋", Effect = "SpinLuck", PerRank = 0.08, MaxRank = 5,
		Costs = { 20, 40, 70, 110, 160 }, Description = "+8% weight on Rare and better spins per rank." },
	{ Id = "SoulRetention", Name = "Soul Chain Memory", Icon = "🔗", Effect = "GlimpseChance", PerRank = 0.05, MaxRank = 5,
		MemoryPerRank = 0.5, Costs = { 15, 30, 55, 85, 125 },
		Description = "+5% glimpse chance and strength per rank; slows ancestral memory decay." },
	{ Id = "AncestralChronicler", Name = "Ancestral Chronicler", Icon = "📜", Effect = "MemoryKeep", PerRank = 1, MaxRank = 3,
		Costs = { 25, 60, 120 }, Description = "Ancestors stay remembered one more generation per rank." },
	{ Id = "SocialMagnetism", Name = "Social Magnetism", Icon = "🧲", Effect = "SocialSlots", PerRank = 1, MaxRank = 2,
		Costs = { 30, 90 }, Description = "+1 NPC interaction every year per rank." },
	-- 3.0 Legacy Tree (Modules/JournalSystem applies these at birth).
	{ Id = "AncestralWisdom", Name = "Ancestral Wisdom", Icon = "W", Effect = "AllStatXp", PerRank = 0.03, MaxRank = 5,
		Costs = { 25, 50, 90, 140, 200 }, Description = "+3% all attribute XP per rank, every life." },
	{ Id = "FamilyFortune", Name = "Family Fortune", Icon = "$", Effect = "StartingMoney", PerRank = 500, MaxRank = 4,
		Costs = { 20, 45, 80, 130 }, Description = "+500 starting money per rank." },
	{ Id = "OldSoul", Name = "Old Soul", Icon = "+", Effect = "ActionSlots", PerRank = 1, MaxRank = 1,
		Costs = { 150 }, Description = "+1 action every year (within the free action cap)." },
	{ Id = "LuckyStars", Name = "Hell Butterfly Luck", Icon = "*", Effect = "SpinLuck", PerRank = 0.05, MaxRank = 4,
		Costs = { 30, 60, 100, 150 }, Description = "+5% luck on every spin per rank." },
	{ Id = "SparkOfTalent", Name = "Spark of Talent", Icon = "!", Effect = "TalentChance", PerRank = 0.1, MaxRank = 4,
		Costs = { 35, 70, 115, 170 }, Description = "+10% chance per rank to be born with a free common talent." },
	{ Id = "RareBlood", Name = "Noble Soul Blood", Icon = "R", Effect = "SpinLuck", PerRank = 0.06, MaxRank = 3,
		Costs = { 40, 85, 140 }, Description = "+6% luck per rank toward rarer soul origins (all spins)." },
	{ Id = "LongLife", Name = "Long Life", Icon = "L", Effect = "LifespanBonus", PerRank = 5, MaxRank = 5,
		Costs = { 20, 40, 70, 110, 160 }, Description = "+5 years of lifespan per rank." },
	{ Id = "FamilyHeirloom", Name = "Clan Heirloom", Icon = "H", Effect = "Heirloom", PerRank = 1, MaxRank = 1,
		Costs = { 80 }, Description = "Start every life with a clan heirloom item." },
	-- Content expansion (2026-11-02): 13 more upgrades.
	{ Id = "SoulCompass", Name = "Soul Compass", Icon = "N", Effect = "SpinLuck", PerRank = 0.04, MaxRank = 3,
		Costs = { 25, 55, 95 }, Description = "+4% luck on every spin per rank." },
	{ Id = "GoldenCradle", Name = "Golden Cradle", Icon = "G", Effect = "StartingMoney", PerRank = 1000, MaxRank = 3,
		Costs = { 60, 120, 200 }, Description = "+1,000 starting money per rank." },
	{ Id = "Evergreen", Name = "Evergreen", Icon = "E", Effect = "LifespanBonus", PerRank = 3, MaxRank = 5,
		Costs = { 15, 30, 50, 80, 120 }, Description = "+3 years of lifespan per rank." },
	{ Id = "ScholarSoul", Name = "Scholar's Soul", Icon = "S", Effect = "AllStatXp", PerRank = 0.02, MaxRank = 3,
		Costs = { 30, 65, 110 }, Description = "+2% all attribute XP per rank, every life." },
	{ Id = "CircleOfFriends", Name = "Circle of Friends", Icon = "C", Effect = "SocialSlots", PerRank = 1, MaxRank = 1,
		Costs = { 140 }, Description = "+1 NPC interaction every year." },
	{ Id = "FamilyArchive", Name = "Family Archive", Icon = "A", Effect = "MemoryKeep", PerRank = 1, MaxRank = 2,
		Costs = { 50, 110 }, Description = "Ancestors stay remembered one more generation per rank." },
	{ Id = "DreamEcho", Name = "Dream Echo", Icon = "D", Effect = "GlimpseChance", PerRank = 0.04, MaxRank = 3,
		Costs = { 20, 45, 80 }, Description = "+4% past-life glimpse chance and strength per rank." },
	{ Id = "GiftedBirth", Name = "Gifted Birth", Icon = "B", Effect = "TalentChance", PerRank = 0.08, MaxRank = 3,
		Costs = { 40, 85, 140 }, Description = "+8% chance per rank to be born with a free common talent." },
	{ Id = "DragonFortune", Name = "Hell Butterfly's Fortune", Icon = "F", Effect = "SpinLuck", PerRank = 0.05, MaxRank = 3,
		Costs = { 45, 95, 160 }, Description = "+5% luck on every spin per rank." },
	{ Id = "SilverCradle", Name = "Silver Cradle", Icon = "$", Effect = "StartingMoney", PerRank = 300, MaxRank = 5,
		Costs = { 10, 20, 35, 55, 80 }, Description = "+300 starting money per rank." },
	{ Id = "TimelessBody", Name = "Timeless Body", Icon = "T", Effect = "LifespanBonus", PerRank = 8, MaxRank = 3,
		Costs = { 70, 140, 230 }, Description = "+8 years of lifespan per rank." },
	{ Id = "InnerFire", Name = "Inner World Fire", Icon = "I", Effect = "AllStatXp", PerRank = 0.04, MaxRank = 2,
		Costs = { 120, 240 }, Description = "+4% all attribute XP per rank, every life." },
	{ Id = "TalentBloom", Name = "Talent Bloom", Icon = "+", Effect = "TalentChance", PerRank = 0.06, MaxRank = 2,
		Costs = { 90, 180 }, Description = "+6% chance per rank to be born with a free common talent." },
}

SamsaraUpgradesConfig.ById = {}
for _, upgrade in SamsaraUpgradesConfig.List do
	SamsaraUpgradesConfig.ById[upgrade.Id] = upgrade
end

return SamsaraUpgradesConfig
