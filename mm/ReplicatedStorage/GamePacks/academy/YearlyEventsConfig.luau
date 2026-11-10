--[[
	Academy events: entrance exam, a rival, and a three-round Sports Festival built
	from FollowUp chains (prelims -> semifinal -> final), plus a delayed consequence.
	Replaces the base events entirely (they assume the base stat set).
]]

local Config = {}

Config.Events = {
	quirk_awakening = {
		Title = "Your Quirk Awakens",
		Text = "At four years old, something inside you finally clicks.",
		MinAge = 4, MaxAge = 4, Weight = 1,
		Options = {
			{ Text = "A burst of raw power", Result = "You crack the kitchen tiles.", Effects = { Stats = { Power = 12 }, Proficiency = { Quirk = 10 } } },
			{ Text = "Precise and subtle", Result = "You make a spoon float, perfectly still.", Effects = { Stats = { Technique = 12 } } },
			{ Text = "Lightning-fast reflexes", Result = "You catch a falling glass mid-air.", Effects = { Stats = { Speed = 12 } } },
		},
	},

	entrance_exam = {
		Title = "Hero Academy Entrance Exam",
		Text = "Robots, rubble and a ticking clock. Only the top forty get in.",
		MinAge = 15, MaxAge = 15, Weight = 1,
		Options = {
			{ Text = "Smash every robot", Chance = 0.45, ChanceStat = "Power",
				Result = "Top score in combat points. You're in!", Effects = { Flags = { "Academy" }, Happiness = 15, FollowUp = { Id = "rival_intro", InYears = 0 } },
				FailResult = "Not enough points. You'll train and wait.", FailEffects = { Happiness = -15, Stress = 10 } },
			{ Text = "Save the other examinees", Chance = 0.45, ChanceStat = "Spirit",
				Result = "Rescue points carry you through. You're in!", Effects = { Flags = { "Academy" }, Alignment = 10, Proficiency = { Rescue = 15 }, FollowUp = { Id = "rival_intro", InYears = 0 } },
				FailResult = "Heroic, but not enough points.", FailEffects = { Happiness = -10, Alignment = 5 } },
			{ Text = "Outthink the course", Chance = 0.45, ChanceStat = "Intellect",
				Result = "The judges love your plan. You're in!", Effects = { Flags = { "Academy" }, Stats = { Intellect = 10 }, FollowUp = { Id = "rival_intro", InYears = 0 } },
				FailResult = "The clock runs out mid-plan.", FailEffects = { Stress = 8 } },
		},
	},

	rival_intro = {
		Title = "First Day, First Rival",
		Text = "An arrogant classmate named {new} declares they will crush you.",
		ChainOnly = true,
		Target = { Create = true },
		Options = {
			{ Text = "Accept the challenge", Result = "{new} smirks. It's on.", Effects = { NewRelationship = { Type = "Rival", Affection = 20 }, Stats = { Power = 6 } } },
			{ Text = "Offer a handshake", Result = "{new} slaps your hand away, but remembers it.", Effects = { NewRelationship = { Type = "Rival", Affection = 40 }, Stats = { Charm = 6 } } },
		},
	},

	rival_challenge = {
		Title = "Training Ground Showdown",
		Text = "{name} calls you out in front of the whole class.",
		MinAge = 10, MaxAge = 120, Weight = 0.18, Repeatable = true, Cooldown = 3,
		Target = { Category = "Rival" },
		Options = {
			{ Text = "Fight", Chance = 0.4, ChanceStat = "Power",
				Result = "You win. {name} grits their teeth.", Effects = { Counters = { Fights = 1 }, Happiness = 10, Stats = { Power = 10 }, Affection = 10, Fame = 5 },
				FailResult = "{name} flattens you.", FailEffects = { Health = -18, Happiness = -10 } },
			{ Text = "Win them over", Chance = 0.3, ChanceStat = "Charm",
				Result = "{name} grudgingly admits you're not bad.", Effects = { TargetBecomes = "Friend", Affection = 30 },
				FailResult = "{name} laughs in your face.", FailEffects = { Happiness = -5 } },
			{ Text = "Walk away", Result = "Whispers follow you down the hall.", Effects = { Happiness = -6, Stress = 4 } },
		},
	},

	-- Everyday repeatable events, so every life has a steady stream of choices.
	quirk_mishap = {
		Title = "Quirk Mishap",
		Text = "Your Quirk flares up at the worst possible moment.",
		MinAge = 6, MaxAge = 60, Weight = 0.3, Repeatable = true, Cooldown = 3,
		Options = {
			{ Text = "Rein it in", Chance = 0.5, ChanceStat = "Technique",
				Result = "You hold it together. Control is improving.", Effects = { Stats = { Technique = 8 }, Proficiency = { Quirk = 6 } },
				FailResult = "It blows up in your face.", FailEffects = { Health = -8, Stress = 6 } },
			{ Text = "Let it rip somewhere safe", Result = "A crater in the training field. Worth it.", Effects = { Stats = { Power = 8 }, Stress = -6 } },
		},
	},

	city_patrol = {
		Title = "Trouble Downtown",
		Text = "A villain is robbing a store two streets away.",
		MinAge = 14, MaxAge = 70, Weight = 0.25, Repeatable = true, Cooldown = 2,
		Options = {
			{ Text = "Step in", Chance = 0.45, ChanceStat = "Speed",
				Result = "You stop them before the police arrive. Cameras catch everything.", Effects = { Stats = { Speed = 8 }, Fame = 10, Alignment = 5 },
				FailResult = "They get away and you get hurt.", FailEffects = { Health = -12 } },
			{ Text = "Call the pros and help civilians", Result = "Quiet heroism. The shop owner never forgets.", Effects = { Stats = { Spirit = 6 }, Alignment = 8 } },
			{ Text = "Not my problem", Result = "You walk on. It stays with you.", Effects = { Alignment = -6, Stress = 4 } },
		},
	},

	-- Triggered by the NPC action AskFavor (base NpcBehaviorConfig).
	friend_in_need = {
		Title = "A Classmate in Trouble",
		Text = "{name} is failing Heroics and asks you for help before the practical exam.",
		MinAge = 12, MaxAge = 30, Weight = 0.12, Repeatable = true, Cooldown = 3,
		Target = { Category = "Friend", MinAffection = 45 },
		Options = {
			{ Text = "Train with them every night", Result = "{name} passes, and so do you, with flying colors.", Effects = { Affection = 20, Stats = { Spirit = 6 }, Stress = 6 } },
			{ Text = "Lend them your notes", Result = "{name} squeaks by.", Effects = { Affection = 10, Stats = { Intellect = 4 } } },
			{ Text = "You have your own exam", Result = "{name} understands, mostly.", Effects = { Affection = -10 } },
		},
	},

	festival_prelims = {
		Title = "Sports Festival: Obstacle Race",
		Text = "The whole country is watching the academy's Sports Festival.",
		MinAge = 16, MaxAge = 18, Weight = 1, Repeatable = true, Cooldown = 1,
		Requires = { Flag = "Academy" },
		Options = {
			{ Text = "Sprint for first", Chance = 0.55, ChanceStat = "Speed",
				Result = "You qualify for the tournament!", Effects = { Stats = { Speed = 8 }, FollowUp = { Id = "festival_semifinal", InYears = 0 } },
				FailResult = "Eliminated in the first round.", FailEffects = { Happiness = -8 } },
			{ Text = "Sabotage the leaders", Chance = 0.5, ChanceStat = "Technique",
				Result = "Dirty, but you qualify.", Effects = { Alignment = -8, FollowUp = { Id = "festival_semifinal", InYears = 0 } },
				FailResult = "Caught and disqualified.", FailEffects = { Alignment = -5, Happiness = -10 } },
			{ Text = "Sit this one out", Result = "Next year, maybe.", Effects = { Stress = -5 } },
		},
	},

	festival_semifinal = {
		Title = "Sports Festival: Semifinal",
		Text = "One-on-one in the arena. Your opponent cracks their knuckles.",
		ChainOnly = true,
		Options = {
			{ Text = "Overpower them", Chance = 0.45, ChanceStat = "Power",
				Result = "A clean knockout. On to the final!", Effects = { Proficiency = { Combat = 10 }, FollowUp = { Id = "festival_final", InYears = 0 } },
				FailResult = "Knocked out of the ring.", FailEffects = { Health = -12, Happiness = -8 } },
			{ Text = "Read their Quirk", Chance = 0.45, ChanceStat = "Intellect",
				Result = "You spot the weakness. On to the final!", Effects = { Stats = { Intellect = 6 }, FollowUp = { Id = "festival_final", InYears = 0 } },
				FailResult = "Your plan falls apart.", FailEffects = { Stress = 8 } },
		},
	},

	festival_final = {
		Title = "Sports Festival: The Final",
		Text = "The stadium roars. One match between you and the title.",
		ChainOnly = true,
		Options = {
			{ Text = "Go all out", Chance = 0.4, ChanceStat = "Power",
				Result = "You win the Sports Festival! Pro agencies take notice.",
				Effects = { Counters = { TournamentWins = 1 }, Happiness = 20, Fame = 40, Delayed = { InYears = 3, Text = "A pro hero agency remembers your festival win and offers you a sidekick contract.", Effects = { Flags = { "ProHero" }, Money = 5000 } } },
				FailResult = "Second place. So close.", FailEffects = { Happiness = -5, Stats = { Spirit = 8 } } },
			{ Text = "Outlast them", Chance = 0.4, ChanceStat = "Spirit",
				Result = "Last one standing. Champion!",
				Effects = { Counters = { TournamentWins = 1 }, Happiness = 20, Fame = 40, Delayed = { InYears = 3, Text = "A pro hero agency remembers your festival win and offers you a sidekick contract.", Effects = { Flags = { "ProHero" }, Money = 5000 } } },
				FailResult = "You collapse first.", FailEffects = { Health = -15 } },
		},
	},
}

return Config
