--[[
	Gacha: weighted rarity spins with pity, shared by server (rolls) and client (odds).

	spin = {
		RarityOrder = { "Common", ..., "Mythic" },       -- low to high
		Rarities = { Common = { Weight = 65 }, ... },
		Pity = { { Rarity = "Epic", Every = 15 }, ... },   -- the Every-th spin without that
	}                                                       -- rarity or better is guaranteed one
	pool  = list of entries with Id and Rarity (tiers with no entry are skipped)
	pity  = counters table owned by the caller, keyed by rule rarity (mutated)
]]

local Gacha = {}

local function ranks(spin)
	local rank = {}
	for i, name in spin.RarityOrder do
		rank[name] = i
	end
	return rank
end

-- Lowest rarity rank this spin may land on, given the pity counters.
function Gacha.Floor(spin, pity): number
	local rank, floor = ranks(spin), 1
	for _, rule in spin.Pity or {} do
		if ((pity and pity[rule.Rarity]) or 0) + 1 >= rule.Every then
			floor = math.max(floor, rank[rule.Rarity] or 1)
		end
	end
	return floor
end

-- Chance of each rarity on the next spin (respecting pity and empty tiers).
-- Weight of a rarity, with luck boosting every rarity above the lowest.
local function weight(spin, name: string, rank, luck: number?): number
	local base = spin.Rarities[name].Weight
	return if rank[name] > 1 then base * (1 + (luck or 0)) else base
end

function Gacha.Odds(spin, pool, pity, luck: number?): { [string]: number }
	local rank, floor = ranks(spin), Gacha.Floor(spin, pity)
	local present = {}
	for _, entry in pool do
		present[entry.Rarity] = true
	end
	local total, odds = 0, {}
	for _, name in spin.RarityOrder do
		if present[name] and rank[name] >= floor then
			total += weight(spin, name, rank, luck)
		end
	end
	if total == 0 and floor > 1 then
		-- The pool has nothing at the pity floor (small pools): ignore the floor.
		floor = 1
		for _, name in spin.RarityOrder do
			if present[name] then
				total += weight(spin, name, rank, luck)
			end
		end
	end
	for _, name in spin.RarityOrder do
		odds[name] = if present[name] and rank[name] >= floor and total > 0 then weight(spin, name, rank, luck) / total else 0
	end
	return odds
end

-- Returns (entry, rarity, forcedByPity). `exclude` = { [id] = true } to skip;
-- `luck` boosts every rarity above the lowest (Karmic Fortune, VIP).
function Gacha.Roll(spin, pool, pity, rng, exclude, luck: number?)
	local rank = ranks(spin)
	local candidates = {}
	for _, entry in pool do
		if not (exclude and exclude[entry.Id]) then
			table.insert(candidates, entry)
		end
	end
	if #candidates == 0 then
		return nil, nil, false
	end
	local odds = Gacha.Odds(spin, candidates, pity, luck)
	local roll, rarity = rng:NextNumber(), nil
	for _, name in spin.RarityOrder do
		if odds[name] > 0 then
			rarity = name
			roll -= odds[name]
			if roll < 0 then
				break
			end
		end
	end
	local tier = {}
	for _, entry in candidates do
		if entry.Rarity == rarity then
			table.insert(tier, entry)
		end
	end
	local entry = tier[rng:NextInteger(1, #tier)]
	local forced = Gacha.Floor(spin, pity) > 1
	if pity then
		for _, rule in spin.Pity or {} do
			if rank[rarity] >= (rank[rule.Rarity] or math.huge) then
				pity[rule.Rarity] = 0
			else
				pity[rule.Rarity] = (pity[rule.Rarity] or 0) + 1
			end
		end
	end
	return entry, rarity, forced
end

-- Display name of a rarity key (Rarities[key].Name, e.g. key "Rare" shown as "Uncommon").
function Gacha.RarityName(spin, key: string): string
	local info = spin and spin.Rarities and spin.Rarities[key]
	return (info and info.Name) or key
end

return Gacha
