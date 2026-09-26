--[[
	ContextMenu.lua (LocalScript)
	Paremkloops hoonel avab kontekstimenuu: info + tegevused.

	EI AVANE sihtimisrezhiimis - seal tahendab paremkloops "tuhista".
	Seda kontrollime jagatud lipu kaudu (PlayerGui.HexagoniumTargeting).

	KOGU MANGIJALE NAHTAV TEKST ON INGLISE KEELES.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local BuildingInfo = require(ReplicatedStorage.Shared.BuildingInfo)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Theme = require(ReplicatedStorage.Shared.Theme)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local FONT = Theme.Font.regular
local FONT_BOLD = Theme.Font.bold

local demolishRemote = RemoteEvents.Get("DemolishBuilding")
local stateRemote = RemoteEvents.Get("GameStateUpdate")

-- =========================================================
-- GUI
-- =========================================================
local existing = playerGui:FindFirstChild("HexagoniumContextMenu")
if existing then
	existing:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HexagoniumContextMenu"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 10   -- teiste paneelide peal
screenGui.Parent = playerGui

local menu = Instance.new("Frame")
menu.Name = "Menu"
menu.Size = UDim2.new(0, 250, 0, 226)
menu.BackgroundColor3 = Theme.UI.background
menu.BackgroundTransparency = 0.02
menu.BorderSizePixel = 0
menu.Visible = false
menu.Parent = screenGui
Theme.Corner(menu, 8)

local menuStroke = Instance.new("UIStroke")
menuStroke.Color = Theme.UI.panelHover
menuStroke.Thickness = 1
menuStroke.Parent = menu

-- Pealkiri
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -24, 0, 20)
titleLabel.Position = UDim2.new(0, 12, 0, 10)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = ""
titleLabel.TextColor3 = Theme.UI.text
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Font = FONT_BOLD
titleLabel.TextSize = Theme.TextSize.value
titleLabel.Parent = menu

local subLabel = Instance.new("TextLabel")
subLabel.Size = UDim2.new(1, -24, 0, 16)
subLabel.Position = UDim2.new(0, 12, 0, 30)
subLabel.BackgroundTransparency = 1
subLabel.Text = ""
subLabel.TextColor3 = Theme.UI.accent
subLabel.TextXAlignment = Enum.TextXAlignment.Left
subLabel.Font = FONT
subLabel.TextSize = Theme.TextSize.small
subLabel.Parent = menu

-- Eraldusjoon
local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, -24, 0, 1)
divider.Position = UDim2.new(0, 12, 0, 52)
divider.BackgroundColor3 = Theme.UI.panelHover
divider.BorderSizePixel = 0
divider.Parent = menu

-- Inforead
local function makeInfoRow(yPos)
	local key = Instance.new("TextLabel")
	key.Size = UDim2.new(0, 90, 0, 16)
	key.Position = UDim2.new(0, 12, 0, yPos)
	key.BackgroundTransparency = 1
	key.TextColor3 = Theme.UI.textDim
	key.TextXAlignment = Enum.TextXAlignment.Left
	key.Font = FONT
	key.TextSize = Theme.TextSize.small
	key.Parent = menu

	local val = Instance.new("TextLabel")
	val.Size = UDim2.new(1, -110, 0, 16)
	val.Position = UDim2.new(0, 104, 0, yPos)
	val.BackgroundTransparency = 1
	val.TextColor3 = Theme.UI.text
	val.TextXAlignment = Enum.TextXAlignment.Left
	val.Font = FONT_BOLD
	val.TextSize = Theme.TextSize.small
	val.Parent = menu

	return key, val
end

-- Tootmisinfo, et mangija naeks, kus ahel ummistub voi nalgib
local statusKey, statusVal = makeInfoRow(62)
local healthKey, healthVal = makeInfoRow(82)
local makesKey, makesVal   = makeInfoRow(102)
local usesKey, usesVal     = makeInfoRow(122)
local storedKey, storedVal = makeInfoRow(142)
local hexKey, hexVal       = makeInfoRow(162)

statusKey.Text = "Status"
healthKey.Text = "Integrity"
makesKey.Text = "Makes"
usesKey.Text = "Uses"
storedKey.Text = "Stored"
hexKey.Text = "Terrain"

