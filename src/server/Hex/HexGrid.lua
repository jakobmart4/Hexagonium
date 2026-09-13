--[[
	HexGrid.lua
	Kuusnurkne ruudustik: koordinaadid (axial), adjacency, hex-tüübid,
	ja hexile paigutatud hoone jälgimine.
	Vt: https://www.redblobgames.com/grids/hexagons/
]]

local Constants = require(game:GetService("ReplicatedStorage").Shared.Constants)

local HexGrid = {}
HexGrid.__index = HexGrid

local DIRECTIONS = {
	{q = 1, r = 0},
	{q = 1, r = -1},
	{q = 0, r = -1},
	{q = -1, r = 0},
	{q = -1, r = 1},
	{q = 0, r = 1},
}

function HexGrid.new()
	local self = setmetatable({}, HexGrid)
	self.cells = {}
	return self
end

local function key(q, r)
	return q .. "," .. r
end

function HexGrid:GetCellKey(q, r)
	return key(q, r)
end

function HexGrid:GetOrCreateCell(q, r)
	if not self.cells[q] then
		self.cells[q] = {}
	end
	if not self.cells[q][r] then
		self.cells[q][r] = {
			q = q,
			r = r,
			hexType = nil,
			building = nil,
			mutation = nil,
		}
	end
	return self.cells[q][r]
end

function HexGrid:GetCell(q, r)
	if self.cells[q] then
		return self.cells[q][r]
	end
	return nil
end

function HexGrid:SetHexType(q, r, hexType)
	assert(
		hexType == Constants.HexTypes.ORE_HEX or hexType == Constants.HexTypes.CRYSTAL_HEX,
		"SetHexType: tundmatu hexType: " .. tostring(hexType)
	)
	local cell = self:GetOrCreateCell(q, r)
	cell.hexType = hexType
	return cell
end

function HexGrid:GetHexType(q, r)
	local cell = self:GetCell(q, r)
	return cell and cell.hexType or nil
end

function HexGrid:PlaceBuilding(q, r, buildingInstance)
	local cell = self:GetOrCreateCell(q, r)
	if cell.building ~= nil then
		return false, "Hex on juba hõivatud"
	end
	cell.building = buildingInstance
	return true
end

function HexGrid:RemoveBuilding(q, r)
	local cell = self:GetCell(q, r)
	if cell then
		cell.building = nil
	end
end

function HexGrid:GetBuildingAt(q, r)
	local cell = self:GetCell(q, r)
	return cell and cell.building or nil
end

function HexGrid:SetMutation(q, r, mutationType)
	local cell = self:GetOrCreateCell(q, r)
	cell.mutation = mutationType
	return cell
end

function HexGrid:GetMutation(q, r)
	local cell = self:GetCell(q, r)
	return cell and cell.mutation or nil
end

function HexGrid:GetNeighbors(q, r)
	local neighbors = {}
	for _, dir in ipairs(DIRECTIONS) do
		table.insert(neighbors, {q = q + dir.q, r = r + dir.r})
	end
	return neighbors
end

function HexGrid:GetHexesInRadius(centerQ, centerR, radius)
	local results = {}
	for dq = -radius, radius do
		for dr = math.max(-radius, -dq - radius), math.min(radius, -dq + radius) do
			local q = centerQ + dq
			local r = centerR + dr
			table.insert(results, {q = q, r = r})
		end
	end
	return results
end

function HexGrid:Distance(q1, r1, q2, r2)
	return (math.abs(q1 - q2) + math.abs(q1 + r1 - q2 - r2) + math.abs(r1 - r2)) / 2
end

function HexGrid:AxialToWorld(q, r, hexSize)
	hexSize = hexSize or 4
	local x = hexSize * (math.sqrt(3) * q + math.sqrt(3) / 2 * r)
	local z = hexSize * (3 / 2 * r)
	return Vector3.new(x, 0, z)
end

return HexGrid
