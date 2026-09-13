--[[
	FracturePact.lua (Faction Card, scope: global)
	Fraktsioon nõuab 10% kogu tootmisest (ore + crystal).
	  Nõustumine -> Trade olek 60 sek
	  Keeldumine  -> Hostile -> Attack 30 sek hiljem

	MÄRKUS: see kaart on liides fraktsioonisüsteemi vastu, mida veel
	ei ole kirjutatud (FactionStateMachine.lua). Kaart töötab ka ilma
	selleta - maks arvestatakse kohe, fraktsiooni olekumuutus
	edastatakse ainult siis, kui context.faction on olemas.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Constants = require(ReplicatedStorage.Shared.Constants)
local CardBase = require(ServerScriptService.Cards.CardBase)

local FracturePact = setmetatable({}, {__index = CardBase})
FracturePact.__index = FracturePact

function FracturePact.new()
	local self = CardBase.new("FracturePact", CardBase.Scopes.BUILDING_TYPE)
	setmetatable(self, FracturePact)

	-- Maks rakendub ainult ressursse tootvatele Extractoritele (ore + crystal)
	self.affectedBuildingTypes = {
		Extractor = true,
	}

	self.playerAccepted = nil   -- nil = pole veel otsustanud, true/false = otsus tehtud

	return self
end

-- Mängija otsus (UI kaudu). Kutsub fraktsiooni olekumuutuse, kui see olemas.
function FracturePact:SetPlayerDecision(accepted, context)
	self.playerAccepted = accepted

	local faction = context and context.faction
	if not faction then
		return
	end

	if accepted then
		if faction.EnterTrade then
			faction:EnterTrade(Constants.Cards.FracturePact.TradeStateDuration)
		end
	else
		if faction.EnterHostile then
			faction:EnterHostile(Constants.Cards.FracturePact.AttackDelayAfterRefusal)
		end
	end
end

-- Kui mängija nõustus, võtab fraktsioon 10% tootmisest.
function FracturePact:GetProductionModifier(building, context)
	if self.playerAccepted == true then
		return 1.0 - Constants.Cards.FracturePact.DemandPercentOfProduction
	end

	-- Enne otsust või pärast keeldumist maksu ei võeta
	-- (keeldumise hind on rünnak, mitte tootmiskadu)
	return 1.0
end

return FracturePact
