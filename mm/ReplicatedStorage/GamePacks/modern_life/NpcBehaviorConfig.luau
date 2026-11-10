-- Modern Life: the people around you work modern jobs; behavior rules are inherited.
local Content = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Content"))

return Content.Extend("NpcBehaviorConfig", script.Parent, function(npc)
	npc.Occupations = { "Nurse", "Software Developer", "Teacher", "Barista", "Engineer", "Graphic Designer", "Accountant", "Delivery Driver", "Chef", "Real Estate Agent" }
end)
