--[[
	CharacterConfig: who you are (Modules/CharacterSystem, Character tab).

	Upbringings   rolled at birth (Weight): a per-life buff source, FamilyAffection shift.
	Path          alignment thresholds: Hero at HeroAt or more, Villain at VillainAt or less.
	Parents       both parents get adult attribute levels (Mean +- Spread per stat group);
	              Inherit stats come straight from their average (x Share), every other
	              stat trains faster or slower (XpPerPoint per level above / below Mean).
	HiddenTalents 4 of these (16 in all) are hidden in every life (????????) and reveal themselves
	              when their Counter reaches Need; Rarity lets them wild-fuse.
	Fusion        once a year from MinAge: fuse two traits (talents or revealed hidden
	              talents). A Recipe pair makes its fused trait (discovered for good);
	              two of the same rarity without a recipe wild-fuse into a random talent
	              of the next rarity.
	Sliders       10 personality sliders: bipolar -100..100, unipolar 0..100. Pushes say
	              how actions move them; past Threshold a side grants its Buffs, and event
	              options can require it (Requirements: Personality = { Id = 50 / -50 }).
]]

local CharacterConfig = {}

CharacterConfig.Upbringings = {
	{ Id = "LovingHome", Name = "Loving Home", Weight = 30, Description = "Warm meals and bedtime stories.", Buffs = { HappinessPerYear = 1, RelationshipMult = 1.1 } },
	{ Id = "StrictDojo", Name = "Strict Dojo", Weight = 15, Description = "Up before dawn, sword in hand.", Buffs = { SkillXp = { Swordsmanship = 1.2, Fitness = 1.1 }, StressPerYear = 1 } },
	{ Id = "Despised", Name = "Parents Who Despise You", Weight = 8, FamilyAffection = -25, Description = "Nothing you do is ever enough. You learn to need no one.",
		Buffs = { AllStatXp = 1.05, HappinessPerYear = -1 } },
	{ Id = "ScholarsHouse", Name = "Scholar's House", Weight = 15, Description = "Books stacked higher than you.", Buffs = { SkillXp = { Knowledge = 1.2, Magic = 1.1 } } },
	{ Id = "MerchantHousehold", Name = "Merchant Household", Weight = 12, Description = "Every dinner is a negotiation.", Buffs = { SkillXp = { Trade = 1.2 }, GoldMult = 1.05 } },
	{ Id = "TempleOrphanage", Name = "Temple Orphanage", Weight = 8, FamilyAffection = -10, Description = "Raised by monks and prayer bells.", Buffs = { SkillXp = { Faith = 1.2, Medicine = 1.1 } } },
	{ Id = "WanderingCaravan", Name = "Wandering Caravan", Weight = 7, Description = "A new horizon every month.", Buffs = { SkillXp = { Exploration = 1.2, Survival = 1.2 } } },
	{ Id = "NobleCourt", Name = "Noble Court", Weight = 5, Description = "Silk, etiquette and whispered plots.", Buffs = { SkillXp = { Charisma = 1.2 }, SocialBonus = 0.05 } },
	-- Content expansion (2026-11-02): 8 more upbringings.
	{ Id = "FarmFamily", Name = "Farm Family", Weight = 20, Description = "Dawn chores and harvest songs.", Buffs = { SkillXp = { Fitness = 1.15, Survival = 1.1 }, StressPerYear = -1 } },
	{ Id = "FishingVillage", Name = "Fishing Village", Weight = 12, Description = "Salt wind, nets and patient waiting.", Buffs = { SkillXp = { Survival = 1.15 }, StatXp = { Vitality = 1.1 } } },
	{ Id = "SmithsForge", Name = "Smith's Forge", Weight = 10, Description = "Sparks and the ring of the anvil.", Buffs = { SkillXp = { Crafting = 1.2, Fitness = 1.1 } } },
	{ Id = "HealersHut", Name = "Healer's Hut", Weight = 8, Description = "Bitter herbs and quiet bedside vigils.", Buffs = { SkillXp = { Medicine = 1.25 }, MaxHealthBonus = 10 } },
	{ Id = "StreetUrchin", Name = "Street Urchin", Weight = 7, FamilyAffection = -20, Description = "No roof, no rules, quick hands.", Buffs = { SkillXp = { Stealth = 1.25 }, StatXp = { Agility = 1.1 }, HappinessPerYear = -1 } },
	{ Id = "SoldiersBarracks", Name = "Soldier's Barracks", Weight = 8, Description = "Drills, discipline and a father away at war.", Buffs = { SkillXp = { Swordsmanship = 1.15, Fitness = 1.15 }, StressPerYear = 1 } },
	{ Id = "MountainHermitage", Name = "Mountain Hermitage", Weight = 5, FamilyAffection = -5, Description = "Raised by a hermit among clouds and pines.", Buffs = { QiMult = 1.1, SkillXp = { Faith = 1.1 } } },
	{ Id = "TravelingTroupe", Name = "Traveling Troupe", Weight = 6, Description = "Acrobats, actors and a new stage every week.", Buffs = { SkillXp = { Charisma = 1.15, Exploration = 1.1 }, StatXp = { Agility = 1.05 } } },
}

