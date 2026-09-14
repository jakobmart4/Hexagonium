--[[
	NodeLinks.lua (LocalScript)
	Ressursivoo uhenduste loomine ja visualiseerimine.

	LOOMINE: LINKS rezhiim -> klopsa allikale -> klopsa sihtmargile.
	KATKESTAMINE: klopsa sama paari uuesti (sama kanal teeb molemat).

	VISUAAL: Beam koos liikuva tekstuuriga - voolu suund on kohe naha,
	nooli pole vaja. Prioriteedi number kuvatakse joone keskel.

	KOGU MANGIJALE NAHTAV TEKST ON INGLISE KEELES.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local BuildingInfo = require(ReplicatedStorage.Shared.BuildingInfo)
local Theme = require(ReplicatedStorage.Shared.Theme)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local FONT = Theme.Font.regular
local FONT_BOLD = Theme.Font.bold

local connectRemote = RemoteEvents.Get("ConnectNodes")
local stateRemote = RemoteEvents.Get("GameStateUpdate")

-- Ressursi varv joonel - sama mis HUD-is, et seos oleks kohene
local RESOURCE_COLORS = {
	Ore     = Theme.Resources.Ore,
	Crystal = Theme.Resources.Crystal,
	Alloy   = Theme.Resources.Alloy,
}

-- =========================================================
-- VISUAALIDE KONTEINER
-- =========================================================
local linkFolder = workspace:FindFirstChild("NodeLinkVisuals")
if linkFolder then
	linkFolder:Destroy()
end
linkFolder = Instance.new("Folder")
linkFolder.Name = "NodeLinkVisuals"
linkFolder.Parent = workspace

-- =========================================================
-- GUI
-- =========================================================
local existing = playerGui:FindFirstChild("HexagoniumNodeLinks")
if existing then
	existing:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HexagoniumNodeLinks"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleButton"
toggleButton.Size = UDim2.new(0, 130, 0, 42)
toggleButton.Position = UDim2.new(0, 296, 1, -58)
toggleButton.BackgroundColor3 = Theme.UI.background
toggleButton.BackgroundTransparency = 0.1
toggleButton.BorderSizePixel = 0
toggleButton.Text = "LINKS   " .. Theme.Hotkeys.links
toggleButton.TextColor3 = Theme.UI.ocean
toggleButton.Font = FONT_BOLD
toggleButton.TextSize = Theme.TextSize.body
toggleButton.AutoButtonColor = false
toggleButton.Parent = screenGui
Theme.Corner(toggleButton, 8)

local banner = Instance.new("Frame")
banner.Size = UDim2.new(0, 430, 0, 44)
banner.Position = UDim2.new(0.5, -215, 0, 168)
banner.BackgroundColor3 = Theme.UI.background
banner.BackgroundTransparency = 0.05
banner.BorderSizePixel = 0
banner.Visible = false
banner.Parent = screenGui
Theme.ClampToViewport(banner)
Theme.Corner(banner, 8)

local bannerStroke = Instance.new("UIStroke")
bannerStroke.Color = Theme.UI.ocean
bannerStroke.Thickness = 2
bannerStroke.Parent = banner

local bannerText = Instance.new("TextLabel")
bannerText.Size = UDim2.new(1, -20, 1, 0)
bannerText.Position = UDim2.new(0, 12, 0, 0)
bannerText.BackgroundTransparency = 1
bannerText.Text = ""
bannerText.TextColor3 = Theme.UI.ocean
bannerText.TextXAlignment = Enum.TextXAlignment.Left
bannerText.Font = FONT_BOLD
bannerText.TextSize = Theme.TextSize.body
bannerText.Parent = banner

-- =========================================================
-- OLEK
-- =========================================================
local linkMode = false
local sourceBuilding = nil   -- {q, r, buildingType}
local buildingStates = {}
local connections = {}
local connectionSignature = ""

-- Saare viide
local islandFolderName = nil

local function getIslandFolder()
	if not islandFolderName then
		return nil
	end
	local root = workspace:FindFirstChild("Islands")
	return root and root:FindFirstChild(islandFolderName)
end

local highlight = Instance.new("Highlight")
highlight.FillTransparency = 0.6
highlight.OutlineTransparency = 0
highlight.Enabled = false
highlight.Parent = screenGui

local sourceHighlight = Instance.new("Highlight")
sourceHighlight.FillTransparency = 0.5
sourceHighlight.OutlineTransparency = 0
sourceHighlight.FillColor = Theme.UI.ocean
sourceHighlight.OutlineColor = Theme.UI.ocean
sourceHighlight.Enabled = false
sourceHighlight.Parent = screenGui

local targetingFlag = playerGui:FindFirstChild("HexagoniumTargeting")
if not targetingFlag then
	targetingFlag = Instance.new("BoolValue")
	targetingFlag.Name = "HexagoniumTargeting"
	targetingFlag.Value = false
	targetingFlag.Parent = playerGui
end

-- =========================================================
-- ABI
-- =========================================================
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

	local node = result.Instance
	while node and node ~= buildings do
		if node:GetAttribute("BuildingType") then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function findBuildingVisual(q, r)
	local folder = getIslandFolder()
	local buildings = folder and folder:FindFirstChild("Buildings")
	if not buildings then
		return nil
	end
	for _, v in ipairs(buildings:GetChildren()) do
		if v:GetAttribute("Q") == q and v:GetAttribute("R") == r then
			return v
		end
	end
	return nil
end

-- =========================================================
-- VISUAALIDE EHITAMINE
-- Ehitame uuesti ainult siis, kui uhenduste komplekt muutus.
-- =========================================================
local function makeSignature(list)
	local parts = {}
	for _, c in ipairs(list) do
		table.insert(parts, string.format("%d,%d>%d,%d:%d",
			c.fromQ, c.fromR, c.toQ, c.toR, c.priority))
	end
	table.sort(parts)
	return table.concat(parts, "|")
end

local function anchorPart(position, parent)
	local p = Instance.new("Part")
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Position = position
	p.Parent = parent

	local a = Instance.new("Attachment")
	a.Parent = p
	return a
end

local function rebuildVisuals()
	linkFolder:ClearAllChildren()

	for _, c in ipairs(connections) do
		local fromVisual = findBuildingVisual(c.fromQ, c.fromR)
		local toVisual = findBuildingVisual(c.toQ, c.toR)
		if fromVisual and toVisual and fromVisual.PrimaryPart and toVisual.PrimaryPart then
			local color = RESOURCE_COLORS[c.resource] or Theme.UI.accent

			-- Beam tuleb tosta hoonete KOHALE, muidu kaob ta mudelite
			-- sisse ara (hooned on 4-7 studi korged).
			local fromPart = fromVisual.PrimaryPart
			local toPart = toVisual.PrimaryPart
			local LIFT = 2.2

			local fromPos = fromPart.Position + Vector3.new(0, fromPart.Size.Y / 2 + LIFT, 0)
			local toPos = toPart.Position + Vector3.new(0, toPart.Size.Y / 2 + LIFT, 0)

			local group = Instance.new("Folder")
			group.Name = string.format("Link_%d_%d_to_%d_%d", c.fromQ, c.fromR, c.toQ, c.toR)
			group.Parent = linkFolder

			local a0 = anchorPart(fromPos, group)
			local a1 = anchorPart(toPos, group)

			-- Beam liikuva tekstuuriga: voolu suund on kohe naha
			local beam = Instance.new("Beam")
			beam.Attachment0 = a0
			beam.Attachment1 = a1
			beam.Color = ColorSequence.new(color)
			beam.Width0 = 0.9
			beam.Width1 = 0.9
			beam.LightEmission = 1
			beam.FaceCamera = true
			-- Kaar ulespoole, et jooned ei joistaks hoonetest labi
			beam.CurveSize0 = 2
			beam.CurveSize1 = 2
			beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			beam.TextureMode = Enum.TextureMode.Wrap
			beam.TextureLength = 3
			beam.TextureSpeed = 1.4
			beam.Transparency = NumberSequence.new(0.1)
			beam.ZOffset = 0.5
			beam.Parent = group

			-- Prioriteedi number joone keskel
			local midPart = Instance.new("Part")
			midPart.Size = Vector3.new(0.2, 0.2, 0.2)
			midPart.Transparency = 1
			midPart.Anchored = true
			midPart.CanCollide = false
			midPart.CanQuery = false
			midPart.Position = (fromPos + toPos) / 2 + Vector3.new(0, 2.2, 0)
			midPart.Parent = group

			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.new(0, 26, 0, 26)
			bb.AlwaysOnTop = true
			bb.MaxDistance = 160
			bb.Parent = midPart

			local bg = Instance.new("Frame")
			bg.Size = UDim2.new(1, 0, 1, 0)
			bg.BackgroundColor3 = Theme.UI.background
			bg.BackgroundTransparency = 0.15
			bg.BorderSizePixel = 0
			bg.Parent = bb
			local uc = Instance.new("UICorner")
			uc.CornerRadius = UDim.new(1, 0)
			uc.Parent = bg

			local num = Instance.new("TextLabel")
			num.Size = UDim2.new(1, 0, 1, 0)
			num.BackgroundTransparency = 1
			num.Text = tostring(c.priority)
			num.TextColor3 = color
			num.Font = FONT_BOLD
			num.TextSize = 13
			num.Parent = bg
		end
	end
end

-- =========================================================
-- REZHIIM
-- =========================================================
local function stopLinkMode()
	linkMode = false
	sourceBuilding = nil
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
	sourceHighlight.Enabled = false
	sourceHighlight.Adornee = nil
end

local function startLinkMode()
	linkMode = true
	sourceBuilding = nil
	targetingFlag.Value = true
	banner.Visible = true
	banner.BackgroundTransparency = 1
	bannerText.TextTransparency = 1
	bannerStroke.Transparency = 1
	Theme.Tween(banner, {BackgroundTransparency = 0.05}, Theme.TweenTime.fast):Play()
	Theme.Tween(bannerText, {TextTransparency = 0}, Theme.TweenTime.fast):Play()
	Theme.Tween(bannerStroke, {Transparency = 0}, Theme.TweenTime.fast):Play()
end

-- Kliendipoolne eelkontroll (server valideerib uuesti).
-- Uhilduvus tuleb BuildingInfo'st, mitte kohalikust tabelist.
RunService.RenderStepped:Connect(function()
	if not linkMode then
		return
	end

	local visual = getBuildingUnderMouse()

	if visual then
		local btype = visual:GetAttribute("BuildingType")
		local valid
		if not sourceBuilding then
			valid = BuildingInfo.CanOutput(btype)
		else
			valid = BuildingInfo.CanAccept(btype)
				and not (visual:GetAttribute("Q") == sourceBuilding.q
					and visual:GetAttribute("R") == sourceBuilding.r)
		end

		highlight.Adornee = visual
		highlight.Enabled = true
		local c = valid and Theme.UI.success or Theme.UI.error
		highlight.FillColor = c
		highlight.OutlineColor = c
	else
		highlight.Enabled = false
		highlight.Adornee = nil
	end

	if not sourceBuilding then
		bannerText.Text = string.format(
			"Pick a SOURCE (Extractor or Refinery)  -  %s to cancel",
			Theme.Hotkeys.cancel)
	else
		bannerText.Text = string.format(
			"%s selected  -  now pick a DESTINATION  -  %s to cancel",
			BuildingInfo.GetDisplayName(sourceBuilding.buildingType),
			Theme.Hotkeys.cancel)
	end
end)

-- =========================================================
-- SISENDID
-- =========================================================
toggleButton.MouseButton1Click:Connect(function()
	if linkMode then
		stopLinkMode()
	else
		startLinkMode()
	end
end)

toggleButton.MouseEnter:Connect(function()
	toggleButton.BackgroundColor3 = Theme.UI.panelHover
end)
toggleButton.MouseLeave:Connect(function()
	toggleButton.BackgroundColor3 = Theme.UI.background
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	local isRight = input.UserInputType == Enum.UserInputType.MouseButton2

	-- Paremkloops peab labi paasema ka gameProcessed korral
	if gameProcessed and not isRight then
		return
	end

	if input.KeyCode == Enum.KeyCode.N then
		if linkMode then stopLinkMode() else startLinkMode() end
		return
	end

	if not linkMode then
		return
	end

	if input.KeyCode == Enum.KeyCode.Q then
		stopLinkMode()
		return
	end

	if isRight then
		if sourceBuilding then
			-- Esimene paremkloops tuhistab valiku, teine lopetab rezhiimi
			sourceBuilding = nil
			sourceHighlight.Enabled = false
			sourceHighlight.Adornee = nil
		else
			stopLinkMode()
		end
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local visual = getBuildingUnderMouse()
		if not visual then
			return
		end

		local q = visual:GetAttribute("Q")
		local r = visual:GetAttribute("R")
		local btype = visual:GetAttribute("BuildingType")

		if not sourceBuilding then
			if BuildingInfo.CanOutput(btype) then
				sourceBuilding = {q = q, r = r, buildingType = btype}
				sourceHighlight.Adornee = visual
				sourceHighlight.Enabled = true
			end
		else
			connectRemote:FireServer({
				fromQ = sourceBuilding.q, fromR = sourceBuilding.r,
				toQ = q, toR = r,
			})
			sourceBuilding = nil
			sourceHighlight.Enabled = false
			sourceHighlight.Adornee = nil
		end
	end
end)

-- =========================================================
-- SERVERI SEIS
-- =========================================================
if stateRemote then
	stateRemote.OnClientEvent:Connect(function(payload)
		if not payload then
			return
		end

		if payload.islandFolder then
			islandFolderName = payload.islandFolder
		end

		if payload.buildings then
			local s = {}
			for _, b in ipairs(payload.buildings) do
				s[b.q .. "," .. b.r] = b
			end
			buildingStates = s
		end

		if payload.connections then
			connections = payload.connections
			local sig = makeSignature(connections)
			if sig ~= connectionSignature then
				connectionSignature = sig
				rebuildVisuals()
			end
		end
	end)
end

print("[Hexagonium] NodeLinks laaditud")
