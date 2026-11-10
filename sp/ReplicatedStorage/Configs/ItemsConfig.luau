--[[
	Items for the Inventory module (Modules/InventorySystem).

	Item fields:
		Id, Name, Category, Description
		Price        -> market price (nil = cannot be bought)
		SellPrice    -> sale value (default floor(Price / 2); nil with no Price = cannot be sold)
		MaxStack     -> most you can carry (default 99, equipment 1)
		MinAge, Requires (Shared/Requirements spec), Module (engine module that must be on)
		Use   = { Effects = {...}, UsesPerYear = n }  -> consumed on use; Effects use the event
		                                              effect schema (YearlyEventsConfig header)
		Equip = { Slot = "Weapon" | "Armor" | "Accessory", Buffs = {...} } -> buffs while equipped

	Events can grant items with the effect Items = { itemId = count } and require them
	with the requirement Items = { itemId = count }.
]]

local ItemsConfig = {}

ItemsConfig.DefaultMaxStack = 99

ItemsConfig.Categories = {
	Consumable = { Name = "Consumable", Color = Color3.fromRGB(110, 225, 150) },
	Equipment = { Name = "Equipment", Color = Color3.fromRGB(110, 190, 255) },
	Valuable = { Name = "Valuable", Color = Color3.fromRGB(236, 196, 104) },
	Material = { Name = "Material", Color = Color3.fromRGB(190, 170, 140) },
}

ItemsConfig.SlotOrder = { "Weapon", "Armor", "Accessory" }
ItemsConfig.Slots = {
	Weapon = { Name = "Zanpakuto" },
	Armor = { Name = "Shihakusho" },
	Accessory = { Name = "Charm" },
}

