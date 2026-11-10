--[[
	Everyday life events, evaluated by LifeEventsEngine on every birthday.

	Event fields:
		Title, Text            -> {name} = targeted relationship, {new} = a newly generated person
		MinAge, MaxAge         -> eligible age range (equal values = guaranteed that year)
		Weight                 -> chance per year while eligible
		Repeatable             -> may happen more than once per life
		Cooldown               -> minimum years between two occurrences of a repeatable event
		ChainOnly              -> never rolled yearly; only reached through a FollowUp
		                          (MinAge/MaxAge/Weight optional)
		Requires               -> Shared/Requirements spec the character must meet
		Target                 -> { Category, Type = {..}, MinAffection, MaxAffection, MinAge } picks an existing
		                          relationship, { Create = true } to introduce a new person as {new},
		                          or { Inherit = true } (ChainOnly) to reuse the parent event's person
		Options                -> 2-3 choices

	Option fields:
		Text, Result, Effects
		Chance, ChanceStat     -> success chance (+1% per level of ChanceStat); on failure FailResult/FailEffects
		Requires               -> requirement spec; unmet options are shown locked

	Effects:
		Stats = { Stat = xp }, Proficiency = { Key = xp }, Qi (fraction of current requirement),
		Health, MaxHealth, Happiness, Stress, Energy, Money, Karma, Alignment, Lifespan,
		Performance (grades), JobPerformance, Affection (on target), TargetBecomes ("Friend"/"Rival"/"Partner"),
		RemoveTarget, NewRelationship = { Type, Affection }, Counters = { Key = n }, Flags = { "flag" },
		Career (job id offered), QuitJob, Items = { itemId = count } (grant; negative removes)
		FollowUp = { Id, InYears }      -> queue another event now (InYears 0) or at a later birthday;
		                                   may be a list. Keeps this event's person for {name}/{new}.
		Delayed = { InYears, Text, Effects } -> silent consequence applied at a later birthday and
		                                   written to the journal; may be a list.
]]

local YearlyEventsConfig = {}

