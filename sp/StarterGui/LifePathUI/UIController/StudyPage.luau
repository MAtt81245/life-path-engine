--[[
	Study & Career tab: current education, further education options,
	current job and job listings with requirements.
]]

local Page = {}

local ctx, root, S, C, Config

local function scale(x, y) return UDim2.fromScale(x, y) end

local function actionRow(parent, order: number, size: UDim2, title: string, requirementText: string, buttonText: string, enabled: boolean, onClick)
	local row = S.panel("Frame", { Name = "Row", LayoutOrder = order, Size = size, Parent = parent }, C.panel1, C.panel2, 10)
	S.padding(row, 8)
	S.label({ Name = "Title", Text = title, Font = S.Fonts.Bold, Size = scale(0.72, 0.45), Parent = row }, 14)
	S.label({ Name = "Req", Text = requirementText, RichText = true, TextColor3 = C.muted, Position = scale(0, 0.5), Size = scale(0.72, 0.5), Parent = row }, 12)
	local button = S.button({ Name = "Action", Text = buttonText, AnchorPoint = Vector2.new(1, 0.5), Position = scale(1, 0.5), Size = scale(0.25, 0.72), Parent = row }, nil, nil, 14)
	S.setEnabled(button, enabled)
	button.Activated:Connect(function()
		if enabled then
			onClick()
		end
	end)
	return row
end

function Page.Init(context, frame)
	ctx, root = context, frame
	S, Config = ctx.Style, ctx.Config
	C = S.C
	local education, career = root.EducationPanel, root.CareerPanel
	local hasEducation, hasCareers = ctx.GamePack.IsEnabled("Education"), ctx.GamePack.IsEnabled("Careers")
	education.Visible = hasEducation
	career.Visible = hasCareers
	if hasCareers and not hasEducation then
		career.Position, career.Size = UDim2.fromScale(0, 0), UDim2.fromScale(1, 1)
	elseif hasEducation and not hasCareers then
		education.Size = UDim2.fromScale(1, 1)
	end
	education.StudyButton.Activated:Connect(function() ctx.Remotes.Train:FireServer("StudyHard") end)
	education.DropButton.Activated:Connect(function() ctx.Remotes.CareerAction:FireServer("DropOut") end)
	career.OvertimeButton.Activated:Connect(function() ctx.Remotes.Train:FireServer("WorkOvertime") end)
	career.QuitButton.Activated:Connect(function() ctx.Remotes.CareerAction:FireServer("QuitJob") end)
end

