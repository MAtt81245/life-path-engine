--[[
	Mobile and tablet support (Shared/Responsive): device profiles and the UI scale
	StarterPlayerScripts/ResponsiveUI applies. Sizes are real device viewports.
]]

local Responsive = require(game:GetService("ReplicatedStorage").Shared.Responsive)

return function(test, expect)
	test("phones, tablets and desktops get the right profile", function()
		local cases = {
			{ "iPhone 13 landscape", Vector2.new(844, 390), true, "Phone" },
			{ "iPhone 13 portrait", Vector2.new(390, 844), true, "Phone" },
			{ "Galaxy A16", Vector2.new(780, 360), true, "Phone" },
			{ "iPad A16", Vector2.new(1180, 820), true, "Tablet" },
			{ "Galaxy Tab A8", Vector2.new(960, 600), true, "Tablet" },
			{ "1080p monitor", Vector2.new(1920, 1080), false, "Desktop" },
			{ "small laptop window", Vector2.new(800, 450), false, "Desktop" },
		}
		for _, case in cases do
			expect.equal(Responsive.Profile(case[2], case[3]).Kind, case[4], case[1])
		end
	end)

	test("UI scale follows the screen against 1280x720, within limits", function()
		expect.near(Responsive.Profile(Vector2.new(1280, 720), false).Scale, 1, 1e-6, "base resolution")
		expect.near(Responsive.Profile(Vector2.new(1920, 1080), false).Scale, 1.5, 1e-6, "1080p")
		expect.near(Responsive.Profile(Vector2.new(1180, 820), true).Scale, 1180 / 1280, 1e-6, "iPad: limited by width")
		expect.equal(Responsive.Profile(Vector2.new(844, 390), true).Scale, Responsive.MinScale, "phone: floor")
		expect.equal(Responsive.Profile(Vector2.new(3840, 2160), false).Scale, Responsive.MaxScale, "4K: ceiling")
	end)

	test("touch targets and readable text meet mobile guidelines", function()
		expect.truthy(Responsive.TouchTarget >= 44, "44 px minimum (Apple HIG)")
		expect.truthy(Responsive.MinReadableText >= 9, "readable floor")
		expect.equal(Responsive.Profile(Vector2.new(844, 390), true).TouchTarget, Responsive.TouchTarget, "profile carries it")
	end)
end
