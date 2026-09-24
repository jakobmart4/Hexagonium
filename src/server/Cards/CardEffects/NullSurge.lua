--[[
	NullSurge.lua (Event Card, scope: global)
	Iga 240 sek:
	  - efektifaas 10 sek: tootmine = baseRate * 3, sisendid ignoreeritakse
	  - lag-faas 5 sek: tootmine = 0
	  - seejärel idle kuni järgmise tsüklini

	INTERAKTSIOON OVERCLOCKIGA (exploit-kaitse, vt CardManager):
	  - efektifaasis EI korrutu Overclockiga (CardManager jätab Overclocki välja)
	  - efektifaasis ülekuumenemist ei kontrollita
	  - lag-faasis on tootmine 0 kõigile, sh Overclockile
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Constants = require(ReplicatedStorage.Shared.Constants)
local GameClock = require(game:GetService("ServerScriptService").Core.GameClock)
local CardBase = require(ServerScriptService.Cards.CardBase)

local NullSurge = setmetatable({}, {__index = CardBase})
NullSurge.__index = NullSurge

function NullSurge.new()
	local self = CardBase.new("NullSurge", CardBase.Scopes.GLOBAL)
	setmetatable(self, NullSurge)

	self.phase = "idle"        -- "idle" | "effect" | "lag"
	self.phaseStartTime = GameClock.now()
	self.lastCycleStart = GameClock.now()

	return self
end

function NullSurge:OnActivate(context)
	CardBase.OnActivate(self, context)
	self.phase = "idle"
	self.phaseStartTime = GameClock.now()
	self.lastCycleStart = GameClock.now()
end

function NullSurge:OnTick(context)
	local config = Constants.Cards.NullSurge
	local now = GameClock.now()
	local elapsed = now - self.phaseStartTime

	if self.phase == "idle" then
		if now - self.lastCycleStart >= config.ActivationInterval then
			self.phase = "effect"
			self.phaseStartTime = now
			self.lastCycleStart = now
		end

	elseif self.phase == "effect" then
		if elapsed >= config.EffectDuration then
			self.phase = "lag"
			self.phaseStartTime = now
		end

	elseif self.phase == "lag" then
		if elapsed >= config.LagDuration then
			self.phase = "idle"
			self.phaseStartTime = now
		end
	end
end

function NullSurge:GetProductionModifier(building, context)
	if self.phase == "effect" then
		return Constants.Cards.NullSurge.ProductionMultiplier
	end
	-- lag-faasi 0-kordaja rakendab CardManager otse (vt IsNullSurgeLagging)
	return 1.0
end

-- Kas hooned peaksid sisendressursse ignoreerima? (efektifaasis jah)
function NullSurge:ShouldIgnoreInputs()
	return self.phase == "effect"
end

return NullSurge
