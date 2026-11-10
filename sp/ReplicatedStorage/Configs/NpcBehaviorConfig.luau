--[[
	NPC autonomy: once a year every person in the character's life picks one action
	(or stays idle) by weighted random choice. Used by Modules/NpcSystem.

	weight = Weight x personality weight x goal weight
	         x (Affection / 50 when AffectionScale)
	         x (1 + Positive * good memories + Negative * bad memories when MemoryBias)
	Idle competes with IdleWeight, so an NPC acts with probability sum / (sum + IdleWeight).

	Action fields:
		Weight, Stages = { Child/Student/Adult/Elder = true }, Categories / Types (relationship filters)
		When = { MinAge, MaxAge, MinAffection, MaxAffection, Occupation = bool, Married = bool, Away = bool }
		Effects = { Affection, PlayerHappiness, PlayerStress, PlayerMoney, SetOccupation, Retire,
		            Married, Children, Away = bool, Remove }
		TriggerEvent   -> queue that life event with this NPC as its person (event rules still apply)
		Log, Notable   -> journal line ({name}, {occupation}, {spouse}); only Notable ones are logged
		MinAffectionToLog -> skip the journal line for people you are not close to
		Memory = { Text, Mood = 1 | -1 } -> remembered by the NPC (shown on their card)
		AffectionScale, MemoryBias = { Positive, Negative }
]]

local NpcBehaviorConfig = {}

NpcBehaviorConfig.IdleWeight = 3
NpcBehaviorConfig.MaxJournalEntriesPerYear = 3
NpcBehaviorConfig.MaxTriggeredEventsPerYear = 1

