--[[
	Immortal Treasury: game passes and developer products (Modules/MonetizationSystem,
	client UIController/ShopModal).

	GamePassId / DevProductId 0 = not created yet: create it on the Creator Hub and paste
	its id here. In Studio, the shop's "Studio Test Purchase (Free)" toggle grants any
	pass or product without Robux (also ServerScriptService attribute DevPasses or the
	dev console `pass <id> on|off` / `buy <productId>`). Live servers never sandbox.

	Pass fields:
		GoldenActions   extra golden action diamonds every year (on top of the free cap)
		Luck            extra spin luck (like Karmic Fortune)
		SpinSpeed       Wheel spinner animation speed multiplier
		AutoAgeSeconds  seconds per year while auto-aging (default AgingSystem.SecondsPerYear)
		FreeLock        locking a bloodline on the Wheel costs no Karma
		Badge           tag shown next to the character name
	Product fields:
		Grant = { Karma = n } | { Revive = true } | { Pill = bonus }
		Module          engine module the product needs (hidden when the pack lacks it)
	Robux is the display price only; the real price is set on the Creator Hub.
	Icon and Description may use the pack's Terms as tokens ({MetaCurrency},
	{MetaCurrencyIcon}, {ActionPip}, {RebirthWheel}, {RaceName} ...), filled in by the shop.
]]

local MonetizationConfig = {}

MonetizationConfig.Passes = {
	{ Id = "CelestialTimekeeper", Name = "Chronos Pendulum Pass", GamePassId = 0, Icon = "⌛", Robux = 149,
		GoldenActions = 1, AutoAgeSeconds = 1.5,
		Description = "+1 golden action {ActionPip} every year. Auto-age runs at 1.5 s per year instead of 4 s." },
	{ Id = "ImmortalVIP", Name = "Squad Zero VIP", GamePassId = 0, Icon = "👑", Robux = 399,
		GoldenActions = 1, SpinSpeed = 2, Luck = 0.25, Badge = "VIP",
		Description = "+1 golden action {ActionPip}, +25% permanent spin luck, x2 Wheel speed and the golden [VIP] badge." },
	{ Id = "Prodigy", Name = "Prodigy's Asauchi", GamePassId = 0, Icon = "🌟", Robux = 249,
		TrainingAgeOffset = 3, Module = "Skills",
		Description = "Real Zanjutsu and Kido training opens at age 5 instead of 8." },
	{ Id = "BloodlineVault", Name = "Royal Zanpakuto Vault", GamePassId = 0, Icon = "🏺", Robux = 249,
		FreeLock = true, Module = "Lineages",
		Description = "A free {RaceName} Lock slot: keep your rarest {RaceName} across full rebirths without paying {MetaCurrency}." },
}

MonetizationConfig.Products = {
	{ Id = "KarmaSmall", Name = "Hogyoku Shard Pack", DevProductId = 0, Icon = "{MetaCurrencyIcon}", Robux = 49,
		Grant = { Karma = 50 }, Description = "+50 {MetaCurrency} for the {RebirthWheel}." },
	{ Id = "KarmaMedium", Name = "Greater Hogyoku Shard Pack", DevProductId = 0, Icon = "{MetaCurrencyIcon}", Robux = 179,
		Grant = { Karma = 200 }, Description = "+200 {MetaCurrency}.", Tag = "Popular" },
	{ Id = "KarmaHeavenly", Name = "Royal Hogyoku Shard Pack", DevProductId = 0, Icon = "{MetaCurrencyIcon}", Robux = 449,
		Grant = { Karma = 600 }, Description = "+600 {MetaCurrency}.", Tag = "Best value" },
	{ Id = "MiracleRevival", Name = "Reject-Fate Miracle Revival", DevProductId = 0, Icon = "✨", Robux = 99,
		Grant = { Revive = true }, Hidden = true, -- offered on the death prompt only
		Description = "Reject your fate and mend your soul chain: revive at 50% health and keep this life (once per life)." },
	{ Id = "MiraclePill", Name = "Superhuman Drug Soul Candy", DevProductId = 0, Icon = "🍬", Robux = 79,
		Grant = { Pill = 0.2 }, Module = "Cultivation",
		Description = "Swallow it to fill this level's {EnergyName} to 100% and add +20% to your next {AdvanceTierName}." },
	-- Birth screen (IntroAndLoadingUI): reroll every card before your first breath. A paid
	-- random roll: hidden where PolicyService restricts paid random items (RandomItem).
	{ Id = "BirthReroll", Name = "Reroll Your Soul", DevProductId = 0, Icon = "🎲", Robux = 199,
		Grant = { BirthReroll = true }, Hidden = true, RandomItem = true,
		Description = "Reroll your {RaceName}, family and innate talent before birth (odds on the Soul Origin Ladder)." },
}

