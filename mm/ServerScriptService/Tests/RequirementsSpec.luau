local Requirements = require(game:GetService("ReplicatedStorage").Shared.Requirements)

local function view()
	return {
		Age = 20, RealmIndex = 2, Money = 500, Alignment = 10, Stress = 20,
		Stats = { Strength = { Level = 15 }, Intelligence = { Level = 30 } },
		Proficiencies = { Sword = { Level = 5 } },
		Counters = { Knowledge = 12 },
		Education = { Enrolled = true, Tier = "University" },
		Graduated = { HighSchool = true }, Honors = {},
		Career = { Id = nil },
		Master = { Id = "elder_mo", Loyalty = 40 },
		Relationships = {
			{ Category = "Friend", Affection = 80, Alive = true },
			{ Category = "Friend", Affection = 30, Alive = true },
		},
		Flags = { Married = true },
	}
end

return function(test, expect)
	test("no requirement always passes", function()
		expect.truthy(Requirements.Check(view(), nil))
	end)

	test("checks stat levels", function()
		expect.truthy(Requirements.Check(view(), { Stats = { Strength = 15, Intelligence = 30 } }))
		expect.falsy(Requirements.Check(view(), { Stats = { Strength = 16 } }))
		expect.falsy(Requirements.Check(view(), { Stats = { Agility = 1 } }), "missing stats count as level 0")
	end)

	-- Regression (academy probe): a stat the pack does not define used to be skipped, so the requirement passed.
	test("requirements on stats or proficiencies the pack lacks fail closed", function()
		expect.falsy(Requirements.Check(view(), { Stats = { NotAStat = 1 } }), "unknown stat")
		expect.falsy(Requirements.Check(view(), { Proficiency = { NotASkill = 1 } }), "unknown proficiency")
		local _, items = Requirements.Evaluate(view(), { Stats = { NotAStat = 3 } })
		expect.contains({ Requirements.UnmetText(items) }, "NotAStat 3", "unmet text")
	end)

	test("checks education, career and master", function()
		local v = view()
		expect.truthy(Requirements.Check(v, { Enrolled = "University", Graduated = "HighSchool" }))
		expect.falsy(Requirements.Check(v, { Honors = "HighSchool" }))
		expect.truthy(Requirements.Check(v, { Employed = false, HasMaster = true }))
		expect.falsy(Requirements.Check(v, { MasterLoyalty = 50 }))
	end)

	test("counts friends by affection", function()
		expect.truthy(Requirements.Check(view(), { Friends = { Count = 1, Affection = 70 } }))
		expect.falsy(Requirements.Check(view(), { Friends = { Count = 2, Affection = 70 } }))
		expect.truthy(Requirements.Check(view(), { NoRelationship = "Partner", HasRelationship = "Friend" }))
	end)

	test("checks flags, counters and ranges", function()
		local v = view()
		expect.truthy(Requirements.Check(v, { Flag = "Married", Counters = { Knowledge = 12 }, MinAge = 18, MaxAge = 20 }))
		expect.falsy(Requirements.Check(v, { NotFlag = "Married" }))
		expect.falsy(Requirements.Check(v, { MinRealm = 3 }))
	end)

	test("reports only unmet items", function()
		local met, items = Requirements.Evaluate(view(), { Stats = { Strength = 10, Intelligence = 99 }, MinMoney = 1000 })
		expect.falsy(met)
		expect.equal(#items, 3, "item count")
		local text = Requirements.UnmetText(items)
		expect.truthy(string.find(text, "Intelligence 99", 1, true), "unmet stat listed")
		expect.falsy(string.find(text, "Strength", 1, true), "met stat not listed")
	end)
end