CharacterConfig.Path = { HeroAt = 10, VillainAt = -8 }

CharacterConfig.Parents = {
	Mean = 25, Spread = 10, -- adult levels (rating ~50)
	MagicMean = 12, MagicStats = { Mana = true, MagicPower = true, MagicControl = true, BattleAura = true, AuraPotential = true },
	Inherit = { "BattleAura", "AuraPotential", "Mana", "MagicPower", "MagicControl", "Luck" },
	Share = 0.12,
	XpPerPoint = 0.01, MinXp = 0.85, MaxXp = 1.25,
}

CharacterConfig.HiddenSlots = 4
CharacterConfig.HiddenTalents = {
	{ Id = "mana_sense", Name = "Mana Sense", Rarity = "Rare", Counter = "spells_cast", Need = 15, Description = "You feel mana like warmth on your skin.", Buffs = { ManaCostMult = 0.9 } },
	{ Id = "shadow_step", Name = "Shadow Step", Rarity = "Rare", Counter = "sneak_wins", Need = 2, Description = "Floorboards never creak under you.", Buffs = { FleeBonus = 0.15, SkillXp = { Stealth = 1.3 } } },
	{ Id = "battle_instinct", Name = "Battle Instinct", Rarity = "Rare", Counter = "battles_won", Need = 5, Description = "Your body moves before you think.", Buffs = { SwordDamageMult = 1.1 } },
	{ Id = "fate_reader", Name = "Fate Reader", Rarity = "Rare", Counter = "omens", Need = 4, Description = "The omens speak plainly to you.", Buffs = { StatXp = { Luck = 1.5 } } },
	{ Id = "scholars_spark", Name = "Scholar's Spark", Rarity = "Rare", Counter = "study_years", Need = 5, Description = "Ideas come easily now.", Buffs = { StudyMult = 1.15, SkillXp = { Knowledge = 1.2 } } },
	{ Id = "hearth_heart", Name = "Hearth Heart", Rarity = "Rare", Counter = "family_years", Need = 5, Description = "Home follows you wherever you go.", Buffs = { HappinessPerYear = 1, RelationshipMult = 1.1 } },
	{ Id = "starlit_eyes", Name = "Starlit Eyes", Rarity = "Rare", Counter = "motes_caught", Need = 60, Description = "You see the faintest lights.", Buffs = { StatXp = { Mana = 1.3 } } },
	{ Id = "jack_of_all", Name = "Jack of All Trades", Rarity = "Rare", Counter = "skill_actions", Need = 6, Description = "A little good at everything.", Buffs = { SkillXpMult = 1.1 } },
	-- Content expansion (2026-11-02): 8 more hidden talents.
	{ Id = "giant_slayer", Name = "Giant Slayer", Rarity = "Rare", Counter = "bosses", Need = 2, Description = "The bigger they are, the calmer you get.", Buffs = { SwordDamageMult = 1.1, MagicDamageMult = 1.05 } },
	{ Id = "spell_smith", Name = "Spell Smith", Rarity = "Rare", Counter = "forged", Need = 2, Description = "Spells bend to your hammer like hot iron.", Buffs = { ManaCostMult = 0.9, SkillXp = { Magic = 1.15 } } },
	{ Id = "iron_will", Name = "Iron Will", Rarity = "Rare", Counter = "train", Need = 20, Description = "Pain stopped meaning anything years ago.", Buffs = { AllStatXp = 1.05, StressPerYear = -1 } },
	{ Id = "people_reader", Name = "People Reader", Rarity = "Rare", Counter = "social", Need = 15, Description = "You hear what people mean, not what they say.", Buffs = { SocialBonus = 0.08, StatXp = { Charisma = 1.2 } } },
	{ Id = "old_soul", Name = "Old Soul", Rarity = "Rare", Counter = "years", Need = 60, Description = "Time has taught you patience.", Buffs = { LifespanBonus = 10, StudyMult = 1.1 } },
	{ Id = "quick_reflexes", Name = "Quick Reflexes", Rarity = "Rare", Counter = "minigames", Need = 6, Description = "Your hands are faster than your eyes.", Buffs = { StatXp = { Agility = 1.3 }, FleeBonus = 0.1 } },
	{ Id = "raid_veteran", Name = "Raid Veteran", Rarity = "Rare", Counter = "raids", Need = 2, Description = "You know exactly when to strike and when to run.", Buffs = { BattleRewardMult = 1.15 } },
	{ Id = "treasure_nose", Name = "Treasure Nose", Rarity = "Rare", Counter = "leads", Need = 2, Description = "You can smell old gold through three feet of stone.", Buffs = { GoldMult = 1.1, StatXp = { Luck = 1.2 } } },
}

