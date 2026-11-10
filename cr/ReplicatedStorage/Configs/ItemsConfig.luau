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
}

ItemsConfig.SlotOrder = { "Weapon", "Armor", "Accessory" }
ItemsConfig.Slots = {
	Weapon = { Name = "Cursed Tool" },
	Armor = { Name = "Uniform" },
	Accessory = { Name = "Charm" },
}

ItemsConfig.Items = {
	-- Consumables
	{ Id = "healing_salve", Name = "Healing Ofuda", Category = "Consumable", Price = 120,
		Description = "Restores 30 health.", Use = { Effects = { Health = 30 } } },
	{ Id = "calming_tea", Name = "Shrine Incense", Category = "Consumable", Price = 60,
		Description = "-15 stress, +3 happiness.", Use = { Effects = { Stress = -15, Happiness = 3 } } },
	{ Id = "energy_ginseng", Name = "Cursed Energy Tonic", Category = "Consumable", Price = 400, MinAge = 10,
		Description = "+1 action this year (once a year).", Use = { Effects = { Actions = 1 }, UsesPerYear = 1 } },
	{ Id = "strategy_book", Name = "Jujutsu Technique Scroll", Category = "Consumable", Price = 300, MinAge = 8,
		Description = "+25 INT XP and +2 knowledge.", Use = { Effects = { Stats = { Intelligence = 25 }, Counters = { Knowledge = 2 } } } },
	{ Id = "spirit_pill", Name = "Cursed Womb Draught", Category = "Consumable", Price = 800, MinAge = 10, Module = "Cultivation",
		Description = "Half a stage of cursed energy (2 per year).", Use = { Effects = { Qi = 0.5 }, UsesPerYear = 2 } },
	{ Id = "foundation_pill", Name = "Grade Promotion Elixir", Category = "Consumable", Price = 6000, Module = "Cultivation",
		Requires = { MinRealm = 2 },
		Description = "Two stages of cursed energy and +10 CE XP (1 per year).", Use = { Effects = { Qi = 2, Stats = { QiControl = 10 } }, UsesPerYear = 1 } },
	{ Id = "longevity_peach", Name = "Reverse Cursed Longevity Elixir", Category = "Consumable", Price = 15000, MinAge = 30,
		Description = "+5 years of life (1 per year, 6 per life).", Use = { Effects = { Lifespan = 5 }, UsesPerYear = 1, MaxPerLife = 6 } },

	-- Equipment
	{ Id = "wooden_sword", Name = "Training Cursed Bokken", Category = "Equipment", Price = 150, MinAge = 8,
		Description = "+15% Cursed Tools XP.", Equip = { Slot = "Weapon", Buffs = { ProficiencyXp = { Sword = 1.15 } } } },
	{ Id = "iron_sword", Name = "Slaughter Demon Blade", Category = "Equipment", Price = 1200, Requires = { Proficiency = { Sword = 5 } },
		Description = "+30% Cursed Tools XP, +5% AGI XP.", Equip = { Slot = "Weapon", Buffs = { ProficiencyXp = { Sword = 1.3 }, StatXp = { Agility = 1.05 } } } },
	{ Id = "jade_spear", Name = "Playful Three-Section Cloud", Category = "Equipment", Price = 2500, Requires = { Proficiency = { Spear = 10 } },
		Description = "+40% Taijutsu XP, +10% STR XP.", Equip = { Slot = "Weapon", Buffs = { ProficiencyXp = { Spear = 1.4 }, StatXp = { Strength = 1.1 } } } },
	{ Id = "padded_robe", Name = "Jujutsu High Uniform", Category = "Equipment", Price = 400,
		Description = "+20 max health.", Equip = { Slot = "Armor", Buffs = { MaxHealthBonus = 20 } } },
	{ Id = "sect_battle_robe", Name = "Warded Faction Coat", Category = "Equipment", Price = 3500, Module = "Masters",
		Requires = { HasMaster = true },
		Description = "+60 max health, +2% Grade Promotion.", Equip = { Slot = "Armor", Buffs = { MaxHealthBonus = 60, BreakthroughBonus = 0.02 } } },
	{ Id = "jade_pendant", Name = "Seer's Cursed Spectacles", Category = "Equipment", Price = 1800,
		Description = "+20% INT XP, +10% study.", Equip = { Slot = "Accessory", Buffs = { StatXp = { Intelligence = 1.2 }, StudyMult = 1.1 } } },
	{ Id = "lucky_charm", Name = "Protective Omamori", Category = "Equipment", Price = 500,
		Description = "+5% social success.", Equip = { Slot = "Accessory", Buffs = { SocialBonus = 0.05 } } },

	-- Valuables (found through events, sold at the market)
	{ Id = "ancient_talisman", Name = "Prison Realm Fragment", Category = "Valuable", SellPrice = 4000,
		Description = "A shard of the living barrier that seals anything. Collectors pay well." },
	{ Id = "jade_bracelet", Name = "Sealed Calamity Finger", Category = "Valuable", SellPrice = 1500,
		Description = "A mummified finger wrapped in seals, passed down in secret." },

	-- Special Grade cursed tools: not sold at the market; found or inherited (events,
	-- heirlooms). Consecrated ones pass down the family as Ancestral Cursed Tools.
	{ Id = "split_soul_katana", Name = "Split-Soul Katana", Category = "Equipment",
		Description = "Cuts the soul, not the flesh. +45% Cursed Tools XP, +10% AGI XP.",
		Equip = { Slot = "Weapon", Buffs = { ProficiencyXp = { Sword = 1.45 }, StatXp = { Agility = 1.1 } } } },
	{ Id = "inverted_spear", Name = "Inverted Spear of Heaven", Category = "Equipment",
		Description = "Nullifies techniques it touches. +40% Cursed Tools XP, +4% Grade Promotion.",
		Equip = { Slot = "Weapon", Buffs = { ProficiencyXp = { Sword = 1.4 }, BreakthroughBonus = 0.04 } } },
	{ Id = "festering_life_blade", Name = "Festering Life Blade", Category = "Equipment",
		Description = "A jagged blade that rots what it cuts. +35% Cursed Tools XP, +10% STR XP.",
		Equip = { Slot = "Weapon", Buffs = { ProficiencyXp = { Sword = 1.35 }, StatXp = { Strength = 1.1 } } } },
	{ Id = "chain_thousand_miles", Name = "Chain of a Thousand Miles", Category = "Equipment",
		Description = "An endless chain with no tip. +35% Taijutsu XP, +10% AGI XP.",
		Equip = { Slot = "Weapon", Buffs = { ProficiencyXp = { Spear = 1.35 }, StatXp = { Agility = 1.1 } } } },
	{ Id = "black_rope", Name = "Black Rope", Category = "Equipment",
		Description = "Unravels cursed techniques. +40 max health, +15% Barrier & Domain Arts XP.",
		Equip = { Slot = "Accessory", Buffs = { MaxHealthBonus = 40, ProficiencyXp = { QiArts = 1.15 } } } },
	-- Content expansion (2026-11-02): 21 more items.
	{ Id = "konbini_onigiri", Name = "Convenience Store Onigiri", Category = "Consumable", Price = 30,
		Description = "Restores 10 health, +2 happiness.", Use = { Effects = { Health = 10, Happiness = 2 } } },
	{ Id = "energy_drink", Name = "Late-Night Energy Drink", Category = "Consumable", Price = 150, MinAge = 12,
		Description = "+12 AGI XP, +4 stress.", Use = { Effects = { Stats = { Agility = 12 }, Stress = 4 } } },
	{ Id = "kikufuku_box", Name = "Box of Kikufuku Sweets", Category = "Consumable", Price = 200,
		Description = "+8 happiness, -6 stress, +5 INT XP.", Use = { Effects = { Happiness = 8, Stress = -6, Stats = { Intelligence = 5 } } } },
	{ Id = "taijutsu_manual", Name = "Taijutsu Drill Manual", Category = "Consumable", Price = 350, MinAge = 8,
		Description = "+15 Taijutsu XP, +5 STR XP.", Use = { Effects = { Proficiency = { Spear = 15 }, Stats = { Strength = 5 } } } },
	{ Id = "curtain_primer", Name = "Curtain Chant Primer", Category = "Consumable", Price = 450, MinAge = 10,
		Description = "+12 Barrier & Domain Arts XP, +1 knowledge.", Use = { Effects = { Proficiency = { QiArts = 12 }, Counters = { Knowledge = 1 } } } },
	{ Id = "straw_doll_kit", Name = "Straw Doll & Nails Kit", Category = "Consumable", Price = 500, MinAge = 12,
		Description = "+15 Barrier & Domain Arts XP, +5 CE XP.", Use = { Effects = { Proficiency = { QiArts = 15 }, Stats = { QiControl = 5 } } } },
	{ Id = "reverse_salve", Name = "Reverse Cursed Salve", Category = "Consumable", Price = 900, MinAge = 12,
		Description = "Restores 60 health (2 per year).", Use = { Effects = { Health = 60 }, UsesPerYear = 2 } },
	{ Id = "curse_core_candy", Name = "Low-Grade Curse Core", Category = "Consumable", Price = 700, MinAge = 12, Module = "Cultivation",
		Description = "A quarter stage of cursed energy (1 per year, 5 per life).", Use = { Effects = { Qi = 0.25 }, UsesPerYear = 1, MaxPerLife = 5 } },
	{ Id = "oath_paper", Name = "Oath Paper", Category = "Consumable", Price = 2500, MinAge = 16,
		Description = "Write a small vow: +10 CHA XP, +3 alignment (1 per year).", Use = { Effects = { Stats = { Charisma = 10 }, Alignment = 3 }, UsesPerYear = 1 } },
	{ Id = "cursed_bat", Name = "Cursed Baseball Bat", Category = "Equipment", Price = 300, MinAge = 10,
		Description = "+15% Taijutsu XP, +5% STR XP.", Equip = { Slot = "Weapon", Buffs = { ProficiencyXp = { Spear = 1.15 }, StatXp = { Strength = 1.05 } } } },
	{ Id = "cursed_knuckles", Name = "Cursed Knuckle Dusters", Category = "Equipment", Price = 1500, Requires = { Proficiency = { Spear = 8 } },
		Description = "+30% Taijutsu XP, +10% STR XP.", Equip = { Slot = "Weapon", Buffs = { ProficiencyXp = { Spear = 1.3 }, StatXp = { Strength = 1.1 } } } },
	{ Id = "talisman_tanto", Name = "Talisman-Wrapped Tanto", Category = "Equipment", Price = 1800, Requires = { Proficiency = { Sword = 8 } },
		Description = "+25% Cursed Tools XP, +10% Barrier & Domain Arts XP.", Equip = { Slot = "Weapon", Buffs = { ProficiencyXp = { Sword = 1.25, QiArts = 1.1 } } } },
	{ Id = "auxiliary_suit", Name = "Auxiliary Manager's Suit", Category = "Equipment", Price = 900,
		Description = "+25 max health, +10% salary.", Equip = { Slot = "Armor", Buffs = { MaxHealthBonus = 25, SalaryMult = 1.1 } } },
	{ Id = "curtain_coat", Name = "Curtain-Weave Coat", Category = "Equipment", Price = 2800, MinAge = 14,
		Description = "+45 max health, +10% Barrier & Domain Arts XP.", Equip = { Slot = "Armor", Buffs = { MaxHealthBonus = 45, ProficiencyXp = { QiArts = 1.1 } } } },
	{ Id = "training_blindfold", Name = "Training Blindfold", Category = "Equipment", Price = 1200,
		Description = "+15% CE XP, +5% INT XP.", Equip = { Slot = "Accessory", Buffs = { StatXp = { QiControl = 1.15, Intelligence = 1.05 } } } },
	{ Id = "phone_charm", Name = "Cursed Phone Charm", Category = "Equipment", Price = 700,
		Description = "+10% affection gains, +3% social success.", Equip = { Slot = "Accessory", Buffs = { RelationshipMult = 1.1, SocialBonus = 0.03 } } },
	{ Id = "curse_residue", Name = "Curse Residue Vial", Category = "Valuable", SellPrice = 300,
		Description = "Black sludge left behind by an exorcised curse. Researchers buy it." },
	{ Id = "broken_cursed_tool", Name = "Broken Cursed Tool", Category = "Valuable", SellPrice = 900,
		Description = "Half a blade that still remembers how to cut curses." },
	{ Id = "womb_shell", Name = "Hatched Cursed Womb Shell", Category = "Valuable", SellPrice = 2500,
		Description = "The empty husk of a cursed womb. Headquarters pays for every one." },
	{ Id = "dragon_bone_blade", Name = "Dragon-Bone Greatsword", Category = "Equipment",
		Description = "Stores the force of every blow it takes. +40% Cursed Tools XP, +30 max health.",
		Equip = { Slot = "Weapon", Buffs = { ProficiencyXp = { Sword = 1.4 }, MaxHealthBonus = 30 } } },
	{ Id = "sealing_beads", Name = "Sealing Prayer Beads", Category = "Equipment",
		Description = "Beads from the thousand-year barrier. +25% Barrier & Domain Arts XP, +20 max health.",
		Equip = { Slot = "Accessory", Buffs = { ProficiencyXp = { QiArts = 1.25 }, MaxHealthBonus = 20 } } },
}

-- Market stock, in display order (items without a Price are never stocked).
ItemsConfig.Shop = {
	"healing_salve", "calming_tea", "energy_ginseng", "strategy_book", "spirit_pill", "foundation_pill", "longevity_peach",
	"wooden_sword", "iron_sword", "jade_spear", "padded_robe", "sect_battle_robe", "jade_pendant", "lucky_charm",
	"konbini_onigiri", "energy_drink", "kikufuku_box", "taijutsu_manual", "curtain_primer", "straw_doll_kit", "reverse_salve",
	"curse_core_candy", "oath_paper", "cursed_bat", "cursed_knuckles", "talisman_tanto", "auxiliary_suit", "curtain_coat",
	"training_blindfold", "phone_charm",
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
