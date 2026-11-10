--[[
	Mastery trees. Every attribute level-up grants 1 mastery point (major realm
	breakthroughs grant 2). Nodes in a branch unlock in order.
]]

local MasteriesConfig = {}

MasteriesConfig.PointsPerStatLevel = 1
MasteriesConfig.PointsPerMajorBreakthrough = 2

MasteriesConfig.Branches = {
	{
		Id = "Intellect", Name = "Intellect", Color = Color3.fromRGB(110, 180, 255),
		Nodes = {
			{ Id = "int_speed_reading", Name = "Speed Reading", Cost = 3, Description = "+20% Intelligence XP.", Buffs = { StatXp = { Intelligence = 1.2 } } },
			{ Id = "int_focus", Name = "Scholar's Focus", Cost = 6, Description = "+25% study performance.", Buffs = { StudyMult = 1.25 } },
			{ Id = "int_eidetic", Name = "Eidetic Memory", Cost = 10, Description = "+1 knowledge per reading, +20% INT XP.", Buffs = { KnowledgeBonus = 1, StatXp = { Intelligence = 1.2 } } },
			{ Id = "int_insight", Name = "Sage's Insight", Cost = 16, Description = "+8% breakthrough chance.", Buffs = { BreakthroughBonus = 0.08 } },
			-- Content expansion (2026-11-02): four deeper nodes per branch.
			{ Id = "int_strategist", Name = "Strategist", Cost = 30, Description = "+15% battle rewards, +15% magic damage.", Buffs = { BattleRewardMult = 1.15, MagicDamageMult = 1.15 } },
			{ Id = "int_polymath", Name = "Polymath", Cost = 45, Description = "+20% skill XP.", Buffs = { SkillXpMult = 1.2 } },
			{ Id = "int_mind_palace", Name = "Mind Palace", Cost = 65, Description = "+40% study, +2 knowledge per reading.", Buffs = { StudyMult = 1.4, KnowledgeBonus = 2 } },
			{ Id = "int_enlightenment", Name = "Enlightenment", Cost = 90, Description = "+5% breakthrough, +10% all attribute XP.", Buffs = { BreakthroughBonus = 0.05, AllStatXp = 1.1 } },
		},
	},
	{
		Id = "Physical", Name = "Physical", Color = Color3.fromRGB(240, 120, 100),
		Nodes = {
			{ Id = "phy_conditioning", Name = "Conditioning", Cost = 3, Description = "+20% Strength & Agility XP.", Buffs = { StatXp = { Strength = 1.2, Agility = 1.2 } } },
			{ Id = "phy_iron_skin", Name = "Iron Skin", Cost = 6, Description = "+50 max health.", Buffs = { MaxHealthBonus = 50 } },
			{ Id = "phy_second_wind", Name = "Second Wind", Cost = 10, Description = "+1 action per year.", Buffs = { ActionSlots = 1 } },
			{ Id = "phy_peak_body", Name = "Peak Body", Cost = 16, Description = "+15 years, +25% Vitality XP.", Buffs = { LifespanBonus = 15, StatXp = { Vitality = 1.25 } } },
			{ Id = "phy_battle_hardened", Name = "Battle-Hardened", Cost = 30, Description = "-10% damage taken, +10% sword damage.", Buffs = { DamageTakenMult = 0.9, SwordDamageMult = 1.1 } },
			{ Id = "phy_iron_marrow", Name = "Iron Marrow", Cost = 45, Description = "+100 max health.", Buffs = { MaxHealthBonus = 100 } },
			{ Id = "phy_wind_runner", Name = "Wind Runner", Cost = 65, Description = "Much easier escapes, +30% Agility XP.", Buffs = { FleeBonus = 0.2, StatXp = { Agility = 1.3 } } },
			{ Id = "phy_diamond_body", Name = "Diamond Body", Cost = 90, Description = "+10 years, -15% damage taken.", Buffs = { LifespanBonus = 10, DamageTakenMult = 0.85 } },
		},
	},
	{
		Id = "Social", Name = "Social", Color = Color3.fromRGB(240, 130, 210),
		Nodes = {
			{ Id = "soc_small_talk", Name = "Small Talk", Cost = 3, Description = "+20% Charisma XP.", Buffs = { StatXp = { Charisma = 1.2 } } },
			{ Id = "soc_networking", Name = "Networking", Cost = 6, Description = "+25% affection gains.", Buffs = { RelationshipMult = 1.25 } },
			{ Id = "soc_silver_words", Name = "Silver Words", Cost = 10, Description = "+10% social success.", Buffs = { SocialBonus = 0.1 } },
			{ Id = "soc_influencer", Name = "Influencer", Cost = 16, Description = "+25% salary, +3 happiness/year.", Buffs = { SalaryMult = 1.25, HappinessPerYear = 3 } },
			{ Id = "soc_patron", Name = "Patron", Cost = 30, Description = "+15% gold.", Buffs = { GoldMult = 1.15 } },
			{ Id = "soc_peacemaker", Name = "Peacemaker", Cost = 45, Description = "-2 stress/year, +15% Karma.", Buffs = { StressPerYear = -2, KarmaMult = 1.15 } },
			{ Id = "soc_legend", Name = "Living Legend", Cost = 65, Description = "+15% social success, +30% affection.", Buffs = { SocialBonus = 0.15, RelationshipMult = 1.3 } },
			{ Id = "soc_dynasty", Name = "Dynasty Founder", Cost = 90, Description = "+40% salary, +5 happiness/year.", Buffs = { SalaryMult = 1.4, HappinessPerYear = 5 } },
		},
	},
	{
		Id = "Artifacts", Name = "Artifacts", Color = Color3.fromRGB(190, 140, 255),
		Nodes = {
			{ Id = "art_stone_sense", Name = "Spirit Stone Sense", Cost = 3, Description = "+20% Qi gain.", Buffs = { QiMult = 1.2 } },
			{ Id = "art_talismans", Name = "Talisman Crafting", Cost = 6, Description = "+5% breakthrough chance.", Buffs = { BreakthroughBonus = 0.05 } },
			{ Id = "art_attunement", Name = "Weapon Attunement", Cost = 10, Description = "+30% proficiency XP (all).", Buffs = { ProficiencyXp = { Sword = 1.3, Spear = 1.3, QiArts = 1.3 } } },
			{ Id = "art_refining", Name = "Artifact Refining", Cost = 16, Description = "x1.5 passive Qi.", Buffs = { PassiveQiMult = 1.5 } },
			{ Id = "art_rune_carving", Name = "Rune Carving", Cost = 30, Description = "-15% mana costs.", Buffs = { ManaCostMult = 0.85 } },
			{ Id = "art_spirit_weapon", Name = "Spirit Weapon", Cost = 45, Description = "+15% sword damage, +40% proficiency XP.", Buffs = { SwordDamageMult = 1.15, ProficiencyXp = { Sword = 1.4, Spear = 1.4, QiArts = 1.4 } } },
			{ Id = "art_qi_furnace", Name = "Qi Furnace", Cost = 65, Description = "+15% Qi gain.", Buffs = { QiMult = 1.15 } },
			{ Id = "art_heaven_artifact", Name = "Heavenly Artifact", Cost = 90, Description = "x1.2 passive Qi, +3% breakthrough.", Buffs = { PassiveQiMult = 1.2, BreakthroughBonus = 0.03 } },
		},
	},
}

MasteriesConfig.NodesById = {}
for _, branch in MasteriesConfig.Branches do
	for index, node in branch.Nodes do
		node.Branch = branch.Id
		node.Index = index
		node.Previous = if index > 1 then branch.Nodes[index - 1].Id else nil
		MasteriesConfig.NodesById[node.Id] = node
	end
end

return MasteriesConfig
