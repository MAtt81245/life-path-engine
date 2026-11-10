--[[
	Progressive disclosure: the interface unfolds as the character grows up.
	Tabs: minimum age before a tab button appears (keys = UIController tab keys or an
	engine module id; unlisted tabs are always visible).
	StripFlag / StripAge: the cultivation strip (Qi bar, Breakthrough) appears once the
	flag is set (Spirit Root awakening) or at StripAge, whichever comes first.
	Milestones: toast + Chronicle entry on that birthday (Modules/MilestoneSystem).
	Action ages live on each action (TrainingConfig MinAge / MaxAge).
]]

local ProgressionGatesConfig = {}

ProgressionGatesConfig.Tabs = {
	Social = 4, Study = 4, Inventory = 7, Masters = 12, Progression = 12, World = 12, Fame = 12,
	Skills = 3, Arcana = 5, -- 2.0 modules (Character is visible from birth)
}

ProgressionGatesConfig.StripFlag = "SpiritRoot"
ProgressionGatesConfig.StripAge = 7

ProgressionGatesConfig.Milestones = {
	{ Age = 4, Text = "You can read and make childhood friends. Study and Bonds unlocked." },
	{ Age = 6, Text = "You keep seeing people nobody else can see..." },
	{ Age = 7, Text = "Physical training, the local market (Bag) and school grades unlocked." },
	{ Age = 12, Text = "Kendo, Kido, mentors, the world map and mastery trees unlocked." },
	{ Age = 16, Text = "You come of age: careers, romance, rival duels and politics are open to you." },
}

return ProgressionGatesConfig
