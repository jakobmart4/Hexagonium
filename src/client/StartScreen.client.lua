--[[
	StartScreen.client.lua (LocalScript)
	Title screen: täisekraani ülekate elava 3D maailma peal (DroneCamera
	juba raamib saare kena nurga alt liitumisel - see ONGI meie "art",
	eraldi tausta ei vaja), logo üleval vasakul, Continue/stats all paremal.

	EI GATE'I SERVERIT: maailm laadib nagu alati taustal
	(Bootstrap.server.lua muutumatu vool). Ülekate lihtsalt NEELAB
	klõpsud (Active=true, kõrge DisplayOrder), kuni mängija otsustab
	jätkata.

	ANDMEVOOG: world.profileSnapshot (server, Bootstrap.server.lua)
	-> StateBroadcaster.BuildPayload()'i "profile" väli ->
	GameStateUpdate (juba olemas, korduv kanal) - EI vaja uut
	ühekordset remote'i, mis oleks race-altis.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local Theme = require(ReplicatedStorage.Shared.Theme)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT = Theme.Font.regular
local FONT_BOLD = Theme.Font.bold

-- Ainus koht, mis on kindlalt vaba: minimap (x kuni ~222) ja
-- ülemised ressursiribad (y kuni ~146) jätavad selle vaba nurga.
local COL_X = 270
local COL_WIDTH = 460

-- Vaikselt legendarne kaugustunnetus (TextStroke, mitte eraldi
-- varjufreim) - loetav ka siis kui maailm taga heledam on.
local function applyStroke(label, transparency)
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = transparency or 0.5
end

local INFO_TEXT_SIZE = Theme.TextSize.small + 12
local INFO_WIDTH = 820

local function infoLabel(parent, y, height, size, color, text)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, INFO_WIDTH, 0, height)
	label.Position = UDim2.new(0, COL_X + 2, 0, y)
	label.BackgroundTransparency = 1
	label.Text = text or ""
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = FONT
	label.TextSize = size
	label.Parent = parent
	applyStroke(label, 0.65)
	return label
end

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

-- Täisekraani tume taust, mis neelab klõpsud (Active=true). Maailm
-- jääb nähtavaks (title-screen "art" on juba olemasolev 3D vaade),
-- aga tumedam kui varem, et tekst oleks kontrastsem.
local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.new(1, 0, 1, 0)
backdrop.Position = UDim2.new(0, 0, 0, 0)
backdrop.BackgroundColor3 = Theme.UI.background
backdrop.BackgroundTransparency = 0.3
backdrop.BorderSizePixel = 0
backdrop.Active = true
backdrop.Parent = screenGui

-- ---------- Logo ----------
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(0, 700, 0, 64)
title.Position = UDim2.new(0, COL_X, 0, 150)
title.BackgroundTransparency = 1
title.Text = "HEXAGONIUM"
title.TextColor3 = Theme.UI.accent
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = FONT_BOLD
title.TextSize = 52
title.Parent = backdrop
applyStroke(title, 0.45)

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.Size = UDim2.new(0, 500, 0, 20)
subtitle.Position = UDim2.new(0, COL_X + 2, 0, 218)
subtitle.BackgroundTransparency = 1
subtitle.Text = ""
subtitle.TextColor3 = Theme.UI.textDim
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Font = FONT
subtitle.TextSize = Theme.TextSize.body
subtitle.Parent = backdrop
applyStroke(subtitle, 0.65)

-- ---------- Continue/Start + save-ülevaade (logo all) ----------
local startButton = Instance.new("TextButton")
startButton.Name = "StartButton"
startButton.Size = UDim2.new(0, COL_WIDTH, 0, 44)
startButton.Position = UDim2.new(0, COL_X, 0, 280)
startButton.BackgroundTransparency = 1
startButton.Text = "\u{203A} START"
startButton.TextColor3 = Theme.UI.success
startButton.TextXAlignment = Enum.TextXAlignment.Left
startButton.Font = FONT_BOLD
startButton.TextSize = 30
startButton.AutoButtonColor = false
startButton.Parent = backdrop
applyStroke(startButton, 0.45)

startButton.MouseEnter:Connect(function()
	startButton.TextColor3 = Theme.UI.text
end)
startButton.MouseLeave:Connect(function()
	startButton.TextColor3 = Theme.UI.success
end)
startButton.MouseButton1Click:Connect(function()
	backdrop.Visible = false
end)

-- Kaks rida: save-info (island/tutorial), siis KÕIK statid ühes reas.
local infoLine1 = infoLabel(backdrop, 340, 30, INFO_TEXT_SIZE, Theme.UI.textDim)
local infoLine2 = infoLabel(backdrop, 374, 30, INFO_TEXT_SIZE, Theme.UI.textDim)

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
Theme.ClampToViewport(menuButton)

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
	startButton.Text = (isNewPlayer and "\u{203A} START" or "\u{203A} CONTINUE")

	infoLine1.Text = string.format(
		"Island: permanent radius %d  \u{00B7}  Tutorial: %s",
		profile.metaRadius or 0,
		profile.tutorialComplete and "Complete" or "In progress"
	)
	infoLine2.Text = string.format(
		"%d runs played  \u{00B7}  %d attacks survived  \u{00B7}  %d lost  \u{00B7}  %d UP earned",
		stats.runsPlayed or 0, stats.attacksSurvived or 0, stats.buildingsLost or 0,
		stats.totalUpgradePoints or 0
	)
end)

print("[Hexagonium] StartScreen laaditud")