function Page.Render(s)
	local Studies = Config.Studies
	local education, careerPanel = root.EducationPanel, root.CareerPanel
	local edu = s.Education
	local tier = edu.Enrolled and Studies.TiersById[edu.Tier]

	if tier then
		education.TierLabel.Text = tier.Name
		local tuition = if tier.TuitionPerYear > 0 then ("  ·  Tuition %s/yr (free at honors grades)"):format(S.money(tier.TuitionPerYear)) else ""
		education.DetailLabel.Text = ("Year %d of %d%s"):format(math.min(edu.Years + 1, tier.Duration), tier.Duration, tuition)
		education.PerfValue.Text = ("%d / 100"):format(math.floor(edu.Performance))
		S.setBar(education.PerfBar.Fill, edu.Performance / 100)
	else
		education.TierLabel.Text = "Not enrolled"
		education.DetailLabel.Text = if s.Age < 3 then "Too young for school." else "Apply for further education below."
		education.PerfValue.Text = "—"
		S.setBar(education.PerfBar.Fill, 0)
	end
	S.setEnabled(education.StudyButton, tier ~= nil and not s.Dead and s.Actions >= 1 and (s.ActionCounts.StudyHard or 0) < 1)
	S.setEnabled(education.DropButton, tier ~= nil and not s.Dead)

	S.clear(education.OptionsList)
	local order = 0
	-- How you learn (SchoolingConfig): one mode a year, ages MinAge-MaxAge.
	local schooling = ctx.Content.Get("SchoolingConfig")
	local data = (s.Modules and s.Modules.Schooling) or {}
	local current = data.Mode or schooling.Default
	if s.Age >= schooling.MinAge and s.Age <= schooling.MaxAge then
		for _, mode in schooling.Modes do
			order += 1
			local price = if mode.Cost > 0 then S.money(mode.Cost) .. "/yr" else "free"
			local need = if mode.MinMoney then ("  -  needs %s"):format(S.money(mode.MinMoney)) else ""
			local enabled = mode.Id ~= current and not s.Dead and (not mode.MinMoney or s.Money >= mode.MinMoney)
			actionRow(education.OptionsList, order, UDim2.new(1, -8, 0, 52), ("%s  -  %s"):format(mode.Name, price),
				mode.Description .. need .. (if mode.Id == current and data.LastGain then "  -  last year: " .. data.LastGain else ""),
				if mode.Id == current then "Current" else "Choose", enabled, function()
					ctx.Remotes.SchoolingAction:FireServer("Mode", mode.Id)
				end)
		end
	end
	for _, option in Studies.Tiers do
		if not option.Auto then
			order += 1
			local met, items = ctx.Requirements.Evaluate(s, option.Requires)
			local done = s.Graduated[option.Id]
			local current = tier and tier.Id == option.Id
			local price = if option.TuitionPerYear > 0 then S.money(option.TuitionPerYear) .. "/yr" else "Free"
			local label = if done then "Completed" elseif current then "Enrolled" else "Enroll"
			local enabled = met and not done and not edu.Enrolled and not s.Dead
			actionRow(education.OptionsList, order, UDim2.new(1, -8, 0, 56), ("%s  ·  %d yrs  ·  %s"):format(option.Name, option.Duration, price),
				S.requirementText(items), label, enabled, function()
					ctx.Remotes.CareerAction:FireServer("Enroll", option.Id)
				end)
		end
	end

	local completed = {}
	for _, t in Studies.Tiers do
		if s.Graduated[t.Id] then
			table.insert(completed, t.Name .. (if s.Honors[t.Id] then " (Honors)" else ""))
		end
	end
	education.HistoryLabel.Text = "Completed: " .. (if #completed > 0 then table.concat(completed, ", ") else "none")

	-- Career
	careerPanel.StatusLabel.Text = "Social status: " .. s.SocialStatus
	local career = s.Career.Id and Studies.CareersById[s.Career.Id]
	if career then
		careerPanel.JobLabel.Text = career.Name
		careerPanel.JobDetail.Text = ("Salary %s / year  ·  %d year%s%s"):format(S.money(s.Career.Salary), s.Career.Years,
			if s.Career.Years == 1 then "" else "s", if career.PartTime then "  ·  Part-time" else "")
		careerPanel.JobPerfValue.Text = ("%d / 100"):format(math.floor(s.Career.Performance))
		S.setBar(careerPanel.JobPerfBar.Fill, s.Career.Performance / 100)
	else
		careerPanel.JobLabel.Text = "Unemployed"
		careerPanel.JobDetail.Text = if s.Age < Studies.MinWorkingAge then ("You can work from age %d."):format(Studies.MinWorkingAge) else "Apply for a job below."
		careerPanel.JobPerfValue.Text = "—"
		S.setBar(careerPanel.JobPerfBar.Fill, 0)
	end
	S.setEnabled(careerPanel.OvertimeButton, career ~= nil and not s.Dead and s.Actions >= 1 and (s.ActionCounts.WorkOvertime or 0) < 1)
	S.setEnabled(careerPanel.QuitButton, career ~= nil and not s.Dead)

	S.clear(careerPanel.JobsScroll)
	for i, job in Studies.Careers do
		local met, items = ctx.Requirements.Evaluate(s, job.Requires)
		local isCurrent = s.Career.Id == job.Id
		local enabled = met and not isCurrent and not s.Dead and s.Age >= Studies.MinWorkingAge and (job.PartTime or not edu.Enrolled)
		local title = ("%s  ·  %s/yr%s"):format(job.Name, S.money(job.Salary), if job.PartTime then "  ·  Part-time" else "")
		actionRow(careerPanel.JobsScroll, i, UDim2.new(1, -8, 0, 60), title, S.requirementText(items),
			if isCurrent then "Current" else "Apply", enabled, function()
				ctx.Remotes.CareerAction:FireServer("ApplyJob", job.Id)
			end)
	end
end

return Page
