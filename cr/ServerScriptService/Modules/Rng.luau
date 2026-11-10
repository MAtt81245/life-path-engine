--[[
	Rng: the server's shared random source. Every gameplay module draws from it,
	so tests and balance reports can replay a run with Rng.Seed(n).
	Use with method syntax like a Random object: rng:NextNumber(), rng:NextInteger(a, b).
]]

local Rng = {}

local generator = Random.new()

-- Reseeds every module at once (nil = unpredictable again).
function Rng.Seed(seed: number?)
	generator = if seed then Random.new(seed) else Random.new()
end

function Rng:NextNumber(min: number?, max: number?): number
	if min then
		return generator:NextNumber(min, max)
	end
	return generator:NextNumber()
end

function Rng:NextInteger(min: number, max: number): number
	return generator:NextInteger(min, max)
end

return Rng
