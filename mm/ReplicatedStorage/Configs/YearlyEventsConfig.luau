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
		Text = "You turn 16. Finals start Monday, but everyone is going to the lantern party on the river.",
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
			{ Text = "Show off martial forms", Chance = 0.5, ChanceStat = "Agility",
				Result = "The crowd gasps at your speed.", Effects = { Happiness = 10, Stats = { Agility = 10 } },
				FailResult = "You trip over your own feet.", FailEffects = { Health = -5, Happiness = -6 } },
			{ Text = "Withdraw", Result = "You watch from the back row.", Effects = { Stress = -3 } },
		},
	},

	part_time_offer = {
		Title = "A Part-Time Job",
		Text = "The noodle stand owner offers you a part-time job after school.",
		MinAge = 15, MaxAge = 17, Weight = 0.3,
		Requires = { Employed = false },
		Options = {
			{ Text = "Accept", Result = "You start selling noodles every evening.", Effects = { Career = "StreetVendor", Money = 100, Stress = 4 } },
			{ Text = "Decline to focus on school", Result = "Your parents approve.", Effects = { Performance = 5 } },
		},
	},

	lost_wallet = {
		Title = "A Lost Purse",
		Text = "You find a silk purse heavy with coins on the road.",
		MinAge = 10, MaxAge = 90, Weight = 0.1, Repeatable = true, Cooldown = 10,
		Options = {
			{ Text = "Return it", Result = "The owner, a merchant, rewards your honesty with a lucky charm.", Effects = { Karma = 2, Alignment = 8, Money = 100, Items = { lucky_charm = 1 } } },
			{ Text = "Keep it", Result = "Easy money. Your conscience itches.", Effects = { Money = 600, Alignment = -8,
				FollowUp = { Id = "purse_owner", InYears = 2 } } },
		},
	},

	romance = {
		Title = "Lantern Festival",
		Text = "At the lantern festival, {new} catches your eye and smiles.",
		MinAge = 17, MaxAge = 45, Weight = 0.15, Repeatable = true, Cooldown = 3,
		Requires = { NoRelationship = "Partner" },
		Target = { Create = true },
		Options = {
			{ Text = "Ask them out", Chance = 0.4, ChanceStat = "Charisma",
				Result = "{new} says yes. Your heart races.", Effects = { NewRelationship = { Type = "Partner", Affection = 65 }, Happiness = 15 },
				FailResult = "{new} politely declines.", FailEffects = { Happiness = -6 } },
			{ Text = "Just be friends", Result = "You talk until the lanterns burn out.", Effects = { NewRelationship = { Type = "Friend", Affection = 55 } } },
			{ Text = "Walk away", Result = "Some chances only come once.", Effects = {} },
		},
	},

	proposal = {
		Title = "A Question of Forever",
		Text = "{name} takes your hands under the plum blossoms. \"Will you marry me?\"",
		MinAge = 18, MaxAge = 80, Weight = 0.25,
		Requires = { NotFlag = "Married" },
		Target = { Category = "Partner", MinAffection = 75 },
		Options = {
			{ Text = "Yes!", Result = "A joyous wedding fills the village with music.", Effects = { Flags = { "Married" }, Happiness = 25, Affection = 15, Money = -1000 } },
			{ Text = "Not yet", Result = "{name} is hurt, but understands.", Effects = { Affection = -12 } },
		},
	},

	friend_in_need = {
		Title = "A Friend in Need",
		Text = "{name} needs money for their sick mother's medicine.",
		MinAge = 14, MaxAge = 90, Weight = 0.12, Repeatable = true, Cooldown = 5,
		Target = { Category = "Friend", MinAffection = 45 },
		Options = {
			{ Text = "Lend $500", Requires = { MinMoney = 500 }, Result = "{name} will never forget this.", Effects = { Money = -500, Affection = 20, Karma = 2, Alignment = 5,
				Delayed = { InYears = 3, Text = "{name} repays your $500 loan, with interest and a long hug.", Effects = { Money = 800, Affection = 10 } } } },
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
		Text = "{name} challenges you in the town square in front of everyone.",
		MinAge = 10, MaxAge = 120, Weight = 0.18, Repeatable = true, Cooldown = 3,
		Target = { Category = "Rival" },
		Options = {
			{ Text = "Accept the duel", Chance = 0.4, ChanceStat = "Strength",
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
			{ Text = "Pay a famous healer ($2K)", Requires = { MinMoney = 2000 }, Result = "{name} recovers fully.", Effects = { Money = -2000, Affection = 15, Karma = 2 } },
			{ Text = "Care for them yourself", Result = "Long nights at the bedside bring you closer.", Effects = { Affection = 20, Stress = 15, Alignment = 5 } },
			{ Text = "Stay away", Result = "{name} feels abandoned.", Effects = { Affection = -25, Alignment = -8 } },
		},
	},

	library_manual = {
		Title = "The Hidden Manual",
		Text = "Behind a loose shelf in the library you find a cultivation manual wrapped in silk.",
		MinAge = 10, MaxAge = 200, Weight = 0.15,
		Requires = { Counters = { Knowledge = 10 } },
		Options = {
			{ Text = "Study it in secret", Result = "The breathing patterns are real.", Effects = { Qi = 1, Stats = { QiControl = 25 } } },
			{ Text = "Return it to the librarian", Result = "The old librarian nods knowingly.", Effects = { Karma = 3, Alignment = 5, Stats = { Intelligence = 10 } } },
		},
	},

	mugging = {
		Title = "Dark Alley",
		Text = "A masked thug blocks your path. \"Your money or your life.\"",
		MinAge = 16, MaxAge = 90, Weight = 0.08, Repeatable = true, Cooldown = 5,
		Options = {
			{ Text = "Fight back", Chance = 0.35, ChanceStat = "Strength",
				Result = "The thug flees, bruised.", Effects = { Counters = { Fights = 1 }, Stats = { Strength = 8 },
					FollowUp = { Id = "watch_captain", InYears = 0 } },
				FailResult = "You get stabbed.", FailEffects = { Health = -30 } },
			{ Text = "Run", Chance = 0.5, ChanceStat = "Agility",
				Result = "You vanish into the crowd.", Effects = { Stats = { Agility = 8 } },
				FailResult = "He catches you and takes everything.", FailEffects = { Money = -400, Health = -10 } },
			{ Text = "Hand over your purse", Result = "You lose some money but stay safe.", Effects = { Money = -250, Stress = 6 } },
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
			{ Text = "Take a vacation ($1K)", Requires = { MinMoney = 1000 }, Result = "Sea air does wonders.", Effects = { Money = -1000, Stress = -40, Happiness = 10 } },
			{ Text = "Visit a temple", Result = "The monks teach you to breathe.", Effects = { Stress = -25, Stats = { QiControl = 8 } } },
			{ Text = "Push through", Result = "You keep going, but something breaks inside.", Effects = { Stress = 10, Health = -15 } },
		},
	},

	midlife = {
		Title = "Midlife Reflection",
		Text = "Halfway through a mortal life, you wonder if this is all there is.",
		MinAge = 40, MaxAge = 50, Weight = 0.15,
		Options = {
			{ Text = "Buy a legendary sword ($5K)", Requires = { MinMoney = 5000 }, Result = "It is beautiful. You feel young again.", Effects = { Money = -5000, Happiness = 15, Proficiency = { Sword = 30 } } },
			{ Text = "Take up calligraphy", Result = "Patient strokes calm your mind.", Effects = { Stats = { Intelligence = 12, QiControl = 8 }, Stress = -10 } },
			{ Text = "Quit your job and travel", Requires = { Employed = true }, Result = "Freedom tastes like road dust.", Effects = { QuitJob = true, Happiness = 15, Stress = -25 } },
		},
	},

	inheritance = {
		Title = "An Unexpected Will",
		Text = "A distant uncle you barely remember has left you his fortune.",
		MinAge = 25, MaxAge = 90, Weight = 0.04,
		Options = {
			{ Text = "Keep it all", Result = "$10K richer, plus your uncle's jade bracelet.", Effects = { Money = 10000, Items = { jade_bracelet = 1 } } },
			{ Text = "Donate half to orphanages", Result = "Children across the city eat well this winter.", Effects = { Money = 5000, Karma = 6, Alignment = 10 } },
		},
	},

	old_friend = {
		Title = "An Old Friend",
		Text = "You bump into {name} after many years. Memories flood back.",
		MinAge = 30, MaxAge = 150, Weight = 0.08, Repeatable = true, Cooldown = 6,
		Target = { Category = "Friend", MaxAffection = 60 },
		Options = {
			{ Text = "Catch up over wine", Result = "It is like no time has passed.", Effects = { Affection = 20, Happiness = 8 } },
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
		Title = "The Merchant Remembers",
		Text = "A merchant recognizes the silk purse on your belt and calls for the guards.",
		ChainOnly = true,
		Options = {
			{ Text = "Confess and repay", Result = "You hand over the money and apologize.", Effects = { Money = -600, Karma = 2, Alignment = 5 } },
			{ Text = "Talk your way out", Chance = 0.35, ChanceStat = "Charisma",
				Result = "He decides it must be a different purse.", Effects = { Happiness = 3 },
				FailResult = "The guards fine you and rough you up.", FailEffects = { Money = -800, Health = -10, Alignment = -5 } },
			{ Text = "Run", Chance = 0.5, ChanceStat = "Agility",
				Result = "You vanish down an alley.", Effects = { Stats = { Agility = 8 }, Alignment = -3 },
				FailResult = "They catch you at the city gate.", FailEffects = { Health = -15, Money = -600 } },
		},
	},

	watch_captain = {
		Title = "The Watch Captain",
		Text = "A captain of the city watch saw the whole fight and walks over, impressed.",
		ChainOnly = true,
		Options = {
			{ Text = "Accept a reward", Result = "She presses a pouch of coins into your hand.", Effects = { Money = 300, Karma = 1 } },
			{ Text = "Ask to train with the watch", Result = "Months of drills with real soldiers.", Effects = { Stats = { Strength = 15, Agility = 8 } } },
			{ Text = "Decline modestly", Result = "Word of your humility spreads.", Effects = { Alignment = 5, Karma = 2 } },
		},
	},

	-- Samsara module: past lives, eras and legends (Modules/SamsaraSystem).
	past_life_encounter = {
		Module = "Samsara",
		Title = "A Familiar Stranger",
		Text = "In a crowded market an old face stops and stares at you, as if they have known you forever.",
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
		Title = "A Primordial Beast",
		Text = "The ancient wilds are not like the tame world you remember. A colossal beast blocks the mountain path.",
		MinAge = 10, MaxAge = 200, Weight = 0.18, Repeatable = true, Cooldown = 5,
		Requires = { Era = "Ancient" },
		Options = {
			{ Text = "Fight it", Chance = 0.45, ChanceStat = "Strength",
				Result = "You slay it and drink from its Qi-rich core.", Effects = { Qi = 0.3, Stats = { Strength = 15 }, Counters = { Fights = 1 } },
				FailResult = "It throws you down the cliff.", FailEffects = { Health = -35 } },
			{ Text = "Hide and observe", Chance = 0.6, ChanceStat = "Agility",
				Result = "You learn how it breathes Qi.", Effects = { Stats = { QiControl = 10 } },
				FailResult = "It smells you anyway.", FailEffects = { Health = -15 } },
			{ Text = "Turn back", Result = "You live to see another day.", Effects = { Stress = 4 } },
		},
	},

	rival_mentor = {
		Module = "Samsara",
		Title = "The Master Who Was Your Enemy",
		Text = "The most feared cultivator in the region is recruiting disciples. You know that face: your arch-rival from a past life. They look straight at you and see a stranger.",
		MinAge = 12, MaxAge = 60, Weight = 0.35, Repeatable = true, Cooldown = 4,
		Requires = { RivalMentorHere = true, IsRivalDisciple = false },
		Options = {
			{ Text = "Kneel and ask to become their disciple", Result = "Your old enemy accepts you. The irony burns.", Effects = { BecomeRivalDisciple = true } },
			{ Text = "Study them from the shadows", Result = "You learn their habits, for now.", Effects = { Stats = { Intelligence = 6 } } },
			{ Text = "Leave the past buried", Result = "Some debts can wait another lifetime.", Effects = { Stress = -3 } },
		},
	},

	rival_reckoning = {
		Module = "Samsara", Trigger = "System", ChainOnly = true,
		Title = "Master and Disciple, Rival and Rival",
		Text = "Your master has taught you everything, including their signature art. Tonight, under the same moon as the duel from your past life, you could tell them who you really are.",
		Options = {
			{ Text = "Reveal your past life and duel them", Requires = { RemembersPastLife = true }, Chance = 0.45, ChanceStat = "Strength",
				Result = "Recognition, then fear. Your blade settles a feud older than this body.", Effects = { RivalReckoning = "Revenge", Counters = { Fights = 1 } },
				FailResult = "They win again and throw you down the mountain.", FailEffects = { RivalReckoning = "Defeat", Health = -40 } },
			{ Text = "Keep the secret and inherit their legacy", Result = "You bow. The hatred of two lifetimes becomes gratitude.", Effects = { RivalReckoning = "Legacy", Karma = 3 } },
		},
	},

	heirloom_reclaim = {
		Module = "Dynasty",
		Title = "Your Own Heirloom",
		Text = "In the market you recognize it at once: the heirloom you consecrated in a past life, now carried by a descendant of your old family. Your name is still on the inscription.",
		MinAge = 14, MaxAge = 300, Weight = 0.4, Repeatable = true, Cooldown = 3,
		Requires = { LostHeirloomHere = true },
		Options = {
			{ Text = "Buy it back ($1.5K)", Requires = { MinMoney = 1500 }, Result = "They sell, puzzled by your tears.", Effects = { Money = -1500, ReclaimHeirloom = "Buy" } },
			{ Text = "Challenge them to a duel for it", Result = "Steel rings out in the market square.", Effects = { StartDuel = "Heirloom" } },
			{ Text = "Steal it in the night", Chance = 0.5, ChanceStat = "Agility",
				Result = "It was yours first.", Effects = { ReclaimHeirloom = "Steal", Alignment = -10 },
				FailResult = "The guards catch you.", FailEffects = { Money = -500, Health = -10, Alignment = -5 } },
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
		Text = "A cousin from the other branch of the family arrives with a cart full of gifts and gossip.",
		MinAge = 8, MaxAge = 20, Weight = 0.2,
		Options = {
			{ Text = "Show them around", Result = "You become fast friends.", Effects = { MeetRelative = "Cousin", Stats = { Charisma = 6 } } },
			{ Text = "Compete with them", Result = "Family rivalry, the healthy kind.", Effects = { MeetRelative = "Cousin", Stats = { Strength = 6 } } },
		},
	},

	legend_of_self = {
		Module = "Samsara",
		Title = "A Legend You Remember",
		Text = "A storyteller at the inn tells the tale of a cultivator from a hundred years ago. The story sounds... very familiar.",
		MinAge = 8, MaxAge = 60, Weight = 0.3,
		Requires = { Era = "Future" },
		Options = {
			{ Text = "Listen closely", Result = "You hear your own past told by strangers.", Effects = { LegendOfSelf = true } },
			{ Text = "Correct the storyteller", Requires = { RemembersPastLife = true },
				Result = "The crowd falls silent as you recount details no one could know.", Effects = { LegendOfSelf = true, Karma = 2, Stats = { Charisma = 8 } } },
		},
	},

	-- 2.0 personality: options that only open past a slider threshold (Character module).
	beggar_gate = {
		Module = "Character",
		Title = "A Beggar at the Gate",
		Text = "An old beggar holds out a cracked bowl as you pass the city gate.",
		MinAge = 10, MaxAge = 90, Weight = 0.12, Repeatable = true, Cooldown = 6,
		Options = {
			{ Text = "Give a few coins", Result = "He bows low and blesses your road.", Effects = { Money = -20, Personality = { Generosity = 4, Kindness = 2 } } },
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
		Text = "The neighborhood bully dares you to jump the gap between two rooftops.",
		MinAge = 8, MaxAge = 16, Weight = 0.2, Repeatable = true, Cooldown = 3,
		Options = {
			{ Text = "Take the jump", Chance = 0.5, ChanceStat = "Agility",
				Result = "You land it. The other kids cheer.", Effects = { Happiness = 8, Personality = { Bravery = 5 } },
				FailResult = "You fall short and land in a cart of cabbages.", FailEffects = { Health = -8, Happiness = -4 } },
			{ Text = "Stare him down until he leaves", Requires = { Personality = { Bravery = 50 } },
				Result = "He mutters something and backs off. Nobody dares you again.", Effects = { Happiness = 10, Stats = { Charisma = 6 }, Personality = { Bravery = 3 } } },
			{ Text = "Walk away", Result = "Laughter follows you home.", Effects = { Happiness = -3, Personality = { Bravery = -3, Caution = 3 } } },
		},
	},

	merchant_mistake = {
		Module = "Character",
		Title = "The Merchant's Mistake",
		Text = "A distracted merchant hands you far too much change.",
		MinAge = 14, MaxAge = 80, Weight = 0.12, Repeatable = true, Cooldown = 6,
		Options = {
			{ Text = "Point out the mistake", Result = "He laughs, thanks you and remembers your face.", Effects = { Alignment = 3, Personality = { Honesty = 4 } } },
			{ Text = "Pocket it", Result = "Easy coin.", Effects = { Money = 80, Personality = { Honesty = -4 } } },
			{ Text = "Talk him into a bigger 'mistake'", Requires = { Personality = { Honesty = -50 } }, Chance = 0.6, ChanceStat = "Charisma",
				Result = "By the end he thinks he owes you. You walk away rich.", Effects = { Money = 400, Alignment = -4 },
				FailResult = "He sees through you and calls the guard.", FailEffects = { Money = -50, Alignment = -4, Stress = 6 } },
		},
	},

	-- ===== Content expansion (2026-11-02): 38 more everyday events =====

	toddler_wander = {
		Title = "The Open Gate",
		Text = "Someone left the courtyard gate open. The whole wide street is right there.",
		MinAge = 2, MaxAge = 3, Weight = 0.5,
		Options = {
			{ Text = "Toddle out to explore", Chance = 0.6, ChanceStat = "Agility",
				Result = "You find a cat, a puddle and a very worried neighbour.", Effects = { Stats = { Agility = 6 }, Happiness = 6, Personality = { Curiosity = 4 } },
				FailResult = "You fall into a ditch and wail until you are found.", FailEffects = { Health = -6, Happiness = -4 } },
			{ Text = "Stay by the door", Result = "You watch the world go by from safety.", Effects = { Personality = { Caution = 4 } } },
			{ Text = "Call for your mother", Result = "She swoops you up and shuts the gate.", Effects = { Happiness = 3 } },
		},
	},

	grandmother_tales = {
		Title = "Grandmother's Tales",
		Text = "On a cold night, Grandmother tells stories of immortals who rode cranes above the clouds.",
		MinAge = 3, MaxAge = 6, Weight = 0.45,
		Options = {
			{ Text = "Ask how to become one", Result = "\"Breathe slowly, child. It starts with breath.\"", Effects = { Stats = { QiControl = 6 }, Personality = { Ambition = 3 } } },
			{ Text = "Ask for a scary one", Result = "You sleep with the lamp on for a week.", Effects = { Stats = { Intelligence = 4 }, Stress = 2, Happiness = 4 } },
			{ Text = "Fall asleep in her lap", Result = "The warmest night of your childhood.", Effects = { Happiness = 8, Stress = -4 } },
		},
	},

	broken_vase = {
		Title = "The Broken Vase",
		Text = "Playing ball indoors, you shatter your father's favourite porcelain vase.",
		MinAge = 4, MaxAge = 8, Weight = 0.4,
		Options = {
			{ Text = "Confess at once", Result = "He is angry, but proud of your honesty.", Effects = { Personality = { Honesty = 5 }, Alignment = 3, Happiness = -3 } },
			{ Text = "Blame the cat", Chance = 0.5, ChanceStat = "Charisma",
				Result = "The cat is banished to the yard. You feel a little bad.", Effects = { Personality = { Honesty = -4 }, Stats = { Charisma = 4 } },
				FailResult = "The cat was asleep in plain view. Double punishment.", FailEffects = { Happiness = -8, Personality = { Honesty = -3 } } },
			{ Text = "Glue it back together", Chance = 0.4, ChanceStat = "Agility",
				Result = "Nobody notices for a whole year.", Effects = { Stats = { Agility = 6, Intelligence = 3 } },
				FailResult = "It falls apart the moment he touches it.", FailEffects = { Happiness = -6, Stress = 4 } },
		},
	},

	kite_contest = {
		Title = "The Kite Contest",
		Text = "Every child in the village brings a kite to the spring hill. The highest one wins a sweet bun.",
		MinAge = 5, MaxAge = 10, Weight = 0.35,
		Options = {
			{ Text = "Build the biggest kite", Chance = 0.45, ChanceStat = "Intelligence",
				Result = "It soars above the pines. You win the bun and the crowd.", Effects = { Stats = { Intelligence = 8 }, Happiness = 10 },
				FailResult = "Too heavy. It never leaves the ground.", FailEffects = { Happiness = -4 } },
			{ Text = "Run faster than everyone", Chance = 0.5, ChanceStat = "Agility",
				Result = "Your little kite climbs like a swallow.", Effects = { Stats = { Agility = 8 }, Happiness = 8 },
				FailResult = "You trip and the string snaps.", FailEffects = { Health = -4, Happiness = -3 } },
			{ Text = "Help a younger kid fly theirs", Result = "They win. You get half the bun anyway.", Effects = { Alignment = 4, Personality = { Kindness = 3 }, Happiness = 5 } },
		},
	},

	injured_sparrow = {
		Title = "The Injured Sparrow",
		Text = "A sparrow with a broken wing flutters helplessly in the road.",
		MinAge = 5, MaxAge = 12, Weight = 0.35,
		Options = {
			{ Text = "Nurse it back to health", Chance = 0.6, ChanceStat = "Intelligence",
				Result = "Weeks later it flies away, circling you once.", Effects = { Alignment = 5, Karma = 1, Happiness = 8, Personality = { Kindness = 4 } },
				FailResult = "It dies in your hands. You cry for days.", FailEffects = { Happiness = -6, Personality = { Kindness = 2 } } },
			{ Text = "Leave it to nature", Result = "You walk on. The road goes quiet.", Effects = {} },
			{ Text = "Poke it with a stick", Result = "An old monk sees you and shakes his head slowly.", Effects = { Alignment = -5, Karma = -1 } },
		},
	},

	first_meditation = {
		Title = "The First Stillness",
		Text = "Sitting by the river at dawn, the world goes quiet and you feel something warm stir below your navel.",
		MinAge = 6, MaxAge = 12, Weight = 0.3,
		Options = {
			{ Text = "Follow the warmth", Result = "A thread of Qi answers you for the first time.", Effects = { Qi = 0.1, Stats = { QiControl = 10 } } },
			{ Text = "Jump up in surprise", Result = "It vanishes. But you know it is there now.", Effects = { Stats = { QiControl = 3 }, Personality = { Curiosity = 3 } } },
			{ Text = "Tell your parents", Result = "They exchange a look and start saving for a sect fee.", Effects = { Money = -20, Happiness = 5 } },
		},
	},

	tutor_offer = {
		Title = "A Wandering Tutor",
		Text = "A threadbare scholar offers lessons in exchange for a bowl of rice a day.",
		MinAge = 7, MaxAge = 14, Weight = 0.3,
		Options = {
			{ Text = "Study with him", Result = "He knows a surprising amount about the classics.", Effects = { Stats = { Intelligence = 14 }, Counters = { Knowledge = 2 }, Money = -30 } },
			{ Text = "Ask him about cultivation", Chance = 0.4, ChanceStat = "Charisma",
				Result = "He lowers his voice and teaches you a breathing rhythm.", Effects = { Stats = { QiControl = 10, Intelligence = 4 }, Money = -30 },
				FailResult = "\"Cultivation? I teach poetry, child.\"", FailEffects = { Stats = { Intelligence = 6 }, Money = -30 } },
			{ Text = "Send him away", Result = "He bows politely and wanders on.", Effects = {} },
		},
	},

	market_thief_kid = {
		Title = "Quick Fingers",
		Text = "A ragged child named {new} offers to teach you how to lift buns from the market stalls.",
		MinAge = 8, MaxAge = 13, Weight = 0.3,
		Target = { Create = true },
		Options = {
			{ Text = "Learn the trick", Chance = 0.55, ChanceStat = "Agility",
				Result = "Warm buns and a new partner in crime.", Effects = { Stats = { Agility = 8 }, Personality = { Honesty = -4 }, NewRelationship = { Type = "Friend", Affection = 45 } },
				FailResult = "The baker grabs your collar. Your parents pay double.", FailEffects = { Money = -40, Happiness = -8, Alignment = -3 } },
			{ Text = "Buy {new} a bun instead", Result = "{new} eats it in three bites and decides you are alright.", Effects = { Money = -5, NewRelationship = { Type = "Friend", Affection = 55 }, Alignment = 4 } },
			{ Text = "Report them to the guard", Result = "{new} is dragged off, glaring at you.", Effects = { NewRelationship = { Type = "Rival", Affection = 15 }, Alignment = -2 } },
		},
	},

	river_swim = {
		Title = "The Cold River",
		Text = "The older kids dare you to swim across the river while it is still swollen with snowmelt.",
		MinAge = 9, MaxAge = 15, Weight = 0.3,
		Options = {
			{ Text = "Swim it", Chance = 0.45, ChanceStat = "Vitality",
				Result = "You crawl out on the far bank, shaking and triumphant.", Effects = { Stats = { Vitality = 10, Strength = 4 }, Happiness = 8 },
				FailResult = "The current drags you downstream. A fisherman pulls you out.", FailEffects = { Health = -18, Stress = 8 } },
			{ Text = "Walk across the bridge", Result = "They call you a coward. You stay dry.", Effects = { Happiness = -3, Personality = { Caution = 4 } } },
			{ Text = "Dare them back", Chance = 0.5, ChanceStat = "Charisma",
				Result = "Nobody swims. Everybody laughs. You win.", Effects = { Stats = { Charisma = 8 } },
				FailResult = "They throw you in anyway.", FailEffects = { Health = -8, Happiness = -4 } },
		},
	},

	sect_recruiters = {
		Title = "Recruiters in the Square",
		Text = "Disciples in blue robes set up a testing stone in the town square. Children line up to touch it.",
		MinAge = 10, MaxAge = 14, Weight = 0.4,
		Options = {
			{ Text = "Touch the stone", Chance = 0.45, ChanceStat = "QiControl",
				Result = "It glows faintly. An elder writes down your name.", Effects = { Qi = 0.15, Stats = { QiControl = 8 }, Happiness = 12, FollowUp = { Id = "sect_letter", InYears = 1 } },
				FailResult = "Nothing. The line moves on without you.", FailEffects = { Happiness = -8, Personality = { Ambition = 3 } } },
			{ Text = "Watch from the crowd", Result = "You memorise how the elders breathe.", Effects = { Stats = { QiControl = 4, Intelligence = 3 } } },
			{ Text = "Sell snacks to the queue", Result = "Cultivation can wait. Profit cannot.", Effects = { Money = 60, Stats = { Charisma = 4 } } },
		},
	},

	sect_letter = {
		ChainOnly = true,
		Title = "A Letter with a Jade Seal",
		Text = "A letter arrives bearing the seal of the sect whose stone glowed for you.",
		Options = {
			{ Text = "Accept the outer-disciple trial", Chance = 0.5, ChanceStat = "Vitality",
				Result = "Three days of climbing stairs. You pass. A jade token is yours.", Effects = { Items = { jade_bracelet = 1 }, Stats = { Vitality = 10, QiControl = 6 }, Happiness = 10 },
				FailResult = "You collapse on the nine-hundredth step.", FailEffects = { Health = -12, Happiness = -6, Stats = { Vitality = 4 } } },
			{ Text = "Stay with your family", Result = "Your mother cries with relief.", Effects = { Happiness = 6, Alignment = 2 } },
		},
	},

	calligraphy_contest = {
		Title = "The Calligraphy Contest",
		Text = "The magistrate holds a calligraphy contest. The prize is a brush made of white tiger hair.",
		MinAge = 10, MaxAge = 20, Weight = 0.25,
		Options = {
			{ Text = "Enter with bold strokes", Chance = 0.4, ChanceStat = "Intelligence",
				Result = "The magistrate hangs your scroll in his hall.", Effects = { Stats = { Intelligence = 12 }, Money = 100, Happiness = 10 },
				FailResult = "An ink blot ruins your best character.", FailEffects = { Stress = 6, Happiness = -4 } },
			{ Text = "Write a poem instead", Chance = 0.5, ChanceStat = "Charisma",
				Result = "It is not calligraphy, but everyone quotes it for a month.", Effects = { Stats = { Charisma = 10 } },
				FailResult = "Nobody understands it. Including you.", FailEffects = { Happiness = -3 } },
			{ Text = "Skip it", Result = "You spend the day fishing.", Effects = { Stress = -5 } },
		},
	},

	festival_dragon_boat = {
		Title = "Dragon Boat Festival",
		Text = "Your street needs one more rower for the dragon boat race.",
		MinAge = 12, MaxAge = 40, Weight = 0.2, Repeatable = true, Cooldown = 8,
		Options = {
			{ Text = "Take the oar", Chance = 0.5, ChanceStat = "Strength",
				Result = "Your boat wins by a nose. The whole street feasts.", Effects = { Stats = { Strength = 10 }, Happiness = 12 },
				FailResult = "You catch a crab and the boat spins. Last place.", FailEffects = { Happiness = -5, Stats = { Strength = 4 } } },
			{ Text = "Beat the drum", Chance = 0.6, ChanceStat = "Charisma",
				Result = "Your rhythm drives them home first.", Effects = { Stats = { Charisma = 8 }, Happiness = 10 },
				FailResult = "Off-beat all race. Nobody lets you forget it.", FailEffects = { Happiness = -4 } },
			{ Text = "Bet on the other street", Result = "You win money and lose friends.", Effects = { Money = 120, Alignment = -3 } },
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
				FailResult = "{new} reads it aloud to their friends.", FailEffects = { Happiness = -12, Stress = 8 } },
			{ Text = "Admire from afar", Result = "You fill a notebook with bad poems.", Effects = { Stats = { Intelligence = 4 }, Stress = 3 } },
			{ Text = "Train harder to impress", Result = "{new} never notices. Your arms do.", Effects = { Stats = { Strength = 8, Vitality = 4 } } },
		},
	},

	runaway_temptation = {
		Title = "The Road Beyond the Hills",
		Text = "After another argument at home, you pack a bundle and stand at the edge of the village.",
		MinAge = 13, MaxAge = 17, Weight = 0.2,
		Options = {
			{ Text = "Leave for a while", Chance = 0.5, ChanceStat = "Vitality",
				Result = "A month on the road teaches you more than a year at home.", Effects = { Stats = { Vitality = 8, Intelligence = 6 }, Personality = { Bravery = 4 }, Stress = -6 },
				FailResult = "Bandits take your bundle. You walk home hungry.", FailEffects = { Health = -10, Happiness = -8 } },
			{ Text = "Go home and apologise", Result = "Your parents hold you a little longer than usual.", Effects = { Happiness = 6, Alignment = 3 } },
			{ Text = "Sit on the hill until dawn", Result = "The stars help you think.", Effects = { Stress = -8, Stats = { QiControl = 4 } } },
		},
	},

	sparring_tournament = {
		Title = "The Youth Tournament",
		Text = "The county holds a youth martial tournament. The winner gets a manual from the magistrate's library.",
		MinAge = 14, MaxAge = 19, Weight = 0.35,
		Options = {
			{ Text = "Enter and fight", Chance = 0.4, ChanceStat = "Strength",
				Result = "Champion! The manual is yours.", Effects = { Counters = { Fights = 3, Knowledge = 1 }, Stats = { Strength = 14 }, Proficiency = { QiArts = 10 }, Happiness = 12 },
				FailResult = "Knocked out in the second round.", FailEffects = { Counters = { Fights = 2 }, Health = -14, Stats = { Strength = 5 } } },
			{ Text = "Enter and dodge everything", Chance = 0.45, ChanceStat = "Agility",
				Result = "Nobody lands a blow. The judges call it a draw and give you the prize.", Effects = { Counters = { Fights = 3 }, Stats = { Agility = 14 }, Happiness = 10 },
				FailResult = "One lucky kick ends your run.", FailEffects = { Counters = { Fights = 1 }, Health = -10 } },
			{ Text = "Scout the fighters", Result = "You learn every style in the county by watching.", Effects = { Stats = { Intelligence = 8 }, Proficiency = { QiArts = 4 } } },
		},
	},

	apprentice_choice = {
		Title = "An Apprenticeship",
		Text = "Three masters in town will take an apprentice this year: a blacksmith, an herbalist and a scribe.",
		MinAge = 14, MaxAge = 18, Weight = 0.4,
		Options = {
			{ Text = "The blacksmith", Result = "Hot iron and heavy hammers. Your arms thicken.", Effects = { Stats = { Strength = 14, Vitality = 6 }, Money = 40 } },
			{ Text = "The herbalist", Result = "You learn which roots heal and which ones kill.", Effects = { Stats = { Intelligence = 10 }, Items = { healing_salve = 2 } } },
			{ Text = "The scribe", Result = "Ink-stained fingers and a head full of laws.", Effects = { Stats = { Intelligence = 12, Charisma = 4 }, Counters = { Knowledge = 1 } } },
		},
	},

	spirit_beast_cub = {
		Title = "A Lost Spirit Cub",
		Text = "In the forest you find a fox cub with two tails, whimpering beside a hunter's trap.",
		MinAge = 12, MaxAge = 60, Weight = 0.15,
		Options = {
			{ Text = "Free it", Chance = 0.6, ChanceStat = "Agility",
				Result = "It licks your hand and vanishes. You feel strangely lucky.", Effects = { Karma = 3, Alignment = 5, Stats = { Luck = 8 } },
				FailResult = "It bites you in panic, then runs.", FailEffects = { Health = -6, Karma = 2 } },
			{ Text = "Sell it to a merchant", Result = "Spirit beasts fetch a fine price.", Effects = { Money = 300, Karma = -3, Alignment = -5 } },
			{ Text = "Leave it", Result = "Its cries follow you all the way home.", Effects = { Stress = 4 } },
		},
	},

	flood_season = {
		Title = "The River Rises",
		Text = "Weeks of rain. The river breaks its banks and water pours into the lower town.",
		MinAge = 12, MaxAge = 80, Weight = 0.12, Repeatable = true, Cooldown = 10,
		Options = {
			{ Text = "Carry people to safety", Chance = 0.55, ChanceStat = "Strength",
				Result = "You save a family of five. The town remembers.", Effects = { Stats = { Strength = 8, Vitality = 6 }, Alignment = 8, Karma = 2 },
				FailResult = "The current knocks you down. You barely make it out.", FailEffects = { Health = -20, Alignment = 4 } },
			{ Text = "Build sandbag walls", Result = "Back-breaking work, but your street stays dry.", Effects = { Stats = { Vitality = 8 }, Stress = 6 } },
			{ Text = "Sell boats at triple price", Result = "A fortune earned on other people's misery.", Effects = { Money = 500, Alignment = -8, Karma = -2 } },
		},
	},

	gambling_den = {
		Title = "The Dice House",
		Text = "Laughter and clattering dice spill from a doorway. A man waves you inside.",
		MinAge = 16, MaxAge = 90, Weight = 0.15, Repeatable = true, Cooldown = 6,
		Requires = { MinMoney = 100 },
		Options = {
			{ Text = "Roll the dice", Chance = 0.35, ChanceStat = "Luck",
				Result = "Fortune smiles. You leave with heavy pockets.", Effects = { Money = 400, Happiness = 8 },
				FailResult = "The house always wins.", FailEffects = { Money = -150, Stress = 8 } },
			{ Text = "Spot the cheat", Chance = 0.4, ChanceStat = "Intelligence",
				Result = "You expose loaded dice. The other players reward you.", Effects = { Money = 200, Alignment = 3 },
				FailResult = "You accuse the wrong man. Bouncers throw you out.", FailEffects = { Health = -10, Happiness = -5 } },
			{ Text = "Walk past", Result = "Your purse thanks you.", Effects = { Personality = { Caution = 2 } } },
		},
	},

	tea_house_poet = {
		Title = "The Tea House Duel",
		Text = "A famous poet in the tea house challenges anyone to finish his couplet.",
		MinAge = 16, MaxAge = 90, Weight = 0.15, Repeatable = true, Cooldown = 10,
		Options = {
			{ Text = "Answer the couplet", Chance = 0.4, ChanceStat = "Intelligence",
				Result = "The room falls silent, then erupts. The poet pays for your tea.", Effects = { Stats = { Intelligence = 10, Charisma = 6 }, Happiness = 8 },
				FailResult = "Your line does not even rhyme.", FailEffects = { Happiness = -6 } },
			{ Text = "Make the room laugh", Chance = 0.55, ChanceStat = "Charisma",
				Result = "Not poetry, but the poet laughs hardest of all.", Effects = { Stats = { Charisma = 10 } },
				FailResult = "Silence. Someone coughs.", FailEffects = { Stress = 4 } },
			{ Text = "Just drink your tea", Result = "Excellent tea.", Effects = { Stress = -4 } },
		},
	},

	road_bandits = {
		Title = "Bandits on the Road",
		Text = "Travelling between towns, masked bandits step out of the bamboo.",
		MinAge = 16, MaxAge = 90, Weight = 0.15, Repeatable = true, Cooldown = 6,
		Options = {
			{ Text = "Fight them off", Chance = 0.4, ChanceStat = "Strength",
				Result = "Three bandits flee into the bamboo. You keep their purse.", Effects = { Counters = { Fights = 1 }, Stats = { Strength = 10 }, Money = 120 },
				FailResult = "They beat you and take everything.", FailEffects = { Health = -25, Money = -100 } },
			{ Text = "Pay the toll", Result = "Expensive, but you keep your teeth.", Effects = { Money = -80 } },
			{ Text = "Talk them into joining a better cause", Chance = 0.3, ChanceStat = "Charisma",
				Result = "They become honest porters. One sends you a gift years later.", Effects = { Alignment = 6, Karma = 2, Stats = { Charisma = 10 } },
				FailResult = "They laugh and take double.", FailEffects = { Money = -160 } },
		},
	},

	sick_neighbor = {
		Title = "Fever Next Door",
		Text = "The old widow next door has been coughing for a week. Nobody has checked on her.",
		MinAge = 14, MaxAge = 90, Weight = 0.15, Repeatable = true, Cooldown = 10,
		Options = {
			{ Text = "Bring medicine", Requires = { Items = { healing_salve = 1 } },
				Result = "She recovers, and swears you are a living bodhisattva.", Effects = { Items = { healing_salve = -1 }, Alignment = 6, Karma = 2, Happiness = 6 } },
			{ Text = "Cook her soup", Result = "She gets better slowly. You visit every day.", Effects = { Alignment = 4, Personality = { Kindness = 3 }, Money = -10 } },
			{ Text = "Mind your own business", Result = "The coughing stops one night. You try not to think about it.", Effects = { Stress = 4 } },
		},
	},

	moving_house = {
		Title = "A New Home",
		Text = "Your landlord doubles the rent. A cheaper place has opened up across the river.",
		MinAge = 18, MaxAge = 70, Weight = 0.12,
		Options = {
			{ Text = "Move across the river", Result = "Smaller rooms, new neighbours, fresh start.", Effects = { Money = 100, Happiness = 4, Stress = 4 } },
			{ Text = "Haggle with the landlord", Chance = 0.45, ChanceStat = "Charisma",
				Result = "He settles for a modest rise.", Effects = { Stats = { Charisma = 8 } },
				FailResult = "He raises it again for your cheek.", FailEffects = { Money = -150, Stress = 6 } },
			{ Text = "Pay the new rent", Result = "Your purse groans.", Effects = { Money = -200 } },
		},
	},

	business_partner = {
		Title = "A Business Proposal",
		Text = "{new}, a confident trader, wants you as a partner in a silk caravan.",
		MinAge = 20, MaxAge = 70, Weight = 0.15,
		Requires = { MinMoney = 500 },
		Target = { Create = true },
		Options = {
			{ Text = "Invest your savings", Chance = 0.5, ChanceStat = "Luck",
				Result = "The caravan returns laden with silver.", Effects = { Money = 1200, NewRelationship = { Type = "Friend", Affection = 55 } },
				FailResult = "The caravan vanishes in the desert. So does {new}.", FailEffects = { Money = -500, Stress = 12 } },
			{ Text = "Study the plan first", Chance = 0.55, ChanceStat = "Intelligence",
				Result = "You fix two fatal mistakes. Modest, safe profit.", Effects = { Money = 400, Stats = { Intelligence = 6 }, NewRelationship = { Type = "Friend", Affection = 50 } },
				FailResult = "You find nothing wrong. Neither does the sandstorm.", FailEffects = { Money = -200 } },
			{ Text = "Decline", Result = "{new} shrugs and finds another fool. Or genius.", Effects = {} },
		},
	},

	wedding_invite = {
		Title = "A Wedding Invitation",
		Text = "Your friend {name} is getting married and wants you to give a toast.",
		MinAge = 18, MaxAge = 60, Weight = 0.2,
		Target = { Type = { "Friend" } },
		Options = {
			{ Text = "Give a heartfelt toast", Chance = 0.55, ChanceStat = "Charisma",
				Result = "Half the guests cry. {name} hugs you for a long time.", Effects = { Affection = 15, Stats = { Charisma = 8 }, Happiness = 8 },
				FailResult = "You forget the bride's name halfway through.", FailEffects = { Affection = -5, Stress = 8 } },
			{ Text = "Bring a generous gift", Result = "{name} will remember this.", Effects = { Money = -150, Affection = 12 } },
			{ Text = "Make an excuse", Result = "{name} notices your empty seat.", Effects = { Affection = -10 } },
		},
	},

	village_dispute = {
		Title = "The Well Dispute",
		Text = "Two families are about to come to blows over who owns the village well. Everyone looks at you.",
		MinAge = 25, MaxAge = 90, Weight = 0.15,
		Options = {
			{ Text = "Judge fairly", Chance = 0.5, ChanceStat = "Intelligence",
				Result = "Both families grumble, which means it was fair.", Effects = { Stats = { Intelligence = 6, Charisma = 6 }, Alignment = 5 },
				FailResult = "Both families now hate you.", FailEffects = { Stress = 8, Happiness = -5 } },
			{ Text = "Side with the richer family", Result = "They send you a fat pig. The poor family spits as you pass.", Effects = { Money = 200, Alignment = -5 } },
			{ Text = "Dig a second well", Requires = { MinMoney = 300 },
				Result = "Problem solved forever. A plaque bears your name.", Effects = { Money = -300, Alignment = 8, Karma = 3, Happiness = 8 } },
		},
	},

	parent_advice = {
		Title = "A Parent's Advice",
		Text = "{name} sits you down. \"I am getting old. There are things I want you to know.\"",
		MinAge = 25, MaxAge = 55, Weight = 0.2,
		Target = { Type = { "Mother", "Father" } },
		Options = {
			{ Text = "Listen to every word", Result = "Old wisdom, plainly given. You carry it for life.", Effects = { Affection = 12, Stats = { Intelligence = 8 }, Stress = -6 } },
			{ Text = "Ask about the family's past", Result = "{name} tells you of an ancestor who once walked with immortals.", Effects = { Affection = 8, Stats = { QiControl = 6 }, Personality = { Curiosity = 3 } } },
			{ Text = "Say you are too busy", Result = "{name} nods quietly and never brings it up again.", Effects = { Affection = -12 } },
		},
	},

	retreat_mountain = {
		Title = "A Mountain Retreat",
		Text = "Life in town grows loud. A hermitage high on the mountain offers a season of silence.",
		MinAge = 20, MaxAge = 200, Weight = 0.12, Repeatable = true, Cooldown = 12,
		Options = {
			{ Text = "Go into seclusion", Result = "Months of stillness. Your Qi grows deep and calm.", Effects = { Qi = 0.25, Stats = { QiControl = 10 }, Stress = -15, Money = -50 } },
			{ Text = "Work as the hermitage cook", Result = "You feed the monks and they feed your mind.", Effects = { Stats = { Intelligence = 6, Vitality = 4 }, Stress = -8 } },
			{ Text = "Stay in town", Result = "The noise continues.", Effects = { Stress = 3 } },
		},
	},

	alchemy_accident = {
		Title = "A Cauldron Explodes",
		Text = "A wandering alchemist lets you watch him refine a pill. The cauldron starts rattling.",
		MinAge = 16, MaxAge = 200, Weight = 0.12, Repeatable = true, Cooldown = 8,
		Options = {
			{ Text = "Pour in cold water", Chance = 0.45, ChanceStat = "Intelligence",
				Result = "It settles. He gives you one of the pills in gratitude.", Effects = { Items = { focus_tonic = 1 }, Stats = { Intelligence = 6 } },
				FailResult = "The steam scalds you both.", FailEffects = { Health = -15 } },
			{ Text = "Stabilise it with your Qi", Requires = { MinRealm = 2 },
				Result = "Your Qi wraps the cauldron like a hand. Perfect pills.", Effects = { Items = { elixir_of_prodigy = 1 }, Stats = { QiControl = 10 } } },
			{ Text = "Dive for cover", Result = "Smart. The alchemist loses his eyebrows.", Effects = { Personality = { Caution = 3 } } },
		},
	},

	heavenly_omen_sky = {
		Title = "Lights in the Night Sky",
		Text = "A ribbon of coloured light splits the sky. Old folk say a treasure has fallen in the hills.",
		MinAge = 14, MaxAge = 300, Weight = 0.1, Repeatable = true, Cooldown = 15,
		Options = {
			{ Text = "Race to the hills", Chance = 0.35, ChanceStat = "Luck",
				Result = "You find a still-warm crystal in a fresh crater.", Effects = { Items = { magic_crystal = 1 }, Qi = 0.2, Happiness = 10 },
				FailResult = "A dozen cultivators got there first. You get mud.", FailEffects = { Stress = 5 } },
			{ Text = "Meditate under the light", Result = "Heaven's light washes through your meridians.", Effects = { Qi = 0.1, Stats = { QiControl = 6 } } },
			{ Text = "Go back to sleep", Result = "Probably just swamp gas.", Effects = { Stress = -2 } },
		},
	},

	sect_rivalry = {
		Title = "Two Sects, One Road",
		Text = "Disciples of two rival sects block the road, swords half drawn. Neither will step aside.",
		MinAge = 16, MaxAge = 200, Weight = 0.12, Repeatable = true, Cooldown = 10,
		Requires = { MinRealm = 2 },
		Options = {
			{ Text = "Step between them", Chance = 0.45, ChanceStat = "Charisma",
				Result = "Both sides lower their blades. Both sects hear your name.", Effects = { Stats = { Charisma = 10 }, Alignment = 5 },
				FailResult = "Both sides attack you instead.", FailEffects = { Health = -20, Counters = { Fights = 1 } } },
			{ Text = "Take the stronger side", Chance = 0.55, ChanceStat = "Strength",
				Result = "Victory. The winning sect owes you a favour.", Effects = { Counters = { Fights = 1 }, Stats = { Strength = 8 }, Money = 150 },
				FailResult = "You picked wrong.", FailEffects = { Health = -18 } },
			{ Text = "Take the long way round", Result = "Three extra days, zero extra wounds.", Effects = {} },
		},
	},

	tribulation_witness = {
		Title = "Someone Else's Tribulation",
		Text = "On a distant peak, lightning falls again and again on a lone cultivator facing their tribulation.",
		MinAge = 18, MaxAge = 300, Weight = 0.08, Repeatable = true, Cooldown = 20,
		Requires = { MinRealm = 3 },
		Options = {
			{ Text = "Watch and learn", Result = "Each bolt shows you a flaw in your own foundation.", Effects = { Stats = { QiControl = 12 }, Qi = 0.15 } },
			{ Text = "Rush to help", Chance = 0.3, ChanceStat = "Vitality",
				Result = "You take a bolt meant for them. They survive, and so do you, barely.", Effects = { Health = -30, Karma = 5, Alignment = 8, Stats = { Vitality = 12 } },
				FailResult = "Heaven does not like interference.", FailEffects = { Health = -45 } },
			{ Text = "Wait to loot the ashes", Result = "They survive. They also saw you waiting.", Effects = { Alignment = -6, Karma = -2 } },
		},
	},

	disciple_request = {
		Title = "A Child at Your Door",
		Text = "A determined child named {new} kneels at your gate in the snow, begging to be your disciple.",
		MinAge = 35, MaxAge = 300, Weight = 0.12,
		Requires = { MinRealm = 3 },
		Target = { Create = true },
		Options = {
			{ Text = "Accept them", Result = "Teaching {new} sharpens your own understanding.", Effects = { NewRelationship = { Type = "Friend", Affection = 70 }, Stats = { Intelligence = 8, QiControl = 6 }, Happiness = 10 } },
			{ Text = "Test their resolve first", Result = "Three days in the snow. {new} never moves. You accept.", Effects = { NewRelationship = { Type = "Friend", Affection = 80 }, Personality = { Patience = 4 } } },
			{ Text = "Send them away", Result = "{new} walks off into the snow. You wonder about them for years.", Effects = { Stress = 3 } },
		},
	},

	old_rival_letter = {
		Title = "A Letter from an Old Rival",
		Text = "A letter arrives from {name}. \"We are both old now. Shall we have one last bout?\"",
		MinAge = 45, MaxAge = 300, Weight = 0.15,
		Target = { Type = { "Rival" } },
		Options = {
			{ Text = "Accept the bout", Chance = 0.5, ChanceStat = "Strength",
				Result = "You win, then share wine until dawn. {name} becomes a friend.", Effects = { TargetBecomes = "Friend", Affection = 30, Counters = { Fights = 1 }, Happiness = 10 },
				FailResult = "{name} wins and laughs. You laugh too. It is enough.", FailEffects = { Affection = 20, Health = -10, Happiness = 6 } },
			{ Text = "Invite them to tea instead", Result = "Old grudges dissolve in green tea.", Effects = { TargetBecomes = "Friend", Affection = 25, Stress = -6 } },
			{ Text = "Burn the letter", Result = "Some fires never go out.", Effects = { Affection = -10 } },
		},
	},

	elder_garden = {
		Title = "The Garden in the Evening",
		Text = "Your knees ache but your plum trees are blooming. A neighbour's grandchild watches you prune.",
		MinAge = 60, MaxAge = 300, Weight = 0.2,
		Options = {
			{ Text = "Teach the child to prune", Result = "Small hands, careful snips. You smile all afternoon.", Effects = { Happiness = 10, Alignment = 3, Stress = -6 } },
			{ Text = "Meditate under the blossoms", Result = "Petals land on your shoulders. Time slows.", Effects = { Qi = 0.1, Lifespan = 1, Stress = -8 } },
			{ Text = "Sell the plums at market", Result = "Sweet fruit, sweet profit.", Effects = { Money = 120 } },
		},
	},

	memoir_request = {
		Title = "Write Your Memoir",
		Text = "A young scholar asks to record the story of your life for the provincial archive.",
		MinAge = 60, MaxAge = 300, Weight = 0.15,
		Options = {
			{ Text = "Tell the whole truth", Result = "It is not always flattering. It is always yours.", Effects = { Personality = { Honesty = 4 }, Alignment = 3, Happiness = 6 } },
			{ Text = "Make yourself a hero", Chance = 0.5, ChanceStat = "Charisma",
				Result = "Your memoir becomes a favourite of tavern storytellers.", Effects = { Stats = { Charisma = 8 }, Money = 200 },
				FailResult = "An old acquaintance publicly corrects every page.", FailEffects = { Happiness = -8, Stress = 6 } },
			{ Text = "Decline politely", Result = "Some stories belong to the wind.", Effects = { Stress = -3 } },
		},
	},

	last_journey = {
		Title = "One Last Journey",
		Text = "You have always wanted to see the sea. Your legs will not carry you many more miles.",
		MinAge = 70, MaxAge = 300, Weight = 0.15,
		Options = {
			{ Text = "Go now", Chance = 0.6, ChanceStat = "Vitality",
				Result = "You stand on the shore and weep at its size.", Effects = { Happiness = 20, Stress = -15, Money = -100 },
				FailResult = "You fall ill halfway and must turn back.", FailEffects = { Health = -15, Happiness = -6 } },
			{ Text = "Ask a grandchild to take you", Result = "The sea and good company. A perfect week.", Effects = { Happiness = 15, Money = -60 } },
			{ Text = "Paint the sea instead", Result = "You have never seen it, but your painting feels true.", Effects = { Stats = { Intelligence = 4 }, Happiness = 6 } },
		},
	},
}

return YearlyEventsConfig
