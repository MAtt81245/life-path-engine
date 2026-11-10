--[[
	Spiritual power and fate events (Soul Reaper path). Same format as YearlyEventsConfig;
	both pools are evaluated by LifeEventsEngine on every birthday.
]]

local LifeEventsConfig = {}

LifeEventsConfig.Events = {
	-- Origin-exclusive events (origins come from Wheel of Souls spins).
	clan_elders = {
		Title = "Summons of the Noble House",
		Text = "The head of your noble house calls you to the family hall in the Seireitei.",
		MinAge = 12, MaxAge = 40, Weight = 0.5,
		Requires = { Race = "AncientClan" },
		Options = {
			{ Text = "Study the house's secret records", Result = "Generations of Kido and Zanjutsu insight fill your mind.", Effects = { Stats = { Intelligence = 25, QiControl = 15 }, Qi = 0.5 } },
			{ Text = "Accept the house's stipend", Result = "The house treasury opens for its heir.", Effects = { Money = 5000 } },
		},
	},

	primordial_awakening = {
		Title = "Inner World Awakening",
		Text = "Something ancient in your soul wakes. Every Hollow in town turns to look at you.",
		MinAge = 10, MaxAge = 30, Weight = 0.6,
		Requires = { Race = { "ChaosSovereign", "VoidWalker", "HeavenlyDemon" } },
		Options = {
			{ Text = "Embrace it", Result = "Reiatsu floods every cell of your body.", Effects = { Qi = 1, Stats = { QiControl = 30 }, Lifespan = 20 } },
			{ Text = "Seal it away", Result = "You hold it down. Calm returns, and with it a deeper focus.", Effects = { Stress = -20, Stats = { Intelligence = 20 }, Karma = 3 } },
		},
	},

	spirit_root = {
		Title = "The Girl by the River",
		Text = "A ghost girl sitting by the river looks up, surprised. \"Wait... you can see me?\"",
		MinAge = 6, MaxAge = 6, Weight = 1,
		Options = {
			{ Text = "Talk to her gently", Result = "She smiles and fades away happy. Your spiritual sight is real.", Effects = { Qi = 0.5, Karma = 1, Stats = { QiControl = 8 }, Flags = { "SpiritRoot" } } },
			{ Text = "Shout at the Hollow chasing her", Chance = 0.5,
				Result = "Your reiatsu flares and the Hollow flees! Somewhere, a shopkeeper notices.", Effects = { Qi = 1.5, Alignment = -2, Flags = { "SpiritRoot" } },
				FailResult = "The Hollow knocks you into the river, but your spiritual power wakes.", FailEffects = { Health = -15, Flags = { "SpiritRoot" } } },
			{ Text = "Run home to play", Result = "You pretend you saw nothing; your spiritual power wakes anyway, slowly.", Effects = { Happiness = 10, Lifespan = 2, Flags = { "SpiritRoot" } } },
		},
	},

	body_or_mind = {
		Title = "Body or Mind",
		Text = "You turn 14. The karate dojo invites you to its senior class; a strange shopkeeper offers reiatsu meditation beneath a frozen waterfall.",
		MinAge = 14, MaxAge = 14, Weight = 1,
		Options = {
			{ Text = "Temper your body at the dojo", Result = "Your fists turn to iron. Pain is your teacher.", Effects = { Stats = { Strength = 25, Vitality = 20 }, MaxHealth = 20 } },
			{ Text = "Meditate under the waterfall", Result = "The icy water clears your mind. Reiatsu begins to flow.", Effects = { Qi = 1, Stats = { QiControl = 25 }, Alignment = 5 } },
		},
	},

	sect_recruitment = {
		Title = "The Factions Are Recruiting",
		Text = "At 20, two factions come for you: the Gotei 13 and a traitor captain's army of Arrancar.",
		MinAge = 20, MaxAge = 20, Weight = 1,
		Options = {
			{ Text = "Join the Gotei 13", Result = "Discipline and division missions strengthen your foundation.", Effects = { Qi = 1, Stats = { Strength = 10, QiControl = 10 }, Alignment = 10 } },
			{ Text = "Join the traitor's army", Result = "Hogyoku experiments speed up your growth... at a price.", Effects = { Qi = 2.5, Health = -10, Alignment = -20 } },
			{ Text = "Stay a Substitute Reaper", Result = "No captains, no chains. Karakura is your division.", Effects = { Karma = 2, Lifespan = 5, Stats = { Agility = 12 } } },
		},
	},

	bandit_ambush = {
		Title = "Hollow in the Alley",
		Text = "A masked Hollow crawls out of a dark alley. It is hungry, and it has smelled your reiatsu.",
		MinAge = 18, MaxAge = 60, Weight = 0.12,
		Options = {
			{ Text = "Fight", Chance = 0.45, ChanceStat = "Strength",
				Result = "You split its mask and learn from the fight.", Effects = { Qi = 0.4, Counters = { Fights = 1 }, Proficiency = { Sword = 10 } },
				FailResult = "It mauls you badly before slinking away.", FailEffects = { Health = -30 } },
			{ Text = "Throw it your reiatsu", Result = "You feed it to escape and keep your life.", Effects = { Qi = -0.5 } },
			{ Text = "Remind it of who it was", Chance = 0.35, ChanceStat = "Charisma",
				Result = "The Hollow remembers the human it once was, and passes on in peace.", Effects = { Karma = 4, Alignment = 10 },
				FailResult = "It howls and bites.", FailEffects = { Health = -15, Qi = -0.3 } },
		},
	},

	immortal_cave = {
		Title = "The Sealed Hogyoku Fragment",
		Text = "Chasing a stray Hollow, you find a cave sealed with Kido. A fragment of the Hogyoku sleeps inside.",
		MinAge = 22, MaxAge = 400, Weight = 0.06,
		Options = {
			{ Text = "Break the seal and claim it", Chance = 0.45, ChanceStat = "QiControl",
				Result = "The fragment grants your soul's desire, and you keep a sliver of it.", Effects = { Qi = 5, Lifespan = 20, Items = { ancient_talisman = 1 },
					Delayed = { InYears = 5, Text = "The Hogyoku's gift finally awakens inside your soul.", Effects = { Qi = 3, Lifespan = 10 } } },
				FailResult = "The Kido seal's backlash nearly kills you.", FailEffects = { Health = -50 } },
			{ Text = "Reseal it and report it", Result = "The Gotei 13 thanks you and promises a reward.", Effects = { Karma = 5, Alignment = 10,
				FollowUp = { Id = "sect_reward", InYears = 1 } } },
			{ Text = "Sell its location", Result = "A shady researcher pays well for your silence.", Effects = { Money = 3000, Alignment = -5 } },
		},
	},

	sect_tournament = {
		Title = "The Division Tournament",
		Text = "The inter-division tournament begins. Your opponent is an arrogant prodigy from Squad Eleven.",
		MinAge = 18, MaxAge = 120, Weight = 0.1, MinRealm = 2,
		Options = {
			{ Text = "Fight with everything", Chance = 0.4, ChanceStat = "Strength",
				Result = "A Getsuga lands! Victory, and a prize from the Captain's vault.", Effects = { Qi = 3, Karma = 1, Counters = { Fights = 1 } },
				FailResult = "You fall in front of every division.", FailEffects = { Health = -35 } },
			{ Text = "Yield with honor", Result = "Your humility impresses a lieutenant.", Effects = { Alignment = 5, Karma = 1, Qi = 0.5 } },
			{ Text = "Poison his tea", Chance = 0.7,
				Result = "An easy win. Nobody suspects... yet.", Effects = { Qi = 3, Alignment = -25,
					FollowUp = { Id = "poison_exposed", InYears = 3 } },
				FailResult = "You are caught, disciplined and suspended.", FailEffects = { Health = -20, Alignment = -30, Karma = -5 } },
		},
	},

	suspicious_pill = {
		Title = "A Suspicious Soul Candy",
		Text = "A shady peddler offers you a glowing candy. \"Eat it. It'll take you to the next class... or the next world.\"",
		MinAge = 18, MaxAge = 2000, Weight = 0.06, Repeatable = true, Cooldown = 8,
		Options = {
			{ Text = "Swallow it", Chance = 0.5,
				Result = "A wave of raw reiatsu floods your body.", Effects = { Qi = 2 },
				FailResult = "It was laced with Hollow serum. You cough blood for days.", FailEffects = { Health = -40 } },
			{ Text = "Analyze it carefully", Requires = { Counters = { Knowledge = 15 } },
				Result = "Your studies let you extract its safe essence.", Effects = { Qi = 1, Stats = { Intelligence = 8 } } },
			{ Text = "Refuse", Result = "The peddler shrugs and melts into the crowd.", Effects = {} },
		},
	},

	heart_demon = {
		Title = "The Inner Hollow",
		Text = "During meditation your regrets take shape. A pale Hollow with your face grins inside your inner world.",
		MinAge = 30, MaxAge = 5000, Weight = 0.07, MinRealm = 3,
		Options = {
			{ Text = "Face it", Chance = 0.45, ChanceStat = "QiControl",
				Result = "You beat it back. Your resolve hardens like steel.", Effects = { Qi = 4, MaxHealth = 30 },
				FailResult = "The Hollow devours you from within.", FailEffects = { Health = -45, Qi = -1 } },
			{ Text = "Call on your Zanpakuto", Requires = { MinAlignment = 20 }, Result = "Your blade's spirit drives the Hollow back.", Effects = { Alignment = 10, Qi = 1, Stress = -15 } },
			{ Text = "Embrace the Hollow", Result = "Your reiatsu turns black and furious.", Effects = { Qi = 3, Alignment = -30 } },
		},
	},

	wandering_orphan = {
		Title = "The Wandering Orphan",
		Text = "A child who can see ghosts follows you for days, then kneels: \"Please teach me to fight the Hollows!\"",
		MinAge = 40, MaxAge = 5000, Weight = 0.06, MinRealm = 3,
		Options = {
			{ Text = "Accept the child", Result = "Teaching reminds you of the fundamentals.", Effects = { Karma = 5, Alignment = 10, Qi = 0.5, NewRelationship = { Type = "Friend", Affection = 80 } } },
			{ Text = "Turn them away", Result = "The child vanishes into the crowd.", Effects = {} },
			{ Text = "Use them as bait", Result = "You gain time to train. They gain scars.", Effects = { Qi = 0.8, Alignment = -10, Karma = -1 } },
		},
	},

	heavenly_tribulation = {
		Title = "Bankai Clash",
		Text = "An Espada releases his Resurreccion. The sky turns black and his spiritual pressure crushes the ground.",
		MinAge = 50, MaxAge = 100000, Weight = 0.05, MinRealm = 4, Repeatable = true, Cooldown = 10,
		Options = {
			{ Text = "Release your Bankai", Chance = 0.5, ChanceStat = "Vitality",
				Result = "You outlast his release and cut through it. Your soul is reborn.", Effects = { Qi = 6, MaxHealth = 50, Stats = { Vitality = 30 } },
				FailResult = "His Cero tears through you.", FailEffects = { Health = -60 } },
			{ Text = "Unleash the Hogyoku Fragment", Requires = { Items = { ancient_talisman = 1 } },
				Result = "The fragment shatters, turning his power against him.", Effects = { Items = { ancient_talisman = -1 }, Qi = 3, MaxHealth = 20 } },
			{ Text = "Flash-step away", Result = "You escape, but Hollows never forget cowards.", Effects = { Alignment = -5, Lifespan = -10 } },
		},
	},

	------------------------------------------------------------------ chain-only follow-ups

	sect_reward = {
		Title = "The Captain's Reward",
		Text = "A year after you reported the sealed fragment, a captain summons you to choose your reward.",
		ChainOnly = true,
		Options = {
			{ Text = "A Kido scroll", Result = "Ancient Kido incantations, copied by hand.", Effects = { Qi = 1.5, Stats = { QiControl = 15 } } },
			{ Text = "A Fourth Division longevity treatment", Result = "Painful, precise, and worth a decade.", Effects = { Lifespan = 15 } },
			{ Text = "Shelter for your family", Requires = { HasRelationship = "Family" },
				Result = "Your family moves inside the Seireitei walls, safe at last.", Effects = { Karma = 4, Alignment = 5, Happiness = 10 } },
		},
	},

	poison_exposed = {
		Title = "The Poison Is Traced",
		Text = "A Fourth Division medic traces the poison from the tournament back to you. The Central 46 wants answers.",
		ChainOnly = true,
		Options = {
			{ Text = "Confess and accept punishment", Result = "A brutal suspension mission. Your conscience feels lighter.", Effects = { Health = -20, Alignment = 15, Karma = 2 } },
			{ Text = "Frame someone else", Chance = 0.4, ChanceStat = "Charisma",
				Result = "An innocent student takes the blame.", Effects = { Alignment = -20 },
				FailResult = "Your lie collapses. The punishment doubles.", FailEffects = { Health = -30, Alignment = -20, Karma = -5 } },
			{ Text = "Flee the region", Result = "You leave everything behind under cover of night.", Effects = { Happiness = -15, Money = -1000, Stress = 10 } },
		},
	},

	-- ===== Content expansion (2026-11-02): 14 more spiritual fate events =====

	berserker_blood_dream = {
		Title = "The Laughing Swordsman in Your Dreams",
		Text = "Night after night a grinning swordsman covered in scars challenges you in your dreams.",
		MinAge = 8, MaxAge = 30, Weight = 0.5,
		Requires = { Race = { "DragonVein", "AscendedBloodline" } },
		Options = {
			{ Text = "Fight him every night", Chance = 0.5, ChanceStat = "Strength",
				Result = "One night you land a blow. He laughs and you wake stronger.", Effects = { Stats = { Strength = 30 }, Qi = 0.5 },
				FailResult = "You wake with bruises that should not exist.", FailEffects = { Health = -15, Stats = { Strength = 10 } } },
			{ Text = "Ask his name", Result = "He only grins wider. Your reiatsu roars awake.", Effects = { Qi = 0.8, Stats = { Vitality = 20 }, MaxHealth = 15 } },
		},
	},

	onmitsukido_trial = {
		Title = "The Shadow Trial",
		Text = "A masked figure drops a scroll at your feet: \"Catch me before sunrise and we will train you.\"",
		MinAge = 10, MaxAge = 40, Weight = 0.5,
		Requires = { Race = { "Beastkin", "Mutant" } },
		Options = {
			{ Text = "Chase them across the rooftops", Result = "You never catch them, but you learn to move like the wind.", Effects = { Stats = { Agility = 25, Vitality = 10 } } },
			{ Text = "Set a trap instead", Result = "They laugh when the net drops. \"Clever. That counts.\"", Effects = { Stats = { Intelligence = 15, QiControl = 10 } } },
		},
	},

	kido_corps_scroll = {
		Title = "A Sealed Kido Corps Scroll",
		Text = "In your grandmother's attic you find a scroll sealed with the crest of the Kido Corps.",
		MinAge = 8, MaxAge = 40, Weight = 0.5,
		Requires = { Race = { "ShikigamiTamer", "SpiritTouched", "MortalBlood" } },
		Options = {
			{ Text = "Break the seal", Result = "Forbidden incantations burn themselves into your memory.", Effects = { Qi = 0.6, Stats = { Intelligence = 15 } } },
			{ Text = "Bargain with the spirit bound inside", Chance = 0.5, ChanceStat = "Charisma",
				Result = "It leaves a charm on your pillow and its blessing.", Effects = { Items = { lucky_charm = 1 }, Stats = { Luck = 10 } },
				FailResult = "It hisses and the scroll burns to ash.", FailEffects = { Stress = 10 } },
		},
	},

	soul_chain_fracture = {
		Title = "A Cracked Soul Sleep",
		Text = "Your reiryoku stops dead at your chest. Every attempt to push through feels like swallowing glass.",
		MinAge = 15, MaxAge = 200, Weight = 0.15, Repeatable = true, Cooldown = 15,
		Requires = { Flag = "SpiritRoot" },
		Options = {
			{ Text = "Force it open", Chance = 0.45, ChanceStat = "QiControl",
				Result = "With a crack like thunder, it opens. Power floods your limbs.", Effects = { Qi = 0.6, Stats = { QiControl = 15 } },
				FailResult = "Something tears. You cough blood for weeks.", FailEffects = { Health = -25, Qi = -0.3 } },
			{ Text = "Visit the Fourth Division", Result = "Expensive treatment, slow progress, no risk.", Effects = { Money = -300, Qi = 0.3 } },
			{ Text = "Let it heal by itself", Result = "Months of patience. It clears on its own.", Effects = { Stress = 6, Stats = { QiControl = 5 } } },
		},
	},

	fallen_asauchi = {
		Title = "A Nameless Blade in the Ruins",
		Text = "In an abandoned Rukongai shrine you find an asauchi, a blank Soul Reaper sword, humming with someone else's dreams.",
		MinAge = 16, MaxAge = 200, Weight = 0.12,
		Options = {
			{ Text = "Sleep beside it", Result = "Its last owner's sword forms teach you through your dreams.", Effects = { Proficiency = { Sword = 25 } } },
			{ Text = "Absorb its residue", Result = "Old reiatsu sinks into your bones.", Effects = { Qi = 0.6, Stats = { Vitality = 10 } } },
			{ Text = "Return it to the Gotei", Result = "A quartermaster rewards your honesty.", Effects = { Money = 2000, Alignment = 4 } },
		},
	},

	two_old_spirits = {
		Title = "Two Old Spirits and a Board Game",
		Text = "On a quiet hill, two ancient spirits play shogi on a stone. They have not moved in hours.",
		MinAge = 14, MaxAge = 200, Weight = 0.12,
		Options = {
			{ Text = "Watch the whole game", Result = "When you leave, a year has passed. Your mind has aged a decade in wisdom.", Effects = { Stats = { Intelligence = 30 }, Qi = 0.4, Lifespan = -1 } },
			{ Text = "Suggest a move", Chance = 0.35, ChanceStat = "Intelligence",
				Result = "Both spirits laugh. One gives you a persimmon that tastes like spring.", Effects = { Lifespan = 5, Qi = 0.4 },
				FailResult = "\"Hm.\" They vanish. So does your lunch.", FailEffects = { Stress = 6 } },
			{ Text = "Bow and walk on", Result = "A hell butterfly follows you halfway home.", Effects = { Karma = 2 } },
		},
	},

	hollowfication_offer = {
		Title = "The Smiling Scientist",
		Text = "A soft-spoken researcher offers to 'unlock your hidden potential' with a small Hollow-derived injection.",
		MinAge = 18, MaxAge = 200, Weight = 0.12,
		Options = {
			{ Text = "Accept the injection", Result = "Power comes fast. Something behind your eyes starts whispering.", Effects = { Qi = 1.2, Alignment = -25, Karma = -5 } },
			{ Text = "Pretend to agree, then report him", Chance = 0.5, ChanceStat = "Charisma",
				Result = "The Onmitsukido raid his lab and reward you.", Effects = { Money = 2000, Alignment = 10, Karma = 3 },
				FailResult = "He sees through you and leaves a scar to remember him by.", FailEffects = { Health = -30, Alignment = 5 } },
			{ Text = "Refuse firmly", Result = "His smile never wavers as he walks away.", Effects = { Alignment = 5 } },
		},
	},

	retired_healer_legacy = {
		Title = "The Retired Healer's Notes",
		Text = "A dying Fourth Division veteran with no apprentice presses the key to her clinic into your hand.",
		MinAge = 20, MaxAge = 200, Weight = 0.1,
		Options = {
			{ Text = "Study her notes", Result = "Decades of healing Kido, half of it brilliant.", Effects = { Stats = { Intelligence = 20 }, Items = { focus_tonic = 2 } } },
			{ Text = "Brew her last formula", Chance = 0.5, ChanceStat = "QiControl",
				Result = "Two perfect vials of prodigy's draught.", Effects = { Items = { elixir_of_prodigy = 2 } },
				FailResult = "The vat cracks. The clinic smells terrible for a month.", FailEffects = { Health = -10, Stress = 8 } },
			{ Text = "Perform her Konso yourself", Result = "She passes on smiling. You feel lighter.", Effects = { Karma = 4, Alignment = 6, Lifespan = 3 } },
		},
	},

	dangai_rift = {
		Title = "A Rift in the Dangai",
		Text = "A Senkaimon misfires and drops you into a pocket of the Dangai where time moves strangely.",
		MinAge = 18, MaxAge = 300, Weight = 0.1, Repeatable = true, Cooldown = 40,
		Requires = { MinRealm = 2 },
		Options = {
			{ Text = "Train until you find the way out", Chance = 0.4, ChanceStat = "Vitality",
				Result = "Months pass inside; days outside. You emerge transformed.", Effects = { Qi = 0.8, Items = { magic_crystal = 1, ancient_talisman = 1 } },
				FailResult = "The Cleaner chases you out, bleeding.", FailEffects = { Health = -35, Qi = 0.3 } },
			{ Text = "Gather reishi crystals at the edge", Result = "Safe and steady. Your pockets are full.", Effects = { Items = { healing_salve = 3, vitality_draught = 1 } } },
			{ Text = "Wait for rescue", Result = "The Twelfth Division fishes you out and bills you for it.", Effects = { Money = -300 } },
		},
	},

	karmic_debt = {
		Title = "A Debt from a Past Life",
		Text = "An old Rukongai fortune teller grabs your sleeve. \"Someone you wronged in your last life is near. Repay them.\"",
		MinAge = 16, MaxAge = 300, Weight = 0.1,
		Options = {
			{ Text = "Give alms to every beggar today", Result = "The tenth beggar smiles strangely and blesses you.", Effects = { Money = -200, Karma = 5, Stats = { Luck = 8 } } },
			{ Text = "Pay her to break it", Result = "She pockets the coins. You will never know if it worked.", Effects = { Money = -500, Stress = -5 } },
			{ Text = "Laugh it off", Result = "Something heavy follows you for a while.", Effects = { Karma = -2, Stress = 5 } },
		},
	},

	waterfall_of_cuts = {
		Title = "The Cliff of a Thousand Cuts",
		Text = "A waterfall pours over a cliff scarred by a thousand sword strokes, all from one long-dead captain.",
		MinAge = 18, MaxAge = 300, Weight = 0.1,
		Requires = { Proficiency = { Sword = 20 } },
		Options = {
			{ Text = "Study the scars", Result = "On the ninth day, the water parts for your blade.", Effects = { Proficiency = { Sword = 30 }, Stats = { QiControl = 10 } } },
			{ Text = "Cut the waterfall", Chance = 0.35, ChanceStat = "Strength",
				Result = "For one heartbeat, the waterfall stops.", Effects = { Proficiency = { Sword = 40 }, Stats = { Strength = 15 } },
				FailResult = "The water knocks you into the pool.", FailEffects = { Health = -12, Proficiency = { Sword = 8 } } },
		},
	},

	black_market_hogyoku = {
		Title = "A Fragment at Auction",
		Text = "A Rukongai black market unveils a crystal fragment said to grant its holder's desires. Bids start at ten thousand.",
		MinAge = 25, MaxAge = 300, Weight = 0.08,
		Requires = { MinMoney = 10000 },
		Options = {
			{ Text = "Bid everything", Chance = 0.5, ChanceStat = "Luck",
				Result = "Sold, to you. It hums against your chest.", Effects = { Money = -10000, Qi = 1.2 },
				FailResult = "A noble house outbids you at the last second.", FailEffects = { Stress = 10 } },
			{ Text = "Bid a little, then fold", Result = "You drive the price up for a rival. Petty, satisfying.", Effects = { Happiness = 6 } },
			{ Text = "Tip off the Onmitsukido", Result = "The auction is raided. You get a reward and enemies.", Effects = { Money = 800, Alignment = 4 } },
		},
	},

	reincarnated_captain = {
		Title = "A Child with a Captain's Eyes",
		Text = "A Rukongai child recites sword forms no child should know, then corrects your stance as if you were their old lieutenant.",
		MinAge = 25, MaxAge = 300, Weight = 0.08,
		Options = {
			{ Text = "Kneel and ask for teaching", Result = "In a squeaky voice, they fix every flaw in your form.", Effects = { Qi = 0.8, Stats = { QiControl = 20 } } },
			{ Text = "Protect the child quietly", Result = "Decades later, a great captain remembers who kept them safe.", Effects = { Karma = 5, Alignment = 8 } },
			{ Text = "Report them to the Academy", Result = "The Academy takes the child. Your purse is heavier.", Effects = { Money = 2000, Karma = -4 } },
		},
	},

	sacred_persimmon = {
		Title = "The Persimmon of the Old Shrine",
		Text = "Deep in the outer districts, a single glowing persimmon hangs from a withered tree guarded by an old monkey spirit.",
		MinAge = 40, MaxAge = 300, Weight = 0.08,
		Options = {
			{ Text = "Fight the spirit", Chance = 0.4, ChanceStat = "Strength",
				Result = "Sweet as honey. Years of life bloom inside you.", Effects = { Lifespan = 12, Counters = { Fights = 1 } },
				FailResult = "It hurls you down the hill.", FailEffects = { Health = -35 } },
			{ Text = "Offer it your rice balls", Chance = 0.6, ChanceStat = "Charisma",
				Result = "It splits the fruit with you, chattering happily.", Effects = { Lifespan = 6, Karma = 2 },
				FailResult = "It eats your rice balls and the persimmon.", FailEffects = { Happiness = -5 } },
			{ Text = "Leave it be", Result = "Some treasures are not meant for you.", Effects = { Karma = 1 } },
		},
	},
}

return LifeEventsConfig
