--[[
	Minimap.lua (LocalScript)
	Kerge hex-grid ulevaade: maastik, hooned, ruundajad.
	Klops minimapil viib kaamera sinna.

	JOUDLUS: hexid joonistatakse UKS KORD ja seejarel ainult siis,
	kui saar muutub (laiendus). Hooned ja ruundajad uuenevad iga
	serveri pakiga, aga neid on vahe.

	KOGU MANGIJALE NAHTAV TEKST ON INGLISE KEELES.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local Theme = require(ReplicatedStorage.Shared.Theme)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT_BOLD = Theme.Font.bold

local stateRemote = RemoteEvents.Get("GameStateUpdate")

-- =========================================================
-- SEADED
-- =========================================================
local MAP_SIZE = 190          -- paneeli sisemine mootmed pikslites
local HEX_DOT = 7             -- uhe hexi suurus minimapil
local BUILDING_DOT = 9
local ATTACKER_DOT = 7

-- Maailma ulatus, mille minimap katab. KOHANDUV: arvutatakse
-- avatud hexide jargi, nii et saar taidab minimapi ka siis, kui
-- ta laieneb. Fikseeritud vaartusega jaanuks 60% pinnast tuhjaks.
local worldExtent = 40
local EXTENT_PADDING = 1.15

-- SAARE VIIDE: saared elavad Workspace.Islands.<nimi> all ja igal
-- on oma nihe. Server saadab molemad.
local islandFolderName = nil
local islandOrigin = Vector3.new()

local function getIslandFolder()
	if not islandFolderName then
		return nil
	end
	local root = workspace:FindFirstChild("Islands")
	return root and root:FindFirstChild(islandFolderName)
end

local HEX_COLORS = {
	OreHex = Theme.World.hexOre,
	CrystalHex = Theme.World.hexCrystal,
	Neutral = Theme.World.hexNeutral,
}

-- =========================================================
-- GUI
-- =========================================================
local existing = playerGui:FindFirstChild("HexagoniumMinimap")
if existing then
	existing:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HexagoniumMinimap"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local panel = Theme.AnimatedPanel(
	"Minimap",
	UDim2.new(0, MAP_SIZE + 16, 0, MAP_SIZE + 34),
	UDim2.new(0, 16, 0, 16),
	screenGui
)
Theme.ClampToViewport(panel)
-- Nagu RunBar: minimap on ALGUSEST PEALE nahtav, fade kehtib ainult
-- hilisema M-klahvi togglega peitmise/naitamise kohta.
panel.Visible = true
panel.GroupTransparency = 0

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -16, 0, 18)
title.Position = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1
title.Text = "ISLAND MAP   " .. Theme.Hotkeys.map
title.TextColor3 = Theme.UI.accent
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = FONT_BOLD
title.TextSize = Theme.TextSize.label
title.Parent = panel

-- Kaardi ala (klopsatav)
local canvas = Instance.new("TextButton")
canvas.Name = "Canvas"
canvas.Size = UDim2.new(0, MAP_SIZE, 0, MAP_SIZE)
canvas.Position = UDim2.new(0, 8, 0, 26)
canvas.BackgroundColor3 = Color3.fromRGB(28, 62, 96)   -- ookean
canvas.BackgroundTransparency = 0.25
canvas.BorderSizePixel = 0
canvas.Text = ""
canvas.AutoButtonColor = false
canvas.ClipsDescendants = true
canvas.Parent = panel
Theme.Corner(canvas, 6)

-- Kihid: maastik all, hooned peal, ruundajad koige peal
local terrainLayer = Instance.new("Frame")
terrainLayer.Size = UDim2.new(1, 0, 1, 0)
terrainLayer.BackgroundTransparency = 1
terrainLayer.ZIndex = 1
terrainLayer.Parent = canvas

local buildingLayer = Instance.new("Frame")
buildingLayer.Size = UDim2.new(1, 0, 1, 0)
buildingLayer.BackgroundTransparency = 1
buildingLayer.ZIndex = 2
buildingLayer.Parent = canvas

local attackerLayer = Instance.new("Frame")
attackerLayer.Size = UDim2.new(1, 0, 1, 0)
attackerLayer.BackgroundTransparency = 1
attackerLayer.ZIndex = 3
attackerLayer.Parent = canvas