YearlyEventsConfig.Events = {
	first_words = {
		Title = "Your First Word",
		Text = "Your whole family leans in. You open your mouth and say...",
		MinAge = 1, MaxAge = 1, Weight = 1,
		Target = { Type = { "Mother" } },
		Options = {
			{ Text = "\"Mama!\"", Result = "{name} cries with joy.", Effects = { Affection = 10, Happiness = 5 } },
			{ Text = "\"Book!\"", Result = "Everyone agrees you will be a scholar.", Effects = { Stats = { Intelligence = 10 } } },
			{ Text = "\"No!\"", Result = "A strong will from day one.", Effects = { Stats = { Charisma = 6 }, Stress = 3 } },
		},
	},

	kindergarten_bully = {
		Title = "The Sandbox Tyrant",
		Text = "A bigger kid named {new} snatches your toy and laughs.",
		MinAge = 3, MaxAge = 5, Weight = 0.5,
		Requires = { Enrolled = "Kindergarten" },
		Target = { Create = true },
		Options = {
			{ Text = "Push them back", Chance = 0.4, ChanceStat = "Strength",
				Result = "{new} falls in the sand and leaves you alone.", Effects = { Stats = { Strength = 8 }, Counters = { Fights = 1 } },
				FailResult = "{new} pushes harder. You cry all afternoon.", FailEffects = { Happiness = -8, NewRelationship = { Type = "Rival", Affection = 15 } } },
			{ Text = "Tell the teacher", Result = "The teacher returns your toy. {new} glares at you.", Effects = { NewRelationship = { Type = "Rival", Affection = 25 } } },
			{ Text = "Offer to share", Result = "Surprised, {new} plays with you instead.", Effects = { Stats = { Charisma = 8 }, NewRelationship = { Type = "Friend", Affection = 50 }, Alignment = 3 } },
		},
	},

	lunch_table = {
		Title = "The Empty Seat",
		Text = "A shy classmate named {new} eats lunch alone every day.",
		MinAge = 6, MaxAge = 11, Weight = 0.35,
		Requires = { Enrolled = "PrimarySchool" },
		Target = { Create = true },
		Options = {
			{ Text = "Sit with them", Result = "{new} smiles for the first time this year.", Effects = { NewRelationship = { Type = "Friend", Affection = 60 }, Alignment = 5, Happiness = 4 } },
			{ Text = "Stay with your group", Result = "Nothing changes.", Effects = {} },
			{ Text = "Make fun of them", Result = "Your friends laugh. {new} never forgets.", Effects = { NewRelationship = { Type = "Rival", Affection = 20 }, Alignment = -6 } },
		},
	},

	stolen_notes = {
		Title = "Stolen Notes",
		Text = "The night before the big exam, a classmate named {new} steals your notes.",
		MinAge = 12, MaxAge = 15, Weight = 0.5,
		Requires = { Enrolled = "HighSchool" },
		Target = { Create = true },
		Options = {
			{ Text = "Confront them", Chance = 0.45, ChanceStat = "Charisma",
				Result = "{new} hands them back, embarrassed.", Effects = { Stats = { Charisma = 8 }, NewRelationship = { Type = "Rival", Affection = 35 },
					FollowUp = { Id = "notes_thief_returns", InYears = 4 } },
				FailResult = "{new} denies everything. You fail the exam.", FailEffects = { Performance = -12, Stress = 10, NewRelationship = { Type = "Rival", Affection = 15 } } },
			{ Text = "Rewrite them overnight", Result = "Exhausted, but you know the material cold.", Effects = { Stats = { Intelligence = 18 }, Stress = 12, Performance = 6 } },
			{ Text = "Recite from memory", Requires = { Counters = { Knowledge = 8 } },
				Result = "Your reading pays off. You ace the exam anyway.", Effects = { Performance = 15, Happiness = 8 } },
		},
	},

	exam_or_party = {
		Title = "Exam Week or Party Week",
		Text = "You turn 16. Finals start Monday, but everyone is going to the summer fireworks festival.",
		MinAge = 16, MaxAge = 16, Weight = 1,
		Requires = { Enrolled = "HighSchool" },
		Options = {
			{ Text = "Study all weekend", Result = "Your grades soar. Your social life does not.", Effects = { Performance = 15, Stats = { Intelligence = 20 }, Stress = 10, Happiness = -5 } },
			{ Text = "Go to the party", Result = "Best night of your life. Worst exam of your life.", Effects = { Happiness = 15, Stats = { Charisma = 15 }, Performance = -10, Stress = -10 } },
			{ Text = "Study, then party", Requires = { Stats = { Intelligence = 12 } },
				Result = "You somehow manage both.", Effects = { Performance = 8, Happiness = 8, Stats = { Charisma = 6, Intelligence = 6 } } },
		},
	},

	schoolyard_fight = {
		Title = "Behind the Gym",
		Text = "A group of older students corners you after class.",
		MinAge = 12, MaxAge = 17, Weight = 0.2,
		Options = {
			{ Text = "Fight", Chance = 0.35, ChanceStat = "Strength",
				Result = "You win. Word spreads fast.", Effects = { Counters = { Fights = 1 }, Stats = { Strength = 10 }, Happiness = 5 },
				FailResult = "You get beaten badly.", FailEffects = { Health = -20, Happiness = -10 } },
			{ Text = "Run", Chance = 0.5, ChanceStat = "Agility",
				Result = "Nobody can catch you.", Effects = { Stats = { Agility = 10 } },
				FailResult = "They catch you anyway.", FailEffects = { Health = -12, Happiness = -6 } },
			{ Text = "Talk your way out", Chance = 0.4, ChanceStat = "Charisma",
				Result = "You end up laughing together.", Effects = { Stats = { Charisma = 10 } },
				FailResult = "They do not find you funny.", FailEffects = { Health = -10 } },
		},
	},

	talent_show = {
		Title = "The Talent Show",
		Text = "Your school is hosting a talent show. Your name is already on the list.",
		MinAge = 8, MaxAge = 17, Weight = 0.12,
		Options = {
			{ Text = "Perform a song", Chance = 0.4, ChanceStat = "Charisma",
				Result = "Standing ovation!", Effects = { Happiness = 12, Stats = { Charisma = 14 } },
				FailResult = "Your voice cracks. People laugh.", FailEffects = { Happiness = -10, Stress = 8 } },
			{ Text = "Show off taijutsu forms", Chance = 0.5, ChanceStat = "Agility",
				Result = "The crowd gasps at your speed.", Effects = { Happiness = 10, Stats = { Agility = 10 } },
				FailResult = "You trip over your own feet.", FailEffects = { Health = -5, Happiness = -6 } },
			{ Text = "Withdraw", Result = "You watch from the back row.", Effects = { Stress = -3 } },
		},
	},

	part_time_offer = {
		Title = "A Part-Time Job",
		Text = "The ramen shop owner offers you a part-time job after school.",
		MinAge = 15, MaxAge = 17, Weight = 0.3,
		Requires = { Employed = false },
		Options = {
			{ Text = "Accept", Result = "You start serving ramen every evening.", Effects = { Career = "StreetVendor", Money = 100, Stress = 4 } },
			{ Text = "Decline to focus on school", Result = "Your parents approve.", Effects = { Performance = 5 } },
		},
	},

	lost_wallet = {
		Title = "A Lost Wallet",
		Text = "You find a wallet stuffed with yen on the train platform.",
		MinAge = 10, MaxAge = 90, Weight = 0.1, Repeatable = true, Cooldown = 10,
		Options = {
			{ Text = "Return it", Result = "The owner, a shrine keeper, rewards your honesty with a protective omamori.", Effects = { Karma = 2, Alignment = 8, Money = 100, Items = { lucky_charm = 1 } } },
			{ Text = "Keep it", Result = "Easy money. Your conscience itches.", Effects = { Money = 600, Alignment = -8,
				FollowUp = { Id = "purse_owner", InYears = 2 } } },
		},
	},

	romance = {
		Title = "Summer Festival",
		Text = "At the summer festival, {new} catches your eye and smiles.",
		MinAge = 17, MaxAge = 45, Weight = 0.15, Repeatable = true, Cooldown = 3,
		Requires = { NoRelationship = "Partner" },
		Target = { Create = true },
		Options = {
			{ Text = "Ask them out", Chance = 0.4, ChanceStat = "Charisma",
				Result = "{new} says yes. Your heart races.", Effects = { NewRelationship = { Type = "Partner", Affection = 65 }, Happiness = 15 },
				FailResult = "{new} politely declines.", FailEffects = { Happiness = -6 } },
			{ Text = "Just be friends", Result = "You talk until the last firework fades.", Effects = { NewRelationship = { Type = "Friend", Affection = 55 } } },
			{ Text = "Walk away", Result = "Some chances only come once.", Effects = {} },
		},
	},

	proposal = {
		Title = "A Question of Forever",
		Text = "{name} takes your hands under the cherry blossoms. \"Will you marry me?\"",
		MinAge = 18, MaxAge = 80, Weight = 0.25,
		Requires = { NotFlag = "Married" },
		Target = { Category = "Partner", MinAffection = 75 },
		Options = {
			{ Text = "Yes!", Result = "A joyous shrine wedding fills the neighborhood with music.", Effects = { Flags = { "Married" }, Happiness = 25, Affection = 15, Money = -1000 } },
			{ Text = "Not yet", Result = "{name} is hurt, but understands.", Effects = { Affection = -12 } },
		},
	},

	friend_in_need = {
		Title = "A Friend in Need",
		Text = "{name} needs money for their sick mother's medicine.",
		MinAge = 14, MaxAge = 90, Weight = 0.12, Repeatable = true, Cooldown = 5,
		Target = { Category = "Friend", MinAffection = 45 },
		Options = {
			{ Text = "Lend ¥500", Requires = { MinMoney = 500 }, Result = "{name} will never forget this.", Effects = { Money = -500, Affection = 20, Karma = 2, Alignment = 5,
				Delayed = { InYears = 3, Text = "{name} repays your ¥500 loan, with interest and a long hug.", Effects = { Money = 800, Affection = 10 } } } },
			{ Text = "Help them find work", Requires = { Stats = { Charisma = 12 } }, Result = "Your connections land them a job.", Effects = { Affection = 15, Stats = { Charisma = 6 } } },
			{ Text = "Refuse", Result = "{name} leaves without a word.", Effects = { Affection = -15 } },
		},
	},

	friend_betrayal = {
		Title = "Whispers Behind Your Back",
		Text = "You learn that {name} has been spreading rumors about you.",
		MinAge = 10, MaxAge = 100, Weight = 0.2, Repeatable = true, Cooldown = 4,
		Target = { Category = "Friend", MaxAffection = 30 },
		Options = {
			{ Text = "Confront them", Result = "The friendship is over. {name} is now your rival.", Effects = { TargetBecomes = "Rival", Affection = -10, Stress = 5 } },
			{ Text = "Forgive them", Result = "{name} is ashamed and apologizes.", Effects = { Affection = 20, Alignment = 5, Stress = 5 } },
			{ Text = "Get revenge", Result = "You ruin their reputation in return.", Effects = { TargetBecomes = "Rival", Alignment = -10, Happiness = 5 } },
		},
	},

	friend_help = {
		Title = "A Loyal Friend",
		Text = "{name} shows up at your door. \"I heard you could use some help.\"",
		MinAge = 10, MaxAge = 100, Weight = 0.15, Repeatable = true, Cooldown = 4,
		Target = { Category = "Friend", MinAffection = 80 },
		Options = {
			{ Text = "Train together", Result = "You push each other to new limits.", Effects = { Stats = { Strength = 15, Agility = 10 }, Affection = 5 } },
			{ Text = "Study together", Result = "Two minds are better than one.", Effects = { Stats = { Intelligence = 18 }, Affection = 5 } },
			{ Text = "Accept a loan", Result = "{name} insists you take it.", Effects = { Money = 1500, Affection = -3 } },
		},
	},

	rival_challenge = {
		Title = "A Public Challenge",
		Text = "{name} challenges you on the school grounds in front of everyone.",
		MinAge = 10, MaxAge = 120, Weight = 0.18, Repeatable = true, Cooldown = 3,
		Target = { Category = "Rival" },
		Options = {
			{ Text = "Accept the challenge", Chance = 0.4, ChanceStat = "Strength",
				Result = "You win decisively. The crowd cheers.", Effects = { Counters = { Fights = 1 }, Happiness = 10, Stats = { Strength = 10 }, Affection = 10 },
				FailResult = "{name} humiliates you.", FailEffects = { Health = -18, Happiness = -10 } },
			{ Text = "Offer friendship", Chance = 0.3, ChanceStat = "Charisma",
				Result = "{name} hesitates... then shakes your hand.", Effects = { TargetBecomes = "Friend", Affection = 30, Alignment = 5 },
				FailResult = "{name} spits at your feet.", FailEffects = { Happiness = -5 } },
			{ Text = "Walk away", Result = "People whisper that you are a coward.", Effects = { Happiness = -6, Stress = 4 } },
		},
	},

	parent_illness = {
		Title = "Failing Health",
		Text = "{name} has fallen seriously ill.",
		MinAge = 12, MaxAge = 90, Weight = 0.1,
		Target = { Type = { "Mother", "Father" }, MinAge = 55 },
		Options = {
			{ Text = "Pay a Reverse Cursed healer (¥2K)", Requires = { MinMoney = 2000 }, Result = "{name} recovers fully.", Effects = { Money = -2000, Affection = 15, Karma = 2 } },
			{ Text = "Care for them yourself", Result = "Long nights at the bedside bring you closer.", Effects = { Affection = 20, Stress = 15, Alignment = 5 } },
			{ Text = "Stay away", Result = "{name} feels abandoned.", Effects = { Affection = -25, Alignment = -8 } },
		},
	},

	library_manual = {
		Title = "The Hidden Technique Scroll",
		Text = "Behind a loose shelf in the library you find a jujutsu technique scroll sealed with talismans.",
		MinAge = 10, MaxAge = 200, Weight = 0.15,
		Requires = { Counters = { Knowledge = 10 } },
		Options = {
			{ Text = "Study it in secret", Result = "The cursed energy patterns are real.", Effects = { Qi = 1, Stats = { QiControl = 25 } } },
			{ Text = "Return it to the librarian", Result = "The old librarian nods knowingly.", Effects = { Karma = 3, Alignment = 5, Stats = { Intelligence = 10 } } },
		},
	},

	mugging = {
		Title = "Dark Alley",
		Text = "A masked thug blocks your path. A tiny curse clings to his shoulder. \"Your money or your life.\"",
		MinAge = 16, MaxAge = 90, Weight = 0.08, Repeatable = true, Cooldown = 5,
		Options = {
			{ Text = "Fight back", Chance = 0.35, ChanceStat = "Strength",
				Result = "The thug flees, bruised.", Effects = { Counters = { Fights = 1 }, Stats = { Strength = 8 },
					FollowUp = { Id = "watch_captain", InYears = 0 } },
				FailResult = "You get stabbed.", FailEffects = { Health = -30 } },
			{ Text = "Run", Chance = 0.5, ChanceStat = "Agility",
				Result = "You vanish into the crowd.", Effects = { Stats = { Agility = 8 } },
				FailResult = "He catches you and takes everything.", FailEffects = { Money = -400, Health = -10 } },
			{ Text = "Hand over your wallet", Result = "You lose some money but stay safe.", Effects = { Money = -250, Stress = 6 } },
		},
	},

	promotion = {
		Title = "A Promotion",
		Text = "Your boss offers you a promotion with more responsibility.",
		MinAge = 18, MaxAge = 80, Weight = 0.15, Repeatable = true, Cooldown = 4,
		Requires = { Employed = true },
		Options = {
			{ Text = "Accept", Result = "Longer hours, bigger pay.", Effects = { JobPerformance = 20, Money = 1000, Stress = 10 } },
			{ Text = "Decline", Result = "You keep your evenings free.", Effects = { Happiness = 3 } },
		},
	},

	burnout = {
		Title = "Burnout",
		Text = "You wake up and cannot get out of bed. Everything feels heavy.",
		MinAge = 14, MaxAge = 200, Weight = 0.5, Repeatable = true, Cooldown = 3,
		Requires = { MinStress = 70 },
		Options = {
			{ Text = "Visit a hot spring (¥1K)", Requires = { MinMoney = 1000 }, Result = "The onsen does wonders.", Effects = { Money = -1000, Stress = -40, Happiness = 10 } },
			{ Text = "Visit a shrine", Result = "The priest teaches you to steady your cursed energy.", Effects = { Stress = -25, Stats = { QiControl = 8 } } },
			{ Text = "Push through", Result = "You keep going, but something breaks inside.", Effects = { Stress = 10, Health = -15 } },
		},
	},

	midlife = {
		Title = "Midlife Reflection",
		Text = "Halfway through a sorcerer's short life, you wonder if this is all there is.",
		MinAge = 40, MaxAge = 50, Weight = 0.15,
		Options = {
			{ Text = "Buy a graded cursed katana (¥5K)", Requires = { MinMoney = 5000 }, Result = "It hums in your hands. You feel young again.", Effects = { Money = -5000, Happiness = 15, Proficiency = { Sword = 30 } } },
			{ Text = "Take up calligraphy", Result = "Patient strokes calm your mind.", Effects = { Stats = { Intelligence = 12, QiControl = 8 }, Stress = -10 } },
			{ Text = "Quit your job and travel", Requires = { Employed = true }, Result = "Freedom tastes like road dust.", Effects = { QuitJob = true, Happiness = 15, Stress = -25 } },
		},
	},

	inheritance = {
		Title = "An Unexpected Will",
		Text = "A distant uncle you barely remember has left you his fortune.",
		MinAge = 25, MaxAge = 90, Weight = 0.04,
		Options = {
			{ Text = "Keep it all", Result = "¥10K richer, plus your uncle's sealed, withered finger.", Effects = { Money = 10000, Items = { jade_bracelet = 1 } } },
			{ Text = "Donate half to orphanages", Result = "Children across the city eat well this winter.", Effects = { Money = 5000, Karma = 6, Alignment = 10 } },
		},
	},

	old_friend = {
		Title = "An Old Friend",
		Text = "You bump into {name} after many years. Memories flood back.",
		MinAge = 30, MaxAge = 150, Weight = 0.08, Repeatable = true, Cooldown = 6,
		Target = { Category = "Friend", MaxAffection = 60 },
		Options = {
			{ Text = "Catch up over sake", Result = "It is like no time has passed.", Effects = { Affection = 20, Happiness = 8 } },
			{ Text = "Make an excuse and leave", Result = "Some bridges fade on their own.", Effects = { Affection = -10 } },
		},
	},

	------------------------------------------------------------------ chain-only follow-ups

	notes_thief_returns = {
		Title = "An Old Debt",
		Text = "Years later, {name}, the classmate who once stole your notes, knocks on your door looking sheepish.",
		ChainOnly = true,
		Target = { Inherit = true },
		Options = {
			{ Text = "Forgive and start over", Result = "You laugh about it over tea. {name} becomes a friend.", Effects = { TargetBecomes = "Friend", Affection = 25, Alignment = 5 } },
			{ Text = "Remind them what they did", Result = "{name} leaves red-faced. It felt good.", Effects = { Affection = -10, Happiness = 4 } },
			{ Text = "Ask for a favor in return", Chance = 0.5, ChanceStat = "Charisma",
				Result = "{name} pays you back with interest.", Effects = { Money = 400 },
				FailResult = "{name} refuses and storms off.", FailEffects = { Affection = -15 } },
		},
	},

	purse_owner = {
		Title = "The Owner Remembers",
		Text = "The wallet's owner recognizes it in your hand and calls the police.",
		ChainOnly = true,
		Options = {
			{ Text = "Confess and repay", Result = "You hand over the money and apologize.", Effects = { Money = -600, Karma = 2, Alignment = 5 } },
			{ Text = "Talk your way out", Chance = 0.35, ChanceStat = "Charisma",
				Result = "He decides it must be a different wallet.", Effects = { Happiness = 3 },
				FailResult = "The police fine you and rough you up.", FailEffects = { Money = -800, Health = -10, Alignment = -5 } },
			{ Text = "Run", Chance = 0.5, ChanceStat = "Agility",
				Result = "You vanish down an alley.", Effects = { Stats = { Agility = 8 }, Alignment = -3 },
				FailResult = "They catch you at the station gates.", FailEffects = { Health = -15, Money = -600 } },
		},
	},

	watch_captain = {
		Title = "The Auxiliary Manager",
		Text = "A jujutsu auxiliary manager saw the whole fight and walks over, impressed.",
		ChainOnly = true,
		Options = {
			{ Text = "Accept a reward", Result = "She presses an envelope of yen into your hand.", Effects = { Money = 300, Karma = 1 } },
			{ Text = "Ask to train with sorcerers", Result = "Months of drills with real exorcists.", Effects = { Stats = { Strength = 15, Agility = 8 } } },
			{ Text = "Decline modestly", Result = "Word of your humility spreads.", Effects = { Alignment = 5, Karma = 2 } },
		},
	},

	-- Samsara module: past lives, eras and legends (Modules/SamsaraSystem).
	past_life_encounter = {
		Module = "Samsara",
		Title = "A Familiar Stranger",
		Text = "On a crowded train platform an old face stops and stares at you, as if they have known you forever.",
		MinAge = 12, MaxAge = 90, Weight = 0.2, Repeatable = true, Cooldown = 6,
		Requires = { HasEcho = true },
		Options = {
			{ Text = "\"We have met before... in another life.\"", Requires = { RemembersPastLife = true },
				Result = "Their eyes fill with tears. The old bond wakes again.", Effects = { MeetEcho = 30, Karma = 2, Happiness = 10 } },
			{ Text = "Introduce yourself", Result = "You talk for hours, strangely at ease.", Effects = { MeetEcho = 0, Happiness = 4 } },
			{ Text = "Walk on", Result = "The feeling lingers for days.", Effects = { Stress = 2 } },
		},
	},

	primordial_beast = {
		Module = "Samsara",
		Title = "A Heian-Era Curse",
		Text = "The Heian era is not like the tame world you remember. A colossal ancient curse blocks the mountain path.",
		MinAge = 13, MaxAge = 200, Weight = 0.18, Repeatable = true, Cooldown = 5, -- a lethal fight: teens and up
		Requires = { Era = "Ancient" },
		Options = {
			{ Text = "Fight it", Chance = 0.45, ChanceStat = "Strength",
				Result = "You exorcise it and absorb the cursed energy it leaves behind.", Effects = { Qi = 0.3, Stats = { Strength = 15 }, Counters = { Fights = 1 } },
				FailResult = "It throws you down the cliff.", FailEffects = { Health = -35 } },
			{ Text = "Hide and observe", Chance = 0.6, ChanceStat = "Agility",
				Result = "You learn how it moves its cursed energy.", Effects = { Stats = { QiControl = 10 } },
				FailResult = "It smells you anyway.", FailEffects = { Health = -15 } },
			{ Text = "Turn back", Result = "You live to see another day.", Effects = { Stress = 4 } },
		},
	},

	rival_mentor = {
		Module = "Samsara",
		Title = "The Mentor Who Was Your Enemy",
		Text = "The most feared sorcerer in the region is taking students. You know that face: your arch-rival from a past life. They look straight at you and see a stranger.",
		MinAge = 12, MaxAge = 60, Weight = 0.35, Repeatable = true, Cooldown = 4,
		Requires = { RivalMentorHere = true, IsRivalDisciple = false },
		Options = {
			{ Text = "Bow and ask to become their student", Result = "Your old enemy accepts you. The irony burns.", Effects = { BecomeRivalDisciple = true } },
			{ Text = "Study them from the shadows", Result = "You learn their habits, for now.", Effects = { Stats = { Intelligence = 6 } } },
			{ Text = "Leave the past buried", Result = "Some debts can wait another lifetime.", Effects = { Stress = -3 } },
		},
	},

	rival_reckoning = {
		Module = "Samsara", Trigger = "System", ChainOnly = true,
		Title = "Mentor and Student, Rival and Rival",
		Text = "Your mentor has taught you everything, including their innate technique. Tonight, under the same moon as the duel from your past life, you could tell them who you really are.",
		Options = {
			{ Text = "Reveal your past life and duel them", Requires = { RemembersPastLife = true }, Chance = 0.45, ChanceStat = "Strength",
				Result = "Recognition, then fear. A Black Flash settles a feud older than this body.", Effects = { RivalReckoning = "Revenge", Counters = { Fights = 1 } },
				FailResult = "They win again and throw you down the mountain.", FailEffects = { RivalReckoning = "Defeat", Health = -40 } },
			{ Text = "Keep the secret and inherit their legacy", Result = "You bow. The hatred of two lifetimes becomes gratitude.", Effects = { RivalReckoning = "Legacy", Karma = 3 } },
		},
	},

	heirloom_reclaim = {
		Module = "Dynasty",
		Title = "Your Own Heirloom",
		Text = "In a back-alley shop you recognize it at once: the cursed tool you bound in a past life, now carried by a descendant of your old family. Your name is still on the seal.",
		MinAge = 14, MaxAge = 300, Weight = 0.4, Repeatable = true, Cooldown = 3,
		Requires = { LostHeirloomHere = true },
		Options = {
			{ Text = "Buy it back (¥1.5K)", Requires = { MinMoney = 1500 }, Result = "They sell, puzzled by your tears.", Effects = { Money = -1500, ReclaimHeirloom = "Buy" } },
			{ Text = "Challenge them to a duel for it", Result = "Cursed energy flares in the alley.", Effects = { StartDuel = "Heirloom" } },
			{ Text = "Steal it in the night", Chance = 0.5, ChanceStat = "Agility",
				Result = "It was yours first.", Effects = { ReclaimHeirloom = "Steal", Alignment = -10 },
				FailResult = "The shop's ward catches you.", FailEffects = { Money = -500, Health = -10, Alignment = -5 } },
		},
	},

	child_born = {
		Module = "Dynasty",
		Title = "A New Life",
		Text = "{name} takes your hand, eyes shining. A child is on the way.",
		MinAge = 19, MaxAge = 45, Weight = 0.1, Repeatable = true, Cooldown = 4,
		Target = { Category = "Partner", MinAffection = 60 },
		Options = {
			{ Text = "Welcome the baby", Result = "Your family grows by one.", Effects = { HaveChild = true, Happiness = 15 } },
			{ Text = "Name them after an ancestor", Result = "An old name lives again.", Effects = { HaveChild = true, Karma = 1 } },
		},
	},

	grandfather_homestead = {
		Module = "Dynasty",
		Title = "Grandfather's Homestead",
		Text = "Your parents take you to the old homestead in the hills, where an old man has been waiting for years to meet you.",
		MinAge = 5, MaxAge = 12, Weight = 0.3,
		Options = {
			{ Text = "Listen to his stories", Result = "He tells you about ancestors you never knew.", Effects = { MeetRelative = "Grandfather", Stats = { Intelligence = 6 }, Happiness = 6 } },
			{ Text = "Explore the farm", Result = "He laughs and shows you the old well.", Effects = { MeetRelative = "Grandfather", Stats = { Agility = 6 } } },
		},
	},

	cousin_visit = {
		Module = "Dynasty",
		Title = "A Cousin Visits",
		Text = "A cousin from the clan's branch family arrives with a bag full of gifts and gossip.",
		MinAge = 8, MaxAge = 20, Weight = 0.2,
		Options = {
			{ Text = "Show them around", Result = "You become fast friends.", Effects = { MeetRelative = "Cousin", Stats = { Charisma = 6 } } },
			{ Text = "Compete with them", Result = "Family rivalry, the healthy kind.", Effects = { MeetRelative = "Cousin", Stats = { Strength = 6 } } },
		},
	},

	legend_of_self = {
		Module = "Samsara",
		Title = "A Legend You Remember",
		Text = "A storyteller at the summer festival tells the tale of a sorcerer from a hundred years ago. The story sounds... very familiar.",
		MinAge = 8, MaxAge = 60, Weight = 0.3,
		Requires = { Era = "Future" },
		Options = {
			{ Text = "Listen closely", Result = "You hear your own past told by strangers.", Effects = { LegendOfSelf = true } },
			{ Text = "Correct the storyteller", Requires = { RemembersPastLife = true },
				Result = "The crowd falls silent as you recount details no one could know.", Effects = { LegendOfSelf = true, Karma = 2, Stats = { Charisma = 8 } } },
		},
	},
	-- Content expansion (2026-11-02): 35 more yearly events, Cursed Path only.
	thing_under_bed = {
		Title = "The Thing Under the Bed",
		Text = "Every night something with too many teeth breathes under your bed. Nobody else can see it.",
		MinAge = 3, MaxAge = 6, Weight = 0.4,
		Options = {
			{ Text = "Stare it down", Chance = 0.5, ChanceStat = "QiControl",
				Result = "It shrinks away from your glare and never comes back.", Effects = { Stats = { QiControl = 6 }, Happiness = 4 },
				FailResult = "It stares back. You sleep with the lights on for a year.", FailEffects = { Stress = 8 } },
			{ Text = "Sleep in your parents' room", Result = "Warm, safe, and a little embarrassing.", Effects = { Happiness = 5 } },
		},
	},

	crayon_curse = {
		Title = "A Drawing That Moves",
		Text = "You draw a little monster in crayon. In the morning it has crawled to the other corner of the page.",
		MinAge = 4, MaxAge = 8, Weight = 0.25,
		Options = {
			{ Text = "Draw it a friend", Result = "Two little monsters now wave at you. You feel strangely proud.", Effects = { Stats = { QiControl = 5, Intelligence = 3 } } },
			{ Text = "Rip it up", Result = "The pieces twitch, then go still. Your hands tingle.", Effects = { Stats = { Strength = 4 }, Stress = 3 } },
		},
	},

	playground_ghost_story = {
		Title = "The Fourth-Floor Toilet",
		Text = "{new} dares you to knock three times on the haunted stall on the fourth floor.",
		MinAge = 7, MaxAge = 11, Weight = 0.35,
		Requires = { Enrolled = "PrimarySchool" },
		Target = { Create = true },
		Options = {
			{ Text = "Knock three times", Chance = 0.55, ChanceStat = "QiControl",
				Result = "A tiny curse squeaks and flees. {new} thinks you are a legend.", Effects = { Stats = { QiControl = 6 }, NewRelationship = { Type = "Friend", Affection = 45 } },
				FailResult = "Something knocks back. You both run screaming.", FailEffects = { Stress = 6, NewRelationship = { Type = "Friend", Affection = 30 } } },
			{ Text = "Refuse the dare", Result = "{new} calls you a chicken all week.", Effects = { NewRelationship = { Type = "Rival", Affection = 20 } } },
		},
	},

	cursed_classroom = {
		Title = "Heavy Air in Class",
		Text = "Your classmates are sleepy and sick. A grey smudge clings to the ceiling above the teacher's desk.",
		MinAge = 8, MaxAge = 15, Weight = 0.3,
		Options = {
			{ Text = "Open every window", Result = "Fresh air thins it out. The class wakes up.", Effects = { Stats = { Intelligence = 4 }, Alignment = 2 } },
			{ Text = "Punch the smudge after school", Chance = 0.45, ChanceStat = "Strength",
				Result = "It pops like a soap bubble. Your knuckles glow faintly.", Effects = { Stats = { Strength = 6, QiControl = 6 }, Counters = { Fights = 1 } },
				FailResult = "Your fist goes straight through. You fall off the desk.", FailEffects = { Health = -6 } },
		},
	},

	curse_glimpse = {
		Title = "Black Uniform on the Rooftop",
		Text = "Walking home, you see a student in a dark uniform leap between rooftops, chasing something only you can see.",
		MinAge = 9, MaxAge = 15, Weight = 0.3,
		Options = {
			{ Text = "Follow from the street", Result = "You lose them, but they noticed you noticing.",
				Effects = { Stats = { Agility = 5 }, FollowUp = { Id = "window_agent_visit", InYears = 1 } } },
			{ Text = "Pretend you saw nothing", Result = "Some things are better left unseen.", Effects = { Stress = -2 } },
		},
	},

	window_agent_visit = {
		ChainOnly = true,
		Title = "A Window Comes Knocking",
		Text = "A tired man in a suit shows a badge from an office that does not exist. \"You can see them, right? We should talk.\"",
		Options = {
			{ Text = "Hear him out", Result = "He leaves a card and a list of places to never go at night.", Effects = { Stats = { Intelligence = 6, QiControl = 6 }, Qi = 0.2 } },
			{ Text = "Slam the door", Result = "The card is in your mailbox the next morning anyway.", Effects = { Stress = 3 } },
		},
	},

	vending_machine_curse = {
		Title = "The Hungry Vending Machine",
		Text = "The vending machine by the station eats coins and hums in a voice only you can hear.",
		MinAge = 10, MaxAge = 40, Weight = 0.15,
		Options = {
			{ Text = "Kick it hard", Chance = 0.5, ChanceStat = "Strength",
				Result = "The curse inside pops. Every can falls out at once.", Effects = { Money = 40, Stats = { Strength = 5 } },
				FailResult = "It keeps your coins and your dignity.", FailEffects = { Money = -10, Happiness = -3 } },
			{ Text = "Feed it a coin out of pity", Result = "It hums a happy tune. You feel oddly lucky.", Effects = { Money = -5, Karma = 1 } },
		},
	},

	sports_day_sabotage = {
		Title = "Sports Day Relay",
		Text = "Your class is losing the relay. {new} on the other team keeps tripping your runners on purpose.",
		MinAge = 9, MaxAge = 17, Weight = 0.25,
		Target = { Create = true },
		Options = {
			{ Text = "Run the anchor leg yourself", Chance = 0.5, ChanceStat = "Agility",
				Result = "You fly past {new} at the line. The class carries you on their shoulders.", Effects = { Stats = { Agility = 8 }, Happiness = 8 },
				FailResult = "{new} wins by a step and smirks the whole way home.", FailEffects = { NewRelationship = { Type = "Rival", Affection = 15 } } },
			{ Text = "Report it to the referee", Result = "{new} is disqualified and hates you for it.", Effects = { Alignment = 2, NewRelationship = { Type = "Rival", Affection = 10 } } },
		},
	},

	cursed_object_flea = {
		Title = "Flea Market Find",
		Text = "A stall at the flea market sells an old wooden box sealed with yellowed talismans. The seller wants ¥300.",
		MinAge = 11, MaxAge = 80, Weight = 0.15,
		Requires = { MinMoney = 300 },
		Options = {
			{ Text = "Buy it and peel one seal", Chance = 0.4, ChanceStat = "QiControl",
				Result = "A trickle of old cursed energy flows into you before you reseal it.", Effects = { Money = -300, Qi = 0.25, Stats = { QiControl = 8 }, Items = { broken_cursed_tool = 1 } },
				FailResult = "Something bites your thumb and escapes through the window.", FailEffects = { Money = -300, Health = -12, Stress = 6 } },
			{ Text = "Warn the seller it is cursed", Result = "He laughs, then quietly moves it under the table.", Effects = { Alignment = 3 } },
			{ Text = "Walk away", Result = "You feel it watching you leave.", Effects = {} },
		},
	},

	exorcism_club = {
		Title = "The Occult Research Club",
		Text = "The school's occult club is three nerds, a camera and a Ouija board. They want you to join.",
		MinAge = 12, MaxAge = 17, Weight = 0.3,
		Requires = { Enrolled = "HighSchool" },
		Target = { Create = true },
		Options = {
			{ Text = "Join and keep them safe", Result = "You quietly exorcise whatever they summon. {new} becomes a loyal friend.", Effects = { Stats = { QiControl = 6, Charisma = 4 }, NewRelationship = { Type = "Friend", Affection = 50 } } },
			{ Text = "Join for the snacks", Result = "Good snacks, terrible ghosts.", Effects = { Happiness = 6, Counters = { Knowledge = 2 } } },
			{ Text = "Decline", Result = "Their board summons nothing anyway. Probably.", Effects = {} },
		},
	},

	midnight_tunnel = {
		Title = "The Midnight Tunnel",
		Text = "Classmates dare each other to walk through the old tunnel at midnight. Two never came back last year.",
		MinAge = 13, MaxAge = 18, Weight = 0.2,
		Options = {
			{ Text = "Walk through and clear it", Chance = 0.4, ChanceStat = "QiControl",
				Result = "You find the curse nesting in the dark and tear it apart.", Effects = { Qi = 0.3, Stats = { QiControl = 10 }, Counters = { Fights = 1 } },
				FailResult = "It nearly drags you into the wall. You crawl out bleeding.", FailEffects = { Health = -18, Stress = 8 } },
			{ Text = "Talk everyone out of it", Chance = 0.6, ChanceStat = "Charisma",
				Result = "Nobody goes in. Nobody disappears.", Effects = { Stats = { Charisma = 8 }, Alignment = 3 },
				FailResult = "They go anyway and call you a coward.", FailEffects = { Happiness = -5 } },
		},
	},

	shrine_festival = {
		Title = "Summer Shrine Festival",
		Text = "Lanterns, takoyaki and fireworks. Under the noise, the old shrine's seal hums a little louder each year.",
		MinAge = 6, MaxAge = 90, Weight = 0.15, Repeatable = true, Cooldown = 6,
		Options = {
			{ Text = "Enjoy the festival", Result = "Goldfish scooping, candied apples and a good night.", Effects = { Happiness = 10, Stress = -6 } },
			{ Text = "Check the seal", Result = "You patch a crack in the talisman before anyone notices.", Effects = { Karma = 1, Stats = { QiControl = 4 } } },
		},
	},

	sealed_finger_rumor = {
		Title = "A Rumour of a Rotten Finger",
		Text = "Students whisper about a mummified finger in the school's old trophy case, wrapped in cloth no one is allowed to touch.",
		MinAge = 13, MaxAge = 18, Weight = 0.12,
		Requires = { Enrolled = "HighSchool" },
		Options = {
			{ Text = "Report it to a Window agent", Result = "Sorcerers seal it away overnight. You get a quiet thank-you letter.", Effects = { Alignment = 4, Karma = 2 } },
			{ Text = "Look, but never touch", Result = "Its presence makes your teeth ache. You learn what real cursed energy feels like.", Effects = { Stats = { QiControl = 8 }, Stress = 6 } },
		},
	},

	first_curse_kill = {
		Title = "Your First Exorcism",
		Text = "A Grade 4 curse corners a child in the park. Nobody else can see it. Nobody else is coming.",
		MinAge = 10, MaxAge = 30, Weight = 0.25,
		Requires = { Flag = "SpiritRoot" },
		Options = {
			{ Text = "Exorcise it", Chance = 0.55, ChanceStat = "Strength",
				Result = "It dissolves under your fists. The child stares at you like a hero.", Effects = { Qi = 0.3, Counters = { Fights = 1 }, Karma = 2, Stats = { Strength = 8 } },
				FailResult = "You drive it off, but it leaves claw marks across your arm.", FailEffects = { Health = -15, Karma = 1 } },
			{ Text = "Grab the child and run", Result = "Both of you get away. Running counts too.", Effects = { Stats = { Agility = 8 }, Alignment = 3 } },
		},
	},

	cram_school_curse = {
		Title = "Cram School Despair",
		Text = "Exam stress at the cram school has grown a curse. It whispers that you will fail.",
		MinAge = 14, MaxAge = 18, Weight = 0.2,
		Requires = { MinStress = 30 },
		Options = {
			{ Text = "Study harder out of spite", Result = "Your grades rise. The whispers fade.", Effects = { Stats = { Intelligence = 10 }, Performance = 6, Stress = 4 } },
			{ Text = "Exorcise the curse", Chance = 0.5, ChanceStat = "QiControl",
				Result = "It pops. Every student in the room exhales at once.", Effects = { Stress = -12, Stats = { QiControl = 6 } },
				FailResult = "It slips into the vents. Exam season is long.", FailEffects = { Stress = 6 } },
		},
	},

	binding_vow_offer = {
		Title = "A Small Binding Vow",
		Text = "You learn a trick: promise yourself something hard, and your cursed energy answers with something stronger.",
		MinAge = 14, MaxAge = 200, Weight = 0.12,
		Requires = { Flag = "SpiritRoot" },
		Options = {
			{ Text = "Vow to train before every dawn", Result = "The vow binds. Your body obeys it, and grows.", Effects = { Stats = { Strength = 8, Vitality = 6 }, Stress = 4, Karma = 1 } },
			{ Text = "Vow never to lie", Result = "Your words carry strange weight from now on.", Effects = { Stats = { Charisma = 10 }, Alignment = 4, Karma = 1 } },
			{ Text = "Make no vows", Result = "Freedom has its own value.", Effects = { Happiness = 3 } },
		},
	},

	curtain_trapped = {
		Title = "Trapped Inside a Curtain",
		Text = "A black curtain falls over your neighbourhood shopping street. Phones die. A curse laughs somewhere in the arcade.",
		MinAge = 12, MaxAge = 120, Weight = 0.12,
		Options = {
			{ Text = "Hunt the curse", Chance = 0.45, ChanceStat = "QiControl",
				Result = "You find it among the claw machines and end it. The curtain lifts.", Effects = { Qi = 0.35, Counters = { Fights = 1 }, Karma = 1, Items = { curse_residue = 1 } },
				FailResult = "It throws you through a shop window before a sorcerer arrives.", FailEffects = { Health = -22, Money = -100 } },
			{ Text = "Lead people to shelter", Chance = 0.6, ChanceStat = "Charisma",
				Result = "Everyone stays calm and safe until help arrives.", Effects = { Stats = { Charisma = 8 }, Alignment = 4 },
				FailResult = "Panic spreads. You do what you can.", FailEffects = { Stress = 8 } },
		},
	},

	technique_name = {
		Title = "Naming Your Technique",
		Text = "Your innate technique has no name yet. A name is a binding of its own; it shapes what the technique becomes.",
		MinAge = 12, MaxAge = 25, Weight = 0.25,
		Requires = { Flag = "SpiritRoot" },
		Options = {
			{ Text = "Something simple and honest", Result = "It feels like yours. Control comes easier.", Effects = { Stats = { QiControl = 10 } } },
			{ Text = "Something terrifying", Result = "Curses hesitate when they hear it.", Effects = { Stats = { Strength = 6, Charisma = 4 } } },
			{ Text = "Something long and poetic", Result = "Your friends laugh. Your focus sharpens anyway.", Effects = { Stats = { Intelligence = 8 }, Happiness = 4 } },
		},
	},

	black_flash_spark = {
		Title = "A Spark of Black",
		Text = "In the middle of a sparring match, your fist and your cursed energy land within a millionth of a second of each other.",
		MinAge = 14, MaxAge = 200, Weight = 0.06,
		Requires = { Flag = "SpiritRoot", Stats = { Strength = 20 } },
		Options = {
			{ Text = "Chase the feeling", Chance = 0.35, ChanceStat = "QiControl",
				Result = "Black lightning. The world sharpens. You finally understand cursed energy.", Effects = { Qi = 0.5, Stats = { QiControl = 15, Strength = 8 } },
				FailResult = "It never comes again this year, but you remember its taste.", FailEffects = { Stats = { Strength = 6 } } },
			{ Text = "Write it down carefully", Result = "Your notes become the core of how you fight.", Effects = { Stats = { Intelligence = 8, QiControl = 6 } } },
		},
	},

	reverse_cursed_hint = {
		Title = "Positive from Negative",
		Text = "A medic sorcerer explains that multiplying negative energy by itself makes something that heals.",
		MinAge = 16, MaxAge = 200, Weight = 0.06,
		Requires = { Flag = "SpiritRoot", Stats = { Intelligence = 20 } },
		Options = {
			{ Text = "Practice until your head spins", Chance = 0.3, ChanceStat = "Intelligence",
				Result = "A cut on your hand closes by itself. You stare at it for an hour.", Effects = { MaxHealth = 10, Health = 20, Stats = { QiControl = 10 } },
				FailResult = "Just a headache. A big one.", FailEffects = { Stress = 8, Stats = { Intelligence = 4 } } },
			{ Text = "Ask her to teach your friends", Result = "Your whole circle gets a little sturdier.", Effects = { Stats = { Charisma = 6 }, Alignment = 2 } },
		},
	},

	cursed_corpse_pet = {
		Title = "A Stuffed Toy That Breathes",
		Text = "A friend of the family makes stuffed toys with a little cursed energy inside. One of them follows you home.",
		MinAge = 6, MaxAge = 40, Weight = 0.12,
		Options = {
			{ Text = "Keep it", Result = "It guards your room at night and punches mosquitoes.", Effects = { Happiness = 10, Stress = -5 } },
			{ Text = "Study how it works", Result = "Cursed energy as a battery. Fascinating.", Effects = { Stats = { Intelligence = 6, QiControl = 4 } } },
		},
	},

	sorcerer_scout = {
		Title = "A Scout from the Jujutsu School",
		Text = "A teacher from a jujutsu high school watches you exorcise a curse, then claps slowly.",
		MinAge = 14, MaxAge = 18, Weight = 0.18,
		Requires = { Flag = "SpiritRoot" },
		Options = {
			{ Text = "Show off a little", Chance = 0.5, ChanceStat = "QiControl",
				Result = "Impressed, she writes your name in a small black book.", Effects = { Stats = { QiControl = 8 }, Karma = 2 },
				FailResult = "You trip. She laughs, but still takes your number.", FailEffects = { Happiness = -3 } },
			{ Text = "Ask what the school is like", Result = "Dangerous, cramped, and full of people like you.", Effects = { Stats = { Intelligence = 5 }, Happiness = 5 } },
		},
	},

	cursed_womb_alert = {
		Title = "Cursed Womb Alert",
		Text = "A cursed womb is about to hatch at the hospital downtown. Every sorcerer in the area is called in, even you.",
		MinAge = 15, MaxAge = 200, Weight = 0.08,
		Requires = { MinRealm = 2 },
		Options = {
			{ Text = "Go in and fight", Chance = 0.4, ChanceStat = "Strength",
				Result = "You hold the line until the Grade 1s arrive. Your name reaches headquarters.", Effects = { Qi = 0.45, Counters = { Fights = 1 }, Karma = 3, Money = 600, Items = { womb_shell = 1 } },
				FailResult = "It nearly kills you. A senior drags you out by the collar.", FailEffects = { Health = -35, Stress = 12 } },
			{ Text = "Evacuate patients", Result = "Forty people walk out alive because of you.", Effects = { Alignment = 6, Karma = 2 } },
		},
	},

	night_parade_rumor = {
		Title = "Whispers of a Night Parade",
		Text = "A curse user is rumoured to be gathering a thousand curses for one night of terror in the city.",
		MinAge = 16, MaxAge = 200, Weight = 0.06,
		Requires = { MinRealm = 3 },
		Options = {
			{ Text = "Volunteer for the defence", Chance = 0.45, ChanceStat = "QiControl",
				Result = "You fight through the night. At dawn, the city still stands.", Effects = { Qi = 0.5, Counters = { Fights = 2 }, Karma = 4 },
				FailResult = "You survive, barely, and lose friends on the street that night.", FailEffects = { Health = -30, Happiness = -10 } },
			{ Text = "Guard your family instead", Result = "Nothing touches your home that night.", Effects = { Alignment = 3, Happiness = 4 } },
		},
	},

	curse_user_offer = {
		Title = "An Offer in the Dark",
		Text = "A smiling curse user with stitched skin offers you power: \"Sorcerers will never respect you. Curses will.\"",
		MinAge = 15, MaxAge = 200, Weight = 0.07,
		Requires = { Flag = "SpiritRoot" },
		Options = {
			{ Text = "Refuse and attack", Chance = 0.35, ChanceStat = "Strength",
				Result = "He retreats, laughing, with a wound he did not expect.", Effects = { Karma = 3, Alignment = 5, Counters = { Fights = 1 } },
				FailResult = "He swats you aside and disappears into the crowd.", FailEffects = { Health = -20, Alignment = 3 } },
			{ Text = "Take a little power", Result = "Cursed energy floods in. It tastes like rot.", Effects = { Qi = 0.4, Alignment = -12, Karma = -3 } },
			{ Text = "Walk away", Result = "He waves. \"See you around.\"", Effects = { Stress = 5 } },
		},
	},

	grade_assessment = {
		Title = "Grade Assessment Mission",
		Text = "Headquarters sends you on a solo mission to test whether you deserve a higher grade.",
		MinAge = 16, MaxAge = 200, Weight = 0.12, Repeatable = true, Cooldown = 8,
		Requires = { MinRealm = 2 },
		Options = {
			{ Text = "Finish it fast", Chance = 0.5, ChanceStat = "Agility",
				Result = "Clean, quick, and noted in your file.", Effects = { Qi = 0.25, Money = 400, Stats = { Agility = 6 } },
				FailResult = "You finish, but it takes all night and most of your blood.", FailEffects = { Health = -15, Money = 200 } },
			{ Text = "Finish it carefully", Result = "No injuries, glowing report.", Effects = { Money = 400, Stats = { Intelligence = 5 } } },
		},
	},

	upper_echelon_summons = {
		Title = "Summoned by the Higher-Ups",
		Text = "The jujutsu elders call you before their paper screens and accuse you of protecting a dangerous vessel.",
		MinAge = 17, MaxAge = 200, Weight = 0.05,
		Requires = { MinRealm = 3 },
		Options = {
			{ Text = "Argue your case", Chance = 0.45, ChanceStat = "Charisma",
				Result = "The screens fall silent. You walk out free and a little feared.", Effects = { Stats = { Charisma = 12 }, Karma = 2 },
				FailResult = "They cut your mission pay for a year.", FailEffects = { Money = -1500, Stress = 10 } },
			{ Text = "Bow and say nothing", Result = "They forget you exist. That has value.", Effects = { Stress = -4 } },
		},
	},

	kyoto_exchange = {
		Title = "Goodwill Exchange Event",
		Text = "The two jujutsu schools meet for their yearly 'friendly' tournament. {new} from the rival school has been staring at you all morning.",
		MinAge = 15, MaxAge = 18, Weight = 0.25,
		Requires = { Flag = "SpiritRoot" },
		Target = { Create = true },
		Options = {
			{ Text = "Challenge {new} in the forest round", Chance = 0.5, ChanceStat = "Strength",
				Result = "You win a brutal fight. {new} grins and shakes your hand.", Effects = { Counters = { Fights = 1 }, Stats = { Strength = 10 }, NewRelationship = { Type = "Friend", Affection = 40 } },
				FailResult = "{new} wins and will never let you forget it.", FailEffects = { Health = -10, NewRelationship = { Type = "Rival", Affection = 20 } } },
			{ Text = "Win the baseball round instead", Result = "Nobody expected you to hit a home run.", Effects = { Stats = { Agility = 8 }, Happiness = 8 } },
		},
	},

	vessel_rumor = {
		Title = "The Boy Who Ate a Finger",
		Text = "Word spreads of a teenager who swallowed a cursed finger and somehow kept his own mind.",
		MinAge = 14, MaxAge = 200, Weight = 0.06,
		Options = {
			{ Text = "Argue he deserves to live", Result = "Some sorcerers agree with you, quietly.", Effects = { Alignment = 5, Stats = { Charisma = 4 } } },
			{ Text = "Argue he must be executed", Result = "Logical. Cold. The elders approve.", Effects = { Alignment = -4, Stats = { Intelligence = 4 } } },
			{ Text = "Stay out of it", Result = "Smart. These things end badly.", Effects = {} },
		},
	},

	limitless_lecture = {
		Title = "A Lecture on Infinity",
		Text = "A visiting Special Grade drops by your class, eats all the sweets and explains the space between two numbers that never meet.",
		MinAge = 15, MaxAge = 30, Weight = 0.08,
		Requires = { Flag = "SpiritRoot" },
		Options = {
			{ Text = "Take careful notes", Result = "You understand a tenth of it. That tenth changes you.", Effects = { Stats = { Intelligence = 12, QiControl = 8 } } },
			{ Text = "Ask him to spar", Chance = 0.05, ChanceStat = "Strength",
				Result = "You land a hit. He laughs for a full minute and gives you his sweets.", Effects = { Stats = { Strength = 20 }, Karma = 3 },
				FailResult = "You never touch him. Not even close. Humbling.", FailEffects = { Stats = { Agility = 6 }, Stress = 4 } },
		},
	},

	domain_glimpse = {
		Title = "Inside Someone Else's Domain",
		Text = "You are dragged into a curse's domain: a sea of eyes under a black sun. Every attack inside is guaranteed to hit.",
		MinAge = 18, MaxAge = 300, Weight = 0.04,
		Requires = { MinRealm = 4 },
		Options = {
			{ Text = "Expand your own cursed energy against it", Chance = 0.35, ChanceStat = "QiControl",
				Result = "The domain cracks. You glimpse how a barrier holds a mind.", Effects = { Qi = 0.5, Proficiency = { QiArts = 20 }, Stats = { QiControl = 12 } },
				FailResult = "You survive only because an ally breaks it from outside.", FailEffects = { Health = -40, Stress = 15 } },
			{ Text = "Protect yourself and wait", Result = "You learn patience the hard way.", Effects = { Health = -15, Stats = { Vitality = 8 } } },
		},
	},

	salary_negotiation = {
		Title = "Sorcerer Pay Is Terrible",
		Text = "Risking your life weekly pays less than a convenience store. A broker offers private exorcism work for real money.",
		MinAge = 18, MaxAge = 200, Weight = 0.1,
		Requires = { Flag = "SpiritRoot" },
		Options = {
			{ Text = "Take private contracts", Result = "Rich clients, haunted mansions, fat envelopes.", Effects = { Money = 1500, Alignment = -2, Stress = 5 } },
			{ Text = "Stay loyal to the school", Result = "Low pay, clear conscience.", Effects = { Alignment = 3, Karma = 1 } },
		},
	},

	clan_marriage_offer = {
		Title = "A Clan Marriage Proposal",
		Text = "An old sorcerer clan sends a matchmaker with a heavy scroll. They want your bloodline in theirs.",
		MinAge = 18, MaxAge = 40, Weight = 0.06,
		Requires = { NotFlag = "Married", NoRelationship = "Partner" },
		Options = {
			{ Text = "Accept the arrangement", Result = "Cold dinners, deep pockets, powerful in-laws.", Effects = { Money = 3000, Happiness = -6, Flags = { "Married" }, NewRelationship = { Type = "Partner", Affection = 35 } } },
			{ Text = "Refuse politely", Result = "The clan is insulted. You sleep well anyway.", Effects = { Happiness = 4, Alignment = 2 } },
		},
	},

	retired_sorcerer = {
		Title = "The Retired Sorcerer",
		Text = "An old man missing two fingers runs the ramen stand near your home. He was a Grade 1, once.",
		MinAge = 12, MaxAge = 200, Weight = 0.1,
		Options = {
			{ Text = "Ask for his stories", Result = "Hours of advice with every bowl.", Effects = { Stats = { Intelligence = 6 }, Counters = { Knowledge = 3 }, Happiness = 4 } },
			{ Text = "Ask him to train you", Chance = 0.5, ChanceStat = "Charisma",
				Result = "He grumbles, then works you to the bone every Sunday.", Effects = { Proficiency = { Spear = 12 }, Stats = { Strength = 6 } },
				FailResult = "\"I'm retired, kid. Eat your noodles.\"", FailEffects = {} },
		},
	},

	elder_haunting = {
		Title = "A Curse Born of Regret",
		Text = "Late in life, an old regret of yours takes shape as a small, sad curse that follows you around the house.",
		MinAge = 55, MaxAge = 300, Weight = 0.12,
		Options = {
			{ Text = "Make peace with the regret", Result = "The curse fades with your sigh. You feel lighter.", Effects = { Stress = -15, Happiness = 8, Karma = 1 } },
			{ Text = "Exorcise it the old way", Result = "Gone in a single strike. Still got it.", Effects = { Stats = { Strength = 4 }, Counters = { Fights = 1 } } },
		},
	},

	successor_student = {
		Title = "A Student Worth Teaching",
		Text = "A young kid who can see curses keeps following you around, asking how you got so strong.",
		MinAge = 35, MaxAge = 300, Weight = 0.1,
		Requires = { Flag = "SpiritRoot" },
		Target = { Create = true },
		Options = {
			{ Text = "Take {new} as your student", Result = "Teaching sharpens your own understanding.", Effects = { Stats = { Intelligence = 8, Charisma = 6 }, NewRelationship = { Type = "Friend", Affection = 55 }, Karma = 2 } },
			{ Text = "Send them to the jujutsu school", Result = "The right place for a kid like that.", Effects = { Alignment = 2 } },
		},
	},
}

return YearlyEventsConfig
