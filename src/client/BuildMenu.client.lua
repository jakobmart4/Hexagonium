--[[
	BuildMenu.lua (LocalScript)
	Mangija ehitusmenuu: vali hoone, klopsa hexile.

	Sihtimisrezhiimis naidatakse kursori all olevat hexi esile:
	roheline = saab ehitada, punane = ei saa. Nii saab mangija
	kohese tagasiside ENNE klopsamist, mitte alles veateatena.

	KOGU MANGIJALE NAHTAV TEKST ON INGLISE KEELES.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local BuildingInfo = require(ReplicatedStorage.Shared.BuildingInfo)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Theme = require(ReplicatedStorage.Shared.Theme)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local FONT = Theme.Font.regular
local FONT_BOLD = Theme.Font.bold

local HIGHLIGHT_OK = Theme.UI.success
local HIGHLIGHT_BAD = Theme.UI.error

local function corner(parent, radius)
	return Theme.Corner(parent, radius)
end

-- =========================================================
-- GUI
-- =========================================================
local existing = playerGui:FindFirstChild("HexagoniumBuildMenu")
if existing then
	existing:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HexagoniumBuildMenu"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Avamisnupp (CARDS nupu korval)
local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleButton"
toggleButton.Size = UDim2.new(0, 130, 0, 42)
toggleButton.Position = UDim2.new(0, 156, 1, -58)
toggleButton.BackgroundColor3 = Theme.UI.background
toggleButton.BackgroundTransparency = 0.1
toggleButton.BorderSizePixel = 0
toggleButton.Text = "BUILD   " .. Theme.Hotkeys.build
toggleButton.TextColor3 = Theme.UI.success
toggleButton.Font = FONT_BOLD
toggleButton.TextSize = Theme.TextSize.body
toggleButton.AutoButtonColor = false
toggleButton.Parent = screenGui
corner(toggleButton, 8)

-- Menuupaneel (suurus/asukoht: Theme.FitLeftColumn)
local panel = Theme.AnimatedPanel("BuildPanel", UDim2.new(), UDim2.new(), screenGui)
Theme.FitLeftColumn(panel, 156, 320, 480)

local function setPanelOpen(open)
	if open then
		Theme.ShowPanel(panel, Theme.TweenTime.normal)
	else
		Theme.HidePanel(panel, Theme.TweenTime.normal)
	end
end

local panelTitle = Instance.new("TextLabel")
panelTitle.Size = UDim2.new(1, -24, 0, 24)
panelTitle.Position = UDim2.new(0, 14, 0, 10)
panelTitle.BackgroundTransparency = 1
panelTitle.Text = "BUILDINGS"
panelTitle.TextColor3 = Theme.UI.success
panelTitle.TextXAlignment = Enum.TextXAlignment.Left
panelTitle.Font = FONT_BOLD
panelTitle.TextSize = Theme.TextSize.label
panelTitle.Parent = panel

local panelHint = Instance.new("TextLabel")
panelHint.Size = UDim2.new(1, -24, 0, 16)
panelHint.Position = UDim2.new(0, 14, 0, 30)
panelHint.BackgroundTransparency = 1
panelHint.Text = "Pick a building, then click a hex"
panelHint.TextColor3 = Theme.UI.textDim
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
list.ScrollBarImageColor3 = Theme.UI.textDim
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = panel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

-- Sihtimisriba
local banner = Instance.new("Frame")
banner.Size = UDim2.new(0, 400, 0, 44)
banner.Position = UDim2.new(0.5, -200, 0, 168)
banner.BackgroundColor3 = Theme.UI.background
banner.BackgroundTransparency = 0.05
banner.BorderSizePixel = 0
banner.Visible = false
banner.Parent = screenGui
Theme.ClampToViewport(banner)
corner(banner, 8)

local bannerStroke = Instance.new("UIStroke")
bannerStroke.Color = Theme.UI.success
bannerStroke.Thickness = 2
bannerStroke.Parent = banner

local bannerText = Instance.new("TextLabel")
bannerText.Size = UDim2.new(1, -20, 1, 0)
bannerText.Position = UDim2.new(0, 12, 0, 0)
bannerText.BackgroundTransparency = 1
bannerText.Text = ""
bannerText.TextColor3 = Theme.UI.success
bannerText.TextXAlignment = Enum.TextXAlignment.Left
bannerText.Font = FONT_BOLD
bannerText.TextSize = Theme.TextSize.body
bannerText.Parent = banner

-- =========================================================
-- OLEK
-- =========================================================
local selectedBuilding = nil
local buildRemote = RemoteEvents.Get("BuildBuilding")

-- Jagatud lipp: kontekstimenuu ei tohi avaneda sihtimisrezhiimis.
-- BoolValue PlayerGui's, et koik kliendiskriptid naeksid sama olekut.
local targetingFlag = playerGui:FindFirstChild("HexagoniumTargeting")
if not targetingFlag then
	targetingFlag = Instance.new("BoolValue")
	targetingFlag.Name = "HexagoniumTargeting"
	targetingFlag.Value = false
	targetingFlag.Parent = playerGui
end

-- Esiletostmine kursori all oleval hexil
local highlight = Instance.new("Highlight")
highlight.Name = "HexHighlight"
highlight.FillTransparency = 0.55
highlight.OutlineTransparency = 0
highlight.Enabled = false
highlight.Parent = screenGui

local occupiedHexes = {}   -- ["q,r"] = true, uuendatakse serverist
local availablePoints = 0  -- PointBank saldo, serverist
local costLabels = {}      -- [buildingType] = TextLabel
local builtCounts = {}     -- [buildingType] = elusate arv (BuildLimits jaoks)

-- Saare viide: saared elavad Workspace.Islands.<nimi> all
local islandFolderName = nil

local function getIslandFolder()
	if not islandFolderName then
		return nil
	end
	local root = workspace:FindFirstChild("Islands")
	return root and root:FindFirstChild(islandFolderName)
end

-- =========================================================
-- HEXI TUVASTAMINE KURSORI ALL
-- =========================================================
local function getHexUnderMouse()
	local folder = getIslandFolder()
	local hexes = folder and folder:FindFirstChild("Hexes")
	if not hexes then
		return nil
	end

	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {hexes}

	local result = workspace:Raycast(ray.Origin, ray.Direction * 800, params)
	if result and result.Instance then
		return result.Instance
	end
	return nil
end

-- Kliendipoolne eelkontroll. Server valideerib ikka uuesti -
-- see on ainult kohese tagasiside jaoks.
local function canBuildHere(hexPart, buildingType)
	if not hexPart then
		return false, "No hex under cursor"
	end

	if hexPart:GetAttribute("Locked") == true then
		return false, "Still underwater"
	end

	local q, r = hexPart:GetAttribute("Q"), hexPart:GetAttribute("R")
	if occupiedHexes[q .. "," .. r] then
		return false, "Hex already occupied"
	end

	local limit = Constants.BuildLimits[buildingType]
	if limit and (builtCounts[buildingType] or 0) >= limit then
		return false, string.format("Only %d allowed", limit)
	end

	local info = BuildingInfo.Get(buildingType)
	if info and info.requiresResourceHex then
		local hexType = hexPart:GetAttribute("HexType")
		if hexType ~= "OreHex" and hexType ~= "CrystalHex" then
			return false, "Needs an ore or crystal hex"
		end
	end

	-- Hind: kliendipoolne eelkontroll, server valideerib uuesti
	local cost = Constants.BuildCosts[buildingType] or 0
	if cost > availablePoints then
		return false, string.format("Need %s, have %d",
			Theme.Points(cost), math.floor(availablePoints))
	end

	return true, nil
end

-- =========================================================
-- SIHTIMISREZHIIM
-- =========================================================
local function stopTargeting()
	selectedBuilding = nil
	targetingFlag.Value = false
	Theme.Tween(bannerText, {TextTransparency = 1}, Theme.TweenTime.fast):Play()
	Theme.Tween(bannerStroke, {Transparency = 1}, Theme.TweenTime.fast):Play()
	local tween = Theme.Tween(banner, {BackgroundTransparency = 1}, Theme.TweenTime.fast)
	tween.Completed:Connect(function()
		banner.Visible = false
	end)
	tween:Play()
	highlight.Enabled = false
	highlight.Adornee = nil
end

local function startTargeting(buildingType)
	selectedBuilding = buildingType
	targetingFlag.Value = true
	banner.Visible = true
	banner.BackgroundTransparency = 1
	bannerText.TextTransparency = 1
	bannerStroke.Transparency = 1
	Theme.Tween(banner, {BackgroundTransparency = 0.05}, Theme.TweenTime.fast):Play()
	Theme.Tween(bannerText, {TextTransparency = 0}, Theme.TweenTime.fast):Play()
	Theme.Tween(bannerStroke, {Transparency = 0}, Theme.TweenTime.fast):Play()
	setPanelOpen(false)
end

-- Iga kaader: uuenda esiletostmist ja riba teksti
RunService.RenderStepped:Connect(function()
	if not selectedBuilding then
		return
	end

	local hexPart = getHexUnderMouse()
	local ok, reason = canBuildHere(hexPart, selectedBuilding)

	if hexPart then
		highlight.Adornee = hexPart
		highlight.Enabled = true
		highlight.FillColor = ok and HIGHLIGHT_OK or HIGHLIGHT_BAD
		highlight.OutlineColor = ok and HIGHLIGHT_OK or HIGHLIGHT_BAD
	else
		highlight.Enabled = false
		highlight.Adornee = nil
	end

	local name = BuildingInfo.GetDisplayName(selectedBuilding)
	if ok then
		bannerText.Text = string.format(
			"Placing %s  -  click to build  -  %s or right-click to cancel",
			name, Theme.Hotkeys.cancel)
		bannerText.TextColor3 = Theme.UI.success
		bannerStroke.Color = Theme.UI.success
	else
		bannerText.Text = string.format("%s  -  %s", name, reason or "Cannot build here")
		bannerText.TextColor3 = Theme.UI.warning
		bannerStroke.Color = Theme.UI.warning
	end
end)

-- =========================================================
-- HOONETE NUPUD
-- =========================================================
local function makeBuildingButton(buildingType, order)
	local info = BuildingInfo.Get(buildingType)
	if not info then
		return
	end

	local button = Instance.new("TextButton")
	button.Name = buildingType
	button.Size = UDim2.new(1, -6, 0, 86)
	button.BackgroundColor3 = Theme.UI.panel
	button.BorderSizePixel = 0
	button.Text = ""
	button.AutoButtonColor = false
	button.LayoutOrder = order
	button.Parent = list
	corner(button, 6)

	-- Varviriba, mis vastab hoone varvile maailmas
	local colorKey = "building" .. buildingType
	local swatch = Instance.new("Frame")
	swatch.Size = UDim2.new(0, 4, 1, -14)
	swatch.Position = UDim2.new(0, 8, 0, 7)
	swatch.BackgroundColor3 = Theme.World[colorKey] or Theme.UI.textDim
	swatch.BorderSizePixel = 0
	swatch.Parent = button
	corner(swatch, 2)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -30, 0, 18)
	nameLabel.Position = UDim2.new(0, 22, 0, 7)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = info.displayName
	nameLabel.TextColor3 = Theme.UI.text
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Font = FONT_BOLD
	nameLabel.TextSize = Theme.TextSize.body
	nameLabel.Parent = button

	local taglineLabel = Instance.new("TextLabel")
	taglineLabel.Size = UDim2.new(1, -30, 0, 14)
	taglineLabel.Position = UDim2.new(0, 22, 0, 25)
	taglineLabel.BackgroundTransparency = 1
	taglineLabel.Text = info.tagline
	taglineLabel.TextColor3 = Theme.UI.accent
	taglineLabel.TextXAlignment = Enum.TextXAlignment.Left
	taglineLabel.Font = FONT
	taglineLabel.TextSize = Theme.TextSize.small
	taglineLabel.Parent = button

	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, -32, 0, 40)
	descLabel.Position = UDim2.new(0, 22, 0, 42)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = info.description
	descLabel.TextColor3 = Theme.UI.textDim
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.TextWrapped = true
	descLabel.Font = FONT
	descLabel.TextSize = Theme.TextSize.small
	descLabel.Parent = button
	Theme.GrowWithText(button, descLabel)

	local costLabel = Instance.new("TextLabel")
	costLabel.Name = "Cost"
	costLabel.Size = UDim2.new(0, 90, 0, 18)
	costLabel.Position = UDim2.new(1, -98, 0, 7)
	costLabel.BackgroundTransparency = 1
	costLabel.Text = Theme.Points(Constants.BuildCosts[buildingType] or 0)
	costLabel.TextColor3 = Theme.Resources.UpgradePoints
	costLabel.TextXAlignment = Enum.TextXAlignment.Right
	costLabel.Font = FONT_BOLD
	costLabel.TextSize = Theme.TextSize.body
	costLabel.Parent = button
	costLabels[buildingType] = costLabel

	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = Theme.UI.panelHover
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = Theme.UI.panel
	end)

	button.MouseButton1Click:Connect(function()
		startTargeting(buildingType)
	end)
