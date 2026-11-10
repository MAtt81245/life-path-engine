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
		Requires = { MinAge = 13 }, -- lethal encounters only from the teen years
		Title = "Hollow Ambush", Text = "Halfway down an empty road, the air tears open. A masked Hollow drops out of the sky.",
		Options = {
			{ Text = "Fight through", Chance = 0.5, ChanceStat = "Strength",
				Result = "You cut through its mask and collect the bounty.", Effects = { Money = 150, Counters = { Fights = 1 }, Stats = { Strength = 8 } },
				FailResult = "They beat you and take your coin.", FailEffects = { Health = -20, Money = -100 } },
			{ Text = "Throw it a soul candy", Requires = { MinMoney = 80 }, Result = "It chases the candy and forgets you.", Effects = { Money = -80 } },
			{ Text = "Flash-step away", Chance = 0.6, ChanceStat = "Agility", Result = "You vanish before it can turn.", Effects = { Stats = { Agility = 6 } },
				FailResult = "Its claws rake your back as you flee.", FailEffects = { Health = -10 } },
		},
	},
	spirit_caravan = {
		Trigger = "Travel", ChainOnly = true, Weight = 2, Repeatable = true,
		Title = "The Traveling Spirit Peddlers", Text = "A cart of masked peddlers from Soul Society offers you a seat and a look at their wares.",
		Options = {
			{ Text = "Buy a soul candy (Kan 600)", Requires = { MinMoney = 600 }, Result = "The candy fizzes with reiatsu.", Effects = { Money = -600, Qi = 0.3 } },
			{ Text = "Trade Hollow stories", Result = "Their tales of Menos and Espada stay with you.", Effects = { Stats = { Charisma = 8 }, Happiness = 6 } },
			{ Text = "Decline politely", Result = "The cart is gone when you look back.", Effects = {} },
		},
	},
	qi_storm = {
		Trigger = "Travel", ChainOnly = true, Weight = 2, Repeatable = true, Module = "Cultivation",
		Requires = { MinAge = 13 },
		Title = "Reiatsu Storm", Text = "The sky turns pale blue. Raw spiritual pressure from a distant battle crackles across the road.",
		Options = {
			{ Text = "Absorb the surge", Chance = 0.45, ChanceStat = "QiControl",
				Result = "You drink the storm and your Reiatsu deepens.", Effects = { Qi = 0.6, Stats = { QiControl = 10 } },
				FailResult = "The pressure crushes you to your knees.", FailEffects = { Health = -25 } },
			{ Text = "Shelter behind a Bakudo wall", Result = "You wait it out, shaken and humbled.", Effects = { Stress = 4 } },
		},
	},
	roadside_shrine = {
		Trigger = "Travel", ChainOnly = true, Weight = 2, Repeatable = true,
		Title = "Forgotten Roadside Shrine", Text = "Moss covers a tiny shrine by the road. A lonely Plus spirit still waits beside it.",
		Options = {
			{ Text = "Perform a soul burial", Result = "The spirit smiles and passes on to Soul Society.", Effects = { Karma = 2, Alignment = 3, Stress = -6 } },
			{ Text = "Take the offerings", Result = "A few coins richer. The spirit's chain grows shorter.", Effects = { Money = 60, Alignment = -6, Karma = -1 } },
		},
	},
	wandering_master = {
		Trigger = "Travel", ChainOnly = true, Weight = 1, Repeatable = true, Module = "Masters",
		Title = "A Traveling Soul Reaper", Text = "A veteran Soul Reaper shares the road with you and watches how you walk.",
		Options = {
			{ Text = "Ask for a lesson", Result = "He corrects your grip and your reiatsu in three words.", Effects = { Proficiency = { Sword = 12, Spear = 6 }, Stats = { QiControl = 6 } } },
			{ Text = "Challenge him", Chance = 0.2, ChanceStat = "Strength", Result = "He laughs and calls you a prodigy.", Effects = { Stats = { Strength = 15 }, Karma = 2 },
				FailResult = "One finger. You are on the ground.", FailEffects = { Health = -10, Happiness = -4 } },
		},
	},
	rival_on_road = {
		Trigger = "Travel", ChainOnly = true, Weight = 1, Repeatable = true, Module = "Relationships",
		Title = "Crossing Paths", Text = "At the ferry crossing you come face to face with {name}.",
		Target = { Category = "Rival" },
		Options = {
			{ Text = "Fight on the riverbank", Chance = 0.5, ChanceStat = "Strength", Result = "{name} falls into the river.", Effects = { Counters = { Fights = 1 }, Affection = -10, Happiness = 8 },
				FailResult = "{name} sends you into the river.", FailEffects = { Health = -15, Happiness = -6 } },
			{ Text = "Share the ferry in silence", Result = "The crossing has never felt so long.", Effects = { Affection = 5 } },
		},
	},

	-- Regional events -----------------------------------------------------
	black_market = {
		Title = "The Back Room of the Shop", Text = "Below the candy shelves, the shopkeeper slides open a case of goods Soul Society banned years ago.",
		MinAge = 12, MaxAge = 200, Weight = 0.25, Repeatable = true, Cooldown = 4,
		Requires = { Region = "crimson" },
		Options = {
			{ Text = "Buy a forbidden Kido scroll (Kan 1K)", Requires = { MinMoney = 1000 }, Result = "The pages smell of ozone and genius.", Effects = { Money = -1000, Proficiency = { Sword = 15, Spear = 15 }, Alignment = -4 } },
			{ Text = "Sell a Sealed Spirit Ribbon", Requires = { Items = { jade_bracelet = 1 } }, Result = "The shopkeeper pays well and asks nothing.", Effects = { Items = { jade_bracelet = -1 }, Money = 2200 } },
			{ Text = "Walk away", Result = "You keep your hands clean.", Effects = { Alignment = 2 } },
		},
	},
	imperial_exam = {
		Title = "The Seated Officer Exam", Text = "The divisions hold their yearly promotion exam. One performance decides your family's standing.",
		MinAge = 16, MaxAge = 60, Weight = 0.3, Repeatable = true, Cooldown = 3,
		Requires = { Region = "capital" },
		Options = {
			{ Text = "Ace the written Kido exam", Chance = 0.25, ChanceStat = "Intelligence",
				Result = "Top marks! A captain offers you a seat.", Effects = { Money = 3000, Karma = 3, Stats = { Intelligence = 12 }, Flags = { "ImperialScholar" } },
				FailResult = "Your name is not on the list this year.", FailEffects = { Stress = 8 } },
			{ Text = "Bribe an examiner (Kan 2K)", Requires = { MinMoney = 2000 }, Chance = 0.6, ChanceStat = "Charisma",
				Result = "A suspiciously good result.", Effects = { Money = -2000, Alignment = -8, Flags = { "ImperialScholar" } },
				FailResult = "Caught! The Central 46 fines you.", FailEffects = { Money = -2000, Health = -20, Alignment = -5 } },
			{ Text = "Skip it", Result = "Maybe next time.", Effects = {} },
		},
	},
	orthodox_sect = {
		Title = "The Academy Entrance Trial", Text = "Shin'o Academy opens its gates for one day. Instructors watch from the training yard walls.",
		MinAge = 12, MaxAge = 300, Weight = 0.3, Repeatable = true, Cooldown = 5,
		Requires = { Region = "kunlun" },
		Options = {
			{ Text = "Run the Hoho course", Chance = 0.5, ChanceStat = "Agility",
				Result = "An instructor nods. You may sit in on the advanced class.", Effects = { Proficiency = { Sword = 20, QiArts = 10 }, Qi = 0.3, Alignment = 4 },
				FailResult = "You trip on the last step in front of everyone.", FailEffects = { Health = -20 } },
			{ Text = "Watch and learn", Result = "Their Zanjutsu forms are burned into your memory.", Effects = { Proficiency = { Sword = 8 } } },
		},
	},
	star_relic = {
		Title = "A Relic in the Bankai Cave", Text = "A shard of an old Hogyoku glows in the hot-spring steam. Its whisper sounds like your own voice from another life.",
		MinAge = 12, MaxAge = 100000, Weight = 0.3, Repeatable = true, Cooldown = 4,
		Requires = { Region = "ruins" },
		Options = {
			{ Text = "Claim the relic", Chance = 0.55, ChanceStat = "Vitality",
				Result = "The relic accepts you.", Effects = { Items = { ancient_talisman = 1 }, Qi = 0.5, Karma = 2 },
				FailResult = "Its spiritual pressure burns your hands.", FailEffects = { Health = -40 } },
			{ Text = "Meditate beside it", Result = "Memories of other lives drift past.", Effects = { Stats = { QiControl = 12 }, Stress = -5 } },
		},
	},
	arrancar_raid = {
		Title = "Arrancar Raid", Text = "The fake town's barrier shudders. Three Arrancar step through a Garganta above the warehouse.",
		MinAge = 13, MaxAge = 100000, Weight = 0.3, Repeatable = true, Cooldown = 4,
		Requires = { Region = "fake_karakura" },
		Options = {
			{ Text = "Fight them head-on", Chance = 0.45, ChanceStat = "Strength",
				Result = "You drive them back through the Garganta.", Effects = { Qi = 0.4, Counters = { Fights = 1 }, Stats = { Strength = 15 } },
				FailResult = "A Cero clips you before they retreat.", FailEffects = { Health = -35 } },
			{ Text = "Put on your Hollow mask", Result = "Eleven seconds of terrifying power. They flee.", Effects = { Qi = 0.6, Alignment = -10 } },
			{ Text = "Hold the barrier", Result = "The town holds. Your arms shake for a week.", Effects = { Stats = { Vitality = 12 } } },
		},
	},
	menos_hunt = {
		Title = "Hunting in the Forest of Menos", Text = "Below the quartz trees an Adjuchas circles a pack of Gillian, devouring the weakest.",
		MinAge = 13, MaxAge = 100000, Weight = 0.3, Repeatable = true, Cooldown = 4,
		Requires = { Region = "hueco_mundo" },
		Options = {
			{ Text = "Hunt the Adjuchas", Chance = 0.4, ChanceStat = "QiControl",
				Result = "Its reiatsu scatters into the dark and some of it into you.", Effects = { Qi = 0.6, Stats = { QiControl = 15 } },
				FailResult = "The pack turns on you.", FailEffects = { Health = -45 } },
			{ Text = "Slip past the swarm", Result = "You leave the forest alive, which counts.", Effects = { Stress = 5 } },
		},
	},
	espada_duel = {
		Title = "An Espada's Challenge", Text = "A numbered Espada blocks the corridor of Las Noches and draws a blade of pure reiatsu.",
		MinAge = 13, MaxAge = 100000, Weight = 0.3, Repeatable = true, Cooldown = 4,
		Requires = { Region = "las_noches" },
		Options = {
			{ Text = "Accept the duel", Chance = 0.35, ChanceStat = "Strength",
				Result = "Your Bankai shatters the Resurreccion.", Effects = { Qi = 0.8, Counters = { Fights = 1 }, Karma = 2 },
				FailResult = "You crawl out of the corridor barely alive.", FailEffects = { Health = -60 } },
			{ Text = "Retreat through the sand", Result = "You live to fight another day.", Effects = { Stress = 6 } },
		},
	},
	royal_audience = {
		Title = "An Audience at the Royal Palace", Text = "Squad Zero receives you on a floating palace above the clouds.",
		MinAge = 13, MaxAge = 100000, Weight = 0.3, Repeatable = true, Cooldown = 4,
		Requires = { Region = "reiokyu" },
		Options = {
			{ Text = "Kneel before the Royal Guard", Result = "They bless your soul for the trials ahead.", Effects = { Qi = 1, Karma = 3, Lifespan = 10 } },
			{ Text = "Ask for a lesson in true names", Result = "The monk writes your name in his book, and you understand it for the first time.", Effects = { Stats = { QiControl = 20 }, Counters = { Knowledge = 3 } } },
		},
	},
	-- ===== Content expansion (2026-11-02): 7 more road encounters, 7 regional events =====
	broken_senkaimon = {
		Trigger = "Travel", ChainOnly = true, Weight = 2, Repeatable = true,
		Title = "A Flickering Senkaimon", Text = "The gate you are crossing flickers. A family of souls is stuck halfway, half in one world and half in another.",
		Options = {
			{ Text = "Stabilise the gate", Chance = 0.55, ChanceStat = "Intelligence",
				Result = "The gate steadies. Everyone crosses safely.", Effects = { Stats = { Intelligence = 6 }, Alignment = 4 },
				FailResult = "The backlash throws you across the platform.", FailEffects = { Health = -15 } },
			{ Text = "Pull them through", Chance = 0.45, ChanceStat = "Strength",
				Result = "You drag them out just as it collapses.", Effects = { Stats = { Strength = 8 }, Alignment = 3 },
				FailResult = "You lose your footing in the Dangai for a terrifying minute.", FailEffects = { Health = -12, Stress = 8 } },
			{ Text = "Wait for the next gate", Result = "A day lost in a cold waiting room.", Effects = { Stress = 3 } },
		},
	},
	lost_child_road = {
		Trigger = "Travel", ChainOnly = true, Weight = 2, Repeatable = true,
		Title = "A Lost Child Soul", Text = "A small soul sits crying at a crossroads, its chain still attached to nothing.",
		Options = {
			{ Text = "Perform a gentle Konso", Requires = { MinRealm = 2 }, Result = "It smiles and drifts toward Soul Society.", Effects = { Karma = 2, Alignment = 5 } },
			{ Text = "Walk it to the nearest Soul Reaper", Result = "The officer thanks you and gives you a few coins.", Effects = { Money = 60, Alignment = 4 } },
			{ Text = "Point it in the right direction", Result = "You hope it makes it.", Effects = { Stress = 2 } },
		},
	},
	cat_shapeshifter = {
		Trigger = "Travel", ChainOnly = true, Weight = 1, Repeatable = true,
		Title = "A Talking Black Cat", Text = "A black cat with golden eyes falls into step beside you. \"Long walk. Got any fish?\"",
		Options = {
			{ Text = "Share your lunch", Chance = 0.5, ChanceStat = "Luck",
				Result = "It shows you a shortcut no map has. You arrive refreshed.", Effects = { Health = 20, Stress = -8 },
				FailResult = "It eats everything and vanishes.", FailEffects = { Money = -20 } },
			{ Text = "Race it", Chance = 0.35, ChanceStat = "Agility",
				Result = "You lose, badly, but it laughs and teaches you a step.", Effects = { Stats = { Agility = 10 } },
				FailResult = "It is gone before you take a step.", FailEffects = { Stress = 4 } },
			{ Text = "Ignore it", Result = "It looks mildly offended.", Effects = {} },
		},
	},
	pilgrim_monks = {
		Trigger = "Travel", ChainOnly = true, Weight = 2, Repeatable = true,
		Title = "Konso Pilgrims", Text = "A line of robed pilgrims walks the same road, ringing small bells for wandering souls.",
		Options = {
			{ Text = "Walk and chant with them", Result = "By nightfall your breathing has slowed and deepened.", Effects = { Stats = { QiControl = 8 }, Stress = -8 } },
			{ Text = "Share your food", Result = "They bless your journey.", Effects = { Karma = 2, Money = -10 } },
		},
	},
	hollow_swarm = {
		Trigger = "Travel", ChainOnly = true, Weight = 1, Repeatable = true,
		Title = "A Swarm of Lesser Hollows", Text = "The ground shakes. A dozen small masked Hollows pour out of a fissure toward you.",
		Options = {
			{ Text = "Stand and fight", Chance = 0.35, ChanceStat = "Strength",
				Result = "You cut through them until the fissure seals.", Effects = { Stats = { Strength = 12, Vitality = 6 }, Counters = { Fights = 1 } },
				FailResult = "They overwhelm you before help comes.", FailEffects = { Health = -30 } },
			{ Text = "Shunpo away", Chance = 0.7, ChanceStat = "Agility",
				Result = "Three steps and they are far behind you.", Effects = { Stats = { Agility = 6 } },
				FailResult = "One catches your ankle.", FailEffects = { Health = -15 } },
		},
	},
	quincy_traveler = {
		Trigger = "Travel", ChainOnly = true, Weight = 1, Repeatable = true,
		Title = "A Stranger with a Bow of Light", Text = "A traveller in white shares your road. When a Hollow appears, a bow of blue light forms in their hand.",
		Options = {
			{ Text = "Fight beside them", Chance = 0.5, ChanceStat = "Agility",
				Result = "The Hollow falls between your blade and their arrows. They nod respectfully.", Effects = { Counters = { Fights = 1 }, Stats = { Agility = 8 } },
				FailResult = "An arrow grazes you. \"Move faster next time.\"", FailEffects = { Health = -12 } },
			{ Text = "Ask about their power", Result = "They explain how they gather reishi from the air. Fascinating.", Effects = { Stats = { Intelligence = 8, QiControl = 4 } } },
		},
	},
	tea_stall_rumors = {
		Trigger = "Travel", ChainOnly = true, Weight = 2, Repeatable = true,
		Title = "Rumours at the Tea Stall", Text = "At a roadside tea stall, off-duty officers gossip about which captain is sleeping in again.",
		Options = {
			{ Text = "Buy them a round", Result = "They tell you more than they should.", Effects = { Money = -30, Stats = { Charisma = 8 } } },
			{ Text = "Just listen", Result = "You learn the patrol routes for the next month.", Effects = { Stats = { Intelligence = 6 } } },
		},
	},

	karakura_river_lanterns = {
		Title = "Lanterns on the River", Text = "Once a year the riverbank fills with floating lanterns for the dead. Some of the dead come to watch.",
		MinAge = 6, MaxAge = 100000, Weight = 0.3, Repeatable = true, Cooldown = 5,
		Requires = { Region = "karakura_river" },
		Options = {
			{ Text = "Float a lantern", Result = "A ghost beside you whispers thanks.", Effects = { Happiness = 8, Karma = 1 } },
			{ Text = "Run a snack stall", Result = "Sold out by nightfall.", Effects = { Money = 150, Stats = { Charisma = 4 } } },
		},
	},
	naruki_arcade_duel = {
		Title = "The Arcade Champion", Text = "A Naruki City arcade legend challenges anyone to beat their fighting-game record.",
		MinAge = 10, MaxAge = 100000, Weight = 0.3, Repeatable = true, Cooldown = 3,
		Requires = { Region = "naruki" },
		Options = {
			{ Text = "Take the challenge", Chance = 0.45, ChanceStat = "Agility",
				Result = "New record. A crowd chants your initials.", Effects = { Stats = { Agility = 10 }, Happiness = 10 },
				FailResult = "Perfect KO. Everyone saw.", FailEffects = { Happiness = -6 } },
			{ Text = "Bet on the champion", Chance = 0.4, ChanceStat = "Luck",
				Result = "Easy money.", Effects = { Money = 200 },
				FailResult = "The champion has an off day.", FailEffects = { Money = -80 } },
		},
	},
	inner_rukon_festival = {
		Title = "A District Rice Festival", Text = "The inner districts celebrate the harvest with drums, dancing and far too much sake.",
		MinAge = 8, MaxAge = 100000, Weight = 0.3, Repeatable = true, Cooldown = 5,
		Requires = { Region = "inner_rukon" },
		Options = {
			{ Text = "Join the drummers", Result = "Your arms ache for days. Worth it.", Effects = { Stats = { Strength = 8 }, Happiness = 8 } },
			{ Text = "Help the elders cook", Result = "Everyone in the district knows your name by night.", Effects = { Stats = { Charisma = 8 }, Alignment = 3 } },
		},
	},
	kido_hall_archives = {
		Title = "The Restricted Shelf", Text = "In the Kido Corps archive, a shelf of forbidden scrolls stands unguarded for one careless minute.",
		MinAge = 14, MaxAge = 100000, Weight = 0.25, Repeatable = true, Cooldown = 8,
		Requires = { Region = "kido_hall" },
		Options = {
			{ Text = "Read one scroll", Chance = 0.5, ChanceStat = "Intelligence",
				Result = "One incantation. It changes how you see Kido forever.", Effects = { Stats = { Intelligence = 12, QiControl = 8 } },
				FailResult = "A ward triggers. You spend a night explaining yourself.", FailEffects = { Stress = 10, Alignment = -3 } },
			{ Text = "Report the lapse", Result = "The archivist is grateful and lends you a book.", Effects = { Counters = { Knowledge = 2 }, Alignment = 3 } },
		},
	},
	relief_gardens_herbs = {
		Title = "Night Herbs in the Relief Gardens", Text = "The Relief Station gardens bloom with moon-herbs only at midnight.",
		MinAge = 10, MaxAge = 100000, Weight = 0.3, Repeatable = true, Cooldown = 4,
		Requires = { Region = "relief_gardens" },
		Options = {
			{ Text = "Gather herbs", Result = "Your basket glows faintly.", Effects = { Items = { healing_salve = 2 } } },
			{ Text = "Meditate among the flowers", Result = "Your breathing slows to match the garden.", Effects = { Stress = -10, Stats = { QiControl = 6 } } },
		},
	},
	dangai_cleaner = {
		Title = "The Cleaner Approaches", Text = "A rumbling wall of light sweeps down the Dangai corridor toward you. It erases everything it touches.",
		MinAge = 14, MaxAge = 100000, Weight = 0.25, Repeatable = true, Cooldown = 6,
		Requires = { Region = "dangai" },
		Options = {
			{ Text = "Outrun it", Chance = 0.5, ChanceStat = "Agility",
				Result = "You dive through a side gate as it passes.", Effects = { Stats = { Agility = 12 } },
				FailResult = "It clips your heel. Part of your sandal no longer exists.", FailEffects = { Health = -25 } },
			{ Text = "Cut a gap in the corridor", Chance = 0.4, ChanceStat = "QiControl",
				Result = "A clean slice of space. The Cleaner flows around you.", Effects = { Stats = { QiControl = 12 }, Proficiency = { Sword = 6 } },
				FailResult = "Your cut barely scratches the corridor wall.", FailEffects = { Health = -20 } },
		},
	},
	white_dunes_menos = {
		Title = "Something Huge Under the Sand", Text = "The white dunes ripple. A Menos rises from the sand, mouth already glowing red.",
		MinAge = 14, MaxAge = 100000, Weight = 0.25, Repeatable = true, Cooldown = 5,
		Requires = { Region = "menos_sands" },
		Options = {
			{ Text = "Strike its mask", Chance = 0.4, ChanceStat = "Strength",
				Result = "The mask splits and the giant crumbles into reishi.", Effects = { Counters = { Fights = 1 }, Qi = 0.2, Stats = { Strength = 10 } },
				FailResult = "Its Cero scorches your side.", FailEffects = { Health = -30 } },
			{ Text = "Bury yourself in the sand", Chance = 0.6, ChanceStat = "Vitality",
				Result = "It passes over you, unaware.", Effects = { Stats = { Vitality = 6 } },
				FailResult = "It smells you anyway.", FailEffects = { Health = -15 } },
		},
	},
}

return TravelEventsConfig