-- =========================================================
-- KOORDINAATIDE TEISENDUS
-- Maailm (X, Z) -> minimapi pikslid
-- =========================================================
-- Maailm -> minimapi pikslid. Arvestab saare nihkega, et minimap
-- naitaks SINU saart, mitte maailma keskpunkti.
local function worldToMap(x, z)
	local lx = x - islandOrigin.X
	local lz = z - islandOrigin.Z
	local nx = (lx + worldExtent) / (worldExtent * 2)
	local nz = (lz + worldExtent) / (worldExtent * 2)
	return nx * MAP_SIZE, nz * MAP_SIZE
end

local function mapToWorld(px, py)
	local nx = px / MAP_SIZE
	local nz = py / MAP_SIZE
	return islandOrigin.X + (nx * worldExtent * 2 - worldExtent),
	       islandOrigin.Z + (nz * worldExtent * 2 - worldExtent)
end

local function makeDot(parent, size, color, zIndex)
	local dot = Instance.new("Frame")
	dot.Size = UDim2.new(0, size, 0, size)
	dot.BackgroundColor3 = color
	dot.BorderSizePixel = 0
	dot.ZIndex = zIndex or 1
	dot.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = dot
	return dot
end

-- =========================================================
-- MAASTIK (joonistatakse harva)
-- =========================================================
local terrainSignature = ""

local function drawTerrain()
	local folder = getIslandFolder()
	local hexes = folder and folder:FindFirstChild("Hexes")
	if not hexes then
		return
	end

	-- Allkiri: mitu avatud hexi ja millised. Kui muutub, joonistame uuesti.
	local unlocked = 0
	for _, hex in ipairs(hexes:GetChildren()) do
		if hex:GetAttribute("Locked") ~= true then
			unlocked = unlocked + 1
		end
	end
	local sig = tostring(unlocked)
	if sig == terrainSignature then
		return
	end
	terrainSignature = sig

	-- Kohanda ulatust avatud saare jargi (saare nihke suhtes)
	local maxDist = 0
	for _, hex in ipairs(hexes:GetChildren()) do
		if hex:GetAttribute("Locked") ~= true then
			local d = math.max(
				math.abs(hex.Position.X - islandOrigin.X),
				math.abs(hex.Position.Z - islandOrigin.Z)
			)
			if d > maxDist then
				maxDist = d
			end
		end
	end
	if maxDist > 0 then
		worldExtent = maxDist * EXTENT_PADDING
	end

	terrainLayer:ClearAllChildren()

	for _, hex in ipairs(hexes:GetChildren()) do
		if hex:GetAttribute("Locked") ~= true then
			local px, py = worldToMap(hex.Position.X, hex.Position.Z)
			local hexType = hex:GetAttribute("HexType") or "Neutral"

			local dot = Instance.new("Frame")
			dot.Size = UDim2.new(0, HEX_DOT, 0, HEX_DOT)
			dot.Position = UDim2.new(0, px - HEX_DOT / 2, 0, py - HEX_DOT / 2)
			dot.BackgroundColor3 = HEX_COLORS[hexType] or HEX_COLORS.Neutral
			dot.BorderSizePixel = 0
			dot.ZIndex = 1
			dot.Parent = terrainLayer
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 2)
			c.Parent = dot
		end
	end
end

-- =========================================================
-- HOONED
-- =========================================================
local buildingDots = {}

