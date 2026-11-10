-- Modern Life: keeps the generic items, drops cultivation and wuxia gear, adds modern ones.
local Content = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Content"))

local REMOVED = {
	energy_ginseng = true, strategy_book = true, spirit_pill = true, foundation_pill = true, longevity_peach = true,
	wooden_sword = true, iron_sword = true, jade_spear = true, padded_robe = true, sect_battle_robe = true,
	jade_pendant = true, ancient_talisman = true,
}

return Content.Extend("ItemsConfig", script.Parent, function(items)
	items.Slots.Weapon.Name = "Gear"
	items.Slots.Armor.Name = "Outfit"
	items.Slots.Accessory.Name = "Gadget"

	local list = {}
	for _, item in items.Items do
		if not REMOVED[item.Id] then
			table.insert(list, item)
		end
	end
	for _, item in list do
		if item.Id == "healing_salve" then
			item.Name, item.Description = "First Aid Kit", "Restores 30 health."
		elseif item.Id == "calming_tea" then
			item.Name = "Herbal Tea"
		end
	end
	local added = {
		{ Id = "energy_drink", Name = "Energy Drink", Category = "Consumable", Price = 30, MinAge = 12,
			Description = "+1 action this year, +2 stress (once a year).", Use = { Effects = { Actions = 1, Stress = 2 }, UsesPerYear = 1 } },
		{ Id = "textbook", Name = "Textbook", Category = "Consumable", Price = 250, MinAge = 8,
			Description = "+25 INT XP and +2 knowledge.", Use = { Effects = { Stats = { Intelligence = 25 }, Counters = { Knowledge = 2 } } } },
		{ Id = "running_shoes", Name = "Running Shoes", Category = "Equipment", Price = 200, MinAge = 8,
			Description = "+15% AGI XP, +5% VIT XP.", Equip = { Slot = "Weapon", Buffs = { StatXp = { Agility = 1.15, Vitality = 1.05 } } } },
		{ Id = "fencing_foil", Name = "Fencing Foil", Category = "Equipment", Price = 600, Requires = { Proficiency = { Sword = 5 } },
			Description = "+30% Fencing XP.", Equip = { Slot = "Weapon", Buffs = { ProficiencyXp = { Sword = 1.3 } } } },
		{ Id = "designer_suit", Name = "Designer Suit", Category = "Equipment", Price = 2500, MinAge = 18,
			Description = "+10% salary, +3% social success.", Equip = { Slot = "Armor", Buffs = { SalaryMult = 1.1, SocialBonus = 0.03 } } },
		{ Id = "smartphone", Name = "Smartphone", Category = "Equipment", Price = 800, MinAge = 10,
			Description = "+10% CHA XP, +5% social success.", Equip = { Slot = "Accessory", Buffs = { StatXp = { Charisma = 1.1 }, SocialBonus = 0.05 } } },
		{ Id = "laptop", Name = "Laptop", Category = "Equipment", Price = 1500, MinAge = 10,
			Description = "+20% INT XP, +10% Focus XP, +10% study.", Equip = { Slot = "Accessory", Buffs = { StatXp = { Intelligence = 1.2, QiControl = 1.1 }, StudyMult = 1.1 } } },
	}
	for _, item in added do
		table.insert(list, item)
	end

	items.Items = list
	items.ById = {}
	for _, item in list do
		items.ById[item.Id] = item
	end
	items.Shop = { "healing_salve", "calming_tea", "energy_drink", "textbook", "running_shoes", "fencing_foil", "designer_suit", "smartphone", "laptop", "lucky_charm" }
end)
