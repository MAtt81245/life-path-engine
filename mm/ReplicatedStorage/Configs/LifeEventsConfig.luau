--[[
	Cultivation and fate events (Xianxia path). Same format as YearlyEventsConfig;
	both pools are evaluated by LifeEventsEngine on every birthday.
]]

local LifeEventsConfig = {}

LifeEventsConfig.Events = {
	-- Bloodline-exclusive events (bloodlines come from Wheel of Reincarnation spins).
	clan_elders = {
		Title = "Summons of the Elders",
		Text = "The elders of your ancient clan call you to the ancestral hall.",
		MinAge = 12, MaxAge = 40, Weight = 0.5,
		Requires = { Race = "AncientClan" },
		Options = {
			{ Text = "Study the clan archives", Result = "Generations of insight fill your mind.", Effects = { Stats = { Intelligence = 25, QiControl = 15 }, Qi = 0.5 } },
			{ Text = "Accept the clan's stipend", Result = "The treasury opens for its heir.", Effects = { Money = 5000 } },
		},
	},

	primordial_awakening = {
		Title = "Primordial Awakening",
		Text = "Something ancient in your blood wakes. The sky darkens over your village.",
		MinAge = 10, MaxAge = 30, Weight = 0.6,
		Requires = { Race = { "ChaosSovereign", "VoidWalker", "HeavenlyDemon" } },
		Options = {
			{ Text = "Embrace it", Result = "Power floods your meridians.", Effects = { Qi = 1, Stats = { QiControl = 30 }, Lifespan = 20 } },
			{ Text = "Seal it away", Result = "Calm returns, and with it a deeper focus.", Effects = { Stress = -20, Stats = { Intelligence = 20 }, Karma = 3 } },
		},
	},

	spirit_root = {
		Title = "The Spirit Root Stone",
		Text = "A village elder places a translucent stone before you. \"Touch it, child, and we shall see if Heaven has blessed you.\"",
		MinAge = 6, MaxAge = 6, Weight = 1,
		Options = {
			{ Text = "Rest your hand calmly", Result = "The stone glows a soft blue. You have potential.", Effects = { Qi = 0.5, Karma = 1, Stats = { QiControl = 8 }, Flags = { "SpiritRoot" } } },
			{ Text = "Force your energy into it", Chance = 0.5,
				Result = "The stone erupts with light! The elders whisper your name.", Effects = { Qi = 1.5, Alignment = -2, Flags = { "SpiritRoot" } },
				FailResult = "The stone cracks and strikes back, but your meridians open.", FailEffects = { Health = -15, Flags = { "SpiritRoot" } } },
			{ Text = "Refuse and go play", Result = "The elder sighs; your Spirit Root wakes anyway, slowly.", Effects = { Happiness = 10, Lifespan = 2, Flags = { "SpiritRoot" } } },
		},
	},

	body_or_mind = {
		Title = "Body or Mind",
		Text = "You turn 14. The blacksmith offers you work at his forge; the temple monk offers meditation beneath the frozen waterfall.",
		MinAge = 14, MaxAge = 14, Weight = 1,
		Options = {
			{ Text = "Temper your body at the forge", Result = "Your arms turn to iron. Pain is your teacher.", Effects = { Stats = { Strength = 25, Vitality = 20 }, MaxHealth = 20 } },
			{ Text = "Meditate under the waterfall", Result = "The icy water clears your mind. Qi begins to flow.", Effects = { Qi = 1, Stats = { QiControl = 25 }, Alignment = 5 } },
		},
	},

	sect_recruitment = {
		Title = "The Sects Are Recruiting",
		Text = "At 20, two sects arrive: the righteous Azure Cloud Sect and the ruthless Blood Lotus Sect.",
		MinAge = 20, MaxAge = 20, Weight = 1,
		Options = {
			{ Text = "Train with the Azure Cloud", Result = "Discipline strengthens your foundation.", Effects = { Qi = 1, Stats = { Strength = 10, QiControl = 10 }, Alignment = 10 } },
			{ Text = "Train with the Blood Lotus", Result = "Blood techniques speed up your cultivation... at a price.", Effects = { Qi = 2.5, Health = -10, Alignment = -20 } },
			{ Text = "Stay a wandering cultivator", Result = "No master, no chains. The world is your sect.", Effects = { Karma = 2, Lifespan = 5, Stats = { Agility = 12 } } },
		},
	},

	bandit_ambush = {
		Title = "Ambush on the Road",
		Text = "A bandit with a rusty sword blocks your way. \"Your spirit stones or your life.\"",
		MinAge = 18, MaxAge = 60, Weight = 0.12,
		Options = {
			{ Text = "Fight", Chance = 0.45, ChanceStat = "Strength",
				Result = "You defeat him and learn from the fight.", Effects = { Qi = 0.4, Counters = { Fights = 1 }, Proficiency = { Sword = 10 } },
				FailResult = "He wounds you badly before fleeing.", FailEffects = { Health = -30 } },
			{ Text = "Hand over your stones", Result = "You lose resources but keep your life.", Effects = { Qi = -0.5 } },
			{ Text = "Persuade him", Chance = 0.35, ChanceStat = "Charisma",
				Result = "He kneels in tears and swears to change.", Effects = { Karma = 4, Alignment = 10 },
				FailResult = "He laughs and stabs you.", FailEffects = { Health = -15, Qi = -0.3 } },
		},
	},

	immortal_cave = {
		Title = "The Immortal's Cave",
		Text = "Chasing a white fox, you discover a cave sealed with ancient runes. Something powerful sleeps inside.",
		MinAge = 22, MaxAge = 400, Weight = 0.06,
		Options = {
			{ Text = "Enter and claim the legacy", Chance = 0.45, ChanceStat = "QiControl",
				Result = "You inherit the legacy of a fallen immortal, and a strange talisman.", Effects = { Qi = 5, Lifespan = 20, Items = { ancient_talisman = 1 },
					Delayed = { InYears = 5, Text = "The immortal's legacy finally awakens inside your dantian.", Effects = { Qi = 3, Lifespan = 10 } } },
				FailResult = "The cave's traps nearly kill you.", FailEffects = { Health = -50 } },
			{ Text = "Seal it and report it", Result = "The elders thank you and promise a reward.", Effects = { Karma = 5, Alignment = 10,
				FollowUp = { Id = "sect_reward", InYears = 1 } } },
			{ Text = "Sell the map", Result = "A merchant pays well for your silence.", Effects = { Money = 3000, Alignment = -5 } },
		},
	},

	sect_tournament = {
		Title = "The Grand Tournament",
		Text = "The disciple tournament begins. Your opponent is an arrogant genius from the North Pavilion.",
		MinAge = 18, MaxAge = 120, Weight = 0.1, MinRealm = 2,
		Options = {
			{ Text = "Fight with everything", Chance = 0.4, ChanceStat = "Strength",
				Result = "Victory! You receive a pill from the treasury.", Effects = { Qi = 3, Karma = 1, Counters = { Fights = 1 } },
				FailResult = "You fall in front of hundreds of eyes.", FailEffects = { Health = -35 } },
			{ Text = "Yield with honor", Result = "Your humility impresses an elder.", Effects = { Alignment = 5, Karma = 1, Qi = 0.5 } },
			{ Text = "Poison his tea", Chance = 0.7,
				Result = "An easy win. Nobody suspects... yet.", Effects = { Qi = 3, Alignment = -25,
					FollowUp = { Id = "poison_exposed", InYears = 3 } },
				FailResult = "You are caught, flogged and expelled.", FailEffects = { Health = -20, Alignment = -30, Karma = -5 } },
		},
	},

	suspicious_pill = {
		Title = "A Suspicious Elixir",
		Text = "A wandering alchemist offers you a reddish pill. \"It will take you to the next level... or the next world.\"",
		MinAge = 18, MaxAge = 2000, Weight = 0.06, Repeatable = true, Cooldown = 8,
		Options = {
			{ Text = "Swallow it", Chance = 0.5,
				Result = "A wave of pure Qi floods your meridians.", Effects = { Qi = 2 },
				FailResult = "Poison. You cough blood for days.", FailEffects = { Health = -40 } },
			{ Text = "Analyze it carefully", Requires = { Counters = { Knowledge = 15 } },
				Result = "Your studies let you extract its safe essence.", Effects = { Qi = 1, Stats = { Intelligence = 8 } } },
			{ Text = "Refuse", Result = "The alchemist shrugs and leaves.", Effects = {} },
		},
	},

	heart_demon = {
		Title = "The Heart Demon",
		Text = "During meditation your regrets take shape. A shadow with your face whispers your failures.",
		MinAge = 30, MaxAge = 5000, Weight = 0.07, MinRealm = 3,
		Options = {
			{ Text = "Face it", Chance = 0.45, ChanceStat = "QiControl",
				Result = "You shatter the shadow. Your Dao heart hardens.", Effects = { Qi = 4, MaxHealth = 30 },
				FailResult = "The shadow devours you from within.", FailEffects = { Health = -45, Qi = -1 } },
			{ Text = "Recite the sutras", Requires = { MinAlignment = 20 }, Result = "The light of the sutras banishes the dark.", Effects = { Alignment = 10, Qi = 1, Stress = -15 } },
			{ Text = "Embrace the darkness", Result = "Your Qi turns black and furious.", Effects = { Qi = 3, Alignment = -30 } },
		},
	},

	wandering_orphan = {
		Title = "The Wandering Orphan",
		Text = "A starving child follows you for days, then kneels: \"Master, please take me as your disciple!\"",
		MinAge = 40, MaxAge = 5000, Weight = 0.06, MinRealm = 3,
		Options = {
			{ Text = "Accept the child", Result = "Teaching reminds you of the fundamentals.", Effects = { Karma = 5, Alignment = 10, Qi = 0.5, NewRelationship = { Type = "Friend", Affection = 80 } } },
			{ Text = "Turn them away", Result = "The child vanishes into the mist.", Effects = {} },
			{ Text = "Use them as a servant", Result = "You gain time to cultivate. They gain scars.", Effects = { Qi = 0.8, Alignment = -10, Karma = -1 } },
		},
	},

	heavenly_tribulation = {
		Title = "Heavenly Tribulation",
		Text = "Black clouds gather above you. Heaven is testing your right to defy it.",
		MinAge = 50, MaxAge = 100000, Weight = 0.05, MinRealm = 4, Repeatable = true, Cooldown = 10,
		Options = {
			{ Text = "Endure the lightning", Chance = 0.5, ChanceStat = "Vitality",
				Result = "Your body is reborn amid the thunder.", Effects = { Qi = 6, MaxHealth = 50, Stats = { Vitality = 30 } },
				FailResult = "The lightning scorches your meridians.", FailEffects = { Health = -60 } },
			{ Text = "Raise the Ancient Talisman", Requires = { Items = { ancient_talisman = 1 } },
				Result = "The talisman shatters, drinking the lightning for you.", Effects = { Items = { ancient_talisman = -1 }, Qi = 3, MaxHealth = 20 } },
			{ Text = "Flee the tribulation", Result = "Heaven does not forget cowards.", Effects = { Alignment = -5, Lifespan = -10 } },
		},
	},

	------------------------------------------------------------------ chain-only follow-ups

	sect_reward = {
		Title = "The Elders' Reward",
		Text = "A year after you reported the sealed cave, the sect elders summon you to choose your reward.",
		ChainOnly = true,
		Options = {
			{ Text = "A cultivation manual", Result = "Ancient breathing techniques, copied by hand.", Effects = { Qi = 1.5, Stats = { QiControl = 15 } } },
			{ Text = "A longevity pill", Result = "Bitter, golden, and worth a decade.", Effects = { Lifespan = 15 } },
			{ Text = "Shelter for your family", Requires = { HasRelationship = "Family" },
				Result = "Your family moves inside the sect walls, safe at last.", Effects = { Karma = 4, Alignment = 5, Happiness = 10 } },
		},
	},

	poison_exposed = {
		Title = "The Poison Is Traced",
		Text = "An apothecary traces the poison from the tournament back to you. The sect wants answers.",
		ChainOnly = true,
		Options = {
			{ Text = "Confess and accept punishment", Result = "Thirty lashes. Your conscience feels lighter.", Effects = { Health = -20, Alignment = 15, Karma = 2 } },
			{ Text = "Frame someone else", Chance = 0.4, ChanceStat = "Charisma",
				Result = "An innocent disciple takes the blame.", Effects = { Alignment = -20 },
				FailResult = "Your lie collapses. The punishment doubles.", FailEffects = { Health = -30, Alignment = -20, Karma = -5 } },
			{ Text = "Flee the region", Result = "You leave everything behind under cover of night.", Effects = { Happiness = -15, Money = -1000, Stress = 10 } },
		},
	},

	-- ===== Content expansion (2026-11-02): 14 more cultivation and fate events =====

	dragon_vein_dream = {
		Title = "The Dragon in Your Dreams",
		Text = "Night after night a golden dragon circles you in your dreams, waiting for something.",
		MinAge = 8, MaxAge = 30, Weight = 0.5,
		Requires = { Race = { "DragonVein", "AscendedBloodline" } },
		Options = {
			{ Text = "Bow to it", Result = "It breathes golden fire into your chest. You wake burning with Qi.", Effects = { Qi = 0.8, Stats = { Vitality = 20 }, MaxHealth = 15 } },
			{ Text = "Challenge it", Chance = 0.5, ChanceStat = "Strength",
				Result = "You wrestle it to the clouds and wake with its scale in your fist.", Effects = { Stats = { Strength = 30 }, Qi = 0.5 },
				FailResult = "It swats you awake. Your ribs ache for a month.", FailEffects = { Health = -15, Stats = { Strength = 10 } } },
		},
	},

	beastkin_hunt = {
		Title = "The Call of the Hunt",
		Text = "Under the full moon your senses sharpen. The forest calls you by an old name.",
		MinAge = 10, MaxAge = 40, Weight = 0.5,
		Requires = { Race = { "Beastkin", "Mutant" } },
		Options = {
			{ Text = "Run with the moon", Result = "You outrun deer and wolves alike.", Effects = { Stats = { Agility = 25, Vitality = 10 } } },
			{ Text = "Master the instinct", Result = "You learn to wake the beast only when you choose.", Effects = { Stats = { QiControl = 20 }, Stress = -10 } },
		},
	},

	spirit_touched_voices = {
		Title = "Voices in the Wind",
		Text = "The spirits that brush against your soul speak clearly for the first time.",
		MinAge = 8, MaxAge = 40, Weight = 0.5,
		Requires = { Race = { "SpiritTouched", "MortalBlood" } },
		Options = {
			{ Text = "Listen to them", Result = "They whisper where the earth's Qi runs strongest.", Effects = { Qi = 0.6, Stats = { Intelligence = 15 } } },
			{ Text = "Bargain for a gift", Chance = 0.5, ChanceStat = "Charisma",
				Result = "A spirit leaves a charm on your pillow.", Effects = { Items = { lucky_charm = 1 }, Stats = { Luck = 10 } },
				FailResult = "The spirits take offence and fall silent for a year.", FailEffects = { Stress = 10 } },
		},
	},

	meridian_blockage = {
		Title = "A Blocked Meridian",
		Text = "Your Qi stops dead at your left wrist. Every attempt to push through sends needles up your arm.",
		MinAge = 15, MaxAge = 200, Weight = 0.15, Repeatable = true, Cooldown = 15,
		Requires = { Flag = "SpiritRoot" },
		Options = {
			{ Text = "Force it open", Chance = 0.45, ChanceStat = "QiControl",
				Result = "With a crack like thunder, it opens. Qi floods your hand.", Effects = { Qi = 0.8, Stats = { QiControl = 15 } },
				FailResult = "The meridian tears. You cough blood for weeks.", FailEffects = { Health = -25, Qi = -0.3 } },
			{ Text = "Seek an acupuncturist", Result = "Expensive needles, slow progress, no risk.", Effects = { Money = -300, Qi = 0.4 } },
			{ Text = "Let it heal by itself", Result = "Months of patience. It clears on its own.", Effects = { Stress = 6, Stats = { QiControl = 5 } } },
		},
	},

	fallen_star_iron = {
		Title = "Fallen Star Iron",
		Text = "A meteor falls outside the village. Its core is a lump of black iron that hums in your hand.",
		MinAge = 16, MaxAge = 200, Weight = 0.12,
		Options = {
			{ Text = "Forge it into a blade", Result = "The blade cuts silk falling on it. Your sword arts leap forward.", Effects = { Proficiency = { Sword = 25 }, Money = -200 } },
			{ Text = "Absorb its starlight", Result = "Cold starlight sinks into your bones.", Effects = { Qi = 0.6, Stats = { Vitality = 10 } } },
			{ Text = "Sell it to a sect", Result = "Spirit stones and a sect's gratitude.", Effects = { Money = 3000 } },
		},
	},

	immortal_chess = {
		Title = "Two Old Men and a Chessboard",
		Text = "On a mountain path, two old men play chess on a stone. They have not moved in hours.",
		MinAge = 14, MaxAge = 200, Weight = 0.12,
		Options = {
			{ Text = "Watch the whole game", Result = "When you leave, a year has passed. Your mind has aged a decade in wisdom.", Effects = { Stats = { Intelligence = 30 }, Qi = 0.5, Lifespan = -1 } },
			{ Text = "Suggest a move", Chance = 0.35, ChanceStat = "Intelligence",
				Result = "Both men laugh. One gives you a peach that tastes like spring.", Effects = { Lifespan = 5, Qi = 0.4 },
				FailResult = "\"Hm.\" They vanish. So does your lunch.", FailEffects = { Stress = 6 } },
			{ Text = "Bow and walk on", Result = "A crane follows you halfway down the mountain.", Effects = { Karma = 2 } },
		},
	},

	demonic_cultivator = {
		Title = "The Smiling Stranger",
		Text = "A handsome cultivator offers to teach you a technique that devours other people's Qi.",
		MinAge = 18, MaxAge = 200, Weight = 0.12,
		Options = {
			{ Text = "Learn it", Result = "Power comes fast. Something inside you grows cold.", Effects = { Qi = 2, Alignment = -25, Karma = -5 } },
			{ Text = "Pretend to learn, then report him", Chance = 0.5, ChanceStat = "Charisma",
				Result = "The sects hunt him down and reward you.", Effects = { Money = 2000, Alignment = 10, Karma = 3 },
				FailResult = "He sees through you and leaves a scar to remember him by.", FailEffects = { Health = -30, Alignment = 5 } },
			{ Text = "Refuse firmly", Result = "His smile never wavers as he walks away.", Effects = { Alignment = 5 } },
		},
	},

	pill_furnace_inheritance = {
		Title = "The Old Alchemist's Furnace",
		Text = "A dying alchemist with no disciples presses the key to his workshop into your hand.",
		MinAge = 20, MaxAge = 200, Weight = 0.1,
		Options = {
			{ Text = "Study his notes", Result = "Decades of recipes, half of them brilliant.", Effects = { Stats = { Intelligence = 20 }, Items = { focus_tonic = 2 } } },
			{ Text = "Refine his last batch", Chance = 0.5, ChanceStat = "QiControl",
				Result = "Three perfect pills of prodigy.", Effects = { Items = { elixir_of_prodigy = 2 } },
				FailResult = "The furnace cracks. The workshop is ash.", FailEffects = { Health = -10, Stress = 8 } },
			{ Text = "Give him a proper burial", Result = "His spirit thanks you in a dream.", Effects = { Karma = 4, Alignment = 6, Lifespan = 3 } },
		},
	},

	secret_realm_opens = {
		Title = "A Secret Realm Opens",
		Text = "Once a century the mist over the Lake of Echoes parts and a hidden realm opens for seven days.",
		MinAge = 18, MaxAge = 300, Weight = 0.1, Repeatable = true, Cooldown = 40,
		Requires = { MinRealm = 2 },
		Options = {
			{ Text = "Plunge into the depths", Chance = 0.4, ChanceStat = "Vitality",
				Result = "Ancient herbs and a broken stele. You emerge transformed.", Effects = { Qi = 0.8, Items = { magic_crystal = 1, ancient_talisman = 1 } },
				FailResult = "Guardian puppets drive you out, bleeding.", FailEffects = { Health = -35, Qi = 0.3 } },
			{ Text = "Gather herbs at the edge", Result = "Safe and steady. Your bag is full.", Effects = { Items = { healing_salve = 3, vitality_draught = 1 } } },
			{ Text = "Guard the entrance for a sect", Result = "Boring, but they pay well.", Effects = { Money = 1500 } },
		},
	},

	karmic_debt = {
		Title = "A Karmic Debt",
		Text = "A fortune teller grabs your sleeve. \"Someone you wronged in a past life is near. Repay them.\"",
		MinAge = 16, MaxAge = 300, Weight = 0.1,
		Options = {
			{ Text = "Give alms to every beggar today", Result = "The tenth beggar smiles strangely and blesses you.", Effects = { Money = -200, Karma = 5, Stats = { Luck = 8 } } },
			{ Text = "Pay the fortune teller to break it", Result = "He pockets the coins. You will never know if it worked.", Effects = { Money = -500, Stress = -5 } },
			{ Text = "Laugh it off", Result = "Something heavy follows you for a while.", Effects = { Karma = -2, Stress = 5 } },
		},
	},

	sword_intent_waterfall = {
		Title = "Sword Intent in the Waterfall",
		Text = "A waterfall roars over a cliff carved with a thousand sword scars, all from one hand.",
		MinAge = 18, MaxAge = 300, Weight = 0.1,
		Requires = { Proficiency = { Sword = 20 } },
		Options = {
			{ Text = "Study the scars", Result = "On the ninth day, the water parts for your blade.", Effects = { Proficiency = { Sword = 30 }, Stats = { QiControl = 10 } } },
			{ Text = "Cut the waterfall", Chance = 0.35, ChanceStat = "Strength",
				Result = "For one heartbeat, the waterfall stops.", Effects = { Proficiency = { Sword = 40 }, Stats = { Strength = 15 } },
				FailResult = "The water knocks you into the pool.", FailEffects = { Health = -12, Proficiency = { Sword = 8 } } },
		},
	},

	heaven_defying_pill = {
		Title = "A Heaven-Defying Pill",
		Text = "An auction house unveils a pill said to break any bottleneck. The bidding starts at ten thousand.",
		MinAge = 25, MaxAge = 300, Weight = 0.08,
		Requires = { MinMoney = 10000 },
		Options = {
			{ Text = "Bid everything", Chance = 0.5, ChanceStat = "Luck",
				Result = "Sold, to you. It tastes of lightning.", Effects = { Money = -10000, Qi = 1.2 },
				FailResult = "A sect master outbids you at the last second.", FailEffects = { Stress = 10 } },
			{ Text = "Bid a little, then fold", Result = "You drive the price up for your rival. Petty, satisfying.", Effects = { Happiness = 6 } },
			{ Text = "Sell rumours about it instead", Result = "Gossip pays surprisingly well.", Effects = { Money = 800, Alignment = -3 } },
		},
	},

	reincarnated_master = {
		Title = "A Child with Old Eyes",
		Text = "A child in your village recites techniques no child should know, then stares at you as if you are their old student.",
		MinAge = 25, MaxAge = 300, Weight = 0.08,
		Options = {
			{ Text = "Kneel and ask for teaching", Result = "In a squeaky voice, they correct every flaw in your form.", Effects = { Qi = 0.8, Stats = { QiControl = 20 } } },
			{ Text = "Protect the child quietly", Result = "Years later, a great master remembers who kept them safe.", Effects = { Karma = 5, Alignment = 8 } },
			{ Text = "Report them to a sect", Result = "The sect takes the child away. Your purse is heavier.", Effects = { Money = 2000, Karma = -4 } },
		},
	},

	thousand_year_peach = {
		Title = "The Peach of a Thousand Years",
		Text = "Deep in the mountains a single peach glows on a withered tree guarded by an old ape.",
		MinAge = 40, MaxAge = 300, Weight = 0.08,
		Options = {
			{ Text = "Fight the ape", Chance = 0.4, ChanceStat = "Strength",
				Result = "Sweet as honey. Years of life bloom inside you.", Effects = { Lifespan = 12, Counters = { Fights = 1 } },
				FailResult = "The ape hurls you down the slope.", FailEffects = { Health = -35 } },
			{ Text = "Offer the ape your rations", Chance = 0.6, ChanceStat = "Charisma",
				Result = "It splits the peach with you, chattering happily.", Effects = { Lifespan = 6, Karma = 2 },
				FailResult = "It eats your rations and the peach.", FailEffects = { Happiness = -5 } },
			{ Text = "Leave the peach be", Result = "Some treasures are not meant for you.", Effects = { Karma = 1 } },
		},
	},
}

return LifeEventsConfig