-- attackedKeys: {[q..":"..r] = true} praegu runnatavate hoonete jaoks
-- (vt drawAttackers'i kutsuja) - pulseeriv aair, ERISTUB allpoolsest
-- staatilisest tervise-aairest ("kahjustatud MINEVIKUS" vs "runnatakse PRAEGU").
local function drawBuildings(buildings, attackedKeys)
	buildingLayer:ClearAllChildren()
	buildingDots = {}

	local folder = getIslandFolder()
	local visuals = folder and folder:FindFirstChild("Buildings")
	if not visuals then
		return
	end

	for _, b in ipairs(buildings) do
		-- Leia visuaal, et saada maailmapositsioon
		for _, v in ipairs(visuals:GetChildren()) do
			if v:GetAttribute("Q") == b.q and v:GetAttribute("R") == b.r and v.PrimaryPart then
				local px, py = worldToMap(v.PrimaryPart.Position.X, v.PrimaryPart.Position.Z)
				local colorKey = "building" .. b.buildingType
				local color = Theme.World[colorKey] or Theme.UI.text

				local dot = makeDot(buildingLayer, BUILDING_DOT, color, 2)
				dot.Position = UDim2.new(0, px - BUILDING_DOT / 2, 0, py - BUILDING_DOT / 2)

				local key = b.q .. ":" .. b.r
				if attackedKeys and attackedKeys[key] then
					-- Runnatakse PRAEGU: pulseeriv paks aair
					local stroke = Instance.new("UIStroke")
					stroke.Color = Theme.UI.error
					stroke.Thickness = 3
					stroke.Transparency = 0.1
					stroke.Parent = dot
					Theme.Tween(stroke, {Transparency = 0.7}, 0.4, Enum.EasingStyle.Sine):Play()
				elseif b.health and b.health < 0.99 then
					-- Kahjustatud (aga hetkel mitte runnatav): staatiline aair
					local stroke = Instance.new("UIStroke")
					stroke.Color = (b.health > 0.5) and Theme.UI.warning or Theme.UI.error
					stroke.Thickness = 2
					stroke.Parent = dot
				end

				-- Peatunud hoone: labipaistev
				if b.paused then
					dot.BackgroundTransparency = 0.55
				end

				table.insert(buildingDots, dot)
				break
			end
		end
	end
end

-- =========================================================
-- RUUNDAJAD
-- =========================================================
-- Sama intervall mis StateBroadcaster.BROADCAST_INTERVAL (server) -
-- tween joudab tapselt jargmise uuenduseni, mitte ei jaa poolele teele.
local ATTACKER_TWEEN_TIME = 0.5

-- id-pohine jalgimine (mitte ClearAllChildren+taasloomine iga uuendus):
-- ilma selleta hupib tapp iga 0.5s uue asukohta, sest server saadab
-- taisseisu, mitte deltasid. TweenService liigutab olemasolevat
-- tappi sujuvalt jargmise positsioonini samas ajas, mis mooduks
-- jargmise saatetsuklini.
local attackerDots = {}

local function drawAttackers(attack)
	if not attack or not attack.active or not attack.positions then
		for _, dot in pairs(attackerDots) do
			dot:Destroy()
		end
		attackerDots = {}
		return
	end

	local seen = {}
	for _, a in ipairs(attack.positions) do
		seen[a.id] = true
		local px, py = worldToMap(a.x, a.z)
		local targetPos = UDim2.new(0, px - ATTACKER_DOT / 2, 0, py - ATTACKER_DOT / 2)

		local dot = attackerDots[a.id]
		if not dot then
			dot = makeDot(attackerLayer, ATTACKER_DOT, Theme.UI.error, 3)
			dot.Position = targetPos

			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.new(1, 1, 1)
			stroke.Thickness = 1
			stroke.Transparency = 0.5
			stroke.Parent = dot

			attackerDots[a.id] = dot
		else
			Theme.Tween(dot, {Position = targetPos}, ATTACKER_TWEEN_TIME, Enum.EasingStyle.Linear):Play()
		end

		-- Kahjustatud ruundaja on tuhmim
		dot.BackgroundTransparency = 0.6 * (1 - (a.health or 1))
	end

	for id, dot in pairs(attackerDots) do
		if not seen[id] then
			dot:Destroy()
			attackerDots[id] = nil
		end
	end
end

-- =========================================================
-- KAAMERA MARKER
-- =========================================================
local cameraDot = Instance.new("Frame")
cameraDot.Size = UDim2.new(0, 14, 0, 14)
cameraDot.BackgroundTransparency = 1
cameraDot.BorderSizePixel = 0
cameraDot.ZIndex = 4
cameraDot.Parent = canvas

local cameraStroke = Instance.new("UIStroke")
cameraStroke.Color = Color3.new(1, 1, 1)
cameraStroke.Thickness = 1.5
cameraStroke.Transparency = 0.3
cameraStroke.Parent = cameraDot

local cc = Instance.new("UICorner")
cc.CornerRadius = UDim.new(1, 0)
cc.Parent = cameraDot

-- =========================================================
-- KLOPS: vii kaamera sinna
-- DroneCamera kuulab seda vaartust.
-- =========================================================
local cameraTarget = playerGui:FindFirstChild("HexagoniumCameraTarget")
if not cameraTarget then
	cameraTarget = Instance.new("Vector3Value")
	cameraTarget.Name = "HexagoniumCameraTarget"
	cameraTarget.Parent = playerGui
end

canvas.MouseButton1Click:Connect(function()
	local mouse = UserInputService:GetMouseLocation()
	local abs = canvas.AbsolutePosition

	-- INSET-PARANDUS: GetMouseLocation() moodab ekraani ulaservast
	-- NII, ET Robloxi topbar on valja arvatud, aga GuiObject'i
	-- AbsolutePosition arvestab seda. Ilma paranduseta lendab
	-- kaamera ~36 pikslit (2-3 hexi) allapoole klopsatud kohast.
	local inset = GuiService:GetGuiInset()

	local px = mouse.X - abs.X - inset.X
	local py = mouse.Y - abs.Y - inset.Y

	if px < 0 or px > MAP_SIZE or py < 0 or py > MAP_SIZE then
		return
	end

	local wx, wz = mapToWorld(px, py)
	cameraTarget.Value = Vector3.new(wx, 0, wz)
end)

-- =========================================================
-- PEIDETUD OLEKU SILT
-- Kui minimap on peidetud, peab midagi jargi jaama - muidu ei
-- tea mangija, et kaart uldse olemas on. SAMAS kohas/mootmetes mis
-- "panel" ise (0,16,0,16) - naeb valja nagu kokkuvarisenud "ISLAND
-- MAP" pealkirjariba, mitte eraldiseisev kollane tekst kuskil mujal.
-- =========================================================
local hiddenHint = Theme.AnimatedPanel(
	"HiddenHint",
	UDim2.new(0, MAP_SIZE + 16, 0, 36),
	UDim2.new(0, 16, 0, 16),
	screenGui
)

local hiddenHintText = Instance.new("TextLabel")
hiddenHintText.Size = UDim2.new(1, -20, 1, 0)
hiddenHintText.Position = UDim2.new(0, 10, 0, 0)
hiddenHintText.BackgroundTransparency = 1
hiddenHintText.Text = "ISLAND MAP   " .. Theme.Hotkeys.map
hiddenHintText.TextColor3 = Theme.UI.accent
hiddenHintText.TextXAlignment = Enum.TextXAlignment.Left
hiddenHintText.Font = FONT_BOLD
hiddenHintText.TextSize = Theme.TextSize.label
hiddenHintText.Parent = hiddenHint

local function setMapVisible(visible)
	if visible then
		Theme.ShowPanel(panel, Theme.TweenTime.normal)
		Theme.HidePanel(hiddenHint, Theme.TweenTime.normal)
	else
		Theme.HidePanel(panel, Theme.TweenTime.normal)
		Theme.ShowPanel(hiddenHint, Theme.TweenTime.normal)
	end
end

-- =========================================================
-- M: peida / naita minimapi
-- =========================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.M then
		setMapVisible(not panel.Visible)
	end
end)

