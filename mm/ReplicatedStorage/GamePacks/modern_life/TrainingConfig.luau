-- Modern Life: weapon and Qi practice become clubs and programming.
local Content = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Content"))

return Content.Extend("TrainingConfig", script.Parent, function(training)
	training.Proficiencies.Sword.Name = "Fencing"
	training.Proficiencies.Spear.Name = "Martial Arts"
	training.Proficiencies.QiArts.Name = "Programming"

	local changes = {
		PracticeSword = { Name = "Fencing Club", Description = "Footwork, parries and lunges." },
		PracticeSpear = { Name = "Martial Arts Class", Description = "Kicks, throws and discipline." },
		PracticeQiArts = { Name = "Learn Programming", Description = "Build apps late into the night.", StatXp = { QiControl = 4, Intelligence = 6 } },
	}
	for _, action in training.Actions do
		for key, value in changes[action.Id] or {} do
			action[key] = value
		end
	end
end)
