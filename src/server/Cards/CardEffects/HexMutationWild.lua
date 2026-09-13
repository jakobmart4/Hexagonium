--[[
	HexMutationWild.lua (Hex Mutation, scope: hex)
	Määratud hex: +20% tootlikkust, kuid 10% tõenäosus iga 45 sek,
	et hoone peatub 5 sek.

	MIRROR WORLD ERAND: Wild Hex -> +10% (spec 5.5).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Constants = require(ReplicatedStorage.Shared.Constants)
local CardBase = require(ServerScriptService.Cards.CardBase)

local HexMutationWild = setmetatable({}, {__index = CardBase})
HexMutationWild.__index = HexMutationWild

function HexMutationWild.new(q, r)
	local self = CardBase.new("HexMutationWild", CardBase.Scopes.HEX)
	setmetatable(self, HexMutationWild)
	self:SetTargetHex(q, r)
	self.lastFailCheck = os.clock()
	return self
end

function HexMutationWild:GetProductionModifier(building, context)
	if context.cardManager and context.cardManager:IsCardActive("MirrorWorld") then
		return 1.0 + Constants.Cards.MirrorWorld.WildHexEffect
	end

	return 1.0 + Constants.Cards.HexMutationWild.ProductivityBonus
end

function HexMutationWild:OnTick(context)
	local config = Constants.Cards.HexMutationWild
	local now = os.clock()

	if now - self.lastFailCheck < config.FailCheckInterval then
		return
	end
	self.lastFailCheck = now

	-- Rikke kontroll ainult sellel hexil asuvale hoonele
	-- Stable Hex samal hexil tühistab Wild Hexi rikked (spec 5.10: 0% rikkeid)
	if context.cardManager and context.cardManager:HexPreventsFailures(self.targetQ, self.targetR) then
		return
	end

	for _, building in ipairs(context.buildings or {}) do
		if building.q == self.targetQ and building.r == self.targetR and not building.isDestroyed then
			if math.random() <= config.FailChance then
				building:Pause(config.FailDuration)
			end
		end
	end
end

return HexMutationWild
