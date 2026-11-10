--[[
	BattleConfig (Soul Path): turn-based Hollow hunts (Modules/BattleSystem, UIController/BattleModal).

	Enemies   in unlock order. Region = nil fights anywhere, otherwise only while you
	          live in that WorldRegionsConfig region. Unlock = the enemy you must beat
	          first. Boss = the first kill raises a statue in the World Chronicle. The list only ever shows enemies you can fight (or beat already)
	          and the single next target, never a wall of locked fights.
	Guard     blocks Block of the next hit and restores ManaRestore of max mana.
	Flee      chance = Base + Agility x PerAgility + FleeBonus buff (max Max).
	Chant     a spell that is not chantless asks for Length keys from Keys within
	          Seconds; typed right it hits x Bonus (chantless spells always do).
	Signature once per battle: your best hit x Mult, named after your birth trait.
	Injury    battle damage becomes real health loss x Share, never below Floor of max.
]]

local BattleConfig = {}

BattleConfig.StartCost = 1 -- actions
BattleConfig.MinAge = 8
BattleConfig.Guard = { Block = 0.6, ManaRestore = 0.12 }
BattleConfig.Flee = { Base = 0.45, PerAgility = 0.004, Max = 0.9 }
BattleConfig.Chant = { Keys = { "Z", "X", "C", "V" }, Length = 3, Seconds = 2.5, Bonus = 1.35 }
BattleConfig.Signature = { Mult = 2.5 }
BattleConfig.Injury = { Share = 0.4, Floor = 0.3 }
BattleConfig.CritMult = 1.5

