-- Academy: Quirk-flavored talents; rarities and rolling come from the base module.
local Content = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Content"))

return Content.Extend("TalentsConfig", script.Parent, function(talents)
	talents.List = {
		{ Id = "iron_bones", Name = "Iron Bones", Rarity = "Common", Description = "+25 max health.", Buffs = { MaxHealthBonus = 25 } },
		{ Id = "boundless_energy", Name = "Boundless Vigor", Rarity = "Rare", Description = "+1 action every year.", Buffs = { ActionSlots = 1 } },
		{ Id = "strategist", Name = "Born Strategist", Rarity = "Common", Description = "+15% Intellect XP.", Buffs = { StatXp = { Intellect = 1.15 } } },
		{ Id = "crowd_favorite", Name = "Crowd Favorite", Rarity = "Rare", Description = "+40% Charm XP, +5% social success.", Buffs = { StatXp = { Charm = 1.4 }, SocialBonus = 0.05 } },
		{ Id = "emitter_type", Name = "Emitter Type", Rarity = "Rare", Description = "+50% Power XP.", Buffs = { StatXp = { Power = 1.5 } } },
		{ Id = "dual_quirk", Name = "Dual Quirk", Rarity = "Epic", Description = "+30% all attribute XP.", Buffs = { AllStatXp = 1.3 } },
		{ Id = "symbol_of_peace", Name = "Symbol of Peace", Rarity = "Mythic", Description = "+60% all XP, +100 max health.", Buffs = { AllStatXp = 1.6, MaxHealthBonus = 100 } },
	}
	talents.ById = {}
	for _, talent in talents.List do
		talents.ById[talent.Id] = talent
	end
end)
