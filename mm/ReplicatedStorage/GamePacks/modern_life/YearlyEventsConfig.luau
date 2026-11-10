-- Modern Life: inherits every everyday event, rewrites one and adds modern ones.
local Content = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Content"))

return Content.Extend("YearlyEventsConfig", script.Parent, function(config)
	local events = config.Events

	-- The hidden cultivation manual becomes a hidden self-help classic.
	local manual = events.library_manual
	manual.Title = "The Forgotten Classic"
	manual.Text = "Behind a loose shelf in the library you find a worn copy of a famous book on mastering your mind."
	manual.Options[1] = { Text = "Read it cover to cover", Result = "Its lessons on focus stay with you for life.", Effects = { Stats = { QiControl = 25 }, Stress = -10 } }

	events.first_phone = {
		Title = "Your First Smartphone",
		Text = "For your 12th birthday your parents hand you a brand-new smartphone.",
		MinAge = 12, MaxAge = 12, Weight = 1,
		Options = {
			{ Text = "Games and social media", Result = "You know every trend. Homework suffers.", Effects = { Happiness = 10, Stats = { Charisma = 10 }, Performance = -6 } },
			{ Text = "Coding tutorials", Result = "You build your first tiny app.", Effects = { Stats = { Intelligence = 12, QiControl = 8 }, Proficiency = { QiArts = 15 } } },
			{ Text = "Keep it for emergencies", Result = "Calm, present and slightly out of the loop.", Effects = { Stress = -6, Stats = { QiControl = 6 } } },
		},
	}

	events.career_fair = {
		Title = "The Career Fair",
		Text = "Dozens of companies fill the convention center, each hunting for new talent.",
		MinAge = 18, MaxAge = 35, Weight = 0.25,
		Requires = { Employed = false },
		Options = {
			{ Text = "Take the clerk internship", Requires = { Graduated = "HighSchool", Stats = { Intelligence = 15 } },
				Result = "You start Monday, in a borrowed suit.", Effects = { Career = "Clerk", Stress = 5 } },
			{ Text = "Network with recruiters", Chance = 0.4, ChanceStat = "Charisma",
				Result = "A recruiter promises to remember you.", Effects = { Stats = { Charisma = 14 }, Happiness = 5 },
				FailResult = "Awkward small talk. You leave early.", FailEffects = { Stress = 5 } },
			{ Text = "Skip it", Result = "There will be other fairs.", Effects = { Stress = -4 } },
		},
	}
end)
