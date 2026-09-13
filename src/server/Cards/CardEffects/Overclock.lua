--[[
	Overclock.lua (Rule Card, scope: global)
	tootmine = baseRate * 2.5
	Iga hoone kohta eraldi: iga 60 sek, 5% tõenäosus -> peatub 20 sek.
	Tõenäosus EI kasva ajas.

	ERAND: Null Surge efektifaasis jätab CardManager selle kaardi
	arvutusest välja (exploit-kaitse) ning ülekuumenemist ei kontrollita.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Constants = require(ReplicatedStorage.Shared.Constants)
local CardBase = require(ServerScriptService.Cards.CardBase)

local Overclock = setmetatable({}, {__index = CardBase})
Overclock.__index = Overclock

function Overclock.new()
	local self = CardBase.new("Overclock", CardBase.Scopes.GLOBAL)
	setmetatable(self, Overclock)

	-- Hoonepõhine ülekuumenemise taimer: [building] = viimane kontrolliaeg
	self.lastOverheatCheck = {}

	return self
end

function Overclock:GetProductionModifier(building, context)
	return Constants.Cards.Overclock.ProductionMultiplier
end

function Overclock:OnTick(context)
	local config = Constants.Cards.Overclock
	local now = os.clock()

	-- Null Surge efektifaasis Overclock ei aktiveeru -> ei kontrolli ka ülekuumenemist
	if context.cardManager and context.cardManager:IsNullSurgeActive() then
		return
	end

	for _, building in ipairs(context.buildings or {}) do
		if not building.isDestroyed then
			local last = self.lastOverheatCheck[building]
			if not last then
				self.lastOverheatCheck[building] = now
			elseif now - last >= config.OverheatCheckInterval then
				self.lastOverheatCheck[building] = now

				if math.random() <= config.OverheatChance then
					building:Pause(config.OverheatDuration)
				end
			end
		end
	end
end

return Overclock
