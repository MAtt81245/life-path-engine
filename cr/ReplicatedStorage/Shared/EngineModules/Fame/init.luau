-- Add-on engine module (optional: packs that do not list it have it off).
-- Added purely as files to prove the module registry: no engine file was edited.
return {
	Id = "Fame",
	Name = "Fame",
	Description = "Public renown: earned by performing and by events, fades every year.",
	Optional = true,
	EffectKeys = { "Fame" },
	Buffs = { FameMult = "mult" },
	-- Shared by FameSystem (server) and the Page below (client).
	Settings = { YearlyDecay = 0.1, PerformSlots = 1, PerformMaxPerYear = 2, PerformBase = 6, PerformPerSocialLevel = 0.5, PerformMinAge = 10 },
	-- UI tab; its page is the "Page" ModuleScript inside this definition.
	Tab = { Label = "Fame", Order = 65, Icon = "⭐" },
	Requirements = {
		MinFame = function(view, need)
			local data = view.Modules and view.Modules.Fame
			return (data and data.Points or 0) >= need, ("Fame %d"):format(need)
		end,
	},
}
