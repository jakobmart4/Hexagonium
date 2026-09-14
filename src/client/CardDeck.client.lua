--[[
	CardDeck.lua (LocalScript)
	Mangija kaardipakk: avatav paneel koigi 10 kaardiga.
	Hex-scope kaardid nouavad sihtimisrezhiimi (klopsa hexile).

	KOGU MANGIJALE NAHTAV TEKST ON INGLISE KEELES.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local CardInfo = require(ReplicatedStorage.Shared.CardInfo)
local Theme = require(ReplicatedStorage.Shared.Theme)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

-- =========================================================
-- STIIL - koik varvid tulevad Theme'ist
-- =========================================================
local COLORS = {
	background = Theme.UI.background,
	panel      = Theme.UI.panel,
	panelHover = Theme.UI.panelHover,
	text       = Theme.UI.text,
	textDim    = Theme.UI.textDim,
	accent     = Theme.UI.accent,
	active     = Theme.UI.success,
	riskHigh   = Theme.Risk.high,
	riskMedium = Theme.Risk.medium,
	riskNone   = Theme.Risk.none,
	targeting  = Theme.UI.targeting,
}

local FONT = Theme.Font.regular
local FONT_BOLD = Theme.Font.bold

local RISK_COLORS = {
	high = COLORS.riskHigh,
	medium = COLORS.riskMedium,
	none = COLORS.riskNone,
}

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = parent
	return c
end

-- =========================================================
-- GUI
-- =========================================================
local existing = playerGui:FindFirstChild("HexagoniumCardDeck")
if existing then
	existing:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HexagoniumCardDeck"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- ---------- Avamisnupp (all vasakul) ----------
local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleButton"
toggleButton.Size = UDim2.new(0, 130, 0, 42)
toggleButton.Position = UDim2.new(0, 16, 1, -58)
toggleButton.BackgroundColor3 = COLORS.background
toggleButton.BackgroundTransparency = 0.1
toggleButton.BorderSizePixel = 0
toggleButton.Text = "CARDS   " .. Theme.Hotkeys.cards
toggleButton.TextColor3 = COLORS.accent
toggleButton.Font = FONT_BOLD
toggleButton.TextSize = Theme.TextSize.body
toggleButton.AutoButtonColor = false
toggleButton.Parent = screenGui
corner(toggleButton, 8)

-- ---------- Kaardipaneel ----------
-- AnimatedPanel (CanvasGroup): sujuv fade sisse/valja, vt Theme.ShowPanel/HidePanel
local panel = Theme.AnimatedPanel(
	"DeckPanel",
	UDim2.new(0, 330, 0, 470),
	UDim2.new(0, 16, 1, -536),
	screenGui
)
Theme.ClampToViewport(panel)

local function setPanelOpen(open)
	if open then
		Theme.ShowPanel(panel, Theme.TweenTime.normal)
	else
		Theme.HidePanel(panel, Theme.TweenTime.normal)
	end
end

local panelTitle = Instance.new("TextLabel")
panelTitle.Size = UDim2.new(1, -24, 0, 26)
panelTitle.Position = UDim2.new(0, 14, 0, 10)
panelTitle.BackgroundTransparency = 1
panelTitle.Text = "REALITY CARDS"
panelTitle.TextColor3 = COLORS.accent
panelTitle.TextXAlignment = Enum.TextXAlignment.Left
panelTitle.Font = FONT_BOLD
panelTitle.TextSize = Theme.TextSize.label
panelTitle.Parent = panel

local panelHint = Instance.new("TextLabel")
panelHint.Name = "Hint"
panelHint.Size = UDim2.new(1, -24, 0, 16)
panelHint.Position = UDim2.new(0, 14, 0, 30)
panelHint.BackgroundTransparency = 1
panelHint.Text = "Click a card to activate it"
panelHint.TextColor3 = COLORS.textDim
panelHint.TextXAlignment = Enum.TextXAlignment.Left
panelHint.Font = FONT
panelHint.TextSize = Theme.TextSize.small
panelHint.Parent = panel

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -16, 1, -60)
list.Position = UDim2.new(0, 8, 0, 52)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 3
list.ScrollBarImageColor3 = COLORS.textDim
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = panel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

-- ---------- Sihtimisriba (hex-kaartide jaoks) ----------
local targetBanner = Instance.new("Frame")
targetBanner.Name = "TargetBanner"
targetBanner.Size = UDim2.new(0, 380, 0, 44)
targetBanner.Position = UDim2.new(0.5, -190, 0, 120)
targetBanner.BackgroundColor3 = COLORS.background
targetBanner.BackgroundTransparency = 0.05
targetBanner.BorderSizePixel = 0
targetBanner.Visible = false
targetBanner.Parent = screenGui
corner(targetBanner, 8)

local targetStroke = Instance.new("UIStroke")
targetStroke.Color = COLORS.targeting
targetStroke.Thickness = 2
targetStroke.Parent = targetBanner

local targetText = Instance.new("TextLabel")
targetText.Size = UDim2.new(1, -20, 1, 0)
targetText.Position = UDim2.new(0, 12, 0, 0)
targetText.BackgroundTransparency = 1
targetText.Text = "Click a hex to place the card"
targetText.TextColor3 = COLORS.targeting
targetText.TextXAlignment = Enum.TextXAlignment.Left
targetText.Font = FONT_BOLD
targetText.TextSize = Theme.TextSize.body
targetText.Parent = targetBanner

-- ---------- Teatealad ----------
local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.Size = UDim2.new(0, 380, 0, 38)
toast.Position = UDim2.new(0.5, -190, 0, 172)
toast.BackgroundColor3 = COLORS.background
toast.BackgroundTransparency = 0.05
toast.BorderSizePixel = 0
toast.Text = ""
toast.TextColor3 = COLORS.text
toast.Font = FONT_BOLD
toast.TextSize = Theme.TextSize.body
toast.Visible = false
toast.Parent = screenGui
corner(toast, 8)

local toastToken = 0
local function showToast(message, kind)
	toastToken += 1
	local myToken = toastToken

	local color = COLORS.text
	if kind == "success" then
		color = COLORS.active
	elseif kind == "warning" then
		color = COLORS.riskMedium
	elseif kind == "error" then
		color = COLORS.riskHigh
	end

	toast.Text = message
	toast.TextColor3 = color
	toast.Visible = true
	toast.BackgroundTransparency = 1
	toast.TextTransparency = 1
	Theme.Tween(toast, {BackgroundTransparency = 0.05, TextTransparency = 0}, Theme.TweenTime.fast):Play()

	task.delay(3, function()
		if toastToken == myToken then
			local tween = Theme.Tween(toast, {BackgroundTransparency = 1, TextTransparency = 1}, Theme.TweenTime.fast)
			tween.Completed:Connect(function()
				if toastToken == myToken then
					toast.Visible = false
				end
			end)
			tween:Play()
		end
	end)
end

-- =========================================================
-- OLEK
-- =========================================================
local activeCardNames = {}   -- [cardName] = true
local cardButtons = {}       -- [cardName] = {button, statusLabel}
local targetingCard = nil    -- kaardi nimi, mis ootab hex-sihtmarki

-- Saare viide: saared elavad Workspace.Islands.<nimi> all (sama muster
-- mis BuildMenu.client.lua's)
local islandFolderName = nil

local function getIslandFolder()
	if not islandFolderName then
		return nil
	end
	local root = workspace:FindFirstChild("Islands")
	return root and root:FindFirstChild(islandFolderName)
end

-- Jagatud lipp (sama mis BuildMenu's)
local targetingFlag = playerGui:FindFirstChild("HexagoniumTargeting")
if not targetingFlag then
	targetingFlag = Instance.new("BoolValue")
	targetingFlag.Name = "HexagoniumTargeting"
	targetingFlag.Value = false
	targetingFlag.Parent = playerGui
end

local activateRemote = RemoteEvents.Get("ActivateCard")
local notifyRemote = RemoteEvents.Get("Notification")
local stateRemote = RemoteEvents.Get("GameStateUpdate")

local HEX_SCOPE_CARDS = {
	BlessedHex = true,
	HexMutationWild = true,
	HexMutationStable = true,
}

-- =========================================================
-- SIHTIMISREZHIIM
-- =========================================================
local function stopTargeting()
	targetingCard = nil
	targetingFlag.Value = false
	Theme.Tween(targetText, {TextTransparency = 1}, Theme.TweenTime.fast):Play()
	Theme.Tween(targetStroke, {Transparency = 1}, Theme.TweenTime.fast):Play()
	local tween = Theme.Tween(targetBanner, {BackgroundTransparency = 1}, Theme.TweenTime.fast)
	tween.Completed:Connect(function()
		targetBanner.Visible = false
	end)
	tween:Play()
end

local function startTargeting(cardName)
	targetingCard = cardName
	targetingFlag.Value = true
	targetText.Text = string.format(
		"Placing %s  -  click a hex  -  %s or right-click to cancel",
		CardInfo.GetDisplayName(cardName),
		Theme.Hotkeys.cancel
	)
	targetBanner.Visible = true
	targetBanner.BackgroundTransparency = 1
	targetText.TextTransparency = 1
	targetStroke.Transparency = 1
	Theme.Tween(targetBanner, {BackgroundTransparency = 0.05}, Theme.TweenTime.fast):Play()
	Theme.Tween(targetText, {TextTransparency = 0}, Theme.TweenTime.fast):Play()
	Theme.Tween(targetStroke, {Transparency = 0}, Theme.TweenTime.fast):Play()
	setPanelOpen(false)
end

-- Leiab hexi hiirekursori alt
local function getHexUnderMouse()
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local islandFolder = getIslandFolder()
	if not islandFolder then
		return nil
	end
	local hexFolder = islandFolder:FindFirstChild("Hexes")
	if not hexFolder then
		return nil
	end
	params.FilterDescendantsInstances = {hexFolder}

	local result = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	if result and result.Instance then
		local q = result.Instance:GetAttribute("Q")
		local r = result.Instance:GetAttribute("R")
		if q and r then
			return q, r, result.Instance
		end
	end
	return nil
end

-- =========================================================
-- KAARDINUPUD
-- =========================================================
local function requestActivate(cardName, q, r)
	activateRemote:FireServer({
		cardName = cardName,
		q = q,
		r = r,
	})
end

local function makeCardButton(cardName, order)
	local info = CardInfo.Get(cardName)
	if not info then
		return
	end

	local button = Instance.new("TextButton")
	button.Name = cardName
	button.Size = UDim2.new(1, -6, 0, 84)
	button.BackgroundColor3 = COLORS.panel
	button.BorderSizePixel = 0
	button.Text = ""
	button.AutoButtonColor = false
	button.LayoutOrder = order
	button.Parent = list
	corner(button, 6)

	-- Riskiriba vasakus servas
	local riskBar = Instance.new("Frame")
	riskBar.Size = UDim2.new(0, 3, 1, -14)
	riskBar.Position = UDim2.new(0, 8, 0, 7)
	riskBar.BackgroundColor3 = RISK_COLORS[info.risk] or COLORS.textDim
	riskBar.BorderSizePixel = 0
	riskBar.Parent = button
	corner(riskBar, 2)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -100, 0, 18)
	nameLabel.Position = UDim2.new(0, 20, 0, 7)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = info.displayName
	nameLabel.TextColor3 = COLORS.text
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Font = FONT_BOLD
	nameLabel.TextSize = Theme.TextSize.body
	nameLabel.Parent = button

	local typeLabel = Instance.new("TextLabel")
	typeLabel.Size = UDim2.new(1, -100, 0, 14)
	typeLabel.Position = UDim2.new(0, 20, 0, 25)
	typeLabel.BackgroundTransparency = 1
	typeLabel.Text = info.cardType
	typeLabel.TextColor3 = COLORS.textDim
	typeLabel.TextXAlignment = Enum.TextXAlignment.Left
	typeLabel.Font = FONT
	typeLabel.TextSize = Theme.TextSize.small
	typeLabel.Parent = button

	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, -30, 0, 38)
	descLabel.Position = UDim2.new(0, 20, 0, 42)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = info.description
	descLabel.TextColor3 = COLORS.textDim
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.TextWrapped = true
	descLabel.Font = FONT
	descLabel.TextSize = Theme.TextSize.small
	descLabel.Parent = button

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Size = UDim2.new(0, 78, 0, 16)
	statusLabel.Position = UDim2.new(1, -86, 0, 8)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = ""
	statusLabel.TextColor3 = COLORS.active
	statusLabel.TextXAlignment = Enum.TextXAlignment.Right
	statusLabel.Font = FONT_BOLD
	statusLabel.TextSize = Theme.TextSize.small
	statusLabel.Parent = button

	button.MouseEnter:Connect(function()
		if not activeCardNames[cardName] then
			button.BackgroundColor3 = COLORS.panelHover
		end
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = COLORS.panel
	end)

	button.MouseButton1Click:Connect(function()
		if activeCardNames[cardName] then
			showToast(info.displayName .. " is already active.", "warning")
			return
		end

		if HEX_SCOPE_CARDS[cardName] then
			startTargeting(cardName)
		else
			requestActivate(cardName)
		end
	end)

	cardButtons[cardName] = {button = button, status = statusLabel}
end

for i, cardName in ipairs(CardInfo.DisplayOrder) do
	makeCardButton(cardName, i)
end

-- =========================================================
-- SISENDID
-- =========================================================
toggleButton.MouseButton1Click:Connect(function()
	if targetingCard then
		stopTargeting()
		return
	end
	setPanelOpen(not panel.Visible)
end)

toggleButton.MouseEnter:Connect(function()
	toggleButton.BackgroundColor3 = COLORS.panelHover
end)
toggleButton.MouseLeave:Connect(function()
	toggleButton.BackgroundColor3 = COLORS.background
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	local isRight = input.UserInputType == Enum.UserInputType.MouseButton2

	-- Paremkloops peab labi paasema ka gameProcessed korral
	if gameProcessed and not isRight then
		return
	end

	-- Q tuhistab sihtimise (ESC ei sobi - Roblox votab selle endale)
	if input.KeyCode == Enum.KeyCode.Q and targetingCard then
		stopTargeting()
		showToast("Placement cancelled.", "info")
		return
	end

	-- Paremkloops tuhistab samuti
	if isRight and targetingCard then
		stopTargeting()
		showToast("Placement cancelled.", "info")
		return
	end

	-- C avab/sulgeb kaardipaki
	if input.KeyCode == Enum.KeyCode.C then
		if targetingCard then
			stopTargeting()
		else
			setPanelOpen(not panel.Visible)
		end
		return
	end

	-- Vasak klopps sihtimisrezhiimis: vali hex
	if input.UserInputType == Enum.UserInputType.MouseButton1 and targetingCard then
		local q, r = getHexUnderMouse()
		if q and r then
			requestActivate(targetingCard, q, r)
			stopTargeting()
		else
			showToast("That is not a hex. Click on the grid.", "warning")
		end
	end
end)

-- =========================================================
-- SERVERI TEATED JA SEISU UUENDUS
-- =========================================================
if notifyRemote then
	notifyRemote.OnClientEvent:Connect(function(data)
		if data and data.message then
			showToast(data.message, data.kind)
		end
	end)
end

if stateRemote then
	stateRemote.OnClientEvent:Connect(function(payload)
		if not payload then
			return
		end

		if payload.islandFolder then
			islandFolderName = payload.islandFolder
		end

		if not payload.cards then
			return
		end

		local nowActive = {}
		for _, card in ipairs(payload.cards) do
			nowActive[card.name] = true
		end
		activeCardNames = nowActive

		for cardName, refs in pairs(cardButtons) do
			if nowActive[cardName] then
				refs.status.Text = "ACTIVE"
				refs.button.BackgroundColor3 = COLORS.panel
				refs.button.BackgroundTransparency = 0.45
			else
				refs.status.Text = ""
				refs.button.BackgroundTransparency = 0
			end
		end
	end)
end

print("[Hexagonium] CardDeck laaditud")
