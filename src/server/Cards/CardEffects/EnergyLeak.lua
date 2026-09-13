--[[
	EnergyLeak.lua (Rule Card, scope: buildingType -> ainult PowerCore)
	Lülitab sisse Power Core energialekke mehaanika:
	  currentEnergy = currentEnergy * 0.95 iga 30 sek
	  kui currentEnergy < 800 (80%) -> peatub 10 sek

	Kaart ise ei arvuta midagi - lekke loogika elab PowerCore.lua sees
	(PowerCore:SetEnergyLeakActive). Kaart on lüliti, mis selle sisse lülitab.
	Ei stacki iseendaga.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local CardBase = require(ServerScriptService.Cards.CardBase)

local EnergyLeak = setmetatable({}, {__index = CardBase})
EnergyLeak.__index = EnergyLeak

function EnergyLeak.new()
	local self = CardBase.new("EnergyLeak", CardBase.Scopes.BUILDING_TYPE)
	setmetatable(self, EnergyLeak)

	self.affectedBuildingTypes = {
		PowerCore = true,
	}

	return self
end

function EnergyLeak:OnActivate(context)
	CardBase.OnActivate(self, context)

	for _, building in ipairs(context.buildings or {}) do
		if building.buildingType == "PowerCore" and building.SetEnergyLeakActive then
			building:SetEnergyLeakActive(true)
		end
	end
end

function EnergyLeak:OnDeactivate(context)
	CardBase.OnDeactivate(self, context)

	for _, building in ipairs(context.buildings or {}) do
		if building.buildingType == "PowerCore" and building.SetEnergyLeakActive then
			building:SetEnergyLeakActive(false)
		end
	end
end

-- Energialeke ei muuda tootmiskordajat - see mõjutab energia-puhvrit otse.
function EnergyLeak:GetProductionModifier(building, context)
	return 1.0
end

return EnergyLeak
