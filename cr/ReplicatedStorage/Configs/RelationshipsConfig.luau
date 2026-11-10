--[[
	Dynamic relationships: Family, Friends, Rivals and a Partner, each with an
	Affection bar (0-100). Affection drifts every year unless you invest in it.
	Low-affection friends may betray you; bonded friends may help (see YearlyEventsConfig).
]]

local RelationshipsConfig = {}

RelationshipsConfig.MaxRelationships = 24
-- Interactions per year across everyone; each interaction once per person per year.
RelationshipsConfig.SocialPerYear = 3 -- + Social Magnetism ranks

RelationshipsConfig.Types = {
	Mother = { Name = "Mother", Category = "Family" },
	Father = { Name = "Father", Category = "Family" },
	Sibling = { Name = "Sibling", Category = "Family" },
	Friend = { Name = "Friend", Category = "Friend" },
	Rival = { Name = "Rival", Category = "Rival" },
	Partner = { Name = "Partner", Category = "Partner" },
	Parent = { Name = "Parent", Category = "Family" }, -- a descendant's surviving parent
	Grandparent = { Name = "Grandparent", Category = "Family" }, -- a grandchild-rebirth's grandparent
	Child = { Name = "Child", Category = "Child" }, -- your own children (Dynasty module)
}

RelationshipsConfig.CategoryOrder = { "Partner", "Child", "Family", "Friend", "Rival" }
RelationshipsConfig.Categories = {
	Family = { Name = "Family", Color = Color3.fromRGB(250, 200, 110), YearlyDrift = -1 },
	Friend = { Name = "Friend", Color = Color3.fromRGB(110, 220, 160), YearlyDrift = -3 },
	Rival = { Name = "Rival", Color = Color3.fromRGB(240, 100, 110), YearlyDrift = 0 },
	Partner = { Name = "Partner", Color = Color3.fromRGB(240, 130, 210), YearlyDrift = -2 },
	Child = { Name = "Child", Color = Color3.fromRGB(150, 230, 210), YearlyDrift = -1 },
}

-- Affection labels, highest threshold first.
RelationshipsConfig.Thresholds = {
	{ Min = 80, Label = "Bonded" },
	{ Min = 60, Label = "Close" },
	{ Min = 40, Label = "Friendly" },
	{ Min = 20, Label = "Distant" },
	{ Min = 0, Label = "Hostile" },
}

function RelationshipsConfig.GetLabel(affection: number): string
	for _, threshold in RelationshipsConfig.Thresholds do
		if affection >= threshold.Min then
			return threshold.Label
		end
	end
	return "Hostile"
end

