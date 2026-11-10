--[[
	BalanceReport: reproducible multi-policy simulation and its diagnostics.
	The diagnosis cases use hand-built reports, so each rule is checked on its own.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local Rng = require(ServerScriptService.Modules.Rng)
local BalanceReport = require(ServerScriptService.Tools.BalanceReport)

local function codes(findings)
	local set = {}
	for _, finding in findings do
		set[finding.Code] = finding.Level
	end
	return set
end

local function policy(id, fields)
	local p = {
		Id = id, Active = id ~= "Idle", Lives = 10, DeathAge = { Median = 70, Min = 60, Max = 80 }, Lifespan = 80,
		TopCause = "Old age", TopCauseCount = 10, AliveAtEnd = 0, BestStat = 40, Money = 1000, MoneyMax = 5000,
		GrowthLives = 0, EventsPerLife = 12, TopAction = "Train", TopActionShare = 0.3,
	}
	for key, value in fields or {} do
		p[key] = value
	end
	return p
end

local function cleanReport()
	return {
		Options = BalanceReport.Defaults,
		Policies = { policy("Idle", { BestStat = 5, Money = 100 }), policy("Greedy"), policy("Focused"), policy("Balanced") },
		Events = { a = 3, b = 1 }, Titles = { t = 2 }, Actions = { Train = 10 },
		Errors = {}, Violations = {},
		KnownEvents = { { Id = "a", Weight = 0.5 }, { Id = "b", ChainOnly = true } },
		KnownTitles = { { Id = "t" } }, KnownActions = { "Train" },
	}
end

local function fingerprint(report): string
	local parts = {}
	for _, p in report.Policies do
		local death = if p.DeathAge then ("%d/%d/%d"):format(p.DeathAge.Median, p.DeathAge.Min, p.DeathAge.Max) else "alive"
		table.insert(parts, ("%s:%s:%d:%.6g:%d:%d"):format(p.Id, death, p.BestStat, p.Money, p.EventsPerLife, p.CeilingLives))
	end
	local events = {}
	for id, n in report.Events do
		table.insert(events, id .. "=" .. n)
	end
	table.sort(events)
	return table.concat(parts, ";") .. "|" .. table.concat(events, ",")
end

return function(test, expect)
	test("the shared Rng replays a sequence after reseeding", function()
		Rng.Seed(42)
		local a, b = Rng:NextNumber(), Rng:NextInteger(1, 1000)
		Rng.Seed(42)
		expect.equal(Rng:NextNumber(), a, "number")
		expect.equal(Rng:NextInteger(1, 1000), b, "integer")
		Rng.Seed(nil)
	end)

	test("the same seed replays the same lives", function()
		-- No yields: this checks seeding, not scheduling (one unexplained mismatch was seen
		-- once right after a server start with yields on; never reproduced since).
		local options = { Lives = 2, MaxYears = 150, Seed = 11, Policies = { "Greedy", "Random" }, YieldEvery = 0 }
		local first = fingerprint(BalanceReport.Run(options))
		local second = fingerprint(BalanceReport.Run(options))
		expect.equal(second, first, "fingerprint")
	end)

	test("every policy plays whole lives without errors or invalid states", function()
		local report = BalanceReport.Run({ Lives = 1, Seed = 3 })
		expect.equal(#report.Policies, #BalanceReport.Policies, "policies run")
		local problems = {}
		for message in report.Errors do table.insert(problems, message) end
		for message in report.Violations do table.insert(problems, message) end
		expect.equal(#problems, 0, "problems (" .. table.concat(problems, " | ") .. ")")
		for _, p in report.Policies do
			expect.equal(p.Lives, 1, p.Id .. " lives")
		end
		expect.truthy(string.find(BalanceReport.Format(report), "FINDINGS", 1, true), "formats")
	end)

	test("a clean report has no warnings or errors", function()
		local found = BalanceReport.Diagnose(cleanReport())
		for _, finding in found do
			expect.equal(finding.Level, "INFO", finding.Code)
		end
	end)

	test("diagnoses crashes, invalid states and broken economies", function()
		local report = cleanReport()
		report.Errors = { ["boom"] = 2 }
		report.Violations = { ["negative energy"] = 1 }
		report.Policies[2] = policy("Greedy", { MoneyMax = 0 / 0 })
		report.Policies[3] = policy("Focused", { MoneyMax = 5e9, GrowthLives = 3, LifespanRunaway = 2 })
		local found = codes(BalanceReport.Diagnose(report))
		expect.equal(found.runtime_error, "ERROR", "runtime_error")
		expect.equal(found.invalid_state, "ERROR", "invalid_state")
		expect.equal(found.non_finite, "ERROR", "non_finite")
		expect.equal(found.runaway_money, "WARN", "runaway_money")
		expect.equal(found.exponential_money, "WARN", "exponential_money")
		expect.equal(found.lifespan_runaway, "WARN", "lifespan_runaway")
	end)

	test("diagnoses early deaths, idle play, dominant strategies and dead content", function()
		local report = cleanReport()
		report.Policies = {
			policy("Idle", { BestStat = 80, Money = 9000 }),
			policy("Greedy", { DeathAge = { Median = 30, Min = 25, Max = 35 }, EarlyDeaths = 8, EarlyCause = "Stress", EarlyCauseCount = 8 }),
			policy("Focused", { BestStat = 90, TopAction = "Spam", TopActionShare = 0.9 }),
			policy("Balanced", { BestStat = 45, EventsPerLife = 2 }),
		}
		report.Events, report.Titles, report.Actions = {}, {}, {}
		local found = codes(BalanceReport.Diagnose(report))
		for _, code in { "early_death", "idle_competitive", "passive_income", "dominant_strategy",
			"event_never_fired", "chain_never_reached", "title_never_unlocked", "action_never_used" } do
			expect.equal(found[code], "WARN", code)
		end
	end)

	-- Regression: lives cut off by MaxYears (immortal cultivators) were counted as early deaths.
	test("lives still alive at the end are not deaths", function()
		local report = cleanReport()
		report.Policies[2] = policy("Greedy", { DeathAge = nil, Deaths = 0, Lifespan = 0, AliveAtEnd = 10 })
		local found = codes(BalanceReport.Diagnose(report))
		expect.equal(found.early_death, nil, "early_death")
		expect.equal(found.outlived_simulation, "INFO", "outlived_simulation")
	end)

	test("a few early deaths are information, most lives dying early is a warning", function()
		local report = cleanReport()
		report.Policies[2] = policy("Greedy", { EarlyDeaths = 3, EarlyCause = "Wounds", EarlyCauseCount = 3 })
		expect.equal(codes(BalanceReport.Diagnose(report)).early_death, "INFO", "3 of 10")
		report.Policies[2] = policy("Greedy", { EarlyDeaths = 6, EarlyCause = "Wounds", EarlyCauseCount = 6 })
		expect.equal(codes(BalanceReport.Diagnose(report)).early_death, "WARN", "6 of 10")
	end)

	test("flags the end-game being reached in most lives", function()
		local report = cleanReport()
		report.Policies[3] = policy("Focused", { CeilingLives = 8, CeilingAge = 90 })
		local found = codes(BalanceReport.Diagnose(report))
		expect.equal(found.progression_ceiling, "WARN", "progression_ceiling")
	end)

	test("findings are sorted by severity", function()
		local report = cleanReport()
		report.Errors = { x = 1 }
		report.Events = {}
		report.Policies[2] = policy("Greedy", { AliveAtEnd = 1 })
		local found = BalanceReport.Diagnose(report)
		expect.equal(found[1].Level, "ERROR", "first")
		expect.equal(found[#found].Level, "INFO", "last")
	end)
end
