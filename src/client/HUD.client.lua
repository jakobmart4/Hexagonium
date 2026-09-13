--[[
	HUD.lua (LocalScript)
	Ehitab mangija HUD-i koodiga (mitte Studio GUI redaktoris),
	et see oleks versioonihallatav ja korratav.

	PAIGUTUS:
	  Ulemine riba  - ressursid (ore, crystal, alloy) + energia-riba
	  Parem paneel  - aktiivsed kaardid koos faasiga
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local Theme = require(ReplicatedStorage.Shared.Theme)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- =========================================================
-- STIIL - koik varvid tulevad Theme'ist, mitte siit
-- =========================================================
local COLORS = {
	background   = Theme.UI.background,
	panel        = Theme.UI.panel,
	text         = Theme.UI.text,
	textDim      = Theme.UI.textDim,
	ore          = Theme.Resources.Ore,
	crystal      = Theme.Resources.Crystal,
	alloy        = Theme.Resources.Alloy,
	upgrade      = Theme.Resources.UpgradePoints,
	energy       = Theme.UI.energy,
	energyLow    = Theme.UI.energyLow,
	accent       = Theme.UI.accent,
	warning      = Theme.UI.warning,
}

local FONT = Theme.Font.regular
local FONT_BOLD = Theme.Font.bold

-- =========================================================
-- ABIFUNKTSIOONID
-- =========================================================
local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = parent
	return c
end

local function padding(parent, px)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.Parent = parent
	return p
end

-- =========================================================
-- GUI EHITAMINE
-- =========================================================
local existing = playerGui:FindFirstChild("HexagoniumHUD")
if existing then
	existing:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HexagoniumHUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
-- IgnoreGuiInset: vaikimisi lukatakse kogu ScreenGui Robloxi
-- ularibast (~36px) allapoole. Meil pole seal midagi, mis segaks,
-- seega votame selle ruumi kasutusele.
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- ---------------------------------------------------------
-- ULEMINE RIBA: ressursid
-- ---------------------------------------------------------
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(0, 600, 0, 54)
topBar.Position = UDim2.new(0.5, -300, 0, 8)
topBar.BackgroundColor3 = COLORS.background
topBar.BackgroundTransparency = 0.1
topBar.BorderSizePixel = 0
topBar.Parent = screenGui
corner(topBar, 8)

local topLayout = Instance.new("UIListLayout")
topLayout.FillDirection = Enum.FillDirection.Horizontal
topLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
topLayout.VerticalAlignment = Enum.VerticalAlignment.Center
topLayout.SortOrder = Enum.SortOrder.LayoutOrder
topLayout.Padding = UDim.new(0, 4)
topLayout.Parent = topBar

-- Loob uhe ressursinaidiku, tagastab TextLabeli vaartuse jaoks
local function makeResourceDisplay(name, color, order)
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.Size = UDim2.new(0, 142, 1, -12)
	holder.BackgroundColor3 = COLORS.panel
	holder.BorderSizePixel = 0
	holder.LayoutOrder = order
	holder.Parent = topBar
	corner(holder, 6)

	local dot = Instance.new("Frame")
	dot.Size = UDim2.new(0, 8, 0, 8)
	dot.Position = UDim2.new(0, 10, 0.5, -4)
	dot.BackgroundColor3 = color
	dot.BorderSizePixel = 0
	dot.Parent = holder
	corner(dot, 4)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -28, 0, 14)
	label.Position = UDim2.new(0, 24, 0, 5)
	label.BackgroundTransparency = 1
	label.Text = name:upper()
	label.TextColor3 = COLORS.textDim
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = FONT
	label.TextSize = Theme.TextSize.label
	label.Parent = holder

	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.Size = UDim2.new(1, -28, 0, 22)
	value.Position = UDim2.new(0, 24, 0, 21)
	value.BackgroundTransparency = 1
	value.Text = "0"
	value.TextColor3 = COLORS.text
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.Font = FONT_BOLD
	value.TextSize = Theme.TextSize.large
	value.Parent = holder

	return value
end

local oreValue     = makeResourceDisplay("Ore", COLORS.ore, 1)
local crystalValue = makeResourceDisplay("Crystal", COLORS.crystal, 2)
local alloyValue   = makeResourceDisplay("Alloy", COLORS.alloy, 3)
local upgradeValue = makeResourceDisplay("Upgrades", COLORS.upgrade, 4)

-- ---------------------------------------------------------
-- ENERGIA-RIBA (ulemise riba all)
-- ---------------------------------------------------------
local energyBar = Instance.new("Frame")
energyBar.Name = "EnergyBar"
energyBar.Size = UDim2.new(0, 600, 0, 32)
energyBar.Position = UDim2.new(0.5, -300, 0, 66)
energyBar.BackgroundColor3 = COLORS.background
energyBar.BackgroundTransparency = 0.1
energyBar.BorderSizePixel = 0
energyBar.Parent = screenGui
corner(energyBar, 8)

local energyLabel = Instance.new("TextLabel")
energyLabel.Size = UDim2.new(0, 70, 1, 0)
energyLabel.Position = UDim2.new(0, 12, 0, 0)
energyLabel.BackgroundTransparency = 1
energyLabel.Text = "ENERGY"
energyLabel.TextColor3 = COLORS.textDim
energyLabel.TextXAlignment = Enum.TextXAlignment.Left
energyLabel.Font = FONT
energyLabel.TextSize = Theme.TextSize.label
energyLabel.Parent = energyBar

local energyTrack = Instance.new("Frame")
energyTrack.Size = UDim2.new(1, -230, 0, 10)
energyTrack.Position = UDim2.new(0, 88, 0.5, -5)
energyTrack.BackgroundColor3 = COLORS.panel
energyTrack.BorderSizePixel = 0
energyTrack.Parent = energyBar
corner(energyTrack, 5)

local energyFill = Instance.new("Frame")
energyFill.Name = "Fill"
energyFill.Size = UDim2.new(1, 0, 1, 0)
energyFill.BackgroundColor3 = COLORS.energy
energyFill.BorderSizePixel = 0
energyFill.Parent = energyTrack
corner(energyFill, 5)

local energyText = Instance.new("TextLabel")
energyText.Name = "EnergyText"
energyText.Size = UDim2.new(0, 132, 1, 0)
energyText.Position = UDim2.new(1, -140, 0, 0)
energyText.BackgroundTransparency = 1
energyText.Text = "0 / 0"
energyText.TextColor3 = COLORS.text
energyText.TextXAlignment = Enum.TextXAlignment.Right
energyText.Font = FONT_BOLD
energyText.TextSize = Theme.TextSize.value
energyText.Parent = energyBar

-- ---------------------------------------------------------
-- PAREM PANEEL: aktiivsed kaardid
-- Algab allpool ulemist riba (y=120), et kitsal ekraanil
-- ressursiribaga mitte kokku joosta.
-- ---------------------------------------------------------
local cardPanel = Instance.new("Frame")
cardPanel.Name = "CardPanel"
cardPanel.Size = UDim2.new(0, 210, 0, 300)
cardPanel.Position = UDim2.new(1, -226, 0, 8)
cardPanel.BackgroundColor3 = COLORS.background
cardPanel.BackgroundTransparency = 0.1
cardPanel.BorderSizePixel = 0
cardPanel.Parent = screenGui
corner(cardPanel, 8)

local cardTitle = Instance.new("TextLabel")
cardTitle.Size = UDim2.new(1, -20, 0, 28)
cardTitle.Position = UDim2.new(0, 12, 0, 6)
cardTitle.BackgroundTransparency = 1
cardTitle.Text = "ACTIVE CARDS"
cardTitle.TextColor3 = COLORS.accent
cardTitle.TextXAlignment = Enum.TextXAlignment.Left
cardTitle.Font = FONT_BOLD
cardTitle.TextSize = Theme.TextSize.label
cardTitle.Parent = cardPanel

local cardList = Instance.new("ScrollingFrame")
cardList.Name = "CardList"
cardList.Size = UDim2.new(1, -16, 1, -44)
cardList.Position = UDim2.new(0, 8, 0, 36)
cardList.BackgroundTransparency = 1
cardList.BorderSizePixel = 0
cardList.ScrollBarThickness = 3
cardList.ScrollBarImageColor3 = COLORS.textDim
cardList.CanvasSize = UDim2.new(0, 0, 0, 0)
cardList.AutomaticCanvasSize = Enum.AutomaticSize.Y
cardList.Parent = cardPanel

local cardLayout = Instance.new("UIListLayout")
cardLayout.Padding = UDim.new(0, 5)
cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
cardLayout.Parent = cardList

local emptyLabel = Instance.new("TextLabel")
emptyLabel.Name = "EmptyLabel"
emptyLabel.Size = UDim2.new(1, 0, 0, 40)
emptyLabel.BackgroundTransparency = 1
emptyLabel.Text = "No cards active"
emptyLabel.TextColor3 = COLORS.textDim
emptyLabel.Font = FONT
emptyLabel.TextSize = Theme.TextSize.small
emptyLabel.TextWrapped = true
emptyLabel.Parent = cardList

-- =========================================================
-- ANDMETE UUENDAMINE
-- =========================================================
local cardEntries = {}

local function formatNumber(n)
	if n >= 1000 then
		return string.format("%.1fk", n / 1000)
	end
	return string.format("%.0f", n)
end

local function updateCards(cards)
	-- Eemalda vanad kirjed
	for _, entry in pairs(cardEntries) do
		entry:Destroy()
	end
	cardEntries = {}

	emptyLabel.Visible = (#cards == 0)

	for i, card in ipairs(cards) do
		local entry = Instance.new("Frame")
		entry.Size = UDim2.new(1, -6, 0, 46)
		entry.BackgroundColor3 = COLORS.panel
		entry.BorderSizePixel = 0
		entry.LayoutOrder = i
		entry.Parent = cardList
		corner(entry, 5)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -16, 0, 18)
		nameLabel.Position = UDim2.new(0, 8, 0, 5)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = card.name
		nameLabel.TextColor3 = COLORS.text
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Font = FONT_BOLD
		nameLabel.TextSize = Theme.TextSize.body
		nameLabel.Parent = entry

		local detail = card.scope
		if card.scope == "hex" and card.targetQ then
			detail = string.format("hex (%d, %d)", card.targetQ, card.targetR)
		end
		if card.phase and card.phase ~= "idle" and card.phase ~= "normal" then
			detail = detail .. "  -  " .. string.upper(card.phase)
		end

		local detailLabel = Instance.new("TextLabel")
		detailLabel.Size = UDim2.new(1, -16, 0, 16)
		detailLabel.Position = UDim2.new(0, 8, 0, 24)
		detailLabel.BackgroundTransparency = 1
		detailLabel.Text = detail
		detailLabel.TextColor3 = (card.phase == "effect" or card.phase == "bonus")
			and COLORS.accent
			or (card.phase == "lag" or card.phase == "penalty")
			and COLORS.warning
			or COLORS.textDim
		detailLabel.TextXAlignment = Enum.TextXAlignment.Left
		detailLabel.Font = FONT
		detailLabel.TextSize = Theme.TextSize.small
		detailLabel.Parent = entry

		table.insert(cardEntries, entry)
	end
end

local remote = RemoteEvents.Get("GameStateUpdate")

remote.OnClientEvent:Connect(function(payload)
	if not payload then
		return
	end

	-- Ressursid
	local res = payload.resources or {}
	oreValue.Text = formatNumber(res.Ore or 0)
	crystalValue.Text = formatNumber(res.Crystal or 0)
	alloyValue.Text = formatNumber(res.Alloy or 0)
	upgradeValue.Text = formatNumber(res.UpgradePoints or 0)

	-- Energia
	local e = payload.energy or {current = 0, max = 0}
	local pct = (e.max > 0) and (e.current / e.max) or 0
	energyFill.Size = UDim2.new(pct, 0, 1, 0)
	energyFill.BackgroundColor3 = e.paused and COLORS.energyLow or COLORS.energy
	energyText.Text = string.format("%d / %d", math.floor(e.current), math.floor(e.max))
	if e.paused then
		energyText.Text = energyText.Text .. "  (OFFLINE)"
		energyText.TextColor3 = COLORS.energyLow
	else
		energyText.TextColor3 = COLORS.text
	end

	-- Kaardid
	updateCards(payload.cards or {})
end)

print("[Hexagonium] HUD laaditud")
