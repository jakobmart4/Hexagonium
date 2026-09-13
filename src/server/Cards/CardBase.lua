--[[
	CardBase.lua
	Kõigi Reality Cards'ide ühine baasklass.

	Iga kaart defineerib:
	  - scope: "global" | "hex" | "buildingType"
	  - GetProductionModifier(building, context) -> number (liidetav või korrutatav täpsustaja)
	  - OnActivate / OnTick / OnDeactivate (valikulised)

	MULTIPLIKAATORITE KOMBINEERIMINE (kinnitatud otsus):
	Korrutav. Iga kaart tagastab oma kordaja (nt 2.5, 1.25, 0.9) ja
	CardManager korrutab need kokku. See teeb kombinatsioonid põnevaks,
	kuid on ka peamine POWER-CREEP RISK - vt CardManager.EXPLOIT_WARN_THRESHOLD.
]]

local CardBase = {}
CardBase.__index = CardBase

CardBase.Scopes = {
	GLOBAL = "global",
	HEX = "hex",
	BUILDING_TYPE = "buildingType",
}

function CardBase.new(cardName, scope)
	local self = setmetatable({}, CardBase)

	self.cardName = cardName
	self.scope = scope or CardBase.Scopes.GLOBAL

	self.isActive = false
	self.activatedAt = nil

	-- Hex-scope kaartide jaoks: millisele hexile kaart rakendub
	self.targetQ = nil
	self.targetR = nil

	-- BuildingType-scope kaartide jaoks: milliseid hoonetüüpe mõjutab
	self.affectedBuildingTypes = nil

	return self
end

-- Kas see kaart mõjutab antud hoonet? Scope-põhine kontroll.
function CardBase:AffectsBuilding(building)
	if not self.isActive then
		return false
	end

	if self.scope == CardBase.Scopes.GLOBAL then
		return true

	elseif self.scope == CardBase.Scopes.HEX then
		return building.q == self.targetQ and building.r == self.targetR

	elseif self.scope == CardBase.Scopes.BUILDING_TYPE then
		if not self.affectedBuildingTypes then
			return false
		end
		return self.affectedBuildingTypes[building.buildingType] ~= nil
	end

	return false
end

-- Vaikimisi: kaart ei muuda tootmist. Alamklassid kirjutavad selle üle.
function CardBase:GetProductionModifier(building, context)
	return 1.0
end

-- Vaikimisi: kaart ei muuda kaitset.
function CardBase:GetDefenseModifier(building, context)
	return 1.0
end

function CardBase:OnActivate(context)
	self.isActive = true
	self.activatedAt = os.clock()
end

function CardBase:OnTick(context)
	-- Alamklassid kirjutavad üle, kui vajavad tsüklilist loogikat
end

function CardBase:OnDeactivate(context)
	self.isActive = false
end

function CardBase:SetTargetHex(q, r)
	self.targetQ = q
	self.targetR = r
end

return CardBase