CharacterConfig.Fusion = { MinAge = 12 }
CharacterConfig.Recipes = {
	{ A = "iron_bones", B = "long_breath", Name = "Ageless Frame", Buffs = { MaxHealthBonus = 60, LifespanBonus = 20 } },
	{ A = "quick_mind", B = "photographic_memory", Name = "Eidetic Genius", Buffs = { StatXp = { Intelligence = 1.8 }, StudyMult = 1.2 } },
	{ A = "lucky_star", B = "karmic_thread", Name = "Fortune's Child", Buffs = { KarmaMult = 1.8, BreakthroughBonus = 0.05 } },
	{ A = "fire_root", B = "heavenly_root", Name = "Phoenix Root", Buffs = { QiMult = 3 } },
	{ A = "jade_body", B = "phoenix_blood", Name = "Undying Body", Buffs = { MaxHealthBonus = 150, LifespanBonus = 80 } },
	{ A = "calm_heart", B = "dao_heart", Name = "Still Mind of the Dao", Buffs = { BreakthroughBonus = 0.2, StressPerYear = -3 } },
	{ A = "silver_tongue", B = "golden_spoon", Name = "Merchant King", Buffs = { SalaryMult = 1.4, GoldMult = 1.2 } },
	{ A = "boundless_energy", B = "iron_bones", Name = "Tireless", Buffs = { ActionSlots = 1, MaxHealthBonus = 30 } },
	{ A = "quick_mind", B = "mana_sense", Name = "Arcane Prodigy", Buffs = { MagicDamageMult = 1.15, SkillXp = { Magic = 1.3 } } },
	{ A = "iron_bones", B = "battle_instinct", Name = "Born Warrior", Buffs = { SwordDamageMult = 1.15, DamageTakenMult = 0.9 } },
	{ A = "lucky_star", B = "fate_reader", Name = "Fate Weaver", Buffs = { StatXp = { Luck = 2 }, BattleRewardMult = 1.2 } },
	{ A = "silver_tongue", B = "hearth_heart", Name = "Beloved", Buffs = { RelationshipMult = 1.3, HappinessPerYear = 1 } },
	{ A = "photographic_memory", B = "scholars_spark", Name = "Living Library", Buffs = { SkillXp = { Knowledge = 1.5 }, KnowledgeBonus = 1 } },
	{ A = "shadow_step", B = "starlit_eyes", Name = "Night Hunter", Buffs = { FleeBonus = 0.3, SwordDamageMult = 1.1 } },
	{ A = "jack_of_all", B = "boundless_energy", Name = "Renaissance Soul", Buffs = { SkillXpMult = 1.2 } },
	{ A = "mana_sense", B = "starlit_eyes", Name = "Star Mage", Buffs = { ManaCostMult = 0.8 } },
	{ A = "battle_instinct", B = "shadow_step", Name = "Assassin's Edge", Buffs = { SwordDamageMult = 1.2 } },
	{ A = "calm_heart", B = "hearth_heart", Name = "Gentle Spirit", Buffs = { StressPerYear = -3, HappinessPerYear = 2 } },
	{ A = "fire_root", B = "mana_sense", Name = "Flame Heart", Buffs = { MagicDamageMult = 1.2, QiMult = 1.3 } },
	{ A = "long_breath", B = "time_lotus", Name = "Eternal Bloom", Buffs = { LifespanMult = 2 } },
	{ A = "chaos_body", B = "reborn_immortal", Name = "Primordial Sovereign", Buffs = { QiMult = 6, AllStatXp = 1.4 } },
	{ A = "golden_spoon", B = "karmic_thread", Name = "Blessed Dynasty", Buffs = { KarmaMult = 1.5, GoldMult = 1.25 } },
	{ A = "dao_heart", B = "fate_reader", Name = "Heaven's Favor", Buffs = { BreakthroughBonus = 0.15, BattleRewardMult = 1.15 } },
	-- Content expansion (2026-11-02): 23 more fusion recipes.
	{ A = "steady_hands", B = "quick_reflexes", Name = "Flowing Hands", Buffs = { StatXp = { Agility = 1.6 }, FleeBonus = 0.15 } },
	{ A = "ox_strength", B = "iron_bones", Name = "Mountain Body", Buffs = { StatXp = { Strength = 1.5 }, MaxHealthBonus = 60 } },
	{ A = "warm_smile", B = "people_reader", Name = "Heart Reader", Buffs = { RelationshipMult = 1.3, SocialBonus = 0.1 } },
	{ A = "thrifty", B = "merchant_blood", Name = "Golden Abacus", Buffs = { GoldMult = 1.3, SalaryMult = 1.15 } },
	{ A = "light_sleeper", B = "calm_heart", Name = "Untroubled Dreams", Buffs = { StressPerYear = -4, BreakthroughBonus = 0.05 } },
	{ A = "bookish", B = "scholars_spark", Name = "Hundred Schools", Buffs = { StudyMult = 1.35, SkillXp = { Knowledge = 1.3 } } },
	{ A = "water_root", B = "fire_root", Name = "Steam Root", Buffs = { QiMult = 2, LifespanBonus = 20 } },
	{ A = "sword_heart", B = "battle_instinct", Name = "Sword Saint's Heart", Buffs = { ProficiencyXp = { Sword = 1.8 }, SwordDamageMult = 1.2 } },
	{ A = "mana_spring", B = "mana_sense", Name = "Endless Well", Buffs = { ManaCostMult = 0.7 } },
	{ A = "war_sense", B = "raid_veteran", Name = "Born Raider", Buffs = { BattleRewardMult = 1.35 } },
	{ A = "serene_mind", B = "dao_heart", Name = "Mirror of the Dao", Buffs = { BreakthroughBonus = 0.2, StudyMult = 1.2 } },
	{ A = "thunder_root", B = "heavenly_root", Name = "Heavenly Thunder Root", Buffs = { QiMult = 3.2, MagicDamageMult = 1.15 } },
	{ A = "dragon_marrow", B = "phoenix_blood", Name = "Dragon-Phoenix Body", Buffs = { MaxHealthBonus = 220, LifespanBonus = 100 } },
	{ A = "fated_one", B = "karmic_thread", Name = "Thread of Destiny", Buffs = { KarmaMult = 2, AllStatXp = 1.25 } },
	{ A = "endless_stamina", B = "boundless_energy", Name = "Inexhaustible", Buffs = { ActionSlots = 2 } },
	{ A = "star_soul", B = "reborn_immortal", Name = "Celestial Rebirth", Buffs = { QiMult = 5, BreakthroughBonus = 0.15 } },
	{ A = "heavenly_fortune", B = "golden_spoon", Name = "Emperor's Fortune", Buffs = { GoldMult = 2, AllStatXp = 1.4 } },
	{ A = "giant_slayer", B = "battle_instinct", Name = "Titan Breaker", Buffs = { SwordDamageMult = 1.25, MagicDamageMult = 1.1 } },
	{ A = "spell_smith", B = "mana_sense", Name = "Runesmith", Buffs = { ManaCostMult = 0.8, MagicDamageMult = 1.1 } },
	{ A = "iron_will", B = "jack_of_all", Name = "Relentless", Buffs = { AllStatXp = 1.15, SkillXpMult = 1.1 } },
	{ A = "old_soul", B = "long_breath", Name = "Thousand Autumns", Buffs = { LifespanBonus = 40, StudyMult = 1.15 } },
	{ A = "treasure_nose", B = "lucky_star", Name = "Gold Dragon's Luck", Buffs = { GoldMult = 1.25, BreakthroughBonus = 0.04 } },
	{ A = "people_reader", B = "silver_tongue", Name = "Voice of Nations", Buffs = { SocialBonus = 0.15, StatXp = { Charisma = 1.6 } } },
}

