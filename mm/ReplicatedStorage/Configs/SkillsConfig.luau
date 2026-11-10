--[[
	SkillsConfig: "What you do is what you become" (Modules/SkillSystem, Skills tab).

	Skills         12 skills (Level 0+, no cap beyond the life-stage ceiling).
	Ranks          name by level (Beginner 0 ... God 90).
	Stages         life-stage ceiling: a skill cannot pass Cap before that stage.
	CombatOpenAge  Magic and Swordsmanship gain nothing before this age; the Prodigy pass
	               (MonetizationConfig TrainingAgeOffset) opens them earlier.
	Unlocks        at levels 15 / 30 / 45 each skill unlocks an Action (one a year, costs
	               1 action) and a permanent Passive (buffs for the rest of the life).
	Inference      skill XP from training: StatXp of these stats and these proficiencies
	               also train the skill (x Ratio); actions may add SkillXp directly.
	Action effects: Money (n or {min, max}, x GoldMult), Fame, Happiness, Stress, Health,
	StatXp = { Stat = xp }, SkillXp = { Skill = xp }, LifeBuff = { Name, Buffs }, Flag.
	Chance + Fail = a risky action (⚠); its odds grow with the skill above the unlock.
]]

local SkillsConfig = {}

SkillsConfig.Ranks = {
	{ Min = 0, Name = "Beginner" }, { Min = 15, Name = "Intermediate" }, { Min = 30, Name = "Advanced" },
	{ Min = 45, Name = "Saint" }, { Min = 60, Name = "King" }, { Min = 75, Name = "Emperor" }, { Min = 90, Name = "God" },
}

SkillsConfig.Stages = {
	{ Id = "Infant", Name = "Infant", MaxAge = 2, Cap = 3 },
	{ Id = "Child", Name = "Child", MaxAge = 7, Cap = 12 },
	{ Id = "Teen", Name = "Teen", MaxAge = 17, Cap = 45 },
	{ Id = "Adult", Name = "Adult", MaxAge = 59, Cap = 90 },
	{ Id = "Elder", Name = "Elder", MaxAge = math.huge, Cap = math.huge },
}

SkillsConfig.CombatOpenAge = 8
SkillsConfig.CombatSkills = { Magic = true, Swordsmanship = true }
SkillsConfig.UnlockLevels = { 15, 30, 45 }

SkillsConfig.Inference = {
	Ratio = 1,
	Stats = {
		Strength = "Fitness", Agility = "Fitness", Vitality = "Fitness", BattleAura = "Swordsmanship",
		Intelligence = "Knowledge", Charisma = "Charisma", QiControl = "Magic", Mana = "Magic", MagicPower = "Magic", MagicControl = "Magic",
	},
	Proficiencies = { Sword = "Swordsmanship", Spear = "Swordsmanship", QiArts = "Magic" },
}

function SkillsConfig.XpForLevel(level: number): number
	return math.floor(5 + level * 1.2)
end

local function unlocks(a, b, c)
	return { [15] = a, [30] = b, [45] = c }
end