table.insert(MonetizationConfig.Products, {
	-- YOUR PATH: walk a recent decision again (Modules/PathSystem). Not random.
	Id = "PathRewind", Name = "Turn Back the Senkaimon", DevProductId = 0, Icon = "«", Robux = 99,
	Grant = { Rewind = true }, Hidden = true,
	Description = "Return to a recent decision of this life and choose again.",
})

----------------------------------------------------------------------
-- 3.0: The Trove (categories), micro-impulse products, 99 R$ passes, whale passes,
-- portrait frames, themes, save slots and codes. Category = the Trove section;
-- Giftable = can be bought for another player in this server; OneTime = once per
-- account; RandomItem = a paid luck item (PolicyService decides if it is offered).
----------------------------------------------------------------------

MonetizationConfig.Categories = {
	{ Id = "Impulse", Name = "Little Luxuries (19-59 R$)" },
	{ Id = "Frames", Name = "Portrait Frames" },
	{ Id = "Sweet", Name = "99 R$ Passes & Cosmetics" },
	{ Id = "Whale", Name = "Legendary Passes" },
	{ Id = "Classic", Name = "{MetaCurrency} Packs & Miracles" },
	{ Id = "ClassicPass", Name = "Permanent Passes" },
}

for _, product in MonetizationConfig.Products do
	product.Category = product.Category or "Classic"
end
for _, pass in MonetizationConfig.Passes do
	pass.Category = pass.Category or "ClassicPass"
end

local function product(entry)
	entry.DevProductId = entry.DevProductId or 0
	table.insert(MonetizationConfig.Products, entry)
end
local function pass(entry)
	entry.GamePassId = entry.GamePassId or 0
	table.insert(MonetizationConfig.Passes, entry)
end

-- Micro-impulse products.
product({ Id = "StarterPack", Name = "Starter Pack", Icon = "!", Robux = 19, Category = "Impulse", OneTime = true, Tag = "One time",
	Grant = { Money = 300, Items = { elixir_of_prodigy = 1, vitality_draught = 2 } },
	Description = "Prodigy's Soul Candy, two restorative draughts and 300 money. Once per account." })
product({ Id = "PouchOfGold", Name = "Pouch of Kan", Icon = "$", Robux = 25, Category = "Impulse", Giftable = true,
	Grant = { Money = 1000 }, Description = "+1,000 money right now." })
product({ Id = "Hourglass", Name = "Pendulum of Hours", Icon = "~", Robux = 29, Category = "Impulse", Giftable = true,
	Grant = { Actions = 3 }, Description = "+3 actions this year." })
product({ Id = "ElixirVitality", Name = "Fourth Division Elixir", Icon = "+", Robux = 35, Category = "Impulse", Giftable = true,
	Grant = { HealFull = true, Lifespan = 5 }, Description = "Full health and +5 years of lifespan." })
product({ Id = "TomeInsight", Name = "Research Bureau Notes", Icon = "?", Robux = 49, Category = "Impulse", Giftable = true, Module = "Skills",
	Grant = { SkillXpAll = 15 }, Description = "+15 XP to every life skill." })
product({ Id = "LegacyOffering", Name = "Hogyoku Offering", Icon = "{MetaCurrencyIcon}", Robux = 59, Category = "Impulse", Giftable = true,
	Grant = { Karma = 100 }, Description = "+100 {MetaCurrency} for the Legacy Tree." })
product({ Id = "MaxAffinity", Name = "Max Kido Affinity", Icon = "*", Robux = 149, Category = "Whale", Module = "Arcana",
	Grant = { MaxAffinity = true }, Description = "Every open Kido school at affinity 100, for this life." })