CharacterConfig.Threshold = 50
CharacterConfig.Sliders = {
	{ Id = "Kindness", Left = "Cruel", Right = "Kind", LeftBuffs = { SwordDamageMult = 1.05, RelationshipMult = 0.9 }, RightBuffs = { HappinessPerYear = 1 } },
	{ Id = "Ambition", Left = "Lazy", Right = "Ambitious", LeftBuffs = { StressPerYear = -2 }, RightBuffs = { AllStatXp = 1.05 } },
	{ Id = "Bravery", Left = "Cowardly", Right = "Brave", LeftBuffs = { FleeBonus = 0.2 }, RightBuffs = { SwordDamageMult = 1.05, MagicDamageMult = 1.05 } },
	{ Id = "Honesty", Left = "Deceitful", Right = "Honest", LeftBuffs = { GoldMult = 1.08 }, RightBuffs = { RelationshipMult = 1.05 } },
	{ Id = "Generosity", Left = "Greedy", Right = "Generous", LeftBuffs = { GoldMult = 1.1 }, RightBuffs = { RelationshipMult = 1.08 } },
	{ Id = "Sociability", Left = "Introverted", Right = "Social", LeftBuffs = { StudyMult = 1.1 }, RightBuffs = { SocialBonus = 0.05 } },
	{ Id = "Caution", Left = "Reckless", Right = "Cautious", LeftBuffs = { SwordDamageMult = 1.1, DamageTakenMult = 1.1 }, RightBuffs = { DamageTakenMult = 0.9 } },
	{ Id = "Curiosity", Right = "Curious", Unipolar = true, RightBuffs = { SkillXp = { Knowledge = 1.15, Exploration = 1.15 } } },
	{ Id = "Competitiveness", Right = "Competitive", Unipolar = true, RightBuffs = { BattleRewardMult = 1.1 } },
	{ Id = "Patience", Right = "Patient", Unipolar = true, RightBuffs = { ManaCostMult = 0.95 } },
}
CharacterConfig.UnipolarStart = 20

