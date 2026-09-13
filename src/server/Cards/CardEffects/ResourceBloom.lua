--[[
	ResourceBloom.lua (Rule Card, scope: buildingType)
	Extractor +25%, Refinery +10%, Assembler +5%.
	Power Core (energiatootmine) EI muutu.
	PÜSIV kogu run'i vältel.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Constants = require(ReplicatedStorage.Shared.Constants)
local CardBase = require(ServerScriptService.Cards.CardBase)

local ResourceBloom = setmetatable({}, {__index = CardBase})
ResourceBloom.__index = ResourceBloom

function ResourceBloom.new()
	local self = CardBase.new("ResourceBloom", CardBase.Scopes.BUILDING_TYPE)
	setmetatable(self, ResourceBloom)

	-- Power Core teadlikult puudub - energiatootmine ei muutu (spec 5.7)
	self.affectedBuildingTypes = {
		Extractor = true,
		Refinery = true,
		Assembler = true,
	}

	return self
end

function ResourceBloom:GetProductionModifier(building, context)
	local config = Constants.Cards.ResourceBloom

	if building.buildingType == "Extractor" then
		return 1.0 + config.ExtractorBonus
	elseif building.buildingType == "Refinery" then
		return 1.0 + config.RefineryBonus
	elseif building.buildingType == "Assembler" then
		return 1.0 + config.AssemblerBonus
	end

	return 1.0
end

return ResourceBloom
