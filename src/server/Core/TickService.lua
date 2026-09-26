--[[
	TickService.lua
	Käivitab kõigi registreeritud hoonete Tick()-meetodi ja
	NodeSystem'i ressursivoo täpselt 1 sekundi intervalliga,
	sõltumata FPS-ist (akumuleeritud delta-aeg).
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local GameClock = require(game:GetService("ServerScriptService").Core.GameClock)
local HexGrid = require(game:GetService("ServerScriptService").Hex.HexGrid)

local TickService = {}
TickService.__index = TickService

function TickService.new(nodeSystem)
	local self = setmetatable({}, TickService)

	self.nodeSystem = nodeSystem
	self.cardManager = nil
	self.stateBroadcaster = nil
	self.faction = nil
	self.runManager = nil
	self.buildings = {}

	self.accumulatedTime = 0
	self.running = false
	self.heartbeatConnection = nil

	return self
end

function TickService:SetCardManager(cardManager)
	self.cardManager = cardManager
end

function TickService:SetStateBroadcaster(broadcaster)
	self.stateBroadcaster = broadcaster
end

function TickService:SetFaction(faction)
	self.faction = faction
end

function TickService:SetRunManager(runManager)
	self.runManager = runManager
end

function TickService:RegisterBuilding(building)
	table.insert(self.buildings, building)
	self.nodeSystem:RegisterBuilding(building)
end

function TickService:UnregisterBuilding(building)
	for i, b in ipairs(self.buildings) do
		if b == building then
			table.remove(self.buildings, i)
			break
		end
	end
	self.nodeSystem:UnregisterBuilding(building)
end

-- Üks läbikäik: kõrgeim Town Hall tase (boonus) ja paranduse alad.
-- Ilma Power Core'ita on boonus 1 ja alasid pole.
function TickService:_scanPowerCores()
	local townHall = Constants.Buildings.PowerCore.TownHall
	local bonus = 1
	local zones = {}
	for _, building in ipairs(self.buildings) do
		if building.buildingType == "PowerCore" and not building.isDestroyed then
			local config = townHall[building.level]
			bonus = math.max(bonus, 1 + config.ProductionBonus)
			table.insert(zones, {q = building.q, r = building.r, radius = config.HealRadius})
		end
	end
	return bonus, zones
end


function TickService:Tick()
	local townHallBonus, healZones = self:_scanPowerCores()

	-- 1) Kaardid uuendavad oma tsüklid ja rakendavad kordajad hoonetele
	--    ENNE tootmist, et jooksev tick kasutaks juba õigeid väärtusi.
	if self.cardManager then
		self.cardManager:Tick(self.buildings, {
			buildings = self.buildings,
			cardManager = self.cardManager,
			nodeSystem = self.nodeSystem,
			faction = self.faction,
		})

		-- Town Hall'i boonus KÕIGILE hoonetele (kõrgeim Power Core'i tase)
		-- ja hoone enda tase (Constants.BuildingLevels). CardManager arvutab
		-- kordaja igal tick'il nullist, nii et korrutamine siin ei kuhju.
		for _, building in ipairs(self.buildings) do
			local mult = townHallBonus * building:GetLevelMultiplier()
			if mult ~= 1 and not building.isDestroyed then
				building:SetProductionMultiplier(building:GetProductionMultiplier() * mult)
			end
		end
	end

	-- 2) Hooned toodavad/töötlevad; tervenevad AINULT Power Core'i raadiuses

	for _, building in ipairs(self.buildings) do
		if not building.isDestroyed and building.Tick then
			building:Tick()
		end
		if not building.isDestroyed then
			local inRange = false
			for _, zone in ipairs(healZones) do
				if HexGrid.Distance(nil, building.q, building.r, zone.q, zone.r) <= zone.radius then
					inRange = true
					break
				end
			end
			building.inHealRange = inRange
			if inRange and building.RegenerateHealth then
				building:RegenerateHealth()
			end
		end
	end

	-- 3) Ressursid liiguvad ühenduste kaudu edasi
	self.nodeSystem:Tick()

	-- 4) Fraktsioon: olekuulemingud, Demand taimerid, runnakud
	if self.faction then
		self.faction:Tick()
	end

	-- 5) Run: tasu kogunemine, lopu kontroll
	if self.runManager then
		self.runManager:Tick()
	end

	-- 4) Kliendile saadetakse varskendatud seis (piiratud sagedusega)
	if self.stateBroadcaster then
		self.stateBroadcaster:Tick()
	end
end

function TickService:Start()
	if self.running then
		return
	end
	self.running = true

	local interval = Constants.NodeSystem.TickInterval

	self.heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		-- Mänguaja kiirusega (Studio kiirendus): 1 tick = 1 mängusekund
		self.accumulatedTime = self.accumulatedTime + dt * GameClock.GetSpeed()

		while self.accumulatedTime >= interval do
			self.accumulatedTime = self.accumulatedTime - interval
			self:Tick()
		end
	end)
end

function TickService:Stop()
	if self.heartbeatConnection then
		self.heartbeatConnection:Disconnect()
		self.heartbeatConnection = nil
	end
	self.running = false
end

return TickService
