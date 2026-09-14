--[[
	Tutorial.client.lua (LocalScript)
	Vaike, mitteblokeeriv sammubanner uuele mangijale: ehita Extractor,
	uhenda see Power Core'iga, aktiveeri kaart, koge runnakut.

	Server (TutorialTracker) otsustab, mis samm on pooleli - see fail
	ainult kuvab vastava ingliskeelse vihje ja peidab end, kui
	tutorial on labi voi juba varem labitud.

	KOGU MANGIJALE NAHTAV TEKST ON INGLISE KEELES.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local Theme = require(ReplicatedStorage.Shared.Theme)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT = Theme.Font.regular

-- =========================================================
-- SAMMUDE TEKST (server teab ainult sammu numbrit, mitte teksti)
-- =========================================================
local STEP_TEXT = {
	[1] = {
		hint = string.format(
			"Build an Extractor on an Ore or Crystal hex. Press [%s] to open the build menu.",
			Theme.Hotkeys.build
		),
	},
	[2] = {
		hint = string.format(
			"Connect your Extractor to a Power Core so its energy chain can flow. Press [%s] to link nodes.",
			Theme.Hotkeys.links
		),
		flavor = "Tip: connection order sets priority when a building has multiple outputs.",
	},
	[3] = {
		hint = string.format(
			"Activate a Reality Card to bend the run's rules in your favor. Press [%s] to open your card deck.",
			Theme.Hotkeys.cards
		),
	},
	[4] = {
		hint = "The Fracture Syndicate is coming. Keep your Defender powered - losing buildings is permanent this run.",
		flavor = "Once you're steady, expand your island with UP to unlock more hexes.",
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
-- kunagi ja mida BuildMenu/CardDeck/NodeLinks'i AVATUD paneelid ei
-- kata tavalisel ekraanikorgusel (need avanevad alt ulespoole).
local panel = Theme.Panel(
	"TutorialPanel",
	UDim2.new(0, 370, 0, 108),
	UDim2.new(0, 16, 0, 248),
	screenGui
)
panel.Visible = false

local title = Theme.Title("STEP 1 / 4", panel)

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.Size = UDim2.new(1, -Theme.Layout.padding * 2, 0, 48)
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
flavorLabel.Size = UDim2.new(1, -Theme.Layout.padding * 2, 0, 16)
flavorLabel.Position = UDim2.new(0, Theme.Layout.padding, 0, 82)
flavorLabel.BackgroundTransparency = 1
flavorLabel.Text = ""
flavorLabel.TextColor3 = Theme.UI.textDim
flavorLabel.TextXAlignment = Enum.TextXAlignment.Left
flavorLabel.TextWrapped = true
flavorLabel.Font = FONT
flavorLabel.TextSize = Theme.TextSize.small
flavorLabel.Parent = panel

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
local currentStep = nil

local stateRemote = RemoteEvents.Get("GameStateUpdate")
stateRemote.OnClientEvent:Connect(function(payload)
	if not payload then
		return
	end

	local tutorial = payload.tutorial
	if not tutorial or tutorial.complete then
		panel.Visible = false
		return
	end

	if tutorial.step == currentStep then
		return
	end
	currentStep = tutorial.step

	local text = STEP_TEXT[tutorial.step]
	if not text then
		panel.Visible = false
		return
	end

	title.Text = string.format("STEP %d / %d", tutorial.step, tutorial.total)
	hintLabel.Text = text.hint
	flavorLabel.Text = text.flavor or ""
	panel.Visible = true
end)

print("[Hexagonium] Tutorial laaditud")