-- Portrait frames (procedural, Shared/PortraitFrames). Guildbound is free for group members.
MonetizationConfig.Frames = {
	{ Id = "guildbound", Name = "Division Crest", Free = "Group" },
	{ Id = "moonlit_scholar", Name = "Moonlit Kido" }, { Id = "galeborn", Name = "Shunpo Wind" },
	{ Id = "thunderclap", Name = "Thunderclap" }, { Id = "demon_kings_eye", Name = "Hollow Mask" },
	{ Id = "royal_asura", Name = "Royal Guard" }, { Id = "ember_crown", Name = "Bankai Flame" },
	{ Id = "frostbite", Name = "Frozen Heavens" }, { Id = "verdant_oath", Name = "Konso Lotus" },
	{ Id = "starfall", Name = "Senkaimon Gate" }, { Id = "abyss_gaze", Name = "Garganta Gaze" },
	{ Id = "sunwheel", Name = "Soul King Sun" }, { Id = "jade_lotus", Name = "Hell Butterfly" },
	{ Id = "blood_moon", Name = "Cero Moon" },
}
for _, frame in MonetizationConfig.Frames do
	if not frame.Free then
		product({ Id = "Frame_" .. frame.Id, Name = frame.Name, Icon = "O", Robux = 19, Category = "Frames", Giftable = true,
			Grant = { Frame = frame.Id }, Frame = frame.Id, Description = "A portrait frame, yours in every life." })
	end
end

-- UI and path color themes (Settings); Moonlight is free.
MonetizationConfig.Themes = {
	{ Id = "Moonlight", Name = "Reiatsu" },
	{ Id = "Gilded", Name = "Gilded", Pass = "ThemeGilded" },
	{ Id = "Crimson", Name = "Crimson", Pass = "ThemeCrimson" },
	{ Id = "Starlit", Name = "Starlit", Pass = "ThemeStarlit" },
}
MonetizationConfig.Backdrops = { "Void", "Dusk", "Forest", "Ocean", "Ember" } -- free Color Changer

-- 99 R$ passes and cosmetics.
pass({ Id = "ThemeGilded", Name = "Gilded Theme", Icon = "G", Robux = 99, Category = "Sweet", Theme = "Gilded", Description = "A gold-leaf interface theme (Settings)." })
pass({ Id = "ThemeCrimson", Name = "Crimson Theme", Icon = "C", Robux = 99, Category = "Sweet", Theme = "Crimson", Description = "A blood-red interface theme (Settings)." })
pass({ Id = "Companion", Name = "Loyal Companion", Icon = "&", Robux = 99, Category = "Sweet", Companion = "Loyal Mod Soul",
	Buffs = { HappinessPerYear = 2, StressPerYear = -1 }, Description = "A loyal Mod Soul plushie follows you through every life: +2 joy and -1 stress a year." })
pass({ Id = "CalmMind", Name = "Calm Mind", Icon = "=", Robux = 99, Category = "Sweet", Buffs = { StressGainMult = 0.5 }, Description = "Every stress gain is halved." })
pass({ Id = "SocialButterfly", Name = "Social Butterfly", Icon = "%", Robux = 99, Category = "Sweet", SocialSlots = 1, Description = "+1 social action every year." })
pass({ Id = "FateWeaver", Name = "Fate Weaver", Icon = "@", Robux = 99, Category = "Sweet", CreationSpins = 2, RandomItem = true,
	Description = "+2 free rerolls on the birth screen." })
pass({ Id = "SaveSlot2", Name = "Save Slot 2", Icon = "2", Robux = 99, Category = "Sweet", Slot = 2, Description = "A second character in the Characters carousel." })
pass({ Id = "SaveSlot3", Name = "Save Slot 3", Icon = "3", Robux = 99, Category = "Sweet", Slot = 3, Description = "A third character in the Characters carousel." })

-- Mid and whale passes.
pass({ Id = "SecondLife", Name = "Second Life", Icon = "^", Robux = 149, Category = "Whale", DeathEscape = true,
	Description = "Once per life, an untimely death becomes a narrow escape at 30% health." })
pass({ Id = "ThemeStarlit", Name = "Starlit Theme", Icon = "S", Robux = 149, Category = "Whale", Theme = "Starlit", Description = "A night-sky interface theme (Settings)." })
pass({ Id = "ArcaneBloodline", Name = "Kido Bloodline", Icon = "A", Robux = 179, Category = "Whale", Module = "Arcana",
	Buffs = { StatXp = { Mana = 1.25, MagicPower = 1.25 } }, Birth = { Affinity = 15 },
	Description = "+25% Reiryoku and Kido Power XP; every life starts with +15 affinity in each Kido school." })