-- Nupud
local function makeButton(text, color, yPos)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -24, 0, 28)
	btn.Position = UDim2.new(0, 12, 0, yPos)
	btn.BackgroundColor3 = Theme.UI.panel
	btn.BorderSizePixel = 0
	btn.Text = text
	btn.TextColor3 = color
	btn.Font = FONT_BOLD
	btn.TextSize = Theme.TextSize.small
	btn.AutoButtonColor = false
	btn.Parent = menu
	Theme.Corner(btn, 6)

	btn.MouseEnter:Connect(function()
		btn.BackgroundColor3 = Theme.UI.panelHover
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = Theme.UI.panel
	end)

	return btn
end

local upgradeButton = makeButton("", Theme.UI.accent, 188)
local demolishButton = makeButton("Demolish", Theme.UI.error, 188)
local upgradeRemote = RemoteEvents.Get("UpgradeBuilding")

-- Town Hall: kõrgeim tase Constants'ist (üks allikas)
local TOWN_HALL = Constants.Buildings.PowerCore.TownHall
local TOWN_HALL_MAX = #TOWN_HALL

-- Uuendusnupp ainult Power Core'il, kui tase pole maksimumis
local function layoutButtons(showUpgrade)
	upgradeButton.Visible = showUpgrade
	demolishButton.Position = UDim2.new(0, 12, 0, showUpgrade and 222 or 188)
	menu.Size = UDim2.new(0, 250, 0, showUpgrade and 260 or 226)
end

-- =========================================================
-- OLEK
-- =========================================================
local currentTarget = nil   -- {q, r, buildingType}
local buildingStates = {}   -- ["q,r"] = serveri seis

-- Saare viide
local islandFolderName = nil

local function getIslandFolder()
	if not islandFolderName then
		return nil
	end
	local root = workspace:FindFirstChild("Islands")
	return root and root:FindFirstChild(islandFolderName)
end

local function isTargeting()
	local flag = playerGui:FindFirstChild("HexagoniumTargeting")
	return flag ~= nil and flag.Value == true
end

local function closeMenu()
	menu.Visible = false
	currentTarget = nil
end

-- Leia hoone kursori all
local function getBuildingUnderMouse()
	local folder = getIslandFolder()
	local buildings = folder and folder:FindFirstChild("Buildings")
	if not buildings then
		return nil
	end

	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {buildings}

	local result = workspace:Raycast(ray.Origin, ray.Direction * 800, params)
	if not result or not result.Instance then
		return nil
	end

	-- Otsi ulespoole Model, millel on BuildingType atribuut
	local node = result.Instance
	while node and node ~= buildings do
		if node:GetAttribute("BuildingType") then
			return node
		end
		node = node.Parent
	end
	return nil
end

-- Hexi tuup antud koordinaatidel
local function getHexTypeAt(q, r)
	local folder = getIslandFolder()
	local hexes = folder and folder:FindFirstChild("Hexes")
	if not hexes then
		return "Unknown"
	end
	local hex = hexes:FindFirstChild(string.format("Hex_%d_%d", q, r))
	if not hex then
		return "Unknown"
	end
	local t = hex:GetAttribute("HexType")
	if t == Constants.HexTypes.ORE_HEX then return "Ore", t end
	if t == Constants.HexTypes.CRYSTAL_HEX then return "Crystal", t end
	return "Barren", nil
end

local function formatFlow(flow, mult)
	if not flow then
		return "-"
	end
	local unit = flow[2] == "UP" and "UP" or flow[2]:lower()
	local text = string.format("%g %s/min", math.floor(flow[1] * mult * 10 + 0.5) / 10, unit)
	if math.abs(mult - 1) > 0.01 then
		text ..= string.format(" (%.2fx)", mult)
	end
	return text
end

-- Kas hoone toob, nalgib voi ummistub? Jarjekord = mis on kõige
-- olulisem parandada. "Piling up" = pakkumine uletab tarbimist rohkem
-- kui minuti jagu -> lisa tarbija voi jaota link.
local function describeStatus(state, flow, usesMult)
	local t = state.buildingType
	if state.paused then
		return "Offline", Theme.UI.error
	end
	if t == "Defender" and not state.hasPowerCore then
		return "No Power Core", Theme.UI.error
	end
	-- Parandus käib ainult Power Core'i raadiuses
	if (state.health or 1) < 0.999 then
		if not state.healing then
			return "Out of repair range", Theme.UI.warning
		elseif state.repairPaused then
			return "Repair paused", Theme.UI.warning
		end
		return "Repairing", Theme.UI.success
	end
	if flow.uses and state.input ~= nil then
		if state.linksIn == 0 then
			return "No input link", Theme.UI.warning
		elseif state.starved then
			return "Waiting for input", Theme.UI.warning
		elseif state.input > flow.uses[1] * usesMult then
			return "Input piling up", Theme.UI.warning
		end
	end
	if state.output ~= nil and state.linksOut == 0 then
		return "No output link", Theme.UI.warning
	end
	return "Running", Theme.UI.success
