-- Engine module definition: rebirth paths, eras, past-life echoes and glimpses
-- (server: Modules/SamsaraSystem). Optional: packs that do not list it have it off.
return {
	Id = "Samsara",
	Name = "Samsara",
	Description = "Rebirth paths (descendant, stranger, past, future), eras, past-life echoes and glimpses.",
	Optional = true,
	EffectKeys = { "MeetEcho", "LegendOfSelf", "BecomeRivalDisciple", "RivalReckoning" },
	Requirements = {
		-- An echo lives in the current region (echoes without a region live everywhere).
		HasEcho = function(view, need)
			local data = view.Modules and view.Modules.Samsara
			local here = view.Modules and view.Modules.World and view.Modules.World.Region
			local has = false
			for _, echo in (data and data.Echoes) or {} do
				if echo.Region == nil or here == nil or echo.Region == here then
					has = true
				end
			end
			return has == (need == true), if need then "Someone from a past life is near" else "No past-life echoes"
		end,
		-- Your powerful past-life rival lives here and does not recognize you.
		RivalMentorHere = function(view, need)
			local data = view.Modules and view.Modules.Samsara
			local here = view.Modules and view.Modules.World and view.Modules.World.Region
			local has = false
			for _, echo in (data and data.Echoes) or {} do
				if echo.Type == "Rival" and echo.Powerful and (echo.Region == nil or here == nil or echo.Region == here) then
					has = true
				end
			end
			return has == (need == true), "Your old rival is near"
		end,
		IsRivalDisciple = function(view, need)
			local data = view.Modules and view.Modules.Samsara
			local is = data ~= nil and data.Mentor ~= nil and not data.Mentor.Done
			return is == (need == true), "Disciple of your old rival"
		end,
		Era = function(view, era)
			local data = view.Modules and view.Modules.Samsara
			return (data and data.Era or "Present") == era, era .. " era"
		end,
		RemembersPastLife = function(view, need)
			local data = view.Modules and view.Modules.Samsara
			local remembers = data ~= nil and (data.Glimpses or 0) > 0
			return remembers == (need == true), "Remembers a past life"
		end,
	},
}
