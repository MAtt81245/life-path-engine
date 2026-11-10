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
	Weapon = { Name = "Weapon" },
	Armor = { Name = "Robe" },
	Accessory = { Name = "Talisman" },
}

ItemsConfig.Items = {
	-- Consumables
	{ Id = "healing_salve", Name = "Healing Salve", Category = "Consumable", Price = 120,
		Description = "Restores 30 health.", Use = { Effects = { Health = 30 } } },
	{ Id = "calming_tea", Name = "Calming Tea", Category = "Consumable", Price = 60,
		Description = "-15 stress, +3 happiness.", Use = { Effects = { Stress = -15, Happiness = 3 } } },
	{ Id = "energy_ginseng", Name = "Spirit Ginseng", Category = "Consumable", Price = 400, MinAge = 10,
		Description = "+1 action this year (once a year).", Use = { Effects = { Actions = 1 }, UsesPerYear = 1 } },
	{ Id = "strategy_book", Name = "Book of Strategy", Category = "Consumable", Price = 300, MinAge = 8,
		Description = "+25 INT XP and +2 knowledge.", Use = { Effects = { Stats = { Intelligence = 25 }, Counters = { Knowledge = 2 } } } },
	{ Id = "spirit_pill", Name = "Spirit Gathering Pill", Category = "Consumable", Price = 800, MinAge = 10, Module = "Cultivation",
		Description = "Half a level of Qi (2 per year).", Use = { Effects = { Qi = 0.5 }, UsesPerYear = 2 } },
	{ Id = "foundation_pill", Name = "Foundation Pill", Category = "Consumable", Price = 6000, Module = "Cultivation",
		Requires = { MinRealm = 2 },
		Description = "Two levels of Qi and +10 QI XP (1 per year).", Use = { Effects = { Qi = 2, Stats = { QiControl = 10 } }, UsesPerYear = 1 } },
	{ Id = "longevity_peach", Name = "Longevity Peach", Category = "Consumable", Price = 15000, MinAge = 30,
		Description = "+5 years of life (1 per year, 6 per life).", Use = { Effects = { Lifespan = 5 }, UsesPerYear = 1, MaxPerLife = 6 } },

	-- Equipment
	{ Id = "wooden_sword", Name = "Wooden Sword", Category = "Equipment", Price = 150, MinAge = 8,
		Description = "+15% Sword XP.", Equip = { Slot = "Weapon", Buffs = { ProficiencyXp = { Sword = 1.15 } } } },
	{ Id = "iron_sword", Name = "Iron Sword", Category = "Equipment", Price = 1200, Requires = { Proficiency = { Sword = 5 } },
		Description = "+30% Sword XP, +5% AGI XP.", Equip = { Slot = "Weapon", Buffs = { ProficiencyXp = { Sword = 1.3 }, StatXp = { Agility = 1.05 } } } },
	{ Id = "jade_spear", Name = "Jade Spear", Category = "Equipment", Price = 2500, Requires = { Proficiency = { Spear = 10 } },
		Description = "+40% Spear XP, +10% STR XP.", Equip = { Slot = "Weapon", Buffs = { ProficiencyXp = { Spear = 1.4 }, StatXp = { Strength = 1.1 } } } },
	{ Id = "padded_robe", Name = "Padded Robe", Category = "Equipment", Price = 400,
		Description = "+20 max health.", Equip = { Slot = "Armor", Buffs = { MaxHealthBonus = 20 } } },
	{ Id = "sect_battle_robe", Name = "Sect Battle Robe", Category = "Equipment", Price = 3500, Module = "Masters",
		Requires = { HasMaster = true },
		Description = "+60 max health, +2% breakthrough.", Equip = { Slot = "Armor", Buffs = { MaxHealthBonus = 60, BreakthroughBonus = 0.02 } } },
	{ Id = "jade_pendant", Name = "Scholar's Jade Pendant", Category = "Equipment", Price = 1800,
		Description = "+20% INT XP, +10% study.", Equip = { Slot = "Accessory", Buffs = { StatXp = { Intelligence = 1.2 }, StudyMult = 1.1 } } },
	{ Id = "lucky_charm", Name = "Lucky Charm", Category = "Equipment", Price = 500,
		Description = "+5% social success.", Equip = { Slot = "Accessory", Buffs = { SocialBonus = 0.05 } } },

	-- Valuables (found through events, sold at the market)
	{ Id = "ancient_talisman", Name = "Ancient Talisman", Category = "Valuable", SellPrice = 4000,
		Description = "Relic from an immortal's cave. Collectors pay well." },
	{ Id = "jade_bracelet", Name = "Jade Bracelet", Category = "Valuable", SellPrice = 1500,
		Description = "A family heirloom of fine green jade." },

	-- 3.0 World hub: monster materials (battle drops, bounties), crafted trinkets and the
	-- Traveling Merchant's rare goods (WorldHubConfig).
	{ Id = "boar_tusk", Name = "Boar Tusk", Category = "Material", SellPrice = 15, Description = "A curved tusk. Crafters want it." },
	{ Id = "spider_silk", Name = "Spider Silk", Category = "Material", SellPrice = 25, Description = "Strong as wire, light as breath." },
	{ Id = "rabbit_horn", Name = "Rabbit Horn", Category = "Material", SellPrice = 20, Description = "From a horned hare. Lucky, they say." },
	{ Id = "bounty_seal", Name = "Bounty Seal", Category = "Material", SellPrice = 60, Description = "Proof of a Wanted Poster fulfilled." },
	{ Id = "hunters_token", Name = "Hunter's Token", Category = "Equipment", SellPrice = 120,
		Description = "+10% battle rewards.", Equip = { Slot = "Accessory", Buffs = { BattleRewardMult = 1.1 } } },
	{ Id = "weavers_charm", Name = "Weaver's Charm", Category = "Equipment", SellPrice = 150,
		Description = "-8% mana costs.", Equip = { Slot = "Accessory", Buffs = { ManaCostMult = 0.92 } } },
	{ Id = "guardsmans_badge", Name = "Guardsman's Badge", Category = "Equipment", SellPrice = 180,
		Description = "-8% damage taken.", Equip = { Slot = "Armor", Buffs = { DamageTakenMult = 0.92 } } },
	{ Id = "survivors_totem", Name = "Survivor's Totem", Category = "Equipment", SellPrice = 140,
		Description = "+25 max health.", Equip = { Slot = "Accessory", Buffs = { MaxHealthBonus = 25 } } },
	{ Id = "magic_crystal", Name = "Magic Crystal", Category = "Consumable", SellPrice = 100,
		Description = "Shatter it to deepen your mana pool (+5 max mana).", Use = { Effects = { ManaBonus = 5 } } },
	{ Id = "focus_tonic", Name = "Focus Tonic", Category = "Consumable", SellPrice = 60,
		Description = "-15 stress, +10 Intelligence XP.", Use = { Effects = { Stress = -15, Stats = { Intelligence = 10 } } } },
	{ Id = "elixir_of_prodigy", Name = "Elixir of Prodigy", Category = "Consumable", SellPrice = 50,
		Description = "+15 Strength, Agility and Intelligence XP.", Use = { Effects = { Stats = { Strength = 15, Agility = 15, Intelligence = 15 } } } },
	{ Id = "vitality_draught", Name = "Vitality Draught", Category = "Consumable", SellPrice = 30,
		Description = "+40 health, -10 stress.", Use = { Effects = { Health = 40, Stress = -10 } } },
	{ Id = "travelers_compass", Name = "Traveler's Compass", Category = "Equipment", SellPrice = 200,
		Description = "+10% battle rewards, easier escapes.", Equip = { Slot = "Accessory", Buffs = { BattleRewardMult = 1.1, FleeBonus = 0.05 } } },

	-- Content expansion (2026-11-02): 29 more items (14 of them in the market).
	{ Id = "rice_wine", Name = "Rice Wine", Category = "Consumable", Price = 40, MinAge = 16,
		Description = "+6 happiness, -8 stress.", Use = { Effects = { Happiness = 6, Stress = -8 } } },
	{ Id = "herbal_poultice", Name = "Herbal Poultice", Category = "Consumable", Price = 250,
		Description = "Restores 60 health.", Use = { Effects = { Health = 60 } } },
	{ Id = "tiger_bone_tonic", Name = "Tiger Bone Tonic", Category = "Consumable", Price = 500, MinAge = 12,
		Description = "+20 Strength and Vitality XP.", Use = { Effects = { Stats = { Strength = 20, Vitality = 20 } } } },
	{ Id = "wind_step_manual", Name = "Wind Step Manual", Category = "Consumable", Price = 450, MinAge = 10,
		Description = "+30 Agility XP.", Use = { Effects = { Stats = { Agility = 30 } } } },
	{ Id = "etiquette_scroll", Name = "Court Etiquette Scroll", Category = "Consumable", Price = 350, MinAge = 10,
		Description = "+25 Charisma XP.", Use = { Effects = { Stats = { Charisma = 25 } } } },
	{ Id = "meridian_needles", Name = "Meridian Needles", Category = "Consumable", Price = 1500, MinAge = 12, Module = "Cultivation",
		Description = "+20 Qi Control XP and a tenth of a level of Qi (1 per year).", Use = { Effects = { Qi = 0.1, Stats = { QiControl = 20 } }, UsesPerYear = 1 } },
	{ Id = "marrow_cleansing_pill", Name = "Marrow Cleansing Pill", Category = "Consumable", Price = 20000, Module = "Cultivation",
		Requires = { MinRealm = 3 },
		Description = "One level of Qi and +20 max health (1 per year, 4 per life).", Use = { Effects = { Qi = 1, MaxHealth = 20 }, UsesPerYear = 1, MaxPerLife = 4 } },
	{ Id = "steel_saber", Name = "Steel Saber", Category = "Equipment", Price = 3000, Requires = { Proficiency = { Sword = 15 } },
		Description = "+40% Sword XP, +5% sword damage.", Equip = { Slot = "Weapon", Buffs = { ProficiencyXp = { Sword = 1.4 }, SwordDamageMult = 1.05 } } },
	{ Id = "scholar_fan", Name = "Scholar's Iron Fan", Category = "Equipment", Price = 900, MinAge = 12,
		Description = "+15% INT and CHA XP.", Equip = { Slot = "Weapon", Buffs = { StatXp = { Intelligence = 1.15, Charisma = 1.15 } } } },
	{ Id = "spirit_staff", Name = "Spirit Staff", Category = "Equipment", Price = 2800, MinAge = 14,
		Description = "+10% magic damage, -5% mana costs.", Equip = { Slot = "Weapon", Buffs = { MagicDamageMult = 1.1, ManaCostMult = 0.95 } } },
	{ Id = "leather_vest", Name = "Hunter's Leather Vest", Category = "Equipment", Price = 900,
		Description = "+35 max health, easier escapes.", Equip = { Slot = "Armor", Buffs = { MaxHealthBonus = 35, FleeBonus = 0.05 } } },
	{ Id = "silk_court_robe", Name = "Silk Court Robe", Category = "Equipment", Price = 2200, MinAge = 16,
		Description = "+10% social success, +5% salary.", Equip = { Slot = "Armor", Buffs = { SocialBonus = 0.1, SalaryMult = 1.05 } } },
	{ Id = "merchant_abacus", Name = "Merchant's Abacus", Category = "Equipment", Price = 1600, MinAge = 14,
		Description = "+8% gold.", Equip = { Slot = "Accessory", Buffs = { GoldMult = 1.08 } } },
	{ Id = "monk_prayer_beads", Name = "Monk's Prayer Beads", Category = "Equipment", Price = 1200,
		Description = "+20% Karma earned, -1 stress per year.", Equip = { Slot = "Accessory", Buffs = { KarmaMult = 1.2, StressPerYear = -1 } } },
	{ Id = "black_pearl", Name = "Black Pearl", Category = "Valuable", SellPrice = 2500,
		Description = "Fished from the deepest part of the marsh." },
	{ Id = "dragon_scale", Name = "Dragon Scale", Category = "Valuable", SellPrice = 8000,
		Description = "Shed by something enormous. Still warm." },
	{ Id = "imperial_seal", Name = "Counterfeit Imperial Seal", Category = "Valuable", SellPrice = 900,
		Description = "Very convincing. Do not show it to a magistrate." },
	{ Id = "star_iron", Name = "Star Iron", Category = "Valuable", SellPrice = 3000,
		Description = "Black iron from a fallen star. It hums faintly." },
	{ Id = "wolf_pelt", Name = "Wolf Pelt", Category = "Material", SellPrice = 30, Description = "Thick grey fur. Warm in winter." },
	{ Id = "serpent_fang", Name = "Serpent Fang", Category = "Material", SellPrice = 45, Description = "Still drips a little venom." },
	{ Id = "spirit_herb", Name = "Spirit Herb", Category = "Material", SellPrice = 35, Description = "Glows faintly at night. Alchemists love it." },
	{ Id = "beast_core", Name = "Beast Core", Category = "Material", SellPrice = 90, Description = "A crystallised knot of Qi from a spirit beast." },
	{ Id = "ghost_lantern_wick", Name = "Ghost Lantern Wick", Category = "Material", SellPrice = 70, Description = "Burns blue and never runs out." },
	{ Id = "ancestral_bracer", Name = "Ancestral Bracer", Category = "Equipment", SellPrice = 400,
		Description = "-10% damage taken, +20 max health.", Equip = { Slot = "Armor", Buffs = { DamageTakenMult = 0.9, MaxHealthBonus = 20 } } },
	{ Id = "fox_tail_charm", Name = "Fox Tail Charm", Category = "Equipment", SellPrice = 350,
		Description = "+15% affection gains.", Equip = { Slot = "Accessory", Buffs = { RelationshipMult = 1.15 } } },
	{ Id = "thunder_talisman", Name = "Thunder Talisman", Category = "Equipment", SellPrice = 500,
		Description = "+12% magic damage.", Equip = { Slot = "Accessory", Buffs = { MagicDamageMult = 1.12 } } },
	{ Id = "jade_dew", Name = "Jade Dew", Category = "Consumable", SellPrice = 120,
		Description = "+3 years of life (1 per year, 5 per life).", Use = { Effects = { Lifespan = 3 }, UsesPerYear = 1, MaxPerLife = 5 } },
	{ Id = "dream_incense", Name = "Dream Incense", Category = "Consumable", SellPrice = 80,
		Description = "-20 stress, +5 Qi Control XP.", Use = { Effects = { Stress = -20, Stats = { QiControl = 5 } } } },
	{ Id = "fortune_cookie", Name = "Fortune Cookie", Category = "Consumable", SellPrice = 10,
		Description = "+10 Luck XP. The message says: \"Soon.\"", Use = { Effects = { Stats = { Luck = 10 } } } },
}

-- Market stock, in display order (items without a Price are never stocked).
ItemsConfig.Shop = {
	"healing_salve", "calming_tea", "energy_ginseng", "strategy_book", "spirit_pill", "foundation_pill", "longevity_peach",
	"wooden_sword", "iron_sword", "jade_spear", "padded_robe", "sect_battle_robe", "jade_pendant", "lucky_charm",
	"rice_wine", "herbal_poultice", "tiger_bone_tonic", "wind_step_manual", "etiquette_scroll", "meridian_needles", "marrow_cleansing_pill",
	"steel_saber", "scholar_fan", "spirit_staff", "leather_vest", "silk_court_robe", "merchant_abacus", "monk_prayer_beads",
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
