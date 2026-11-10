--[[
	Cursed Black Market: game passes and developer products (Modules/MonetizationSystem,
	client UIController/ShopModal).

	GamePassId / DevProductId 0 = not created yet: create it on the Creator Hub and paste
	its id here. In Studio, the shop's "Studio Test Purchase (Free)" toggle grants any
	pass or product without Robux (also ServerScriptService attribute DevPasses or the
	dev console `pass <id> on|off` / `buy <productId>`). Live servers never sandbox.

	Pass fields:
		GoldenActions   extra golden action diamonds every year (on top of the free cap)
		Luck            extra spin luck (like Karmic Fortune)
		SpinSpeed       Wheel spinner animation speed multiplier
		AutoAgeSeconds  seconds per year while auto-aging (default AgingSystem.SecondsPerYear)
		FreeLock        locking a bloodline on the Wheel costs no Karma
		Badge           tag shown next to the character name
	Product fields:
		Grant = { Karma = n } | { Revive = true } | { Pill = bonus }
		Module          engine module the product needs (hidden when the manifest turns it off)
	Robux is the display price only; the real price is set on the Creator Hub.
	Icon and Description may use the game's Terms (UIThemeConfig) as tokens ({MetaCurrency},
	{MetaCurrencyIcon}, {ActionPip}, {RebirthWheel}, {RaceName} ...), filled in by the shop.
]]

local MonetizationConfig = {}

MonetizationConfig.Passes = {
	{ Id = "CelestialTimekeeper", Name = "Time Manipulation Pass", GamePassId = 0, Icon = "⌛", Robux = 149,
		GoldenActions = 1, AutoAgeSeconds = 1.5,
		Description = "+1 golden action {ActionPip} every year. Auto-age runs at 1.5 s per year instead of 4 s." },
	{ Id = "ImmortalVIP", Name = "Honored One VIP", GamePassId = 0, Icon = "👁", Robux = 399,
		GoldenActions = 1, SpinSpeed = 2, Luck = 0.25, Badge = "VIP",
		Description = "+1 golden action {ActionPip}, +25% permanent spin luck, x2 Wheel speed and the golden [VIP] badge." },
	{ Id = "BloodlineVault", Name = "Ancestral Clan Vault", GamePassId = 0, Icon = "🏺", Robux = 249,
		FreeLock = true, Module = "Lineages",
		Description = "A free {RaceName} Lock slot: keep your rarest {RaceName} across full rebirths without paying {MetaCurrency}." },
}

MonetizationConfig.Products = {
	{ Id = "KarmaSmall", Name = "Binding Vow Pack", DevProductId = 0, Icon = "{MetaCurrencyIcon}", Robux = 49,
		Grant = { Karma = 50 }, Description = "+50 {MetaCurrency} for the {RebirthWheel}." },
	{ Id = "KarmaMedium", Name = "Greater Binding Vow Pack", DevProductId = 0, Icon = "{MetaCurrencyIcon}", Robux = 179,
		Grant = { Karma = 200 }, Description = "+200 {MetaCurrency}.", Tag = "Popular" },
	{ Id = "KarmaHeavenly", Name = "Special Grade Vow Pack", DevProductId = 0, Icon = "{MetaCurrencyIcon}", Robux = 449,
		Grant = { Karma = 600 }, Description = "+600 {MetaCurrency}.", Tag = "Best value" },
	{ Id = "MiracleRevival", Name = "Reverse Cursed Energy Miracle Revival", DevProductId = 0, Icon = "♻", Robux = 99,
		Grant = { Revive = true }, Hidden = true, -- offered on the death prompt only
		Description = "Reverse death itself with Reverse Cursed Energy: revive at 50% health and keep this life (once per life)." },
	{ Id = "MiraclePill", Name = "Special Grade Cursed Object", DevProductId = 0, Icon = "☠", Robux = 79,
		Grant = { Pill = 0.2 }, Module = "Cultivation",
		Description = "Consume it to fill this level's {EnergyName} to 100% and add +20% to your next {AdvanceTierName}." },
}

-- Karma refunded when a revival can no longer be applied (the purchase is never lost).
MonetizationConfig.ReviveFallbackKarma = 100
MonetizationConfig.ReviveHealth = 0.5

MonetizationConfig.ById = {}
for _, pass in MonetizationConfig.Passes do
	MonetizationConfig.ById[pass.Id] = pass
end
MonetizationConfig.ProductsById = {}
for _, product in MonetizationConfig.Products do
	MonetizationConfig.ProductsById[product.Id] = product
end

return MonetizationConfig
