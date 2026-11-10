--[[
	Standalone game: one theme and vocabulary (Configs/UIThemeConfig via Shared/PackTheme)
	used by the client UI and the server's messages, a single content folder (no packs),
	and the creation screen guard (GamePack.CreationSpins).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = game:GetService("ServerScriptService").Modules

local PackTheme = require(ReplicatedStorage.Shared.PackTheme)
local Content = require(ReplicatedStorage.Shared.Content)
local GamePack = require(ReplicatedStorage.Shared.GamePack)
local PlayerState = require(Modules.PlayerState)
local MonetizationSystem = require(Modules.MonetizationSystem)
local WheelSystem = require(Modules.WheelSystem)
require(Modules.CreationSystem) -- registers the creation guard hook

return function(test, expect)
	test("the game's vocabulary resolves, with unknown keys returning themselves", function()
		local expected = { EnergyName = "Reiatsu", TierHeader = "SPIRITUAL CLASS", AdvanceTierButton = "AWAKEN",
			AdvanceTierName = "Soul Awakening", RaceName = "Soul Origin", RebirthTab = "Rebirth", MetaCurrency = "Hogyoku Shards" }
		for key, value in expected do
			expect.equal(PackTheme.Term(key), value, key)
		end
		expect.equal(PackTheme.Term("NoSuchTerm"), "NoSuchTerm", "unknown key")
		for key, value in PackTheme.Get().Terms do
			expect.equal(type(value), "string", "term " .. key)
		end
	end)

	test("Words fills tokens, lowercases on request and leaves unknown tokens", function()
		expect.equal(PackTheme.Words("+%d {MetaCurrency}"), "+%d Hogyoku Shards", "currency")
		expect.equal(PackTheme.Words("your {raceName}"), "your soul origin", "lowercase")
		expect.equal(PackTheme.Words("{Nope} stays"), "{Nope} stays", "unknown token kept")
	end)

	test("server messages use the vocabulary, never hardcoded words", function()
		local terms = PackTheme.Get().Terms
		local saved = { terms.MetaCurrency, terms.RaceName }
		terms.MetaCurrency, terms.RaceName = "Spirit Stones", "Clan"
		local ok, err = pcall(function()
			local player = { Name = "Vocab" }
			local state = PlayerState.CreateState({}, nil)
			PlayerState.Track(player, state)
			local _, message = MonetizationSystem.GrantProduct(player, state, "KarmaSmall")
			expect.truthy(string.find(message, "Spirit Stones", 1, true), "product message: " .. message)
			state.Age = 40
			PlayerState.Die(player, "test")
			state.Karma = 0
			local _, why = WheelSystem.SpinTalent(player, state, 1)
			expect.truthy(why and string.find(why, "Spirit Stones", 1, true), "wheel message: " .. tostring(why))
			if GamePack.IsEnabled("Lineages") then
				state.Wheel.StoredRace = "Human"
				local _, locked = WheelSystem.SpinBloodline(player, state)
				expect.truthy(locked and string.find(locked, "clan", 1, true), "lowercased race word: " .. tostring(locked))
			end
			PlayerState.Track(player, nil)
		end)
		terms.MetaCurrency, terms.RaceName = saved[1], saved[2]
		expect.truthy(ok, tostring(err))
	end)

	test("palette, fonts and pip shape are complete", function()
		local theme = PackTheme.Get()
		for _, key in { "bg1", "bg2", "ink", "panel1", "panel2", "card1", "card2", "stroke", "gold", "gold2", "qi1", "text", "muted" } do
			expect.equal(typeof(theme.Palette[key]), "Color3", "color " .. key)
		end
		for _, role in { "Body", "Bold", "Heavy", "Title" } do
			expect.equal(typeof(PackTheme.Font(role)), "EnumItem", "font " .. role)
		end
		expect.equal(PackTheme.Font("Title"), Enum.Font.Michroma, "title font")
		expect.equal(PackTheme.Font("Mono"), Enum.Font.RobotoMono, "number font")
		expect.equal(theme.Pip.Rotation, 45, "spirit-seal pips")
	end)

	test("standalone: one content folder, no game packs", function()
		expect.equal(ReplicatedStorage:FindFirstChild("GamePacks"), nil, "no GamePacks folder")
		expect.equal(Content.Folder, ReplicatedStorage.Configs, "content comes from Configs")
		expect.equal(Content.Get("GameManifest").Id, "soul_path_zanpakuto", "the Soul Path game")
	end)

	test("the creation screen is skipped when no wheel can roll", function()
		local races, legacies = Content.Get("RacesConfig"), Content.Get("FamilyLegacyConfig")
		expect.truthy(GamePack.CreationSpins().Any, "this game has starter spins")
		local savedRace, savedLegacy = races.Spin, legacies.Spin
		races.Spin, legacies.Spin = nil, nil
		local ok, result = pcall(function()
			local wheels = GamePack.CreationSpins()
			local state = PlayerState.CreateState({}, nil)
			return { Any = wheels.Any, Done = state.Creation.Done }
		end)
		races.Spin, legacies.Spin = savedRace, savedLegacy
		expect.truthy(ok, tostring(result))
		expect.falsy(result.Any, "no wheel")
		expect.truthy(result.Done, "creation closed at birth")
		expect.falsy(PlayerState.CreateState({}, nil).Creation.Done, "open again with spins")
	end)
end
