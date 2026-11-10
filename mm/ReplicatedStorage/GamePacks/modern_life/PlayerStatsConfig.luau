-- Modern Life: Qi Control becomes Focus (same stat key, so all content still works).
local Content = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Content"))

return Content.Extend("PlayerStatsConfig", script.Parent, function(stats)
	local focus = stats.Stats.QiControl
	focus.Name = "Focus"
	focus.Short = "FOC"
	focus.Description = "Concentration for study, work and practice."
	focus.Describe = function(level: number): string
		return ("Concentration level %d"):format(level)
	end
end)
