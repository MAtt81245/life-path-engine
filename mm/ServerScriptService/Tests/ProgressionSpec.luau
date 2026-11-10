local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.Shared.Content)
local Realms = Content.Get("RealmsConfig")
local Stats = Content.Get("PlayerStatsConfig")

return function(test, expect)
	test("breakthrough requirements strictly increase through every realm", function()
		local previous
		for realm = 1, #Realms.Realms do
			for sub = 1, Realms.SubLevels do
				local requirement = Realms.GetRequirement(realm, sub)
				if previous then
					expect.truthy(requirement:Gt(previous), ("realm %d sub %d"):format(realm, sub))
				end
				previous = requirement
			end
		end
	end)

	test("breakthrough chances stay within bounds", function()
		for realm = 1, #Realms.Realms do
			for sub = 1, Realms.SubLevels do
				local chance = Realms.GetSuccessChance(realm, sub)
				expect.truthy(chance >= 0 and chance <= 1, ("realm %d sub %d chance %s"):format(realm, sub, tostring(chance)))
			end
		end
	end)

	test("longevity grows with realms", function()
		for realm = 2, #Realms.Realms do
			expect.truthy(Realms.GetLongevity(realm) > Realms.GetLongevity(realm - 1), "realm " .. realm)
		end
	end)

	test("stat XP curve increases", function()
		for level = 1, 100 do
			expect.truthy(Stats.XpForLevel(level) >= Stats.XpForLevel(level - 1), "level " .. level)
		end
	end)
end
