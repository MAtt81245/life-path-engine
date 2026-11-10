--[[
	TestRunner: minimal test harness (no external dependencies).

	Every sibling ModuleScript whose name ends in "Spec" returns
		function(test, expect) test("name", function() ... end) end

	Run from the Studio command bar (edit mode is fine):
		print(require(game.ServerScriptService.Tests.TestRunner).Report())
]]

local TestRunner = {}

local expect = {}

function expect.equal(actual, expected, label: string?)
	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(label or "value", tostring(expected), tostring(actual)), 2)
	end
end

function expect.truthy(value, label: string?)
	if not value then
		error((label or "value") .. " should be truthy", 2)
	end
end

function expect.falsy(value, label: string?)
	if value then
		error((label or "value") .. " should be falsy, got " .. tostring(value), 2)
	end
end

function expect.near(actual: number, expected: number, tolerance: number?, label: string?)
	if math.abs(actual - expected) > (tolerance or 1e-6) then
		error(("%s: expected ~%s, got %s"):format(label or "value", tostring(expected), tostring(actual)), 2)
	end
end

-- Passes when some string in `list` contains `fragment`.
function expect.contains(list, fragment: string, label: string?)
	for _, item in list do
		if string.find(item, fragment, 1, true) then
			return
		end
	end
	error(("%s: no entry contains '%s'"):format(label or "list", fragment), 2)
end

-- Skips the rest of a test whose fixture content or module the active pack lacks.
-- Skips are counted and listed, so missing coverage stays visible.
local SKIP = {}
function expect.skipUnless(condition, reason: string)
	if not condition then
		error({ [SKIP] = reason }, 0)
	end
end

TestRunner.expect = expect

function TestRunner.Run(folder: Instance?)
	folder = folder or script.Parent
	local results = { Passed = 0, Failed = 0, Skipped = 0, Failures = {}, Skips = {} }
	local specs = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") and string.sub(child.Name, -4) == "Spec" then
			table.insert(specs, child)
		end
	end
	table.sort(specs, function(a, b) return a.Name < b.Name end)

	for _, module in specs do
		local cases = {}
		local ok, err = pcall(function()
			require(module)(function(name, fn)
				table.insert(cases, { Name = name, Fn = fn })
			end, expect)
		end)
		if not ok then
			results.Failed += 1
			table.insert(results.Failures, module.Name .. " failed to load: " .. tostring(err))
		end
		for _, case in cases do
			local passed, failure = pcall(case.Fn)
			if passed then
				results.Passed += 1
			elseif type(failure) == "table" and failure[SKIP] then
				results.Skipped += 1
				table.insert(results.Skips, ("%s > %s: %s"):format(module.Name, case.Name, failure[SKIP]))
			else
				results.Failed += 1
				table.insert(results.Failures, ("%s > %s: %s"):format(module.Name, case.Name, tostring(failure)))
			end
		end
	end
	return results
end

function TestRunner.Report(folder: Instance?): string
	local results = TestRunner.Run(folder)
	local lines = { ("%d passed, %d failed, %d skipped"):format(results.Passed, results.Failed, results.Skipped) }
	for _, failure in results.Failures do
		table.insert(lines, "  FAIL " .. failure)
	end
	for _, skip in results.Skips do
		table.insert(lines, "  SKIP " .. skip)
	end
	return table.concat(lines, "\n")
end

return TestRunner
