--[[
	StartScreen.client.lua (LocalScript)
	Kolm vaadet ühes täisekraani ülekattes (nagu Minecraft):

	  TITLE     HEXAGONIUM + PLAY. Maailma veel POLE - server loob selle
	            alles profiili valikul (Bootstrap.startWorld).
	  PROFILES  3 profiili (SaveService.SLOTS): New / Play / Delete, Back.
	  MENU      mängu ajal: statistika, seemnepood, Resume, Back to title.
	            MENU EI PEATA run'i - maailm jookseb edasi.

	ANDMEVOOG:
	  ProfileList (server -> klient) liitumisel, kustutamisel ja pärast
	  Back to title'it -> profiilikaardid.
	  GameStateUpdate'i "profile" väli (aktiivne profiil, iga broadcast)
	  -> MENU statistika ja pood (Hex Seeds ostud näha kohe).
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

-- Tekstinupp "› TEXT" (hover -> valge)
local function textButton(parent, x, y, width, height, size, color, text)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, width, 0, height)
	b.Position = UDim2.new(0, x, 0, y)
	b.BackgroundTransparency = 1
	b.Text = text
	b.TextColor3 = color
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.Font = FONT_BOLD
	b.TextSize = size
	b.AutoButtonColor = false
	b.Parent = parent
	applyStroke(b, 0.45)
	b:SetAttribute("BaseColor", color) -- setColor muudab
	b.MouseEnter:Connect(function()
		b.TextColor3 = Theme.UI.text
	end)
	b.MouseLeave:Connect(function()
		b.TextColor3 = b:GetAttribute("BaseColor")
	end)
	return b
end

-- Kaheklõpsuline kinnitus: esimene klõps muudab teksti, teine teeb
local function confirmButton(button, normalText, confirmText, onConfirm)
	local armed = false
	button.Text = normalText
	button.MouseButton1Click:Connect(function()
		if armed then
			armed = false
			button.Text = normalText
			onConfirm()
		else
			armed = true
			button.Text = confirmText
		end
	end)
	return function() -- disarm (vaate vahetusel)
		armed = false
		button.Text = normalText
	end
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

-- Täisekraani tume taust, mis neelab klõpsud (Active=true)
local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundColor3 = Theme.UI.background
backdrop.BorderSizePixel = 0
backdrop.Active = true
backdrop.Parent = screenGui

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

local subtitle = infoLabel(backdrop, 254, 32, Theme.TextSize.body + 12, Theme.UI.textDim)

local function makeView(name)
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = UDim2.new(1, 0, 1, 0)
	f.BackgroundTransparency = 1
	f.Visible = false
	f.Parent = backdrop
	return f
end

local titleView = makeView("TitleView")
local profilesView = makeView("ProfilesView")
local menuView = makeView("MenuView")

local inGame = false
local disarmers = {}

-- Ülekatte ajal on muu UI (HUD, tutorial, ...) peidetud: title/profiilivaates
-- näitaks see vana run'i seisu, MENU-s jooksis MENU tekst paneelide peale.
-- Saar ise jääb MENU-s läbi tausta nähtavaks.
local hideOtherUi = true
local function applyOtherUi(gui)
	if gui:IsA("ScreenGui") and gui ~= screenGui then
		gui.Enabled = not hideOtherUi
	end
end
playerGui.ChildAdded:Connect(applyOtherUi)

local function show(view)
	hideOtherUi = view ~= nil
	for _, gui in ipairs(playerGui:GetChildren()) do
		applyOtherUi(gui)
	end
	for _, disarm in ipairs(disarmers) do
		disarm()
	end
	titleView.Visible = view == titleView
	profilesView.Visible = view == profilesView
	menuView.Visible = view == menuView
	backdrop.Visible = view ~= nil
	-- Title screen'il maailma pole -> peaaegu läbipaistmatu; MENU-s
	-- jääb saar nähtavaks (run jookseb edasi)
	backdrop.BackgroundTransparency = view == menuView and 0.3 or 0.08
	if view == titleView then
		subtitle.Text = "Build. Bend the rules. Extract before it falls."
	elseif view == profilesView then
		subtitle.Text = "Select a profile"
	elseif view == menuView then
		subtitle.Text = "Menu \u{00B7} the run keeps going"
	end
end

-- =========================================================
-- TITLE
-- =========================================================
local playButton = textButton(titleView, COL_X, 316, COL_WIDTH, 44, 30, Theme.UI.success, "\u{203A} PLAY")
playButton.Name = "PlayButton"
playButton.MouseButton1Click:Connect(function()
	show(profilesView)
end)

-- =========================================================
-- PROFILES
-- =========================================================
local selectRemote = RemoteEvents.Get("SelectProfile")
local deleteRemote = RemoteEvents.Get("DeleteProfile")

local ROW_HEIGHT = 64
local ROW_GAP = 12
local profileRows = {} -- [slot] = {info, play, delete}

for slot = 1, 3 do
	local y = 316 + (slot - 1) * (ROW_HEIGHT + ROW_GAP)
	local row = Instance.new("Frame")
	row.Name = "Profile" .. slot
	row.Size = UDim2.new(0, 700, 0, ROW_HEIGHT)
	row.Position = UDim2.new(0, COL_X, 0, y)
	row.BackgroundColor3 = Theme.UI.panel
	row.BackgroundTransparency = 0.2
	row.BorderSizePixel = 0
	row.Parent = profilesView
	Theme.Corner(row, Theme.Layout.cornerSmall)

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(0, 420, 0, 28)
	name.Position = UDim2.new(0, 16, 0, 6)
	name.BackgroundTransparency = 1
	name.Text = "PROFILE " .. slot
	name.TextColor3 = Theme.UI.text
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Font = FONT_BOLD
	name.TextSize = Theme.TextSize.body + 4
	name.Parent = row

	local info = Instance.new("TextLabel")
	info.Size = UDim2.new(0, 440, 0, 24)
	info.Position = UDim2.new(0, 16, 0, 34)
	info.BackgroundTransparency = 1
	info.Text = "Loading..."
	info.TextColor3 = Theme.UI.textDim
	info.TextXAlignment = Enum.TextXAlignment.Left
	info.Font = FONT
	info.TextSize = Theme.TextSize.body
	info.Parent = row

	local play = textButton(row, 470, 0, 110, ROW_HEIGHT, Theme.TextSize.body + 6, Theme.UI.success, "")
	play.Name = "Play"
	play.MouseButton1Click:Connect(function()
		inGame = true
		show(nil)
		selectRemote:FireServer({slot = slot})
	end)

	local delete = textButton(row, 580, 0, 120, ROW_HEIGHT, Theme.TextSize.body, Theme.UI.blocked, "")
	delete.Name = "Delete"
	table.insert(disarmers, confirmButton(delete, "Delete", "Confirm delete", function()
		deleteRemote:FireServer({slot = slot})
	end))

	profileRows[slot] = {info = info, play = play, delete = delete}
end

local backButton = textButton(profilesView, COL_X, 316 + 3 * (ROW_HEIGHT + ROW_GAP) + 8,
	200, 36, Theme.TextSize.body + 6, Theme.UI.textDim, "\u{2039} BACK")
backButton.Name = "BackButton"
backButton.MouseButton1Click:Connect(function()
	show(titleView)
end)

RemoteEvents.Get("ProfileList").OnClientEvent:Connect(function(list)
	for _, p in ipairs(list) do
		local row = profileRows[p.slot]
		if row then
			if p.empty then
				row.info.Text = "Empty"
				row.play.Text = "\u{203A} NEW"
				row.delete.Visible = false
			else
				local parts = {
					string.format("%d %s", p.hexSeeds, p.hexSeeds == 1 and "seed" or "seeds"),
					string.format("%d %s", p.runsPlayed, p.runsPlayed == 1 and "run" or "runs"),
					p.tutorialComplete and "tutorial done" or "tutorial in progress",
				}
				if p.lastPlayed and p.lastPlayed > 0 then
					table.insert(parts, "last played " .. os.date("%b %d", p.lastPlayed))
				end
				row.info.Text = table.concat(parts, "  \u{00B7}  ")
				row.play.Text = "\u{203A} PLAY"
				row.delete.Visible = true
			end
		end
	end

	-- Liitumisel või pärast Back to title'it: tagasi title screen'ile
	if inGame or not backdrop.Visible then
		inGame = false
		show(titleView)
	end
end)

-- =========================================================
-- MENU (mängu ajal): Resume, Back to title, statistika, seemnepood
-- =========================================================
local resumeButton = textButton(menuView, COL_X, 316, 220, 44, 30, Theme.UI.success, "\u{203A} RESUME")
resumeButton.Name = "ResumeButton"
resumeButton.MouseButton1Click:Connect(function()
	show(nil)
end)

local returnRemote = RemoteEvents.Get("ReturnToTitle")
local toTitleButton = textButton(menuView, COL_X + 260, 322, 460, 36, Theme.TextSize.body + 6,
	Theme.UI.textDim, "")
toTitleButton.Name = "ToTitleButton"
table.insert(disarmers, confirmButton(toTitleButton, "\u{2039} BACK TO TITLE",
	"\u{2039} Click again: this run ends, no reward", function()
		returnRemote:FireServer()
	end))

local INFO_LINE_SPACING = 28
local infoSave = infoLabel(menuView, 402, 26, INFO_TEXT_SIZE, Theme.UI.textDim)
local infoRuns = infoLabel(menuView, 402 + INFO_LINE_SPACING, 26, INFO_TEXT_SIZE, Theme.UI.textDim)
local infoAttacks = infoLabel(menuView, 402 + INFO_LINE_SPACING * 2, 26, INFO_TEXT_SIZE, Theme.UI.textDim)
local infoLost = infoLabel(menuView, 402 + INFO_LINE_SPACING * 3, 26, INFO_TEXT_SIZE, Theme.UI.textDim)
local infoPoints = infoLabel(menuView, 402 + INFO_LINE_SPACING * 4, 26, INFO_TEXT_SIZE, Theme.UI.textDim)

-- ---------- Hex Seeds: püsiv valuuta + ost (vt Constants.Meta) ----------
-- Klient kontrollib ainult tagasiside jaoks; server valideerib ostu uuesti.
local buyRemote = RemoteEvents.Get("BuyMetaUpgrade")

local infoSeeds = infoLabel(menuView, 402 + INFO_LINE_SPACING * 5 + 12, 26, INFO_TEXT_SIZE, Theme.UI.accent)

local buyIslandButton = textButton(menuView, COL_X, 402 + INFO_LINE_SPACING * 6 + 18, COL_WIDTH + 200, 36,
	Theme.TextSize.body + 8, Theme.UI.blocked, "")
buyIslandButton.Name = "BuyIslandButton"

local canBuyIsland = false
buyIslandButton.MouseButton1Click:Connect(function()
	if canBuyIsland then
		buyRemote:FireServer({kind = "island"})
	end
end)

-- Lukus kaardid: 2 veergu. Nupud luuakse ÜKS kord algkomplekti-välistele
-- kaartidele; render uuendab ainult teksti ja värvi.
local cardGrid = Instance.new("Frame")
cardGrid.Name = "CardUnlocks"
cardGrid.Size = UDim2.new(0, 610, 0, 96)
cardGrid.Position = UDim2.new(0, COL_X, 0, 402 + INFO_LINE_SPACING * 6 + 62)
cardGrid.BackgroundTransparency = 1
cardGrid.Parent = menuView

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 300, 0, 28)
gridLayout.CellPadding = UDim2.new(0, 10, 0, 6)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = cardGrid