-- Life stages by age (first stage whose MaxAge is >= the NPC's age).
NpcBehaviorConfig.Stages = {
	{ Id = "Child", MaxAge = 5 },
	{ Id = "Student", MaxAge = 17 },
	{ Id = "Adult", MaxAge = 64 },
	{ Id = "Elder", MaxAge = math.huge },
}

NpcBehaviorConfig.Occupations = { "Office Worker", "Teacher", "Nurse", "Doctor", "Police Officer", "Ramen Cook", "Shrine Keeper", "Store Clerk", "Dojo Instructor", "Shop Owner",
	"Taxi Driver", "Ghost Tour Guide", "Bento Shop Cook", "Arcade Owner", "Fisherman", "Florist", "Train Conductor", "Librarian", "Construction Worker", "Shrine Maiden",
}

NpcBehaviorConfig.Personalities = {
	{ Id = "Kind", Name = "Kind", Weights = { Visit = 1.5, Gift = 1.8, Sabotage = 0.2, AskFavor = 0.7 } },
	{ Id = "Ambitious", Name = "Ambitious", Weights = { Promotion = 2, MoveAway = 1.4, Visit = 0.7 } },
	{ Id = "Adventurous", Name = "Adventurous", Weights = { MoveAway = 1.8, ReturnHome = 0.6, Marry = 0.7 } },
	{ Id = "Homebody", Name = "Homebody", Weights = { MoveAway = 0.3, Marry = 1.4, HaveChild = 1.6, Visit = 1.3 } },
	{ Id = "Scheming", Name = "Scheming", Weights = { Sabotage = 2.2, AskFavor = 1.6, Gift = 0.4 } },
	{ Id = "Loyal", Name = "Loyal", Weights = { Visit = 1.4, Gift = 1.3, Sabotage = 0.1, Drift = 0.3 } },
	-- Content expansion (2026-11-02): 6 more personalities.
	{ Id = "Cheerful", Name = "Cheerful", Weights = { Visit = 1.3, SendLetter = 1.6, Celebrate = 2, Sabotage = 0.3 } },
	{ Id = "Greedy", Name = "Greedy", Weights = { BorrowMoney = 2.2, Promotion = 1.4, Gift = 0.3, Gamble = 1.8 } },
	{ Id = "Scholarly", Name = "Scholarly", Weights = { StudyAbroad = 2, ShareKnowledge = 2, Gamble = 0.3 } },
	{ Id = "Pious", Name = "Pious", Weights = { Pilgrimage = 2.2, PrayForYou = 2, Sabotage = 0.2 } },
	{ Id = "Hotheaded", Name = "Hotheaded", Weights = { BrawlInTown = 2.2, RivalChallenge = 1.5, Visit = 0.8 } },
	{ Id = "Secretive", Name = "Secretive", Weights = { MoveAway = 1.3, SendLetter = 0.4, Visit = 0.6, KeepSecret = 2 } },
}

-- Personal goals; a goal is replaced once its CompletedBy action happens.
NpcBehaviorConfig.Goals = {
	{ Id = "Family", Name = "Start a family", Weights = { Marry = 2.5, HaveChild = 2.5 }, CompletedBy = "HaveChild" },
	{ Id = "Fortune", Name = "Make a fortune", Weights = { Promotion = 2.5, MoveAway = 1.3 }, CompletedBy = "Promotion" },
	{ Id = "Wanderlust", Name = "See the world", Weights = { MoveAway = 2 }, CompletedBy = "MoveAway" },
	{ Id = "Bond", Name = "Stay close to you", Weights = { Visit = 1.8, Gift = 1.8, Drift = 0.2 }, CompletedBy = "Gift",
		Categories = { Family = true, Friend = true, Partner = true } },
	{ Id = "Revenge", Name = "Get even with you", Weights = { Sabotage = 2, RivalChallenge = 2 }, CompletedBy = "RivalChallenge",
		Categories = { Rival = true } },
	-- Content expansion (2026-11-02): 5 more goals.
	{ Id = "Learning", Name = "Master their zanpakuto", Weights = { StudyAbroad = 2.5, Promotion = 1.3 }, CompletedBy = "StudyAbroad" },
	{ Id = "Faith", Name = "Find inner peace", Weights = { Pilgrimage = 2.5, PrayForYou = 1.5 }, CompletedBy = "Pilgrimage" },
	{ Id = "Riches", Name = "Strike it rich", Weights = { Gamble = 2, BorrowMoney = 1.4 }, CompletedBy = "Gamble" },
	{ Id = "Joy", Name = "Enjoy every day", Weights = { Celebrate = 2.5, Visit = 1.2 }, CompletedBy = "Celebrate",
		Categories = { Family = true, Friend = true, Partner = true } },
	{ Id = "Glory", Name = "Prove themselves", Weights = { BrawlInTown = 2, Promotion = 1.5 }, CompletedBy = "BrawlInTown" },
}

-- Your own children grow up, marry and have children too (your grandchildren, DynastySystem).
local NOT_PARENTS = { Sibling = true, Friend = true, Rival = true, Child = true }

NpcBehaviorConfig.Actions = {
	-- Their own lives
	{ Id = "StartCareer", Weight = 6, Stages = { Adult = true }, When = { Occupation = false },
		Effects = { SetOccupation = true }, Log = "{name} started working as a {occupation}." },
	{ Id = "Promotion", Weight = 0.3, Stages = { Adult = true }, When = { Occupation = true },
		Effects = { PlayerHappiness = 2 }, Log = "{name} was promoted at work.", Notable = true, MinAffectionToLog = 50 },
	{ Id = "Marry", Weight = 0.35, Types = NOT_PARENTS, When = { MinAge = 20, Married = false },
		Effects = { Married = true }, Log = "{name} married {spouse}.", Notable = true, MinAffectionToLog = 30 },
	{ Id = "HaveChild", Weight = 0.35, Types = NOT_PARENTS, When = { Married = true, MinAge = 20, MaxAge = 45 },
		Effects = { Children = 1 }, Log = "{name} welcomed a baby.", Notable = true, MinAffectionToLog = 40 },
	{ Id = "MoveAway", Weight = 0.06, Types = NOT_PARENTS, When = { MinAge = 18, Away = false },
		Effects = { Away = true, Affection = -5 }, Log = "{name} moved to a faraway city.", Notable = true, MinAffectionToLog = 35,
		Memory = { Text = "Moved away", Mood = 0 } },
	{ Id = "ReturnHome", Weight = 0.45, When = { Away = true },
		Effects = { Away = false, Affection = 4 }, Log = "{name} moved back to town.", Notable = true, MinAffectionToLog = 35 },
	{ Id = "Retire", Weight = 6, Stages = { Elder = true }, When = { Occupation = true },
		Effects = { Retire = true }, Log = "{name} retired." },

	-- Toward you
	{ Id = "Visit", Weight = 0.7, Categories = { Family = true, Friend = true, Partner = true }, When = { Away = false, MinAffection = 50 },
		AffectionScale = true, Effects = { Affection = 3, PlayerHappiness = 2 } },
	{ Id = "Gift", Weight = 0.25, Categories = { Family = true, Friend = true, Partner = true }, When = { MinAffection = 70 },
		AffectionScale = true, MemoryBias = { Positive = 0.3 },
		Effects = { PlayerMoney = 150, Affection = 2 }, Log = "{name} sent you a gift (Kan 150).", Notable = true,
		Memory = { Text = "Sent you a gift", Mood = 1 } },
	{ Id = "AskFavor", Weight = 0.3, Categories = { Friend = true }, When = { MinAffection = 45, MinAge = 14, Away = false },
		TriggerEvent = "friend_in_need" },
	{ Id = "Sabotage", Weight = 0.5, Categories = { Rival = true }, When = { Away = false, MinAge = 10 },
		MemoryBias = { Negative = 0.5 },
		Effects = { PlayerStress = 8, PlayerHappiness = -5, Affection = -3 }, Log = "{name} spread nasty rumors about you.", Notable = true,
		Memory = { Text = "Spread rumors about you", Mood = -1 } },
	{ Id = "RivalChallenge", Weight = 0.25, Categories = { Rival = true }, When = { Away = false, MinAge = 10 },
		TriggerEvent = "rival_challenge" },
	{ Id = "Drift", Weight = 0.4, Categories = { Friend = true }, When = { MaxAffection = 20 },
		Effects = { Remove = true }, Log = "You and {name} drifted apart for good.", Notable = true },
	-- Content expansion (2026-11-02): 13 more actions.
	{ Id = "StudyAbroad", Weight = 0.08, Stages = { Student = true, Adult = true }, Types = NOT_PARENTS, When = { MinAge = 16, MaxAge = 40, Away = false },
		Effects = { Away = true }, Log = "{name} left to study at the Shin'o Academy.", Notable = true, MinAffectionToLog = 40,
		Memory = { Text = "Went away to study", Mood = 0 } },
	{ Id = "Pilgrimage", Weight = 0.06, Stages = { Adult = true, Elder = true }, When = { Away = false },
		Effects = { Affection = 2 }, Log = "{name} returned from a Konso pilgrimage through the districts.", Notable = true, MinAffectionToLog = 45 },
	{ Id = "Gamble", Weight = 0.1, Stages = { Adult = true, Elder = true }, When = { MinAge = 18 },
		Effects = { PlayerHappiness = -1 }, Log = "{name} lost a small fortune at the pachinko parlor.", Notable = true, MinAffectionToLog = 55 },
	{ Id = "Celebrate", Weight = 0.3, Categories = { Family = true, Friend = true, Partner = true }, When = { Away = false, MinAffection = 55 },
		AffectionScale = true, Effects = { Affection = 3, PlayerHappiness = 3 }, Log = "{name} threw a little feast and invited you.", Notable = true, MinAffectionToLog = 55,
		Memory = { Text = "Feasted with you", Mood = 1 } },
	{ Id = "SendLetter", Weight = 0.5, Categories = { Family = true, Friend = true, Partner = true }, When = { Away = true, MinAffection = 40 },
		AffectionScale = true, Effects = { Affection = 3, PlayerHappiness = 2 }, Log = "A letter arrived from {name}, far away.", Notable = true, MinAffectionToLog = 40 },
	{ Id = "BorrowMoney", Weight = 0.15, Categories = { Family = true, Friend = true }, When = { MinAge = 18, MinAffection = 40, Away = false },
		Effects = { PlayerMoney = -100, Affection = 4 }, Log = "{name} borrowed $100 from you. \"I'll pay you back, promise.\"", Notable = true,
		Memory = { Text = "Borrowed money from you", Mood = 1 } },
	{ Id = "RepayDebt", Weight = 0.12, Categories = { Family = true, Friend = true }, When = { MinAge = 18, MinAffection = 50 },
		MemoryBias = { Positive = 0.4 }, Effects = { PlayerMoney = 120, Affection = 2 }, Log = "{name} paid you back, with a little extra.", Notable = true },
	{ Id = "ShareKnowledge", Weight = 0.2, Categories = { Family = true, Friend = true, Partner = true }, When = { MinAffection = 50, MinAge = 14, Away = false },
		AffectionScale = true, Effects = { Affection = 2, PlayerStress = -2 }, Log = "{name} spent an evening teaching you something new.", Notable = true, MinAffectionToLog = 60,
		Memory = { Text = "Taught you something", Mood = 1 } },
	{ Id = "PrayForYou", Weight = 0.2, Categories = { Family = true, Partner = true }, When = { MinAffection = 60 },
		AffectionScale = true, Effects = { PlayerStress = -3 }, Log = "{name} lit incense at the shrine for your safety.", Notable = true, MinAffectionToLog = 60 },
	{ Id = "BrawlInTown", Weight = 0.1, Stages = { Student = true, Adult = true }, When = { MinAge = 14, Away = false },
		Effects = { Affection = -1 }, Log = "{name} got into a brawl in the market square.", Notable = true, MinAffectionToLog = 50 },
	{ Id = "KeepSecret", Weight = 0.15, Categories = { Friend = true, Partner = true }, When = { MinAffection = 65 },
		Effects = { Affection = 3 }, Memory = { Text = "Kept your secret", Mood = 1 } },
	{ Id = "Gossip", Weight = 0.25, Categories = { Rival = true }, When = { Away = false, MinAge = 12 },
		MemoryBias = { Negative = 0.4 }, Effects = { PlayerHappiness = -3, Affection = -2 }, Log = "{name} mocked you in front of the whole tea house.", Notable = true,
		Memory = { Text = "Mocked you in public", Mood = -1 } },
	{ Id = "GrudgingRespect", Weight = 0.1, Categories = { Rival = true }, When = { MinAffection = 35 },
		Effects = { Affection = 5 }, Log = "{name} admitted, through gritted teeth, that you are not bad.", Notable = true,
		Memory = { Text = "Respected you, grudgingly", Mood = 1 } },
}

return NpcBehaviorConfig
