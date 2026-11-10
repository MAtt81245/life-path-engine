-- Character (2.0): upbringing, Hero / Neutral / Villain path, parents' genetics, Trait
-- Fusion, hidden talents and personality sliders (Configs/CharacterConfig,
-- Modules/CharacterSystem). The "Character" tab.
local Skills = require(script.Parent:WaitForChild("Skills"))

return {
	Id = "Character",
	Name = "Character",
	Description = "Who you are: upbringing, genetics, fused traits, hidden talents and personality.",
	Optional = true,
	EffectKeys = { "Personality" },
	Buffs = Skills.CombatBuffs, -- personality thresholds use the combat buff keys
	Tab = { Label = "Character", Order = 15, Icon = "🧭" },
	Requirements = {
		-- Personality = { Kindness = 50 } (>= 50) or { Kindness = -50 } (<= -50)
		Personality = function(view, need)
			local sliders = view.Modules and view.Modules.Character and view.Modules.Character.Personality or {}
			local met, parts = true, {}
			for slider, value in need do
				local current = sliders[slider] or 0
				if (value >= 0 and current < value) or (value < 0 and current > value) then
					met = false
				end
				table.insert(parts, ("%s %s%d"):format(slider, if value >= 0 then "≥" else "≤", value))
			end
			return met, table.concat(parts, ", ")
		end,
	},
}
