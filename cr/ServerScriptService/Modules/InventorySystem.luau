--[[
	InventorySystem: buying, selling, using and equipping items (Inventory module).
	Item use applies the same effect schema as life events (Engine.ApplyEffects);
	equipped items add their buffs through PlayerState.GetBuffs.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Content = require(Shared:WaitForChild("Content"))
local GamePack = require(Shared:WaitForChild("GamePack"))
local Requirements = require(Shared:WaitForChild("Requirements"))
local Items = Content.Get("ItemsConfig")
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local Engine = require(script.Parent:WaitForChild("LifeEventsEngine"))

local InventorySystem = {}

local function available(itemId: string)
	local item = Items.ById[itemId]
	if item and GamePack.IsEnabled(item.Module) then
		return item
	end
	return nil
end

-- Returns (ok, message).
function InventorySystem.Buy(player, state, itemId: string)
	local item = available(itemId)
	if not item or not item.Price or not table.find(Items.Shop, itemId) then
		return false
	end
	if item.MinAge and state.Age < item.MinAge then
		return false, ("You must be %d to buy that."):format(item.MinAge)
	end
	local met, requirements = Requirements.Evaluate(state, item.Requires)
	if not met then
		return false, "Requires " .. Requirements.UnmetText(requirements)
	end
	if state.Money < item.Price then
		return false, "You can't afford that."
	end
	if PlayerState.ItemCount(state, itemId) >= Items.MaxStack(item) then
		return false, "You can't carry any more of those."
	end
	state.Money -= item.Price
	PlayerState.AddItem(state, itemId, 1)
	return true, ("Bought %s for %s."):format(item.Name, PlayerState.FormatMoney(item.Price))
end

function InventorySystem.Sell(player, state, itemId: string)
	local item = Items.ById[itemId]
	if not item or PlayerState.ItemCount(state, itemId) < 1 then
		return false
	end
	local price = Items.SellPrice(item)
	if not price then
		return false, "Nobody wants to buy that."
	end
	PlayerState.AddItem(state, itemId, -1)
	state.Money += price
	return true, ("Sold %s for %s."):format(item.Name, PlayerState.FormatMoney(price))
end

function InventorySystem.Use(player, state, itemId: string)
	local item = available(itemId)
	if not item or not item.Use or PlayerState.ItemCount(state, itemId) < 1 then
		return false
	end
	local inventory = PlayerState.Inventory(state)
	local limit = item.Use.UsesPerYear
	if limit and (inventory.Uses[itemId] or 0) >= limit then
		return false, ("You can only use %d %s per year."):format(limit, item.Name)
	end
	-- Lifetime cap (e.g. longevity pills): diminishing returns, no endless lifespan.
	inventory.LifeUses = inventory.LifeUses or {}
	local lifeLimit = item.Use.MaxPerLife
	if lifeLimit and (inventory.LifeUses[itemId] or 0) >= lifeLimit then
		return false, ("%s no longer works on you (%d per life)."):format(item.Name, lifeLimit)
	end
	local effects = item.Use.Effects or {}
	if effects.Qi and GamePack.IsEnabled("Cultivation") and state.Qi:Ge(PlayerState.GetRequirement(state)) then
		return false, PlayerState.Words("Your {EnergyName} is at its limit. {AdvanceTierName} first.")
	end
	PlayerState.AddItem(state, itemId, -1)
	inventory.Uses[itemId] = (inventory.Uses[itemId] or 0) + 1
	inventory.LifeUses[itemId] = (inventory.LifeUses[itemId] or 0) + 1
	local summary = Engine.ApplyEffects(player, state, { Id = itemId }, effects)
	return true, if summary ~= "" then item.Name .. ":  " .. summary else "Used " .. item.Name .. "."
end

function InventorySystem.Equip(player, state, itemId: string)
	local item = available(itemId)
	if not item or not item.Equip or PlayerState.ItemCount(state, itemId) < 1 then
		return false
	end
	local inventory = PlayerState.Inventory(state)
	if inventory.Equipped[item.Equip.Slot] == itemId then
		return false, "Already equipped."
	end
	inventory.Equipped[item.Equip.Slot] = itemId
	return true, "Equipped " .. item.Name .. "."
end

function InventorySystem.Unequip(player, state, slot: string)
	local inventory = PlayerState.Inventory(state)
	local itemId = inventory.Equipped[slot]
	if not itemId then
		return false
	end
	inventory.Equipped[slot] = nil
	local item = Items.ById[itemId]
	return true, "Unequipped " .. (if item then item.Name else itemId) .. ".", "info"
end

-- Registry hooks (see SystemRegistry).
InventorySystem.Hooks = {
	Remotes = {
		InventoryAction = {
			Module = "Inventory",
			Cooldown = 0.15,
			Validate = function(action, id)
				return type(action) == "string" and type(id) == "string"
			end,
			Handle = function(player, state, _, action, id)
				if action == "Buy" then
					return InventorySystem.Buy(player, state, id)
				elseif action == "Sell" then
					return InventorySystem.Sell(player, state, id)
				elseif action == "Use" then
					return InventorySystem.Use(player, state, id)
				elseif action == "Equip" then
					return InventorySystem.Equip(player, state, id)
				elseif action == "Unequip" then
					return InventorySystem.Unequip(player, state, id)
				end
				return false
			end,
		},
	},
}

return InventorySystem
