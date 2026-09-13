--[[
	BlessedHex.lua (Hex Mutation, scope: hex)
	Valitud hex annab sellel asuvatele hoonetele +10% efektiivsust.

	MIRROR WORLD ERAND: kui Mirror World on aktiivne, muutub see -10%.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Constants = require(ReplicatedStorage.Shared.Constants)
local CardBase = require(ServerScriptService.Cards.CardBase)

local BlessedHex = setmetatable({}, {__index = CardBase})
BlessedHex.__index = BlessedHex

function BlessedHex.new(q, r)
	local self = CardBase.new("BlessedHex", CardBase.Scopes.HEX)
	setmetatable(self, BlessedHex)
	self:SetTargetHex(q, r)
	return self
end

function BlessedHex:GetProductionModifier(building, context)
	-- Mirror World pöörab biome-efekti ümber: +10% -> -10%
	if context.cardManager and context.cardManager:IsCardActive("MirrorWorld") then
		return 1.0 + Constants.Cards.MirrorWorld.BlessedHexEffect
	end

	return 1.0 + Constants.Cards.BlessedHex.EfficiencyBonus
end

return BlessedHex
