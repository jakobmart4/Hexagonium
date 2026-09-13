--[[
	FluxTide.lua (Cycle Card, scope: buildingType -> ainult PowerCore)
	Tsükkel iga 180 sek:
	  - boonusfaas 30 sek: +50% energia tootmine
	  - karistusfaas 60 sek: -30% energia tootmine
	  - seejärel normaalne kuni järgmise tsüklini
	Ei stacki iseendaga.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Constants = require(ReplicatedStorage.Shared.Constants)
local CardBase = require(ServerScriptService.Cards.CardBase)

local FluxTide = setmetatable({}, {__index = CardBase})
FluxTide.__index = FluxTide

function FluxTide.new()
	local self = CardBase.new("FluxTide", CardBase.Scopes.BUILDING_TYPE)
	setmetatable(self, FluxTide)

	-- Flux Tide mõjutab AINULT energiatootmist (spec 5.2)
	self.affectedBuildingTypes = {
		PowerCore = true,
	}

	self.phase = "normal"      -- "normal" | "bonus" | "penalty"
	self.phaseStartTime = os.clock()
	self.lastCycleStart = os.clock()

	return self
end

function FluxTide:OnActivate(context)
	CardBase.OnActivate(self, context)
	self.phase = "normal"
	self.phaseStartTime = os.clock()
	self.lastCycleStart = os.clock()
end

function FluxTide:OnTick(context)
	local config = Constants.Cards.FluxTide
	local now = os.clock()
	local elapsed = now - self.phaseStartTime

	if self.phase == "normal" then
		if now - self.lastCycleStart >= config.CycleInterval then
			self.phase = "bonus"
			self.phaseStartTime = now
			self.lastCycleStart = now
		end

	elseif self.phase == "bonus" then
		if elapsed >= config.BonusDuration then
			self.phase = "penalty"
			self.phaseStartTime = now
		end

	elseif self.phase == "penalty" then
		if elapsed >= config.PenaltyDuration then
			self.phase = "normal"
			self.phaseStartTime = now
		end
	end
end

function FluxTide:GetProductionModifier(building, context)
	local config = Constants.Cards.FluxTide

	if self.phase == "bonus" then
		return config.BonusMultiplier
	elseif self.phase == "penalty" then
		return config.PenaltyMultiplier
	end

	return 1.0
end

return FluxTide
