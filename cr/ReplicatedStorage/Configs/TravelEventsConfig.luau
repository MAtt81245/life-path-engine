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
		Title = "Curse User Ambush", Text = "Halfway through an empty underpass, a curtain drops behind you. Masked curse users step out of the dark.",
		Options = {
			{ Text = "Fight through", Chance = 0.5, ChanceStat = "Strength",
				Result = "You scatter them and take their bounty money.", Effects = { Money = 150, Counters = { Fights = 1 }, Stats = { Strength = 8 } },
				FailResult = "They beat you and take your coin.", FailEffects = { Health = -20, Money = -100 } },
			{ Text = "Pay them off", Requires = { MinMoney = 80 }, Result = "They lift the curtain, grinning.", Effects = { Money = -80 } },
			{ Text = "Slip into the side streets", Chance = 0.6, ChanceStat = "Agility", Result = "You lose them in the back alleys.", Effects = { Stats = { Agility = 6 } },
				FailResult = "A cursed blade grazes you as you flee.", FailEffects = { Health = -10 } },
		},
	},
	spirit_caravan = {
		Trigger = "Travel", ChainOnly = true, Weight = 2, Repeatable = true,
		Title = "Night Train Curse Brokers", Text = "On the last train of the night, a carriage of hooded brokers offers you a seat and a look at their wares.",
		Options = {
			{ Text = "Buy a cursed talisman (¥600)", Requires = { MinMoney = 600 }, Result = "The talisman hums with cursed energy.", Effects = { Money = -600, Qi = 0.3 } },
			{ Text = "Trade exorcism stories", Result = "Their tales of Special Grade curses stay with you.", Effects = { Stats = { Charisma = 8 }, Happiness = 6 } },
			{ Text = "Decline politely", Result = "The carriage is empty when you look back.", Effects = {} },
		},
	},
	qi_storm = {
		Trigger = "Travel", ChainOnly = true, Weight = 2, Repeatable = true, Module = "Cultivation",
		Requires = { MinAge = 13 },
		Title = "Cursed Energy Surge", Text = "The sky turns violet. Raw cursed energy leaks from a cracked seal and crackles across the road.",
		Options = {
			{ Text = "Absorb the surge", Chance = 0.45, ChanceStat = "QiControl",
				Result = "You drink the surge and your cursed energy deepens.", Effects = { Qi = 0.6, Stats = { QiControl = 10 } },
				FailResult = "The surge tears through your body.", FailEffects = { Health = -25 } },
			{ Text = "Shelter behind a barrier", Result = "You wait it out, shaken and humbled.", Effects = { Stress = 4 } },
		},
	},
	roadside_shrine = {
		Trigger = "Travel", ChainOnly = true, Weight = 2, Repeatable = true,
		Title = "Forgotten Roadside Shrine", Text = "Moss covers a tiny shrine by the road. Someone still leaves incense to keep a curse sealed.",
		Options = {
			{ Text = "Offer incense and pray", Result = "The seal glows warm. The curse stays asleep.", Effects = { Karma = 2, Alignment = 3, Stress = -6 } },
			{ Text = "Take the offerings", Result = "A few coins richer. Something behind the seal laughs.", Effects = { Money = 60, Alignment = -6, Karma = -1 } },
		},
	},
	wandering_master = {
		Trigger = "Travel", ChainOnly = true, Weight = 1, Repeatable = true, Module = "Masters",
		Title = "A Traveling Sorcerer", Text = "A veteran sorcerer shares the road with you and watches how you walk.",
		Options = {
			{ Text = "Ask for a lesson", Result = "He corrects your cursed energy flow in three words.", Effects = { Proficiency = { Sword = 12, Spear = 6 }, Stats = { QiControl = 6 } } },
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
		Title = "The Dorm Black Market", Text = "In the dormitory basement an upperclassman opens a velvet case of forbidden cursed goods.",
		MinAge = 12, MaxAge = 200, Weight = 0.25, Repeatable = true, Cooldown = 4,
		Requires = { Region = "crimson" },
		Options = {
			{ Text = "Buy a stolen technique scroll (¥1K)", Requires = { MinMoney = 1000 }, Result = "The pages smell of blood and genius.", Effects = { Money = -1000, Proficiency = { Sword = 15, Spear = 15 }, Alignment = -4 } },
			{ Text = "Fence a Sealed Calamity Finger", Requires = { Items = { jade_bracelet = 1 } }, Result = "The upperclassman pays well and asks nothing.", Effects = { Items = { jade_bracelet = -1 }, Money = 2200 } },
			{ Text = "Walk away", Result = "You keep your hands clean.", Effects = { Alignment = 2 } },
		},
	},
	imperial_exam = {
		Title = "The Kyoto Exchange Event", Text = "The Tokyo and Kyoto schools meet for their yearly contest. One performance decides your family's standing.",
		MinAge = 16, MaxAge = 60, Weight = 0.3, Repeatable = true, Cooldown = 3,
		Requires = { Region = "capital" },
		Options = {
			{ Text = "Outsmart the other school", Chance = 0.25, ChanceStat = "Intelligence",
				Result = "You win the event! The higher-ups grant you a post.", Effects = { Money = 3000, Karma = 3, Stats = { Intelligence = 12 }, Flags = { "ImperialScholar" } },
				FailResult = "Kyoto takes the win this year.", FailEffects = { Stress = 8 } },
			{ Text = "Bribe a judge (¥2K)", Requires = { MinMoney = 2000 }, Chance = 0.6, ChanceStat = "Charisma",
				Result = "A suspiciously good result.", Effects = { Money = -2000, Alignment = -8, Flags = { "ImperialScholar" } },
				FailResult = "Caught! Disciplined and fined by the higher-ups.", FailEffects = { Money = -2000, Health = -20, Alignment = -5 } },
			{ Text = "Skip it", Result = "Maybe next time.", Effects = {} },
		},
	},
	orthodox_sect = {
		Title = "Trial of the Cursed Warehouse", Text = "The vault keepers open the cursed warehouse for one day. Sorcerers watch from the shifting stairways.",
		MinAge = 12, MaxAge = 300, Weight = 0.3, Repeatable = true, Cooldown = 5,
		Requires = { Region = "kunlun" },
		Options = {
			{ Text = "Run the shifting stairs", Chance = 0.5, ChanceStat = "Agility",
				Result = "A vault keeper nods. You may study the sealed tools below.", Effects = { Proficiency = { Sword = 20, QiArts = 10 }, Qi = 0.3, Alignment = 4 },
				FailResult = "The barrier spits you out at the entrance, bruised.", FailEffects = { Health = -20 } },
			{ Text = "Watch and learn", Result = "Their cursed tool forms are burned into your memory.", Effects = { Proficiency = { Sword = 8 } } },
		},
	},
	star_relic = {
		Title = "A Relic in the Ruins", Text = "A shard of a sealed cursed object glows in Shinjuku's rubble. Its whisper sounds like your own voice from another life.",
		MinAge = 12, MaxAge = 100000, Weight = 0.3, Repeatable = true, Cooldown = 4,
		Requires = { Region = "ruins" },
		Options = {
			{ Text = "Claim the relic", Chance = 0.55, ChanceStat = "Vitality",
				Result = "The relic accepts you.", Effects = { Items = { ancient_talisman = 1 }, Qi = 0.5, Karma = 2 },
				FailResult = "Residual cursed energy burns your hands.", FailEffects = { Health = -40 } },
			{ Text = "Meditate beside it", Result = "Memories of other lives drift past.", Effects = { Stats = { QiControl = 12 }, Stress = -5 } },
		},
	},
	-- Content expansion (2026-11-02): 5 more road encounters and 5 regional events.
	ghost_taxi = {
		Trigger = "Travel", ChainOnly = true, Weight = 2, Repeatable = true,
		Title = "The Taxi That Takes the Long Way", Text = "Your taxi driver has no reflection, and the meter is counting in years, not yen.",
		Options = {
			{ Text = "Exorcise the driver", Chance = 0.5, ChanceStat = "QiControl",
				Result = "The curse dissolves at a red light. You drive yourself the rest of the way.", Effects = { Stats = { QiControl = 8 }, Counters = { Fights = 1 } },
				FailResult = "It throws you out onto the highway shoulder.", FailEffects = { Health = -12 } },
			{ Text = "Jump out at the next light", Chance = 0.7, ChanceStat = "Agility", Result = "You roll onto the pavement, unhurt.", Effects = { Stats = { Agility = 5 } },
				FailResult = "You scrape your knees badly.", FailEffects = { Health = -6 } },
		},
	},
	lost_child_curse = {
		Trigger = "Travel", ChainOnly = true, Weight = 2, Repeatable = true,
		Title = "A Lost Child at the Rest Stop", Text = "A crying child at a highway rest stop asks you to help find her mother. Her feet do not touch the ground.",
		Options = {
			{ Text = "Help her pass on", Result = "You walk with her until she fades with a smile.", Effects = { Karma = 2, Alignment = 3, Stress = -4 } },
			{ Text = "Exorcise her", Result = "Quick. Efficient. You do not feel good about it.", Effects = { Stats = { QiControl = 5 }, Alignment = -2 } },
		},
	},
	auxiliary_driver = {
		Trigger = "Travel", ChainOnly = true, Weight = 1, Repeatable = true, Requires = { MinRealm = 2 },
		Title = "An Auxiliary Manager's Ride", Text = "A nervous auxiliary manager offers you a lift and a stack of mission briefings to read on the way.",
		Options = {
			{ Text = "Study the briefings", Result = "You learn three new ways curses hide.", Effects = { Stats = { Intelligence = 8 }, Counters = { Knowledge = 2 } } },
			{ Text = "Nap in the back seat", Result = "Best sleep you have had in weeks.", Effects = { Stress = -8, Health = 5 } },
		},
	},
	broker_checkpoint = {
		Trigger = "Travel", ChainOnly = true, Weight = 1, Repeatable = true, Requires = { MinAge = 14 },
		Route = { "arcade", "marsh", "colony" },
		Title = "Curse Broker Checkpoint", Text = "A curse broker's men block the alley and demand a 'passage fee' in cursed objects or cash.",
		Options = {
			{ Text = "Pay ¥150", Requires = { MinMoney = 150 }, Result = "They wave you through with fake smiles.", Effects = { Money = -150 } },
			{ Text = "Break through", Chance = 0.5, ChanceStat = "Strength",
				Result = "Three of them hit the ground. The rest scatter.", Effects = { Counters = { Fights = 1 }, Stats = { Strength = 8 }, Money = 80 },
				FailResult = "They drag you down and empty your pockets.", FailEffects = { Health = -15, Money = -120 } },
		},
	},
	cursed_rain = {
		Trigger = "Travel", ChainOnly = true, Weight = 1, Repeatable = true, Module = "Cultivation", Requires = { MinAge = 13 },
		Title = "Rain That Tastes of Fear", Text = "Black rain falls on the road. Each drop carries a trace of cursed energy from a dying curse far away.",
		Options = {
			{ Text = "Stand in it and absorb", Chance = 0.5, ChanceStat = "Vitality",
				Result = "Your cursed energy grows a little denser.", Effects = { Qi = 0.2, Stats = { Vitality = 5 } },
				FailResult = "You catch a cursed fever for a week.", FailEffects = { Health = -12, Stress = 5 } },
			{ Text = "Wait it out under a bridge", Result = "You watch the road steam until it stops.", Effects = { Stress = -3 } },
		},
	},

	-- Regional events (yearly, Requires = { Region = id }).
	obon_swarm = {
		Title = "Obon Night Swarm", Text = "Lanterns float up the cemetery hill, and with them a swarm of tiny curses hungry for grief.",
		MinAge = 10, MaxAge = 300, Weight = 0.35, Repeatable = true, Cooldown = 3,
		Requires = { Region = "hills" },
		Options = {
			{ Text = "Clear the swarm", Chance = 0.6, ChanceStat = "Strength",
				Result = "You fight until dawn. The graves fall quiet.", Effects = { Stats = { Strength = 8, Vitality = 6 }, Counters = { Fights = 1 } },
				FailResult = "Too many. You retreat with bites up both arms.", FailEffects = { Health = -12 } },
			{ Text = "Light incense with the families", Result = "Less grief, fewer curses. Simple.", Effects = { Karma = 1, Stress = -6 } },
		},
	},
	arcade_contract = {
		Title = "A Contract in the Arcade", Text = "A pawn-shop owner slides you an envelope: ¥800 to clear a curse from a karaoke booth, no questions asked.",
		MinAge = 14, MaxAge = 300, Weight = 0.35, Repeatable = true, Cooldown = 3,
		Requires = { Region = "arcade" },
		Options = {
			{ Text = "Take the job", Chance = 0.6, ChanceStat = "QiControl",
				Result = "One curse, one song and one envelope later, you walk out richer.", Effects = { Money = 800, Stats = { QiControl = 5 } },
				FailResult = "The curse wrecks the booth and the owner refuses to pay.", FailEffects = { Health = -10 } },
			{ Text = "Refuse shady work", Result = "He shrugs and calls someone else.", Effects = { Alignment = 2 } },
		},
	},
	archive_night_shift = {
		Title = "Night Shift in the Archives", Text = "The liaison office needs someone to sort decades of unsorted mission reports before an audit.",
		MinAge = 14, MaxAge = 300, Weight = 0.35, Repeatable = true, Cooldown = 4,
		Requires = { Region = "window_office" },
		Options = {
			{ Text = "Read every report", Result = "Patterns appear: where curses gather, and why.", Effects = { Stats = { Intelligence = 10 }, Counters = { Knowledge = 3 } } },
			{ Text = "Sort them fast and leave", Result = "Overtime pay is overtime pay.", Effects = { Money = 300 } },
		},
	},
	barrier_monks = {
		Title = "A Week of Silence", Text = "The temple monks offer to teach you their barrier, if you can keep silent for seven days.",
		MinAge = 14, MaxAge = 300, Weight = 0.3, Repeatable = true, Cooldown = 5,
		Requires = { Region = "hiei" },
		Options = {
			{ Text = "Keep the silence", Chance = 0.55, ChanceStat = "Intelligence",
				Result = "On the seventh day the barrier opens to your hands.", Effects = { Proficiency = { QiArts = 18 }, Stress = -10, Items = { sealing_beads = 1 } },
				FailResult = "You crack on day four. The monks smile and send you home.", FailEffects = { Stress = 4 } },
			{ Text = "Just help sweep the temple", Result = "Calm, steady work.", Effects = { Stress = -6, Karma = 1 } },
		},
	},
	colony_points = {
		Title = "Points on Your Head", Text = "Inside the colony, a stranger in an old-fashioned kimono says your head is worth five points.",
		MinAge = 16, MaxAge = 300, Weight = 0.35, Repeatable = true, Cooldown = 3,
		Requires = { Region = "colony" },
		Options = {
			{ Text = "Fight him", Chance = 0.45, ChanceStat = "Strength",
				Result = "An ancient sorcerer falls. His points, and some of his secrets, are yours.", Effects = { Qi = 0.4, Counters = { Fights = 1 }, Stats = { Strength = 10 }, Items = { dragon_bone_blade = 1 } },
				FailResult = "He nearly takes your head. You escape over the rooftops.", FailEffects = { Health = -30 } },
			{ Text = "Bargain with information", Chance = 0.5, ChanceStat = "Charisma",
				Result = "He lets you go for news of the outside world.", Effects = { Stats = { Charisma = 8 } },
				FailResult = "He is not interested in talk.", FailEffects = { Health = -15 } },
		},
	},
	winter_sea_curse = {
		Title = "Drowned Sailors' Curse", Text = "A curse made of seaweed and old fishing nets crawls onto the beach, groaning sailors' names.",
		MinAge = 14, MaxAge = 300, Weight = 0.3, Repeatable = true, Cooldown = 4,
		Requires = { Region = "coast" },
		Options = {
			{ Text = "Fight it in the surf", Chance = 0.55, ChanceStat = "Agility",
				Result = "You drag it back to the waves where it belongs.", Effects = { Stats = { Agility = 8 }, Counters = { Fights = 1 } },
				FailResult = "It pulls you under. You come up coughing.", FailEffects = { Health = -14 } },
			{ Text = "Ask a retired sorcerer for help", Result = "The old woman ends it with one strike, then teaches you how.", Effects = { Proficiency = { Spear = 10 }, Stats = { Intelligence = 4 } } },
		},
	},
}

return TravelEventsConfig
