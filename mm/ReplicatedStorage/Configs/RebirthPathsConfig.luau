--[[
	How and when to be reborn (Modules/SamsaraSystem, chosen on the Wheel).
	Paths:
		Cost       Karma paid at rebirth (FreeIfFlag at death waives it)
		Era        "Same" keeps the previous era; otherwise an Eras key
		Echoes     people from the past life still live and can be met again
		WealthShare / Heirloom / FamilyAffection  descendant inheritance
		Legends    the world remembers the previous self (future rebirths)
	Eras: per-life Buffs (shared buff keys). Echoes: relationship types that persist.
	Glimpse: Past-Life Glimpse rolls in childhood and youth (Soul Retention adds
	GlimpseChance to both chance and strength).
]]

local RebirthPathsConfig = {}

RebirthPathsConfig.Default = "Stranger"

RebirthPathsConfig.Paths = {
	{ Id = "Descendant", Name = "Direct Descendant", Icon = "🏯", Cost = 30, FreeIfFlag = "Married", Era = "Same", Echoes = true,
		WealthShare = 0.25, Heirloom = true, FamilyAffection = { 85, 95 },
		Description = "Keep the family name, 25% of your wealth and an heirloom. Free if you married." },
	{ Id = "Stranger", Name = "Stranger, Same Era", Icon = "👤", Cost = 0, Era = "Same", Echoes = true,
		Description = "A new family in the same world. People from your past life still live." },
	{ Id = "Past", Name = "Ancient Primordial Era", Icon = "🏛", Cost = 25, Era = "Ancient",
		Description = "Denser Qi (+25%) and ancient masters, but a harsher, deadlier world." },
	{ Id = "Future", Name = "A Century Later", Icon = "🔮", Cost = 25, Era = "Future", Legends = true,
		Description = "The world has changed because of who you were. Hear your own legend." },
}

RebirthPathsConfig.Eras = {
	Present = { Name = "Present Era", Buffs = {} },
	Ancient = { Name = "Ancient Primordial Era", Buffs = { QiMult = 1.25, MaxHealthBonus = -25, StressPerYear = 2 } },
	Future = { Name = "A Century Later", Buffs = { StudyMult = 1.1 } },
}

RebirthPathsConfig.EchoTypes = { Partner = true, Friend = true, Rival = true }

RebirthPathsConfig.Glimpse = {
	MinAge = 4, MaxAge = 30, MaxPerLife = 3,
	BaseChance = 0.08, BaseStrength = 0.15,
}

RebirthPathsConfig.ById = {}
for _, path in RebirthPathsConfig.Paths do
	RebirthPathsConfig.ById[path.Id] = path
end

return RebirthPathsConfig
