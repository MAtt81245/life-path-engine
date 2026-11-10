-- Modern Life: no sect academy or sect instructors; adds a coding bootcamp and tech jobs.
local Content = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Content"))

return Content.Extend("StudiesAndCareerConfig", script.Parent, function(studies)
	local tiers = {}
	for _, tier in studies.Tiers do
		if tier.Id ~= "SectAcademy" then
			table.insert(tiers, tier)
		end
	end
	table.insert(tiers, {
		Id = "Bootcamp", Name = "Coding Bootcamp", Duration = 1, Status = 2, TuitionPerYear = 8000,
		Description = "One intense year that turns curious minds into developers.",
		Requires = { MinAge = 16, Stats = { Intelligence = 15 } },
		YearlyXp = { QiControl = 25, Intelligence = 15 },
	})

	local careers = {}
	for _, career in studies.Careers do
		if career.Id ~= "SectInstructor" then
			table.insert(careers, career)
		end
	end
	table.insert(careers, {
		Id = "SoftwareEngineer", Name = "Software Engineer", Salary = 60000, Stress = 8, Status = 3,
		Requires = { MinAge = 18, Stats = { Intelligence = 30, QiControl = 20 } },
	})

	studies.Tiers = tiers
	studies.Careers = careers
	studies.TiersById = {}
	for index, tier in tiers do
		tier.Order = index
		studies.TiersById[tier.Id] = tier
	end
	studies.CareersById = {}
	for _, career in careers do
		studies.CareersById[career.Id] = career
	end
end)
