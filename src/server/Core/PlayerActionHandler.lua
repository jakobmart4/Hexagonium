--[[
	PlayerActionHandler.lua
	Votab kliendilt tegevuspäringud vastu ja valideerib need SERVERIS.

	MAAILMATEADLIK: iga kasitleja alustab sellest, et leiab mangija
	maailma. Varem oli uks globaalne gameState; nuud voib uhes
	serveris olla kuni 6 eraldi saart.

	TURVAPOHIMOTE: klient ei ole kunagi usaldusvaarne. Iga paring
	kontrollitakse siin ule - ja mangija saab tegutseda AINULT oma
	maailmas, sest world tuleb temast, mitte paringust.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local Constants = require(ReplicatedStorage.Shared.Constants)
local CardRegistry = require(ServerScriptService.Cards.CardRegistry)
local MapGenerator = require(ServerScriptService.Core.MapGenerator)
local BuildingFactory = require(ServerScriptService.Buildings.BuildingFactory)
local SaveService = require(ServerScriptService.Core.SaveService)
local CardInfo = require(ReplicatedStorage.Shared.CardInfo)
local Telemetry = require(ServerScriptService.Core.Telemetry)

local PlayerActionHandler = {}
PlayerActionHandler.__index = PlayerActionHandler

function PlayerActionHandler.new(worldManager)
	local self = setmetatable({}, PlayerActionHandler)
	self.worldManager = worldManager
	self.notify = RemoteEvents.Get("Notification")
	return self
end

function PlayerActionHandler:GetWorld(player)
	return self.worldManager.Get(player)
end

function PlayerActionHandler:Notify(player, message, kind, soundHint)
	self.notify:FireClient(player, {
		message = message,
		kind = kind or "info",
		sound = soundHint,
	})
end

-- ============================================================
-- KAARDI AKTIVEERIMINE
-- ============================================================

function PlayerActionHandler:HandleActivateCard(player, request)
	local world = self:GetWorld(player)
	if not world then return end
	if type(request) ~= "table" then return end

	local cardName = request.cardName
	if type(cardName) ~= "string" then
		self:Notify(player, "Invalid card request.", "error")
		return
	end

	if not CardRegistry.Cards[cardName] then
		self:Notify(player, "Unknown card.", "error")
		return
	end

	-- Meta-lukk (Constants.Meta.StartingCards + ostetud kaardid). Klient
	-- naitab lukku ka ise, aga ainult see kontroll siin loeb.
	if not CardInfo.IsUnlocked(SaveService.Get(player), cardName) then
		self:Notify(player, CardInfo.GetDisplayName(cardName) ..
			" is locked - unlock it in MENU.", "warning")
		return
	end

	local cm = world.cardManager

	if cm:IsCardActive(cardName) then
		self:Notify(player, cardName .. " is already active.", "warning")
		return
	end

	local q, r = request.q, request.r
	if CardRegistry.NeedsHex(cardName) then
		if type(q) ~= "number" or type(r) ~= "number" then
			self:Notify(player, "Select a hex first.", "warning", "cardTargetError")
			return
		end
		if not world.hexGrid:GetCell(q, r) then
			self:Notify(player, "That hex does not exist.", "error", "cardTargetError")
			return
		end
	end

	local card = CardRegistry.Create(cardName, q, r)
	if not card then
		self:Notify(player, "Could not create that card.", "error")
		return
	end

	cm:ActivateCard(card, {
		buildings = world.tickService.buildings,
		cardManager = cm,
		hexGrid = world.hexGrid,
		nodeSystem = world.nodeSystem,
		faction = world.faction,
	})

	if world.tutorial then
		world.tutorial:NotifyActivatedCard()
	end

	Telemetry.Event(player, "CardActivated", 1, {cardName})
	self:Notify(player, cardName .. " activated.", "success", "card")
end

-- ============================================================
-- HOONE EHITAMINE
-- ============================================================

function PlayerActionHandler:HandleBuildBuilding(player, request)
	local world = self:GetWorld(player)
	if not world then return end
	if type(request) ~= "table" then return end

	local buildingType = request.buildingType
	local q, r = request.q, request.r

	if type(buildingType) ~= "string" then
		self:Notify(player, "Invalid build request.", "error")
		return
	end

	if not BuildingFactory.IsValidType(buildingType) then
		self:Notify(player, "Unknown building type.", "error")
		return
	end

	if type(q) ~= "number" or type(r) ~= "number" then
		self:Notify(player, "Select a hex first.", "warning")
		return
	end

	local cost = Constants.BuildCosts[buildingType] or 0
	local bank = world.pointBank

	if cost > 0 then
		if not bank or not bank:CanAfford(cost) then
			self:Notify(player, string.format(
				"Need %d UP, you have %d.",
				cost, bank and math.floor(bank:Get()) or 0), "warning")
			return
		end
	end

	local visual, err = MapGenerator.PlaceBuilding(buildingType, q, r, {
		folder = world.folder,
		origin = world.origin,
	})
	if not visual then
		self:Notify(player, tostring(err), "warning")
		return
	end

	local logic = BuildingFactory.Create(buildingType, q, r, world.hexGrid, bank)
	if not logic then
		visual:Destroy()
		self:Notify(player, "Could not create that building.", "error")
		return
	end

	if cost > 0 then
		bank:Spend(cost)
	end

	if world.tutorial and buildingType == "Extractor" then
		world.tutorial:NotifyBuiltExtractor()
	end

	local uniqueName = string.format("%s_%d_%d", buildingType, q, r)
	visual.Name = uniqueName

	world.tickService:RegisterBuilding(logic)
	world.buildings[uniqueName] = logic

	BuildingFactory.LinkDefenders(world.buildings, world.hexGrid)

	self:Notify(player, cost > 0
		and string.format("%s built for %d UP.", buildingType, cost)
		or (buildingType .. " built."), "success", "build")
end

-- ============================================================
-- FRAKTSIOONI OTSUSED
-- ============================================================

function PlayerActionHandler:HandleFactionDecision(player, request)
	local world = self:GetWorld(player)
	if not world then return end
	if type(request) ~= "table" then return end

	local faction = world.faction
	if not faction then
		self:Notify(player, "No faction is active.", "error")
		return
	end

	local accept = request.accept
	if type(accept) ~= "boolean" then
		self:Notify(player, "Invalid decision.", "error")
		return
	end

	local success, message
	if accept then
		success, message = faction:AcceptDemand()
	else
		success, message = faction:RefuseDemand()
	end

	self:Notify(player, message, success and "success" or "warning")
end

-- ============================================================
-- NODE-UHENDUSED
-- ============================================================

local function findBuildingAt(world, q, r)
	for _, b in pairs(world.buildings) do
		if b.q == q and b.r == r and not b.isDestroyed then
			return b
		end
	end
	return nil
end

function PlayerActionHandler:HandleConnectNodes(player, request)
	local world = self:GetWorld(player)
	if not world then return end
	if type(request) ~= "table" then return end

	local fromQ, fromR = request.fromQ, request.fromR
	local toQ, toR = request.toQ, request.toR

	if type(fromQ) ~= "number" or type(fromR) ~= "number"
		or type(toQ) ~= "number" or type(toR) ~= "number"
	then
		self:Notify(player, "Invalid link request.", "error")
		return
	end

	local source = findBuildingAt(world, fromQ, fromR)
	local target = findBuildingAt(world, toQ, toR)

	if not source or not target then
		self:Notify(player, "One of those buildings is gone.", "warning")
		return
	end

	local nodeSystem = world.nodeSystem

	if nodeSystem:IsConnected(source, target) then
		nodeSystem:Disconnect(source, target)
		self:Notify(player, string.format("Link removed: %s to %s.",
			source.buildingType, target.buildingType), "info")
		return
	end

	local ok, reason = nodeSystem:CanConnect(source, target)
	if not ok then
		self:Notify(player, tostring(reason), "warning")
		return
	end

	nodeSystem:Connect(source, target)

	-- Tutorial: Extractor ühendati sobivasse sihtmärki. CanConnect on juba
	-- kontrollinud ressursi (Crystal -> Power Core, Ore -> Refinery). Varem
	-- nõuti Power Core'i ja Ore-extractoriga mängija jäi sammule kinni.
	if world.tutorial and source.buildingType == "Extractor" then
		world.tutorial:NotifyLinkedExtractor()
	end

	self:Notify(player, string.format("Linked %s to %s (priority %d).",
		source.buildingType, target.buildingType, #source.outputConnections), "success", "connect")
end

-- ============================================================
-- HOONE LAMMUTAMINE
-- ============================================================

function PlayerActionHandler:HandleDemolish(player, request)
	local world = self:GetWorld(player)
	if not world then return end
	if type(request) ~= "table" then return end

	local q, r = request.q, request.r
	if type(q) ~= "number" or type(r) ~= "number" then
		self:Notify(player, "Invalid demolish request.", "error")
		return
	end

	local foundKey, foundLogic
	for key, b in pairs(world.buildings) do
		if b.q == q and b.r == r and not b.isDestroyed then
			foundKey, foundLogic = key, b
			break
		end
	end

	if not foundLogic then
		self:Notify(player, "No building there.", "warning")
		return
	end

	local buildingType = foundLogic.buildingType

	local cost = Constants.BuildCosts[buildingType] or 0
	local refund = math.floor(cost * Constants.DemolishRefund)
	if refund > 0 and world.pointBank then
		world.pointBank:Refund(refund)
	end

	foundLogic:Destroy()
	world.tickService:UnregisterBuilding(foundLogic)
	world.buildings[foundKey] = nil

	local buildings = world.folder:FindFirstChild("Buildings")
	if buildings then
		for _, visual in ipairs(buildings:GetChildren()) do
			if visual:GetAttribute("Q") == q and visual:GetAttribute("R") == r then
				visual:Destroy()
				break
			end
		end
	end

	BuildingFactory.LinkDefenders(world.buildings, world.hexGrid)

	self:Notify(player, refund > 0
		and string.format("%s demolished, %d UP refunded.", buildingType, refund)
		or (buildingType .. " demolished."), "success", "demolish")
end

-- ============================================================
-- RUN'I LOPETAMINE JA SAARE LAIENDUS
-- ============================================================

function PlayerActionHandler:HandleExtract(player)
	local world = self:GetWorld(player)
	if not world then return end

	local run = world.runManager
	if not run then
		self:Notify(player, "Run system unavailable.", "error")
		return
	end

	local canExtract, reason = run:CanExtract()
	if not canExtract then
		self:Notify(player, tostring(reason), "warning")
		return
	end

	local result = run:EndRun(run.EndReasons and run.EndReasons.EXTRACT or "Extract")
	if result then
		self:Notify(player, string.format("Extracted with %d UP.", result.payout), "success")
	end
end

-- ============================================================
-- TUTOORIUMI VAHELEJATMINE
-- ============================================================

function PlayerActionHandler:HandleSkipTutorial(player)
	local world = self:GetWorld(player)
	if not world or not world.tutorial then return end

	-- Telemeetria: mitmendal sammul vahele jäeti (ainult päris vahelejätmine)
	if not world.tutorial.complete then
		Telemetry.Event(player, "TutorialSkipped", world.tutorial:GetClientState().step)
	end
	world.tutorial:Complete()
end

-- Infosammu "Next". TutorialTracker:AdvanceInfo lubab ainult PRAEGUST
-- infosammu - klient ei saa sellega tegevussamme vahele jätta.
function PlayerActionHandler:HandleAdvanceTutorial(player, request)
	local world = self:GetWorld(player)
	if not world or not world.tutorial then return end
	if type(request) ~= "table" or type(request.step) ~= "number" then return end

	world.tutorial:AdvanceInfo(request.step)
end

function PlayerActionHandler:HandleExpandIsland(player)
	local world = self:GetWorld(player)
	if not world then return end

	local island = world.islandManager
	if not island then
		self:Notify(player, "Island system unavailable.", "error")
		return
	end

	local success, message = island:TryExpand()
	if success then
		-- 2. väli: run'i minut -> "aeg 1./2. laienduseni" (Play-test B, analüütika)
		local minute = world.runManager and math.floor(world.runManager:GetElapsed() / 60) or 0
		Telemetry.Event(player, "IslandExpanded", island.runExpansions, {island.bonusExpansions, minute})
		if world.tutorial then
			world.tutorial:NotifyExpandedIsland()
		end
	end
	self:Notify(player, message, success and "success" or "warning")
end

-- ============================================================
-- META-OST (Hex Seeds, start screen)
-- ============================================================

function PlayerActionHandler:HandleBuyMetaUpgrade(player, request)
	local world = self:GetWorld(player)
	if not world then return end
	if type(request) ~= "table" then return end

	local data = SaveService.Get(player)
	if not data then
		self:Notify(player, "Save data is not loaded yet.", "error")
		return
	end

	if request.kind == "island" then
		local island = world.islandManager
		if not island then
			self:Notify(player, "Island system unavailable.", "error")
			return
		end

		local isl = Constants.IslandExpansion
		if island.bonusExpansions >= isl.MetaExpansionsMax then
			self:Notify(player, "All permanent expansions are already unlocked.", "warning")
			return
		end

		local cost = (island.bonusExpansions + 1) * Constants.Meta.IslandUpgradeCostPerStep
		if not SaveService.SpendSeeds(player, cost) then
			self:Notify(player, string.format("Need %d Hex Seeds, you have %d.",
				cost, data.hexSeeds), "warning")
			return
		end

		local ok, bonus = island:GrantBonusExpansion()
		if not ok then
			-- Ei tohiks juhtuda (lagi kontrolliti ules), aga raha tagasi
			SaveService.AddSeeds(player, cost)
			self:Notify(player, "Could not unlock the expansion.", "error")
			return
		end

		-- Kehtib KOHE: laienduste lagi loetakse igal CanExpand'il,
		-- saart ei pea uuesti genereerima.
		Telemetry.Economy(player, "Sink", "HexSeeds", cost, data.hexSeeds, "Shop", "ExpansionSlot")
		SaveService.SetBonusExpansions(player, bonus)
		SaveService.SaveSoon(player)
		self:Notify(player, string.format("Island expansions per run: %d.",
			island:GetExpansionsMax()), "success", "build")
		return
	end

	if request.kind == "card" then
		local cardName = request.cardName
		if type(cardName) ~= "string" or not CardRegistry.Cards[cardName] then
			self:Notify(player, "Unknown card.", "error")
			return
		end

		if CardInfo.IsUnlocked(data, cardName) then
			self:Notify(player, CardInfo.GetDisplayName(cardName) .. " is already unlocked.", "warning")
			return
		end

		local cost = Constants.Meta.CardUnlockCost
		if not SaveService.SpendSeeds(player, cost) then
			self:Notify(player, string.format("Need %d Hex Seeds, you have %d.",
				cost, data.hexSeeds), "warning")
			return
		end

		Telemetry.Economy(player, "Sink", "HexSeeds", cost, data.hexSeeds, "Shop", "Card_" .. cardName)
		SaveService.UnlockCard(player, cardName)
		SaveService.SaveSoon(player)
		self:Notify(player, CardInfo.GetDisplayName(cardName) .. " unlocked.", "success", "card")
		return
	end

	self:Notify(player, "Unknown upgrade.", "error")
end

-- ============================================================
-- UHENDAMINE
-- ============================================================

function PlayerActionHandler:Connect()
	local function bind(eventName, handler)
		local remote = RemoteEvents.Get(eventName)
		remote.OnServerEvent:Connect(function(player, request)
			local ok, err = pcall(function()
				handler(self, player, request)
			end)
			if not ok then
				warn("[PlayerActionHandler] " .. eventName .. " viga: " .. tostring(err))
			end
		end)
	end

	bind("ActivateCard", PlayerActionHandler.HandleActivateCard)
	bind("BuildBuilding", PlayerActionHandler.HandleBuildBuilding)
	bind("DemolishBuilding", PlayerActionHandler.HandleDemolish)
	bind("ConnectNodes", PlayerActionHandler.HandleConnectNodes)
	bind("FactionDecision", PlayerActionHandler.HandleFactionDecision)
	bind("ExpandIsland", PlayerActionHandler.HandleExpandIsland)
	bind("ExtractRun", PlayerActionHandler.HandleExtract)
	bind("SkipTutorial", PlayerActionHandler.HandleSkipTutorial)
	bind("BuyMetaUpgrade", PlayerActionHandler.HandleBuyMetaUpgrade)
	bind("AdvanceTutorial", PlayerActionHandler.HandleAdvanceTutorial)
end

return PlayerActionHandler
