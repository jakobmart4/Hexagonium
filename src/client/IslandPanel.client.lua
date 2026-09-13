--[[
	IslandPanel.lua (LocalScript)
	Saare laienduse UI: naitab praegust suurust, jargmise laienduse
	hinda ja upgrade points'i seisu.

	KOGU MANGIJALE NAHTAV TEKST ON INGLISE KEELES.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local Theme = require(ReplicatedStorage.Shared.Theme)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Koik varvid tulevad Theme'ist
local COLORS = {
	background = Theme.UI.background,
	panel      = Theme.UI.panel,
	panelHover = Theme.UI.panelHover,
	text       = Theme.UI.text,
	textDim    = Theme.UI.textDim,
	accent     = Theme.UI.accent,
	ready      = Theme.UI.success,
	blocked    = Theme.UI.blocked,
	ocean      = Theme.UI.ocean,
}

local FONT = Theme.Font.regular
local FONT_BOLD = Theme.Font.bold

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = parent
	return c
end

local existing = playerGui:FindFirstChild("HexagoniumIslandPanel")
if existing then
	existing:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HexagoniumIslandPanel"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Paneel all paremal
local panel = Instance.new("Frame")
panel.Name = "IslandPanel"
panel.Size = UDim2.new(0, 248, 0, 130)
panel.Position = UDim2.new(1, -264, 1, -146)
panel.BackgroundColor3 = COLORS.background
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Parent = screenGui
corner(panel, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -24, 0, 20)
title.Position = UDim2.new(0, 12, 0, 8)
title.BackgroundTransparency = 1
title.Text = "ISLAND"
title.TextColor3 = COLORS.ocean
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = FONT_BOLD
title.TextSize = Theme.TextSize.label
title.Parent = panel

-- Suuruse rida
local sizeLabel = Instance.new("TextLabel")
sizeLabel.Name = "SizeLabel"
sizeLabel.Size = UDim2.new(1, -24, 0, 18)
sizeLabel.Position = UDim2.new(0, 12, 0, 28)
sizeLabel.BackgroundTransparency = 1
sizeLabel.Text = "Size 4  -  permanent 4"
sizeLabel.TextColor3 = COLORS.text
sizeLabel.TextXAlignment = Enum.TextXAlignment.Left
sizeLabel.Font = FONT_BOLD
sizeLabel.TextSize = Theme.TextSize.value
sizeLabel.Parent = panel

-- Run-laienduste rida
local runLabel = Instance.new("TextLabel")
runLabel.Name = "RunLabel"
runLabel.Size = UDim2.new(1, -24, 0, 16)
runLabel.Position = UDim2.new(0, 12, 0, 47)
runLabel.BackgroundTransparency = 1
runLabel.Text = "Expansions this run: 0 / 2"
runLabel.TextColor3 = COLORS.textDim
runLabel.TextXAlignment = Enum.TextXAlignment.Left
runLabel.Font = FONT
runLabel.TextSize = Theme.TextSize.small
runLabel.Parent = panel

-- Laiendusnupp
local expandButton = Instance.new("TextButton")
expandButton.Name = "ExpandButton"
expandButton.Size = UDim2.new(1, -24, 0, 44)
expandButton.Position = UDim2.new(0, 12, 0, 70)
expandButton.BackgroundColor3 = COLORS.panel
expandButton.BorderSizePixel = 0
expandButton.Text = ""
expandButton.AutoButtonColor = false
expandButton.Parent = panel
corner(expandButton, 6)

local buttonTitle = Instance.new("TextLabel")
buttonTitle.Name = "ButtonTitle"
buttonTitle.Size = UDim2.new(1, -16, 0, 18)
buttonTitle.Position = UDim2.new(0, 10, 0, 5)
buttonTitle.BackgroundTransparency = 1
buttonTitle.Text = "Reclaim land   " .. Theme.Hotkeys.expand
buttonTitle.TextColor3 = COLORS.text
buttonTitle.TextXAlignment = Enum.TextXAlignment.Left
buttonTitle.Font = FONT_BOLD
buttonTitle.TextSize = Theme.TextSize.body
buttonTitle.Parent = expandButton

local buttonDetail = Instance.new("TextLabel")
buttonDetail.Name = "ButtonDetail"
buttonDetail.Size = UDim2.new(1, -16, 0, 16)
buttonDetail.Position = UDim2.new(0, 10, 0, 24)
buttonDetail.BackgroundTransparency = 1
buttonDetail.Text = "0 / 40 UP"
buttonDetail.TextColor3 = COLORS.textDim
buttonDetail.TextXAlignment = Enum.TextXAlignment.Left
buttonDetail.Font = FONT
buttonDetail.TextSize = Theme.TextSize.small
buttonDetail.Parent = expandButton

local expandRemote = RemoteEvents.Get("ExpandIsland")
local stateRemote = RemoteEvents.Get("GameStateUpdate")

local canExpandNow = false

expandButton.MouseEnter:Connect(function()
	if canExpandNow then
		expandButton.BackgroundColor3 = COLORS.panelHover
	end
end)
expandButton.MouseLeave:Connect(function()
	expandButton.BackgroundColor3 = COLORS.panel
end)

expandButton.MouseButton1Click:Connect(function()
	expandRemote:FireServer()
end)

-- Hotkey: E laiendab saart
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.L then
		expandRemote:FireServer()
	end
end)

if stateRemote then
	stateRemote.OnClientEvent:Connect(function(payload)
		if not payload or not payload.island then
			return
		end

		local i = payload.island

		sizeLabel.Text = string.format("Size %d  -  permanent %d", i.activeRadius, i.metaRadius)
		runLabel.Text = string.format(
			"Expansions this run: %d / %d",
			i.runExpansions,
			i.runExpansionsMax
		)

		canExpandNow = i.canExpand

		if i.canExpand then
			buttonTitle.Text = "Reclaim land   " .. Theme.Hotkeys.expand
			buttonTitle.TextColor3 = COLORS.ready
			buttonDetail.Text = "Cost " .. Theme.Points(i.nextCost)
			buttonDetail.TextColor3 = COLORS.textDim
		else
			buttonTitle.Text = "Reclaim land   " .. Theme.Hotkeys.expand
			buttonTitle.TextColor3 = COLORS.blocked
			buttonDetail.Text = i.reason or "Unavailable"
			buttonDetail.TextColor3 = COLORS.blocked
		end
	end)
end

print("[Hexagonium] IslandPanel laaditud")
