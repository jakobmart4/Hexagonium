--[[
	MapGenerator.lua
	Maailma genereerimine. MAAILMATEADLIK: iga saar elab oma
	nihkes ja oma kaustas, et uhes serveris saaks olla kuni 6
	eraldi saart.

	VAREM: uks saar, alati Workspace.Map, alati koordinaadil (0,0).
	NUUD:  Workspace.Islands.<nimi>, iga oma origin-nihkega.

	Ookean ja hoonemallid on UHISED - neid on motet luua uks kord.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Theme = require(ReplicatedStorage.Shared.Theme)

local MapGenerator = {}

-- ============================================================
-- KONFIGURATSIOON
-- ============================================================

MapGenerator.Defaults = {
	radius = 4,
	maxRadius = 7,
	hexSize = 4,
	hexThickness = 6,
	hexGap = 0.25,
	seed = nil,
	placeDemoBase = true,
}

-- Hexi pealispind on ALATI siin (saare nihke suhtes)
MapGenerator.HEX_TOP_Y = 0.5

-- Saarte paigutus serveris: 3 veergu x 2 rida, 6 kohta
MapGenerator.SLOT_SPACING = 320
MapGenerator.SLOT_COLUMNS = 3
MapGenerator.MAX_SLOTS = 6

MapGenerator.LOCKED_COLOR = Theme.World.hexLocked
MapGenerator.LOCKED_DEPTH = 7

MapGenerator.HexColors = {
	OreHex     = Theme.World.hexOre,
	CrystalHex = Theme.World.hexCrystal,
	Neutral    = Theme.World.hexNeutral,
}

MapGenerator.BuildingColors = {
	Extractor = Theme.World.buildingExtractor,
	PowerCore = Theme.World.buildingPowerCore,
	Refinery  = Theme.World.buildingRefinery,
	Assembler = Theme.World.buildingAssembler,
	Defender  = Theme.World.buildingDefender,
}

-- PrimaryPart'i (aluse) mõõt. Alus istub ALATI hexi pinnal (vt
-- PlaceBuilding: worldPos.Y = origin.Y + HEX_TOP_Y + size.Y/2).
MapGenerator.BuildingSizes = {
	Extractor = Vector3.new(4.2, 1.4, 4.2),
	PowerCore = Vector3.new(4.8, 2.0, 4.8),
	Refinery  = Vector3.new(2.4, 4.0, 2.4),
	Assembler = Vector3.new(4.5, 3.0, 4.5),
	Defender  = Vector3.new(2.0, 4.5, 2.0),
}

-- Aktsendiosa iga hoonetuubi jaoks - annab silhueti, mis eristub
-- teistest hoonetest kujult, mitte ainult varvilt. accentOffset on
-- KOHALIK nihe ALUSE KESKPUNKTIST (mitte hexist) - kord oigesti
-- seatuna liigub kaasa automaatselt, sest Model:PivotTo() liigutab
-- koiki osi korraga (vt PlaceBuilding, CLAUDE.md "Visuaal on
-- loogikast lahutatud").
-- Detaili-varv (tume metall) - ei sobitu Theme.World.buildingXxx
-- varvidega, mis on molemad reserveeritud alus+aktsent jaoks, aga
-- peab eristuma neist molemast, et detail oleks nahtav.
local DETAIL_COLOR = Color3.fromRGB(46, 48, 54)

MapGenerator.BuildingShapes = {
	Extractor = {
		-- Lai madal alus + peenike korge vars = puurivarras
		accentPartType = Enum.PartType.Cylinder,
		accentSize = Vector3.new(1.6, 3.4, 1.6),
		accentOffset = Vector3.new(0, 2.4, 0),
		accentMaterial = Enum.Material.SmoothPlastic,
		baseMaterial = Enum.Material.DiamondPlate,
		-- Puuriots varre tipus - loeb "puurina", mitte lihtsalt vardana
		extraPart = {
			name = "DrillBit",
			partType = Enum.PartType.Cylinder,
			size = Vector3.new(0.8, 1.0, 1.0),
			cframe = CFrame.new(0, 4.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
			material = Enum.Material.Metal,
			color = DETAIL_COLOR,
		},
	},
	PowerCore = {
		-- Alus + helendav energiakera peal
		accentPartType = Enum.PartType.Ball,
		accentSize = Vector3.new(3.6, 3.6, 3.6),
		accentOffset = Vector3.new(0, 2.8, 0),
		accentMaterial = Enum.Material.Neon,
		baseMaterial = Enum.Material.Metal,
		pulse = true, -- energiakera "hingab" - vt PlaceBuilding
	},
	Refinery = {
		-- Kaks paralleelset paaki kõrvuti (alus = paak 1)
		accentPartType = Enum.PartType.Cylinder,
		accentSize = Vector3.new(2.0, 3.6, 2.0),
		accentOffset = Vector3.new(2.3, -0.2, 0),
		accentMaterial = Enum.Material.SmoothPlastic,
		baseMaterial = Enum.Material.Metal,
		-- Ühendustoru paakide vahel - loeb "rafineerimistehasena", mitte
		-- kahe juhusliku paagina
		extraPart = {
			name = "Pipe",
			partType = Enum.PartType.Cylinder,
			size = Vector3.new(1.0, 0.4, 0.4),
			cframe = CFrame.new(1.2, 1.0, 0),
			material = Enum.Material.Metal,
			color = DETAIL_COLOR,
		},
	},
	Assembler = {
		-- Lai alus (tehasehoone) + korsten uhes nurgas
		accentPartType = Enum.PartType.Cylinder,
		accentSize = Vector3.new(1.0, 2.8, 1.0),
		accentOffset = Vector3.new(1.5, 2.9, 1.5),
		accentMaterial = Enum.Material.SmoothPlastic,
		baseMaterial = Enum.Material.Concrete,
	},
	Defender = {
		-- Peenike korge post + helendav sihtimiskera tipus
		accentPartType = Enum.PartType.Ball,
		accentSize = Vector3.new(2.4, 2.4, 2.4),
		accentOffset = Vector3.new(0, 3.45, 0),
		accentMaterial = Enum.Material.Neon,
		baseMaterial = Enum.Material.Metal,
		pulse = true, -- sihtimiskera vilgub - vt PlaceBuilding
		-- Kahurutoru kera kulje - loeb "turnina", mitte lihtsalt postiga kerana
		extraPart = {
			name = "Barrel",
			partType = Enum.PartType.Cylinder,
			size = Vector3.new(1.8, 0.35, 0.35),
			cframe = CFrame.new(1.6, 3.45, 0),
			material = Enum.Material.Metal,
			color = DETAIL_COLOR,
		},
	},
}

MapGenerator.NoiseConfig = {
	scale = 0.28,
	crystalThreshold = 0.22,
	oreThreshold = 0.02,
}

MapGenerator.MinResources = {ore = 6, crystal = 4}

-- ============================================================
-- SLOTID: kus uks saar serveris asub
-- ============================================================

function MapGenerator.GetSlotOrigin(slotIndex)
	local i = (slotIndex - 1) % MapGenerator.MAX_SLOTS
	local col = i % MapGenerator.SLOT_COLUMNS
	local row = math.floor(i / MapGenerator.SLOT_COLUMNS)

	-- Tsentreerime ruudustiku nulli umber
	local xOffset = (col - (MapGenerator.SLOT_COLUMNS - 1) / 2) * MapGenerator.SLOT_SPACING
	local zOffset = (row - 0.5) * MapGenerator.SLOT_SPACING

	return Vector3.new(xOffset, 0, zOffset)
end

-- ============================================================
-- KOORDINAADID
-- ============================================================

-- Hexi asukoht SAARE SEES (ilma nihketa)
function MapGenerator.AxialToLocal(q, r, hexSize)
	hexSize = hexSize or MapGenerator.Defaults.hexSize
	local x = hexSize * (math.sqrt(3) * q + math.sqrt(3) / 2 * r)
	local z = hexSize * (3 / 2 * r)
	return Vector3.new(x, 0, z)
end

-- Hexi asukoht MAAILMAS (koos saare nihkega)
function MapGenerator.AxialToWorld(q, r, hexSize, origin)
	local localPos = MapGenerator.AxialToLocal(q, r, hexSize)
	return localPos + (origin or Vector3.new())
end

-- ============================================================
-- HEX-TUUBI MAARAMINE (Perlin-mura)
-- ============================================================

local function seedOffsets(seed)
	local rng = Random.new(seed)
	return rng:NextNumber(0, 1000), rng:NextNumber(0, 1000)
end

function MapGenerator.GetHexType(q, r, seed, offsets)
	local cfg = MapGenerator.NoiseConfig

	local oreOffset, crystalOffset
	if offsets then
		oreOffset, crystalOffset = offsets[1], offsets[2]
	else
		oreOffset, crystalOffset = seedOffsets(seed or 0)
	end

	local nx = (q + r * 0.5) * cfg.scale
	local ny = (r * 0.866) * cfg.scale

	if math.noise(nx + crystalOffset, ny + crystalOffset) > cfg.crystalThreshold then
		return Constants.HexTypes.CRYSTAL_HEX
	end

	if math.noise(nx + oreOffset, ny + oreOffset) > cfg.oreThreshold then
		return Constants.HexTypes.ORE_HEX
	end

	return nil
end

-- ============================================================
-- UHISED OSAD: ookean ja hoonemallid
-- ============================================================

function MapGenerator.EnsureOcean()
	local terrain = Workspace.Terrain

	-- Kui vesi on juba olemas, ara tee uuesti
	if terrain:GetAttribute("HexagoniumOcean") then
		return
	end

	terrain:Clear()

	-- Katab koik 6 slotti pluss varu
	local extent = 1200
	local depth = 60
	local waterLevel = -2

	terrain:FillBlock(
		CFrame.new(0, waterLevel - depth / 2, 0),
		Vector3.new(extent * 2, depth, extent * 2),
		Enum.Material.Water
	)

	terrain:SetAttribute("HexagoniumOcean", true)

	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate.Transparency = 1
		baseplate.CanCollide = false
	end

	for _, obj in ipairs(Workspace:GetChildren()) do
		if obj:IsA("SpawnLocation") then
			obj.Transparency = 1
			obj.CanCollide = false
			obj.Anchored = true
			obj.Position = Vector3.new(0, -60, 0)
			local decal = obj:FindFirstChildOfClass("Decal")
			if decal then decal:Destroy() end
		end
	end
end

function MapGenerator.CreateBuildingTemplates()
	local existing = ReplicatedStorage:FindFirstChild("BuildingTemplates")
	if existing then
		return #existing:GetChildren()
	end

	local templates = Instance.new("Folder")
	templates.Name = "BuildingTemplates"
	templates.Parent = ReplicatedStorage

	local created = 0
	for buildingType, color in pairs(MapGenerator.BuildingColors) do
		local size = MapGenerator.BuildingSizes[buildingType]
		local shape = MapGenerator.BuildingShapes[buildingType]

		local model = Instance.new("Model")
		model.Name = buildingType .. "Template"

		-- Alus: ALATI PrimaryPart, ALATI Block (vaikimisi kuju, ROTEERIMATA).
		-- PlaceBuilding loeb otse PrimaryPart.Size.Y kui MAAILMA vertikaalset
		-- korgust (worldPos.Y = origin.Y + HEX_TOP_Y + size.Y/2) - Size on
		-- alati KOHALIKUS ruumis, seega roteeritud Cylinder'i Size.Y ei
		-- vastaks enam tegelikule korgusele. Seepärast on alus alati Block;
		-- silueti annab aktsendiosa (vt allpool).
		local base = Instance.new("Part")
		base.Name = "Body"
		base.Shape = Enum.PartType.Block
		base.Size = size
		base.Color = color
		base.Material = (shape and shape.baseMaterial) or Enum.Material.SmoothPlastic
		base.Anchored = true
		base.CanCollide = true
		base.Parent = model

		local topOffsetFromBaseBottom = size.Y

		if shape then
			local accentPart = Instance.new("Part")
			accentPart.Name = "Accent"
			accentPart.Shape = shape.accentPartType
			accentPart.Color = color
			accentPart.Material = shape.accentMaterial
			accentPart.Anchored = true
			accentPart.CanCollide = true

			if shape.accentPartType == Enum.PartType.Cylinder then
				-- Cylinder'i telg on Robloxis ALATI kohalik X, seega
				-- "korgus" (meie tabelis Size.Y) laheb Size.X'i ja part
				-- keeratakse 90 kraadi Z umber, et telg saaks vertikaalne
				-- (kohalik +X -> maailma +Y sellise poordega).
				accentPart.Size = Vector3.new(
					shape.accentSize.Y, shape.accentSize.X, shape.accentSize.Z
				)
				accentPart.CFrame = CFrame.new(shape.accentOffset) * CFrame.Angles(0, 0, math.rad(90))
			else
				accentPart.Size = shape.accentSize
				accentPart.CFrame = CFrame.new(shape.accentOffset)
			end

			accentPart.Parent = model

			topOffsetFromBaseBottom = math.max(
				size.Y,
				size.Y / 2 + shape.accentOffset.Y + shape.accentSize.Y / 2
			)

			-- Vaike detailosa (puuriots/toru/kahurutoru) - puhtalt
			-- kosmeetiline, ei mojuta topOffsetFromBaseBottom't, sest
			-- pole kunagi korgeim punkt.
			if shape.extraPart then
				local ep = shape.extraPart
				local extra = Instance.new("Part")
				extra.Name = ep.name
				extra.Shape = ep.partType
				extra.Size = ep.size
				extra.CFrame = ep.cframe
				extra.Color = ep.color or color
				extra.Material = ep.material or Enum.Material.SmoothPlastic
				extra.Anchored = true
				extra.CanCollide = false
				extra.Parent = model
			end
		end

		local billboard = Instance.new("BillboardGui")
		billboard.Name = "Label"
		billboard.Size = UDim2.new(0, 110, 0, 26)
		billboard.StudsOffset = Vector3.new(0, topOffsetFromBaseBottom - size.Y / 2 + 1.5, 0)
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 200
		billboard.Parent = base

		local text = Instance.new("TextLabel")
		text.Name = "NameLabel"
		text.Size = UDim2.new(1, 0, 1, 0)
		text.BackgroundTransparency = 1
		text.Text = buildingType
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextStrokeTransparency = 0.2
		text.TextScaled = true
		text.Font = Theme.Font.bold
		text.Parent = billboard

		model.PrimaryPart = base
		model:SetAttribute("BuildingType", buildingType)
		model.Parent = templates
		created += 1
	end

	return created
end

-- ============================================================
-- HEXI KUJU
-- ============================================================

function MapGenerator.GetHexTemplates()
	return ReplicatedStorage:FindFirstChild("HexTemplates")
end

function MapGenerator.CreateHexPart(typeName, isLocked, hexSize, thickness, gap)
	gap = gap or MapGenerator.Defaults.hexGap or 0

	local flatToFlat = math.sqrt(3) * hexSize
	local cornerToCorner = 2 * hexSize
	local shrink = (flatToFlat - gap) / flatToFlat

	local templates = MapGenerator.GetHexTemplates()
	assert(templates, "ReplicatedStorage.HexTemplates puudub - hexe ei saa luua")

	local templateName = isLocked and "HexTemplate_Locked"
		or ("HexTemplate_" .. typeName)
	local template = templates:FindFirstChild(templateName)
		or templates:FindFirstChild("HexTemplate_Neutral")
	assert(template, "Hexi malli ei leitud: " .. templateName)

	local part = template:Clone()
	part.Size = Vector3.new(cornerToCorner * shrink, thickness, flatToFlat * shrink)
	part.Anchored = true
	part.CanCollide = true
	return part
end

-- ============================================================
-- SAARE KAUST
-- ============================================================

local function getIslandsRoot()
	local root = Workspace:FindFirstChild("Islands")
	if not root then
		root = Instance.new("Folder")
		root.Name = "Islands"
		root.Parent = Workspace
	end
	return root
end

function MapGenerator.CreateIslandFolder(name, origin)
	local root = getIslandsRoot()

	local existing = root:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder:SetAttribute("OriginX", origin.X)
	folder:SetAttribute("OriginZ", origin.Z)
	folder.Parent = root

	local hexes = Instance.new("Folder")
	hexes.Name = "Hexes"
	hexes.Parent = folder

	local buildings = Instance.new("Folder")
	buildings.Name = "Buildings"
	buildings.Parent = folder

	local attackers = Instance.new("Folder")
	attackers.Name = "Attackers"
	attackers.Parent = folder

	return folder
end

function MapGenerator.DestroyIsland(folder)
	if folder and folder.Parent then
		folder:Destroy()
	end
end

-- ============================================================
-- SAARE GENEREERIMINE
-- config: {folder, origin, radius, maxRadius, hexSize, hexThickness,
--          hexGap, seed}
-- ============================================================

function MapGenerator.GenerateIsland(config)
	local folder = config.folder
	assert(folder, "GenerateIsland vajab folder'it")

	local origin = config.origin or Vector3.new()
	local radius = config.radius or MapGenerator.Defaults.radius
	local maxRadius = config.maxRadius or MapGenerator.Defaults.maxRadius
	local hexSize = config.hexSize or MapGenerator.Defaults.hexSize
	local thickness = config.hexThickness or MapGenerator.Defaults.hexThickness
	local gap = config.hexGap or MapGenerator.Defaults.hexGap

	local seed = config.seed
	if seed == nil then
		seed = Random.new():NextInteger(1, 2147483646)
	end
	local offsets = {seedOffsets(seed)}

	if maxRadius < radius then
		maxRadius = radius
	end

	local hexes = folder:FindFirstChild("Hexes")
	hexes:ClearAllChildren()

	local count, lockedCount = 0, 0

	local function hexDistance(q, r)
		return (math.abs(q) + math.abs(q + r) + math.abs(r)) / 2
	end

	for dq = -maxRadius, maxRadius do
		local rMin = math.max(-maxRadius, -dq - maxRadius)
		local rMax = math.min(maxRadius, -dq + maxRadius)

		for dr = rMin, rMax do
			local q, r = dq, dr
			local dist = hexDistance(q, r)
			local isLocked = dist > radius

			local hexType = MapGenerator.GetHexType(q, r, seed, offsets)
			local typeName = hexType or "Neutral"

			local part = MapGenerator.CreateHexPart(typeName, isLocked, hexSize, thickness, gap)
			part.Name = string.format("Hex_%d_%d", q, r)

			local topY = MapGenerator.HEX_TOP_Y
			if isLocked then
				part.Color = MapGenerator.LOCKED_COLOR
				topY = topY - MapGenerator.LOCKED_DEPTH
				lockedCount += 1
			else
				part.Color = MapGenerator.HexColors[typeName]
			end

			local worldPos = MapGenerator.AxialToWorld(q, r, hexSize, origin)
			part.CFrame = CFrame.new(worldPos.X, origin.Y + topY - thickness / 2, worldPos.Z)
				* CFrame.Angles(0, math.rad(90), 0)

			part:SetAttribute("Q", q)
			part:SetAttribute("R", r)
			part:SetAttribute("HexType", typeName)
			part:SetAttribute("Locked", isLocked)
			part:SetAttribute("Ring", dist)

			part.Parent = hexes
			count += 1
		end
	end

	local guaranteed = MapGenerator.EnsureMinimumResources(hexes)

	local typeCounts = {OreHex = 0, CrystalHex = 0, Neutral = 0}
	for _, part in ipairs(hexes:GetChildren()) do
		if part:GetAttribute("Locked") ~= true then
			local t = part:GetAttribute("HexType")
			typeCounts[t] = (typeCounts[t] or 0) + 1
		end
	end

	return {
		total = count,
		active = count - lockedCount,
		locked = lockedCount,
		ore = typeCounts.OreHex,
		crystal = typeCounts.CrystalHex,
		neutral = typeCounts.Neutral,
		seed = seed,
		guaranteed = guaranteed,
	}
end

-- ============================================================
-- RESSURSSIDE MIINIMUMGARANTII
-- ============================================================

function MapGenerator.EnsureMinimumResources(hexes)
	local minOre = MapGenerator.MinResources.ore
	local minCrystal = MapGenerator.MinResources.crystal

	local oreCount, crystalCount = 0, 0
	local neutrals = {}

	for _, part in ipairs(hexes:GetChildren()) do
		if part:GetAttribute("Locked") ~= true then
			local t = part:GetAttribute("HexType")
			if t == "OreHex" then
				oreCount += 1
			elseif t == "CrystalHex" then
				crystalCount += 1
			else
				table.insert(neutrals, part)
			end
		end
	end

	if oreCount >= minOre and crystalCount >= minCrystal then
		return {ore = 0, crystal = 0}
	end

	table.sort(neutrals, function(a, b)
		local ra = a:GetAttribute("Ring") or 0
		local rb = b:GetAttribute("Ring") or 0
		if ra == rb then
			return a.Name < b.Name
		end
		return ra < rb
	end)

	local addedOre, addedCrystal = 0, 0
	local index = 1

	while crystalCount + addedCrystal < minCrystal and index <= #neutrals do
		local part = neutrals[index]
		part:SetAttribute("HexType", "CrystalHex")
		part.Color = MapGenerator.HexColors.CrystalHex
		addedCrystal += 1
		index += 1
	end

	while oreCount + addedOre < minOre and index <= #neutrals do
		local part = neutrals[index]
		part:SetAttribute("HexType", "OreHex")
		part.Color = MapGenerator.HexColors.OreHex
		addedOre += 1
		index += 1
	end

	return {ore = addedOre, crystal = addedCrystal}
end

-- ============================================================
-- SAARE LAIENDUS
-- ============================================================

function MapGenerator.GetNextLockedRing(folder)
	local hexes = folder and folder:FindFirstChild("Hexes")
	if not hexes then
		return nil
	end

	local lowest = nil
	for _, part in ipairs(hexes:GetChildren()) do
		if part:GetAttribute("Locked") == true then
			local ring = part:GetAttribute("Ring")
			if ring and (lowest == nil or ring < lowest) then
				lowest = ring
			end
		end
	end
	return lowest
end

-- Kui palju sekundeid ronga hexide vahel viivitada, et laienemine
-- naeks valja nagu LAINE, mitte kogu ronga korraga vee alt hupamine.
local RING_REVEAL_STAGGER = 0.035

function MapGenerator.UnlockRing(folder, ringNumber, config)
	config = config or {}
	local thickness = config.hexThickness or MapGenerator.Defaults.hexThickness
	local animate = config.animate ~= false

	local hexes = folder and folder:FindFirstChild("Hexes")
	if not hexes then
		return 0
	end

	local originY = 0

	local ringParts = {}
	for _, part in ipairs(hexes:GetChildren()) do
		if part:GetAttribute("Locked") == true and part:GetAttribute("Ring") == ringNumber then
			table.insert(ringParts, part)
		end
	end

	-- Sorteeri nurga jargi umber saare keskpunkti, et laine leviks
	-- radiaalselt (mitte GetChildren'i juhuslikus jarjekorras).
	if animate then
		table.sort(ringParts, function(a, b)
			local aAngle = math.atan2(a:GetAttribute("R"), a:GetAttribute("Q"))
			local bAngle = math.atan2(b:GetAttribute("R"), b:GetAttribute("Q"))
			return aAngle < bAngle
		end)
	end

	for i, part in ipairs(ringParts) do
		local typeName = part:GetAttribute("HexType") or "Neutral"
		local targetY = originY + MapGenerator.HEX_TOP_Y - thickness / 2
		local pos = part.Position
		local targetCFrame = CFrame.new(pos.X, targetY, pos.Z) * part.CFrame.Rotation

		part:SetAttribute("Locked", false)

		if animate then
			task.delay((i - 1) * RING_REVEAL_STAGGER, function()
				local info = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				TweenService:Create(part, info, {
					CFrame = targetCFrame,
					Color = MapGenerator.HexColors[typeName],
				}):Play()
			end)
		else
			part.CFrame = targetCFrame
			part.Color = MapGenerator.HexColors[typeName]
		end
	end

	return #ringParts
end

-- ============================================================
-- HOONE PAIGUTAMINE
-- ============================================================

function MapGenerator.PlaceBuilding(buildingType, q, r, config)
	config = config or {}
	local folder = config.folder
	if not folder then
		return nil, "Saare kaust puudub"
	end

	local origin = config.origin or Vector3.new()
	local hexSize = config.hexSize or MapGenerator.Defaults.hexSize
	local customName = config.name

	local templates = ReplicatedStorage:FindFirstChild("BuildingTemplates")
	if not templates then
		return nil, "BuildingTemplates puudub"
	end

	local template = templates:FindFirstChild(buildingType .. "Template")
	if not template then
		return nil, "Malli ei leitud: " .. buildingType
	end

	local hexes = folder:FindFirstChild("Hexes")
	local buildings = folder:FindFirstChild("Buildings")
	if not hexes or not buildings then
		return nil, "Saare struktuur on puudulik"
	end

	local hexPart = hexes:FindFirstChild(string.format("Hex_%d_%d", q, r))
	if not hexPart then
		return nil, string.format("Hexi (%d, %d) ei ole olemas", q, r)
	end

	if hexPart:GetAttribute("Locked") == true then
		return nil, string.format("Hex (%d, %d) on veel vee all", q, r)
	end

	for _, existing in ipairs(buildings:GetChildren()) do
		if existing:GetAttribute("Q") == q and existing:GetAttribute("R") == r then
			return nil, string.format("Hex (%d, %d) on juba hoivatud", q, r)
		end
	end

	if buildingType == "Extractor" then
		local hexType = hexPart:GetAttribute("HexType")
		if hexType ~= Constants.HexTypes.ORE_HEX and hexType ~= Constants.HexTypes.CRYSTAL_HEX then
			return nil, "Extractor vajab Ore voi Crystal hexi"
		end
	end

	local clone = template:Clone()
	local size = clone.PrimaryPart.Size
	local worldPos = MapGenerator.AxialToWorld(q, r, hexSize, origin)

	clone:PivotTo(CFrame.new(
		worldPos.X,
		origin.Y + MapGenerator.HEX_TOP_Y + size.Y / 2,
		worldPos.Z
	))

	clone:SetAttribute("Q", q)
	clone:SetAttribute("R", r)
	clone.Name = customName or buildingType
	clone.Parent = buildings

	-- Energiaosade pulseerimine (PowerCore/Defender) - Tween on seotud
	-- osa enda eluajaga, Roblox koristab selle automaatselt kui
	-- hoone havib/lammutatakse, seega eraldi cleanup pole vaja.
	local shape = MapGenerator.BuildingShapes[buildingType]
	if shape and shape.pulse then
		local accent = clone:FindFirstChild("Accent")
		if accent then
			TweenService:Create(
				accent,
				TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{Transparency = 0.45}
			):Play()
		end
	end

	return clone
end

-- ============================================================
-- DEMO-BAAS
-- ============================================================

function MapGenerator.PlaceDemoBase(config)
	local folder = config.folder
	local hexes = folder:FindFirstChild("Hexes")
	local buildings = folder:FindFirstChild("Buildings")
	buildings:ClearAllChildren()

	local occupied = {}
	local placed, failed = {}, {}

	local function findFreeHex(hexType)
		for _, hex in ipairs(hexes:GetChildren()) do
			if hex:GetAttribute("HexType") == hexType and hex:GetAttribute("Locked") ~= true then
				local q, r = hex:GetAttribute("Q"), hex:GetAttribute("R")
				if not occupied[q .. "," .. r] then
					return q, r
				end
			end
		end
		return nil
	end

	local function findFreeNeighbor(q, r)
		local DIRS = {{1,0},{1,-1},{0,-1},{-1,0},{-1,1},{0,1}}
		for _, d in ipairs(DIRS) do
			local nq, nr = q + d[1], r + d[2]
			local hex = hexes:FindFirstChild(string.format("Hex_%d_%d", nq, nr))
			if not occupied[nq .. "," .. nr] and hex and hex:GetAttribute("Locked") ~= true then
				return nq, nr
			end
		end
		return nil
	end

	local function place(buildingType, q, r, name)
		if not q then
			table.insert(failed, (name or buildingType) .. ": sobivat hexi ei leitud")
			return nil
		end
		local model, err = MapGenerator.PlaceBuilding(buildingType, q, r, {
			folder = folder,
			origin = config.origin,
			hexSize = config.hexSize,
			name = name,
		})
		if model then
			occupied[q .. "," .. r] = true
			table.insert(placed, string.format("%s (%d, %d)", name or buildingType, q, r))
			return q, r
		end
		table.insert(failed, (name or buildingType) .. ": " .. tostring(err))
		return nil
	end

	local cq, cr = findFreeHex(Constants.HexTypes.CRYSTAL_HEX)
	local eq, er = place("Extractor", cq, cr, "Extractor")
	if eq then
		local pq, pr = findFreeNeighbor(eq, er)
		local gq, gr = place("PowerCore", pq, pr, "PowerCore")
		if gq then
			local dq, dr = findFreeNeighbor(gq, gr)
			place("Defender", dq, dr, "Defender")
		end
	end

	local oq, orr = findFreeHex(Constants.HexTypes.ORE_HEX)
	local xq, xr = place("Extractor", oq, orr, "ExtractorOre")
	if xq then
		local rq, rr = findFreeNeighbor(xq, xr)
		local fq, fr = place("Refinery", rq, rr, "Refinery")
		if fq then
			local aq, ar = findFreeNeighbor(fq, fr)
			place("Assembler", aq, ar, "Assembler")
		end
	end

	return {placed = placed, failed = failed}
end

return MapGenerator
