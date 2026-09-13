--[[
	BuildingFactory.lua
	Uks koht, kus hoone loogika-instants luuakse.

	MIKS: varem elas see kood GameManager.Start() sees ja tootas ainult
	demo-baasi jaoks. Mangija ehitatud hooned vajavad TAPSELT sama
	loogikat - dubleerimine oleks tahendanud, et uks neist jaab ajapikku
	maha.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local Extractor = require(ServerScriptService.Buildings.Extractor)
local PowerCore = require(ServerScriptService.Buildings.PowerCore)
local Refinery = require(ServerScriptService.Buildings.Refinery)
local Assembler = require(ServerScriptService.Buildings.Assembler)
local Defender = require(ServerScriptService.Buildings.Defender)

local BuildingFactory = {}

-- Koik ehitatavad hoonetuubid (MVP: 5)
BuildingFactory.Types = {
	"Extractor",
	"PowerCore",
	"Refinery",
	"Assembler",
	"Defender",
}

function BuildingFactory.IsValidType(buildingType)
	for _, t in ipairs(BuildingFactory.Types) do
		if t == buildingType then
			return true
		end
	end
	return false
end

-- Loob loogika-instantsi. hexGrid on vajalik ainult Extractorile
-- (ta loeb sealt hex-tuupi). pointBank on vajalik Assemblerile
-- (ta deponeerib sinna toodetud punktid).
function BuildingFactory.Create(buildingType, q, r, hexGrid, pointBank)
	local logic

	if buildingType == "Extractor" then
		logic = Extractor.new(q, r, hexGrid)
	elseif buildingType == "PowerCore" then
		logic = PowerCore.new(q, r)
	elseif buildingType == "Refinery" then
		logic = Refinery.new(q, r)
	elseif buildingType == "Assembler" then
		logic = Assembler.new(q, r)
		if pointBank then
			logic:SetPointBank(pointBank)
		end
	elseif buildingType == "Defender" then
		logic = Defender.new(q, r)
	end

	return logic
end

-- Defender vajab otseviidet lahimale Power Core'ile (spec 3.5:
-- energia ei liigu node-susteemi kaudu, vaid otse).
-- Kutsutakse iga kord, kui Defender voi PowerCore lisandub.
function BuildingFactory.LinkDefenders(buildings, hexGrid)
	local cores = {}
	for _, b in pairs(buildings) do
		if b.buildingType == "PowerCore" and not b.isDestroyed then
			table.insert(cores, b)
		end
	end

	if #cores == 0 then
		return 0
	end

	local linked = 0
	for _, b in pairs(buildings) do
		if b.buildingType == "Defender" and not b.isDestroyed then
			-- Vali lahim Power Core
			local best, bestDist = nil, math.huge
			for _, core in ipairs(cores) do
				local d = hexGrid:Distance(b.q, b.r, core.q, core.r)
				if d < bestDist then
					best, bestDist = core, d
				end
			end
			if best then
				b:LinkPowerCore(best)
				linked += 1
			end
		end
	end

	return linked
end

return BuildingFactory