end

-- Taidab inforead serveri seisust. Kutsutakse avamisel JA iga
-- seisu-uuenduse ajal, kui menuu on lahti (numbrid elavad).
local function refreshMenu()
	if not currentTarget then
		return
	end
	local q, r = currentTarget.q, currentTarget.r
	local hexName, hexType = getHexTypeAt(q, r)
	hexVal.Text = hexName

	local state = buildingStates[q .. "," .. r]
	if not state then
		for _, val in ipairs({statusVal, healthVal, makesVal, usesVal, storedVal}) do
			val.Text = "-"
			val.TextColor3 = Theme.UI.textDim
		end
		statusVal.Text = "Unknown"
		layoutButtons(false)
		return
	end


	local flow = BuildingInfo.GetFlow(currentTarget.buildingType, hexType)
	local mult = state.multiplier or 1

	-- Kordaja = läbilaskevõime: Refinery/Assembler tarbivad ka rohkem.
	-- Defenderi energiakulu on fikseeritud.
	local usesMult = currentTarget.buildingType == "Defender" and 1 or mult
	statusVal.Text, statusVal.TextColor3 = describeStatus(state, flow, usesMult)

	local hp = state.health or 1
	healthVal.Text = string.format("%d%%", math.floor(hp * 100 + 0.5))
	healthVal.TextColor3 = (hp > 0.66) and Theme.UI.success
		or (hp > 0.33) and Theme.UI.warning
		or Theme.UI.error

	makesVal.Text = formatFlow(flow.makes, mult)
	makesVal.TextColor3 = (mult > 1.01) and Theme.UI.success
		or (mult < 0.99) and Theme.UI.warning
		or Theme.UI.text
	usesVal.Text = formatFlow(flow.uses, usesMult)
	usesVal.TextColor3 = Theme.UI.text

	-- Town Hall tase ja uuendus
	local nextLevel = state.level and TOWN_HALL[state.level + 1]
	if state.level then
		local current = TOWN_HALL[state.level]
		subLabel.Text = string.format("Town Hall Lv %d/%d · repair %d%s", state.level, TOWN_HALL_MAX, current.HealRadius,
			current.ProductionBonus > 0 and string.format(" · +%d%%", math.floor(current.ProductionBonus * 100 + 0.5)) or "")
	end
	if nextLevel then
		upgradeButton.Text = string.format("Upgrade (%d UP + %d crystal)", nextLevel.Cost, nextLevel.Crystal)
	end
	layoutButtons(nextLevel ~= nil)

	if state.energy and state.maxEnergy then
		storedVal.Text = string.format("%d / %d energy", state.energy, state.maxEnergy)
	elseif state.input ~= nil or state.output ~= nil then
		local parts = {}
		if state.input ~= nil then table.insert(parts, state.input .. " in") end
		if state.output ~= nil then table.insert(parts, state.output .. " out") end
		storedVal.Text = table.concat(parts, "  ·  ")
	else
		storedVal.Text = "-"
	end
	storedVal.TextColor3 = Theme.UI.text
end

local function openMenu(visual)
	local buildingType = visual:GetAttribute("BuildingType")
	local q = visual:GetAttribute("Q")
	local r = visual:GetAttribute("R")

	currentTarget = {q = q, r = r, buildingType = buildingType}

	local info = BuildingInfo.Get(buildingType)
	titleLabel.Text = info and info.displayName or buildingType
	subLabel.Text = info and info.tagline or ""

	refreshMenu()

	-- Aseta menuu kursori juurde, hoides seda ekraani sees
	local mouse = UserInputService:GetMouseLocation()
	local viewport = camera.ViewportSize
	local x = math.min(mouse.X, viewport.X - menu.AbsoluteSize.X - 8)
	local y = math.min(mouse.Y, viewport.Y - menu.AbsoluteSize.Y - 8)
	menu.Position = UDim2.new(0, x, 0, y)

	menu.Visible = true
end

