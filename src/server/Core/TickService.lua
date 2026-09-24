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

function TickService:_getTownHallBonus()
	local level = 1
	for _, building in ipairs(self.buildings) do
		if building.buildingType == "PowerCore" and not building.isDestroyed and building.level > level then
			level = building.level
		end
	end
	local config = Constants.Buildings.PowerCore.TownHall[level]
	return config and (1 + config.ProductionBonus) or 1
end

function TickService:Tick()
	-- 1) Kaardid uuendavad oma tsüklid ja rakendavad kordajad hoonetele
	--    ENNE tootmist, et jooksev tick kasutaks juba õigeid väärtusi.
	if self.cardManager then
		self.cardManager:Tick(self.buildings, {
			buildings = self.buildings,
			cardManager = self.cardManager,
			nodeSystem = self.nodeSystem,
			faction = self.faction,
		})

		-- Town Hall: kõrgeima Power Core'i taseme boonus KÕIGILE hoonetele.
		-- CardManager arvutab kordaja igal tick'il nullist, nii et korrutamine
		-- siin ei kuhju.
		local bonus = self:_getTownHallBonus()
		if bonus ~= 1 then
			for _, building in ipairs(self.buildings) do
				if not building.isDestroyed then
					building:SetProductionMultiplier(building:GetProductionMultiplier() * bonus)
				end
			end
		end
	end

	-- 2) Hooned toodavad/töötlevad
	for _, building in ipairs(self.buildings) do
		if not building.isDestroyed and building.Tick then
			building:Tick()
		end
		-- Elupunktide aeglane taastumine
		if not building.isDestroyed and building.RegenerateHealth then
			building:RegenerateHealth()
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
