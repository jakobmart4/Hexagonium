--[[
	MirrorWorld.lua (Rule Card, scope: global)
	Globaalne tootmine: baseRate * 0.9
	Globaalne kaitse: baseDefense * 1.1

	Biome-efektide ümberpööramist (Blessed -10%, Wild +10%, Stable 0%)
	käsitlevad hex-kaardid ise - nad küsivad CardManager'ilt, kas
	Mirror World on aktiivne. Nii ei pea Mirror World teisi kaarte
	teadma ega nende sisemusse sekkuma.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Constants = require(ReplicatedStorage.Shared.Constants)
local CardBase = require(ServerScriptService.Cards.CardBase)

local MirrorWorld = setmetatable({}, {__index = CardBase})
MirrorWorld.__index = MirrorWorld

function MirrorWorld.new()
	local self = CardBase.new("MirrorWorld", CardBase.Scopes.GLOBAL)
	setmetatable(self, MirrorWorld)
	return self
end

function MirrorWorld:GetProductionModifier(building, context)
	return Constants.Cards.MirrorWorld.GlobalProductionMultiplier
end

function MirrorWorld:GetDefenseModifier(building, context)
	return Constants.Cards.MirrorWorld.GlobalDefenseMultiplier
end

return MirrorWorld
