-- Engine module definition: birth regions, the world map and travel (server:
-- Modules/RegionSystem; content: WorldRegionsConfig, TravelEventsConfig).
return {
	Id = "World",
	Name = "World",
	Description = "Birth regions with their own Qi and modifiers, the drawn world map and journeys with road encounters.",
	Optional = true,
	Tab = { Label = "Map", Order = 66, Icon = "🗺" },
	Requirements = {
		Region = function(view, regionId)
			local data = view.Modules and view.Modules.World
			return (data and data.Region) == regionId, "In " .. tostring(regionId)
		end,
	},
}
