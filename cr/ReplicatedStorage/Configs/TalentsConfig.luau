--[[
	Innate talents. Bought on the Wheel of Reincarnation with Karma and active
	for the whole next life. `Buffs` uses the shared buff keys (see PlayerState.GetBuffs).
]]

local TalentsConfig = {}

TalentsConfig.RarityOrder = { "Common", "Rare", "Epic", "Mythic" }

-- Talent spins on the Wheel of Reincarnation (Shared/Gacha); one spin fills one slot.
TalentsConfig.Spin = {
	Cost = 3,
	Slots = 2,
	RarityOrder = TalentsConfig.RarityOrder,
	Pity = {
		{ Rarity = "Epic", Every = 15 },
		{ Rarity = "Mythic", Every = 60 },
	},
}

-- Collection Codex: every race, talent, title and technique ever obtained adds a
-- small permanent bonus (BonusPerEntry to each listed multiplicative buff).
TalentsConfig.Codex = {
	BonusPerEntry = 0.01,
	Buffs = { "AllStatXp", "QiMult" },
}

TalentsConfig.Rarities = {
	Common = { Name = "Common", Weight = 60, Cost = 1, Color = Color3.fromRGB(190, 190, 205) },
	Rare = { Name = "Rare", Weight = 28, Cost = 6, Color = Color3.fromRGB(100, 180, 255) },
	Epic = { Name = "Epic", Weight = 10, Cost = 20, Color = Color3.fromRGB(190, 120, 255) },
	Mythic = { Name = "Mythic", Weight = 2, Cost = 60, Color = Color3.fromRGB(255, 190, 80) },
}

