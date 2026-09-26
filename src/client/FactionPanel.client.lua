--[[
	FactionPanel.lua (LocalScript)
	Fraktsiooni olek + Demand otsus (Accept / Refuse).

	Paneel on ALATI nahtav (naitab suhte seisu), aga otsusenupud
	ilmuvad ainult Demand olekus koos pooratava taimeriga.

	KOGU MANGIJALE NAHTAV TEKST ON INGLISE KEELES.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local Theme = require(ReplicatedStorage.Shared.Theme)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT = Theme.Font.regular
local FONT_BOLD = Theme.Font.bold

local decisionRemote = RemoteEvents.Get("FactionDecision")
local stateRemote = RemoteEvents.Get("GameStateUpdate")

-- Oleku varv ja kirjeldus mangijale.
-- countdownLabel selgitab, MIDA taimer loeb - ilma selleta ei saa
-- mangija aru, kas number tahendab ohtu voi rahu.
local STATE_INFO = {
	Neutral  = {color = Theme.UI.textDim, text = "Watching from a distance", countdown = "Next demand in"},
	Friendly = {color = Theme.UI.success, text = "Willing to cooperate",     countdown = "Goodwill lasts"},
	Trade    = {color = Theme.UI.success, text = "Trading with you",         countdown = "Trade ends in"},
	Demand   = {color = Theme.UI.warning, text = "Demanding tribute",        countdown = "Decide within"},
	Hostile  = {color = Theme.UI.error,   text = "Preparing to attack",      countdown = "ATTACK IN"},
	Attack   = {color = Theme.UI.error,   text = "Attacking your base",      countdown = "Assault ends in"},
	Recover  = {color = Theme.UI.textDim, text = "Withdrawing to regroup",   countdown = "Regrouping for"},
}

local existing = playerGui:FindFirstChild("HexagoniumFactionPanel")
if existing then
	existing:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HexagoniumFactionPanel"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Paneel: parem serv, saarepaneeli kohal. Alumine serv fikseeritud,
-- kõrgus sisu järgi (fitPanel) - nõudeta oli all tühi riba.
local panel = Instance.new("Frame")
panel.Name = "FactionPanel"
panel.AnchorPoint = Vector2.new(0, 1)
panel.Position = UDim2.new(1, -264, 1, -160)
panel.Size = UDim2.new(0, 248, 0, 96)
panel.BackgroundColor3 = Theme.UI.background
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Parent = screenGui
Theme.Corner(panel, 8)

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Theme.UI.background
panelStroke.Thickness = 2
panelStroke.Transparency = 1
panelStroke.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -24, 0, 20)
title.Position = UDim2.new(0, 12, 0, 8)
title.BackgroundTransparency = 1
title.Text = "FRACTURE SYNDICATE"
title.TextColor3 = Theme.UI.error
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = FONT_BOLD
title.TextSize = Theme.TextSize.label
title.Parent = panel

local stateLabel = Instance.new("TextLabel")
stateLabel.Size = UDim2.new(1, -24, 0, 20)
stateLabel.Position = UDim2.new(0, 12, 0, 28)
stateLabel.BackgroundTransparency = 1
stateLabel.Text = "Neutral"
stateLabel.TextColor3 = Theme.UI.text
stateLabel.TextXAlignment = Enum.TextXAlignment.Left
stateLabel.Font = FONT_BOLD
stateLabel.TextSize = Theme.TextSize.value
stateLabel.Parent = panel

local descLabel = Instance.new("TextLabel")
descLabel.Size = UDim2.new(1, -24, 0, 18)
descLabel.Position = UDim2.new(0, 12, 0, 48)
descLabel.BackgroundTransparency = 1
descLabel.Text = ""
descLabel.TextColor3 = Theme.UI.textDim
descLabel.TextXAlignment = Enum.TextXAlignment.Left
descLabel.Font = FONT
descLabel.TextSize = Theme.TextSize.small
descLabel.Parent = panel

-- Eraldi pooordloendus, et taimer oleks kohe silmatorkav
local countdownLabel = Instance.new("TextLabel")
countdownLabel.Size = UDim2.new(1, -24, 0, 18)
countdownLabel.Position = UDim2.new(0, 12, 0, 66)
countdownLabel.BackgroundTransparency = 1
countdownLabel.Text = ""
countdownLabel.TextColor3 = Theme.UI.textDim
countdownLabel.TextXAlignment = Enum.TextXAlignment.Left
countdownLabel.Font = FONT_BOLD
countdownLabel.TextSize = Theme.TextSize.small
countdownLabel.Parent = panel

-- Demand rida (ainult Demand olekus)
local demandLabel = Instance.new("TextLabel")
demandLabel.Size = UDim2.new(1, -24, 0, 18)
demandLabel.Position = UDim2.new(0, 12, 0, 86)
demandLabel.BackgroundTransparency = 1
demandLabel.Text = ""
demandLabel.TextColor3 = Theme.UI.warning
demandLabel.TextXAlignment = Enum.TextXAlignment.Left
demandLabel.Font = FONT_BOLD
demandLabel.TextSize = Theme.TextSize.small
demandLabel.Visible = false
demandLabel.Parent = panel

-- Otsusenupud
local function makeDecisionButton(text, color, xOffset, width)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, width, 0, 28)
	btn.Position = UDim2.new(0, xOffset, 0, 106)
	btn.BackgroundColor3 = Theme.UI.panel
	btn.BorderSizePixel = 0
	btn.Text = text
	btn.TextColor3 = color
	btn.Font = FONT_BOLD
	btn.TextSize = Theme.TextSize.small
	btn.AutoButtonColor = false
	btn.Visible = false
	btn.Parent = panel
	Theme.Corner(btn, 6)

	btn.MouseEnter:Connect(function()
		btn.BackgroundColor3 = Theme.UI.panelHover
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = Theme.UI.panel
	end)

	return btn