ItemsConfig.Items = {
	-- Consumables
	{ Id = "healing_salve", Name = "Kido Healing Salve", Category = "Consumable", Price = 120,
		Description = "Restores 30 health.", Use = { Effects = { Health = 30 } } },
	{ Id = "calming_tea", Name = "Fourth Division Tea", Category = "Consumable", Price = 60,
		Description = "-15 stress, +3 happiness.", Use = { Effects = { Stress = -15, Happiness = 3 } } },
	{ Id = "energy_ginseng", Name = "Superhuman Drug", Category = "Consumable", Price = 400, MinAge = 10,
		Description = "+1 action this year (once a year).", Use = { Effects = { Actions = 1 }, UsesPerYear = 1 } },
	{ Id = "strategy_book", Name = "Shin'o Kido Textbook", Category = "Consumable", Price = 300, MinAge = 8,
		Description = "+25 INT XP and +2 knowledge.", Use = { Effects = { Stats = { Intelligence = 25 }, Counters = { Knowledge = 2 } } } },
	{ Id = "spirit_pill", Name = "Soul Candy", Category = "Consumable", Price = 800, MinAge = 10, Module = "Cultivation",
		Description = "Half a stage of Reiatsu (2 per year).", Use = { Effects = { Qi = 0.5 }, UsesPerYear = 2 } },
	{ Id = "foundation_pill", Name = "Reishi Condensation Pill", Category = "Consumable", Price = 6000, Module = "Cultivation",
		Requires = { MinRealm = 2 },
		Description = "Two stages of Reiatsu and +10 Reiatsu Control XP (1 per year).", Use = { Effects = { Qi = 2, Stats = { QiControl = 10 } }, UsesPerYear = 1 } },
	{ Id = "longevity_peach", Name = "Gigai Longevity Tuning", Category = "Consumable", Price = 15000, MinAge = 30,
		Description = "+5 years of life (1 per year, 6 per life).", Use = { Effects = { Lifespan = 5 }, UsesPerYear = 1, MaxPerLife = 6 } },

	-- Equipment
	{ Id = "wooden_sword", Name = "Sealed Asauchi Katana", Category = "Equipment", Price = 150, MinAge = 8,
		Description = "A nameless blade waiting to learn your soul. +15% Zanjutsu XP.", Equip = { Slot = "Weapon", Buffs = { ProficiencyXp = { Sword = 1.15 } } } },
	{ Id = "iron_sword", Name = "Unseated Officer's Katana", Category = "Equipment", Price = 1200, Requires = { Proficiency = { Sword = 5 } },
		Description = "+30% Zanjutsu XP, +5% AGI XP.", Equip = { Slot = "Weapon", Buffs = { ProficiencyXp = { Sword = 1.3 }, StatXp = { Agility = 1.05 } } } },
	{ Id = "jade_spear", Name = "Onmitsukido Combat Gauntlets", Category = "Equipment", Price = 2500, Requires = { Proficiency = { Spear = 10 } },
		Description = "+40% Hakuda & Hoho XP, +10% STR XP.", Equip = { Slot = "Weapon", Buffs = { ProficiencyXp = { Spear = 1.4 }, StatXp = { Strength = 1.1 } } } },
	{ Id = "padded_robe", Name = "Academy Shihakusho", Category = "Equipment", Price = 400,
		Description = "+20 max health.", Equip = { Slot = "Armor", Buffs = { MaxHealthBonus = 20 } } },
	{ Id = "sect_battle_robe", Name = "Division Haori", Category = "Equipment", Price = 3500, Module = "Masters",
		Requires = { HasMaster = true },
		Description = "+60 max health, +2% Soul Awakening.", Equip = { Slot = "Armor", Buffs = { MaxHealthBonus = 60, BreakthroughBonus = 0.02 } } },
	{ Id = "jade_pendant", Name = "Spirit-Sight Glasses", Category = "Equipment", Price = 1800,
		Description = "+20% INT XP, +10% study.", Equip = { Slot = "Accessory", Buffs = { StatXp = { Intelligence = 1.2 }, StudyMult = 1.1 } } },
	{ Id = "lucky_charm", Name = "Substitute Combat Pass", Category = "Equipment", Price = 500,
		Description = "+5% social success.", Equip = { Slot = "Accessory", Buffs = { SocialBonus = 0.05 } } },

	-- Valuables (found through events, sold at the market)
	{ Id = "ancient_talisman", Name = "Hogyoku Fragment", Category = "Valuable", SellPrice = 4000,
		Description = "A sliver of the orb that grants its holder's heart's desire. Collectors pay well." },
	{ Id = "jade_bracelet", Name = "Sealed Spirit Ribbon", Category = "Valuable", SellPrice = 1500,
		Description = "An old Quincy cross tied with a sealed ribbon, passed down in secret." },

	-- Named Zanpakuto and spirit weapons: not sold at the market; found or inherited (events,
	-- heirlooms). Consecrated ones pass down the family as Inherited Zanpakuto.
	{ Id = "split_soul_katana", Name = "Black Crescent Getsuga Greatblade", Category = "Equipment",
		Description = "A huge cleaver that fires crescent waves. +45% Zanjutsu XP, +10% AGI XP.",
		Equip = { Slot = "Weapon", Buffs = { ProficiencyXp = { Sword = 1.45 }, StatXp = { Agility = 1.1 } } } },
	{ Id = "inverted_spear", Name = "Thousand Cherry Blossom Katana", Category = "Equipment",
		Description = "Scatters into a thousand blossom blades. +40% Zanjutsu XP, +4% Soul Awakening.",
		Equip = { Slot = "Weapon", Buffs = { ProficiencyXp = { Sword = 1.4 }, BreakthroughBonus = 0.04 } } },
	{ Id = "festering_life_blade", Name = "All-Things-to-Ash Flame Katana", Category = "Equipment",
		Description = "The oldest flame blade; everything it touches burns. +35% Zanjutsu XP, +10% STR XP.",
		Equip = { Slot = "Weapon", Buffs = { ProficiencyXp = { Sword = 1.35 }, StatXp = { Strength = 1.1 } } } },
	{ Id = "chain_thousand_miles", Name = "Murcielago Lanza Spear", Category = "Equipment",
		Description = "A spear of green light from a winged Espada. +35% Hakuda & Hoho XP, +10% AGI XP.",
		Equip = { Slot = "Weapon", Buffs = { ProficiencyXp = { Spear = 1.35 }, StatXp = { Agility = 1.1 } } } },
	{ Id = "black_rope", Name = "Heilig Pfeil Quincy Spirit Bow", Category = "Equipment",
		Description = "A bow of gathered reishi. +40 max health, +15% Kido & Cero Arts XP.",
		Equip = { Slot = "Accessory", Buffs = { MaxHealthBonus = 40, ProficiencyXp = { QiArts = 1.15 } } } },
	{ Id = "frozen_heavens_blade", Name = "Frozen Heavens Dragon Blade", Category = "Equipment",
		Description = "An ice dragon coils around the blade. +35% Zanjutsu XP, +15% Kido & Cero Arts XP.",
		Equip = { Slot = "Weapon", Buffs = { ProficiencyXp = { Sword = 1.35, QiArts = 1.15 } } } },
	{ Id = "white_haze_blade", Name = "White Haze Subzero Blade", Category = "Equipment",
		Description = "A pure white blade that freezes the air it cuts. +35% Zanjutsu XP, +10% Charisma XP.",
		Equip = { Slot = "Weapon", Buffs = { ProficiencyXp = { Sword = 1.35 }, StatXp = { Charisma = 1.1 } } } },
	{ Id = "kyoka_hypnosis_blade", Name = "Kyoka Perfect Hypnosis Blade", Category = "Equipment",
		Description = "Whoever sees its release believes whatever its wielder wants. +30% Zanjutsu XP, +15% INT XP.",
		Equip = { Slot = "Weapon", Buffs = { ProficiencyXp = { Sword = 1.3 }, StatXp = { Intelligence = 1.15 } } } },
	-- 3.0: Hollow hunt drops (World hub crafting), crafted trinkets, merchant and pass goods.
	{ Id = "boar_tusk", Name = "Hollow Fang", Category = "Material", SellPrice = 15, Description = "A fang from a lesser Hollow. Smiths want it." },
	{ Id = "spider_silk", Name = "Menos Silk", Category = "Material", SellPrice = 25, Description = "Strong as wire, light as breath." },
	{ Id = "rabbit_horn", Name = "Mask Shard", Category = "Material", SellPrice = 20, Description = "A shard of a broken Hollow mask. Lucky, they say." },
	{ Id = "bounty_seal", Name = "Hell Butterfly Seal", Category = "Material", SellPrice = 60, Description = "Proof of a Hollow Bounty fulfilled." },
	{ Id = "hunters_token", Name = "Hollow Hunter's Token", Category = "Equipment", SellPrice = 120,
		Description = "+10% hunt rewards.", Equip = { Slot = "Accessory", Buffs = { BattleRewardMult = 1.1 } } },
	{ Id = "weavers_charm", Name = "Reishi Weaver's Charm", Category = "Equipment", SellPrice = 150,
		Description = "-8% reiryoku costs.", Equip = { Slot = "Accessory", Buffs = { ManaCostMult = 0.92 } } },
	{ Id = "guardsmans_badge", Name = "Gotei Patrol Badge", Category = "Equipment", SellPrice = 180,
		Description = "-8% damage taken.", Equip = { Slot = "Armor", Buffs = { DamageTakenMult = 0.92 } } },
	{ Id = "survivors_totem", Name = "Rukongai Survivor's Totem", Category = "Equipment", SellPrice = 140,
		Description = "+25 max health.", Equip = { Slot = "Accessory", Buffs = { MaxHealthBonus = 25 } } },
	{ Id = "magic_crystal", Name = "Reiryoku Crystal", Category = "Consumable", SellPrice = 100,
		Description = "Shatter it to deepen your reiryoku (+5 max).", Use = { Effects = { ManaBonus = 5 } } },
	{ Id = "focus_tonic", Name = "Fourth Division Focus Tonic", Category = "Consumable", SellPrice = 60,
		Description = "-15 stress, +10 Intelligence XP.", Use = { Effects = { Stress = -15, Stats = { Intelligence = 10 } } } },
	{ Id = "elixir_of_prodigy", Name = "Prodigy's Soul Candy", Category = "Consumable", SellPrice = 50,
		Description = "+15 Strength, Agility and Intelligence XP.", Use = { Effects = { Stats = { Strength = 15, Agility = 15, Intelligence = 15 } } } },
	{ Id = "vitality_draught", Name = "Restorative Draught", Category = "Consumable", SellPrice = 30,
		Description = "+40 health, -10 stress.", Use = { Effects = { Health = 40, Stress = -10 } } },
	{ Id = "travelers_compass", Name = "Senkaimon Compass", Category = "Equipment", SellPrice = 200,
		Description = "+10% hunt rewards, easier escapes.", Equip = { Slot = "Accessory", Buffs = { BattleRewardMult = 1.1, FleeBonus = 0.05 } } },
	-- Content expansion (2026-11-02): 29 more items (14 of them in the market).
	{ Id = "rice_wine", Name = "Karakura Sake", Category = "Consumable", Price = 40, MinAge = 16,
		Description = "+6 happiness, -8 stress.", Use = { Effects = { Happiness = 6, Stress = -8 } } },
	{ Id = "herbal_poultice", Name = "Kaido Poultice", Category = "Consumable", Price = 250,
		Description = "Restores 60 health.", Use = { Effects = { Health = 60 } } },
	{ Id = "tiger_bone_tonic", Name = "Training Cavern Tonic", Category = "Consumable", Price = 500, MinAge = 12,
		Description = "+20 Strength and Vitality XP.", Use = { Effects = { Stats = { Strength = 20, Vitality = 20 } } } },
	{ Id = "wind_step_manual", Name = "Hoho Footwork Manual", Category = "Consumable", Price = 450, MinAge = 10,
		Description = "+30 Agility XP.", Use = { Effects = { Stats = { Agility = 30 } } } },
	{ Id = "etiquette_scroll", Name = "Noble House Etiquette Scroll", Category = "Consumable", Price = 350, MinAge = 10,
		Description = "+25 Charisma XP.", Use = { Effects = { Stats = { Charisma = 25 } } } },
	{ Id = "meridian_needles", Name = "Reiraku Needles", Category = "Consumable", Price = 1500, MinAge = 12, Module = "Cultivation",
		Description = "+20 Reiatsu Control XP and a tenth of a level of Reiatsu (1 per year).", Use = { Effects = { Qi = 0.1, Stats = { QiControl = 20 } }, UsesPerYear = 1 } },
	{ Id = "marrow_cleansing_pill", Name = "Reishi Marrow Capsule", Category = "Consumable", Price = 20000, Module = "Cultivation",
		Requires = { MinRealm = 3 },
		Description = "One level of Reiatsu and +20 max health (1 per year, 4 per life).", Use = { Effects = { Qi = 1, MaxHealth = 20 }, UsesPerYear = 1, MaxPerLife = 4 } },
	{ Id = "steel_saber", Name = "Seated Officer's Katana", Category = "Equipment", Price = 3000, Requires = { Proficiency = { Sword = 15 } },
		Description = "+40% Zanjutsu XP, +5% Zanjutsu damage.", Equip = { Slot = "Weapon", Buffs = { ProficiencyXp = { Sword = 1.4 }, SwordDamageMult = 1.05 } } },
	{ Id = "scholar_fan", Name = "Kido Scholar's Fan", Category = "Equipment", Price = 900, MinAge = 12,
		Description = "+15% INT and CHA XP.", Equip = { Slot = "Weapon", Buffs = { StatXp = { Intelligence = 1.15, Charisma = 1.15 } } } },
	{ Id = "spirit_staff", Name = "Kido Focus Staff", Category = "Equipment", Price = 2800, MinAge = 14,
		Description = "+10% Kido damage, -5% Reiryoku costs.", Equip = { Slot = "Weapon", Buffs = { MagicDamageMult = 1.1, ManaCostMult = 0.95 } } },
	{ Id = "leather_vest", Name = "Patrol Vest", Category = "Equipment", Price = 900,
		Description = "+35 max health, easier escapes.", Equip = { Slot = "Armor", Buffs = { MaxHealthBonus = 35, FleeBonus = 0.05 } } },
	{ Id = "silk_court_robe", Name = "Noble's Silk Kimono", Category = "Equipment", Price = 2200, MinAge = 16,
		Description = "+10% social success, +5% salary.", Equip = { Slot = "Armor", Buffs = { SocialBonus = 0.1, SalaryMult = 1.05 } } },
	{ Id = "merchant_abacus", Name = "Shopkeeper's Abacus", Category = "Equipment", Price = 1600, MinAge = 14,
		Description = "+8% gold.", Equip = { Slot = "Accessory", Buffs = { GoldMult = 1.08 } } },
	{ Id = "monk_prayer_beads", Name = "Konso Prayer Beads", Category = "Equipment", Price = 1200,
		Description = "+20% Hogyoku Shards earned, -1 stress per year.", Equip = { Slot = "Accessory", Buffs = { KarmaMult = 1.2, StressPerYear = -1 } } },
	{ Id = "black_pearl", Name = "Black Pearl", Category = "Valuable", SellPrice = 2500,
		Description = "Found in the deepest pool of the outer districts." },
	{ Id = "dragon_scale", Name = "Vasto Lorde Mask Fragment", Category = "Valuable", SellPrice = 8000,
		Description = "Shed by something enormous. Still warm." },
	{ Id = "imperial_seal", Name = "Counterfeit Gotei Seal", Category = "Valuable", SellPrice = 900,
		Description = "Very convincing. Do not show it to the Onmitsukido." },
	{ Id = "star_iron", Name = "Sekkiseki Shard", Category = "Valuable", SellPrice = 3000,
		Description = "Spirit-blocking stone. It drinks reiatsu." },
	{ Id = "wolf_pelt", Name = "Hollow Hide", Category = "Material", SellPrice = 30, Description = "Tough, pale and slightly sticky." },
	{ Id = "serpent_fang", Name = "Serpent Hollow Fang", Category = "Material", SellPrice = 45, Description = "Still drips a little venom." },
	{ Id = "spirit_herb", Name = "Spirit Herb", Category = "Material", SellPrice = 35, Description = "Glows faintly at night. The Fourth Division loves it." },
	{ Id = "beast_core", Name = "Hollow Core", Category = "Material", SellPrice = 90, Description = "A crystallised knot of reiatsu from a slain Hollow." },
	{ Id = "ghost_lantern_wick", Name = "Ghost Lantern Wick", Category = "Material", SellPrice = 70, Description = "Burns blue and never runs out." },
	{ Id = "ancestral_bracer", Name = "Ancestral Gauntlet", Category = "Equipment", SellPrice = 400,
		Description = "-10% damage taken, +20 max health.", Equip = { Slot = "Armor", Buffs = { DamageTakenMult = 0.9, MaxHealthBonus = 20 } } },
	{ Id = "fox_tail_charm", Name = "Black Cat Charm", Category = "Equipment", SellPrice = 350,
		Description = "+15% affection gains.", Equip = { Slot = "Accessory", Buffs = { RelationshipMult = 1.15 } } },
	{ Id = "thunder_talisman", Name = "Lightning Kido Talisman", Category = "Equipment", SellPrice = 500,
		Description = "+12% Kido damage.", Equip = { Slot = "Accessory", Buffs = { MagicDamageMult = 1.12 } } },
	{ Id = "jade_dew", Name = "Reiokyu Dew", Category = "Consumable", SellPrice = 120,
		Description = "+3 years of life (1 per year, 5 per life).", Use = { Effects = { Lifespan = 3 }, UsesPerYear = 1, MaxPerLife = 5 } },
	{ Id = "dream_incense", Name = "Inner World Incense", Category = "Consumable", SellPrice = 80,
		Description = "-20 stress, +5 Reiatsu Control XP.", Use = { Effects = { Stress = -20, Stats = { QiControl = 5 } } } },
	{ Id = "fortune_cookie", Name = "Fortune Cookie", Category = "Consumable", SellPrice = 10,
		Description = "+10 Luck XP. The message says: \"Soon.\"", Use = { Effects = { Stats = { Luck = 10 } } } },
	-- Soul Path only (2026-11-02): 8 more items.
	{ Id = "mod_candy_pack", Name = "Mod Soul Candy Pack", Category = "Consumable", Price = 200, MinAge = 10,
		Description = "+15 Agility XP, +3 happiness.", Use = { Effects = { Stats = { Agility = 15 }, Happiness = 3 } } },
	{ Id = "gigai_tuneup", Name = "Gigai Tune-up", Category = "Consumable", Price = 900, MinAge = 16,
		Description = "Restores 50 health, -5 stress.", Use = { Effects = { Health = 50, Stress = -5 } } },
	{ Id = "hell_butterfly_jar", Name = "Hell Butterfly Jar", Category = "Equipment", Price = 1400,
		Description = "+10% affection gains, +10% Hogyoku Shards.", Equip = { Slot = "Accessory", Buffs = { RelationshipMult = 1.1, KarmaMult = 1.1 } } },
	{ Id = "blank_asauchi", Name = "Blank Asauchi", Category = "Equipment", Price = 2000, Requires = { Proficiency = { Sword = 10 } },
		Description = "+35% Zanjutsu XP.", Equip = { Slot = "Weapon", Buffs = { ProficiencyXp = { Sword = 1.35 } } } },
	{ Id = "reishi_glove", Name = "Reishi Training Glove", Category = "Equipment", Price = 2600, MinAge = 14,
		Description = "+20% Agility XP, +5% Kido damage.", Equip = { Slot = "Accessory", Buffs = { StatXp = { Agility = 1.2 }, MagicDamageMult = 1.05 } } },
	{ Id = "badge_replica", Name = "Substitute Badge Replica", Category = "Valuable", SellPrice = 600,
		Description = "A very convincing fake. Collectors in Naruki love them." },
	{ Id = "hogyoku_dust", Name = "Hogyoku Dust", Category = "Valuable", SellPrice = 5000,
		Description = "A pinch of glittering dust that wants something from you." },
	{ Id = "menos_mask_shard", Name = "Menos Mask Shard", Category = "Material", SellPrice = 150, Description = "Bone-white and still faintly warm." },
}

