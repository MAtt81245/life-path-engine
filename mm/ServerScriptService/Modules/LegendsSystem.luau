--[[
	LegendsSystem: the Seven Thrones, the Family Weapon, relic leads, the Hall of Lives
	and the Community Hall (LegendsConfig; Legends module).

	Account-wide (state.World, saved; Snapshot.World): Thrones = { [seat] = { Holder,
	Power, Life } } claimed by your lives, FamilyWeapon = { Name, Tier, ForgedBy, Life },
	Relics = { relicId = true }. Per life: ModuleData(state, "Legends") = { Leads,
	ChallengeAge, Seat }.
	LegendsAction remote: ("Encounter" | "Spar" | "Challenge", seat) | ("ForgeWeapon") |
	("Share", lifeIndex). CommunityQuery remote function -> the Community Hall feed;
	CommunityHall remote event pushes new cards to every player.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))
local GamePack = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GamePack"))
local CombatMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatMath"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local SkillSystem = require(script.Parent:WaitForChild("SkillSystem"))
local HistorySystem = require(script.Parent:WaitForChild("HistorySystem"))
local BattleSystem = require(script.Parent:WaitForChild("BattleSystem"))
local Rng = require(script.Parent:WaitForChild("Rng"))

local Legends = Content.Get("LegendsConfig")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local LegendsSystem = {}

local community = {} -- this server's Community Hall feed (newest last)

local function active(): boolean
	return GamePack.IsActive("Legends")
end

function LegendsSystem.Data(state)
	local data = PlayerState.ModuleData(state, "Legends", {})
	data.Leads = data.Leads or 0
	return data
end

function LegendsSystem.World(state)
	local world = HistorySystem.World(state)
	world.Thrones = world.Thrones or {}
	world.Relics = world.Relics or {}
	return world
end

-- Your combat power right now (CombatMath.Power with your best element).
function LegendsSystem.Power(state): number
	local affinity = 0
	local arcana = state.Modules and state.Modules.Arcana
	for _, value in (arcana and arcana.Affinity) or {} do
		affinity = math.max(affinity, value)
	end
	return CombatMath.Power(PlayerState.StatLevels(state), SkillSystem.Levels(state), affinity)
end

-- The seat as the world sees it: claimed by one of your lives or its default holder.
function LegendsSystem.Seat(state, seat: number)
	local def = Legends.Thrones[seat]
	local claimed = LegendsSystem.World(state).Thrones[seat]
	if claimed then
		return { Title = def.Title, Holder = claimed.Holder, Power = claimed.Power, Yours = true, Life = claimed.Life }
	end
	return { Title = def.Title, Holder = def.Holder, Power = if def.Vacant then def.ClaimPower else def.Power, Vacant = def.Vacant, Hidden = def.Hidden }
end

local function claim(player, state, seat: number, power: number)
	local def = Legends.Thrones[seat]
	LegendsSystem.World(state).Thrones[seat] = { Holder = state.Name, Power = power, Life = state.Lives }
	LegendsSystem.Data(state).Seat = seat
	SkillSystem.Count(player, state, "thrones", 1)
	PlayerState.SetLifeBuff(state, "Throne", def.Title, def.Buffs)
	HistorySystem.Record(state, ("%s claims the seat of the %s (#%d of the Seven Thrones)."):format(state.Name, def.Title, seat), "deed")
	PlayerState.Log(player, ("You are the %s now. The Seven Thrones have a new name."):format(def.Title), "realm")
end

function LegendsSystem.FindLead(player, state, source: string): boolean
	if not active() or state.Dead then
		return false
	end
	local chance = Legends.LeadSources[source] or 0
	if Rng:NextNumber() >= chance then
		return false
	end
	local data = LegendsSystem.Data(state)
	data.Leads += 1
	SkillSystem.Count(player, state, "leads", 1)
	PlayerState.Log(player, ("You found a relic lead (%d/%d this life)."):format(math.min(data.Leads, Legends.LeadsNeeded), Legends.LeadsNeeded), "realm")
	if data.Leads == Legends.LeadsNeeded then
		local world = LegendsSystem.World(state)
		for _, relic in Legends.Relics do
			if not world.Relics[relic.Id] then
				world.Relics[relic.Id] = true
				PlayerState.SetLifeBuff(state, "Relic:" .. relic.Id, relic.Name, relic.Buffs)
				HistorySystem.Record(state, ("%s recovers the %s. It will guard every generation to come."):format(state.Name, relic.Name), "deed")
				break
			end
		end
	end
	return true
end

