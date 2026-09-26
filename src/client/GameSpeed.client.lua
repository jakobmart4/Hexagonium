--[[
	GameSpeed.client.lua (LocalScript)
	Play-testi kiirendus: 3 nuppu (2x / 3x / 5x) ekraani all keskel.
	Aktiivse nupu uus klõps viib tagasi 1x peale.

	AINULT STUDIOS - avaldatud mängus seda paneeli ei looda ja server
	ignoreerib päringut (PlayerActionHandler:HandleSetGameSpeed).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local Theme = require(ReplicatedStorage.Shared.Theme)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local speedRemote = RemoteEvents.Get("SetGameSpeed")

local SPEEDS = {2, 3, 5}
local BUTTON_W, BUTTON_H, GAP = 48, 30, 6

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HexagoniumGameSpeed"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local box = Instance.new("Frame")
box.Name = "SpeedBox"
box.AnchorPoint = Vector2.new(0.5, 1)
box.Position = UDim2.new(0.5, 0, 1, -16)
box.Size = UDim2.new(0, #SPEEDS * BUTTON_W + (#SPEEDS + 1) * GAP, 0, BUTTON_H + GAP * 2)
box.BackgroundColor3 = Theme.UI.background
box.BackgroundTransparency = 0.1
box.BorderSizePixel = 0
box.Parent = screenGui
Theme.Corner(box, Theme.Layout.cornerSmall)

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, GAP)
layout.Parent = box

local buttons = {}

-- Serveri tegelik kiirus (GameClock.SetSpeed seab atribuudi) - mitte
-- kliendi oletus: sagedusepiirangu taha jäänud klõps ei vii UI-d lahku.
local function currentSpeed()
	return ReplicatedStorage:GetAttribute("GameSpeed") or 1
end

local function refresh()
	local current = currentSpeed()
	for speed, button in pairs(buttons) do
		local active = speed == current
		button.BackgroundColor3 = active and Theme.UI.accent or Theme.UI.panel
		button.TextColor3 = active and Theme.UI.background or Theme.UI.text
	end
end

for i, speed in ipairs(SPEEDS) do
	local button = Instance.new("TextButton")
	button.Name = "Speed" .. speed
	button.LayoutOrder = i
	button.Size = UDim2.new(0, BUTTON_W, 0, BUTTON_H)
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = speed .. "x"
	button.Font = Theme.Font.bold
	button.TextSize = Theme.TextSize.value
	button.Parent = box
	Theme.Corner(button, Theme.Layout.cornerSmall)
	buttons[speed] = button

	button.MouseButton1Click:Connect(function()
		speedRemote:FireServer({speed = (currentSpeed() == speed) and 1 or speed})
	end)
end

ReplicatedStorage:GetAttributeChangedSignal("GameSpeed"):Connect(refresh)
refresh()
print("[Hexagonium] GameSpeed laaditud (Studio)")
