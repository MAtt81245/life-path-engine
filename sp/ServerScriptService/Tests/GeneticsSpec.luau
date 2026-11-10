--[[
	Life 1 starter spins, family legacies, spouse genetics and selective breeding,
	rebirth as your own child, adult duels with stakes, region-locked masters with
	sect ranks, and the Kunlun toll.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = game:GetService("ServerScriptService").Modules

local PlayerState = require(Modules.PlayerState)
local CreationSystem = require(Modules.CreationSystem)
local DynastySystem = require(Modules.DynastySystem)
local RelationshipSystem = require(Modules.RelationshipSystem)
local WheelSystem = require(Modules.WheelSystem)
local MasterSystem = require(Modules.MasterSystem)
local RegionSystem = require(Modules.RegionSystem)
local DuelSystem = require(Modules.DuelSystem)
local Rng = require(Modules.Rng)
local GeneticsText = require(ReplicatedStorage.Shared.GeneticsText)
local Content = require(ReplicatedStorage.Shared.Content)
local GamePack = require(ReplicatedStorage.Shared.GamePack)

local Genetics = Content.Get("GeneticsConfig")
local Legacies = Content.Get("FamilyLegacyConfig")
local Races = Content.Get("RacesConfig")
local Masters = Content.Get("MastersConfig")

local function character(name: string, age: number)
	local player = { Name = name }
	local state = PlayerState.CreateState({}, nil)
	PlayerState.Track(player, state)
	state.Age = age
	PlayerState.StartYear(state)
	return player, state
end

local function dynasty(): boolean
	return GamePack.IsActive("Dynasty")
end

return function(test, expect)
	test("Life 1 gets 3 free starter spins for bloodline and legacy, only before the first birthday", function()
		expect.skipUnless(dynasty(), "Dynasty disabled")
		local player, state = character("Newborn", 0)
		expect.equal(state.Creation.Spins, 3, "three free spins")
		expect.equal(state.Legacy, Legacies.Default, "default legacy")
		local karma = state.Karma
		for _, kind in { "Legacy", "Legacy", "Bloodline" } do
			local ok = CreationSystem.Roll(player, state, kind)
			expect.truthy(ok or kind == "Bloodline" and not GamePack.IsEnabled("Lineages"), kind .. " roll")
		end
		expect.equal(state.Karma, karma, "free")
		local ok, reason = CreationSystem.Roll(player, state, "Legacy")
		expect.falsy(ok, "no fourth spin")
		expect.truthy(reason and string.find(reason, "No free spins", 1, true), "explains: " .. tostring(reason))
		-- A reroll replaces the old legacy's money instead of stacking it.
		local legacy = Legacies.Get(state.Legacy)
		-- Birth money comes from the rolled social class (HistoryConfig.Classes), 50 without one.
		local birth = state.Modules and state.Modules.Birth
		local class = birth and Content.Get("HistoryConfig").ClassesById[birth.Class or ""]
		local base = if class then class.Money else 50
		expect.equal(state.Money, base + PlayerState.GetBuffs(state).StartingMoney + (legacy.Money or 0), "money of the final legacy only")
		expect.truthy(CreationSystem.Roll(player, state, "Done"), "done")
		-- The journal shows only the final result, not every reroll.
		local lines = {}
		for _, entry in state.Log do
			if string.find(entry.Text, "first breath", 1, true) then
				table.insert(lines, entry.Text)
			end
		end
		expect.equal(#lines, 1, "one creation line")
		expect.truthy(lines[1] and string.find(lines[1], legacy.Name, 1, true), "names the final legacy: " .. tostring(lines[1]))
		state.Creation.Spins = 3
		expect.falsy(CreationSystem.Roll(player, state, "Legacy"), "closed after Done")
		local _, older = character("Toddler", 1)
		expect.falsy(CreationSystem.Open(older), "closed after the first birthday")
		PlayerState.Track(player, nil)
	end)

	test("suitors carry genetics; elite roots need Charisma and realm to court", function()
		expect.skipUnless(dynasty(), "Dynasty disabled")
		local player, state = character("Suitor", 20)
		local friend = PlayerState.CreateRelationship(state, "Friend", { Affection = 80 })
		expect.truthy(friend.Genetics and Genetics.GradeIndex[friend.Genetics.Grade] and Genetics.TraitsById[friend.Genetics.Trait], "rolled genetics")
		friend.Genetics.Grade = "Peerless"
		local ok, reason = RelationshipSystem.Interact(player, state, friend.Id, "Romance", PlayerState.GetBuffs(state))
		expect.falsy(ok, "refused")
		expect.truthy(reason and string.find(reason, "Charisma", 1, true), "needs Charisma: " .. tostring(reason))
		state.Stats.Charisma.Level = 50
		expect.truthy(GeneticsText.RomanceBlock(state, friend), "still needs the realm")
		state.RealmIndex = Genetics.Grades[5].RomanceRealm
		expect.equal(GeneticsText.RomanceBlock(state, friend), nil, "may court now")
		local family = state.Relationships[1]
		expect.equal(family.Genetics, nil, "family members have no rolled genetics")
		PlayerState.Track(player, nil)
	end)

	test("children inherit from both parents: bloodline, your talent, the spouse's trait, potential", function()
		expect.skipUnless(dynasty(), "Dynasty disabled")
		Rng.Seed(5)
		local player, state = character("Parent", 30)
		state.Talents = { "iron_bones" }
		state.Stats.Strength.Level = 35
		local spouse = PlayerState.CreateRelationship(state, "Partner", { Name = "Mei Lin", Age = 30, Affection = 90 })
		spouse.Genetics = { Race = state.Race, Grade = "Peerless", Trait = "SwordHeart" }
		local traits, mutations, children = 0, 0, 0
		for _ = 1, 40 do
			local child = DynastySystem.Conceive(player, state, spouse)
			if child then
				children += 1
				local g = child.Genetics
				expect.equal(g.Talents[1], "iron_bones", "your talent")
				expect.equal(g.Potential.Strength, math.floor(35 / Genetics.PotentialPerLevels), "stat potential")
				if g.Trait == "SwordHeart" then traits += 1 end
				if g.Mutated then mutations += 1 end
				PlayerState.RemoveRelationship(state, child.Id)
			end
		end
		Rng.Seed(nil)
		expect.equal(children, 40, "born")
		local traitShare = traits / children
		expect.truthy(traitShare > 0.55 and traitShare < 0.98, ("Peerless spouse passes the trait ~80%% (%.2f)"):format(traitShare))
		if Races.Spin and GamePack.IsEnabled("Lineages") then
			expect.truthy(mutations > 0, "bloodline awakenings happen with a Peerless spouse")
		end
		PlayerState.Track(player, nil)
	end)

	test("try for a child and upbringing guidance", function()
		expect.skipUnless(dynasty(), "Dynasty disabled")
		local player, state = character("Family", 25)
		state.Social = 10
		local spouse = PlayerState.CreateRelationship(state, "Partner", { Age = 25, Affection = 90 })
		state.Flags.Married = true
		local born = nil
		for _ = 1, 30 do
			state.SocialDone, state.Social = {}, 10
			RelationshipSystem.Interact(player, state, spouse.Id, "TryForChild", PlayerState.GetBuffs(state))
			for _, rel in state.Relationships do
				if rel.Type == "Child" then born = rel end
			end
			if born then break end
		end
		expect.truthy(born, "a child is born")
		expect.truthy(RelationshipSystem.Interact(player, state, born.Id, "RaiseScholarly", PlayerState.GetBuffs(state)), "guided")
		expect.equal(born.Genetics.Upbringing, "Scholarly", "upbringing set")
		state.SocialDone = {}
		expect.falsy(RelationshipSystem.Interact(player, state, born.Id, "RaiseMartial", PlayerState.GetBuffs(state)), "only once")
		PlayerState.Track(player, nil)
	end)

	test("rebirth as your child: inherited genes and legacy, no spin, spouse becomes your parent", function()
		expect.skipUnless(dynasty() and GamePack.IsEnabled("Samsara"), "Dynasty/Samsara disabled")
		local player, state = character("Heir", 40)
		state.Talents = { "iron_bones" }
		DynastySystem.ApplyLegacy(state, "sword_clan")
		local spouse = PlayerState.CreateRelationship(state, "Partner", { Name = "Mei Lin", Age = 40, Affection = 90 })
		spouse.Genetics = { Race = state.Race, Grade = "Genius", Trait = "QiAffinity" }
		local heir = DynastySystem.Conceive(player, state, spouse)
		local sibling = DynastySystem.Conceive(player, state, spouse)
		heir.Age, sibling.Age = 10, 14
		heir.Genetics.Trait, heir.Genetics.Upbringing = "QiAffinity", "Martial"
		PlayerState.Die(player, "test")
		state.Karma = 0
		expect.truthy(WheelSystem.ChooseHeir(player, state, heir.Id), "heir chosen")
		local ok, reason = WheelSystem.SpinLegacy(player, state)
		expect.falsy(ok, "no spins for an heir")
		expect.truthy(reason and string.find(reason, "inherited", 1, true), "explains: " .. tostring(reason))
		expect.truthy(WheelSystem.Confirm(player, state), "reborn (free even with 0 Karma)")
		expect.equal(state.Name, heir.Name, "you are the child")
		expect.equal(state.Race, heir.Genetics.Race, "their bloodline")
		expect.equal(state.Talents[1], "iron_bones", "their inherited talent")
		expect.equal(state.Legacy, "sword_clan", "the family legacy carries on")
		local hasTrait, parent, brother = false, nil, nil
		for _, buff in state.LifeBuffs do
			if buff.Kind == "Heredity" then hasTrait = true end
		end
		for _, rel in state.Relationships do
			if rel.Type == "Parent" then parent = rel end
			if rel.Type == "Sibling" and rel.Name == sibling.Name then brother = rel end
		end
		expect.truthy(hasTrait, "hereditary trait active")
		expect.truthy(parent and parent.Name == "Mei Lin", "spouse is now your parent")
		expect.equal(state.Age, 10, "taken over at the heir's real age")
		expect.truthy(brother and brother.Age == 14, "the other child is an older sibling")
		expect.equal(state.Lineage[1].NextPath, "Descendant", "gold bloodline link on the tree")
		PlayerState.Track(player, nil)
	end)

	test("a full rebirth spins a new family legacy", function()
		expect.skipUnless(dynasty(), "Dynasty disabled")
		local player, state = character("Wanderer", 40)
		PlayerState.Die(player, "test")
		state.Karma = 500
		expect.truthy(WheelSystem.SpinLegacy(player, state), "legacy spin")
		local rolled = state.Wheel.Legacy
		expect.truthy(Legacies.ById[rolled], "rolled a legacy")
		WheelSystem.ChoosePath(player, state, "Stranger")
		WheelSystem.Confirm(player, state)
		expect.equal(state.Legacy, rolled, "the new life has it")
		PlayerState.Track(player, nil)
	end)

	test("adult duels: wagers move money, a won blood feud ends the rival", function()
		local player, state = character("Duelist", 20)
		state.Money, state.Social = 1000, 10
		local rival = PlayerState.CreateRelationship(state, "Rival", { Affection = 5 })
		local ok = RelationshipSystem.Interact(player, state, rival.Id, "Wager", PlayerState.GetBuffs(state))
		expect.truthy(ok and state.PendingDuel and state.PendingDuel.Kind == "Wager", "wager opens a clash")
		DuelSystem.Quick(player, state)
		expect.truthy(state.PendingDuel.Done, "resolved")
		expect.truthy(state.Money == 1200 or state.Money == 800, "20% stake either way: " .. state.Money)
		DuelSystem.Close(state)
		local feudStat = Content.Get("RelationshipsConfig").InteractionsById.BloodFeud.ChanceStat -- Power in the academy pack
		state.Stats[feudStat].Level = 60
		local ended = false
		for _ = 1, 20 do
			state.SocialDone, state.Social, state.Health = {}, 10, PlayerState.GetMaxHealth(state)
			RelationshipSystem.Interact(player, state, rival.Id, "BloodFeud", PlayerState.GetBuffs(state))
			DuelSystem.Quick(player, state)
			DuelSystem.Close(state)
			if not PlayerState.FindRelationship(state, rival.Id) then
				ended = true
				break
			end
		end
		expect.truthy(ended, "the feud ends with the rival's death")
		local _, young = character("Kid", 12)
		young.Social = 5
		local kidRival = PlayerState.CreateRelationship(young, "Rival", { Affection = 5 })
		local allowed, why = RelationshipSystem.Interact(player, young, kidRival.Id, "BloodFeud", PlayerState.GetBuffs(young))
		expect.falsy(allowed, "not before 16: " .. tostring(why))
		PlayerState.Track(player, nil)
	end)

	test("masters are found only in their region; sect ranks pay stipends and need trials", function()
		expect.skipUnless(GamePack.IsEnabled("Masters") and GamePack.IsActive("World"), "Masters/World disabled")
		local player, state = character("Seeker", 20)
		RegionSystem.SetRegion(state, "capital")
		for _ = 1, 40 do
			MasterSystem.Seek(player, state, PlayerState.GetBuffs(state))
		end
		for id in state.DiscoveredMasters do
			expect.truthy(table.find(Masters.ById[id].Regions, "capital"), id .. " lives in the capital")
		end
		expect.truthy(state.DiscoveredMasters.scholar_bai or state.DiscoveredMasters.madame_su, "found a capital master")
		expect.truthy(MasterSystem.AllDiscovered(state), "nobody else here")
		state.Master = { Id = "scholar_bai", Loyalty = 100, QuestsDone = {}, Rank = 1 }
		local money = state.Money
		MasterSystem.YearTick(player, state)
		expect.equal(state.Money - money, Masters.SectRanks[1].Stipend, "outer disciple stipend")
		state.Stats.Strength.Level = 60
		local promoted = false
		for _ = 1, 10 do
			state.Actions, state.Health = 3, PlayerState.GetMaxHealth(state)
			MasterSystem.Trial(player, state)
			DuelSystem.Quick(player, state)
			DuelSystem.Close(state)
			if state.Master.Rank == 2 then promoted = true break end
		end
		expect.truthy(promoted, "promoted to Inner Disciple")
		local ok, reason = MasterSystem.Trial(player, state)
		expect.falsy(ok, "core needs a realm")
		expect.truthy(reason and string.find(reason, "Not ready", 1, true), "explains: " .. tostring(reason))
		PlayerState.Track(player, nil)
	end)

	test("Kunlun opens at Foundation Establishment, or at 16 for the sect toll", function()
		expect.skipUnless(GamePack.IsActive("World"), "World disabled")
		local Regions = Content.Get("WorldRegionsConfig")
		local player, state = character("Climber", 14)
		RegionSystem.SetRegion(state, "qinghe")
		state.Money = 5000
		local reason = RegionSystem.Check(state, "kunlun")
		expect.truthy(reason and string.find(reason, "toll", 1, true), "explains both ways in: " .. tostring(reason))
		state.Age = 16
		local tollReason, toll = RegionSystem.Check(state, "kunlun")
		expect.equal(tollReason, nil, "the toll opens the gate")
		expect.equal(toll, Regions.ById.kunlun.AltFee, "sect toll fee")
		state.Age, state.RealmIndex = 14, 3
		local realmReason, fee = RegionSystem.Check(state, "kunlun")
		expect.equal(realmReason, nil, "Foundation Establishment opens it")
		expect.equal(fee, Regions.ById.kunlun.TravelFee, "normal fee")
		PlayerState.Track(player, nil)
	end)
end
