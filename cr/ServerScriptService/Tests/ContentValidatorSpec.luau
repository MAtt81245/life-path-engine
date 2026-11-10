local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Validator = require(ReplicatedStorage.Shared.ContentValidator)
local GamePack = require(ReplicatedStorage.Shared.GamePack)
local Talents = require(ReplicatedStorage.Shared.Content).Get("TalentsConfig")

-- These cases exercise the base Configs content (packId false), whatever pack is active.
local Content = require(ReplicatedStorage.Shared.Content)
local BASE = false

local function manifestWith(changes)
	local base = Content.Get("GameManifest", BASE)
	local manifest = table.clone(base)
	manifest.Modules = table.clone(base.Modules)
	for key, value in changes do
		manifest.Modules[key] = value
	end
	return manifest
end

return function(test, expect)
	test("the shipped game pack is valid", function()
		local report = Validator.Run()
		expect.equal(#report.Errors, 0, "errors (" .. table.concat(report.Errors, " | ") .. ")")
	end)

	test("engine compatibility", function()
		expect.truthy(GamePack.IsEngineCompatible("0.3", "0.3.0"))
		expect.truthy(GamePack.IsEngineCompatible("0.2", "0.3.0"), "older minor")
		expect.falsy(GamePack.IsEngineCompatible("0.4", "0.3.0"), "newer minor")
		expect.falsy(GamePack.IsEngineCompatible("1.0", "0.3.0"), "other major")
		expect.falsy(GamePack.IsEngineCompatible(nil, "0.3.0"), "missing version")
	end)

	test("detects duplicate ids and unknown buffs", function()
		local broken = table.clone(Talents)
		broken.List = table.clone(Talents.List)
		table.insert(broken.List, Talents.List[1])
		table.insert(broken.List, { Id = "bogus", Rarity = "Common", Buffs = { NotABuff = 1 } })
		local report = Validator.Run({ TalentsConfig = broken }, BASE)
		expect.contains(report.Errors, "duplicate id", "errors")
		expect.contains(report.Errors, "unknown buff 'NotABuff'", "errors")
	end)

	test("detects broken event references", function()
		local events = { Events = { bad_event = {
			Title = "Broken", Text = "{name} waves.", MinAge = 1, MaxAge = 2, Weight = 0.5,
			Options = { { Text = "Go", Result = "Done", Chance = 0.5, Effects = { Career = "NoSuchJob", Bogus = 1 } } },
		} } }
		local report = Validator.Run({ YearlyEventsConfig = events }, BASE)
		expect.contains(report.Errors, "uses {name} without", "errors")
		expect.contains(report.Errors, "unknown career 'NoSuchJob'", "errors")
		expect.contains(report.Errors, "unknown effect 'Bogus'", "errors")
		expect.contains(report.Errors, "Chance but no FailResult", "errors")
	end)

	test("warns about content that needs disabled modules", function()
		local report = Validator.Run({ GameManifest = manifestWith({ Cultivation = false, Masters = false }) }, BASE)
		expect.equal(#report.Errors, 0, "errors")
		expect.contains(report.Warnings, "disabled module Cultivation", "warnings")
		expect.contains(report.Warnings, "disabled module Masters", "warnings")
	end)

	-- Regression (academy probe): unused content of a disabled module must not block a pack.
	test("problems in disabled-module content are counted, not reported as errors", function()
		local masters = Content.Get("MastersConfig", BASE)
		local broken = table.clone(masters)
		local master = table.clone(masters.List[1])
		master.Requires = { Stats = { NotAStat = 5 } }
		broken.List = { master }

		local off = Validator.Run({ MastersConfig = broken, GameManifest = manifestWith({ Masters = false }) }, BASE)
		expect.equal(#off.Errors, 0, "errors with Masters off (" .. table.concat(off.Errors, " | ") .. ")")
		expect.contains(off.Warnings, "content of disabled module Masters not reported", "warnings")

		local on = Validator.Run({ MastersConfig = broken }, BASE)
		expect.contains(on.Errors, "unknown stat 'NotAStat'", "errors with Masters on")
	end)

	test("rejects unknown modules and incompatible engines", function()
		local manifest = manifestWith({ Spaceships = true })
		manifest.EngineVersion = "9.0"
		local report = Validator.Run({ GameManifest = manifest }, BASE)
		expect.contains(report.Errors, "unknown module 'Spaceships'", "errors")
		expect.contains(report.Errors, "targets engine 9.0", "errors")
	end)
end
