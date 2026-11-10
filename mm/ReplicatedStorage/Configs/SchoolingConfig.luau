--[[
	SchoolingConfig: how a child learns (Modules/SchoolingSystem, the Education tab).
	One mode at a time between MinAge and MaxAge; every year it pays Gains
	(SkillSystem.ApplyEffects keys, plus FamilyAffection) and charges Cost. A paid mode
	the family can no longer afford falls back to Default. MinMoney = wealth needed to
	pick it at all.
]]

return {
	MinAge = 4, MaxAge = 17, Default = "Village",
	Modes = {
		{ Id = "Village", Name = "Village School", Cost = 0, Description = "Free lessons with the other children.",
			Gains = { StatXp = { Intelligence = 8, Charisma = 4 }, SkillXp = { Knowledge = 4, Charisma = 2 } } },
		{ Id = "Home", Name = "Homeschooled", Cost = 0, Description = "Your parents teach you at the kitchen table.",
			Gains = { StatXp = { Intelligence = 10 }, SkillXp = { Knowledge = 4 }, FamilyAffection = 2 } },
		{ Id = "Tutor", Name = "Private Tutor", Cost = 120, MinMoney = 300, Description = "A strict scholar, one pupil: you.",
			Gains = { StatXp = { Intelligence = 18 }, SkillXp = { Knowledge = 8 } } },
		{ Id = "MageTutor", Name = "Mage Tutor", Cost = 90, Description = "Runes and mana drills (magic opens at 8).",
			Gains = { StatXp = { Mana = 6, MagicPower = 6 }, SkillXp = { Magic = 10 } } },
		{ Id = "SwordTutor", Name = "Sword Tutor", Cost = 90, Description = "Footwork and steel (sword opens at 8).",
			Gains = { StatXp = { Strength = 6, BattleAura = 6 }, SkillXp = { Swordsmanship = 10 } } },
		{ Id = "Self", Name = "Teach Yourself", Cost = 0, Description = "Library corners and stubborn curiosity.",
			Gains = { SkillXp = { Knowledge = 3, Survival = 2 }, Stress = -2 } },
	},
}
