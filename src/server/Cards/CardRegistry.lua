--[[
	CardRegistry.lua
	Keskne kaartide kataloog. Lubab luua kaarte nime järgi, ilma et
	GameManager või UI peaks iga mooduli eraldi require'ima.

	Hex-scope kaardid vajavad loomisel sihthexi (q, r).
]]

local ServerScriptService = game:GetService("ServerScriptService")
local Effects = ServerScriptService.Cards.CardEffects

local CardRegistry = {}

-- Kõik 10 MVP kaarti. needsHex = kas loomisel on vaja (q, r) sihtmärki.
CardRegistry.Cards = {
	Overclock          = {module = require(Effects.Overclock),          needsHex = false},
	FluxTide           = {module = require(Effects.FluxTide),           needsHex = false},
	BlessedHex         = {module = require(Effects.BlessedHex),         needsHex = true},
	FracturePact       = {module = require(Effects.FracturePact),       needsHex = false},
	MirrorWorld        = {module = require(Effects.MirrorWorld),        needsHex = false},
	NullSurge          = {module = require(Effects.NullSurge),          needsHex = false},
	ResourceBloom      = {module = require(Effects.ResourceBloom),      needsHex = false},
	EnergyLeak         = {module = require(Effects.EnergyLeak),         needsHex = false},
	HexMutationWild    = {module = require(Effects.HexMutationWild),    needsHex = true},
	HexMutationStable  = {module = require(Effects.HexMutationStable),  needsHex = true},
}

-- Loob kaardi nime järgi. Hex-scope kaartide puhul on q, r kohustuslikud.
function CardRegistry.Create(cardName, q, r)
	local entry = CardRegistry.Cards[cardName]
	if not entry then
		warn("[CardRegistry] Tundmatu kaart: " .. tostring(cardName))
		return nil
	end

	if entry.needsHex then
		if q == nil or r == nil then
			warn("[CardRegistry] " .. cardName .. " vajab sihthexi (q, r)")
			return nil
		end
		return entry.module.new(q, r)
	end

	return entry.module.new()
end

function CardRegistry.GetAllCardNames()
	local names = {}
	for name in pairs(CardRegistry.Cards) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function CardRegistry.NeedsHex(cardName)
	local entry = CardRegistry.Cards[cardName]
	return entry ~= nil and entry.needsHex
end

return CardRegistry
