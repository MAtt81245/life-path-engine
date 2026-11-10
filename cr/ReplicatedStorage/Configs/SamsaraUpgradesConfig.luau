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
	{ Id = "KarmicFortune", Name = "Cursed Fortune", Icon = "🎲", Effect = "SpinLuck", PerRank = 0.08, MaxRank = 5,
		Costs = { 20, 40, 70, 110, 160 }, Description = "+8% weight on Rare and better spins per rank." },
	{ Id = "SoulRetention", Name = "Soul Imprint", Icon = "🕯", Effect = "GlimpseChance", PerRank = 0.05, MaxRank = 5,
		MemoryPerRank = 0.5, Costs = { 15, 30, 55, 85, 125 },
		Description = "+5% glimpse chance and strength per rank; slows ancestral memory decay." },
	{ Id = "AncestralChronicler", Name = "Ancestral Chronicler", Icon = "📜", Effect = "MemoryKeep", PerRank = 1, MaxRank = 3,
		Costs = { 25, 60, 120 }, Description = "Ancestors stay remembered one more generation per rank." },
	{ Id = "SocialMagnetism", Name = "Social Magnetism", Icon = "🧲", Effect = "SocialSlots", PerRank = 1, MaxRank = 2,
		Costs = { 30, 90 }, Description = "+1 NPC interaction every year per rank." },
	-- Content expansion (2026-11-02): 5 more upgrades. Effects of the same key add up.
	{ Id = "LuckyDraw", Name = "Lucky Draw", Icon = "🎴", Effect = "SpinLuck", PerRank = 0.04, MaxRank = 3,
		Costs = { 60, 120, 200 }, Description = "+4% weight on Rare and better spins per rank." },
	{ Id = "PastLifeEcho", Name = "Past-Life Echo", Icon = "🔔", Effect = "GlimpseChance", PerRank = 0.03, MaxRank = 3,
		Costs = { 40, 80, 140 }, Description = "+3% glimpse chance and strength per rank." },
	{ Id = "FamilyRegister", Name = "Clan Register", Icon = "📖", Effect = "MemoryKeep", PerRank = 1, MaxRank = 2,
		Costs = { 80, 180 }, Description = "Ancestors stay remembered one more generation per rank." },
	{ Id = "WideCircle", Name = "Wide Circle", Icon = "🤝", Effect = "SocialSlots", PerRank = 1, MaxRank = 1,
		Costs = { 200 }, Description = "+1 NPC interaction every year." },
	{ Id = "OvertimeVow", Name = "Overtime Vow", Icon = "⏰", Effect = "ActionSlots", PerRank = 1, MaxRank = 1,
		Costs = { 300 }, Description = "+1 action diamond every year (still capped)." },
}

SamsaraUpgradesConfig.ById = {}
for _, upgrade in SamsaraUpgradesConfig.List do
	SamsaraUpgradesConfig.ById[upgrade.Id] = upgrade
end

return SamsaraUpgradesConfig
