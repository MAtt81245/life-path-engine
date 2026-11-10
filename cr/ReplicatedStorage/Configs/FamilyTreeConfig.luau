--[[
	Dynasty & reincarnation tree (Lineage tab, Shared/LineageMemory, Modules/DynastySystem).
	Memory decay by GenerationsAgo (lives since that ancestor), shifted later by
	Ancestral Chronicler (+1 per rank) and Soul Retention (+0.5 per rank, floored):
		<= ClearGenerations   clear memory: portrait, stats, cause of death, rival, biography
		<= FadingGenerations  fading oral history: occupation / cause lost or rumored, dimmed
		beyond                forgotten: a weathered stone "An Unknown Ancestor of <Region>"
	Exceptions never fade: realm index >= ImmortalRealm (an Immortal Ancestor myth) or
	an ancestor who consecrated an Ancestral Heirloom (its inscription keeps the name).
	Heirlooms: +SoulStackPerGeneration all-XP per generation it has passed down;
	descendants inherit it at InheritAge.
]]

local FamilyTreeConfig = {}

FamilyTreeConfig.ClearGenerations = 2
FamilyTreeConfig.FadingGenerations = 4
FamilyTreeConfig.ImmortalRealm = 5 -- Grade 2 Sorcerer

FamilyTreeConfig.Heirloom = {
	Slots = { Weapon = true, Armor = true, Accessory = true },
	SoulStackPerGeneration = 0.05,
	InheritAge = 12,
	ReclaimMinAge = 14,
	BuyPrice = 1500, -- heirloom_reclaim "buy it back" option
}

-- Extended relatives appear only when met through an event (effect MeetRelative).
FamilyTreeConfig.Relatives = {
	Grandfather = { Name = "Grandfather", Above = 2 },
	Grandmother = { Name = "Grandmother", Above = 2 },
	Uncle = { Name = "Uncle", Above = 1 },
	Aunt = { Name = "Aunt", Above = 1 },
	Cousin = { Name = "Cousin", Above = 0 },
}

return FamilyTreeConfig
