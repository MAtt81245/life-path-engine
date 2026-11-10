--[[
	ArcanaConfig: magic (Modules/ArcanaSystem, the Magic & Sword tab).

	Elements        five base elements, rolled at birth (BirthAffinity), 0-100.
	SpecialSchools  Sound, Gravity, Lightning, Shadow, Time: each opens when the
	                Knowledge skill reaches its Knowledge level (affinity starts at 5).
	Spells          7 per element (Beginner .. God); a rank needs RankAffinity in that
	                element. Id = element .. rank ("Fire3").
	Mastery         practising a spell builds Mastery 0-5 (MasteryCasts per level); at 5
	                the spell is Chantless (instant, full power in battle).
	Collapse        a practice that empties the mana pool triggers a safe Mana Collapse
	                (once a year): Max Mana grows by the Gain of your age (fastest young).
	SilentTrial     opens at Magic Control 20: land Hits timed casts -> Silent Casting for
	                the rest of the life (mana cost x0.7, magic damage x1.2).
	Forge           Spell Forge: Magic skill, Knowledge skill and age gates; 1 or 2
	                elements, a shape and a rank. Forged spells enter the Family Grimoire
	                (account-wide); a Legend's spells are taught everywhere (free to learn).
]]

local ArcanaConfig = {}

ArcanaConfig.RankNames = { "Beginner", "Intermediate", "Advanced", "Saint", "King", "Emperor", "God" }
ArcanaConfig.RankAffinity = { 0, 15, 30, 45, 60, 75, 90 }
ArcanaConfig.BaseManaCost = { 4, 8, 14, 22, 32, 45, 60 }
ArcanaConfig.MasteryCasts = { 2, 3, 4, 5, 6 } -- casts for mastery 1, 2, 3, 4, 5
ArcanaConfig.MaxMastery = 5
ArcanaConfig.BirthAffinity = { Min = 3, Max = 25, FavoredBonus = 20 }
ArcanaConfig.SpecialStartAffinity = 5

ArcanaConfig.Collapse = {
	{ MaxAge = 12, Gain = 6 },
	{ MaxAge = 17, Gain = 3 },
	{ MaxAge = 40, Gain = 2 },
	{ MaxAge = math.huge, Gain = 1 },
}

ArcanaConfig.SilentTrial = { MagicControl = 20, Hits = 3, Buffs = { ManaCostMult = 0.7, MagicDamageMult = 1.2 } }

ArcanaConfig.Forge = {
	MagicSkill = 30, KnowledgeSkill = 15, Age = 10, MaxElements = 2, MaxNameLength = 24, GrimoireLimit = 30,
	Shapes = {
		{ Id = "Bolt", Name = "Bolt", Power = 1 },
		{ Id = "Lance", Name = "Lance", Power = 1.1 },
		{ Id = "Wave", Name = "Wave", Power = 0.95 },
		{ Id = "Orb", Name = "Orb", Power = 1.05 },
		{ Id = "Barrier", Name = "Barrier", Power = 0.8 },
		{ Id = "Storm", Name = "Storm", Power = 1.15 },
	},
	FusionBonus = 1.15, -- two elements in one spell
}

-- A life is legendary (its forged spells are taught worldwide) with any skill at
-- SkillLevel or fame at Fame.
ArcanaConfig.Legend = { SkillLevel = 75, Fame = 2000 }

ArcanaConfig.Elements = {
	{ Id = "Fire", Name = "Fire", Icon = "🔥", Color = Color3.fromRGB(255, 120, 70),
		Spells = { "Ember Flick", "Fireball", "Flame Lance", "Inferno Wall", "Crimson Phoenix", "Sun Collapse", "Primordial Flame" } },
	{ Id = "Water", Name = "Water", Icon = "💧", Color = Color3.fromRGB(90, 170, 255),
		Spells = { "Water Bead", "Water Whip", "Frost Spear", "Tidal Prison", "Leviathan Torrent", "Glacial Age", "Ocean Sovereign" } },
	{ Id = "Wind", Name = "Wind", Icon = "🌪", Color = Color3.fromRGB(150, 230, 200),
		Spells = { "Gust", "Wind Blade", "Cyclone Step", "Gale Fortress", "Tempest Wyrm", "Sky Sunder", "Breath of Heaven" } },
	{ Id = "Earth", Name = "Earth", Icon = "⛰", Color = Color3.fromRGB(200, 160, 100),
		Spells = { "Pebble Shot", "Stone Wall", "Earth Spike", "Quake", "Titan's Fist", "Mountain Crown", "World Shaper" } },
	{ Id = "Healing", Name = "Healing", Icon = "✨", Color = Color3.fromRGB(150, 240, 160), Heals = true,
		Spells = { "Mend", "Soothing Light", "Restoration", "Sanctuary", "Rebirth Bloom", "Saint's Grace", "Divine Resurrection" } },
}

ArcanaConfig.SpecialSchools = {
	{ Id = "Sound", Name = "Sound", Icon = "🎵", Color = Color3.fromRGB(240, 200, 120), Knowledge = 15,
		Spells = { "Chime", "Sonic Pulse", "Resonance Spear", "Silent Requiem", "Thunderous Choir", "Song of Ending", "Primordial Note" } },
	{ Id = "Gravity", Name = "Gravity", Icon = "🌑", Color = Color3.fromRGB(150, 120, 220), Knowledge = 30,
		Spells = { "Weight", "Pull", "Crushing Field", "Gravity Well", "Collapse Star", "Event Horizon", "Singularity" } },
	{ Id = "Lightning", Name = "Lightning", Icon = "⚡", Color = Color3.fromRGB(255, 230, 90), Knowledge = 45,
		Spells = { "Spark", "Lightning Arrow", "Chain Lightning", "Storm Lance", "Thunder Emperor", "Heaven's Judgment", "God's Wrath" } },
	{ Id = "Shadow", Name = "Shadow", Icon = "🌘", Color = Color3.fromRGB(130, 110, 170), Knowledge = 60,
		Spells = { "Shade", "Shadow Bind", "Night Blade", "Umbral Gate", "Abyss Tide", "Eclipse", "Endless Night" } },
	{ Id = "Time", Name = "Time", Icon = "⌛", Color = Color3.fromRGB(220, 220, 255), Knowledge = 75,
		Spells = { "Blink", "Slow", "Haste", "Rewind Wound", "Frozen Moment", "Epoch Break", "Eternity" } },
}

ArcanaConfig.ElementsById, ArcanaConfig.SpellsById, ArcanaConfig.AllElements = {}, {}, {}
for _, list in { ArcanaConfig.Elements, ArcanaConfig.SpecialSchools } do
	for _, element in list do
		element.Special = element.Knowledge ~= nil
		ArcanaConfig.ElementsById[element.Id] = element
		table.insert(ArcanaConfig.AllElements, element)
		for rank, name in element.Spells do
			local id = element.Id .. rank
			ArcanaConfig.SpellsById[id] = {
				Id = id, Name = name, Element = element.Id, Rank = rank, RankName = ArcanaConfig.RankNames[rank],
				Affinity = ArcanaConfig.RankAffinity[rank], ManaCost = ArcanaConfig.BaseManaCost[rank], Heals = element.Heals,
			}
		end
	end
end

function ArcanaConfig.CollapseGain(age: number): number
	for _, step in ArcanaConfig.Collapse do
		if age <= step.MaxAge then
			return step.Gain
		end
	end
	return 0
end

function ArcanaConfig.Shape(id: string)
	for _, shape in ArcanaConfig.Forge.Shapes do
		if shape.Id == id then
			return shape
		end
	end
	return nil
end

return ArcanaConfig
