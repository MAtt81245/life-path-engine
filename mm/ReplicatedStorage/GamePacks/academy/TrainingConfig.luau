-- Academy: Quirk training instead of weapons and Qi. Same yearly slot rules as the base.
local TrainingConfig = {}

TrainingConfig.BaseActionSlots = 4
TrainingConfig.MaxActionSlots = 6
TrainingConfig.DefaultMaxPerYear = 2
TrainingConfig.SlotBonuses = {
	{ Label = "Academy years", MinAge = 15, MaxAge = 22, Slots = 1 },
}

TrainingConfig.ProficiencyOrder = { "Quirk", "Combat", "Rescue" }
TrainingConfig.Proficiencies = {
	Quirk = { Name = "Quirk Control", Color = Color3.fromRGB(255, 190, 80) },
	Combat = { Name = "Hand-to-Hand", Color = Color3.fromRGB(240, 110, 100) },
	Rescue = { Name = "Rescue Ops", Color = Color3.fromRGB(120, 230, 150) },
}

TrainingConfig.Actions = {
	{ Id = "QuirkDrills", Name = "Quirk Drills", Description = "Push your Quirk to its limit.", MinAge = 5,
		Proficiency = "Quirk", ProficiencyXp = 16, StatXp = { Power = 12, Technique = 6 }, Health = -3, Stress = 4 },
	{ Id = "Sparring", Name = "Sparring", Description = "Trade blows with classmates.", MinAge = 8,
		Proficiency = "Combat", ProficiencyXp = 16, StatXp = { Speed = 10, Spirit = 4 }, Health = -4, Stress = 3 },
	{ Id = "RescueTraining", Name = "Rescue Training", Description = "Evacuation and first-aid drills.", MinAge = 10,
		Proficiency = "Rescue", ProficiencyXp = 14, StatXp = { Spirit = 10 }, Stress = 2 },
	{ Id = "StudyTactics", Name = "Study Tactics", Description = "Analyze pro hero battles.", MinAge = 6,
		StatXp = { Intellect = 14 }, Stress = 2, Knowledge = 1 },
	{ Id = "HangOut", Name = "Hang Out", Description = "Lunch with classmates.", MinAge = 4, MaxPerYear = 1,
		StatXp = { Charm = 12 }, Happiness = 4, MeetChance = 0.35 },
	{ Id = "Rest", Name = "Rest", Description = "Sleep in and recover.", MinAge = 0, MaxPerYear = 1,
		Stress = -15, Happiness = 6, Health = 4 },
}

TrainingConfig.ById = {}
for _, action in TrainingConfig.Actions do
	action.Page = action.Page or "Training"
	action.Slots = action.Slots or 1
	TrainingConfig.ById[action.Id] = action
end

return TrainingConfig