-- Chance-based interactions add 1% per level of ChanceStat, plus social buffs for Charisma.
-- Module: engine module that must be on. Upbringing: sets a child's upbringing (once,
-- child age <= MaxChildAge). Stake: duel stakes (RelationshipSystem). Rivals and
-- romance targets with a high genetic Grade are harder (GeneticsConfig).
RelationshipsConfig.Interactions = {
	{ Id = "SpendTime", Name = "Spend Time", Affection = 8, Happiness = 3,
		Categories = { Family = true, Friend = true, Partner = true, Child = true } },
	{ Id = "Gift", Name = "Gift ¥200", MoneyCost = 200, Affection = 14,
		Categories = { Family = true, Friend = true, Partner = true, Child = true } },
	{ Id = "AskHelp", Name = "Ask Help", MinAffection = 70, Affection = -6, OncePerYear = true,
		Categories = { Family = true, Friend = true, Partner = true } },
	{ Id = "Romance", Name = "Ask Out", MinAffection = 60, MinAge = 16, Chance = 0.35, ChanceStat = "Charisma",
		Categories = { Friend = true } },
	{ Id = "Argue", Name = "Argue", Affection = -15, Stress = -8,
		Categories = { Family = true, Friend = true, Partner = true } },
	{ Id = "Challenge", Name = "Spar", Chance = 0.4, ChanceStat = "Strength", Stake = "Pride",
		Categories = { Rival = true } },
	{ Id = "Wager", Name = "Wager", MinAge = 16, Chance = 0.4, ChanceStat = "Strength", Stake = "Wealth", MinMoney = 100,
		Categories = { Rival = true } },
	{ Id = "BloodFeud", Name = "Blood Feud", MinAge = 16, Chance = 0.35, ChanceStat = "Strength", Stake = "Life",
		Categories = { Rival = true } },
	{ Id = "TryForChild", Name = "Try for a Child", MinAge = 18, MinAffection = 50, Module = "Dynasty",
		Categories = { Partner = true } },
	{ Id = "RaiseMartial", Name = "Taijutsu", Upbringing = "Martial", Affection = 6, MaxChildAge = 15, Module = "Dynasty",
		Categories = { Child = true } },
	{ Id = "RaiseScholarly", Name = "Scholarly", Upbringing = "Scholarly", Affection = 6, MaxChildAge = 15, Module = "Dynasty",
		Categories = { Child = true } },
	{ Id = "RaiseSpiritual", Name = "Cursed Energy", Upbringing = "Spiritual", Affection = 6, MaxChildAge = 15, Module = "Dynasty",
		Categories = { Child = true } },
	{ Id = "RaiseAgile", Name = "Agility", Upbringing = "Agile", Affection = 6, MaxChildAge = 15, Module = "Dynasty",
		Categories = { Child = true } },
	{ Id = "RaiseCourtly", Name = "Etiquette", Upbringing = "Courtly", Affection = 6, MaxChildAge = 15, Module = "Dynasty",
		Categories = { Child = true } },
	{ Id = "RaiseHardy", Name = "Endurance", Upbringing = "Hardy", Affection = 6, MaxChildAge = 15, Module = "Dynasty",
		Categories = { Child = true } },
	{ Id = "Reconcile", Name = "Make Peace", Chance = 0.3, ChanceStat = "Charisma",
		Categories = { Rival = true } },
	-- Content expansion (2026-11-02): 14 more interactions.
	{ Id = "ShareMeal", Name = "Share Ramen", MoneyCost = 20, Affection = 6, Happiness = 3,
		Categories = { Family = true, Partner = true, Child = true } },
	{ Id = "TeaHouse", Name = "Cafe Date ¥50", MoneyCost = 50, Affection = 10, Stress = -4, MinAge = 12,
		Categories = { Friend = true, Partner = true } },
	{ Id = "Confide", Name = "Confide", MinAffection = 50, Affection = 7, Stress = -6, MinAge = 8,
		Categories = { Family = true, Friend = true, Partner = true } },
	{ Id = "Compliment", Name = "Compliment", Affection = 4,
		Categories = { Family = true, Friend = true, Partner = true } },
	{ Id = "PlayGo", Name = "Play Shogi", Affection = 5, Stress = -2, MinAge = 8,
		Categories = { Family = true, Friend = true, Child = true } },
	{ Id = "TeachSkill", Name = "Teach a Technique", Affection = 7, MinAge = 18,
		Categories = { Friend = true, Child = true } },
	{ Id = "FestivalOuting", Name = "Summer Festival ¥80", MoneyCost = 80, Affection = 12, Happiness = 5, MinAge = 6,
		Categories = { Family = true, Friend = true, Partner = true } },
	{ Id = "WriteLetter", Name = "Text Them", Affection = 5, MinAge = 8,
		Categories = { Family = true, Friend = true, Partner = true, Child = true } },
	{ Id = "Karaoke Duet", Name = "Karaoke Duet", Affection = 12, Happiness = 4, MinAge = 16,
		Categories = { Partner = true } },
	{ Id = "Watch Fireworks", Name = "Watch Fireworks", Affection = 9, Stress = -5, MinAge = 14,
		Categories = { Partner = true } },
	{ Id = "BedtimeStory", Name = "Bedtime Story", Affection = 8, Happiness = 3, MinAge = 18,
		Categories = { Child = true } },
	{ Id = "Taunt", Name = "Taunt", Affection = -6, Stress = -6,
		Categories = { Rival = true } },
	{ Id = "IgnoreRival", Name = "Ignore", Affection = 2, Stress = -3,
		Categories = { Rival = true } },
	{ Id = "RivalGift", Name = "Peace Gift ¥150", MoneyCost = 150, Affection = 10, MinAge = 12,
		Categories = { Rival = true } },
}

-- "Ask Help" from family. Relatives younger than MinGiverAge offer comfort
-- instead of money. Money comes from the first bracket whose MaxAge covers the
-- character's age, x (0.5 + affection / 200) when AffectionScale, x EmployedMult
-- when the relative has an occupation (NPC autonomy).
RelationshipsConfig.FamilyHelp = {
	MinGiverAge = 18,
	AffectionScale = true,
	EmployedMult = 1.5,
	Brackets = {
		{ MaxAge = 11, Min = 5, Max = 20 }, -- pocket money
		{ MaxAge = 17, Min = 20, Max = 80 }, -- teen allowance
		{ MaxAge = math.huge, Min = 100, Max = 400 }, -- help as an adult
	},
}

RelationshipsConfig.InteractionsById = {}
for _, interaction in RelationshipsConfig.Interactions do
	RelationshipsConfig.InteractionsById[interaction.Id] = interaction
end

RelationshipsConfig.FirstNames = {
	"Yuki", "Ren", "Aoi", "Kai", "Mio", "Haru", "Sora", "Riku", "Hana", "Taro", "Emi", "Daichi", "Rin", "Kenta", "Saki",
	"Yuto", "Mei", "Sota", "Nana", "Kaito", "Akane", "Shun", "Yui", "Takumi", "Kana", "Ryo", "Mika", "Hiro", "Asuka", "Jun",
	"Kiyoshi", "Natsu", "Tomoe", "Isamu", "Chiyo", "Raiden", "Sayaka", "Goro", "Hotaru", "Akio", "Fumiko", "Kenji", "Ume", "Tetsu", "Nozomi",
	"Masaru", "Kaede", "Shiro", "Ayame", "Toru", "Midori", "Juro", "Sumire", "Hayato", "Ritsu", "Kotone", "Ibuki", "Yoshi", "Chika", "Arata",
}
RelationshipsConfig.Surnames = { "Sato", "Kamo", "Mori", "Aoyama", "Fujita", "Ishida", "Kuroda", "Takeda", "Hayashi", "Ono", "Sakamoto", "Shimizu", "Yamada", "Kondo", "Nishida",
	"Arakawa", "Tsukishima", "Hoshino", "Kirishima", "Mibu", "Saionji", "Kageyama", "Noda", "Ueda", "Shirakawa", "Kurogane", "Amagi", "Hinode", "Tachibana", "Mizuno" }

return RelationshipsConfig
