--[[
	Tutorial.client.lua (LocalScript)
	Mitteblokeeriv sammubanner uuele mangijale (9 sammu): algbaas, ehitus,
	uhendus, kaart, Demand, runnakud, laiendus, run'i lopp, Hex Seeds.

	Server (TutorialTracker) otsustab, mis samm on pooleli ja kas see on
	infosamm ("Next"-nupp) - see fail ainult kuvab vastava ingliskeelse
	vihje ja peidab end, kui tutorial on labi voi juba varem labitud.

	Numbrid tekstides tulevad Constants'ist ja kiirklahvid Theme'ist -
	mitte kasitsi kirjutatud, et balansi muutmisel ei hakkaks tekst valetama.

	KOGU MANGIJALE NAHTAV TEKST ON INGLISE KEELES.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Constants = require(ReplicatedStorage.Shared.Constants)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT = Theme.Font.regular
local FONT_BOLD = Theme.Font.bold
local KEYS = Theme.Hotkeys

-- =========================================================
-- SAMMUDE TEKST (server teab ainult sammu numbrit ja tüüpi)
-- =========================================================
local DESTROYED_PERCENT = math.floor(Constants.Run.PayoutDestroyed * 100 + 0.5)

local STEP_TEXT = {
	[1] = {
		hint = "Your base already runs two chains: Crystal -> Power Core -> Defender (energy), and Ore -> Refinery -> Assembler -> UP. UP is your currency.",
		flavor = string.format("Tip: press [%s] to see every link and what it carries.", KEYS.links),
	},
	[2] = {
		hint = string.format("Build an Extractor on an Ore or Crystal hex. Press [%s] to open the build menu.", KEYS.build),
		flavor = "Tip: Ore and Crystal hexes are colored on the ground - build costs are shown on each button.",
	},
	[3] = {
		hint = string.format("Link your new Extractor to what uses its resource: Crystal -> Power Core, Ore -> Refinery. Press [%s] to link.", KEYS.links),
		flavor = "Tip: link order sets priority when a building has several outputs.",
	},
	[4] = {
		hint = string.format("Activate a Reality Card to bend this run's rules. Press [%s] to open your deck.", KEYS.cards),
		flavor = "Tip: more cards unlock with Hex Seeds in MENU.",
	},
	[5] = {
		hint = "The Fracture Syndicate will demand ore and crystal. Pay to keep the peace, or Refuse and get ready to fight.",
		flavor = "Ignoring a demand counts as refusing.",
	},
	[6] = {
		hint = "Attacks destroy buildings for the rest of the run. Defenders shoot attackers, but only while a Power Core feeds them energy.",
		flavor = "Attacks grow stronger every minute - add Defenders over time.",
	},
	[7] = {
		hint = string.format("Expand your island with [%s]. More land means more resources, but UP spent here is not spent on production.", KEYS.expand),
		flavor = "Each expansion costs more than the last.",
	},
	[8] = {
		hint = string.format("End the run with EXTRACT when the risk feels too high. You keep the full reward - if your base is destroyed, only %d%%.", DESTROYED_PERCENT),
		flavor = "Your reward grows every minute you survive.",
	},
	[9] = {
		hint = string.format("Every %d run reward becomes 1 Hex Seed - at least %d if your base survives. Spend seeds in MENU on extra expansion slots and more cards.", Constants.Meta.SeedsPerPayout, Constants.Meta.MinSeedsPerRun),
		flavor = "Seeds and purchases carry over between runs.",
	},
}

-- =========================================================
-- GUI
-- =========================================================
local existing = playerGui:FindFirstChild("HexagoniumTutorial")
if existing then
	existing:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HexagoniumTutorial"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Vasak veerg, Island Map'i (Minimap.client.lua, 16,16 - 206x224) alla:
-- see on ainus koht, mida HUD/RunPanel/CardPanel/FactionPanel ei kata
-- kunagi. Korgem kui varem, sest tekstid on pikemad ja all on Next-nupp.
local panel = Theme.AnimatedPanel(
	"TutorialPanel",
	UDim2.new(0, 370, 0, 170),
	UDim2.new(0, 16, 0, 248),
	screenGui
)
Theme.ClampToViewport(panel)

local title = Theme.Title("STEP 1 / 9", panel)

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.Size = UDim2.new(1, -Theme.Layout.padding * 2, 0, 66)
hintLabel.Position = UDim2.new(0, Theme.Layout.padding, 0, 32)
hintLabel.BackgroundTransparency = 1
hintLabel.Text = ""
hintLabel.TextColor3 = Theme.UI.text
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.TextYAlignment = Enum.TextYAlignment.Top
hintLabel.TextWrapped = true
hintLabel.Font = FONT
hintLabel.TextSize = Theme.TextSize.body
hintLabel.Parent = panel

local flavorLabel = Instance.new("TextLabel")
flavorLabel.Name = "Flavor"
flavorLabel.Size = UDim2.new(1, -Theme.Layout.padding * 2, 0, 32)
flavorLabel.Position = UDim2.new(0, Theme.Layout.padding, 0, 100)
flavorLabel.BackgroundTransparency = 1
flavorLabel.Text = ""
flavorLabel.TextColor3 = Theme.UI.textDim
flavorLabel.TextXAlignment = Enum.TextXAlignment.Left
flavorLabel.TextWrapped = true
flavorLabel.Font = FONT
flavorLabel.TextSize = Theme.TextSize.small
flavorLabel.Parent = panel

-- Next/Finish: nähtav ainult infosammul (server ütleb isInfo)
local nextButton = Instance.new("TextButton")
nextButton.Name = "Next"
nextButton.Size = UDim2.new(0, 72, 0, 22)
nextButton.Position = UDim2.new(1, -84, 0, 136)
nextButton.BackgroundColor3 = Theme.UI.panelHover
nextButton.BorderSizePixel = 0
nextButton.Text = "Next"
nextButton.TextColor3 = Theme.UI.accent
nextButton.Font = FONT_BOLD
nextButton.TextSize = Theme.TextSize.small
nextButton.AutoButtonColor = false
nextButton.Visible = false
nextButton.Parent = panel
Theme.Corner(nextButton, Theme.Layout.cornerSmall)

-- Progressiriba: visuaalne vaste "STEP N/9" tekstile
local progressTrack = Instance.new("Frame")
progressTrack.Name = "ProgressTrack"
progressTrack.Size = UDim2.new(1, -Theme.Layout.padding * 2, 0, 3)
progressTrack.Position = UDim2.new(0, Theme.Layout.padding, 1, -7)
progressTrack.BackgroundColor3 = Theme.UI.panelHover
progressTrack.BorderSizePixel = 0
progressTrack.Parent = panel
Theme.Corner(progressTrack, 2)

local progressFill = Instance.new("Frame")
progressFill.Name = "Fill"
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = Theme.UI.accent
progressFill.BorderSizePixel = 0
progressFill.Parent = progressTrack
Theme.Corner(progressFill, 2)

-- Vaike tekstlink, mitte täisnupp - ei tohi hinttekstiga konkureerida
local skipButton = Instance.new("TextButton")
skipButton.Name = "Skip"
skipButton.Size = UDim2.new(0, 40, 0, 16)
skipButton.Position = UDim2.new(1, -52, 0, 8)
skipButton.BackgroundTransparency = 1
skipButton.Text = "Skip"
skipButton.TextColor3 = Theme.UI.textDim
skipButton.Font = FONT
skipButton.TextSize = Theme.TextSize.small
skipButton.AutoButtonColor = false
skipButton.Parent = panel

skipButton.MouseEnter:Connect(function()
	skipButton.TextColor3 = Theme.UI.text
end)
skipButton.MouseLeave:Connect(function()
	skipButton.TextColor3 = Theme.UI.textDim
end)

local skipRemote = RemoteEvents.Get("SkipTutorial")
skipButton.MouseButton1Click:Connect(function()
	skipRemote:FireServer()
end)

-- =========================================================
-- UUENDAMINE
-- =========================================================
local advanceRemote = RemoteEvents.Get("AdvanceTutorial")
local currentStep = nil

nextButton.MouseButton1Click:Connect(function()
	if currentStep then
		-- Server kontrollib, et see on päriselt praegune infosamm
		advanceRemote:FireServer({step = currentStep})
	end
end)

local stateRemote = RemoteEvents.Get("GameStateUpdate")
stateRemote.OnClientEvent:Connect(function(payload)
	if not payload then
		return
	end

	local tutorial = payload.tutorial
	if not tutorial or tutorial.complete then
		if panel.Visible then
			Theme.HidePanel(panel, Theme.TweenTime.normal)
		end
		return
	end

	if tutorial.step == currentStep then
		return
	end
	local wasVisible = panel.Visible
	currentStep = tutorial.step

	local text = STEP_TEXT[tutorial.step]
	if not text then
		if panel.Visible then
			Theme.HidePanel(panel, Theme.TweenTime.normal)
		end
		return
	end

	title.Text = string.format("STEP %d / %d", tutorial.step, tutorial.total)
	hintLabel.Text = text.hint
	flavorLabel.Text = text.flavor or ""
	nextButton.Visible = tutorial.isInfo == true
	nextButton.Text = tutorial.step == tutorial.total and "Finish" or "Next"
	Theme.Tween(progressFill, {Size = UDim2.new(tutorial.step / tutorial.total, 0, 1, 0)}, Theme.TweenTime.normal):Play()

	if wasVisible then
		-- Paneel oli juba nahtav - vilgatus tombab tahelepanu uuele sammule
		title.TextColor3 = Theme.UI.warning
		local flash = Theme.Tween(title, {TextColor3 = Theme.UI.accent}, Theme.TweenTime.slow)
		flash:Play()
	else
		Theme.ShowPanel(panel, Theme.TweenTime.normal)
	end
end)

print("[Hexagonium] Tutorial laaditud")
