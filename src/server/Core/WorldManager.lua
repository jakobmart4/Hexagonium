--[[
	WorldManager.lua
	Haldab kuni 6 eraldi maailma uhes serveris.

	IGA MANGIJA SAAB OMA SAARE. Maailmad ei tea teineteisest midagi.

	CO-OP TULEVIKUS: world.owners on juba list, mitte uks mangija.
	Co-op tahendab siis "lisa mangija olemasoleva maailma owners'isse"
	- mitte uut arhitektuuri.
]]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local GameManager = require(ServerScriptService.Core.GameManager)
local MapGenerator = require(ServerScriptService.Core.MapGenerator)

local WorldManager = {}

-- [userId] = world
local worldsByPlayer = {}
-- [slotIndex] = world
local worldsBySlot = {}

-- ============================================================
-- SLOTID
-- ============================================================

local function findFreeSlot()
	for i = 1, MapGenerator.MAX_SLOTS do
		if not worldsBySlot[i] then
			return i
		end
	end
	return nil
end

-- ============================================================
-- MAAILMA LOOMINE
-- ============================================================

function WorldManager.CreateFor(player, options)
	options = options or {}

	if worldsByPlayer[player.UserId] then
		return worldsByPlayer[player.UserId]
	end

	local slot = findFreeSlot()
	if not slot then
		warn("[WorldManager] Vabu slotte pole - " .. player.Name .. " jaab ilma saareta")
		return nil
	end

	local origin = MapGenerator.GetSlotOrigin(slot)
	local folder = MapGenerator.CreateIslandFolder("Island_" .. player.UserId, origin)

	local world = GameManager.CreateWorld({
		slot = slot,
		origin = origin,
		folder = folder,
		metaRadius = options.metaRadius,
		seed = options.seed,
		tutorialComplete = options.tutorialComplete,
	})

	table.insert(world.owners, player)

	worldsByPlayer[player.UserId] = world
	worldsBySlot[slot] = world

	return world
end

-- ============================================================
-- OTSING
-- ============================================================

function WorldManager.Get(player)
	return worldsByPlayer[player.UserId]
end

function WorldManager.GetAll()
	local list = {}
	for _, world in pairs(worldsByPlayer) do
		table.insert(list, world)
	end
	return list
end

function WorldManager.Count()
	local n = 0
	for _ in pairs(worldsByPlayer) do
		n = n + 1
	end
	return n
end

-- ============================================================
-- EEMALDAMINE
-- ============================================================

function WorldManager.RemovePlayer(player)
	local world = worldsByPlayer[player.UserId]
	if not world then
		return
	end

	worldsByPlayer[player.UserId] = nil

	-- Eemalda omanike seast
	for i = #world.owners, 1, -1 do
		if world.owners[i] == player then
			table.remove(world.owners, i)
		end
	end

	-- Kui omanikke enam pole, hävita maailm ja vabasta slot
	if #world.owners == 0 then
		worldsBySlot[world.slot] = nil
		GameManager.DestroyWorld(world)
	end
end

return WorldManager