TalentsConfig.List = {
	-- Common
	{ Id = "iron_bones", Name = "Iron Bones", Rarity = "Common", Description = "+25 max health.", Buffs = { MaxHealthBonus = 25 } },
	{ Id = "quick_mind", Name = "Quick Mind", Rarity = "Common", Description = "+15% Intelligence XP.", Buffs = { StatXp = { Intelligence = 1.15 } } },
	{ Id = "long_breath", Name = "Long Breath", Rarity = "Common", Description = "+10 years of lifespan.", Buffs = { LifespanBonus = 10 } },
	{ Id = "lucky_star", Name = "Lucky Star", Rarity = "Common", Description = "+3% Grade Promotion chance.", Buffs = { BreakthroughBonus = 0.03 } },
	{ Id = "boundless_energy", Name = "Boundless Vigor", Rarity = "Rare", Description = "+1 action every year.", Buffs = { ActionSlots = 1 } },
	-- Rare
	{ Id = "fire_root", Name = "Flame Cursed Technique", Rarity = "Rare", Description = "+40% cursed energy gain.", Buffs = { QiMult = 1.4 } },
	{ Id = "jade_body", Name = "Reinforced Body", Rarity = "Rare", Description = "+60 max health and +15 years.", Buffs = { MaxHealthBonus = 60, LifespanBonus = 15 } },
	{ Id = "calm_heart", Name = "Calm Heart", Rarity = "Rare", Description = "+7% Grade Promotion, -2 stress per year.", Buffs = { BreakthroughBonus = 0.07, StressPerYear = -2 } },
	{ Id = "karmic_thread", Name = "Vow Keeper", Rarity = "Rare", Description = "+50% Binding Vows earned.", Buffs = { KarmaMult = 1.5 } },
	{ Id = "photographic_memory", Name = "Photographic Memory", Rarity = "Rare", Description = "+50% Intelligence XP.", Buffs = { StatXp = { Intelligence = 1.5 } } },
	{ Id = "silver_tongue", Name = "Silver Tongue", Rarity = "Rare", Description = "+50% Charisma XP, +5% social success.", Buffs = { StatXp = { Charisma = 1.5 }, SocialBonus = 0.05 } },
	-- Epic
	{ Id = "heavenly_root", Name = "Black Flash Prodigy", Rarity = "Epic", Description = "x2.2 cursed energy gain.", Buffs = { QiMult = 2.2 } },
	{ Id = "phoenix_blood", Name = "Reverse Cursed Healing", Rarity = "Epic", Description = "+60 years and +80 max health.", Buffs = { LifespanBonus = 60, MaxHealthBonus = 80 } },
	{ Id = "dao_heart", Name = "Domain Instinct", Rarity = "Epic", Description = "+12% Grade Promotion and +30% cursed energy.", Buffs = { BreakthroughBonus = 0.12, QiMult = 1.3 } },
	{ Id = "golden_spoon", Name = "Golden Spoon", Rarity = "Epic", Description = "Born rich: start with ¥20K, +20% salary.", Buffs = { StartingMoney = 20000, SalaryMult = 1.2 } },
	-- Mythic
	{ Id = "chaos_body", Name = "Six Eyes", Rarity = "Mythic", Description = "x4 cursed energy, +150 max health, +30% all stat XP.", Buffs = { QiMult = 4, MaxHealthBonus = 150, AllStatXp = 1.3 } },
	{ Id = "reborn_immortal", Name = "Reincarnated Heian Sorcerer", Rarity = "Mythic", Description = "x2.5 cursed energy, +200 years, +10% Grade Promotion.", Buffs = { QiMult = 2.5, LifespanBonus = 200, BreakthroughBonus = 0.1 } },
	{ Id = "time_lotus", Name = "Cursed Womb Longevity", Rarity = "Mythic", Description = "x1.6 total lifespan.", Buffs = { LifespanMult = 1.6 } },
	-- Content expansion (2026-11-02): 18 more talents.
	{ Id = "steady_hands", Name = "Steady Hands", Rarity = "Common", Description = "+15% Agility XP.", Buffs = { StatXp = { Agility = 1.15 } } },
	{ Id = "ox_strength", Name = "Gorilla Grip", Rarity = "Common", Description = "+15% Strength XP.", Buffs = { StatXp = { Strength = 1.15 } } },
	{ Id = "warm_smile", Name = "Warm Smile", Rarity = "Common", Description = "+10% affection gains.", Buffs = { RelationshipMult = 1.1 } },
	{ Id = "thrifty", Name = "Part-Timer's Hustle", Rarity = "Common", Description = "+5% salary, start with ¥500.", Buffs = { SalaryMult = 1.05, StartingMoney = 500 } },
	{ Id = "light_sleeper", Name = "Nerves of Steel", Rarity = "Common", Description = "-1 stress per year.", Buffs = { StressPerYear = -1 } },
	{ Id = "bookish", Name = "Bookworm", Rarity = "Common", Description = "+10% study.", Buffs = { StudyMult = 1.1 } },
	{ Id = "water_root", Name = "Flowing Cursed Energy", Rarity = "Rare", Description = "+30% cursed energy gain, +10 years.", Buffs = { QiMult = 1.3, LifespanBonus = 10 } },
	{ Id = "sword_heart", Name = "Cursed Tool Affinity", Rarity = "Rare", Description = "+40% Cursed Tools XP.", Buffs = { ProficiencyXp = { Sword = 1.4 } } },
	{ Id = "mana_spring", Name = "Barrier Savant", Rarity = "Rare", Description = "+40% Barrier & Domain Arts XP.", Buffs = { ProficiencyXp = { QiArts = 1.4 } } },
	{ Id = "merchant_blood", Name = "Freelancer's Nose", Rarity = "Rare", Description = "+20% salary, start with ¥2K.", Buffs = { SalaryMult = 1.2, StartingMoney = 2000 } },
	{ Id = "war_sense", Name = "Brawler's Instinct", Rarity = "Rare", Description = "+40% Taijutsu XP, +20 max health.", Buffs = { ProficiencyXp = { Spear = 1.4 }, MaxHealthBonus = 20 } },
	{ Id = "serene_mind", Name = "Serene Mind", Rarity = "Rare", Description = "+5% Grade Promotion, +20% study.", Buffs = { BreakthroughBonus = 0.05, StudyMult = 1.2 } },
	{ Id = "thunder_root", Name = "Lightning Cursed Energy", Rarity = "Epic", Description = "x1.8 cursed energy gain, +10% Agility XP.", Buffs = { QiMult = 1.8, StatXp = { Agility = 1.1 } } },
	{ Id = "dragon_marrow", Name = "Unbreakable Body", Rarity = "Epic", Description = "+120 max health, +40 years.", Buffs = { MaxHealthBonus = 120, LifespanBonus = 40 } },
	{ Id = "fated_one", Name = "Child of Fate", Rarity = "Epic", Description = "+20% all stat XP, +30% Binding Vows.", Buffs = { AllStatXp = 1.2, KarmaMult = 1.3 } },
	{ Id = "endless_stamina", Name = "Endless Stamina", Rarity = "Epic", Description = "+1 action every year, -1 stress per year.", Buffs = { ActionSlots = 1, StressPerYear = -1 } },
	{ Id = "star_soul", Name = "Star Plasma Soul", Rarity = "Mythic", Description = "x3 cursed energy, x1.5 passive CE, +12% Grade Promotion.", Buffs = { QiMult = 3, PassiveQiMult = 1.5, BreakthroughBonus = 0.12 } },
	{ Id = "heavenly_fortune", Name = "Loved by Heaven and Earth", Rarity = "Mythic", Description = "+40% all stat XP, +30% salary, +100 years.", Buffs = { AllStatXp = 1.4, SalaryMult = 1.3, LifespanBonus = 100 } },
}

TalentsConfig.ById = {}
for _, talent in TalentsConfig.List do
	TalentsConfig.ById[talent.Id] = talent
end
TalentsConfig.Spin.Rarities = TalentsConfig.Rarities

function TalentsConfig.Get(id: string)
	return TalentsConfig.ById[id]
end

function TalentsConfig.GetCost(id: string): number
	local talent = TalentsConfig.ById[id]
	return talent and TalentsConfig.Rarities[talent.Rarity].Cost or math.huge
end

-- Rolls `count` distinct talents weighted by rarity.
function TalentsConfig.Roll(count: number, rng: Random?): { string }
	rng = rng or Random.new()
	local totalWeight = 0
	for _, rarity in TalentsConfig.RarityOrder do
		totalWeight += TalentsConfig.Rarities[rarity].Weight
	end

	local results, used = {}, {}
	local attempts = 0
	while #results < count and attempts < 100 do
		attempts += 1
		local roll = rng:NextNumber() * totalWeight
		local picked = "Common"
		for _, rarity in TalentsConfig.RarityOrder do
			roll -= TalentsConfig.Rarities[rarity].Weight
			if roll <= 0 then
				picked = rarity
				break
			end
		end
		local pool = {}
		for _, talent in TalentsConfig.List do
			if talent.Rarity == picked and not used[talent.Id] then
				table.insert(pool, talent)
			end
		end
		if #pool > 0 then
			local talent = pool[rng:NextInteger(1, #pool)]
			used[talent.Id] = true
			table.insert(results, talent.Id)
		end
	end
	return results
end

return TalentsConfig