end

local acceptButton = makeDecisionButton("Pay", Theme.UI.success, 12, 110)
local refuseButton = makeDecisionButton("Refuse", Theme.UI.error, 128, 108)

acceptButton.MouseButton1Click:Connect(function()
	decisionRemote:FireServer({accept = true})
end)

refuseButton.MouseButton1Click:Connect(function()
	decisionRemote:FireServer({accept = false})
end)

local function fitPanel()
	local height = acceptButton.Visible and 148 or demandLabel.Visible and 112 or 96
	panel.Size = UDim2.new(0, 248, 0, height)
end
acceptButton:GetPropertyChangedSignal("Visible"):Connect(fitPanel)
demandLabel:GetPropertyChangedSignal("Visible"):Connect(fitPanel)

-- =========================================================
-- RUNNAKU HOIATUS (ekraani keskel, ainult Attack olekus)
-- =========================================================
local alert = Instance.new("Frame")
alert.Name = "AttackAlert"
alert.Size = UDim2.new(0, 420, 0, 56)
alert.Position = UDim2.new(0.5, -210, 0, 230)
alert.BackgroundColor3 = Theme.UI.background
alert.BackgroundTransparency = 0.05
alert.BorderSizePixel = 0
alert.Visible = false
alert.Parent = screenGui
Theme.ClampToViewport(alert)
Theme.Corner(alert, 8)

local alertStroke = Instance.new("UIStroke")
alertStroke.Color = Theme.UI.error
alertStroke.Thickness = 2
alertStroke.Parent = alert

local alertTitle = Instance.new("TextLabel")
alertTitle.Size = UDim2.new(1, -24, 0, 22)
alertTitle.Position = UDim2.new(0, 14, 0, 8)
alertTitle.BackgroundTransparency = 1
alertTitle.Text = "UNDER ATTACK"
alertTitle.TextColor3 = Theme.UI.error
alertTitle.TextXAlignment = Enum.TextXAlignment.Left
alertTitle.Font = FONT_BOLD
alertTitle.TextSize = Theme.TextSize.value
alertTitle.Parent = alert

local alertDetail = Instance.new("TextLabel")
alertDetail.Size = UDim2.new(1, -24, 0, 18)
alertDetail.Position = UDim2.new(0, 14, 0, 30)
alertDetail.BackgroundTransparency = 1
alertDetail.Text = ""
alertDetail.TextColor3 = Theme.UI.textDim
alertDetail.TextXAlignment = Enum.TextXAlignment.Left
alertDetail.Font = FONT
alertDetail.TextSize = Theme.TextSize.small
alertDetail.Parent = alert

-- Pulseeriv aair, et hoiatus jouaks kohale
task.spawn(function()
	local up = true
	while true do
		task.wait(0.6)
		if alert.Visible then
			alertStroke.Transparency = up and 0.6 or 0
			up = not up
		end
	end
end)

-- =========================================================
-- SERVERI SEIS
-- =========================================================
local demandActive = false
local attackAlertActive = false