-- =========================================================
-- SISENDID
-- =========================================================
-- Paremkloops: KLOPS vs LOHISTAMINE
-- Sama lavend kui DroneCamera's. Menuu avaneb ainult siis, kui
-- hiir EI liikunud - vastasel juhul poorab mangija kaamerat ja
-- menuu oleks tulemas segav.
local DRAG_THRESHOLD = 6   -- pikslit
local rightPending = false
local rightStartPos = nil
local rightDragged = false

-- Kas kursor on labipaistmatu UI-paneeli peal?
-- Paremkloops paneeli peal ei tohi kontekstimenuud avada.
local function isOverOwnUI()
	local mouse = UserInputService:GetMouseLocation()
	local objects = playerGui:GetGuiObjectsAtPosition(mouse.X, mouse.Y)
	for _, obj in ipairs(objects) do
		if obj.Visible and obj.BackgroundTransparency < 0.9 then
			return true
		end
	end
	return false
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	local isRight = input.UserInputType == Enum.UserInputType.MouseButton2

	-- Paremkloopsu tootleme ka gameProcessed korral - ilma
	-- karakterita margib Roblox selle sageli tarbituks ja menuu
	-- ei avaneks kunagi.
	if gameProcessed and not isRight then
		return
	end

	-- Paremkloops alla: hakkame lugema liikumist
	if isRight then
		if isTargeting() or isOverOwnUI() then
			return
		end
		rightPending = true
		-- Kursori positsioon, mitte Delta - Delta on lukustamata
		-- hiire puhul null (vt DroneCamera sama kommentaar)
		rightStartPos = UserInputService:GetMouseLocation()
		return
	end

	-- Vasak kloops menuust valjaspool sulgeb selle
	if input.UserInputType == Enum.UserInputType.MouseButton1 and menu.Visible then
		local mouse = UserInputService:GetMouseLocation()
		local p, s = menu.AbsolutePosition, menu.AbsoluteSize
		local inside = mouse.X >= p.X and mouse.X <= p.X + s.X
			and mouse.Y >= p.Y and mouse.Y <= p.Y + s.Y
		if not inside then
			closeMenu()
		end
		return
	end

	-- Q sulgeb menuu
	if input.KeyCode == Enum.KeyCode.Q and menu.Visible then
		closeMenu()
	end
end)

-- Loeme paremkloopsu ajal hiire liikumist
UserInputService.InputChanged:Connect(function(input)
	if rightPending and rightStartPos
		and input.UserInputType == Enum.UserInputType.MouseMovement
	then
		local nowPos = UserInputService:GetMouseLocation()
		rightDragged = (nowPos - rightStartPos).Magnitude >= DRAG_THRESHOLD
	end
end)

-- Paremkloops lahti: kui hiir ei liikunud, ava menuu
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton2 then
		return
	end

	local wasClick = rightPending and not rightDragged
	rightPending = false
	rightStartPos = nil
	rightDragged = false

	if not wasClick then
		return   -- oli lohistamine (kaamera poore), menuud ei ava
	end

	local visual = getBuildingUnderMouse()
	if visual then
		openMenu(visual)
	else
		closeMenu()
	end
end)

upgradeButton.MouseButton1Click:Connect(function()
	if not currentTarget then
		return
	end
	-- Server kontrollib taset ja hinda; menüü jääb lahti, et uus tase näha
	upgradeRemote:FireServer({q = currentTarget.q, r = currentTarget.r})
end)

demolishButton.MouseButton1Click:Connect(function()
	if not currentTarget then
		return
	end
	demolishRemote:FireServer({q = currentTarget.q, r = currentTarget.r})
	closeMenu()
end)

-- =========================================================
-- SERVERI SEIS
-- =========================================================
if stateRemote then
	stateRemote.OnClientEvent:Connect(function(payload)
		if not payload or not payload.buildings then
			return
		end

		if payload.islandFolder then
			islandFolderName = payload.islandFolder
		end

		local newStates = {}
		for _, b in ipairs(payload.buildings) do
			if b.q and b.r then
				newStates[b.q .. "," .. b.r] = b
			end
		end
		buildingStates = newStates

		-- Kui avatud menuu hoone on kadunud, sulge menuu; muidu uuenda numbrid
		if currentTarget and menu.Visible then
			if not newStates[currentTarget.q .. "," .. currentTarget.r] then
				closeMenu()
			else
				refreshMenu()
			end
		end
	end)
end

print("[Hexagonium] ContextMenu laaditud")
