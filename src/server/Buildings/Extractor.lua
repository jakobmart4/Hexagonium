--[[
	Extractor.lua
	Toodab ore't Ore Hex'il või crystal'i Crystal Hex'il.
	Iga Extractor toodab AINULT ÜHTE ressurssi, vastavalt hexile, millel ta asub.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local GameClock = require(game:GetService("ServerScriptService").Core.GameClock)
local BuildingBase = require(script.Parent.BuildingBase)

local Extractor = setmetatable({}, {__index = BuildingBase})
Extractor.__index = Extractor

function Extractor.new(q, r, hexGrid)
	local self = BuildingBase.new("Extractor", q, r)
	setmetatable(self, Extractor)

	local hexType = hexGrid:GetHexType(q, r)
	assert(
		hexType == Constants.HexTypes.ORE_HEX or hexType == Constants.HexTypes.CRYSTAL_HEX,
		"Extractor peab olema paigutatud Ore Hex'ile või Crystal Hex'ile"
	)
	self.hexType = hexType

	self.outputBuffer = 0
	self.lastProductionTime = GameClock.now()

	return self
end

function Extractor:Tick()
	if not self:IsOperational() then
		return
	end

	local config = Constants.Buildings.Extractor
	local now = GameClock.now()

	local rate, interval, resourceType
	if self.hexType == Constants.HexTypes.ORE_HEX then
		rate = config.OreProductionRate
		interval = config.OreProductionInterval
		resourceType = Constants.ResourceTypes.ORE
	else
		rate = config.CrystalProductionRate
		interval = config.CrystalProductionInterval
		resourceType = Constants.ResourceTypes.CRYSTAL
	end

	if now - self.lastProductionTime >= interval then
		self.lastProductionTime = now
		local produced = rate * self:GetProductionMultiplier()
		self.outputBuffer = self.outputBuffer + produced
	end

	return resourceType
end

function Extractor:GetResourceType()
	if self.hexType == Constants.HexTypes.ORE_HEX then
		return Constants.ResourceTypes.ORE
	else
		return Constants.ResourceTypes.CRYSTAL
	end
end

function Extractor:DrainOutput(amount)
	local drained = math.min(self.outputBuffer, amount)
	self.outputBuffer = self.outputBuffer - drained
	return drained
end

return Extractor
