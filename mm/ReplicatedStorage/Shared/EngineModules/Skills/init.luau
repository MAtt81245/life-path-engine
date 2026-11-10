-- Skills (2.0): 12 skills that grow with what you do (Configs/SkillsConfig,
-- Modules/SkillSystem). Owns the combat buff keys shared by Arcana, Battle and Character.
local COMBAT_BUFFS = {
	SkillXp = "nested", SkillXpMult = "mult", SwordDamageMult = "mult", MagicDamageMult = "mult", ManaCostMult = "mult",
	DamageTakenMult = "mult", GoldMult = "mult", BattleRewardMult = "mult", FleeBonus = "add",
	MaxManaMult = "mult", DodgeChance = "add", StressGainMult = "mult", -- 3.0 birth anomalies, passes
}

return {
	Id = "Skills",
	Name = "Skills",
	Description = "Twelve life skills with ranks, mastery unlocks and life-stage ceilings.",
	Optional = true,
	Buffs = COMBAT_BUFFS,
	CombatBuffs = COMBAT_BUFFS,
	Tab = { Label = "Skills", Order = 25, Icon = "📜" },
	Requirements = {
		-- MinSkill = { Swordsmanship = 15 }
		MinSkill = function(view, need)
			local levels = view.Modules and view.Modules.Skills and view.Modules.Skills.Levels or {}
			local parts = {}
			local met = true
			for skill, level in need do
				if ((levels[skill] and levels[skill].Level) or 0) < level then
					met = false
				end
				table.insert(parts, ("%s %d"):format(skill, level))
			end
			return met, table.concat(parts, ", ")
		end,
	},
}
