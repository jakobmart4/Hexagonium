--[[
	RunPanel.lua (LocalScript)
	Run'i taimer, kogunev tasu ja Extract nupp.

	AHNUSE-MOMENT:
	Paneel naitab korraga kolme asja - kui palju tasu on kogutud,
	kui palju jargmine minut annab, ja kui tugevaks runnakud on
	kasvanud. Mangija naeb seega korraga notu JA riski, mis teebki
	Extract'i otsuseks.

	KOGU MANGIJALE NAHTAV TEKST ON INGLISE KEELES.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local Theme = require(ReplicatedStorage.Shared.Theme)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT = Theme.Font.regular
local FONT_BOLD = Theme.Font.bold

local extractRemote = RemoteEvents.Get("ExtractRun")
local stateRemote = RemoteEvents.Get("GameStateUpdate")

local existing = playerGui:FindFirstChild("HexagoniumRunPanel")
if existing then
	existing:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HexagoniumRunPanel"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- =========================================================
-- RUN-RIBA (ulal keskel, ressursiriba all)
-- =========================================================
local panel = Theme.AnimatedPanel(
	"RunBar",
	UDim2.new(0, 600, 0, 38),
	UDim2.new(0.5, -300, 0, 104),
	screenGui
)
Theme.ClampToViewport(panel)
-- Erinevalt CardDeck/Tutorial paneelidest on RunBar ALGUSEST PEALE
-- nahtav (jooksva run'i riba) - fade kehtib ainult hilisemate
-- lopp-ekraani/taaskaivituse ULEMINEKUTE kohta, mitte esmasel laadimisel.
panel.Visible = true
panel.GroupTransparency = 0

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Theme.UI.error
panelStroke.Thickness = 2
panelStroke.Transparency = 1
panelStroke.Parent = panel

-- Aeg
local timeLabel = Instance.new("TextLabel")
timeLabel.Size = UDim2.new(0, 100, 1, 0)
timeLabel.Position = UDim2.new(0, 12, 0, 0)
timeLabel.BackgroundTransparency = 1
timeLabel.Text = "0:00"
timeLabel.TextColor3 = Theme.UI.text
timeLabel.TextXAlignment = Enum.TextXAlignment.Left
timeLabel.Font = FONT_BOLD
timeLabel.TextSize = Theme.TextSize.value
timeLabel.Parent = panel

-- Kogutud tasu
local rewardLabel = Instance.new("TextLabel")
rewardLabel.Size = UDim2.new(0, 160, 1, 0)
rewardLabel.Position = UDim2.new(0, 114, 0, 0)
rewardLabel.BackgroundTransparency = 1
rewardLabel.Text = "Banked 0 UP"
rewardLabel.TextColor3 = Theme.UI.success
rewardLabel.TextXAlignment = Enum.TextXAlignment.Left
rewardLabel.Font = FONT_BOLD
rewardLabel.TextSize = Theme.TextSize.body
rewardLabel.Parent = panel

-- Jargmise minuti vaartus (notu kasv)
local gainLabel = Instance.new("TextLabel")
gainLabel.Size = UDim2.new(0, 150, 1, 0)
gainLabel.Position = UDim2.new(0, 278, 0, 0)
gainLabel.BackgroundTransparency = 1
gainLabel.Text = ""
gainLabel.TextColor3 = Theme.UI.textDim
gainLabel.TextXAlignment = Enum.TextXAlignment.Left
gainLabel.Font = FONT
gainLabel.TextSize = Theme.TextSize.small
gainLabel.Parent = panel

-- Ohu kordaja (riski kasv)
local threatLabel = Instance.new("TextLabel")
threatLabel.Size = UDim2.new(0, 110, 1, 0)
threatLabel.Position = UDim2.new(0, 428, 0, 0)
threatLabel.BackgroundTransparency = 1
threatLabel.Text = ""
threatLabel.TextColor3 = Theme.UI.warning
threatLabel.TextXAlignment = Enum.TextXAlignment.Left
threatLabel.Font = FONT
threatLabel.TextSize = Theme.TextSize.small
threatLabel.Parent = panel

-- Extract nupp
local extractButton = Instance.new("TextButton")
extractButton.Size = UDim2.new(0, 96, 0, 26)
extractButton.Position = UDim2.new(1, -108, 0, 6)
extractButton.BackgroundColor3 = Theme.UI.panel
extractButton.BorderSizePixel = 0
extractButton.Text = "EXTRACT"
extractButton.TextColor3 = Theme.UI.success
extractButton.Font = FONT_BOLD
extractButton.TextSize = Theme.TextSize.small
extractButton.AutoButtonColor = false
extractButton.Parent = panel
Theme.Corner(extractButton, 6)

extractButton.MouseEnter:Connect(function()
	extractButton.BackgroundColor3 = Theme.UI.panelHover
end)
extractButton.MouseLeave:Connect(function()
	extractButton.BackgroundColor3 = Theme.UI.panel
end)

-- Kinnitus, et kogemata ei klopsaks
local confirming = false
local confirmToken = 0

extractButton.MouseButton1Click:Connect(function()
	if not confirming then
		confirming = true
		confirmToken = confirmToken + 1
		local myToken = confirmToken
		extractButton.Text = "SURE?"
		extractButton.TextColor3 = Theme.UI.warning

		task.delay(3, function()
			if confirmToken == myToken and confirming then
				confirming = false
				extractButton.Text = "EXTRACT"
				extractButton.TextColor3 = Theme.UI.success
			end
		end)
		return
	end

	confirming = false
	extractButton.Text = "EXTRACT"
	extractButton.TextColor3 = Theme.UI.success
	extractRemote:FireServer()
end)

-- =========================================================
-- RUN'I LOPU EKRAAN
-- =========================================================
local endScreen = Theme.AnimatedPanel(
	"EndScreen",
	UDim2.new(0, 420, 0, 270),
	UDim2.new(0.5, -210, 0.5, -135),
	screenGui
)
endScreen.ZIndex = 20
Theme.ClampToViewport(endScreen)

local endStroke = Instance.new("UIStroke")
endStroke.Color = Theme.UI.accent
endStroke.Thickness = 2
endStroke.Parent = endScreen

local endTitle = Instance.new("TextLabel")
endTitle.Size = UDim2.new(1, -32, 0, 30)
endTitle.Position = UDim2.new(0, 16, 0, 16)
endTitle.BackgroundTransparency = 1
endTitle.Text = "RUN COMPLETE"
endTitle.TextColor3 = Theme.UI.accent
endTitle.TextXAlignment = Enum.TextXAlignment.Left
endTitle.Font = FONT_BOLD
endTitle.TextSize = Theme.TextSize.large
endTitle.ZIndex = 21
endTitle.Parent = endScreen

local endReason = Instance.new("TextLabel")
endReason.Size = UDim2.new(1, -32, 0, 20)
endReason.Position = UDim2.new(0, 16, 0, 44)
endReason.BackgroundTransparency = 1
endReason.Text = ""
endReason.TextColor3 = Theme.UI.textDim
endReason.TextXAlignment = Enum.TextXAlignment.Left
endReason.Font = FONT
endReason.TextSize = Theme.TextSize.small
endReason.ZIndex = 21
endReason.Parent = endScreen

local function makeResultRow(y)
	local key = Instance.new("TextLabel")
	key.Size = UDim2.new(0, 200, 0, 20)
	key.Position = UDim2.new(0, 16, 0, y)
	key.BackgroundTransparency = 1
	key.TextColor3 = Theme.UI.textDim
	key.TextXAlignment = Enum.TextXAlignment.Left
	key.Font = FONT
	key.TextSize = Theme.TextSize.small
	key.ZIndex = 21
	key.Parent = endScreen

	local val = Instance.new("TextLabel")
	val.Size = UDim2.new(0, 160, 0, 20)
	val.Position = UDim2.new(1, -176, 0, y)
	val.BackgroundTransparency = 1
	val.TextColor3 = Theme.UI.text
	val.TextXAlignment = Enum.TextXAlignment.Right
	val.Font = FONT_BOLD
	val.TextSize = Theme.TextSize.small
	val.ZIndex = 21
	val.Parent = endScreen

	return key, val
end

local kDur, vDur       = makeResultRow(80)
local kAtk, vAtk       = makeResultRow(104)
local kExp, vExp       = makeResultRow(128)
local kBank, vBank     = makeResultRow(152)
local kRate, vRate     = makeResultRow(176)
local kPayout, vPayout = makeResultRow(206)

kDur.Text = "Survived"
kAtk.Text = "Attacks survived"
kExp.Text = "Island expansions"
kBank.Text = "Reward banked"
kRate.Text = "Payout rate"
kPayout.Text = "FINAL REWARD"
kPayout.Font = FONT_BOLD
kPayout.TextColor3 = Theme.UI.text
vPayout.TextSize = Theme.TextSize.value

-- =========================================================
-- UUENDAMINE
-- =========================================================
local shown = false

local function formatTime(seconds)
	local m = math.floor(seconds / 60)
	local s = math.floor(seconds % 60)
	return string.format("%d:%02d", m, s)
end

local REASON_TEXT = {
	Extract = "You pulled out with everything intact.",
	Timeout = "You held the island to the end.",
	Destroyed = "Your base was wiped out.",
}

if stateRemote then
	stateRemote.OnClientEvent:Connect(function(payload)
		if not payload or not payload.run then
			return
		end

		local r = payload.run

		-- Run labi -> naita tulemust
		if r.result and not shown then
			shown = true
			Theme.HidePanel(panel, Theme.TweenTime.normal)
			Theme.ShowPanel(endScreen, Theme.TweenTime.normal)

			local res = r.result
			endTitle.Text = (res.reason == "Destroyed") and "RUN LOST" or "RUN COMPLETE"
			endTitle.TextColor3 = (res.reason == "Destroyed")
				and Theme.UI.error or Theme.UI.success
			endStroke.Color = endTitle.TextColor3
			endReason.Text = REASON_TEXT[res.reason] or ""

			vDur.Text = formatTime(res.duration)
			vAtk.Text = tostring(res.attacksSurvived)
			vExp.Text = tostring(res.expansionsMade)
			vBank.Text = Theme.Points(res.banked)
			vRate.Text = string.format("%d%%", math.floor(res.payoutRate * 100))
			vRate.TextColor3 = (res.payoutRate < 1)
				and Theme.UI.error or Theme.UI.success
			vPayout.Text = Theme.Points(res.payout)
			vPayout.TextColor3 = Theme.UI.success
			return
		end

		-- Uus run on alanud (tulemus kustus) - peida lopuekraan ja
		-- naita jooksva run'i riba jalle.
		if shown and not r.result then
			shown = false
			Theme.HidePanel(endScreen, Theme.TweenTime.normal)
			Theme.ShowPanel(panel, Theme.TweenTime.normal)
		end

		if shown then
			return
		end

		-- Jooksev seis.
		-- Naitame MOODUNUD aega, mitte jargijaanut: run'i pikkus on
		-- muutuv ja taimer on ainult ulempiir. "12:04 vastu peetud"
		-- on tahenduslikum kui "47:56 jaanud".
		if r.warning then
			timeLabel.Text = formatTime(r.remaining) .. " left"
			timeLabel.TextColor3 = Theme.UI.error
			panelStroke.Transparency = 0
		else
			timeLabel.Text = formatTime(r.elapsed or 0)
			timeLabel.TextColor3 = Theme.UI.text
			panelStroke.Transparency = 1
		end

		rewardLabel.Text = "Banked " .. Theme.Points(r.banked)
		gainLabel.Text = string.format("next minute +%d %s",
			r.nextMinuteValue or 0, Theme.Currency.suffix)

		local threat = r.threatScale or 1
		threatLabel.Text = string.format("threat %.1fx", threat)
		threatLabel.TextColor3 = (threat > 4) and Theme.UI.error
			or (threat > 2) and Theme.UI.warning
			or Theme.UI.textDim
	end)
end

print("[Hexagonium] RunPanel laaditud")
