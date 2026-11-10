local BigNum = require(game:GetService("ReplicatedStorage").Configs.BigNum)

return function(test, expect)
	test("normalizes the mantissa", function()
		local n = BigNum.new(1500, 0)
		expect.near(n.m, 1.5, 1e-9, "mantissa")
		expect.equal(n.e, 3, "exponent")
	end)

	test("adds across exponents", function()
		expect.near(BigNum.new(1, 3):Add(BigNum.new(5, 2)):ToNumber(), 1500, 1e-6)
	end)

	test("ignores negligible addends", function()
		expect.truthy(BigNum.new(1, 30):Add(1):Eq(BigNum.new(1, 30)))
	end)

	test("subtracts to zero", function()
		expect.truthy(BigNum.new(5, 10):Sub(BigNum.new(5, 10)):IsZero())
	end)

	test("multiplies and divides huge values", function()
		local product = BigNum.new(2, 50):Mul(BigNum.new(3, 40))
		expect.equal(product.e, 90, "product exponent")
		expect.near(product.m, 6, 1e-9, "product mantissa")
		expect.truthy(product:Div(BigNum.new(3, 40)):Eq(BigNum.new(2, 50)), "division undoes multiplication")
	end)

	test("compares", function()
		expect.truthy(BigNum.new(1, 10):Lt(BigNum.new(2, 10)))
		expect.truthy(BigNum.new(1, 11):Gt(BigNum.new(9, 10)))
		expect.truthy(BigNum.new(1, 5):Ge(100000))
	end)

	test("formats with suffixes", function()
		expect.equal(BigNum.new(123):ToString(), "123")
		expect.equal(BigNum.new(1500):ToString(), "1.5K")
		expect.equal(BigNum.new(1, 6):ToString(), "1M")
		expect.equal(BigNum.new(1, 70):ToString(), "1.00e70")
	end)

	test("serializes and parses", function()
		local n = BigNum.new(4.2, 77)
		expect.truthy(BigNum.from(n:Serialize()):Eq(n), "round trip")
		expect.near(BigNum.from("2.5e12"):ToNumber(), 2.5e12, 1)
	end)
end
