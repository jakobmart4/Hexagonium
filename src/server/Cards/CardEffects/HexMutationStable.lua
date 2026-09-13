--[[
	HexMutationStable.lua (Hex Mutation, scope: hex)
	Määratud hex: +10% tootlikkust, 0% rikkeid (täiesti stabiilne).

	MIRROR WORLD ERAND: Stable Hex -> 0% (spec 5.5).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Constants = require(ReplicatedStorage.Shared.Constants)
local CardBase = require(ServerScriptService.Cards.CardBase)

local HexMutationStable = setmetatable({}, {__index = CardBase})
HexMutationStable.__index = HexMutationStable

function HexMutationStable.new(q, r)
	local self = CardBase.new("HexMutationStable", CardBase.Scopes.HEX)
	setmetatable(self, HexMutationStable)
	self:SetTargetHex(q, r)
	return self
end

function HexMutationStable:GetProductionModifier(building, context)
	if context.cardManager and context.cardManager:IsCardActive("MirrorWorld") then
		return 1.0 + Constants.Cards.MirrorWorld.StableHexEffect
	end

	return 1.0 + Constants.Cards.HexMutationStable.ProductivityBonus
end

-- Stable hex garanteerib 0% rikkeid. Teised kaardid (nt Overclock,
-- Wild) kontrollivad seda enne oma rikke-loogika rakendamist.
function HexMutationStable:PreventsFailures()
	return true
end

return HexMutationStable
