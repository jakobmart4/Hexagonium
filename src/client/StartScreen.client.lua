--[[
	StartScreen.client.lua (LocalScript)
	Peamenüü / start screen: täisekraani ülekate, mis näitab
	salvestuse ülevaadet ja elu-aegset statistikat, kuni mängija
	klõpsab Start/Continue.

	EI GATE'I SERVERIT: maailm laadib nagu alati taustal
	(Bootstrap.server.lua muutumatu vool). Ülekate lihtsalt NEELAB
	klõpsud (Active=true, kõrge DisplayOrder), kuni mängija otsustab
	jätkata - visuaalselt sama efekt, ilma serveripoolset
	käivitusvoogu puutumata.

	ANDMEVOOG: world.profileSnapshot (server, Bootstrap.server.lua)
	-> StateBroadcaster.BuildPayload()'i "profile" väli ->
	GameStateUpdate (juba olemas, korduv kanal) - EI vaja uut
	ühekordset remote'i, mis oleks race-altis (vt CLAUDE.md 13.-laadsed
	lõksud: hiline kuulaja jääks ühekordsest FireClient'ist ilma).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local Theme = require(ReplicatedStorage.Shared.Theme)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT = Theme.Font.regular
local FONT_BOLD = Theme.Font.bold

-- =========================================================
-- GUI
-- =========================================================
local existing = playerGui:FindFirstChild("HexagoniumStartScreen")
if existing then
	existing:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HexagoniumStartScreen"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 100 -- kindlasti koige teise UI peal
screenGui.Parent = playerGui

-- Täisekraani tume taust, mis neelab klõpsud (Active=true)
local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.new(1, 0, 1, 0)
backdrop.Position = UDim2.new(0, 0, 0, 0)
backdrop.BackgroundColor3 = Theme.UI.background
backdrop.BackgroundTransparency = 0.15
backdrop.BorderSizePixel = 0
backdrop.Active = true
backdrop.Parent = screenGui

local panel = Theme.Panel(
	"StartPanel",
	UDim2.new(0, 420, 0, 340),
	UDim2.new(0.5, -210, 0.5, -170),
	backdrop
)

local title = Theme.Title("HEXAGONIUM", panel)
title.TextSize = Theme.TextSize.large
title.Font = FONT_BOLD

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.Size = UDim2.new(1, -Theme.Layout.padding * 2, 0, 16)
subtitle.Position = UDim2.new(0, Theme.Layout.padding, 0, 32)
subtitle.BackgroundTransparency = 1
subtitle.Text = ""
subtitle.TextColor3 = Theme.UI.textDim
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Font = FONT
subtitle.TextSize = Theme.TextSize.small
subtitle.Parent = panel

local function makeSectionLabel(text, y)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -Theme.Layout.padding * 2, 0, 16)
	label.Position = UDim2.new(0, Theme.Layout.padding, 0, y)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Theme.UI.accent
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = FONT_BOLD
	label.TextSize = Theme.TextSize.label
	label.Parent = panel
	return label
end

local function makeRow(y)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -Theme.Layout.padding * 2, 0, 18)
	label.Position = UDim2.new(0, Theme.Layout.padding, 0, y)
	label.BackgroundTransparency = 1
	label.Text = ""
	label.TextColor3 = Theme.UI.text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = FONT
	label.TextSize = Theme.TextSize.body
	label.Parent = panel
	return label
end

makeSectionLabel("SAVE FILE", 58)
local islandRow = makeRow(78)
local tutorialRow = makeRow(98)

makeSectionLabel("LIFETIME STATS", 126)
local runsRow = makeRow(146)
local attacksRow = makeRow(166)
local lostRow = makeRow(186)
local pointsRow = makeRow(206)

local startButton = Instance.new("TextButton")
startButton.Name = "StartButton"
startButton.Size = UDim2.new(1, -Theme.Layout.padding * 2, 0, 44)
startButton.Position = UDim2.new(0, Theme.Layout.padding, 1, -60)
startButton.BackgroundColor3 = Theme.UI.panel
startButton.BorderSizePixel = 0
startButton.Text = "START"
startButton.TextColor3 = Theme.UI.success
startButton.Font = FONT_BOLD
startButton.TextSize = Theme.TextSize.value
startButton.AutoButtonColor = false
startButton.Parent = panel
Theme.Corner(startButton, Theme.Layout.cornerSmall)

startButton.MouseEnter:Connect(function()
	startButton.BackgroundColor3 = Theme.UI.panelHover
end)
startButton.MouseLeave:Connect(function()
	startButton.BackgroundColor3 = Theme.UI.panel
end)
startButton.MouseButton1Click:Connect(function()
	backdrop.Visible = false
end)

-- =========================================================
-- ALUMINE-VASAK "MENU" NUPP: taasavab ülekatte igal ajal.
-- Samas reas mis CARDS (x=16) / BUILD (x=156) / LINKS (x=296),
-- vt CardDeck/BuildMenu/NodeLinks.client.lua.
-- =========================================================
local menuButton = Instance.new("TextButton")
menuButton.Name = "MenuButton"
menuButton.Size = UDim2.new(0, 130, 0, 42)
menuButton.Position = UDim2.new(0, 436, 1, -58)
menuButton.BackgroundColor3 = Theme.UI.background
menuButton.BackgroundTransparency = 0.1
menuButton.BorderSizePixel = 0
menuButton.Text = "MENU"
menuButton.TextColor3 = Theme.UI.accent
menuButton.Font = FONT_BOLD
menuButton.TextSize = Theme.TextSize.body
menuButton.AutoButtonColor = false
menuButton.Parent = screenGui
Theme.Corner(menuButton, Theme.Layout.cornerSmall)

menuButton.MouseEnter:Connect(function()
	menuButton.BackgroundColor3 = Theme.UI.panelHover
end)
menuButton.MouseLeave:Connect(function()
	menuButton.BackgroundColor3 = Theme.UI.background
end)
menuButton.MouseButton1Click:Connect(function()
	backdrop.Visible = true
end)

-- =========================================================
-- ANDMETE TÄITMINE (üks kord, esimesel profiili saabumisel)
-- =========================================================
local receivedProfile = false

local stateRemote = RemoteEvents.Get("GameStateUpdate")
stateRemote.OnClientEvent:Connect(function(payload)
	if not payload or not payload.profile or receivedProfile then
		return
	end
	receivedProfile = true

	local profile = payload.profile
	local stats = profile.stats or {}

	local isNewPlayer = (stats.runsPlayed or 0) == 0 and not profile.tutorialComplete
	subtitle.Text = isNewPlayer
		and "Welcome to Hexagonium."
		or "Welcome back."
	startButton.Text = isNewPlayer and "START" or "CONTINUE"

	islandRow.Text = string.format("Island: permanent radius %d", profile.metaRadius or 0)
	tutorialRow.Text = "Tutorial: " .. (profile.tutorialComplete and "Complete" or "In progress")

	runsRow.Text = string.format("Runs played: %d", stats.runsPlayed or 0)
	attacksRow.Text = string.format("Attacks survived: %d", stats.attacksSurvived or 0)
	lostRow.Text = string.format("Buildings lost: %d", stats.buildingsLost or 0)
	pointsRow.Text = string.format("Lifetime UP earned: %d", stats.totalUpgradePoints or 0)
end)

print("[Hexagonium] StartScreen laaditud")
