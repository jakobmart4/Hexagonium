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
local Constants = require(ReplicatedStorage.Shared.Constants)
local CardInfo = require(ReplicatedStorage.Shared.CardInfo)

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
-- Muidu jaab Robloxi enda ulariba (~36px) tumeda ala kohal katmata.
screenGui.IgnoreGuiInset = true
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
title.Position = UDim2.new(0, COL_X, 0, 186)
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
subtitle.Size = UDim2.new(0, 500, 0, 32)
subtitle.Position = UDim2.new(0, COL_X + 2, 0, 254)
subtitle.BackgroundTransparency = 1
subtitle.Text = ""
subtitle.TextColor3 = Theme.UI.textDim
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Font = FONT
subtitle.TextSize = Theme.TextSize.body + 12
subtitle.Parent = backdrop
applyStroke(subtitle, 0.65)

-- ---------- Continue/Start + save-ülevaade (logo all) ----------
local startButton = Instance.new("TextButton")
startButton.Name = "StartButton"
startButton.Size = UDim2.new(0, COL_WIDTH, 0, 44)
startButton.Position = UDim2.new(0, COL_X, 0, 316)
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

-- Ulevalt-alla list: save-info, siis iga stat oma real.
local INFO_LINE_SPACING = 28
local infoSave = infoLabel(backdrop, 402, 26, INFO_TEXT_SIZE, Theme.UI.textDim)
local infoRuns = infoLabel(backdrop, 402 + INFO_LINE_SPACING, 26, INFO_TEXT_SIZE, Theme.UI.textDim)
local infoAttacks = infoLabel(backdrop, 402 + INFO_LINE_SPACING * 2, 26, INFO_TEXT_SIZE, Theme.UI.textDim)
local infoLost = infoLabel(backdrop, 402 + INFO_LINE_SPACING * 3, 26, INFO_TEXT_SIZE, Theme.UI.textDim)
local infoPoints = infoLabel(backdrop, 402 + INFO_LINE_SPACING * 4, 26, INFO_TEXT_SIZE, Theme.UI.textDim)

-- ---------- Hex Seeds: püsiv valuuta + ost (vt Constants.Meta) ----------
-- Klient kontrollib ainult tagasiside jaoks; server valideerib ostu uuesti.
local buyRemote = RemoteEvents.Get("BuyMetaUpgrade")

local infoSeeds = infoLabel(backdrop, 402 + INFO_LINE_SPACING * 5 + 12, 26, INFO_TEXT_SIZE, Theme.UI.accent)

local buyIslandButton = Instance.new("TextButton")
buyIslandButton.Name = "BuyIslandButton"
buyIslandButton.Size = UDim2.new(0, COL_WIDTH, 0, 36)
buyIslandButton.Position = UDim2.new(0, COL_X, 0, 402 + INFO_LINE_SPACING * 6 + 18)
buyIslandButton.BackgroundTransparency = 1
buyIslandButton.Text = ""
buyIslandButton.TextColor3 = Theme.UI.blocked
buyIslandButton.TextXAlignment = Enum.TextXAlignment.Left
buyIslandButton.Font = FONT_BOLD
buyIslandButton.TextSize = Theme.TextSize.body + 8
buyIslandButton.AutoButtonColor = false
buyIslandButton.Parent = backdrop
applyStroke(buyIslandButton, 0.5)

local canBuyIsland = false
buyIslandButton.MouseButton1Click:Connect(function()
	if canBuyIsland then
		buyRemote:FireServer({kind = "island"})
	end
end)

-- Lukus kaardid: 2 veergu, avatakse Hex Seeds'iga (Constants.Meta).
-- Nupud luuakse ÜKS kord algkomplekti-välistele kaartidele; render
-- uuendab ainult teksti ja värvi.
local cardGrid = Instance.new("Frame")
cardGrid.Name = "CardUnlocks"
cardGrid.Size = UDim2.new(0, 610, 0, 96)
cardGrid.Position = UDim2.new(0, COL_X, 0, 402 + INFO_LINE_SPACING * 6 + 62)
cardGrid.BackgroundTransparency = 1
cardGrid.Parent = backdrop

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 300, 0, 28)
gridLayout.CellPadding = UDim2.new(0, 10, 0, 6)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = cardGrid