local cardUnlockButtons = {} -- [cardName] = TextButton
local canBuyCard = {}         -- [cardName] = bool, ainult eelvaade

for order, cardName in ipairs(CardInfo.DisplayOrder) do
	if not CardInfo.IsUnlocked(nil, cardName) then
		local b = textButton(cardGrid, 0, 0, 0, 0, Theme.TextSize.body + 4, Theme.UI.blocked, "")
		b.Name = cardName
		b.LayoutOrder = order
		b.MouseButton1Click:Connect(function()
			if canBuyCard[cardName] then
				buyRemote:FireServer({kind = "card", cardName = cardName})
			end
		end)
		cardUnlockButtons[cardName] = b
	end
end

-- Värv, mis jääb pärast hover'it (textButton loeb BaseColor'it)
local function setColor(b, color)
	b.TextColor3 = color
	b:SetAttribute("BaseColor", color)
end

-- =========================================================
-- ALUMINE-VASAK "MENU" NUPP (ainult mängus).
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
	show(menuView)
end)

backdrop:GetPropertyChangedSignal("Visible"):Connect(function()
	menuButton.Visible = inGame and not backdrop.Visible
end)

-- =========================================================
-- MENU ANDMED (iga GameStateUpdate'iga - Hex Seeds ostud peavad kohe näha olema)
-- =========================================================
RemoteEvents.Get("GameStateUpdate").OnClientEvent:Connect(function(payload)
	if not payload or not payload.profile then
		return
	end

	local profile = payload.profile
	local stats = profile.stats or {}

	infoSave.Text = string.format(
		"Island expansions per run: %d  \u{00B7}  Tutorial: %s",
		Constants.IslandExpansion.RunExpansionsMax + (profile.bonusExpansions or 0),
		profile.tutorialComplete and "Complete" or "In progress"
	)
	infoRuns.Text = string.format("Runs played: %d", stats.runsPlayed or 0)
	infoAttacks.Text = string.format("Attacks survived: %d", stats.attacksSurvived or 0)
	infoLost.Text = string.format("Buildings lost: %d", stats.buildingsLost or 0)
	infoPoints.Text = string.format("Lifetime UP earned: %d", stats.totalUpgradePoints or 0)

	local seeds = profile.hexSeeds or 0
	infoSeeds.Text = string.format("SEED SHOP  \u{00B7}  you have %d Hex %s",
		seeds, seeds == 1 and "Seed" or "Seeds")

	-- Sama valem mis HandleBuyMetaUpgrade'is - ainult eelvaade, server otsustab
	local isl = Constants.IslandExpansion
	local bonus = profile.bonusExpansions or 0
	if bonus >= isl.MetaExpansionsMax then
		canBuyIsland = false
		buyIslandButton.Text = "+1 ISLAND EXPANSION per run  \u{00B7}  OWNED (max)"
		setColor(buyIslandButton, Theme.UI.textDim)
	else
		local cost = (bonus + 1) * Constants.Meta.IslandUpgradeCostPerStep
		canBuyIsland = seeds >= cost
		buyIslandButton.Text = string.format(
			"\u{203A} +1 ISLAND EXPANSION per run  \u{00B7}  %d %s",
			cost, cost == 1 and "seed" or "seeds")
		setColor(buyIslandButton, canBuyIsland and Theme.UI.success or Theme.UI.blocked)
	end

	local cardCost = Constants.Meta.CardUnlockCost
	for cardName, b in pairs(cardUnlockButtons) do
		local name = CardInfo.GetDisplayName(cardName)
		if CardInfo.IsUnlocked(profile, cardName) then
			canBuyCard[cardName] = false
			b.Text = name .. "  \u{00B7}  OWNED"
			setColor(b, Theme.UI.textDim)
		else
			canBuyCard[cardName] = seeds >= cardCost
			b.Text = string.format("\u{203A} %s  \u{00B7}  %d seeds", name, cardCost)
			setColor(b, canBuyCard[cardName] and Theme.UI.success or Theme.UI.blocked)
		end
	end
end)

show(titleView)
menuButton.Visible = false

print("[Hexagonium] StartScreen laaditud")
