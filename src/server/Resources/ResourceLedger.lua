--[[
	ResourceLedger.lua
	Ressursside lugemine ja kulutamine ule KOIGI hoonete.

	MIKS ON SEDA VAJA: mangul ei ole tsentraalset ressursivaru -
	ressursid elavad hoonete puhvrites (Extractor.outputBuffer,
	Refinery.inputBuffer jne). Kui fraktsioon noab 50 ore'i, tuleb
	see kokku korjata mitmest kohast.

	See moodul on ka alus tulevastele hoonehindadele - siis ei pea
	seda loogikat teist korda kirjutama.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)

local RT = Constants.ResourceTypes

local ResourceLedger = {}

-- Kus iga ressurss hoonetes asub.
-- Tagastab listi {buffer = "valjanimi", amount = kogus}
local function getStores(building, resourceType)
	local stores = {}

	if building.isDestroyed then
		return stores
	end

	local t = building.buildingType

	if t == "Extractor" and building.GetResourceType then
		if building:GetResourceType() == resourceType then
			table.insert(stores, "outputBuffer")
		end

	elseif t == "Refinery" then
		if resourceType == RT.ORE then
			table.insert(stores, "inputBuffer")
		elseif resourceType == RT.ALLOY then
			table.insert(stores, "outputBuffer")
		end

	elseif t == "Assembler" then
		if resourceType == RT.ALLOY then
			table.insert(stores, "inputBuffer")
		end
	end

	return stores
end

-- Kui palju antud ressurssi on kokku saadaval
function ResourceLedger.GetTotal(buildings, resourceType)
	local total = 0
	for _, building in pairs(buildings) do
		for _, field in ipairs(getStores(building, resourceType)) do
			total = total + (building[field] or 0)
		end
	end
	return total
end

-- Koik kolm ressurssi korraga (HUD ja fraktsiooni jaoks)
function ResourceLedger.GetAll(buildings)
	return {
		[RT.ORE] = ResourceLedger.GetTotal(buildings, RT.ORE),
		[RT.CRYSTAL] = ResourceLedger.GetTotal(buildings, RT.CRYSTAL),
		[RT.ALLOY] = ResourceLedger.GetTotal(buildings, RT.ALLOY),
	}
end

-- Kas nouet saab taita?
function ResourceLedger.CanAfford(buildings, costs)
	for resourceType, amount in pairs(costs) do
		if ResourceLedger.GetTotal(buildings, resourceType) < amount then
			return false
		end
	end
	return true
end

-- Kulutab ressursse. KOIK-VOI-MITTE MIDAGI: kui mone ressursi
-- jaoks ei jatku, ei votata midagi ara.
function ResourceLedger.Spend(buildings, costs)
	if not ResourceLedger.CanAfford(buildings, costs) then
		return false
	end

	for resourceType, amount in pairs(costs) do
		local remaining = amount
		for _, building in pairs(buildings) do
			if remaining <= 0 then
				break
			end
			for _, field in ipairs(getStores(building, resourceType)) do
				if remaining <= 0 then
					break
				end
				local available = building[field] or 0
				local taken = math.min(available, remaining)
				building[field] = available - taken
				remaining = remaining - taken
			end
		end
	end

	return true
end

return ResourceLedger