local cardUnlockButtons = {} -- [cardName] = TextButton
local canBuyCard = {}         -- [cardName] = bool, ainult eelvaade

for order, cardName in ipairs(CardInfo.DisplayOrder) do
	if not CardInfo.IsUnlocked(nil, cardName) then
		local b = Instance.new("TextButton")
		b.Name = cardName
		b.LayoutOrder = order
		b.BackgroundTransparency = 1
		b.Text = ""
		b.TextColor3 = Theme.UI.blocked
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.Font = FONT_BOLD
		b.TextSize = Theme.TextSize.body + 4
		b.AutoButtonColor = false
		b.Parent = cardGrid
		applyStroke(b, 0.5)
		b.MouseButton1Click:Connect(function()
			if canBuyCard[cardName] then
				buyRemote:FireServer({kind = "card", cardName = cardName})
			end
		end)
		cardUnlockButtons[cardName] = b
	end
end

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
-- ANDMETE TÄITMINE (iga GameStateUpdate'iga - Hex Seeds ostud peavad kohe näha olema)
-- =========================================================
local stateRemote = RemoteEvents.Get("GameStateUpdate")
stateRemote.OnClientEvent:Connect(function(payload)
	if not payload or not payload.profile then
		return
	end

	local profile = payload.profile
	local stats = profile.stats or {}

	local isNewPlayer = (stats.runsPlayed or 0) == 0 and not profile.tutorialComplete
	subtitle.Text = isNewPlayer
		and "Welcome to Hexagonium."
		or "Welcome back."
	startButton.Text = (isNewPlayer and "\u{203A} START" or "\u{203A} CONTINUE")

	infoSave.Text = string.format(
		"Island: permanent radius %d  \u{00B7}  Tutorial: %s",
		profile.metaRadius or 0,
		profile.tutorialComplete and "Complete" or "In progress"
	)
	infoRuns.Text = string.format("Runs played: %d", stats.runsPlayed or 0)
	infoAttacks.Text = string.format("Attacks survived: %d", stats.attacksSurvived or 0)
	infoLost.Text = string.format("Buildings lost: %d", stats.buildingsLost or 0)
	infoPoints.Text = string.format("Lifetime UP earned: %d", stats.totalUpgradePoints or 0)

	local seeds = profile.hexSeeds or 0
	infoSeeds.Text = string.format("Hex Seeds: %d", seeds)

	-- Sama valem mis HandleBuyMetaUpgrade'is - ainult eelvaade, server otsustab
	local isl = Constants.IslandExpansion
	local radius = profile.metaRadius or isl.StartRadius
	if radius >= isl.MetaMaxRadius then
		canBuyIsland = false
		buyIslandButton.Text = "\u{203A} ISLAND  \u{00B7}  permanent maximum reached"
		buyIslandButton.TextColor3 = Theme.UI.blocked
	else
		local cost = (radius - isl.StartRadius + 1) * Constants.Meta.IslandUpgradeCostPerStep
		canBuyIsland = seeds >= cost
		buyIslandButton.Text = string.format(
			"\u{203A} GROW ISLAND to radius %d  \u{00B7}  %d %s  (next run)",
			radius + 1, cost, cost == 1 and "seed" or "seeds")
		buyIslandButton.TextColor3 = canBuyIsland and Theme.UI.success or Theme.UI.blocked
	end

	local cardCost = Constants.Meta.CardUnlockCost
	for cardName, b in pairs(cardUnlockButtons) do
		local name = CardInfo.GetDisplayName(cardName)
		if CardInfo.IsUnlocked(profile, cardName) then
			canBuyCard[cardName] = false
			b.Text = name .. "  \u{00B7}  unlocked"
			b.TextColor3 = Theme.UI.textDim
		else
			canBuyCard[cardName] = seeds >= cardCost
			b.Text = string.format("\u{203A} %s  \u{00B7}  %d seeds", name, cardCost)
			b.TextColor3 = canBuyCard[cardName] and Theme.UI.success or Theme.UI.blocked
		end
	end
end)

print("[Hexagonium] StartScreen laaditud")