SkillsConfig.Skills = {
	{ Id = "Magic", Name = "Magic", Icon = "✨", Color = Color3.fromRGB(186, 120, 255), Description = "Spells, rituals and the arcane.",
		Unlocks = unlocks(
			{ Action = { Id = "TutorMage", Name = "Tutor a Young Mage", Description = "Teach the basics for coin.", Effects = { Money = { 60, 140 }, SkillXp = { Charisma = 6 } } },
				Passive = { Name = "Mana Flow", Buffs = { ManaCostMult = 0.95 } } },
			{ Action = { Id = "MageExpedition", Name = "Mage Guild Expedition", Description = "Delve into a ruin with the guild.", Chance = 0.65,
				Effects = { Money = { 400, 900 }, SkillXp = { Magic = 10 } }, Fail = { Health = -15, Stress = 8 } },
				Passive = { Name = "Arcane Insight", Buffs = { MagicDamageMult = 1.1 } } },
			{ Action = { Id = "OpenAcademy", Name = "Open a Magic Academy", Description = "Your name over a gate of students.", Effects = { Money = 2500, Fame = 60, Flag = "FoundedAcademy" } },
				Passive = { Name = "Archmage", Buffs = { MagicDamageMult = 1.15, ManaCostMult = 0.9 } } }) },
	{ Id = "Swordsmanship", Name = "Swordsmanship", Icon = "⚔", Color = Color3.fromRGB(150, 210, 255), Description = "Blades, footwork and duels.",
		Unlocks = unlocks(
			{ Action = { Id = "Tournament", Name = "Enter a Tournament", Description = "Steel against the region's best.", Chance = 0.55,
				Effects = { Money = { 200, 600 }, Fame = 15, SkillXp = { Swordsmanship = 8 } }, Fail = { Health = -12, Happiness = -4 } },
				Passive = { Name = "Clean Cuts", Buffs = { SwordDamageMult = 1.05 } } },
			{ Action = { Id = "Bodyguard", Name = "Bodyguard Contract", Description = "Guard a merchant on the road.", Chance = 0.75,
				Effects = { Money = { 700, 1400 } }, Fail = { Health = -20, Money = 200 } },
				Passive = { Name = "Battle Rhythm", Buffs = { SwordDamageMult = 1.1 } } },
			{ Action = { Id = "SwordSchool", Name = "Found a Sword School", Description = "Your style, taught to others.", Effects = { Money = 1800, Fame = 70, Flag = "FoundedSwordSchool" } },
				Passive = { Name = "Sword Saint", Buffs = { SwordDamageMult = 1.15, DamageTakenMult = 0.95 } } }) },
	{ Id = "Charisma", Name = "Charisma", Icon = "💬", Color = Color3.fromRGB(240, 130, 210), Description = "Persuasion, leadership and charm.",
		Unlocks = unlocks(
			{ Action = { Id = "HostFeast", Name = "Host a Feast", Description = "Food, music and new friends.", Effects = { Happiness = 8, Money = -80, SkillXp = { Charisma = 6 } } },
				Passive = { Name = "Warm Presence", Buffs = { RelationshipMult = 1.1 } } },
			{ Action = { Id = "BrokerAlliance", Name = "Broker an Alliance", Description = "Bring two houses to one table.", Chance = 0.7, Effects = { Money = { 500, 1000 }, Fame = 10 }, Fail = { Stress = 10 } },
				Passive = { Name = "Silver Words", Buffs = { SocialBonus = 0.05 } } },
			{ Action = { Id = "LeadMovement", Name = "Lead a Movement", Description = "Crowds chant your name.", Effects = { Fame = 80, Happiness = 10, Flag = "LedMovement" } },
				Passive = { Name = "Living Legend", Buffs = { RelationshipMult = 1.2, SocialBonus = 0.05 } } }) },
	{ Id = "Trade", Name = "Trade", Icon = "⚖", Color = Color3.fromRGB(240, 196, 92), Description = "Buying low, selling high.",
		Unlocks = unlocks(
			{ Action = { Id = "MarketStall", Name = "Run a Market Stall", Description = "A season of haggling.", Effects = { Money = { 150, 400 } } },
				Passive = { Name = "Sharp Eye", Buffs = { GoldMult = 1.05 } } },
			{ Action = { Id = "Caravan", Name = "Lead a Caravan", Description = "Three towns, one road, many bandits.", Chance = 0.65, Effects = { Money = { 900, 2000 } }, Fail = { Money = -300, Health = -10 } },
				Passive = { Name = "Ledger Mind", Buffs = { GoldMult = 1.1 } } },
			{ Action = { Id = "TradingHouse", Name = "Found a Trading House", Description = "Ships, warehouses, a family name.", Effects = { Money = 5000, Fame = 40, Flag = "FoundedTradingHouse" } },
				Passive = { Name = "Merchant Prince", Buffs = { GoldMult = 1.2, SalaryMult = 1.1 } } }) },
	{ Id = "Fitness", Name = "Fitness", Icon = "💪", Color = Color3.fromRGB(240, 110, 100), Description = "Endurance, strength and health.",
		Unlocks = unlocks(
			{ Action = { Id = "MountainRace", Name = "Run the Mountain Race", Description = "Up the cliff path before dawn.", Effects = { StatXp = { Vitality = 12, Agility = 8 }, Fame = 5 } },
				Passive = { Name = "Iron Lungs", Buffs = { MaxHealthBonus = 10 } } },
			{ Action = { Id = "Strongman", Name = "Strongman Contest", Description = "Lift the temple bell.", Chance = 0.7, Effects = { Money = { 300, 700 }, Fame = 10 }, Fail = { Health = -12 } },
				Passive = { Name = "Unbreakable", Buffs = { MaxHealthBonus = 25 } } },
			{ Action = { Id = "TrainUnit", Name = "Train an Army Unit", Description = "Forge recruits into soldiers.", Effects = { Money = 1500, Fame = 30 } },
				Passive = { Name = "Body of Steel", Buffs = { MaxHealthBonus = 50, LifespanBonus = 5 } } }) },
	{ Id = "Stealth", Name = "Stealth", Icon = "👣", Color = Color3.fromRGB(150, 150, 180), Description = "Moving unseen and unheard.",
		Unlocks = unlocks(
			{ Action = { Id = "ScoutGuard", Name = "Scout for the Guard", Description = "Watch the bandit roads.", Effects = { Money = { 100, 250 }, SkillXp = { Survival = 4 } } },
				Passive = { Name = "Soft Steps", Buffs = { FleeBonus = 0.1 } } },
			{ Action = { Id = "InfiltrateCamp", Name = "Infiltrate a Bandit Camp", Description = "In, out, with their ledger.", Chance = 0.6, Effects = { Money = { 800, 1600 }, Fame = 10 }, Fail = { Health = -20, Stress = 10 } },
				Passive = { Name = "Shadow Walker", Buffs = { FleeBonus = 0.2 } } },
			{ Action = { Id = "ShadowGuild", Name = "Lead a Shadow Guild", Description = "Whispers answer to you.", Effects = { Money = 3000, Flag = "ShadowGuild" } },
				Passive = { Name = "Unseen", Buffs = { FleeBonus = 0.3, DamageTakenMult = 0.95 } } }) },
	{ Id = "Crafting", Name = "Crafting", Icon = "🔨", Color = Color3.fromRGB(200, 160, 110), Description = "Making things that last.",
		Unlocks = unlocks(
			{ Action = { Id = "CarveStaff", Name = "Carve Your Own Staff", Description = "A focus shaped to your hand.", Effects = { LifeBuff = { Name = "Your Own Staff", Buffs = { MagicDamageMult = 1.08 } } } },
				Passive = { Name = "Steady Hands", Buffs = { GoldMult = 1.03 } } },
			{ Action = { Id = "ForgeBlade", Name = "Forge Your Own Blade", Description = "Steel folded a hundred times.", Effects = { LifeBuff = { Name = "Your Own Blade", Buffs = { SwordDamageMult = 1.1 } } } },
				Passive = { Name = "Master Smith", Buffs = { GoldMult = 1.05 } } },
			{ Action = { Id = "Masterwork", Name = "Create a Family Weapon", Description = "A masterwork your descendants will carry.", Effects = { Fame = 40, Flag = "FamilyWeapon",
				LifeBuff = { Name = "Family Weapon", Buffs = { SwordDamageMult = 1.1, MagicDamageMult = 1.1 } } } },
				Passive = { Name = "Living Forge", Buffs = { GoldMult = 1.1 } } }) },
	{ Id = "Survival", Name = "Survival", Icon = "🏕", Color = Color3.fromRGB(120, 200, 120), Description = "Food, fire and shelter anywhere.",
		Unlocks = unlocks(
			{ Action = { Id = "Forage", Name = "Forage the Wilds", Description = "Herbs, roots and mushrooms.", Effects = { Money = { 60, 160 }, Health = 5 } },
				Passive = { Name = "Weathered", Buffs = { StressPerYear = -1 } } },
			{ Action = { Id = "WinterAlone", Name = "Survive a Winter Alone", Description = "Just you and the snow.", Chance = 0.7, Effects = { StatXp = { Vitality = 20 }, Fame = 8 }, Fail = { Health = -25 } },
				Passive = { Name = "Hardy", Buffs = { MaxHealthBonus = 15 } } },
			{ Action = { Id = "TameBeast", Name = "Tame a Spirit Beast", Description = "A companion for life.", Chance = 0.6, Effects = { Fame = 30, LifeBuff = { Name = "Spirit Beast", Buffs = { DamageTakenMult = 0.9 } } }, Fail = { Health = -20 } },
				Passive = { Name = "Wild Heart", Buffs = { LifespanBonus = 5 } } }) },
	{ Id = "Faith", Name = "Faith", Icon = "🕯", Color = Color3.fromRGB(255, 230, 160), Description = "Prayer, temples and the gods.",
		Unlocks = unlocks(
			{ Action = { Id = "LeadPrayers", Name = "Lead Prayers", Description = "The village gathers.", Effects = { Happiness = 6, Stress = -6 } },
				Passive = { Name = "Inner Calm", Buffs = { HappinessPerYear = 1 } } },
			{ Action = { Id = "Pilgrimage", Name = "Pilgrimage", Description = "To the mountain shrine.", Effects = { Stress = -15, StatXp = { Luck = 10 } } },
				Passive = { Name = "Blessed", Buffs = { LifespanBonus = 5 } } },
			{ Action = { Id = "FoundTemple", Name = "Found a Temple", Description = "Stone, incense, devotion.", Effects = { Fame = 50, Happiness = 10, Flag = "FoundedTemple" } },
				Passive = { Name = "Saint's Grace", Buffs = { LifespanBonus = 10, HappinessPerYear = 1 } } }) },
	{ Id = "Exploration", Name = "Exploration", Icon = "🧭", Color = Color3.fromRGB(110, 200, 220), Description = "Maps, ruins and horizons.",
		Unlocks = unlocks(
			{ Action = { Id = "MapRuins", Name = "Map the Old Ruins", Description = "Chalk, rope and luck.", Chance = 0.75, Effects = { Money = { 150, 450 }, StatXp = { Luck = 6 } }, Fail = { Health = -8 } },
				Passive = { Name = "Pathfinder", Buffs = { BattleRewardMult = 1.05 } } },
			{ Action = { Id = "HiddenValley", Name = "Discover a Hidden Valley", Description = "Mist parts over green land.", Effects = { Fame = 25, Happiness = 8 } },
				Passive = { Name = "Far Wanderer", Buffs = { BattleRewardMult = 1.1 } } },
			{ Action = { Id = "ChartSea", Name = "Chart the Unknown Sea", Description = "Beyond the last map.", Chance = 0.6, Effects = { Money = 4000, Fame = 60 }, Fail = { Health = -25, Stress = 12 } },
				Passive = { Name = "World Walker", Buffs = { BattleRewardMult = 1.2 } } }) },
	{ Id = "Knowledge", Name = "Knowledge", Icon = "📚", Color = Color3.fromRGB(110, 180, 255), Description = "Books, history and theory. Opens special magic schools.",
		Unlocks = unlocks(
			{ Action = { Id = "CopyManuscripts", Name = "Copy Rare Manuscripts", Description = "Ink-stained fingers, paid well.", Effects = { Money = { 80, 200 }, StatXp = { Intelligence = 10 } } },
				Passive = { Name = "Well Read", Buffs = { StudyMult = 1.1 } } },
			{ Action = { Id = "PublishTreatise", Name = "Publish a Treatise", Description = "Scholars argue about you.", Effects = { Fame = 20, Money = 400 } },
				Passive = { Name = "Scholar", Buffs = { KnowledgeBonus = 1 } } },
			{ Action = { Id = "FoundLibrary", Name = "Found a Library", Description = "Knowledge kept for the ages.", Effects = { Fame = 50, Flag = "FoundedLibrary" } },
				Passive = { Name = "Sage", Buffs = { StudyMult = 1.2, AllStatXp = 1.05 } } }) },
	{ Id = "Medicine", Name = "Medicine", Icon = "🌿", Color = Color3.fromRGB(110, 230, 170), Description = "Herbs, healing and anatomy.",
		Unlocks = unlocks(
			{ Action = { Id = "TreatVillagers", Name = "Treat Villagers", Description = "Fevers, cuts and gratitude.", Effects = { Money = { 80, 180 }, Happiness = 4 } },
				Passive = { Name = "Healer's Touch", Buffs = { MaxHealthBonus = 10 } } },
			{ Action = { Id = "CurePlague", Name = "Cure a Plague", Description = "Walk into the sick quarter.", Chance = 0.6, Effects = { Fame = 40, Money = 800 }, Fail = { Health = -25, Stress = 10 } },
				Passive = { Name = "Physician", Buffs = { LifespanBonus = 5 } } },
			{ Action = { Id = "HealingHouse", Name = "Found a Healing House", Description = "Beds for all who come.", Effects = { Fame = 45, Happiness = 8, Flag = "FoundedHealingHouse" } },
				Passive = { Name = "Miracle Healer", Buffs = { MaxHealthBonus = 30, LifespanBonus = 10 } } }) },
}

SkillsConfig.ById, SkillsConfig.Order, SkillsConfig.ActionsById = {}, {}, {}
for _, skill in SkillsConfig.Skills do
	SkillsConfig.ById[skill.Id] = skill
	table.insert(SkillsConfig.Order, skill.Id)
	for level, unlock in skill.Unlocks do
		unlock.Action.Skill, unlock.Action.Level = skill.Id, level
		SkillsConfig.ActionsById[unlock.Action.Id] = unlock.Action
	end
end

function SkillsConfig.Rank(level: number)
	local rank = SkillsConfig.Ranks[1]
	for _, entry in SkillsConfig.Ranks do
		if level >= entry.Min then
			rank = entry
		end
	end
	return rank
end

function SkillsConfig.Stage(age: number)
	for _, stage in SkillsConfig.Stages do
		if age <= stage.MaxAge then
			return stage
		end
	end
	return SkillsConfig.Stages[#SkillsConfig.Stages]
end

-- Age a combat skill opens at, given extra years from passes (Prodigy).
function SkillsConfig.OpenAge(skillId: string, offset: number?): number
	if SkillsConfig.CombatSkills[skillId] then
		return SkillsConfig.CombatOpenAge - (offset or 0)
	end
	return 0
end

return SkillsConfig
