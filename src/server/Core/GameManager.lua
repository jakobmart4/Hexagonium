--[[
	GameManager.lua
	Loob UHE MAAILMA: saar, selle loogika ja süsteemid.

	VAREM: uks globaalne mang (GameManager.Start).
	NUUD:  CreateWorld(config) - iga mangija saab oma maailma.

	Maailm ei tea teistest maailmadest midagi. Koik, mis tal on,
	on oma folder, origin ja oma susteemid. See on ka see, mis
	teeb co-op'i hiljem lihtsaks: co-op = mitu mangijat UHES
	maailmas, mitte uus arhitektuur.

	MARKUS: PlayerActionHandler EI ole siin - see on globaalne ja
	elab WorldManager'is, sest ta peab suunama iga mangija oma
	maailma.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HexGrid = require(ServerScriptService.Hex.HexGrid)
local NodeSystem = require(ServerScriptService.Resources.NodeSystem)
local TickService = require(ServerScriptService.Core.TickService)
local CardManager = require(ServerScriptService.Cards.CardManager)
local StateBroadcaster = require(ServerScriptService.Core.StateBroadcaster)
local MapGenerator = require(ServerScriptService.Core.MapGenerator)
local IslandManager = require(ServerScriptService.Core.IslandManager)
local RunManager = require(ServerScriptService.Core.RunManager)
local TutorialTracker = require(ServerScriptService.Core.TutorialTracker)
local PointBank = require(ServerScriptService.Resources.PointBank)
local BuildingFactory = require(ServerScriptService.Buildings.BuildingFactory)
local FractureSyndicate = require(ServerScriptService.Factions.FractureSyndicate)
local Constants = require(ReplicatedStorage.Shared.Constants)

local GameManager = {}

-- ============================================================
-- MAAILMA SUSTEEMIDE EHITUS
--
-- UHINE nii esimese loomise (CreateWorld) kui run'i taaskaivituse
-- (RestartRun) vahel. Vahe on ainult selles, KES kutsub ja mis
-- seed kaasa antakse - islandManager (pusiv, sailib
-- run'ide vahel) ja world.owners (mangijad ei vaheta) JAAVAD ALLES,
-- koik ulejaanu (saar, hooned, kaardid, pank, run) tehakse uuesti.
-- ============================================================
local function buildWorldSystems(world, seed)
	local islandConfig = Constants.IslandExpansion
	local folder = world.folder
	local origin = world.origin

	-- 1) Genereeri saar sellesse kausta
	local gridStats = MapGenerator.GenerateIsland({
		folder = folder,
		origin = origin,
		radius = islandConfig.StartRadius, -- ALATI sama algsaar, vt IslandManager
		maxRadius = islandConfig.MaxRadius,
		seed = seed,
	})

	MapGenerator.PlaceDemoBase({folder = folder, origin = origin})

	-- 2) Loe hexid HexGrid'i
	local hexGrid = HexGrid.new()
	for _, hexPart in ipairs(folder.Hexes:GetChildren()) do
		local hexType = hexPart:GetAttribute("HexType")
		if hexType == "OreHex" or hexType == "CrystalHex" then
			hexGrid:SetHexType(hexPart:GetAttribute("Q"), hexPart:GetAttribute("R"), hexType)
		end
	end

	local nodeSystem = NodeSystem.new()
	local cardManager = CardManager.new()
	local pointBank = PointBank.new()
	local tickService = TickService.new(nodeSystem)
	tickService:SetCardManager(cardManager)

	-- 3) Loogika-instantsid
	local logicByVisualName = {}
	for _, visual in ipairs(folder.Buildings:GetChildren()) do
		local logic = BuildingFactory.Create(
			visual:GetAttribute("BuildingType"),
			visual:GetAttribute("Q"),
			visual:GetAttribute("R"),
			hexGrid,
			pointBank
		)
		if logic then
			tickService:RegisterBuilding(logic)
			logicByVisualName[visual.Name] = logic
		end
	end

	world.hexGrid = hexGrid
	world.nodeSystem = nodeSystem
	world.cardManager = cardManager
	world.pointBank = pointBank
	world.tickService = tickService
	world.buildings = logicByVisualName
	world.seed = gridStats.seed

	-- 4) Demo-ahela uhendused
	local ex = logicByVisualName["Extractor"]
	local exOre = logicByVisualName["ExtractorOre"]
	local core = logicByVisualName["PowerCore"]
	local refinery = logicByVisualName["Refinery"]
	local assembler = logicByVisualName["Assembler"]
	local defender = logicByVisualName["Defender"]

	if ex and core then nodeSystem:Connect(ex, core) end
	if exOre and refinery then nodeSystem:Connect(exOre, refinery) end
	if refinery and assembler then nodeSystem:Connect(refinery, assembler) end
	if defender and core then defender:LinkPowerCore(core) end

	-- 5) Susteemid
	local broadcaster = StateBroadcaster.new(world)
	tickService:SetStateBroadcaster(broadcaster)
	world.stateBroadcaster = broadcaster

	world.runManager = RunManager.new(world)
	tickService:SetRunManager(world.runManager)

	world.faction = FractureSyndicate.new(world)
	tickService:SetFaction(world.faction)

	tickService:Start()
end

-- config: {slot, origin, folder, bonusExpansions, seed, tutorialComplete}
function GameManager.CreateWorld(config)

	local world = {
		slot = config.slot,
		origin = config.origin or Vector3.new(),
		folder = config.folder,
		owners = {},
	}

	-- Pusivad run'ide ule - EI looda RestartRun'is uuesti
	world.islandManager = IslandManager.new(world, config.bonusExpansions)
	world.tutorial = TutorialTracker.new(config.tutorialComplete)

	buildWorldSystems(world, config.seed)

	return world
end

-- Alustab UUE run'i SAMAS maailmas: saar taasgenereeritakse uue
-- juhusliku seemnega, ostetud lisalaiendused sailivad (islandManager pusib),
-- run-laiendused kaovad (ResetForNewRun). Kutsutakse pärast
-- RunManager:EndRun'i, vt Bootstrap.server.lua.
function GameManager.RestartRun(world)
	if world.tickService then
		world.tickService:Stop()
	end
	if world.faction and world.faction.attackManager then
		world.faction.attackManager:EndWave()
	end

	world.islandManager:ResetForNewRun()
	buildWorldSystems(world, nil)

	return world
end

-- Peatab maailma ja kustutab tema saare
function GameManager.DestroyWorld(world)
	if not world then
		return
	end

	if world.tickService then
		world.tickService:Stop()
	end

	if world.faction and world.faction.attackManager then
		world.faction.attackManager:EndWave()
	end

	MapGenerator.DestroyIsland(world.folder)
end

return GameManager