function LegendsSystem.Throne(player, state, action: string, seat)
	seat = math.floor(tonumber(seat) or 0)
	local def = Legends.Thrones[seat]
	if not def then
		return false
	end
	local current = LegendsSystem.Seat(state, seat)
	local power = LegendsSystem.Power(state)
	local data = LegendsSystem.Data(state)
	if action == "Encounter" then
		local found = LegendsSystem.FindLead(player, state, "Encounter")
		return true, ("You cross paths with %s, the %s.%s"):format(current.Holder or "no one", def.Title, if found then " They let slip a relic lead." else ""), "info"
	elseif action == "Spar" then
		if current.Vacant or current.Yours then
			return false, "No one sits there to spar with.", "warn"
		elseif state.Actions < 1 then
			return false, "No actions left this year.", "warn"
		end
		state.Actions -= 1
		local parts = SkillSystem.ApplyEffects(player, state, { SkillXp = { Swordsmanship = Legends.Spar.SkillXp, Magic = Legends.Spar.SkillXp }, Health = Legends.Spar.Health })
		return true, ("You spar with %s and learn from every bruise: %s"):format(current.Holder, table.concat(parts, ", ")), "good"
	elseif action == "Challenge" then
		if state.Age < Legends.ChallengeAge then
			return false, ("The Thrones ignore anyone younger than %d."):format(Legends.ChallengeAge), "warn"
		elseif data.ChallengeAge == state.Age then
			return false, "One challenge a year.", "warn"
		elseif current.Yours and current.Life == state.Lives then
			return false, "That seat is already yours.", "warn"
		end
		data.ChallengeAge = state.Age
		if current.Vacant then
			if power < def.ClaimPower then
				return false, ("The empty seat rejects you. It needs power %d."):format(def.ClaimPower), "warn"
			end
			claim(player, state, seat, power)
			return true, ("You take the empty seat of the %s!"):format(def.Title), "good"
		end
		local chance = math.clamp(0.5 + (power / math.max(1, current.Power) - 1) * 1.5, 0.02, 0.95)
		if Rng:NextNumber() < chance then
			claim(player, state, seat, power)
			return true, ("You defeat %s and claim the throne of the %s!"):format(current.Holder, def.Title), "good"
		end
		local maxHealth = PlayerState.GetMaxHealth(state)
		state.Health = math.max(math.floor(maxHealth * 0.3), state.Health - math.floor(maxHealth * Legends.ChallengeLoss.HealthShare))
		PlayerState.AdjustMeter(state, "Stress", Legends.ChallengeLoss.Stress)
		return true, ("%s crushes you. Your power (%d) was not enough."):format(current.Holder, power), "bad"
	end
	return false
end

function LegendsSystem.ForgeWeapon(player, state)
	local rule = Legends.FamilyWeapon
	local crafting = SkillSystem.Level(state, "Crafting")
	if crafting < rule.CraftingLevel then
		return false, ("Forging a Family Weapon needs Crafting %d."):format(rule.CraftingLevel), "warn"
	end
	local tier = math.floor(crafting / rule.TierEvery)
	local world = LegendsSystem.World(state)
	if world.FamilyWeapon and world.FamilyWeapon.Tier >= tier then
		return false, "Your family's weapon is already as fine as you can make it.", "warn"
	elseif state.Money < rule.Cost or state.Actions < 1 then
		return false, ("You need %s and an action."):format(PlayerState.FormatMoney(rule.Cost)), "warn"
	end
	state.Money -= rule.Cost
	state.Actions -= 1
	local surname = string.match(state.Name or "", "(%S+)$") or "Nameless"
	world.FamilyWeapon = { Name = ("Blade of House %s"):format(surname), Tier = tier, ForgedBy = state.Name, Life = state.Lives }
	LegendsSystem.ApplyWeapon(state)
	HistorySystem.Record(state, ("%s forges the %s, a weapon for every heir to come."):format(state.Name, world.FamilyWeapon.Name), "deed")
	return true, ("Forged: %s (tier %d)"):format(world.FamilyWeapon.Name, tier), "good"
end

function LegendsSystem.ApplyWeapon(state)
	local weapon = LegendsSystem.World(state).FamilyWeapon
	if not weapon then return end
	local buffs = {}
	for key, per in Legends.FamilyWeapon.PerTier do
		buffs[key] = 1 + per * weapon.Tier
	end
	PlayerState.SetLifeBuff(state, "FamilyWeapon", weapon.Name, buffs)
end

