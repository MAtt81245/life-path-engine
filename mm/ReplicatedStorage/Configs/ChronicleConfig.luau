--[[
	ChronicleConfig: the living chronicle around a life (Modules/ChronicleSystem,
	client UIController/ChronicleHUD and TodayPage).

	StartYear / RebirthGap  the world calendar: Life 1 is born in StartYear; each new life
	                        is born RebirthGap { min, max } years after the last death.
	Eras                    { From, Name }: the era of a world year (last From <= year).
	Stages                  life stage by age (first whose MaxAge >= age).
	Genders                 rolled at birth (Name, Icon).
	Routines                the bottom routine bar: one is active; every year it pays its
	                        Gains on AGE UP. KidName shows below KidMaxAge.
	FameTiers               fame points -> tier name (header).
	Omens                   Today's Omen: one claim per real day, a small boon.
	Gains keys: Happiness, Stress, Money, Health, FamilyAffection, FriendAffection,
	StatXp = { Stat = id | Role = "Knowledge", Amount = n } (skipped if the pack lacks it).
]]

local ChronicleConfig = {}

ChronicleConfig.StartYear = 1000
ChronicleConfig.RebirthGap = { 8, 40 }

ChronicleConfig.Eras = {
	{ From = -math.huge, Name = "The Age of Dragons" },
	{ From = 1120, Name = "The Age of Sects" },
	{ From = 1300, Name = "The Age of Heavenly Wars" },
	{ From = 1600, Name = "The Age of Myth" },
}

ChronicleConfig.Stages = {
	{ Id = "Baby", Name = "Baby", MaxAge = 2 },
	{ Id = "Child", Name = "Child", MaxAge = 12 },
	{ Id = "Teen", Name = "Teen", MaxAge = 17 },
	{ Id = "Adult", Name = "Adult", MaxAge = 59 },
	{ Id = "Elder", Name = "Elder", MaxAge = math.huge },
}

ChronicleConfig.Genders = {
	{ Id = "Male", Name = "Male", Icon = "♂" },
	{ Id = "Female", Name = "Female", Icon = "♀" },
}

ChronicleConfig.KidMaxAge = 12
ChronicleConfig.DefaultRoutine = "Relax"
ChronicleConfig.Routines = {
	{ Id = "Relax", Name = "Relax", KidName = "Just Be a Kid", Icon = "🪁", Gains = { Happiness = 4, Stress = -4 } },
	{ Id = "Family", Name = "Help the Family", Icon = "🏠", Gains = { FamilyAffection = 3, Money = 20, Stress = 1 } },
	{ Id = "Study", Name = "Study", Icon = "📖", Gains = { StatXp = { Role = "Knowledge", Amount = 10 }, Stress = 2 } },
	{ Id = "Socialize", Name = "Socialize", Icon = "💬", Gains = { StatXp = { Stat = "Charisma", Amount = 8 }, Happiness = 2, FriendAffection = 2 } },
}

ChronicleConfig.FameTiers = {
	{ Min = 0, Name = "Unknown" },
	{ Min = 25, Name = "Local Name" },
	{ Min = 100, Name = "Known" },
	{ Min = 300, Name = "Renowned" },
	{ Min = 800, Name = "Famous" },
	{ Min = 2000, Name = "Legendary" },
}

ChronicleConfig.Omens = {
	{ Id = "red_sun", Text = "A red sun rises. Your blood runs hot.", Gains = { StatXp = { Stat = "Strength", Amount = 15 } } },
	{ Id = "falling_star", Text = "A falling star crosses the night sky for you.", Gains = { Happiness = 6 } },
	{ Id = "silver_coin", Text = "A silver coin glints in the mud.", Gains = { Money = 60 } },
	{ Id = "quiet_wind", Text = "A quiet wind settles your heart.", Gains = { Stress = -8 } },
	{ Id = "old_book", Text = "An old book falls open at your feet.", Gains = { StatXp = { Role = "Knowledge", Amount = 15 } } },
	{ Id = "warm_rain", Text = "Warm rain washes your aches away.", Gains = { Health = 10, Stress = -3 } },
	-- Content expansion (2026-11-02): 6 more omens.
	{ Id = "white_crane", Text = "A white crane lands beside you and bows.", Gains = { StatXp = { Stat = "Agility", Amount = 15 } } },
	{ Id = "jade_dew", Text = "Dew on the bamboo glitters like jade.", Gains = { StatXp = { Stat = "Vitality", Amount = 15 } } },
	{ Id = "laughing_child", Text = "A stranger's child laughs at your joke.", Gains = { StatXp = { Stat = "Charisma", Amount = 15 } } },
	{ Id = "lucky_cat", Text = "A black cat crosses your path and purrs.", Gains = { StatXp = { Stat = "Luck", Amount = 12 } } },
	{ Id = "temple_bell", Text = "A distant temple bell rings three times.", Gains = { Stress = -6, Happiness = 3 } },
	{ Id = "red_envelope", Text = "A red envelope blows into your hands.", Gains = { Money = 120 } },
}

ChronicleConfig.RoutinesById, ChronicleConfig.OmensById = {}, {}
for _, routine in ChronicleConfig.Routines do
	ChronicleConfig.RoutinesById[routine.Id] = routine
end
for _, omen in ChronicleConfig.Omens do
	ChronicleConfig.OmensById[omen.Id] = omen
end

function ChronicleConfig.Era(year: number): string
	local name = ChronicleConfig.Eras[1].Name
	for _, era in ChronicleConfig.Eras do
		if year >= era.From then
			name = era.Name
		end
	end
	return name
end

function ChronicleConfig.Stage(age: number)
	for _, stage in ChronicleConfig.Stages do
		if age <= stage.MaxAge then
			return stage
		end
	end
	return ChronicleConfig.Stages[#ChronicleConfig.Stages]
end

function ChronicleConfig.FameTier(points: number): string
	local name = ChronicleConfig.FameTiers[1].Name
	for _, tier in ChronicleConfig.FameTiers do
		if points >= tier.Min then
			name = tier.Name
		end
	end
	return name
end

function ChronicleConfig.RoutineName(routine, age: number): string
	return if routine.KidName and age <= ChronicleConfig.KidMaxAge then routine.KidName else routine.Name
end

-- Today's day number (UTC); the omen resets when it changes.
function ChronicleConfig.Day(now: number?): number
	return math.floor((now or os.time()) / 86400)
end

return ChronicleConfig