-- How everyday choices move the sliders.
CharacterConfig.Pushes = {
	Training = { Ambition = 2 },
	Rest = { Ambition = -2, Patience = 1 },
	Routine = {
		Relax = { Ambition = -1, Patience = 1 },
		Family = { Kindness = 1, Generosity = 1 },
		Study = { Curiosity = 2, Ambition = 1 },
		Socialize = { Sociability = 2 },
	},
	RiskyChoice = { Caution = -2, Bravery = 1 },
	GoodDeed = { Kindness = 3, Honesty = 1 },
	BadDeed = { Kindness = -3, Honesty = -2 },
	BattleWin = { Bravery = 2, Competitiveness = 2 },
	Flee = { Bravery = -3, Caution = 2 },
	Sneak = { Honesty = -1, Caution = 1, Curiosity = 1 },
	Omen = { Patience = 1, Curiosity = 1 },
}

CharacterConfig.UpbringingsById, CharacterConfig.HiddenById, CharacterConfig.SlidersById = {}, {}, {}
for _, entry in CharacterConfig.Upbringings do CharacterConfig.UpbringingsById[entry.Id] = entry end
for _, entry in CharacterConfig.HiddenTalents do CharacterConfig.HiddenById[entry.Id] = entry end
for _, entry in CharacterConfig.Sliders do CharacterConfig.SlidersById[entry.Id] = entry end
for i, recipe in CharacterConfig.Recipes do
	recipe.Id = "recipe" .. i
end

function CharacterConfig.Recipe(a: string, b: string)
	for _, recipe in CharacterConfig.Recipes do
		if (recipe.A == a and recipe.B == b) or (recipe.A == b and recipe.B == a) then
			return recipe
		end
	end
	return nil
end

function CharacterConfig.PathName(alignment: number): string
	if alignment >= CharacterConfig.Path.HeroAt then
		return "Hero"
	elseif alignment <= CharacterConfig.Path.VillainAt then
		return "Villain"
	end
	return "Neutral"
end

return CharacterConfig
