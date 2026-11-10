--[[
	Sorcery and fate events (jujutsu path). Same format as YearlyEventsConfig;
	both pools are evaluated by LifeEventsEngine on every birthday.
]]

local LifeEventsConfig = {}

LifeEventsConfig.Events = {
	-- Clan-exclusive events (clans come from Wheel of Curses spins).
	clan_elders = {
		Title = "Summons of the Clan Head",
		Text = "The head of the Cursed Speech clan calls you to the sealed ancestral hall.",
		MinAge = 12, MaxAge = 40, Weight = 0.5,
		Requires = { Race = "AncientClan" },
		Options = {
			{ Text = "Study the clan's forbidden records", Result = "Generations of cursed technique insight fill your mind.", Effects = { Stats = { Intelligence = 25, QiControl = 15 }, Qi = 0.5 } },
			{ Text = "Accept the clan's stipend", Result = "The clan vault opens for its heir.", Effects = { Money = 5000 } },
		},
	},

	primordial_awakening = {
		Title = "Innate Technique Awakening",
		Text = "Something ancient in your blood wakes. Every curse in the city turns to look at you.",
		MinAge = 10, MaxAge = 30, Weight = 0.6,
		Requires = { Race = { "ChaosSovereign", "VoidWalker", "HeavenlyDemon" } },
		Options = {
			{ Text = "Embrace it", Result = "Cursed energy floods every cell of your body.", Effects = { Qi = 1, Stats = { QiControl = 30 }, Lifespan = 20 } },
			{ Text = "Seal it with a Binding Vow", Result = "You vow restraint. Calm returns, and with it a deeper focus.", Effects = { Stress = -20, Stats = { Intelligence = 20 }, Karma = 3 } },
		},
	},

	spirit_root = {
		Title = "The Cursed Energy Test",
		Text = "A jujutsu recruiter hands you a cursed doll. \"Hold it, kid, and we'll see if you've got cursed energy.\"",
		MinAge = 6, MaxAge = 6, Weight = 1,
		Options = {
			{ Text = "Hold it calmly", Result = "The doll's eyes glow a soft violet. You have potential.", Effects = { Qi = 0.5, Karma = 1, Stats = { QiControl = 8 }, Flags = { "SpiritRoot" } } },
			{ Text = "Pour your anger into it", Chance = 0.5,
				Result = "The doll bursts with cursed energy! The recruiter whispers your name.", Effects = { Qi = 1.5, Alignment = -2, Flags = { "SpiritRoot" } },
				FailResult = "The doll punches you in the face, but your cursed energy wakes.", FailEffects = { Health = -15, Flags = { "SpiritRoot" } } },
			{ Text = "Refuse and go play", Result = "The recruiter sighs; your cursed energy wakes anyway, slowly.", Effects = { Happiness = 10, Lifespan = 2, Flags = { "SpiritRoot" } } },
		},
	},

	body_or_mind = {
		Title = "Body or Mind",
		Text = "You turn 14. A brutal taijutsu dojo offers you a spot; a shrine priest offers cursed energy meditation beneath a frozen waterfall.",
		MinAge = 14, MaxAge = 14, Weight = 1,
		Options = {
			{ Text = "Temper your body at the dojo", Result = "Your fists turn to iron. Pain is your teacher.", Effects = { Stats = { Strength = 25, Vitality = 20 }, MaxHealth = 20 } },
			{ Text = "Meditate under the waterfall", Result = "The icy water clears your mind. Cursed energy begins to flow.", Effects = { Qi = 1, Stats = { QiControl = 25 }, Alignment = 5 } },
		},
	},

	sect_recruitment = {
		Title = "The Factions Are Recruiting",
		Text = "At 20, two factions come for you: the jujutsu schools and the ruthless Curse User Cabal.",
		MinAge = 20, MaxAge = 20, Weight = 1,
		Options = {
			{ Text = "Join the jujutsu schools", Result = "Discipline and graded missions strengthen your foundation.", Effects = { Qi = 1, Stats = { Strength = 10, QiControl = 10 }, Alignment = 10 } },
			{ Text = "Join the curse users", Result = "Forbidden techniques speed up your growth... at a price.", Effects = { Qi = 2.5, Health = -10, Alignment = -20 } },
			{ Text = "Stay a freelance sorcerer", Result = "No higher-ups, no chains. The world is your faction.", Effects = { Karma = 2, Lifespan = 5, Stats = { Agility = 12 } } },
		},
	},

	bandit_ambush = {
		Title = "Cursed Spirit in the Alley",
		Text = "A Grade 2 cursed spirit drags itself out of a dark alley. It is hungry, and it has seen you.",
		MinAge = 18, MaxAge = 60, Weight = 0.12,
		Options = {
			{ Text = "Fight", Chance = 0.45, ChanceStat = "Strength",
				Result = "You exorcise it and learn from the fight.", Effects = { Qi = 0.4, Counters = { Fights = 1 }, Proficiency = { Sword = 10 } },
				FailResult = "It mauls you badly before slinking away.", FailEffects = { Health = -30 } },
			{ Text = "Throw it your cursed energy", Result = "You feed it to escape and keep your life.", Effects = { Qi = -0.5 } },
			{ Text = "Calm the curse's grief", Chance = 0.35, ChanceStat = "Charisma",
				Result = "The curse remembers the human fear that made it, and fades in peace.", Effects = { Karma = 4, Alignment = 10 },
				FailResult = "It laughs with a hundred mouths and bites.", FailEffects = { Health = -15, Qi = -0.3 } },
		},
	},

	immortal_cave = {
		Title = "The Sealed Cursed Object",
		Text = "Chasing a stray curse, you find a shrine sealed with ancient talismans. A Special Grade cursed object sleeps inside.",
		MinAge = 22, MaxAge = 400, Weight = 0.06,
		Options = {
			{ Text = "Break the seal and claim it", Chance = 0.45, ChanceStat = "QiControl",
				Result = "You absorb a Heian sorcerer's remnant power, and a fragment of a prison realm.", Effects = { Qi = 5, Lifespan = 20, Items = { ancient_talisman = 1 },
					Delayed = { InYears = 5, Text = "The Heian remnant finally awakens inside your cursed energy.", Effects = { Qi = 3, Lifespan = 10 } } },
				FailResult = "The seal's backlash nearly kills you.", FailEffects = { Health = -50 } },
			{ Text = "Reseal it and report it", Result = "The higher-ups thank you and promise a reward.", Effects = { Karma = 5, Alignment = 10,
				FollowUp = { Id = "sect_reward", InYears = 1 } } },
			{ Text = "Sell its location", Result = "A curse broker pays well for your silence.", Effects = { Money = 3000, Alignment = -5 } },
		},
	},

	sect_tournament = {
		Title = "The Domain Clash Tournament",
		Text = "The inter-school tournament begins. Your opponent is an arrogant prodigy from the Kyoto school.",
		MinAge = 18, MaxAge = 120, Weight = 0.1, MinRealm = 2,
		Options = {
			{ Text = "Fight with everything", Chance = 0.4, ChanceStat = "Strength",
				Result = "A Black Flash lands! Victory, and a cursed object from the vault.", Effects = { Qi = 3, Karma = 1, Counters = { Fights = 1 } },
				FailResult = "You fall in front of both schools.", FailEffects = { Health = -35 } },
			{ Text = "Yield with honor", Result = "Your humility impresses a Grade 1 sorcerer.", Effects = { Alignment = 5, Karma = 1, Qi = 0.5 } },
			{ Text = "Poison his tea", Chance = 0.7,
				Result = "An easy win. Nobody suspects... yet.", Effects = { Qi = 3, Alignment = -25,
					FollowUp = { Id = "poison_exposed", InYears = 3 } },
				FailResult = "You are caught, disciplined and suspended.", FailEffects = { Health = -20, Alignment = -30, Karma = -5 } },
		},
	},

	suspicious_pill = {
		Title = "A Suspicious Cursed Finger",
		Text = "A shady broker offers you a withered, cursed finger. \"Eat it. It'll take you to the next grade... or the next world.\"",
		MinAge = 18, MaxAge = 2000, Weight = 0.06, Repeatable = true, Cooldown = 8,
		Options = {
			{ Text = "Swallow it", Chance = 0.5,
				Result = "A wave of raw cursed energy floods your body.", Effects = { Qi = 2 },
				FailResult = "The curse fights back. You cough blood for days.", FailEffects = { Health = -40 } },
			{ Text = "Analyze it carefully", Requires = { Counters = { Knowledge = 15 } },
				Result = "Your studies let you extract its safe essence.", Effects = { Qi = 1, Stats = { Intelligence = 8 } } },
			{ Text = "Refuse", Result = "The broker shrugs and melts into the crowd.", Effects = {} },
		},
	},

	heart_demon = {
		Title = "The Curse Within",
		Text = "During meditation your regrets take shape. A cursed spirit with your face whispers your failures.",
		MinAge = 30, MaxAge = 5000, Weight = 0.07, MinRealm = 3,
		Options = {
			{ Text = "Face it", Chance = 0.45, ChanceStat = "QiControl",
				Result = "You exorcise it. Your resolve hardens like a Binding Vow.", Effects = { Qi = 4, MaxHealth = 30 },
				FailResult = "The curse devours you from within.", FailEffects = { Health = -45, Qi = -1 } },
			{ Text = "Chant the exorcism", Requires = { MinAlignment = 20 }, Result = "Your positive energy banishes the curse.", Effects = { Alignment = 10, Qi = 1, Stress = -15 } },
			{ Text = "Embrace the curse", Result = "Your cursed energy turns black and furious.", Effects = { Qi = 3, Alignment = -30 } },
		},
	},

	wandering_orphan = {
		Title = "The Wandering Orphan",
		Text = "A child who can see curses follows you for days, then kneels: \"Sensei, please teach me to fight them!\"",
		MinAge = 40, MaxAge = 5000, Weight = 0.06, MinRealm = 3,
		Options = {
			{ Text = "Accept the child", Result = "Teaching reminds you of the fundamentals.", Effects = { Karma = 5, Alignment = 10, Qi = 0.5, NewRelationship = { Type = "Friend", Affection = 80 } } },
			{ Text = "Turn them away", Result = "The child vanishes into the crowd.", Effects = {} },
			{ Text = "Use them as bait", Result = "You gain time to train. They gain scars.", Effects = { Qi = 0.8, Alignment = -10, Karma = -1 } },
		},
	},

	heavenly_tribulation = {
		Title = "Domain Expansion Clash",
		Text = "A Special Grade curse opens its Domain around you. Black walls close in, and its sure-hit technique is coming.",
		MinAge = 50, MaxAge = 100000, Weight = 0.05, MinRealm = 4, Repeatable = true, Cooldown = 10,
		Options = {
			{ Text = "Endure the sure-hit", Chance = 0.5, ChanceStat = "Vitality",
				Result = "You outlast its Domain and Black Flash it as the walls break. Your body is reborn.", Effects = { Qi = 6, MaxHealth = 50, Stats = { Vitality = 30 } },
				FailResult = "The sure-hit technique tears through you.", FailEffects = { Health = -60 } },
			{ Text = "Unleash the Prison Realm Fragment", Requires = { Items = { ancient_talisman = 1 } },
				Result = "The fragment shatters, swallowing the Domain for you.", Effects = { Items = { ancient_talisman = -1 }, Qi = 3, MaxHealth = 20 } },
			{ Text = "Flee the Domain", Result = "You escape, but curses never forget cowards.", Effects = { Alignment = -5, Lifespan = -10 } },
		},
	},

	------------------------------------------------------------------ content expansion (2026-11-02)
	-- Content expansion (2026-11-02): 14 more sorcerer fate events.
	cursed_energy_overflow = {
		Title = "Cursed Energy Overflow",
		Text = "A bad week leaves your cursed energy boiling over. Lamps flicker when you walk past.",
		MinAge = 10, MaxAge = 40, Weight = 0.3,
		Options = {
			{ Text = "Vent it in the training yard", Result = "Concrete cracks under your fists. You feel clear again.", Effects = { Stats = { Strength = 10 }, Stress = -8 } },
			{ Text = "Compress it inward", Chance = 0.5, ChanceStat = "QiControl",
				Result = "It folds into a dense, quiet core.", Effects = { Qi = 0.4, Stats = { QiControl = 10 } },
				FailResult = "It leaks out as a nosebleed that lasts all day.", FailEffects = { Health = -10 } },
		},
	},

	technique_revelation = {
		Title = "Technique Revelation",
		Text = "A senior sorcerer tells you to reveal how your technique works before you use it. \"A Binding Vow with your enemy. It makes it stronger.\"",
		MinAge = 14, MaxAge = 200, Weight = 0.25,
		Options = {
			{ Text = "Practise explaining it mid-fight", Result = "Strange, but the hits land harder.", Effects = { Stats = { QiControl = 10, Charisma = 4 } } },
			{ Text = "Keep it secret, always", Result = "Your enemies never know what is coming.", Effects = { Stats = { Agility = 8, Intelligence = 4 } } },
		},
	},

	special_grade_sighting = {
		Title = "A Special Grade Passes By",
		Text = "On a crowded train, a curse in human shape sits across from you and smiles. Nobody else notices.",
		MinAge = 15, MaxAge = 300, Weight = 0.08, MinRealm = 2,
		Options = {
			{ Text = "Hold its gaze", Chance = 0.45, ChanceStat = "QiControl",
				Result = "It leaves at the next stop, curious. Your cursed energy steadies forever.", Effects = { Qi = 0.6, Stats = { QiControl = 12 } },
				FailResult = "Its pressure makes you faint. You wake up at the terminal.", FailEffects = { Health = -15, Stress = 12 } },
			{ Text = "Look away and get off", Result = "Survival instinct is a skill too.", Effects = { Stats = { Agility = 6 } } },
		},
	},

	vow_of_restriction = {
		Title = "A Heavenly Restriction?",
		Text = "Doctors find something odd: your body is far stronger than it should be, and your cursed energy far weaker.",
		MinAge = 8, MaxAge = 16, Weight = 0.06,
		Options = {
			{ Text = "Lean into the body", Result = "You train like a beast. No curse outruns you.", Effects = { Stats = { Strength = 18, Agility = 12, Vitality = 10 } } },
			{ Text = "Fight for your cursed energy", Result = "Slow, stubborn progress. Your will hardens.", Effects = { Qi = 0.3, Stats = { QiControl = 10 }, Stress = 6 } },
		},
	},

	simple_domain_lesson = {
		Title = "The Simple Domain",
		Text = "An old swordsman from the New Shadow school draws a small circle around himself. \"Nothing gets in here. Learn it.\"",
		MinAge = 15, MaxAge = 200, Weight = 0.15, MinRealm = 2,
		Options = {
			{ Text = "Pay for the lesson (¥1,000)", Requires = { MinMoney = 1000 }, Result = "Your first Simple Domain holds for three seconds. A lifetime, in a fight.",
				Effects = { Money = -1000, Proficiency = { QiArts = 15, Sword = 10 } } },
			{ Text = "Copy him by watching", Chance = 0.35, ChanceStat = "Intelligence",
				Result = "Close enough. He shrugs and lets it go.", Effects = { Proficiency = { QiArts = 10 } },
				FailResult = "He catches you and bills you anyway.", FailEffects = { Money = -300 } },
		},
	},

	cursed_tool_inheritance = {
		Title = "A Blade Left Behind",
		Text = "A sorcerer you barely knew dies on a mission. Her will leaves you her cursed tool and a note: \"Don't waste it.\"",
		MinAge = 16, MaxAge = 200, Weight = 0.08,
		Options = {
			{ Text = "Train with it every day", Result = "The tool remembers its old owner, and slowly accepts you.", Effects = { Proficiency = { Sword = 18 }, Stats = { Strength = 6 } } },
			{ Text = "Give it to her family", Result = "They weep and thank you. Her clan remembers.", Effects = { Karma = 3, Alignment = 5 } },
		},
	},

	sealed_finger_found = {
		Title = "A Finger in the Rubble",
		Text = "Clearing a collapsed shrine, you find a desiccated finger wrapped in seals. It pulses with the energy of a Special Grade.",
		MinAge = 15, MaxAge = 300, Weight = 0.05, MinRealm = 3,
		Options = {
			{ Text = "Hand it to headquarters", Result = "Sealed away in the deepest vault. Your record shines.", Effects = { Karma = 4, Money = 2000 } },
			{ Text = "Draw power from its leakage", Chance = 0.4, ChanceStat = "QiControl",
				Result = "You sip at its overflow without breaking the seal.", Effects = { Qi = 0.8, Alignment = -4 },
				FailResult = "Its malice floods your head for a week.", FailEffects = { Stress = 20, Health = -20, Alignment = -6 } },
		},
	},

	cursed_spirit_manipulation = {
		Title = "A Curse That Obeys",
		Text = "A weak curse you defeated does not dissolve. It kneels, waiting for orders.",
		MinAge = 14, MaxAge = 200, Weight = 0.06,
		Options = {
			{ Text = "Exorcise it anyway", Result = "Rules are rules. Clean and simple.", Effects = { Alignment = 3, Counters = { Fights = 1 } } },
			{ Text = "Keep it as a scout", Result = "It shows you places sorcerers never look.", Effects = { Stats = { Intelligence = 8 }, Money = 300, Alignment = -3 } },
		},
	},

	barrier_team_training = {
		Title = "Curtain Duty",
		Text = "The auxiliary staff need someone to raise and hold curtains around exorcisms all season.",
		MinAge = 14, MaxAge = 200, Weight = 0.2,
		Options = {
			{ Text = "Volunteer for the whole season", Result = "Boring work. Your barriers become rock solid.", Effects = { Proficiency = { QiArts = 14 }, Money = 400 } },
			{ Text = "Do one shift and leave", Result = "Easy money for a single night.", Effects = { Money = 150 } },
		},
	},

	dead_friend_curse = {
		Title = "A Friend Who Became a Curse",
		Text = "A friend who died full of hatred returns as a vengeful spirit. It still remembers your name.",
		MinAge = 16, MaxAge = 300, Weight = 0.05, MinRealm = 2,
		Options = {
			{ Text = "Exorcise them yourself", Chance = 0.5, ChanceStat = "QiControl",
				Result = "You send them off gently. It is the hardest thing you have ever done.", Effects = { Qi = 0.5, Stress = 10, Karma = 3 },
				FailResult = "You cannot bring yourself to strike. Another sorcerer does it.", FailEffects = { Stress = 15, Happiness = -10 } },
			{ Text = "Talk to them until dawn", Result = "Their hatred thins into tears, then into nothing.", Effects = { Karma = 4, Happiness = -4, Stress = -6 } },
		},
	},

	clan_succession_feud = {
		Title = "Clan Succession Feud",
		Text = "Two branches of a great sorcerer clan want you on their side in a fight for the next clan head.",
		MinAge = 18, MaxAge = 200, Weight = 0.08,
		Options = {
			{ Text = "Back the main family", Result = "They win. You are paid generously and trusted little.", Effects = { Money = 2500, Alignment = -2 } },
			{ Text = "Back the branch family", Chance = 0.4, ChanceStat = "Charisma",
				Result = "Against the odds they win, and they never forget you.", Effects = { Karma = 3, Stats = { Charisma = 10 } },
				FailResult = "They lose. You are banned from the clan's lands.", FailEffects = { Stress = 10, Money = -500 } },
			{ Text = "Stay out of it", Result = "Both sides think you are a coward. Both sides leave you alive.", Effects = {} },
		},
	},

	culling_game_rumor = {
		Title = "Rules of a Killing Game",
		Text = "A message spreads through cursed energy itself: barriers around whole cities, points for every sorcerer killed.",
		MinAge = 18, MaxAge = 300, Weight = 0.04, MinRealm = 3,
		Options = {
			{ Text = "Enter to rescue civilians", Chance = 0.4, ChanceStat = "Strength",
				Result = "You walk out with points, scars and a dozen saved lives.", Effects = { Qi = 1, Counters = { Fights = 2 }, Karma = 4, Health = -15 },
				FailResult = "You barely survive the first colony.", FailEffects = { Health = -45, Stress = 15 } },
			{ Text = "Study the rules from outside", Result = "Rules are weaknesses. You find three.", Effects = { Stats = { Intelligence = 12 }, Counters = { Knowledge = 4 } } },
		},
	},

	reverse_technique = {
		Title = "Running It Backwards",
		Text = "Feeding positive energy into your innate technique makes it do the opposite of what it always did.",
		MinAge = 20, MaxAge = 5000, Weight = 0.05, MinRealm = 4,
		Options = {
			{ Text = "Master the reversal", Chance = 0.4, ChanceStat = "QiControl",
				Result = "Your technique has two faces now. Enemies cannot predict either.", Effects = { Qi = 1.5, Stats = { QiControl = 20 } },
				FailResult = "It backfires and burns your hands for a month.", FailEffects = { Health = -30 } },
			{ Text = "Keep it as a last resort", Result = "Some cards you only play once.", Effects = { Stats = { Intelligence = 10 } } },
		},
	},

	domain_awakening = {
		Title = "Your Domain Takes Shape",
		Text = "In a dream you stand in a world built entirely from your technique. You realise you could pull others into it.",
		MinAge = 25, MaxAge = 5000, Weight = 0.04, MinRealm = 5,
		Options = {
			{ Text = "Expand it for real", Chance = 0.35, ChanceStat = "QiControl",
				Result = "For one second your domain closes around a curse. Then it is gone, and so is the curse.", Effects = { Qi = 2, Proficiency = { QiArts = 25 }, MaxHealth = 15 },
				FailResult = "It collapses and leaves your technique burnt out for a season.", FailEffects = { Health = -35, Stress = 15 } },
			{ Text = "Refine it in meditation first", Result = "Patience. The domain will be stronger when it comes.", Effects = { Stats = { QiControl = 15, Intelligence = 6 } } },
		},
	},

	------------------------------------------------------------------ chain-only follow-ups

	sect_reward = {
		Title = "The Higher-Ups' Reward",
		Text = "A year after you reported the sealed cursed object, the higher-ups summon you to choose your reward.",
		ChainOnly = true,
		Options = {
			{ Text = "A technique scroll", Result = "Ancient cursed energy techniques, copied by hand.", Effects = { Qi = 1.5, Stats = { QiControl = 15 } } },
			{ Text = "A Reverse Cursed longevity treatment", Result = "Painful, precise, and worth a decade.", Effects = { Lifespan = 15 } },
			{ Text = "Shelter for your family", Requires = { HasRelationship = "Family" },
				Result = "Your family moves inside the school's barrier, safe at last.", Effects = { Karma = 4, Alignment = 5, Happiness = 10 } },
		},
	},

	poison_exposed = {
		Title = "The Poison Is Traced",
		Text = "A school medic traces the poison from the tournament back to you. The higher-ups want answers.",
		ChainOnly = true,
		Options = {
			{ Text = "Confess and accept punishment", Result = "A brutal suspension mission. Your conscience feels lighter.", Effects = { Health = -20, Alignment = 15, Karma = 2 } },
			{ Text = "Frame someone else", Chance = 0.4, ChanceStat = "Charisma",
				Result = "An innocent student takes the blame.", Effects = { Alignment = -20 },
				FailResult = "Your lie collapses. The punishment doubles.", FailEffects = { Health = -30, Alignment = -20, Karma = -5 } },
			{ Text = "Flee the region", Result = "You leave everything behind under cover of night.", Effects = { Happiness = -15, Money = -1000, Stress = 10 } },
		},
	},
}

return LifeEventsConfig