-- Hall of Lives: score, title and epitaph of the life that just ended.
table.insert(PlayerState.DeathRecorders, function(state, entry)
	local top = 0
	for _, level in SkillSystem.Levels(state) do top = math.max(top, level) end
	entry.TopSkill = top
	local fame = state.Modules and state.Modules.Fame
	entry.Fame = fame and fame.Peak or 0
	local seat = state.Modules and state.Modules.Legends and state.Modules.Legends.Seat
	entry.Throne = seat and Legends.Thrones[seat] and Legends.Thrones[seat].Title or nil
	local titleId = state.Titles and state.Titles.Equipped and state.Titles.Equipped[1]
	local title = titleId and Content.Get("TitlesConfig").ById[titleId]
	entry.Title = entry.Throne or (title and title.Name) or "the Wanderer"
	entry.Score = Legends.Score(entry)
	local first = string.match(state.Name or "", "^(%S+)") or state.Name
	entry.Epitaph = Legends.Epitaphs[Rng:NextInteger(1, #Legends.Epitaphs)]:format(first)
end)

-- Relics guard every life from birth; an heir carries the Family Weapon.
table.insert(PlayerState.NewLifeHooks, function(state)
	if not active() then return end
	local world = LegendsSystem.World(state)
	for _, relic in Legends.Relics do
		if world.Relics[relic.Id] then
			PlayerState.SetLifeBuff(state, "Relic:" .. relic.Id, relic.Name, relic.Buffs)
		end
	end
	local birth = state.Modules and state.Modules.Birth
	if birth and birth.Rebirth == "Heir" then
		LegendsSystem.ApplyWeapon(state)
	end
end)

table.insert(BattleSystem.WinHooks, function(player, state, enemy)
	LegendsSystem.FindLead(player, state, if enemy.Boss then "Boss" else "Battle")
end)
table.insert(SkillSystem.CounterHooks, function(player, state, counter)
	if counter == "skill_actions" then
		LegendsSystem.FindLead(player, state, "SkillAction")
	end
end)

----------------------------------------------------------------------
-- Community Hall
----------------------------------------------------------------------

local function addCard(card)
	table.insert(community, card)
	while #community > Legends.CommunitySize do
		table.remove(community, 1)
	end
	local event = Remotes:FindFirstChild("CommunityHall")
	if event then
		event:FireAllClients(card)
	end
end

function LegendsSystem.Community()
	return community
end

-- Shares a past life (Lineage index, newest = 1) to the Community Hall.
function LegendsSystem.Share(player, state, index)
	local entry = state.Lineage and state.Lineage[math.floor(tonumber(index) or 0)]
	if not entry then
		return false, "No such life.", "warn"
	elseif entry.Shared then
		return false, "That life is already in the Community Hall.", "warn"
	end
	entry.Shared = true
	local card = {
		Player = if typeof(player) == "Instance" then player.DisplayName else tostring(player.Name or "?"),
		Name = entry.Name, Life = entry.Life, Age = entry.Age, Score = entry.Score or Legends.Score(entry),
		Title = entry.Title or "the Wanderer", Epitaph = entry.Epitaph or "", Time = os.time(),
	}
	addCard(card)
	task.spawn(pcall, function()
		game:GetService("MessagingService"):PublishAsync("CommunityHall", card)
	end)
	return true, "Shared to the Community Hall.", "good"
end

local started = false
function LegendsSystem.Start()
	if started then return end
	started = true
	if not Remotes:FindFirstChild("CommunityHall") then
		local event = Instance.new("RemoteEvent")
		event.Name = "CommunityHall"
		event.Parent = Remotes
	end
	local query = Remotes:FindFirstChild("CommunityQuery") or Instance.new("RemoteFunction")
	query.Name = "CommunityQuery"
	query.Parent = Remotes
	query.OnServerInvoke = function()
		return community
	end
	task.spawn(function()
		pcall(function()
			game:GetService("MessagingService"):SubscribeAsync("CommunityHall", function(message)
				local card = message.Data
				if type(card) == "table" and type(card.Name) == "string" then
					for _, existing in community do
						if existing.Time == card.Time and existing.Name == card.Name then return end
					end
					addCard(card)
				end
			end)
		end)
	end)
end

LegendsSystem.Hooks = {
	Remotes = {
		LegendsAction = {
			Module = "Legends",
			Cooldown = 0.4,
			Validate = function(action)
				return type(action) == "string"
			end,
			Handle = function(player, state, _, action, arg)
				if action == "ForgeWeapon" then
					return LegendsSystem.ForgeWeapon(player, state)
				elseif action == "Share" then
					return LegendsSystem.Share(player, state, arg)
				end
				return LegendsSystem.Throne(player, state, action, arg)
			end,
		},
	},
}

return LegendsSystem