-- =========================================================
-- UUENDAMINE
-- =========================================================
if stateRemote then
	stateRemote.OnClientEvent:Connect(function(payload)
		if not payload then
			return
		end

		-- Saare viide ja nihe serverilt
		if payload.islandFolder then
			islandFolderName = payload.islandFolder
		end
		if payload.origin then
			islandOrigin = Vector3.new(payload.origin.x, 0, payload.origin.z)
		end

		drawTerrain()

		local attack = payload.faction and payload.faction.attack
		local attackedKeys = {}
		if attack and attack.active and attack.positions then
			for _, a in ipairs(attack.positions) do
				if a.targetQ ~= nil and a.targetR ~= nil then
					attackedKeys[a.targetQ .. ":" .. a.targetR] = true
				end
			end
		end

		if payload.buildings then
			drawBuildings(payload.buildings, attackedKeys)
		end

		drawAttackers(attack)
	end)
end

-- Kaamera markeri positsioon.
-- Kasutame camera.Focus'e, mille DroneCamera seab vaatepunktiks.
-- Varem arvutasime LookVector * 60, mis nihkus suumimisel, sest
-- kaamera kaugus muutus, aga 60 jai samaks.
local RunService = game:GetService("RunService")
RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local focus = camera.Focus.Position
	local px, py = worldToMap(focus.X, focus.Z)
	cameraDot.Position = UDim2.new(0, px - 7, 0, py - 7)
end)

print("[Hexagonium] Minimap laaditud")