BattleConfig.Enemies = {
	{ Id = "wild_boar", Name = "Lesser Hollow", Icon = "👹", HP = 40, Power = 6, Reward = { Money = { 20, 50 } } },
	{ Id = "bandit_scout", Name = "Rogue Plus Spirit", Icon = "👻", HP = 60, Power = 9, Unlock = "wild_boar", Reward = { Money = { 60, 120 } } },
	{ Id = "slum_enforcer", Name = "Cavern Training Puppet", Icon = "🪆", Region = "crimson", HP = 80, Power = 11, Unlock = "bandit_scout", Reward = { Money = { 120, 220 } } },
	{ Id = "bamboo_viper", Name = "Serpent Hollow", Icon = "🐍", Region = "qinghe", HP = 75, Power = 12, Unlock = "bandit_scout", Reward = { Money = { 90, 180 }, StatXp = { Agility = 10 } } },
	{ Id = "palace_duelist", Name = "Eleventh Division Brawler", Icon = "🤺", Region = "capital", HP = 110, Power = 15, Unlock = "bandit_scout", Reward = { Money = { 250, 450 }, Fame = 5 } },
	{ Id = "rogue_mage", Name = "Rogue Kido Master", Icon = "🧙", HP = 120, Power = 17, Unlock = "bandit_scout", Reward = { Money = { 200, 400 }, SkillXp = { Magic = 15 } } },
	{ Id = "marsh_ghoul", Name = "Rukongai Hollow Pack", Icon = "💀", Region = "marsh", HP = 150, Power = 20, Unlock = "rogue_mage", Reward = { Money = { 300, 600 } } },
	{ Id = "snow_ape", Name = "Escaped Training Hollow", Icon = "🦍", Region = "kunlun", HP = 180, Power = 22, Unlock = "rogue_mage", Reward = { Money = { 350, 650 }, StatXp = { Strength = 15 } } },
	{ Id = "star_golem", Name = "Sokyoku Guardian Construct", Icon = "🗿", Region = "ruins", HP = 260, Power = 28, Unlock = "rogue_mage", Boss = true, Reward = { Money = { 600, 1000 }, Fame = 10 } },
	{ Id = "wyvern", Name = "Menos Grande", Icon = "🌑", HP = 320, Power = 32, Unlock = "rogue_mage", Boss = true, Reward = { Money = { 800, 1500 }, Fame = 20 } },
	{ Id = "dragon", Name = "Vasto Lorde", Icon = "☠", HP = 700, Power = 55, Unlock = "wyvern", Boss = true, Reward = { Money = { 4000, 7000 }, Fame = 80 } },
	-- Content expansion (2026-11-02): 11 more enemies.
	{ Id = "stray_wolf", Name = "Stray Hollow Hound", Icon = "🐺", HP = 50, Power = 7, Unlock = "wild_boar", Reward = { Money = { 30, 70 }, StatXp = { Agility = 6 } } },
	{ Id = "drunk_brawler", Name = "Rogue Training Puppet", Icon = "🍶", Region = "crimson", HP = 70, Power = 10, Unlock = "stray_wolf", Reward = { Money = { 80, 150 }, StatXp = { Strength = 8 } } },
	{ Id = "lotus_assassin", Name = "Disguised Hollow Stalker", Icon = "🎭", Region = "qinghe", HP = 100, Power = 15, Unlock = "bamboo_viper", Reward = { Money = { 180, 320 }, SkillXp = { Stealth = 10 } } },
	{ Id = "imperial_guard", Name = "Gotei Gate Guardian", Icon = "🛡", Region = "capital", HP = 140, Power = 18, Unlock = "palace_duelist", Reward = { Money = { 350, 600 }, Fame = 8 } },
	{ Id = "rogue_cultivator", Name = "Rogue Shinigami", Icon = "⚔", HP = 160, Power = 19, Unlock = "rogue_mage", Reward = { Money = { 300, 550 }, StatXp = { QiControl = 12 } } },
	{ Id = "bog_witch", Name = "Rukongai Kido Witch", Icon = "🧪", Region = "marsh", HP = 190, Power = 23, Unlock = "marsh_ghoul", Reward = { Money = { 400, 700 }, SkillXp = { Magic = 18 } } },
	{ Id = "frost_yeti", Name = "Escaped Experiment Hollow", Icon = "❄", Region = "kunlun", HP = 230, Power = 25, Unlock = "snow_ape", Reward = { Money = { 450, 800 }, StatXp = { Vitality = 15 } } },
	{ Id = "ruin_wraith", Name = "Sokyoku Wraith", Icon = "👻", Region = "ruins", HP = 210, Power = 26, Unlock = "rogue_mage", Reward = { Money = { 450, 750 }, SkillXp = { Faith = 12 } } },
	{ Id = "blood_lotus_elder", Name = "Traitor Lieutenant", Icon = "🩸", HP = 380, Power = 36, Unlock = "wyvern", Boss = true, Reward = { Money = { 1200, 2200 }, Fame = 30 } },
	{ Id = "nine_tailed_fox", Name = "Adjuchas Fox", Icon = "🦊", HP = 480, Power = 42, Unlock = "blood_lotus_elder", Boss = true, Reward = { Money = { 2000, 3500 }, Fame = 45 } },
	{ Id = "heavenly_demon_lord", Name = "Primordial Hollow King", Icon = "👹", HP = 1000, Power = 70, Unlock = "dragon", Boss = true, Reward = { Money = { 7000, 12000 }, Fame = 150 } },
}

BattleConfig.ById = {}
for i, enemy in BattleConfig.Enemies do
	enemy.Order = i
	BattleConfig.ById[enemy.Id] = enemy
end

-- Enemies to show for a region and a defeated set: { Enemy, State = "Beaten" | "Open" | "Next" }.
-- Only fightable or beaten enemies, plus the first locked one as the next target.
function BattleConfig.Visible(regionId: string?, defeated)
	defeated = defeated or {}
	local list, nextShown = {}, false
	for _, enemy in BattleConfig.Enemies do
		if enemy.Region == nil or enemy.Region == regionId then
			local open = enemy.Unlock == nil or defeated[enemy.Unlock] == true
			if defeated[enemy.Id] then
				table.insert(list, { Enemy = enemy, State = "Beaten" })
			elseif open then
				table.insert(list, { Enemy = enemy, State = "Open" })
			elseif not nextShown then
				nextShown = true
				table.insert(list, { Enemy = enemy, State = "Next" })
			end
		end
	end
	return list
end

function BattleConfig.CanFight(regionId: string?, defeated, enemyId: string): boolean
	for _, entry in BattleConfig.Visible(regionId, defeated) do
		if entry.Enemy.Id == enemyId then
			return entry.State ~= "Next"
		end
	end
	return false
end

return BattleConfig
