--[[
	PowerCore.lua
	Toodab energiat crystalist. Omab energia-puhvrit (maxEnergyStorage = 1000).
	Energy Leak kaardi mõjul kaotab energiat protsentuaalselt ja võib peatuda.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local GameClock = require(game:GetService("ServerScriptService").Core.GameClock)
local BuildingBase = require(script.Parent.BuildingBase)

local PowerCore = setmetatable({}, {__index = BuildingBase})
PowerCore.__index = PowerCore

function PowerCore.new(q, r)
	local self = BuildingBase.new("PowerCore", q, r)
	setmetatable(self, PowerCore)

	local config = Constants.Buildings.PowerCore
	self.maxEnergyStorage = config.MaxEnergyStorage
	self.currentEnergy = config.StartingEnergy
	self.level = 1 -- Town Hall tase (Constants.Buildings.PowerCore.TownHall)

	self.energyLeakActive = false
	self.lastLeakTime = GameClock.now()

	return self
end

function PowerCore:SetEnergyLeakActive(active)
	self.energyLeakActive = active
	if active then
		self.lastLeakTime = GameClock.now()
	end
end

function PowerCore:Tick()
	local config = Constants.Buildings.PowerCore
	local now = GameClock.now()

	if self.energyLeakActive then
		if now - self.lastLeakTime >= config.EnergyLeakInterval then
			self.lastLeakTime = now
			self.currentEnergy = self.currentEnergy * config.EnergyLeakMultiplier

			local threshold = self.maxEnergyStorage * config.EnergyLeakPauseThreshold
			if self.currentEnergy < threshold then
				self:Pause(config.EnergyLeakPauseDuration)
			end
		end
	end

	if not self:IsOperational() then
		return 0
	end

	return self.currentEnergy
end

function PowerCore:AddEnergy(amount)
	self.currentEnergy = math.min(self.maxEnergyStorage, self.currentEnergy + amount)
end

function PowerCore:ConsumeEnergy(amount)
	if not self:IsOperational() then
		return false
	end
	if self.currentEnergy < amount then
		return false
	end
	self.currentEnergy = self.currentEnergy - amount
	return true
end

-- Järgmise taseme seaded või nil, kui tase on maksimumis
function PowerCore:GetNextLevel()
	return Constants.Buildings.PowerCore.TownHall[self.level + 1]
end

-- Kulu kontrollib ja võtab PlayerActionHandler; siin ainult efekt
function PowerCore:Upgrade()
	local nextLevel = self:GetNextLevel()
	if not nextLevel then
		return false
	end
	self.level = self.level + 1
	self.maxEnergyStorage = nextLevel.MaxEnergy
	return true
end

function PowerCore:GetEnergyPercent()
	return self.currentEnergy / self.maxEnergyStorage
end

function PowerCore:TryAccept(crystalAmount)
	local config = Constants.Buildings.PowerCore

	-- Flux Tide ja teised energiakaardid mojutavad energiatootmise
	-- tohusust: sama crystal annab rohkem voi vahem energiat.
	local energyPerCrystal = config.EnergyPerCrystal * self:GetProductionMultiplier()

	if energyPerCrystal <= 0 then
		return 0
	end

	local spaceAvailable = self.maxEnergyStorage - self.currentEnergy
	local maxCrystalAcceptable = spaceAvailable / energyPerCrystal

	local accepted = math.min(crystalAmount, maxCrystalAcceptable)
	if accepted > 0 then
		self:AddEnergy(accepted * energyPerCrystal)
	end
	return accepted
end

return PowerCore
