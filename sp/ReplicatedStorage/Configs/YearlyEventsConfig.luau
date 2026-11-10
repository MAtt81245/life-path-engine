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
			{ Text = "Return it", Result = "The owner, an odd shopkeeper, rewards your honesty with a substitute combat pass.", Effects = { Karma = 2, Alignment = 8, Money = 100, Items = { lucky_charm = 1 } } },
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
			{ Text = "Lend Kan 500", Requires = { MinMoney = 500 }, Result = "{name} will never forget this.", Effects = { Money = -500, Affection = 20, Karma = 2, Alignment = 5,
				Delayed = { InYears = 3, Text = "{name} repays your Kan 500 loan, with interest and a long hug.", Effects = { Money = 800, Affection = 10 } } } },
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
			{ Text = "Pay the best clinic in town (Kan 2K)", Requires = { MinMoney = 2000 }, Result = "{name} recovers fully.", Effects = { Money = -2000, Affection = 15, Karma = 2 } },
			{ Text = "Care for them yourself", Result = "Long nights at the bedside bring you closer.", Effects = { Affection = 20, Stress = 15, Alignment = 5 } },
			{ Text = "Stay away", Result = "{name} feels abandoned.", Effects = { Affection = -25, Alignment = -8 } },
		},
	},

	library_manual = {
		Title = "The Hidden Technique Scroll",
		Text = "Behind a loose shelf in the library you find an old book of Kido incantations.",
		MinAge = 10, MaxAge = 200, Weight = 0.15,
		Requires = { Counters = { Knowledge = 10 } },
		Options = {
			{ Text = "Study it in secret", Result = "The incantations actually work.", Effects = { Qi = 1, Stats = { QiControl = 25 } } },
			{ Text = "Return it to the librarian", Result = "The old librarian nods knowingly.", Effects = { Karma = 3, Alignment = 5, Stats = { Intelligence = 10 } } },
		},
	},

	mugging = {
		Title = "Dark Alley",
		Text = "A masked thug blocks your path. A tiny Hollow chain dangles from his chest. \"Your money or your life.\"",
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
			{ Text = "Visit a hot spring (Kan 1K)", Requires = { MinMoney = 1000 }, Result = "The onsen does wonders.", Effects = { Money = -1000, Stress = -40, Happiness = 10 } },
			{ Text = "Visit a shrine", Result = "The priest teaches you to steady your reiatsu.", Effects = { Stress = -25, Stats = { QiControl = 8 } } },
			{ Text = "Push through", Result = "You keep going, but something breaks inside.", Effects = { Stress = 10, Health = -15 } },
		},
	},

	midlife = {
		Title = "Midlife Reflection",
		Text = "Halfway through a soul's long life, you wonder if this is all there is.",
		MinAge = 40, MaxAge = 50, Weight = 0.15,
		Options = {
			{ Text = "Buy a master-forged katana (Kan 5K)", Requires = { MinMoney = 5000 }, Result = "It hums in your hands. You feel young again.", Effects = { Money = -5000, Happiness = 15, Proficiency = { Sword = 30 } } },
			{ Text = "Take up calligraphy", Result = "Patient strokes calm your mind.", Effects = { Stats = { Intelligence = 12, QiControl = 8 }, Stress = -10 } },
			{ Text = "Quit your job and travel", Requires = { Employed = true }, Result = "Freedom tastes like road dust.", Effects = { QuitJob = true, Happiness = 15, Stress = -25 } },
		},
	},

	inheritance = {
		Title = "An Unexpected Will",
		Text = "A distant uncle you barely remember has left you his fortune.",
		MinAge = 25, MaxAge = 90, Weight = 0.04,
		Options = {
			{ Text = "Keep it all", Result = "Kan 10K richer, plus your uncle's sealed spirit ribbon.", Effects = { Money = 10000, Items = { jade_bracelet = 1 } } },
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
		Title = "The Off-Duty Soul Reaper",
		Text = "An off-duty Soul Reaper in a gigai saw the whole fight and walks over, impressed.",
		ChainOnly = true,
		Options = {
			{ Text = "Accept a reward", Result = "She presses an envelope of yen into your hand.", Effects = { Money = 300, Karma = 1 } },
			{ Text = "Ask to train with Soul Reapers", Result = "Months of drills with real Soul Reapers.", Effects = { Stats = { Strength = 15, Agility = 8 } } },
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
		Title = "A Primal Hollow",
		Text = "The founding era is not like the tame world you remember. A colossal primal Hollow blocks the mountain path.",
		MinAge = 13, MaxAge = 200, Weight = 0.18, Repeatable = true, Cooldown = 5, -- a lethal fight: teens and up
		Requires = { Era = "Ancient" },
		Options = {
			{ Text = "Fight it", Chance = 0.45, ChanceStat = "Strength",
				Result = "You cut it down and absorb the reishi it leaves behind.", Effects = { Qi = 0.3, Stats = { Strength = 15 }, Counters = { Fights = 1 } },
				FailResult = "It throws you down the cliff.", FailEffects = { Health = -35 } },
			{ Text = "Hide and observe", Chance = 0.6, ChanceStat = "Agility",
				Result = "You learn how it moves its reiatsu.", Effects = { Stats = { QiControl = 10 } },
				FailResult = "It smells you anyway.", FailEffects = { Health = -15 } },
			{ Text = "Turn back", Result = "You live to see another day.", Effects = { Stress = 4 } },
		},
	},

	rival_mentor = {
		Module = "Samsara",
		Title = "The Mentor Who Was Your Enemy",
		Text = "The most feared Soul Reaper in the region is taking students. You know that face: your arch-rival from a past life. They look straight at you and see a stranger.",
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
		Text = "Your mentor has taught you everything, including their Zanpakuto's release. Tonight, under the same moon as the duel from your past life, you could tell them who you really are.",
		Options = {
			{ Text = "Reveal your past life and duel them", Requires = { RemembersPastLife = true }, Chance = 0.45, ChanceStat = "Strength",
				Result = "Recognition, then fear. Your Bankai settles a feud older than this body.", Effects = { RivalReckoning = "Revenge", Counters = { Fights = 1 } },
				FailResult = "They win again and throw you down the mountain.", FailEffects = { RivalReckoning = "Defeat", Health = -40 } },
			{ Text = "Keep the secret and inherit their legacy", Result = "You bow. The hatred of two lifetimes becomes gratitude.", Effects = { RivalReckoning = "Legacy", Karma = 3 } },
		},
	},

	heirloom_reclaim = {
		Module = "Dynasty",
		Title = "Your Own Heirloom",
		Text = "In a back-alley shop you recognize it at once: the Zanpakuto you carried in a past life, now held by a descendant of your old family. Your name is still on the hilt.",
		MinAge = 14, MaxAge = 300, Weight = 0.4, Repeatable = true, Cooldown = 3,
		Requires = { LostHeirloomHere = true },
		Options = {
			{ Text = "Buy it back (Kan 1.5K)", Requires = { MinMoney = 1500 }, Result = "They sell, puzzled by your tears.", Effects = { Money = -1500, ReclaimHeirloom = "Buy" } },
			{ Text = "Challenge them to a duel for it", Result = "Reiatsu flares in the alley.", Effects = { StartDuel = "Heirloom" } },
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
		Text = "A storyteller at the summer festival tells the tale of a Soul Reaper from a hundred years ago. The story sounds... very familiar.",
		MinAge = 8, MaxAge = 60, Weight = 0.3,
		Requires = { Era = "Future" },
		Options = {
			{ Text = "Listen closely", Result = "You hear your own past told by strangers.", Effects = { LegendOfSelf = true } },
			{ Text = "Correct the storyteller", Requires = { RemembersPastLife = true },
				Result = "The crowd falls silent as you recount details no one could know.", Effects = { LegendOfSelf = true, Karma = 2, Stats = { Charisma = 8 } } },
		},
	},
	beggar_gate = {
		Module = "Character",
		Title = "A Lost Soul at the Gate",
		Text = "A ragged soul from the outer districts holds out a cracked bowl as you pass the gate.",
		MinAge = 10, MaxAge = 90, Weight = 0.12, Repeatable = true, Cooldown = 6,
		Options = {
			{ Text = "Give a few coins", Result = "He bows low and wishes you a peaceful Konso.", Effects = { Money = -20, Personality = { Generosity = 4, Kindness = 2 } } },
			{ Text = "Give him everything you carry", Requires = { Personality = { Generosity = 50 } },
				Result = "His eyes fill with tears. Word of it spreads through the gate.", Effects = { Money = -200, Alignment = 6, Karma = 2, Happiness = 6 } },
			{ Text = "Walk past", Result = "You do not look back.", Effects = { Personality = { Generosity = -3 } } },
			{ Text = "Kick his bowl away", Requires = { Personality = { Kindness = -50 } },
				Result = "Coins scatter in the dust. People stare at you.", Effects = { Alignment = -6, Personality = { Kindness = -3 } } },
		},
	},
	bully_dare = {
		Module = "Character",
		Title = "The Bully's Dare",
		Text = "The neighborhood bully dares you to jump the gap between two Karakura rooftops.",
		MinAge = 8, MaxAge = 16, Weight = 0.2, Repeatable = true, Cooldown = 3,
		Options = {
			{ Text = "Take the jump", Chance = 0.5, ChanceStat = "Agility",
				Result = "You land it. The other kids cheer.", Effects = { Happiness = 8, Personality = { Bravery = 5 } },
				FailResult = "You fall short and land in a stack of recycling bins.", FailEffects = { Health = -8, Happiness = -4 } },
			{ Text = "Stare him down until he leaves", Requires = { Personality = { Bravery = 50 } },
				Result = "He mutters something and backs off. Nobody dares you again.", Effects = { Happiness = 10, Stats = { Charisma = 6 }, Personality = { Bravery = 3 } } },
			{ Text = "Walk away", Result = "Laughter follows you home.", Effects = { Happiness = -3, Personality = { Bravery = -3, Caution = 3 } } },
		},
	},
	merchant_mistake = {
		Module = "Character",
		Title = "The Shopkeeper's Mistake",
		Text = "A distracted candy-shop clerk hands you far too much change.",
		MinAge = 14, MaxAge = 80, Weight = 0.12, Repeatable = true, Cooldown = 6,
		Options = {
			{ Text = "Point out the mistake", Result = "He laughs, thanks you and remembers your face.", Effects = { Alignment = 3, Personality = { Honesty = 4 } } },
			{ Text = "Pocket it", Result = "Easy coin.", Effects = { Money = 80, Personality = { Honesty = -4 } } },
			{ Text = "Talk him into a bigger 'mistake'", Requires = { Personality = { Honesty = -50 } }, Chance = 0.6, ChanceStat = "Charisma",
				Result = "By the end he thinks he owes you. You walk away rich.", Effects = { Money = 400, Alignment = -4 },
				FailResult = "He sees through you and calls the neighborhood watch.", FailEffects = { Money = -50, Alignment = -4, Stress = 6 } },
		},
	},

	-- ===== Content expansion (2026-11-02): 38 more everyday events =====

	ghost_at_window = {
		Title = "The Face at the Window",
		Text = "Every night a pale little girl presses her face to your bedroom window. Nobody else can see her.",
		MinAge = 2, MaxAge = 5, Weight = 0.5,
		Options = {
			{ Text = "Wave at her", Result = "She smiles and waves back. You sleep better after that.", Effects = { Stats = { QiControl = 6 }, Happiness = 4 } },
			{ Text = "Hide under the blanket", Result = "She goes away. For now.", Effects = { Personality = { Caution = 4 }, Stress = 3 } },
			{ Text = "Tell your parents", Result = "They smile nervously and buy you a nightlight.", Effects = { Happiness = 2 } },
		},
	},

	broken_vase = {
		Title = "The Broken Vase",
		Text = "Playing ball indoors, you shatter the vase your mother keeps by the family altar.",
		MinAge = 4, MaxAge = 8, Weight = 0.4,
		Options = {
			{ Text = "Confess at once", Result = "She is upset, but proud of your honesty.", Effects = { Personality = { Honesty = 5 }, Alignment = 3, Happiness = -3 } },
			{ Text = "Blame the cat", Chance = 0.5, ChanceStat = "Charisma",
				Result = "The cat is exiled to the porch. You feel a little bad.", Effects = { Personality = { Honesty = -4 }, Stats = { Charisma = 4 } },
				FailResult = "The cat was asleep upstairs the whole time.", FailEffects = { Happiness = -8, Personality = { Honesty = -3 } } },
			{ Text = "Glue it back together", Chance = 0.4, ChanceStat = "Agility",
				Result = "Nobody notices for a whole year.", Effects = { Stats = { Agility = 6, Intelligence = 3 } },
				FailResult = "It falls apart the moment she dusts it.", FailEffects = { Happiness = -6, Stress = 4 } },
		},
	},

	riverbank_kite = {
		Title = "Kites on the Riverbank",
		Text = "Every kid in the neighbourhood brings a kite to the riverbank on the windiest day of spring.",
		MinAge = 5, MaxAge = 10, Weight = 0.35,
		Options = {
			{ Text = "Build the biggest kite", Chance = 0.45, ChanceStat = "Intelligence",
				Result = "It soars over the bridge. Everyone wants to fly it.", Effects = { Stats = { Intelligence = 8 }, Happiness = 10 },
				FailResult = "Too heavy. It never leaves the grass.", FailEffects = { Happiness = -4 } },
			{ Text = "Run faster than everyone", Chance = 0.5, ChanceStat = "Agility",
				Result = "Your little kite climbs like a swallow.", Effects = { Stats = { Agility = 8 }, Happiness = 8 },
				FailResult = "You trip and the string snaps.", FailEffects = { Health = -4, Happiness = -3 } },
			{ Text = "Help a younger kid fly theirs", Result = "Their grin is worth more than winning.", Effects = { Alignment = 4, Personality = { Kindness = 3 }, Happiness = 5 } },
		},
	},

	senior_tutor = {
		Title = "A Senior Who Sees Ghosts Too",
		Text = "An older student who also sees spirits offers to tutor you, in exchange for walking her home past the haunted shrine.",
		MinAge = 7, MaxAge = 14, Weight = 0.3,
		Options = {
			{ Text = "Study with her", Result = "She knows a surprising amount about the classics, and about ghosts.", Effects = { Stats = { Intelligence = 14 }, Counters = { Knowledge = 2 } } },
			{ Text = "Ask her about spirits", Chance = 0.4, ChanceStat = "Charisma",
				Result = "She lowers her voice and teaches you how to calm a restless soul.", Effects = { Stats = { QiControl = 10, Intelligence = 4 } },
				FailResult = "\"Spirits? I tutor maths.\" She winks.", FailEffects = { Stats = { Intelligence = 6 } } },
			{ Text = "Say no", Result = "She shrugs and walks home alone.", Effects = {} },
		},
	},

	plus_spirit_dog = {
		Title = "The Ghost Dog",
		Text = "A translucent dog with a broken chain on its chest follows you home from the park.",
		MinAge = 5, MaxAge = 12, Weight = 0.4,
		Options = {
			{ Text = "Play fetch with it", Result = "It wags so hard its chain rattles. You feel strangely lighter.", Effects = { Stats = { QiControl = 6, Agility = 4 }, Happiness = 8 } },
			{ Text = "Find out how it died", Chance = 0.5, ChanceStat = "Intelligence",
				Result = "You lay flowers at the crossing. The dog fades away, smiling somehow.", Effects = { Karma = 2, Alignment = 5, Stats = { Intelligence = 4 } },
				FailResult = "You never find out. It stops coming one day.", FailEffects = { Stress = 3 } },
			{ Text = "Shoo it away", Result = "It whimpers and leaves. Something dark watches it go.", Effects = { Alignment = -3 } },
		},
	},

	first_reiatsu = {
		Title = "A Weight in the Air",
		Text = "Walking home, the air suddenly turns heavy. Somewhere close, something huge is breathing.",
		MinAge = 6, MaxAge = 12, Weight = 0.3,
		Options = {
			{ Text = "Breathe through it", Result = "The pressure answers your breath. You feel your own spiritual power for the first time.", Effects = { Qi = 0.1, Stats = { QiControl = 10 } } },
			{ Text = "Run home", Chance = 0.6, ChanceStat = "Agility",
				Result = "You make it. Whatever it was loses interest.", Effects = { Stats = { Agility = 6 } },
				FailResult = "You trip and scrape both knees. The pressure fades anyway.", FailEffects = { Health = -6, Stress = 4 } },
			{ Text = "Look for its source", Result = "Nothing there but a crack in the sky that seals as you watch.", Effects = { Personality = { Curiosity = 4 }, Stats = { QiControl = 4 } } },
		},
	},

	candy_shop_job = {
		Title = "The Odd Candy Shop",
		Text = "The owner of a dusty candy shop offers you pocket money to sweep the floor. The shop has a very deep basement.",
		MinAge = 8, MaxAge = 14, Weight = 0.3,
		Options = {
			{ Text = "Sweep the floor", Result = "Easy money, and the owner tells odd stories.", Effects = { Money = 40, Stats = { Charisma = 4 } } },
			{ Text = "Peek into the basement", Chance = 0.4, ChanceStat = "Agility",
				Result = "A cavern the size of a stadium. You back out quietly, heart pounding.", Effects = { Stats = { QiControl = 8 }, Personality = { Curiosity = 4 } },
				FailResult = "A large man in an apron gently carries you back upstairs.", FailEffects = { Stress = 4 } },
			{ Text = "Buy candy instead", Result = "One of the candies tastes like electricity.", Effects = { Money = -5, Happiness = 6 } },
		},
	},

	market_thief_kid = {
		Title = "Quick Fingers",
		Text = "A scruffy kid named {new} offers to teach you how to swipe snacks from the convenience store.",
		MinAge = 8, MaxAge = 13, Weight = 0.3,
		Target = { Create = true },
		Options = {
			{ Text = "Learn the trick", Chance = 0.55, ChanceStat = "Agility",
				Result = "Free snacks and a new partner in crime.", Effects = { Stats = { Agility = 8 }, Personality = { Honesty = -4 }, NewRelationship = { Type = "Friend", Affection = 45 } },
				FailResult = "The clerk grabs your collar. Your parents are called.", FailEffects = { Money = -40, Happiness = -8, Alignment = -3 } },
			{ Text = "Buy {new} a snack instead", Result = "{new} eats it in three bites and decides you are alright.", Effects = { Money = -5, NewRelationship = { Type = "Friend", Affection = 55 }, Alignment = 4 } },
			{ Text = "Tell the clerk", Result = "{new} is dragged out, glaring at you.", Effects = { NewRelationship = { Type = "Rival", Affection = 15 }, Alignment = -2 } },
		},
	},

	river_swim = {
		Title = "The Cold River",
		Text = "The older kids dare you to swim across the river while it is still swollen with spring rain.",
		MinAge = 9, MaxAge = 15, Weight = 0.3,
		Options = {
			{ Text = "Swim it", Chance = 0.45, ChanceStat = "Vitality",
				Result = "You crawl out on the far bank, shaking and triumphant.", Effects = { Stats = { Vitality = 10, Strength = 4 }, Happiness = 8 },
				FailResult = "The current drags you downstream. A jogger pulls you out.", FailEffects = { Health = -18, Stress = 8 } },
			{ Text = "Take the bridge", Result = "They call you a coward. You stay dry.", Effects = { Happiness = -3, Personality = { Caution = 4 } } },
			{ Text = "Dare them back", Chance = 0.5, ChanceStat = "Charisma",
				Result = "Nobody swims. Everybody laughs. You win.", Effects = { Stats = { Charisma = 8 } },
				FailResult = "They throw you in anyway.", FailEffects = { Health = -8, Happiness = -4 } },
		},
	},

	shinigami_glimpse = {
		Title = "A Figure in Black Robes",
		Text = "On a rooftop across the street, a figure in a black kimono with a sword watches the night. They notice you noticing.",
		MinAge = 10, MaxAge = 16, Weight = 0.4,
		Options = {
			{ Text = "Wave", Chance = 0.45, ChanceStat = "QiControl",
				Result = "They nod once, write something in a notebook and vanish. Your power stirs.", Effects = { Qi = 0.15, Stats = { QiControl = 8 }, Happiness = 8, FollowUp = { Id = "reaper_return", InYears = 1 } },
				FailResult = "They frown and flash-step away. You must have imagined it.", FailEffects = { Stress = 4, Personality = { Curiosity = 3 } } },
			{ Text = "Pretend you saw nothing", Result = "Smart. Some things are better left unseen.", Effects = { Personality = { Caution = 4 } } },
			{ Text = "Follow them", Chance = 0.3, ChanceStat = "Agility",
				Result = "You watch them cut down a masked monster in one stroke.", Effects = { Stats = { Agility = 8 }, Proficiency = { Sword = 6 } },
				FailResult = "You lose them in three streets and get scolded for being out late.", FailEffects = { Happiness = -4 } },
		},
	},

	reaper_return = {
		ChainOnly = true,
		Title = "The Reaper Returns",
		Text = "The black-robed figure lands on your windowsill. \"You can see us. That makes you a target. Let me teach you to run, at least.\"",
		Options = {
			{ Text = "Accept the lessons", Chance = 0.5, ChanceStat = "Vitality",
				Result = "A month of brutal night training. You can sense Hollows coming now.", Effects = { Stats = { Vitality = 10, QiControl = 8 }, Proficiency = { Sword = 6 }, Happiness = 6 },
				FailResult = "You collapse on the second night. They leave a charm and a sigh.", FailEffects = { Items = { lucky_charm = 1 }, Health = -10 } },
			{ Text = "Ask them to erase your memory", Result = "A puff of smoke. You wake up remembering a weird dream.", Effects = { Stress = -6 } },
		},
	},

	calligraphy_contest = {
		Title = "The Calligraphy Contest",
		Text = "Your school holds a calligraphy contest. The winning scroll hangs in the town hall for a year.",
		MinAge = 10, MaxAge = 18, Weight = 0.25,
		Options = {
			{ Text = "Enter with bold strokes", Chance = 0.4, ChanceStat = "Intelligence",
				Result = "Your scroll hangs in the town hall.", Effects = { Stats = { Intelligence = 12 }, Money = 50, Happiness = 10 },
				FailResult = "An ink blot ruins your best character.", FailEffects = { Stress = 6, Happiness = -4 } },
			{ Text = "Write a Kido-style incantation", Chance = 0.5, ChanceStat = "QiControl",
				Result = "The judges are baffled. The paper is faintly warm.", Effects = { Stats = { QiControl = 8 } },
				FailResult = "It is just gibberish. Even to you.", FailEffects = { Happiness = -3 } },
			{ Text = "Skip it", Result = "You spend the day at the arcade.", Effects = { Stress = -5 } },
		},
	},

	summer_festival = {
		Title = "Summer Fireworks Festival",
		Text = "Lanterns, food stalls and fireworks over the river. Your friends want to go together.",
		MinAge = 10, MaxAge = 40, Weight = 0.2, Repeatable = true, Cooldown = 8,
		Options = {
			{ Text = "Win every stall game", Chance = 0.5, ChanceStat = "Agility",
				Result = "Your arms are full of prizes. Kids follow you around.", Effects = { Stats = { Agility = 8 }, Happiness = 12 },
				FailResult = "The goldfish nets keep tearing.", FailEffects = { Money = -30, Happiness = 3 } },
			{ Text = "Watch the fireworks quietly", Result = "Somewhere in the crowd you feel a dozen spirits watching too.", Effects = { Stress = -8, Stats = { QiControl = 4 } } },
			{ Text = "Sell yakisoba at a stall", Result = "Smoky, sweaty, profitable.", Effects = { Money = 120, Stats = { Charisma = 4 } } },
		},
	},

	first_crush = {
		Title = "A Flutter in Your Chest",
		Text = "Every time {new} walks past, you forget what you were saying.",
		MinAge = 13, MaxAge = 17, Weight = 0.35,
		Target = { Create = true },
		Options = {
			{ Text = "Write them a letter", Chance = 0.45, ChanceStat = "Charisma",
				Result = "{new} writes back. You read it a hundred times.", Effects = { NewRelationship = { Type = "Friend", Affection = 65 }, Happiness = 14 },
				FailResult = "{new} reads it aloud to the whole class.", FailEffects = { Happiness = -12, Stress = 8 } },
			{ Text = "Admire from afar", Result = "You fill a notebook with bad poems.", Effects = { Stats = { Intelligence = 4 }, Stress = 3 } },
			{ Text = "Train harder to impress", Result = "{new} never notices. Your arms do.", Effects = { Stats = { Strength = 8, Vitality = 4 } } },
		},
	},

	hollow_attack_school = {
		Title = "Something in the School Yard",
		Text = "During lunch, windows shatter one by one. Only you can see the masked beast stalking between the students.",
		MinAge = 12, MaxAge = 18, Weight = 0.3,
		Options = {
			{ Text = "Lure it away", Chance = 0.45, ChanceStat = "Agility",
				Result = "You lead it on a chase until a Soul Reaper drops out of the sky and finishes it.", Effects = { Stats = { Agility = 12 }, Alignment = 8, Counters = { Fights = 1 } },
				FailResult = "Its claw catches your shoulder before help arrives.", FailEffects = { Health = -22, Alignment = 4 } },
			{ Text = "Fight it with a bat", Chance = 0.25, ChanceStat = "Strength",
				Result = "You crack its mask. It flees, howling.", Effects = { Stats = { Strength = 12 }, Counters = { Fights = 1 }, Qi = 0.1 },
				FailResult = "The bat passes straight through it.", FailEffects = { Health = -28 } },
			{ Text = "Get everyone out", Result = "You pull the fire alarm. Nobody is hurt.", Effects = { Alignment = 5, Stats = { Charisma = 6 } } },
		},
	},

	kendo_tournament = {
		Title = "The Kendo Tournament",
		Text = "The prefectural kendo tournament is open to students. The prize is a real, unsharpened katana.",
		MinAge = 13, MaxAge = 19, Weight = 0.35,
		Options = {
			{ Text = "Attack relentlessly", Chance = 0.4, ChanceStat = "Strength",
				Result = "Champion! The katana is yours.", Effects = { Counters = { Fights = 3 }, Stats = { Strength = 12 }, Proficiency = { Sword = 14 }, Happiness = 12 },
				FailResult = "Knocked out in the quarter-finals.", FailEffects = { Counters = { Fights = 2 }, Health = -10, Proficiency = { Sword = 5 } } },
			{ Text = "Wait for openings", Chance = 0.45, ChanceStat = "Agility",
				Result = "Nobody lands a clean strike on you all day.", Effects = { Counters = { Fights = 3 }, Stats = { Agility = 12 }, Proficiency = { Sword = 10 } },
				FailResult = "One feint and it is over.", FailEffects = { Counters = { Fights = 1 }, Proficiency = { Sword = 3 } } },
			{ Text = "Scout the fighters", Result = "You learn every style in the prefecture by watching.", Effects = { Stats = { Intelligence = 8 }, Proficiency = { Sword = 4 } } },
		},
	},

	runaway_temptation = {
		Title = "The Last Train Out",
		Text = "After another fight at home, you stand on the platform with a backpack, watching the last train pull in.",
		MinAge = 13, MaxAge = 17, Weight = 0.2,
		Options = {
			{ Text = "Get on", Chance = 0.5, ChanceStat = "Vitality",
				Result = "A week in another city teaches you more than a year at home.", Effects = { Stats = { Vitality = 8, Intelligence = 6 }, Personality = { Bravery = 4 }, Stress = -6 },
				FailResult = "Your wallet is stolen on day two. You call home, embarrassed.", FailEffects = { Money = -50, Happiness = -8 } },
			{ Text = "Go home and apologise", Result = "Your parents hug you a little longer than usual.", Effects = { Happiness = 6, Alignment = 3 } },
			{ Text = "Sit on the platform until dawn", Result = "A ghost conductor keeps you company. He has good advice.", Effects = { Stress = -8, Stats = { QiControl = 4 } } },
		},
	},

	club_choice = {
		Title = "Club Recruitment Day",
		Text = "Three clubs want you: the karate club, the handicrafts club and the occult research club.",
		MinAge = 14, MaxAge = 17, Weight = 0.4,
		Options = {
			{ Text = "Karate club", Result = "Bruises, sweat and real friends.", Effects = { Stats = { Strength = 12, Vitality = 6 }, Counters = { Fights = 1 } } },
			{ Text = "Handicrafts club", Result = "You sew a stuffed lion that everyone says looks alive.", Effects = { Stats = { Agility = 8, Intelligence = 6 } } },
			{ Text = "Occult research club", Result = "Most of it is nonsense. Some of it is not.", Effects = { Stats = { QiControl = 8, Intelligence = 6 }, Counters = { Knowledge = 1 } } },
		},
	},

	lost_soul_guide = {
		Title = "A Lost Soul at the Crossing",
		Text = "An old man's ghost stands at a busy crossing every day, looking for his wife. His chain is short and rusting.",
		MinAge = 12, MaxAge = 80, Weight = 0.18, Repeatable = true, Cooldown = 8,
		Options = {
			{ Text = "Help him find her grave", Chance = 0.55, ChanceStat = "Intelligence",
				Result = "He smiles at the headstone and fades into light.", Effects = { Karma = 3, Alignment = 6, Happiness = 6 },
				FailResult = "You search for weeks. His chain grows shorter.", FailEffects = { Stress = 6, Alignment = 2 } },
			{ Text = "Warn him about Hollows", Result = "He thanks you and promises to keep moving.", Effects = { Alignment = 3 } },
			{ Text = "Ignore him", Result = "One day the crossing is empty, and the air smells wrong.", Effects = { Stress = 4 } },
		},
	},

	flood_season = {
		Title = "The River Rises",
		Text = "A typhoon stalls over town. The river breaks its banks and water pours into the low streets.",
		MinAge = 12, MaxAge = 80, Weight = 0.12, Repeatable = true, Cooldown = 10,
		Options = {
			{ Text = "Carry people to safety", Chance = 0.55, ChanceStat = "Strength",
				Result = "You save a family of five. The neighbourhood remembers.", Effects = { Stats = { Strength = 8, Vitality = 6 }, Alignment = 8, Karma = 2 },
				FailResult = "The current knocks you down. You barely make it out.", FailEffects = { Health = -20, Alignment = 4 } },
			{ Text = "Stack sandbags", Result = "Back-breaking work, but your street stays dry.", Effects = { Stats = { Vitality = 8 }, Stress = 6 } },
			{ Text = "Sell bottled water at triple price", Result = "Profit on other people's misery.", Effects = { Money = 400, Alignment = -8, Karma = -2 } },
		},
	},

	pachinko_parlor = {
		Title = "The Pachinko Parlor",
		Text = "Bright lights and a deafening rattle. A man in a hat waves you toward a lucky machine.",
		MinAge = 18, MaxAge = 90, Weight = 0.15, Repeatable = true, Cooldown = 6,
		Requires = { MinMoney = 100 },
		Options = {
			{ Text = "Play", Chance = 0.35, ChanceStat = "Luck",
				Result = "Jackpot! Silver balls everywhere.", Effects = { Money = 400, Happiness = 8 },
				FailResult = "The machine eats everything.", FailEffects = { Money = -150, Stress = 8 } },
			{ Text = "Notice the rigged machine", Chance = 0.4, ChanceStat = "Intelligence",
				Result = "You report it. The other players buy you dinner.", Effects = { Money = 150, Alignment = 3 },
				FailResult = "Security escorts you out for 'loitering'.", FailEffects = { Happiness = -5 } },
			{ Text = "Walk past", Result = "Your wallet thanks you.", Effects = { Personality = { Caution = 2 } } },
		},
	},

	street_thugs = {
		Title = "Thugs Under the Overpass",
		Text = "Three thugs block the path under the overpass and demand your wallet.",
		MinAge = 15, MaxAge = 70, Weight = 0.15, Repeatable = true, Cooldown = 6,
		Options = {
			{ Text = "Fight", Chance = 0.4, ChanceStat = "Strength",
				Result = "They limp away. One drops his wallet.", Effects = { Counters = { Fights = 1 }, Stats = { Strength = 10 }, Money = 80 },
				FailResult = "They beat you and take everything.", FailEffects = { Health = -22, Money = -80 } },
			{ Text = "Hand it over", Result = "Expensive, but you keep your teeth.", Effects = { Money = -60 } },
			{ Text = "Talk them down", Chance = 0.35, ChanceStat = "Charisma",
				Result = "By the end you are giving one of them career advice.", Effects = { Alignment = 4, Stats = { Charisma = 10 } },
				FailResult = "They laugh and take double.", FailEffects = { Money = -120 } },
		},
	},

	sick_neighbor = {
		Title = "Fever Next Door",
		Text = "The old woman next door has been coughing for a week. Nobody has checked on her.",
		MinAge = 14, MaxAge = 90, Weight = 0.15, Repeatable = true, Cooldown = 10,
		Options = {
			{ Text = "Bring medicine", Requires = { Items = { healing_salve = 1 } },
				Result = "She recovers and calls you her guardian angel.", Effects = { Items = { healing_salve = -1 }, Alignment = 6, Karma = 2, Happiness = 6 } },
			{ Text = "Cook her soup", Result = "She gets better slowly. You visit every day.", Effects = { Alignment = 4, Personality = { Kindness = 3 }, Money = -10 } },
			{ Text = "Mind your own business", Result = "The coughing stops one night. You try not to think about it.", Effects = { Stress = 4 } },
		},
	},

	moving_house = {
		Title = "A New Apartment",
		Text = "Your landlord doubles the rent. A cheaper flat has opened up near the station.",
		MinAge = 18, MaxAge = 70, Weight = 0.12,
		Options = {
			{ Text = "Move near the station", Result = "Smaller rooms, noisy trains, fresh start.", Effects = { Money = 100, Happiness = 4, Stress = 4 } },
			{ Text = "Haggle with the landlord", Chance = 0.45, ChanceStat = "Charisma",
				Result = "He settles for a modest rise.", Effects = { Stats = { Charisma = 8 } },
				FailResult = "He raises it again for your cheek.", FailEffects = { Money = -150, Stress = 6 } },
			{ Text = "Pay the new rent", Result = "Your wallet groans.", Effects = { Money = -200 } },
		},
	},

	business_partner = {
		Title = "A Business Proposal",
		Text = "{new}, a fast-talking shop owner, wants you as a partner in a spirit-goods mail-order business.",
		MinAge = 20, MaxAge = 70, Weight = 0.15,
		Requires = { MinMoney = 500 },
		Target = { Create = true },
		Options = {
			{ Text = "Invest your savings", Chance = 0.5, ChanceStat = "Luck",
				Result = "Orders pour in from places with no postcode.", Effects = { Money = 1200, NewRelationship = { Type = "Friend", Affection = 55 } },
				FailResult = "The business vanishes overnight. So does {new}.", FailEffects = { Money = -500, Stress = 12 } },
			{ Text = "Study the plan first", Chance = 0.55, ChanceStat = "Intelligence",
				Result = "You fix two fatal mistakes. Modest, safe profit.", Effects = { Money = 400, Stats = { Intelligence = 6 }, NewRelationship = { Type = "Friend", Affection = 50 } },
				FailResult = "You find nothing wrong. Neither does the tax office, until later.", FailEffects = { Money = -200 } },
			{ Text = "Decline", Result = "{new} shrugs and finds another partner.", Effects = {} },
		},
	},

	wedding_invite = {
		Title = "A Wedding Invitation",
		Text = "Your friend {name} is getting married and wants you to give a speech.",
		MinAge = 18, MaxAge = 60, Weight = 0.2,
		Target = { Type = { "Friend" } },
		Options = {
			{ Text = "Give a heartfelt speech", Chance = 0.55, ChanceStat = "Charisma",
				Result = "Half the guests cry. {name} hugs you for a long time.", Effects = { Affection = 15, Stats = { Charisma = 8 }, Happiness = 8 },
				FailResult = "You forget the groom's name halfway through.", FailEffects = { Affection = -5, Stress = 8 } },
			{ Text = "Bring a generous gift", Result = "{name} will remember this.", Effects = { Money = -150, Affection = 12 } },
			{ Text = "Make an excuse", Result = "{name} notices your empty seat.", Effects = { Affection = -10 } },
		},
	},

	district_dispute = {
		Title = "The Well in the District",
		Text = "Two families in the Rukongai district are about to brawl over the only clean well. Everyone looks at you.",
		MinAge = 25, MaxAge = 300, Weight = 0.15,
		Options = {
			{ Text = "Judge fairly", Chance = 0.5, ChanceStat = "Intelligence",
				Result = "Both families grumble, which means it was fair.", Effects = { Stats = { Intelligence = 6, Charisma = 6 }, Alignment = 5 },
				FailResult = "Both families now hate you.", FailEffects = { Stress = 8, Happiness = -5 } },
			{ Text = "Side with the stronger family", Result = "They bring you rice. The other family spits as you pass.", Effects = { Money = 150, Alignment = -5 } },
			{ Text = "Dig a second well", Requires = { MinMoney = 300 },
				Result = "Problem solved forever. The children name the well after you.", Effects = { Money = -300, Alignment = 8, Karma = 3, Happiness = 8 } },
		},
	},

	parent_advice = {
		Title = "A Parent's Advice",
		Text = "{name} sits you down. \"There's something about our family I've never told you.\"",
		MinAge = 20, MaxAge = 55, Weight = 0.2,
		Target = { Type = { "Mother", "Father" } },
		Options = {
			{ Text = "Listen to every word", Result = "Plain wisdom, plainly given. You carry it for life.", Effects = { Affection = 12, Stats = { Intelligence = 8 }, Stress = -6 } },
			{ Text = "Ask about the family's past", Result = "{name} admits a great-grandparent once carried a sword nobody else could see.", Effects = { Affection = 8, Stats = { QiControl = 6 }, Personality = { Curiosity = 3 } } },
			{ Text = "Say you are too busy", Result = "{name} nods quietly and never brings it up again.", Effects = { Affection = -12 } },
		},
	},

	jinzen_retreat = {
		Title = "A Season of Jinzen",
		Text = "Life grows loud. A quiet mountain temple offers a season of silent meditation with your blade across your knees.",
		MinAge = 18, MaxAge = 300, Weight = 0.12, Repeatable = true, Cooldown = 12,
		Options = {
			{ Text = "Sit with your blade", Result = "On the last night, a voice inside the steel speaks your name.", Effects = { Qi = 0.25, Stats = { QiControl = 10 }, Stress = -15, Money = -50 } },
			{ Text = "Work as the temple cook", Result = "You feed the monks and they feed your mind.", Effects = { Stats = { Intelligence = 6, Vitality = 4 }, Stress = -8 } },
			{ Text = "Stay in town", Result = "The noise continues.", Effects = { Stress = 3 } },
		},
	},

	lab_accident = {
		Title = "The Twelfth Division Prototype",
		Text = "A researcher in a lab coat asks you to hold a humming device 'for just a moment'. It starts smoking.",
		MinAge = 16, MaxAge = 300, Weight = 0.12, Repeatable = true, Cooldown = 8,
		Options = {
			{ Text = "Pull the plug", Chance = 0.45, ChanceStat = "Intelligence",
				Result = "It settles. The grateful researcher gives you a sample.", Effects = { Items = { focus_tonic = 1 }, Stats = { Intelligence = 6 } },
				FailResult = "It shocks you both across the room.", FailEffects = { Health = -15 } },
			{ Text = "Stabilise it with your reiryoku", Requires = { MinRealm = 2 },
				Result = "Your spiritual power steadies the core. Perfect readings.", Effects = { Items = { elixir_of_prodigy = 1 }, Stats = { QiControl = 10 } } },
			{ Text = "Drop it and run", Result = "Smart. The researcher loses an eyebrow.", Effects = { Personality = { Caution = 3 } } },
		},
	},

	garganta_sky = {
		Title = "The Sky Cracks Open",
		Text = "A black tear rips across the evening sky. For a moment you see an endless white desert on the other side.",
		MinAge = 14, MaxAge = 300, Weight = 0.1, Repeatable = true, Cooldown = 15,
		Options = {
			{ Text = "Race to where it opened", Chance = 0.35, ChanceStat = "Luck",
				Result = "Something dropped through: a crystal humming with reishi.", Effects = { Items = { magic_crystal = 1 }, Qi = 0.2, Happiness = 10 },
				FailResult = "Soul Reapers already sealed the area. You get a stern look.", FailEffects = { Stress = 5 } },
			{ Text = "Meditate on the residue", Result = "Hollow reiatsu washes over you. You learn its shape.", Effects = { Qi = 0.1, Stats = { QiControl = 6 } } },
			{ Text = "Close the curtains", Result = "Probably just weather.", Effects = { Stress = -2 } },
		},
	},

	division_rivalry = {
		Title = "Two Divisions, One Corridor",
		Text = "Officers of two rival divisions block the corridor, hands on their hilts. Neither will step aside.",
		MinAge = 16, MaxAge = 300, Weight = 0.12, Repeatable = true, Cooldown = 10,
		Requires = { MinRealm = 2 },
		Options = {
			{ Text = "Step between them", Chance = 0.45, ChanceStat = "Charisma",
				Result = "Both sides lower their blades. Both captains hear your name.", Effects = { Stats = { Charisma = 10 }, Alignment = 5 },
				FailResult = "Both sides draw on you instead.", FailEffects = { Health = -20, Counters = { Fights = 1 } } },
			{ Text = "Back the stronger side", Chance = 0.55, ChanceStat = "Strength",
				Result = "Victory. That division owes you a favour.", Effects = { Counters = { Fights = 1 }, Stats = { Strength = 8 }, Money = 150 },
				FailResult = "You picked wrong.", FailEffects = { Health = -18 } },
			{ Text = "Take the long way round", Result = "Three extra corridors, zero extra wounds.", Effects = {} },
		},
	},

	bankai_witness = {
		Title = "Someone Else's Bankai",
		Text = "Far across Seireitei, a pillar of spiritual pressure splits the clouds. Someone has just released their Bankai.",
		MinAge = 18, MaxAge = 300, Weight = 0.08, Repeatable = true, Cooldown = 20,
		Requires = { MinRealm = 3 },
		Options = {
			{ Text = "Feel its shape", Result = "Every wave shows you a flaw in your own spiritual foundation.", Effects = { Stats = { QiControl = 12 }, Qi = 0.15 } },
			{ Text = "Rush toward it", Chance = 0.3, ChanceStat = "Vitality",
				Result = "You arrive in time to shield an injured officer from the fallout.", Effects = { Health = -30, Karma = 5, Alignment = 8, Stats = { Vitality = 12 } },
				FailResult = "The pressure alone knocks you flat.", FailEffects = { Health = -40 } },
			{ Text = "Hide in the barracks", Result = "Wise. Several walls do not survive the afternoon.", Effects = { Personality = { Caution = 3 } } },
		},
	},

	academy_student_request = {
		Title = "A Student at Your Door",
		Text = "An Academy student named {new} bows at your gate in the rain, begging you to teach them Zanjutsu.",
		MinAge = 35, MaxAge = 300, Weight = 0.12,
		Requires = { MinRealm = 3 },
		Target = { Create = true },
		Options = {
			{ Text = "Accept them", Result = "Teaching {new} sharpens your own understanding.", Effects = { NewRelationship = { Type = "Friend", Affection = 70 }, Stats = { Intelligence = 8, QiControl = 6 }, Happiness = 10 } },
			{ Text = "Test their resolve first", Result = "Three days in the rain. {new} never moves. You accept.", Effects = { NewRelationship = { Type = "Friend", Affection = 80 }, Personality = { Patience = 4 } } },
			{ Text = "Send them away", Result = "{new} walks off into the rain. You wonder about them for years.", Effects = { Stress = 3 } },
		},
	},

	old_rival_letter = {
		Title = "A Hell Butterfly from an Old Rival",
		Text = "A black butterfly lands on your hand carrying a message from {name}: \"We're both old now. One last spar?\"",
		MinAge = 45, MaxAge = 300, Weight = 0.15,
		Target = { Type = { "Rival" } },
		Options = {
			{ Text = "Accept the spar", Chance = 0.5, ChanceStat = "Strength",
				Result = "You win, then share sake until dawn. {name} becomes a friend.", Effects = { TargetBecomes = "Friend", Affection = 30, Counters = { Fights = 1 }, Happiness = 10 },
				FailResult = "{name} wins and laughs. You laugh too. It is enough.", FailEffects = { Affection = 20, Health = -10, Happiness = 6 } },
			{ Text = "Invite them to tea instead", Result = "Old grudges dissolve in green tea.", Effects = { TargetBecomes = "Friend", Affection = 25, Stress = -6 } },
			{ Text = "Let the butterfly fly off", Result = "Some fires never go out.", Effects = { Affection = -10 } },
		},
	},

	elder_garden = {
		Title = "Evening in the Garden",
		Text = "Your knees ache but the plum tree is blooming. A neighbour's grandchild watches you prune it.",
		MinAge = 60, MaxAge = 300, Weight = 0.2,
		Options = {
			{ Text = "Teach the child to prune", Result = "Small hands, careful snips. You smile all afternoon.", Effects = { Happiness = 10, Alignment = 3, Stress = -6 } },
			{ Text = "Meditate under the blossoms", Result = "Petals land on your shoulders. Time slows.", Effects = { Qi = 0.1, Lifespan = 1, Stress = -8 } },
			{ Text = "Sell the plums at market", Result = "Sweet fruit, sweet profit.", Effects = { Money = 120 } },
		},
	},

	memoir_request = {
		Title = "Write Your Memoir",
		Text = "A young archivist asks to record the story of your life for the Great Spirit Library.",
		MinAge = 60, MaxAge = 300, Weight = 0.15,
		Options = {
			{ Text = "Tell the whole truth", Result = "It is not always flattering. It is always yours.", Effects = { Personality = { Honesty = 4 }, Alignment = 3, Happiness = 6 } },
			{ Text = "Make yourself a hero", Chance = 0.5, ChanceStat = "Charisma",
				Result = "Your memoir becomes a favourite in every division mess hall.", Effects = { Stats = { Charisma = 8 }, Money = 200 },
				FailResult = "An old acquaintance publicly corrects every page.", FailEffects = { Happiness = -8, Stress = 6 } },
			{ Text = "Decline politely", Result = "Some stories belong to the wind.", Effects = { Stress = -3 } },
		},
	},

	last_journey = {
		Title = "One Last Journey",
		Text = "You have always wanted to see the sea at sunrise. Your legs will not carry you many more miles.",
		MinAge = 70, MaxAge = 300, Weight = 0.15,
		Options = {
			{ Text = "Go now", Chance = 0.6, ChanceStat = "Vitality",
				Result = "You stand on the shore as the sun rises and weep at its size.", Effects = { Happiness = 20, Stress = -15, Money = -100 },
				FailResult = "You fall ill halfway and must turn back.", FailEffects = { Health = -15, Happiness = -6 } },
			{ Text = "Ask a grandchild to take you", Result = "The sea and good company. A perfect week.", Effects = { Happiness = 15, Money = -60 } },
			{ Text = "Paint the sea instead", Result = "You have never seen it, but your painting feels true.", Effects = { Stats = { Intelligence = 4 }, Happiness = 6 } },
		},
	},
}

return YearlyEventsConfig
