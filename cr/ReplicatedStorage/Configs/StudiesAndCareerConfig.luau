--[[
	Education tiers and careers.

	Tiers with Auto = true enroll you automatically at StartAge (if the previous tier
	was completed). Other tiers are applied for from the Study & Career tab.
	At the end of `Duration` years you graduate if Performance >= PassPerformance
	(Honors at HonorsPerformance). Grades shape which careers open up.

	Careers pay Salary per year, scaled by years worked, performance and buffs.
	PartTime jobs can be held while studying.
]]

local StudiesAndCareerConfig = {}

StudiesAndCareerConfig.PassPerformance = 35
StudiesAndCareerConfig.HonorsPerformance = 85
StudiesAndCareerConfig.StartPerformance = 55
StudiesAndCareerConfig.RaisePerYear = 0.05
StudiesAndCareerConfig.MinWorkingAge = 14

StudiesAndCareerConfig.StatusNames = { [0] = "Commoner", [1] = "Respectable", [2] = "Educated", [3] = "Elite", [4] = "Noble" }

StudiesAndCareerConfig.Tiers = {
	{ Id = "Kindergarten", Name = "Kindergarten", Auto = true, StartAge = 3, Duration = 3, Status = 0,
		YearlyXp = { Charisma = 6, Intelligence = 4 } },
	{ Id = "PrimarySchool", Name = "Primary School", Auto = true, StartAge = 6, Duration = 6, Previous = "Kindergarten", Status = 0,
		YearlyXp = { Intelligence = 10, Charisma = 4 } },
	{ Id = "HighSchool", Name = "High School", Auto = true, StartAge = 12, Duration = 6, Previous = "PrimarySchool", Status = 1,
		YearlyXp = { Intelligence = 14, Charisma = 5, Strength = 4 } },
	{ Id = "University", Name = "University", Duration = 4, Status = 2, TuitionPerYear = 2000,
		Description = "Opens skilled careers. Honors students study free.",
		Requires = { MinAge = 17, Graduated = "HighSchool", Stats = { Intelligence = 18 } },
		YearlyXp = { Intelligence = 22, Charisma = 6 } },
	{ Id = "Graduate", Name = "Graduate Studies", Duration = 2, Status = 3, TuitionPerYear = 5000,
		Description = "Masters and doctorates for the elite.",
		Requires = { Graduated = "University", Stats = { Intelligence = 35 } },
		YearlyXp = { Intelligence = 30 } },
	{ Id = "SectAcademy", Name = "Jujutsu High", Duration = 3, Status = 3, TuitionPerYear = 0,
		Description = "Sorcerer training at your mentor's jujutsu school.",
		Requires = { HasMaster = true, MinRealm = 2 },
		YearlyXp = { QiControl = 20, Intelligence = 10 } },
}

StudiesAndCareerConfig.Careers = {
	{ Id = "Farmhand", Name = "Convenience Store Clerk", Salary = 800, Stress = 3, Status = 0, PartTime = true,
		Requires = { MinAge = 16 } },
	{ Id = "StreetVendor", Name = "Ramen Shop Server", Salary = 1500, Stress = 4, Status = 0, PartTime = true,
		Requires = { MinAge = 16, Stats = { Charisma = 5 } } },
	{ Id = "CityGuard", Name = "Police Officer", Salary = 4000, Stress = 6, Status = 1,
		Requires = { MinAge = 18, Graduated = "HighSchool", Stats = { Strength = 15 } } },
	{ Id = "Clerk", Name = "Office Clerk", Salary = 5000, Stress = 5, Status = 1,
		Requires = { MinAge = 18, Graduated = "HighSchool", Stats = { Intelligence = 15 } } },
	{ Id = "Merchant", Name = "Cursed Object Broker", Salary = 20000, Stress = 8, Status = 2,
		Requires = { Graduated = "University", Stats = { Charisma = 25 } } },
	{ Id = "Official", Name = "Jujutsu Higher-Up", Salary = 30000, Stress = 9, Status = 3,
		Requires = { Graduated = "University", Stats = { Intelligence = 35, Charisma = 15 } } },
	{ Id = "Physician", Name = "Jujutsu High Medic", Salary = 45000, Stress = 10, Status = 3,
		Requires = { Graduated = "Graduate", Stats = { Intelligence = 45 } } },
	{ Id = "SectInstructor", Name = "Jujutsu Instructor", Salary = 35000, Stress = 6, Status = 4,
		Requires = { MinRealm = 3, HasMaster = true, Stats = { QiControl = 30 } } },
	-- Content expansion (2026-11-02): 8 more careers.
	{ Id = "Courier", Name = "Bike Delivery Courier", Salary = 1200, Stress = 4, Status = 0, PartTime = true,
		Requires = { MinAge = 15, Stats = { Agility = 8 } } },
	{ Id = "ArcadeAttendant", Name = "Arcade Attendant", Salary = 1000, Stress = 2, Status = 0, PartTime = true,
		Requires = { MinAge = 15 } },
	{ Id = "AuxiliaryManager", Name = "Auxiliary Manager", Salary = 9000, Stress = 7, Status = 1,
		Requires = { MinAge = 18, Graduated = "HighSchool", Stats = { Intelligence = 18, Charisma = 10 } } },
	{ Id = "WindowAgent", Name = "Window Agent", Salary = 7000, Stress = 5, Status = 1,
		Requires = { MinAge = 18, Graduated = "HighSchool", Flag = "SpiritRoot" } },
	{ Id = "Freelancer", Name = "Freelance Exorcist", Salary = 18000, Stress = 9, Status = 2,
		Requires = { MinAge = 18, MinRealm = 2, Stats = { Strength = 25 } } },
	{ Id = "ToolSmith", Name = "Cursed Tool Smith", Salary = 22000, Stress = 6, Status = 2,
		Requires = { MinAge = 20, Proficiency = { Sword = 25 }, Stats = { Strength = 20 } } },
	{ Id = "Researcher", Name = "Cursed Object Researcher", Salary = 32000, Stress = 7, Status = 3,
		Requires = { Graduated = "Graduate", Stats = { Intelligence = 40, QiControl = 15 } } },
	{ Id = "BarrierKeeper", Name = "Barrier Keeper", Salary = 40000, Stress = 5, Status = 4,
		Requires = { MinRealm = 4, Proficiency = { QiArts = 40 }, Stats = { Intelligence = 30 } } },
}

StudiesAndCareerConfig.TiersById = {}
for index, tier in StudiesAndCareerConfig.Tiers do
	tier.Order = index
	tier.TuitionPerYear = tier.TuitionPerYear or 0
	StudiesAndCareerConfig.TiersById[tier.Id] = tier
end

StudiesAndCareerConfig.CareersById = {}
for _, career in StudiesAndCareerConfig.Careers do
	StudiesAndCareerConfig.CareersById[career.Id] = career
end

-- Highest status from completed education and the current job.
function StudiesAndCareerConfig.GetSocialStatus(graduated, careerId): string
	local status = 0
	for tierId in graduated or {} do
		local tier = StudiesAndCareerConfig.TiersById[tierId]
		if tier then
			status = math.max(status, tier.Status)
		end
	end
	local career = careerId and StudiesAndCareerConfig.CareersById[careerId]
	if career then
		status = math.max(status, career.Status)
	end
	return StudiesAndCareerConfig.StatusNames[status]
end

return StudiesAndCareerConfig