-- Market stock, in display order (items without a Price are never stocked).
ItemsConfig.Shop = {
	"healing_salve", "calming_tea", "energy_ginseng", "strategy_book", "spirit_pill", "foundation_pill", "longevity_peach",
	"wooden_sword", "iron_sword", "jade_spear", "padded_robe", "sect_battle_robe", "jade_pendant", "lucky_charm",
	"rice_wine", "herbal_poultice", "tiger_bone_tonic", "wind_step_manual", "etiquette_scroll", "meridian_needles", "marrow_cleansing_pill",
	"steel_saber", "scholar_fan", "spirit_staff", "leather_vest", "silk_court_robe", "merchant_abacus", "monk_prayer_beads",
	"mod_candy_pack", "gigai_tuneup", "hell_butterfly_jar", "blank_asauchi", "reishi_glove",
}

ItemsConfig.ById = {}
for _, item in ItemsConfig.Items do
	ItemsConfig.ById[item.Id] = item
end

function ItemsConfig.MaxStack(item): number
	return item.MaxStack or (if item.Equip then 1 else ItemsConfig.DefaultMaxStack)
end

function ItemsConfig.SellPrice(item): number?
	if item.SellPrice then
		return item.SellPrice
	end
	return if item.Price then math.floor(item.Price / 2) else nil
end

return ItemsConfig