end

for i, buildingType in ipairs(BuildingInfo.DisplayOrder) do
	makeBuildingButton(buildingType, i)
end

-- =========================================================
-- SISENDID
-- =========================================================
toggleButton.MouseButton1Click:Connect(function()
	if selectedBuilding then
		stopTargeting()
		return
	end
	setPanelOpen(not panel.Visible)
end)

toggleButton.MouseEnter:Connect(function()
	toggleButton.BackgroundColor3 = Theme.UI.panelHover
end)
toggleButton.MouseLeave:Connect(function()
	toggleButton.BackgroundColor3 = Theme.UI.background
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	local isRight = input.UserInputType == Enum.UserInputType.MouseButton2

	-- Paremkloops peab labi paasema ka gameProcessed korral,
	-- muidu ei saa sihtimist katkestada (vt DroneCamera kommentaar)
	if gameProcessed and not isRight then
		return
	end

	-- Q tuhistab sihtimise (ESC ei sobi - Roblox votab selle endale)
	if input.KeyCode == Enum.KeyCode.Q and selectedBuilding then
		stopTargeting()
		return
	end

	if input.KeyCode == Enum.KeyCode.B then
		if selectedBuilding then
			stopTargeting()
		else
			setPanelOpen(not panel.Visible)
		end
		return
	end

	-- Paremkloops tuhistab samuti (RTS-tavaparane)
	if isRight and selectedBuilding then
		stopTargeting()
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 and selectedBuilding then
		local hexPart = getHexUnderMouse()
		local ok = canBuildHere(hexPart, selectedBuilding)
		if ok and hexPart then
			buildRemote:FireServer({
				buildingType = selectedBuilding,
				q = hexPart:GetAttribute("Q"),
				r = hexPart:GetAttribute("R"),
			})
			-- Jaa sihtimisrezhiimi, et saaks mitu hoonet jarjest ehitada
		end
	end
end)

