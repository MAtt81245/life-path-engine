--[[
	World module event pool (GameManifest EventPools, Module = "World").
	- Road encounters (Trigger = "Travel"): never rolled yearly; Modules/RegionSystem
	  picks one per journey (Weight, Requires, Route = { region ids } where it can happen:
	  the origin or the destination must be listed; omitted = any road).
	- Regional events: ordinary yearly events gated by Requires = { Region = id }.
	Same event fields as YearlyEventsConfig.
]]

local TravelEventsConfig = {}

TravelEventsConfig.Events = {
	-- Road encounters ------------------------------------------------------
	bandit_pass = {
		Trigger = "Travel", ChainOnly = true, Weight = 3, Repeatable = true,
		Title = "Bandit Ambush", Text = "Halfway up the mountain pass, a rope snaps taut across the road. Masked bandits pour out of the pines.",
		Options = {
			{ Text = "Fight through", Chance = 0.5, ChanceStat = "Strength",
				Result = "You scatter them and take their purse.", Effects = { Money = 150, Counters = { Fights = 1 }, Stats = { Strength = 8 } },
				FailResult = "They beat you and take your coin.", FailEffects = { Health = -20, Money = -100 } },
			{ Text = "Pay the toll", Requires = { MinMoney = 80 }, Result = "They wave you through, grinning.", Effects = { Money = -80 } },
			{ Text = "Slip into the forest", Chance = 0.6, ChanceStat = "Agility", Result = "You lose them among the trees.", Effects = { Stats = { Agility = 6 } },
				FailResult = "An arrow grazes you as you flee.", FailEffects = { Health = -10 } },
		},
	},
	spirit_caravan = {
		Trigger = "Travel", ChainOnly = true, Weight = 2, Repeatable = true,
		Title = "Wandering Spirit Merchants", Text = "A caravan of lantern-lit wagons drawn by spirit oxen offers you a seat and a look at their wares.",
		Options = {
			{ Text = "Buy a spirit pill ($600)", Requires = { MinMoney = 600 }, Result = "The pill hums in your palm.", Effects = { Money = -600, Qi = 0.3 } },
			{ Text = "Trade stories by the fire", Result = "Their tales of distant lands stay with you.", Effects = { Stats = { Charisma = 8 }, Happiness = 6 } },
			{ Text = "Decline politely", Result = "The lanterns fade into the dusk.", Effects = {} },
		},
	},
	qi_storm = {
		Trigger = "Travel", ChainOnly = true, Weight = 2, Repeatable = true, Module = "Cultivation",
		Title = "Sudden Qi Storm", Text = "The sky turns violet. Raw Qi crackles across the road like lightning.",
		Options = {
			{ Text = "Absorb the storm", Chance = 0.45, ChanceStat = "QiControl",
				Result = "You drink the storm and your meridians sing.", Effects = { Qi = 0.6, Stats = { QiControl = 10 } },
				FailResult = "The storm tears through your meridians.", FailEffects = { Health = -25 } },
			{ Text = "Shelter under a rock", Result = "You wait it out, soaked and humbled.", Effects = { Stress = 4 } },
		},
	},
	roadside_shrine = {
		Trigger = "Travel", ChainOnly = true, Weight = 2, Repeatable = true,
		Title = "Hidden Roadside Shrine", Text = "Moss covers a tiny shrine by the road. Someone still leaves incense here.",
		Options = {
			{ Text = "Offer incense and pray", Result = "A warm breeze answers your prayer.", Effects = { Karma = 2, Alignment = 3, Stress = -6 } },
			{ Text = "Take the offerings", Result = "A few coins richer. The wind turns cold.", Effects = { Money = 60, Alignment = -6, Karma = -1 } },
		},
	},
	wandering_master = {
		Trigger = "Travel", ChainOnly = true, Weight = 1, Repeatable = true, Module = "Masters",
		Title = "A Traveling Master", Text = "An old cultivator shares the road with you and watches how you walk.",
		Options = {
			{ Text = "Ask for a lesson", Result = "He corrects your stance in three words.", Effects = { Proficiency = { Sword = 12, Spear = 6 }, Stats = { QiControl = 6 } } },
			{ Text = "Challenge him", Chance = 0.2, ChanceStat = "Strength", Result = "He laughs and calls you a prodigy.", Effects = { Stats = { Strength = 15 }, Karma = 2 },
				FailResult = "One finger. You are on the ground.", FailEffects = { Health = -10, Happiness = -4 } },
		},
	},
	rival_on_road = {
		Trigger = "Travel", ChainOnly = true, Weight = 1, Repeatable = true, Module = "Relationships",
		Title = "Crossing Paths", Text = "At the ferry crossing you come face to face with {name}.",
		Target = { Category = "Rival" },
		Options = {
			{ Text = "Duel on the riverbank", Chance = 0.5, ChanceStat = "Strength", Result = "{name} falls into the river.", Effects = { Counters = { Fights = 1 }, Affection = -10, Happiness = 8 },
				FailResult = "{name} sends you into the river.", FailEffects = { Health = -15, Happiness = -6 } },
			{ Text = "Share the ferry in silence", Result = "The crossing has never felt so long.", Effects = { Affection = 5 } },
		},
	},

	-- Regional events -----------------------------------------------------
	black_market = {
		Title = "The Black Market", Text = "Beneath the Leviathan's ribs a hooded broker shows you a velvet tray of forbidden goods.",
		MinAge = 12, MaxAge = 200, Weight = 0.25, Repeatable = true, Cooldown = 4,
		Requires = { Region = "crimson" },
		Options = {
			{ Text = "Buy a stolen manual ($1K)", Requires = { MinMoney = 1000 }, Result = "The pages smell of blood and genius.", Effects = { Money = -1000, Proficiency = { Sword = 15, Spear = 15 }, Alignment = -4 } },
			{ Text = "Fence a jade bracelet", Requires = { Items = { jade_bracelet = 1 } }, Result = "The broker pays well and asks nothing.", Effects = { Items = { jade_bracelet = -1 }, Money = 2200 } },
			{ Text = "Walk away", Result = "You keep your hands clean.", Effects = { Alignment = 2 } },
		},
	},
	imperial_exam = {
		Title = "The Imperial Examination", Text = "Thousands of candidates fill the examination halls. One essay decides your family's fate.",
		MinAge = 16, MaxAge = 60, Weight = 0.3, Repeatable = true, Cooldown = 3,
		Requires = { Region = "capital" },
		Options = {
			{ Text = "Write your heart out", Chance = 0.25, ChanceStat = "Intelligence",
				Result = "Top of the list! The Emperor grants you a post.", Effects = { Money = 3000, Karma = 3, Stats = { Intelligence = 12 }, Flags = { "ImperialScholar" } },
				FailResult = "Your name is not on the list this year.", FailEffects = { Stress = 8 } },
			{ Text = "Bribe an examiner ($2K)", Requires = { MinMoney = 2000 }, Chance = 0.6, ChanceStat = "Charisma",
				Result = "A suspiciously good result.", Effects = { Money = -2000, Alignment = -8, Flags = { "ImperialScholar" } },
				FailResult = "Caught! Flogged and fined.", FailEffects = { Money = -2000, Health = -20, Alignment = -5 } },
			{ Text = "Skip it", Result = "Maybe next time.", Effects = {} },
		},
	},
	orthodox_sect = {
		Title = "Trial of the Cloud Sects", Text = "The orthodox sword sects of Kunlun open their gates for one day. Disciples watch from floating stones.",
		MinAge = 12, MaxAge = 300, Weight = 0.3, Repeatable = true, Cooldown = 5,
		Requires = { Region = "kunlun" },
		Options = {
			{ Text = "Cross the floating stones", Chance = 0.5, ChanceStat = "Agility",
				Result = "An elder nods. You may train with the outer disciples.", Effects = { Proficiency = { Sword = 20, QiArts = 10 }, Qi = 0.3, Alignment = 4 },
				FailResult = "You fall into the clouds and wake at the foot of the mountain.", FailEffects = { Health = -20 } },
			{ Text = "Watch and learn", Result = "Their sword forms are burned into your memory.", Effects = { Proficiency = { Sword = 8 } } },
		},
	},
	star_relic = {
		Title = "A Relic in the Crater", Text = "A shard of a fallen god glows beneath the ash. Its whisper sounds like your own voice from another life.",
		MinAge = 12, MaxAge = 100000, Weight = 0.3, Repeatable = true, Cooldown = 4,
		Requires = { Region = "ruins" },
		Options = {
			{ Text = "Claim the relic", Chance = 0.55, ChanceStat = "Vitality",
				Result = "The relic accepts you.", Effects = { Items = { ancient_talisman = 1 }, Qi = 0.5, Karma = 2 },
				FailResult = "Divine radiation burns your hands.", FailEffects = { Health = -40 } },
			{ Text = "Meditate beside it", Result = "Memories of other lives drift past.", Effects = { Stats = { QiControl = 12 }, Stress = -5 } },
		},
	},
	-- ===== Content expansion (2026-11-02): 5 more road encounters, 5 regional events =====
	broken_bridge = {
		Trigger = "Travel", ChainOnly = true, Weight = 2, Repeatable = true,
		Title = "The Broken Bridge", Text = "The rope bridge over the gorge hangs in tatters. A family of travellers waits helplessly on the edge.",
		Options = {
			{ Text = "Repair it together", Chance = 0.55, ChanceStat = "Intelligence",
				Result = "Knots, planks and patience. Everyone crosses safely.", Effects = { Stats = { Intelligence = 6 }, Alignment = 4 },
				FailResult = "A plank gives way under you.", FailEffects = { Health = -15 } },
			{ Text = "Leap the gap", Chance = 0.45, ChanceStat = "Agility",
				Result = "You land on the far side and throw them a rope.", Effects = { Stats = { Agility = 8 }, Alignment = 3 },
				FailResult = "You catch the ledge with your fingertips. Barely.", FailEffects = { Health = -12, Stress = 8 } },
			{ Text = "Take the long road", Result = "Two extra days of walking.", Effects = { Stress = 3 } },
		},
	},
	lost_child_road = {
		Trigger = "Travel", ChainOnly = true, Weight = 2, Repeatable = true,
		Title = "A Lost Child", Text = "A small child sits crying at a crossroads, separated from a caravan.",
		Options = {
			{ Text = "Carry them to the next town", Result = "The parents weep and press silver into your hands.", Effects = { Money = 100, Alignment = 5, Karma = 1 } },
			{ Text = "Point them in the right direction", Result = "You hope they make it.", Effects = { Stress = 2 } },
		},
	},
	fox_spirit_inn = {
		Trigger = "Travel", ChainOnly = true, Weight = 1, Repeatable = true,
		Title = "An Inn That Was Not There", Text = "At dusk you find a lantern-lit inn on an empty road. The innkeeper has a fox's smile.",
		Options = {
			{ Text = "Stay the night", Chance = 0.5, ChanceStat = "Luck",
				Result = "Best sleep of your life. You wake in a meadow, fully healed.", Effects = { Health = 30, Stress = -10 },
				FailResult = "You wake in a meadow with an empty purse.", FailEffects = { Money = -120 } },
			{ Text = "Trade riddles with the innkeeper", Chance = 0.45, ChanceStat = "Intelligence",
				Result = "She laughs and gives you a charm for luck.", Effects = { Items = { lucky_charm = 1 } },
				FailResult = "She laughs and the inn vanishes around you.", FailEffects = { Stress = 6 } },
			{ Text = "Keep walking", Result = "Somewhere behind you, a fox barks.", Effects = {} },
		},
	},
	pilgrim_monks = {
		Trigger = "Travel", ChainOnly = true, Weight = 2, Repeatable = true,
		Title = "Pilgrim Monks", Text = "A line of barefoot monks walks the same road, chanting softly.",
		Options = {
			{ Text = "Walk and chant with them", Result = "By nightfall your breathing has slowed and deepened.", Effects = { Stats = { QiControl = 8 }, Stress = -8 } },
			{ Text = "Share your food", Result = "They bless your journey.", Effects = { Karma = 2, Money = -10 } },
		},
	},
	stampede = {
		Trigger = "Travel", ChainOnly = true, Weight = 1, Repeatable = true,
		Title = "Spirit Ox Stampede", Text = "The ground shakes. A herd of panicked spirit oxen thunders down the valley toward you.",
		Options = {
			{ Text = "Stand your ground", Chance = 0.35, ChanceStat = "Strength",
				Result = "You turn the lead ox by its horns. The herd follows it away.", Effects = { Stats = { Strength = 12, Vitality = 6 } },
				FailResult = "You are trampled flat.", FailEffects = { Health = -30 } },
			{ Text = "Climb a tree", Chance = 0.7, ChanceStat = "Agility",
				Result = "You watch the herd rumble past beneath you.", Effects = { Stats = { Agility = 6 } },
				FailResult = "The tree goes down with you in it.", FailEffects = { Health = -15 } },
		},
	},

	qinghe_lotus_fair = {
		Title = "The Lotus Fair", Text = "Qinghe's lakes bloom pink and the lotus fair fills every bridge with lanterns.",
		MinAge = 8, MaxAge = 100000, Weight = 0.3, Repeatable = true, Cooldown = 5,
		Requires = { Region = "qinghe" },
		Options = {
			{ Text = "Float a wish lantern", Result = "It drifts all the way to the far shore. A good sign.", Effects = { Happiness = 8, Stats = { Luck = 4 } } },
			{ Text = "Run a food stall", Result = "Lotus root cakes sell out by noon.", Effects = { Money = 150, Stats = { Charisma = 4 } } },
		},
	},
	crimson_fighting_pit = {
		Title = "The Fighting Pit", Text = "Crimson Reach's slums have a sunken pit where anyone can fight for coin.",
		MinAge = 14, MaxAge = 100000, Weight = 0.3, Repeatable = true, Cooldown = 3,
		Requires = { Region = "crimson" },
		Options = {
			{ Text = "Step into the pit", Chance = 0.45, ChanceStat = "Strength",
				Result = "The crowd roars your name.", Effects = { Money = 200, Counters = { Fights = 1 }, Stats = { Strength = 10 } },
				FailResult = "Carried out unconscious.", FailEffects = { Health = -25 } },
			{ Text = "Bet on the underdog", Chance = 0.3, ChanceStat = "Luck",
				Result = "The underdog wins. So do you.", Effects = { Money = 300 },
				FailResult = "The underdog stays down.", FailEffects = { Money = -80 } },
		},
	},
	capital_palace_banquet = {
		Title = "A Palace Banquet", Text = "Through a friend of a friend, you receive an invitation to a minor palace banquet.",
		MinAge = 16, MaxAge = 100000, Weight = 0.2, Repeatable = true, Cooldown = 8,
		Requires = { Region = "capital" },
		Options = {
			{ Text = "Charm the nobles", Chance = 0.45, ChanceStat = "Charisma",
				Result = "A minister asks for your name twice.", Effects = { Stats = { Charisma = 12 }, Money = 300 },
				FailResult = "You use the wrong chopsticks. Everyone sees.", FailEffects = { Happiness = -8, Stress = 6 } },
			{ Text = "Listen to court gossip", Result = "You learn which ministers will fall this year.", Effects = { Stats = { Intelligence = 10 } } },
		},
	},
	kunlun_snow_lotus = {
		Title = "The Snow Lotus", Text = "Above Kunlun's glaciers, a snow lotus blooms once every sixty years.",
		MinAge = 14, MaxAge = 100000, Weight = 0.25, Repeatable = true, Cooldown = 10,
		Requires = { Region = "kunlun" },
		Options = {
			{ Text = "Climb for it", Chance = 0.45, ChanceStat = "Vitality",
				Result = "Its petals taste of ice and eternity.", Effects = { Lifespan = 8, Qi = 0.4 },
				FailResult = "Frostbite and a long fall.", FailEffects = { Health = -30 } },
			{ Text = "Meditate in the thin air", Result = "Your breath turns to mist and then to Qi.", Effects = { Stats = { QiControl = 10 } } },
		},
	},
	marsh_will_o_wisp = {
		Title = "Lights over the Marsh", Text = "Pale lights bob over the black water, drifting deeper into the marsh.",
		MinAge = 10, MaxAge = 100000, Weight = 0.3, Repeatable = true, Cooldown = 4,
		Requires = { Region = "marsh" },
		Options = {
			{ Text = "Follow the lights", Chance = 0.4, ChanceStat = "Luck",
				Result = "They lead you to a drowned shrine full of offerings.", Effects = { Money = 250, Items = { magic_crystal = 1 } },
				FailResult = "They lead you into a sinkhole.", FailEffects = { Health = -20, Stress = 8 } },
			{ Text = "Catch one in a jar", Chance = 0.5, ChanceStat = "Agility",
				Result = "It glows on your shelf for a year.", Effects = { Happiness = 6, Stats = { QiControl = 4 } },
				FailResult = "It burns cold and slips away.", FailEffects = { Health = -5 } },
		},
	},
}

return TravelEventsConfig
