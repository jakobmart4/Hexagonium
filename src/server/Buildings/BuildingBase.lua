--[[
	BuildingBase.lua
	Kõigi hoonete ühine baasklass: input/output nodes, peatumise loogika,
	mutatsioonide rakendamine.
]]

local BuildingBase = {}
BuildingBase.__index = BuildingBase

local Constants = require(game:GetService("ReplicatedStorage").Shared.Constants)
local GameClock = require(game:GetService("ServerScriptService").Core.GameClock)

function BuildingBase.new(buildingType, q, r)
	local self = setmetatable({}, BuildingBase)

	self.buildingType = buildingType
	self.q = q
	self.r = r

	self.inputConnections = {}
	self.outputConnections = {}

	self.isPaused = false
	self.pauseEndTime = nil
	self.isDestroyed = false

	self.activeMultipliers = {
		production = 1.0,
		defense = 1.0,
	}

	-- Null Surge efektifaasis tõene: hoone toodab ilma sisendressursita
	self.ignoreInputs = false

	-- Elupunktid. Uks vaartus koigile hoonetele (MVP lihtsus).
	self.maxHealth = Constants.Attack.BuildingHealth
	self.health = self.maxHealth
	self.lastDamageTime = nil

	return self
end

function BuildingBase:ConnectOutput(targetBuilding)
	table.insert(self.outputConnections, targetBuilding)
	table.insert(targetBuilding.inputConnections, self)
end

function BuildingBase:DisconnectOutput(targetBuilding)
	for i, conn in ipairs(self.outputConnections) do
		if conn == targetBuilding then
			table.remove(self.outputConnections, i)
			break
		end
	end
	for i, conn in ipairs(targetBuilding.inputConnections) do
		if conn == self then
			table.remove(targetBuilding.inputConnections, i)
			break
		end
	end
end

function BuildingBase:DisconnectAll()
	for _, target in ipairs(table.clone(self.outputConnections)) do
		self:DisconnectOutput(target)
	end
	for _, source in ipairs(table.clone(self.inputConnections)) do
		source:DisconnectOutput(self)
	end
end

function BuildingBase:Pause(duration)
	self.isPaused = true
	self.pauseEndTime = GameClock.now() + duration
end

function BuildingBase:UpdatePauseState()
	if self.isPaused and self.pauseEndTime and GameClock.now() >= self.pauseEndTime then
		self.isPaused = false
		self.pauseEndTime = nil
	end
end

function BuildingBase:IsOperational()
	self:UpdatePauseState()
	return not self.isPaused and not self.isDestroyed
end

function BuildingBase:Destroy()
	self.isDestroyed = true
	self:DisconnectAll()
end

function BuildingBase:SetProductionMultiplier(value)
	self.activeMultipliers.production = value
end

function BuildingBase:GetProductionMultiplier()
	return self.activeMultipliers.production
end

function BuildingBase:SetDefenseMultiplier(value)
	self.activeMultipliers.defense = value
end

function BuildingBase:GetDefenseMultiplier()
	return self.activeMultipliers.defense
end

-- CardManager seab selle igal tickil (Null Surge efektifaas).
function BuildingBase:SetIgnoreInputs(value)
	self.ignoreInputs = value
end

function BuildingBase:ShouldIgnoreInputs()
	return self.ignoreInputs == true
end

-- ============================================================
-- ELUPUNKTID
-- ============================================================

-- Tagastab: destroyed (bool) - kas hoone havis selle loogiga
function BuildingBase:TakeDamage(amount)
	if self.isDestroyed then
		return false
	end

	self.health = math.max(0, self.health - amount)
	self.lastDamageTime = GameClock.now()

	if self.health <= 0 then
		self:Destroy()
		return true
	end

	return false
end

function BuildingBase:GetHealthPercent()
	if self.maxHealth <= 0 then
		return 1
	end
	return self.health / self.maxHealth
end

-- Aeglane taastumine, kui hoonet pole hiljuti runnatud.
-- Kutsutakse TickService'i poolt (1x sekundis).
function BuildingBase:RegenerateHealth()
	if self.isDestroyed or self.health >= self.maxHealth then
		return
	end

	local cfg = Constants.Attack

	if self.lastDamageTime and (GameClock.now() - self.lastDamageTime) < cfg.BuildingRegenDelay then
		return
	end

	self.health = math.min(self.maxHealth, self.health + Constants.Buildings.PowerCore.HealPerSecond)
end

return BuildingBase
