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
	{ Id = "SectAcademy", Name = "Shin'o Academy", Duration = 3, Status = 3, TuitionPerYear = 0,
		Description = "Soul Reaper training at the Shin'o Spiritual Academy.",
		Requires = { HasMaster = true, MinRealm = 2 },
		YearlyXp = { QiControl = 20, Intelligence = 10 } },
	-- Content expansion (2026-11-02): 6 more schools.
	{ Id = "MartialAcademy", Name = "Hakuda Dojo Academy", Duration = 3, Status = 2, TuitionPerYear = 1500,
		Description = "Forms, sparring and endurance from dawn to dusk.",
		Requires = { MinAge = 15, Graduated = "PrimarySchool", Stats = { Strength = 15 } },
		YearlyXp = { Strength = 18, Agility = 12, Vitality = 8 } },
	{ Id = "MerchantSchool", Name = "Shopkeepers' Guild School", Duration = 2, Status = 1, TuitionPerYear = 1200,
		Description = "Ledgers, contracts and the art of the deal.",
		Requires = { MinAge = 15, Graduated = "PrimarySchool", Stats = { Charisma = 10 } },
		YearlyXp = { Charisma = 16, Intelligence = 10 } },
	{ Id = "Monastery", Name = "Konso Shrine School", Duration = 4, Status = 1, TuitionPerYear = 0,
		Description = "Bells, sutras and early mornings guiding lost souls.",
		Requires = { MinAge = 12 },
		YearlyXp = { QiControl = 10, Intelligence = 8, Vitality = 6 } },
	{ Id = "MedicalSchool", Name = "Fourth Division Medical Course", Duration = 4, Status = 3, TuitionPerYear = 4000,
		Description = "Healing Kido, field surgery and a thousand herbs.",
		Requires = { Graduated = "University", Stats = { Intelligence = 30 } },
		YearlyXp = { Intelligence = 24, Vitality = 6 } },
	{ Id = "AlchemyInstitute", Name = "Twelfth Division Research Institute", Duration = 3, Status = 3, TuitionPerYear = 6000,
		Description = "Reishi furnaces, strange devices and explosions you learn from.",
		Requires = { MinRealm = 2, Stats = { Intelligence = 25 } },
		YearlyXp = { Intelligence = 18, QiControl = 14 } },
	{ Id = "ImperialAcademy", Name = "Kido Corps Academy", Duration = 3, Status = 4, TuitionPerYear = 8000,
		Description = "The finest Kido minds guard the forbidden incantations here.",
		Requires = { Graduated = "Graduate", Stats = { Intelligence = 50, Charisma = 25 } },
		YearlyXp = { Intelligence = 32, Charisma = 12 } },
}

StudiesAndCareerConfig.Careers = {
	{ Id = "Farmhand", Name = "Candy Shop Helper", Salary = 800, Stress = 3, Status = 0, PartTime = true,
		Requires = { MinAge = 16 } },
	{ Id = "StreetVendor", Name = "Karakura Delivery Runner", Salary = 1500, Stress = 4, Status = 0, PartTime = true,
		Requires = { MinAge = 16, Stats = { Charisma = 5 } } },
	{ Id = "CityGuard", Name = "Police Officer", Salary = 4000, Stress = 6, Status = 1,
		Requires = { MinAge = 18, Graduated = "HighSchool", Stats = { Strength = 15 } } },
	{ Id = "Clerk", Name = "Clinic Receptionist", Salary = 5000, Stress = 5, Status = 1,
		Requires = { MinAge = 18, Graduated = "HighSchool", Stats = { Intelligence = 15 } } },
	{ Id = "Merchant", Name = "Spirit Goods Trader", Salary = 20000, Stress = 8, Status = 2,
		Requires = { Graduated = "University", Stats = { Charisma = 25 } } },
	{ Id = "Official", Name = "Central 46 Clerk", Salary = 30000, Stress = 9, Status = 3,
		Requires = { Graduated = "University", Stats = { Intelligence = 35, Charisma = 15 } } },
	{ Id = "Physician", Name = "Karakura General Doctor", Salary = 45000, Stress = 10, Status = 3,
		Requires = { Graduated = "Graduate", Stats = { Intelligence = 45 } } },
	{ Id = "SectInstructor", Name = "Academy Instructor", Salary = 35000, Stress = 6, Status = 4,
		Requires = { MinRealm = 3, HasMaster = true, Stats = { QiControl = 30 } } },
	-- Content expansion (2026-11-02): 8 more careers.
	{ Id = "Fisherman", Name = "River Fisherman", Salary = 1000, Stress = 2, Status = 0, PartTime = true,
		Requires = { MinAge = 15 } },
	{ Id = "Courier", Name = "Hell Butterfly Courier", Salary = 2200, Stress = 5, Status = 0, PartTime = true,
		Requires = { MinAge = 15, Stats = { Agility = 10 } } },
	{ Id = "Innkeeper", Name = "Innkeeper", Salary = 6000, Stress = 6, Status = 1,
		Requires = { MinAge = 20, Stats = { Charisma = 18 } } },
	{ Id = "Blacksmith", Name = "Soul Smith", Salary = 7000, Stress = 6, Status = 1,
		Requires = { MinAge = 18, Stats = { Strength = 22, Vitality = 15 } } },
	{ Id = "MartialInstructor", Name = "Hakuda Instructor", Salary = 12000, Stress = 6, Status = 2,
		Requires = { Graduated = "MartialAcademy", Stats = { Strength = 25 } } },
	{ Id = "Healer", Name = "Fourth Division Healer", Salary = 38000, Stress = 9, Status = 3,
		Requires = { Graduated = "MedicalSchool", Stats = { Intelligence = 35 } } },
	{ Id = "Alchemist", Name = "Twelfth Division Researcher", Salary = 50000, Stress = 9, Status = 3,
		Requires = { Graduated = "AlchemyInstitute", Stats = { QiControl = 25 } } },
	{ Id = "Minister", Name = "Kido Corps Grand Master", Salary = 60000, Stress = 12, Status = 4,
		Requires = { Graduated = "ImperialAcademy", Stats = { Intelligence = 55, Charisma = 30 } } },
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
