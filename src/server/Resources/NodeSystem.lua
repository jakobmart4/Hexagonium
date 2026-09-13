--[[
	NodeSystem.lua
	Haldab hoonetevahelisi uhendusi ja liigutab ressursse prioriteedi
	jargi iga server-tick'i ajal.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local BuildingInfo = require(ReplicatedStorage.Shared.BuildingInfo)

local NodeSystem = {}
NodeSystem.__index = NodeSystem

-- ============================================================
-- RESSURSIUHILDUVUS
-- Tabelid elavad BuildingInfo's (jagatud kliendiga), et server ja
-- klient ei saaks lahku minna. Siin ainult Extractori eriloogika:
-- tema valjund soltub hexist, seega kusime hoonelt endalt.
-- ============================================================

function NodeSystem.GetOutputResource(building)
	local declared = BuildingInfo.GetOutput(building.buildingType)

	if declared == BuildingInfo.VARIABLE then
		return building.GetResourceType and building:GetResourceType() or nil
	end

	return declared
end

function NodeSystem.GetAcceptedResource(building)
	return BuildingInfo.GetAccepts(building.buildingType)
end

-- ============================================================
-- KAS UHENDUS ON LUBATUD?
-- Tagastab: ok (bool), reason (string, INGLISE KEELES)
-- ============================================================

function NodeSystem:CanConnect(source, target)
	if source == target then
		return false, "A building cannot feed itself."
	end

	if source.isDestroyed or target.isDestroyed then
		return false, "That building no longer exists."
	end

	local out = NodeSystem.GetOutputResource(source)
	if not out then
		return false, source.buildingType .. " does not output anything."
	end

	local accepts = NodeSystem.GetAcceptedResource(target)
	if not accepts then
		if target.buildingType == "Defender" then
			return false, "Defenders draw energy directly from a Power Core."
		end
		return false, target.buildingType .. " does not accept deliveries."
	end

	if out ~= accepts then
		return false, string.format("%s outputs %s, but %s needs %s.",
			source.buildingType, out, target.buildingType, accepts)
	end

	-- Juba uhendatud?
	for _, existing in ipairs(source.outputConnections) do
		if existing == target then
			return false, "Already connected."
		end
	end

	return true, nil
end

-- Kas nende vahel on juba uhendus?
function NodeSystem:IsConnected(source, target)
	for _, existing in ipairs(source.outputConnections) do
		if existing == target then
			return true
		end
	end
	return false
end

-- Koik uhendused kliendile saatmiseks
function NodeSystem:GetAllConnections()
	local list = {}
	for _, source in ipairs(self.buildings) do
		if not source.isDestroyed then
			for priority, target in ipairs(source.outputConnections) do
				if not target.isDestroyed then
					table.insert(list, {
						fromQ = source.q, fromR = source.r,
						toQ = target.q, toR = target.r,
						resource = NodeSystem.GetOutputResource(source),
						priority = priority,
					})
				end
			end
		end
	end
	return list
end

function NodeSystem.new()
	local self = setmetatable({}, NodeSystem)
	self.buildings = {}
	return self
end

function NodeSystem:RegisterBuilding(building)
	table.insert(self.buildings, building)
end

function NodeSystem:UnregisterBuilding(building)
	for i, b in ipairs(self.buildings) do
		if b == building then
			table.remove(self.buildings, i)
			break
		end
	end
end

function NodeSystem:Connect(sourceBuilding, targetBuilding)
	assert(sourceBuilding ~= targetBuilding, "Hoone ei saa iseendaga ühenduda")
	assert(not sourceBuilding.isDestroyed, "Ei saa ühendada hävinud hoonet")
	assert(not targetBuilding.isDestroyed, "Ei saa ühendada hävinud hoonet")

	sourceBuilding:ConnectOutput(targetBuilding)
end

function NodeSystem:Disconnect(sourceBuilding, targetBuilding)
	sourceBuilding:DisconnectOutput(targetBuilding)
end

function NodeSystem:Tick()
	for _, source in ipairs(self.buildings) do
		if source.outputBuffer ~= nil and #source.outputConnections > 0 then
			local available = source.outputBuffer

			if available > 0 then
				for _, target in ipairs(source.outputConnections) do
					if available <= 0 then
						break
					end

					if target.TryAccept then
						local accepted = target:TryAccept(available)
						available = available - accepted
					end
				end

				source.outputBuffer = available
			end
		end
	end
end

return NodeSystem
