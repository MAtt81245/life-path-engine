--[[
	SkillsConfig (Soul Path): "What you do is what you become" (Modules/SkillSystem, Skills tab).

	Skills         12 skills (Level 0+, no cap beyond the life-stage ceiling).
	Ranks          name by level (Beginner 0 ... God 90).
	Stages         life-stage ceiling: a skill cannot pass Cap before that stage.
	CombatOpenAge  Kido (Magic) and Zanjutsu (Swordsmanship) gain nothing before this age; the Prodigy pass
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
	{ Min = 0, Name = "Unseated" }, { Min = 15, Name = "Seated" }, { Min = 30, Name = "Lieutenant" },
	{ Min = 45, Name = "Captain" }, { Min = 60, Name = "Royal Guard" }, { Min = 75, Name = "Legend" }, { Min = 90, Name = "Transcendent" },
}

SkillsConfig.Stages = {
	{ Id = "Infant", Name = "Newborn Soul", MaxAge = 2, Cap = 3 },
	{ Id = "Child", Name = "Child", MaxAge = 7, Cap = 12 },
	{ Id = "Teen", Name = "Academy Age", MaxAge = 17, Cap = 45 },
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
	{ Id = "Magic", Name = "Kido", Icon = "✨", Color = Color3.fromRGB(186, 120, 255), Description = "Hado, Bakudo and the incantations of the demon arts.",
		Unlocks = unlocks(
			{ Action = { Id = "TutorMage", Name = "Tutor Academy Students", Description = "Drill first-years on Hado #1 for coin.", Effects = { Money = { 60, 140 }, SkillXp = { Charisma = 6 } } },
				Passive = { Name = "Steady Incantation", Buffs = { ManaCostMult = 0.95 } } },
			{ Action = { Id = "MageExpedition", Name = "Kido Corps Field Assignment", Description = "Seal a rift with the Kido Corps.", Chance = 0.65,
				Effects = { Money = { 400, 900 }, SkillXp = { Magic = 10 } }, Fail = { Health = -15, Stress = 8 } },
				Passive = { Name = "Kido Insight", Buffs = { MagicDamageMult = 1.1 } } },
			{ Action = { Id = "OpenAcademy", Name = "Found a Kido School", Description = "Your name over a gate of students.", Effects = { Money = 2500, Fame = 60, Flag = "FoundedAcademy" } },
				Passive = { Name = "Kido Grandmaster", Buffs = { MagicDamageMult = 1.15, ManaCostMult = 0.9 } } }) },
	{ Id = "Swordsmanship", Name = "Zanjutsu", Icon = "⚔", Color = Color3.fromRGB(150, 210, 255), Description = "The art of the Zanpakuto: stances, cuts and duels.",
		Unlocks = unlocks(
			{ Action = { Id = "Tournament", Name = "Enter a Division Tournament", Description = "Steel against the Gotei's best.", Chance = 0.55,
				Effects = { Money = { 200, 600 }, Fame = 15, SkillXp = { Swordsmanship = 8 } }, Fail = { Health = -12, Happiness = -4 } },
				Passive = { Name = "Clean Cuts", Buffs = { SwordDamageMult = 1.05 } } },
			{ Action = { Id = "Bodyguard", Name = "Escort a Senkaimon Convoy", Description = "Guard travellers through the Dangai.", Chance = 0.75,
				Effects = { Money = { 700, 1400 } }, Fail = { Health = -20, Money = 200 } },
				Passive = { Name = "Battle Rhythm", Buffs = { SwordDamageMult = 1.1 } } },
			{ Action = { Id = "SwordSchool", Name = "Found a Zanjutsu Dojo", Description = "Your style, taught to others.", Effects = { Money = 1800, Fame = 70, Flag = "FoundedSwordSchool" } },
				Passive = { Name = "Sword Sage", Buffs = { SwordDamageMult = 1.15, DamageTakenMult = 0.95 } } }) },
	{ Id = "Charisma", Name = "Leadership", Icon = "💬", Color = Color3.fromRGB(240, 130, 210), Description = "Commanding a squad, persuading captains, earning loyalty.",
		Unlocks = unlocks(
			{ Action = { Id = "HostFeast", Name = "Host a Division Feast", Description = "Sake, music and new friends.", Effects = { Happiness = 8, Money = -80, SkillXp = { Charisma = 6 } } },
				Passive = { Name = "Warm Presence", Buffs = { RelationshipMult = 1.1 } } },
			{ Action = { Id = "BrokerAlliance", Name = "Broker a Clan Pact", Description = "Bring two noble houses to one table.", Chance = 0.7, Effects = { Money = { 500, 1000 }, Fame = 10 }, Fail = { Stress = 10 } },
				Passive = { Name = "Silver Words", Buffs = { SocialBonus = 0.05 } } },
			{ Action = { Id = "LeadMovement", Name = "Rally the Rukongai", Description = "Whole districts chant your name.", Effects = { Fame = 80, Happiness = 10, Flag = "LedMovement" } },
				Passive = { Name = "Living Legend", Buffs = { RelationshipMult = 1.2, SocialBonus = 0.05 } } }) },
	{ Id = "Trade", Name = "Commerce", Icon = "⚖", Color = Color3.fromRGB(240, 196, 92), Description = "Soul candy, gigai and spirit goods: buying low, selling high.",
		Unlocks = unlocks(
			{ Action = { Id = "MarketStall", Name = "Mind a Candy Shop", Description = "A season of haggling over soul candy.", Effects = { Money = { 150, 400 } } },
				Passive = { Name = "Sharp Eye", Buffs = { GoldMult = 1.05 } } },
			{ Action = { Id = "Caravan", Name = "Smuggle Goods Through the Dangai", Description = "One corridor, many cleaners.", Chance = 0.65, Effects = { Money = { 900, 2000 } }, Fail = { Money = -300, Health = -10 } },
				Passive = { Name = "Ledger Mind", Buffs = { GoldMult = 1.1 } } },
			{ Action = { Id = "TradingHouse", Name = "Open a Spirit Goods Shop", Description = "Hidden basements, a family name.", Effects = { Money = 5000, Fame = 40, Flag = "FoundedTradingHouse" } },
				Passive = { Name = "Merchant Prince", Buffs = { GoldMult = 1.2, SalaryMult = 1.1 } } }) },
	{ Id = "Fitness", Name = "Hakuda", Icon = "💪", Color = Color3.fromRGB(240, 110, 100), Description = "Hand-to-hand combat, endurance and a body built for battle.",
		Unlocks = unlocks(
			{ Action = { Id = "MountainRace", Name = "Run Sokyoku Hill", Description = "Up the execution hill before dawn.", Effects = { StatXp = { Vitality = 12, Agility = 8 }, Fame = 5 } },
				Passive = { Name = "Iron Lungs", Buffs = { MaxHealthBonus = 10 } } },
			{ Action = { Id = "Strongman", Name = "Hakuda Exhibition", Description = "Bare fists before the Second Division.", Chance = 0.7, Effects = { Money = { 300, 700 }, Fame = 10 }, Fail = { Health = -12 } },
				Passive = { Name = "Unbreakable", Buffs = { MaxHealthBonus = 25 } } },
			{ Action = { Id = "TrainUnit", Name = "Train a Squad", Description = "Forge recruits into soldiers.", Effects = { Money = 1500, Fame = 30 } },
				Passive = { Name = "Body of Steel", Buffs = { MaxHealthBonus = 50, LifespanBonus = 5 } } }) },
	{ Id = "Stealth", Name = "Hoho", Icon = "👣", Color = Color3.fromRGB(150, 150, 180), Description = "Flash steps, stealth and moving unseen.",
		Unlocks = unlocks(
			{ Action = { Id = "ScoutGuard", Name = "Patrol for the Onmitsukido", Description = "Watch the Rukongai roads.", Effects = { Money = { 100, 250 }, SkillXp = { Survival = 4 } } },
				Passive = { Name = "Soft Steps", Buffs = { FleeBonus = 0.1 } } },
			{ Action = { Id = "InfiltrateCamp", Name = "Infiltrate a Rogue Hideout", Description = "In, out, with their ledger.", Chance = 0.6, Effects = { Money = { 800, 1600 }, Fame = 10 }, Fail = { Health = -20, Stress = 10 } },
				Passive = { Name = "Flash Step", Buffs = { FleeBonus = 0.2 } } },
			{ Action = { Id = "ShadowGuild", Name = "Command a Covert Squad", Description = "Whispers answer to you.", Effects = { Money = 3000, Flag = "ShadowGuild" } },
				Passive = { Name = "Unseen", Buffs = { FleeBonus = 0.3, DamageTakenMult = 0.95 } } }) },
	{ Id = "Crafting", Name = "Soul Smithing", Icon = "🔨", Color = Color3.fromRGB(200, 160, 110), Description = "Asauchi, gigai and spirit tools that last.",
		Unlocks = unlocks(
			{ Action = { Id = "CarveStaff", Name = "Carve a Kido Focus", Description = "A focus shaped to your hand.", Effects = { LifeBuff = { Name = "Your Kido Focus", Buffs = { MagicDamageMult = 1.08 } } } },
				Passive = { Name = "Steady Hands", Buffs = { GoldMult = 1.03 } } },
			{ Action = { Id = "ForgeBlade", Name = "Temper Your Own Asauchi", Description = "Steel folded a hundred times.", Effects = { LifeBuff = { Name = "Your Asauchi", Buffs = { SwordDamageMult = 1.1 } } } },
				Passive = { Name = "Master Smith", Buffs = { GoldMult = 1.05 } } },
			{ Action = { Id = "Masterwork", Name = "Forge a Clan Blade", Description = "A masterwork your descendants will carry.", Effects = { Fame = 40, Flag = "FamilyWeapon",
				LifeBuff = { Name = "Family Weapon", Buffs = { SwordDamageMult = 1.1, MagicDamageMult = 1.1 } } } },
				Passive = { Name = "Royal Smith", Buffs = { GoldMult = 1.1 } } }) },
	{ Id = "Survival", Name = "Survival", Icon = "🏕", Color = Color3.fromRGB(120, 200, 120), Description = "Food, fire and shelter anywhere, even the outer Rukongai.",
		Unlocks = unlocks(
			{ Action = { Id = "Forage", Name = "Forage the Outer Districts", Description = "Herbs, roots and clean water.", Effects = { Money = { 60, 160 }, Health = 5 } },
				Passive = { Name = "Weathered", Buffs = { StressPerYear = -1 } } },
			{ Action = { Id = "WinterAlone", Name = "Survive a Night in Hueco Mundo", Description = "Just you and the white sand.", Chance = 0.7, Effects = { StatXp = { Vitality = 20 }, Fame = 8 }, Fail = { Health = -25 } },
				Passive = { Name = "Hardy", Buffs = { MaxHealthBonus = 15 } } },
			{ Action = { Id = "TameBeast", Name = "Bond with a Spirit Beast", Description = "A companion for life.", Chance = 0.6, Effects = { Fame = 30, LifeBuff = { Name = "Spirit Beast", Buffs = { DamageTakenMult = 0.9 } } }, Fail = { Health = -20 } },
				Passive = { Name = "Wild Heart", Buffs = { LifespanBonus = 5 } } }) },
	{ Id = "Faith", Name = "Konso Rites", Icon = "🕯", Color = Color3.fromRGB(255, 230, 160), Description = "Soul burials, prayers and guiding the lost to rest.",
		Unlocks = unlocks(
			{ Action = { Id = "LeadPrayers", Name = "Perform a Konso", Description = "A lost soul passes on.", Effects = { Happiness = 6, Stress = -6 } },
				Passive = { Name = "Inner Calm", Buffs = { HappinessPerYear = 1 } } },
			{ Action = { Id = "Pilgrimage", Name = "Visit the Soul King's Shrine", Description = "A long climb to the royal stair.", Effects = { Stress = -15, StatXp = { Luck = 10 } } },
				Passive = { Name = "Blessed", Buffs = { LifespanBonus = 5 } } },
			{ Action = { Id = "FoundTemple", Name = "Found a Konso Shrine", Description = "Stone, incense, devotion.", Effects = { Fame = 50, Happiness = 10, Flag = "FoundedTemple" } },
				Passive = { Name = "Saint's Grace", Buffs = { LifespanBonus = 10, HappinessPerYear = 1 } } }) },
	{ Id = "Exploration", Name = "Exploration", Icon = "🧭", Color = Color3.fromRGB(110, 200, 220), Description = "Maps, ruins and the worlds between worlds.",
		Unlocks = unlocks(
			{ Action = { Id = "MapRuins", Name = "Map the Old Seireitei Ruins", Description = "Chalk, rope and luck.", Chance = 0.75, Effects = { Money = { 150, 450 }, StatXp = { Luck = 6 } }, Fail = { Health = -8 } },
				Passive = { Name = "Pathfinder", Buffs = { BattleRewardMult = 1.05 } } },
			{ Action = { Id = "HiddenValley", Name = "Find a Hidden Training Ground", Description = "A cavern older than the Gotei.", Effects = { Fame = 25, Happiness = 8 } },
				Passive = { Name = "Far Wanderer", Buffs = { BattleRewardMult = 1.1 } } },
			{ Action = { Id = "ChartSea", Name = "Chart the Garganta Paths", Description = "Beyond the last map.", Chance = 0.6, Effects = { Money = 4000, Fame = 60 }, Fail = { Health = -25, Stress = 12 } },
				Passive = { Name = "World Walker", Buffs = { BattleRewardMult = 1.2 } } }) },
	{ Id = "Knowledge", Name = "Research", Icon = "📚", Color = Color3.fromRGB(110, 180, 255), Description = "Spirit science, history and theory. Opens forbidden Kido schools.",
		Unlocks = unlocks(
			{ Action = { Id = "CopyManuscripts", Name = "Assist the Research Bureau", Description = "Ink-stained fingers, paid well.", Effects = { Money = { 80, 200 }, StatXp = { Intelligence = 10 } } },
				Passive = { Name = "Well Read", Buffs = { StudyMult = 1.1 } } },
			{ Action = { Id = "PublishTreatise", Name = "Publish a Reishi Treatise", Description = "Scientists argue about you.", Effects = { Fame = 20, Money = 400 } },
				Passive = { Name = "Scholar", Buffs = { KnowledgeBonus = 1 } } },
			{ Action = { Id = "FoundLibrary", Name = "Found an Archive", Description = "Knowledge kept for the ages.", Effects = { Fame = 50, Flag = "FoundedLibrary" } },
				Passive = { Name = "Sage", Buffs = { StudyMult = 1.2, AllStatXp = 1.05 } } }) },
	{ Id = "Medicine", Name = "Kaido", Icon = "🌿", Color = Color3.fromRGB(110, 230, 170), Description = "Healing Kido, herbs and the Fourth Division's craft.",
		Unlocks = unlocks(
			{ Action = { Id = "TreatVillagers", Name = "Treat the Wounded", Description = "Burns, cuts and gratitude.", Effects = { Money = { 80, 180 }, Happiness = 4 } },
				Passive = { Name = "Healer's Touch", Buffs = { MaxHealthBonus = 10 } } },
			{ Action = { Id = "CurePlague", Name = "Purge a Hollow Poison", Description = "Walk into the sick quarter.", Chance = 0.6, Effects = { Fame = 40, Money = 800 }, Fail = { Health = -25, Stress = 10 } },
				Passive = { Name = "Physician", Buffs = { LifespanBonus = 5 } } },
			{ Action = { Id = "HealingHouse", Name = "Found a Relief Station", Description = "Beds for all who come.", Effects = { Fame = 45, Happiness = 8, Flag = "FoundedHealingHouse" } },
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