pass({ Id = "ScholarsBlessing", Name = "Scholar's Blessing", Icon = "B", Robux = 179, Category = "Whale",
	Buffs = { StatXp = { Intelligence = 1.25 }, SkillXp = { Knowledge = 1.25 }, StudyMult = 1.1 }, Description = "+25% Intelligence and Research growth, +10% study." })
pass({ Id = "TraitLuck", Name = "Trait Luck x2", Icon = "L", Robux = 199, Category = "Whale", Luck = 0.5, RandomItem = true,
	Description = "Double luck on every trait and soul origin roll." })
pass({ Id = "ExtraActivity", Name = "Extra Activity", Icon = "E", Robux = 199, Category = "Whale", GoldenActions = 1, Description = "+1 golden action every year." })
pass({ Id = "FortunesFavorite", Name = "Fortune's Favorite", Icon = "F", Robux = 199, Category = "Whale", Buffs = { GoldMult = 1.2 }, Description = "+20% money from everything." })
pass({ Id = "BornMage", Name = "Born Kido Prodigy", Icon = "M", Robux = 249, Category = "Whale", Module = "Arcana",
	Birth = { SkillLevels = { Magic = 10 }, Affinity = 20 }, Description = "Every life starts with Kido 10 and +20 affinity in each Kido school." })
pass({ Id = "BladeProdigy", Name = "Zanjutsu Prodigy", Icon = "P", Robux = 249, Category = "Whale", Module = "Skills", TrainingAgeOffset = 3,
	Birth = { SkillLevels = { Swordsmanship = 10 } }, Description = "Every life starts with Zanjutsu 10; sword training opens at 5." })
pass({ Id = "BloodlineBlessing", Name = "Noble Soul Blessing", Icon = "V", Robux = 299, Category = "Whale", Luck = 0.3, RandomItem = true,
	Buffs = { AllStatXp = 1.05 }, Description = "+30% soul origin luck and +5% all attribute XP." })
pass({ Id = "SecretLuck", Name = "Secret Luck", Icon = "?", Robux = 400, Category = "Whale", Luck = 1, RandomItem = true,
	Description = "A huge, hidden boost to every roll of fate." })
pass({ Id = "FateChooser", Name = "Fate Chooser", Icon = "!", Robux = 800, Category = "Whale", CreationSpins = 5, Luck = 0.5, RandomItem = true,
	Description = "+5 rerolls on the birth screen and better odds on every roll." })
pass({ Id = "SecretBirth", Name = "Secret Birth", Icon = "#", Robux = 1000, Category = "Whale", RandomItem = true,
	Description = "Rare birth anomalies are three times as likely." })
pass({ Id = "Ultimate", Name = "ULTIMATE Pass", Icon = "U", Robux = 2000, Category = "Whale", ChooseStats = { Min = 10, Max = 100 }, Tag = "Ultimate",
	Description = "Choose every starting attribute (10-100) at the start of each life." })

-- Codes (the Codes window). Rewards: Money, Karma, Items.
MonetizationConfig.Codes = {
	RELEASE = { Money = 500 },
	SPINLUCK = { Karma = 15 },
	SECONDCHANCE = { Money = 200, Items = { healing_salve = 1 } },
	FREE99 = { Karma = 99 },
	UNBOUND = { Items = { magic_crystal = 1, focus_tonic = 1 } },
}

-- The same birth reroll paid with the meta currency instead of Robux.
MonetizationConfig.BirthRerollMetaCost = 30

-- Karma refunded when a revival can no longer be applied (the purchase is never lost).
MonetizationConfig.ReviveFallbackKarma = 100
MonetizationConfig.ReviveHealth = 0.5

MonetizationConfig.ById = {}
for _, pass in MonetizationConfig.Passes do
	MonetizationConfig.ById[pass.Id] = pass
end
MonetizationConfig.ProductsById = {}
for _, product in MonetizationConfig.Products do
	MonetizationConfig.ProductsById[product.Id] = product
end

return MonetizationConfig