if stateRemote then
	stateRemote.OnClientEvent:Connect(function(payload)
		if not payload or not payload.faction then
			return
		end

		local f = payload.faction
		local info = STATE_INFO[f.state] or STATE_INFO.Neutral

		stateLabel.Text = f.state
		stateLabel.TextColor3 = info.color
		descLabel.Text = info.text

		-- Pooordloendus: mis on jargmine sundmus ja millal
		local seconds = f.remaining or f.nextDemandIn
		if seconds then
			countdownLabel.Text = string.format("%s  %ds", info.countdown, math.ceil(seconds))
			-- Punane, kui oht laheneb
			if f.state == "Hostile" or f.state == "Attack" then
				countdownLabel.TextColor3 = Theme.UI.error
			elseif f.state == "Demand" then
				countdownLabel.TextColor3 = Theme.UI.warning
			elseif f.state == "Neutral" and seconds < 30 then
				countdownLabel.TextColor3 = Theme.UI.warning
			else
				countdownLabel.TextColor3 = Theme.UI.textDim
			end
		else
			countdownLabel.Text = ""
		end

		-- Hoiatav aair, kui fraktsioon on ohtlik
		if f.state == "Attack" or f.state == "Hostile" then
			panelStroke.Color = Theme.UI.error
			panelStroke.Transparency = 0
		elseif f.state == "Demand" then
			panelStroke.Color = Theme.UI.warning
			panelStroke.Transparency = 0
		else
			panelStroke.Transparency = 1
		end

		-- Demand: naita noue ja nupud. Fade AINULT olekumuutusel, mitte
		-- iga tick'i peal (payload saadetakse iga 0.5s ka muutumatult).
		if f.demand then
			demandLabel.Text = string.format("Wants %d ore + %d crystal  (have %d / %d)",
				f.demand.ore, f.demand.crystal,
				f.demand.haveOre, f.demand.haveCrystal)
			demandLabel.TextColor3 = f.demand.canAfford
				and Theme.UI.warning or Theme.UI.error
			acceptButton.TextColor3 = f.demand.canAfford
				and Theme.UI.success or Theme.UI.blocked

			if not demandActive then
				demandActive = true
				for _, label in ipairs({demandLabel, acceptButton, refuseButton}) do
					label.Visible = true
					if label:IsA("TextButton") then
						label.TextTransparency = 1
						label.BackgroundTransparency = 1
						Theme.Tween(label, {TextTransparency = 0, BackgroundTransparency = 0}, Theme.TweenTime.fast):Play()
					else
						label.TextTransparency = 1
						Theme.Tween(label, {TextTransparency = 0}, Theme.TweenTime.fast):Play()
					end
				end
			end
		elseif demandActive then
			demandActive = false
			for _, label in ipairs({demandLabel, acceptButton, refuseButton}) do
				local props = label:IsA("TextButton")
					and {TextTransparency = 1, BackgroundTransparency = 1}
					or {TextTransparency = 1}
				local tween = Theme.Tween(label, props, Theme.TweenTime.fast)
				tween.Completed:Connect(function()
					label.Visible = false
				end)
				tween:Play()
			end
		end

		-- Runnaku hoiatus - stroke'i pulss on eraldi task.spawn silmuses
		-- allpool, ei puutu seda siin.
		if f.attack and f.attack.active then
			local parts = {}
			table.insert(parts, string.format("%d attacking", f.attack.attackers))
			if f.attack.incoming > 0 then
				table.insert(parts, string.format("%d incoming", f.attack.incoming))
			end
			if f.attack.killed > 0 then
				table.insert(parts, string.format("%d destroyed", f.attack.killed))
			end
			if f.attack.buildingsLost > 0 then
				table.insert(parts, string.format("%d buildings lost", f.attack.buildingsLost))
			end
			alertDetail.Text = table.concat(parts, "   -   ")

			if not attackAlertActive then
				attackAlertActive = true
				alert.Visible = true
				alert.BackgroundTransparency = 1
				alertTitle.TextTransparency = 1
				alertDetail.TextTransparency = 1
				Theme.Tween(alert, {BackgroundTransparency = 0.05}, Theme.TweenTime.fast):Play()
				Theme.Tween(alertTitle, {TextTransparency = 0}, Theme.TweenTime.fast):Play()
				Theme.Tween(alertDetail, {TextTransparency = 0}, Theme.TweenTime.fast):Play()
			end
		elseif attackAlertActive then
			attackAlertActive = false
			alertStroke.Transparency = 0
			Theme.Tween(alertTitle, {TextTransparency = 1}, Theme.TweenTime.fast):Play()
			Theme.Tween(alertDetail, {TextTransparency = 1}, Theme.TweenTime.fast):Play()
			local tween = Theme.Tween(alert, {BackgroundTransparency = 1}, Theme.TweenTime.fast)
			tween.Completed:Connect(function()
				alert.Visible = false
			end)
			tween:Play()
		end
	end)
end

print("[Hexagonium] FactionPanel laaditud")
