--[[
	CombatMath: the one place damage is computed, shared by server (BattleSystem) and
	client (damage previews), so the two sides never disagree.

	The separation rule: sword damage reads only Strength, Agility, Battle Aura and the
	Swordsmanship skill; magic damage reads only Magic Power, Magic Control, the Magic
	skill, element affinity and spell rank. Mana and Magic Power never touch a blade;
	Strength never touches a spell. Missing stats (packs with other attributes) are 0.

	levels = { Stat = level }, skills = { Skill = level }, buffs = merged buffs (optional).
]]

local CombatMath = {}

CombatMath.SwordStats = { Strength = 0.6, Agility = 0.3, BattleAura = 0.8 }
CombatMath.MagicStats = { MagicPower = 0.9, MagicControl = 0.3 }
CombatMath.SkillWeight = 0.5
CombatMath.AffinityWeight = 0.3
CombatMath.RankMultipliers = { 1, 1.4, 1.9, 2.5, 3.2, 4, 5 } -- Beginner .. God

local function buff(buffs, key: string): number
	return (buffs and buffs[key]) or 1
end

function CombatMath.SwordDamage(levels, skills, buffs): number
	local damage = 6
	for stat, weight in CombatMath.SwordStats do
		damage += (levels[stat] or 0) * weight
	end
	damage += (skills and skills.Swordsmanship or 0) * CombatMath.SkillWeight
	return math.floor(damage * buff(buffs, "SwordDamageMult") + 0.5)
end

-- rank 1..7, affinity 0..100.
function CombatMath.MagicDamage(levels, skills, rank: number, affinity: number, buffs): number
	local damage = 6
	for stat, weight in CombatMath.MagicStats do
		damage += (levels[stat] or 0) * weight
	end
	damage += (skills and skills.Magic or 0) * CombatMath.SkillWeight + (affinity or 0) * CombatMath.AffinityWeight
	damage *= CombatMath.RankMultipliers[math.clamp(rank or 1, 1, #CombatMath.RankMultipliers)]
	return math.floor(damage * buff(buffs, "MagicDamageMult") + 0.5)
end

function CombatMath.MaxMana(levels, bonus: number?): number
	return 20 + (levels.Mana or 0) * 4 + (bonus or 0)
end

-- Mana cost after Magic Control (up to -40%) and cost buffs (Silent Casting, traits).
function CombatMath.ManaCost(base: number, levels, buffs): number
	local control = 1 - math.min(0.4, (levels.MagicControl or 0) * 0.005)
	return math.max(1, math.floor(base * control * buff(buffs, "ManaCostMult") + 0.5))
end

function CombatMath.BattleHealth(levels): number
	return 60 + (levels.Vitality or 0) * 6
end

-- Combat power (Seven Thrones, raids): sword and magic together, scaled up so the
-- world's strongest sit in the hundreds of thousands. affinity = best element.
function CombatMath.Power(levels, skills, affinity: number?): number
	local sword = CombatMath.SwordDamage(levels, skills)
	local magic = CombatMath.MagicDamage(levels, skills, 1, affinity or 0)
	return math.floor(((sword + magic) * 1.5 + CombatMath.BattleHealth(levels) * 0.25) ^ 2)
end

-- Adventurer level for raid gates: sqrt(power) / 10.
function CombatMath.Level(power: number): number
	return math.floor(math.sqrt(math.max(0, power)) / 10)
end

function CombatMath.CritChance(levels): number
	return math.min(0.3, (levels.Luck or 0) * 0.003)
end

return CombatMath
