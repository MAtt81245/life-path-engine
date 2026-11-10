-- Engine module definition: the living family tree's extras (server:
-- Modules/DynastySystem; content: FamilyTreeConfig). Ancestral heirlooms are
-- consecrated before death and pass down the generations; extended relatives join
-- the tree only when met through an event.
return {
	Id = "Dynasty",
	Name = "Dynasty",
	Description = "Ancestral heirlooms with soul stacks, relatives met through events and the family tree's memory.",
	Optional = true,
	EffectKeys = { "MeetRelative", "ReclaimHeirloom", "HaveChild", "StartDuel" },
	Requirements = {
		-- An heirloom of a past life is held by the old family in the current region.
		LostHeirloomHere = function(view, need)
			local here = view.Modules and view.Modules.World and view.Modules.World.Region
			local found = false
			for _, heirloom in view.Heirlooms or {} do
				if heirloom.Holder == "Family" and heirloom.Lost and (here == nil or heirloom.Region == here) then
					found = true
				end
			end
			return found == (need == true), "Your old family's heirloom is near"
		end,
	},
}