-- =========================================================
-- SERVERI SEIS: milline hex on hoivatud
-- =========================================================
local stateRemote = RemoteEvents.Get("GameStateUpdate")
if stateRemote then
	stateRemote.OnClientEvent:Connect(function(payload)
		if not payload then
			return
		end

		if payload.buildings then
			local newOccupied = {}
			local counts = {}
			for _, b in ipairs(payload.buildings) do
				if b.q and b.r then
					newOccupied[b.q .. "," .. b.r] = true
				end
				counts[b.buildingType] = (counts[b.buildingType] or 0) + 1
			end
			occupiedHexes = newOccupied
			builtCounts = counts
		end

		if payload.islandFolder then
			islandFolderName = payload.islandFolder
		end

		-- Punktide saldo: varvi hinnad selle jargi, mida saab lubada
		if payload.resources then
			availablePoints = payload.resources.UpgradePoints or 0
			for buildingType, label in pairs(costLabels) do
				local cost = Constants.BuildCosts[buildingType] or 0
				local limit = Constants.BuildLimits[buildingType]
				if limit and (builtCounts[buildingType] or 0) >= limit then
					-- Ehituspiirang täis (nt Town Hall on juba olemas)
					label.Text = "BUILT"
					label.TextColor3 = Theme.UI.textDim
				else
					label.Text = Theme.Points(cost)
					label.TextColor3 = (cost <= availablePoints)
						and Theme.Resources.UpgradePoints
						or Theme.UI.error
				end
			end
		end
	end)
end

print("[Hexagonium] BuildMenu laaditud")
