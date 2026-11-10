--[[
	BigNum: massive numbers stored as mantissa * 10^exponent.
	The mantissa is kept normalized to [1, 10) (or 0). Values are immutable:
	every operation returns a new BigNum.

	local a = BigNum.new(1.5, 30)          -- 1.5e30
	local b = a:Add(250):Mul(BigNum.from("1e12"))
	print(b:ToString())                    -- "1.5No"
]]

local BigNum = {}
BigNum.__index = BigNum

-- Beyond this exponent gap the smaller operand is negligible.
local PRECISION_DIGITS = 17

local SUFFIXES = {
	"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc",
	"UDc", "DDc", "TDc", "QaDc", "QiDc", "SxDc", "SpDc", "OcDc", "NoDc", "Vg",
}

local function normalize(m: number, e: number): (number, number)
	if m == 0 or m ~= m or e ~= e then
		return 0, 0
	end
	local whole = math.floor(e)
	m *= 10 ^ (e - whole)
	e = whole
	local shift = math.floor(math.log10(math.abs(m)))
	m /= 10 ^ shift
	e += shift
	-- Guard against floating point drift at the boundaries
	if math.abs(m) >= 10 then
		m /= 10
		e += 1
	elseif math.abs(m) < 1 then
		m *= 10
		e -= 1
	end
	return m, e
end

function BigNum.new(mantissa: number?, exponent: number?)
	local m, e = normalize(mantissa or 0, exponent or 0)
	return setmetatable({ m = m, e = e }, BigNum)
end

function BigNum.zero()
	return BigNum.new(0, 0)
end

function BigNum.isBigNum(value): boolean
	return type(value) == "table" and getmetatable(value) == BigNum
end

-- Accepts a BigNum, number, string ("1.5e30") or serialized table {m=, e=}.
function BigNum.from(value)
	if BigNum.isBigNum(value) then
		return value
	elseif type(value) == "number" then
		return BigNum.new(value, 0)
	elseif type(value) == "string" then
		local m, e = string.match(value, "^%s*([%-%d%.]+)[eE]([%-%d]+)%s*$")
		if m then
			return BigNum.new(tonumber(m) or 0, tonumber(e) or 0)
		end
		return BigNum.new(tonumber(value) or 0, 0)
	elseif type(value) == "table" then
		return BigNum.new(tonumber(value.m or value[1]) or 0, tonumber(value.e or value[2]) or 0)
	end
	return BigNum.zero()
end

function BigNum:IsZero(): boolean
	return self.m == 0
end

function BigNum:Neg()
	return BigNum.new(-self.m, self.e)
end

function BigNum:Add(other)
	local b = BigNum.from(other)
	if self.m == 0 then
		return b
	elseif b.m == 0 then
		return self
	end
	local diff = self.e - b.e
	if diff > PRECISION_DIGITS then
		return self
	elseif diff < -PRECISION_DIGITS then
		return b
	end
	return BigNum.new(self.m + b.m * 10 ^ (b.e - self.e), self.e)
end

function BigNum:Sub(other)
	return self:Add(BigNum.from(other):Neg())
end

function BigNum:Mul(other)
	local b = BigNum.from(other)
	return BigNum.new(self.m * b.m, self.e + b.e)
end

function BigNum:Div(other)
	local b = BigNum.from(other)
	if b.m == 0 then
		return BigNum.zero()
	end
	return BigNum.new(self.m / b.m, self.e - b.e)
end

-- Power with a numeric exponent (positive values only).
function BigNum:Pow(power: number)
	if self.m <= 0 then
		return BigNum.zero()
	end
	return BigNum.new(1, self:Log10() * power)
end

function BigNum:Log10(): number
	if self.m <= 0 then
		return -math.huge
	end
	return math.log10(self.m) + self.e
end

-- Returns -1, 0 or 1.
function BigNum:Compare(other): number
	local d = self:Sub(other)
	if d.m > 0 then
		return 1
	elseif d.m < 0 then
		return -1
	end
	return 0
end

function BigNum:Lt(other): boolean return self:Compare(other) < 0 end
function BigNum:Le(other): boolean return self:Compare(other) <= 0 end
function BigNum:Gt(other): boolean return self:Compare(other) > 0 end
function BigNum:Ge(other): boolean return self:Compare(other) >= 0 end
function BigNum:Eq(other): boolean return self:Compare(other) == 0 end

function BigNum:Max(other)
	local b = BigNum.from(other)
	return self:Ge(b) and self or b
end

function BigNum:Min(other)
	local b = BigNum.from(other)
	return self:Le(b) and self or b
end

-- May return math.huge for exponents above 308.
function BigNum:ToNumber(): number
	return self.m * 10 ^ self.e
end

local function trimZeros(s: string): string
	if string.find(s, "%.") then
		s = string.gsub(s, "0+$", "")
		s = string.gsub(s, "%.$", "")
	end
	return s
end

function BigNum:ToString(decimals: number?): string
	decimals = decimals or 2
	if self.m == 0 then
		return "0"
	end
	local sign = self.m < 0 and "-" or ""
	local absM = math.abs(self.m)
	if self.e < 3 then
		return sign .. trimZeros(string.format("%.1f", absM * 10 ^ self.e))
	end
	local tier = math.floor(self.e / 3)
	if tier < #SUFFIXES then
		local value = absM * 10 ^ (self.e - tier * 3)
		return sign .. trimZeros(string.format("%." .. decimals .. "f", value)) .. SUFFIXES[tier + 1]
	end
	return sign .. string.format("%." .. decimals .. "fe%d", absM, self.e)
end

function BigNum:Serialize()
	return { m = self.m, e = self.e }
end

BigNum.__add = function(a, b) return BigNum.from(a):Add(b) end
BigNum.__sub = function(a, b) return BigNum.from(a):Sub(b) end
BigNum.__mul = function(a, b) return BigNum.from(a):Mul(b) end
BigNum.__div = function(a, b) return BigNum.from(a):Div(b) end
BigNum.__unm = function(a) return a:Neg() end
BigNum.__eq = function(a, b) return a:Eq(b) end
BigNum.__lt = function(a, b) return BigNum.from(a):Lt(b) end
BigNum.__le = function(a, b) return BigNum.from(a):Le(b) end
BigNum.__tostring = function(a) return a:ToString() end

return BigNum
