--[[
	Pack-driven UI theme and terminology (Configs/UIThemeConfig, pack overrides,
	Shared/PackTheme): every pack resolves a full palette, fonts, pip shape and
	vocabulary, with the base as the fallback; server messages use the active pack's
	words (PlayerState.Words); the creation screen guard (GamePack.CreationSpins).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PackTheme = require(ReplicatedStorage.Shared.PackTheme)
local Content = require(ReplicatedStorage.Shared.Content)

local GamePack = require(ReplicatedStorage.Shared.GamePack)
local Modules = game:GetService("ServerScriptService").Modules
local PlayerState = require(Modules.PlayerState)
local MonetizationSystem = require(Modules.MonetizationSystem)
local WheelSystem = require(Modules.WheelSystem)
require(Modules.CreationSystem) -- registers the creation guard hook

local PACKS = { false, "modern_life", "academy" }

return function(test, expect)
	test("Words fills tokens per pack, lowercases on request, keeps unknown tokens", function()
		expect.equal(PackTheme.Words("+%d {MetaCurrency}", false), "+%d Karma", "base currency")
		expect.equal(PackTheme.Words("+%d {MetaCurrency}", "modern_life"), "+%d Legacy Points", "modern currency")
		expect.equal(PackTheme.Words("your {raceName}", "academy"), "your lineage", "lowercase")
		expect.equal(PackTheme.Words("{AdvanceTierName}!", "modern_life"), "Promotion!", "advance word")
		expect.equal(PackTheme.Words("{Nope} stays", false), "{Nope} stays", "unknown token kept")
	end)

	test("server messages use the active pack's vocabulary", function()
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

	test("the creation screen is skipped when no wheel can roll", function()
		local races, legacies = Content.Get("RacesConfig"), Content.Get("FamilyLegacyConfig")
		local hadSpins = GamePack.CreationSpins().Any
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
		expect.equal(PlayerState.CreateState({}, nil).Creation.Done == true, not hadSpins, "open again only when this pack has spins")
	end)

	test("each pack has its own vocabulary", function()
		local expected = {
			{ Pack = false, EnergyName = "Qi", TierHeader = "CULTIVATION REALM", AdvanceTierButton = "BREAKTHROUGH", RaceName = "Bloodline", RebirthTab = "Samsara" },
			{ Pack = "modern_life", EnergyName = "Focus", TierHeader = "CAREER TIER", AdvanceTierButton = "PROMOTE", RaceName = "Background", RebirthTab = "Legacy" },
			{ Pack = "academy", EnergyName = "Mana", TierHeader = "RANK", AdvanceTierButton = "AWAKEN", RaceName = "Lineage", RebirthTab = "Legacy" },
		}
		for _, row in expected do
			for key, value in row do
				if key ~= "Pack" then
					expect.equal(PackTheme.Term(key, row.Pack), value, tostring(row.Pack) .. " " .. key)
				end
			end
		end
	end)

	test("missing terms fall back to the base; every pack resolves every term", function()
		local base = PackTheme.Get(false).Terms
		expect.equal(PackTheme.Term("SpiritRootTutorial", "modern_life"), base.SpiritRootTutorial, "inherited from the base")
		expect.equal(PackTheme.Term("NoSuchTerm", "academy"), "NoSuchTerm", "unknown key returns itself")
		for _, pack in PACKS do
			local terms = PackTheme.Get(pack).Terms
			for key in base do
				expect.equal(type(terms[key]), "string", tostring(pack) .. " term " .. key)
			end
		end
	end)

	test("palettes, fonts and pip shapes differ per pack and are complete", function()
		local base = PackTheme.Get(false)
		for _, pack in PACKS do
			local theme = PackTheme.Get(pack)
			for key in base.Palette do
				expect.equal(typeof(theme.Palette[key]), "Color3", tostring(pack) .. " color " .. key)
			end
			for _, role in { "Body", "Bold", "Heavy", "Title" } do
				expect.equal(typeof(PackTheme.Font(role, pack)), "EnumItem", tostring(pack) .. " font " .. role)
			end
		end
		expect.truthy(PackTheme.Get("modern_life").Palette.gold ~= base.Palette.gold, "modern accent differs")
		expect.truthy(PackTheme.Get("academy").Palette.bg1 ~= base.Palette.bg1, "academy background differs")
		expect.equal(base.Pip.Rotation, 45, "cultivation diamonds")
		expect.equal(PackTheme.Get("modern_life").Pip.Rotation, 0, "modern badges")
		expect.equal(PackTheme.Get("academy").Pip.Rotation, 15, "academy crests")
		expect.equal(PackTheme.Font("Title", false), Enum.Font.Fondamento, "base title font")
	end)

	test("pack themes never change the base theme", function()
		local gold = Content.Get("UIThemeConfig", false).Palette.gold
		local energy = Content.Get("UIThemeConfig", false).Terms.EnergyName
		Content.Get("UIThemeConfig", "modern_life")
		Content.Get("UIThemeConfig", "academy")
		expect.equal(Content.Get("UIThemeConfig", false).Palette.gold, gold, "base palette intact")
		expect.equal(Content.Get("UIThemeConfig", false).Terms.EnergyName, energy, "base terms intact")
	end)
end
