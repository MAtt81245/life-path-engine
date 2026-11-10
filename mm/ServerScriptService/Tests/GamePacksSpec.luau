local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.Shared.Content)
local Validator = require(ReplicatedStorage.Shared.ContentValidator)

return function(test, expect)
	-- Regression: Extend used to deep-copy, so helpers like RacesConfig.Get kept reading
	-- the base tables (found with the dev console in the academy pack).
	test("extended configs' helper functions read the patched data", function()
		local folder = game:GetService("ReplicatedStorage").GamePacks:FindFirstChildWhichIsA("Folder")
		expect.skipUnless(folder, "no game pack folder")
		local Content = require(game:GetService("ReplicatedStorage").Shared.Content)
		local races = Content.Extend("RacesConfig", folder, function(r)
			r.List = { { Id = "Probe", Name = "Probe Race", Cost = 0, BaseStats = {}, Buffs = {} } }
			r.ById = { Probe = r.List[1] }
			r.Default = "Probe"
		end)
		expect.equal(races.Get("Probe").Name, "Probe Race", "Get reads the patched ById")
		expect.equal(races.Get("Missing").Id, "Probe", "fallback uses the patched Default")
		expect.equal(Content.Get("RacesConfig", false).ById.Probe, nil, "base data untouched")
		local talents = Content.Extend("TalentsConfig", folder, function(t)
			t.List = { { Id = "probe_talent", Name = "Probe", Rarity = "Common", Buffs = {} } }
			t.ById = { probe_talent = t.List[1] }
		end)
		expect.equal(talents.Roll(1, Random.new(1))[1], "probe_talent", "Roll draws from the patched list")
		for _, child in folder:GetChildren() do
			expect.falsy(string.find(child.Name, "__Extend", 1, true), "no clone left behind: " .. child.Name)
		end
	end)

	test("every game pack validates without errors", function()
		for packId, report in Validator.RunAll() do
			expect.equal(#report.Errors, 0, packId .. " errors (" .. table.concat(report.Errors, " | ") .. ")")
		end
	end)

	test("packs override some modules and inherit the rest", function()
		local _, trainingFrom = Content.Resolve("TrainingConfig", "modern_life")
		local _, racesFrom = Content.Resolve("RacesConfig", "modern_life")
		expect.equal(trainingFrom.Name, "modern_life", "TrainingConfig source")
		expect.equal(racesFrom.Name, "Configs", "RacesConfig source")
		expect.equal(Content.Get("GameManifest", "modern_life").Id, "modern_life", "manifest")
		expect.equal(Content.Get("GameManifest", false).Id, "life_path_xianxia", "base manifest")
	end)

	test("extending content never mutates the inherited module", function()
		local base = Content.Get("TrainingConfig", false)
		local modern = Content.Get("TrainingConfig", "modern_life")
		expect.equal(base.ById.PracticeSword.Name, "Sword Practice", "base action name")
		expect.equal(modern.ById.PracticeSword.Name, "Fencing Club", "pack action name")
		local listed
		for _, action in modern.Actions do
			if action.Id == "PracticeSword" then listed = action end
		end
		expect.truthy(listed and modern.ById.PracticeSword == listed, "copied index points at copied entries")
		expect.equal(base.Proficiencies.QiArts.Name, "Qi Arts", "base proficiency name")
	end)

	test("pack lists and indexes stay consistent", function()
		local studies = Content.Get("StudiesAndCareerConfig", "modern_life")
		expect.falsy(studies.TiersById.SectAcademy, "sect academy removed")
		expect.truthy(studies.TiersById.Bootcamp, "bootcamp added")
		expect.truthy(studies.CareersById.SoftwareEngineer, "new career indexed")
		local events = Content.Get("YearlyEventsConfig", "modern_life").Events
		expect.truthy(events.first_phone and events.stolen_notes, "new and inherited events")
		expect.falsy(events.library_manual.Options[1].Effects.Qi, "cultivation effect removed")
	end)

	test("missing packs are reported", function()
		local chain, problem = Content.Chain("no_such_pack")
		expect.truthy(problem and string.find(problem, "not found", 1, true), "problem reported")
		expect.equal(chain[#chain].Name, "Configs", "falls back to Configs")
	end)
end
