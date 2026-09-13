--[[
	StateBroadcaster.lua
	Kogub mangu seisu kokku ja saadab kliendile HUD-i jaoks.

	Saadab iga BROADCAST_INTERVAL sekundi jarel (mitte iga tick,
	et mitte vorku ule koormata). HUD interpoleerib vahepealsed hetked ise.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local StateBroadcaster = {}
StateBroadcaster.__index = StateBroadcaster

StateBroadcaster.BROADCAST_INTERVAL = 0.5

function StateBroadcaster.new(world)
	local self = setmetatable({}, StateBroadcaster)

	-- Nimi "gameState" on ajalooline; nuud on see MAAILM
	self.gameState = world
	self.world = world
	self.lastBroadcast = 0
	self.remote = RemoteEvents.Get("GameStateUpdate")

	return self
end

-- Kogub koik ressursid kokku koigist hoonetest
function StateBroadcaster:CollectResources()
	local totals = {
		Ore = 0,
		Crystal = 0,
		Alloy = 0,
		UpgradePoints = 0,
	}

	for _, building in pairs(self.gameState.buildings) do
		if building.isDestroyed then
			continue
		end

		-- Extractor: outputBuffer sisaldab ore't voi crystalit
		if building.buildingType == "Extractor" and building.outputBuffer then
			local resType = building:GetResourceType()
			totals[resType] = (totals[resType] or 0) + building.outputBuffer

		-- Refinery: sisendis ore, valjundis alloy
		elseif building.buildingType == "Refinery" then
			totals.Ore = totals.Ore + (building.inputBuffer or 0)
			totals.Alloy = totals.Alloy + (building.outputBuffer or 0)

		-- Assembler: sisendis alloy (punktid on PointBank'is)
		elseif building.buildingType == "Assembler" then
			totals.Alloy = totals.Alloy + (building.inputBuffer or 0)
		end
	end

	-- Punktid tulevad tsentraalsest pangast, mitte hoonetest
	local bank = self.gameState.pointBank
	totals.UpgradePoints = bank and bank:Get() or 0

	return totals
end

-- Energia seis koigist Power Core'idest
function StateBroadcaster:CollectEnergy()
	local current, max = 0, 0
	local anyPaused = false

	for _, building in pairs(self.gameState.buildings) do
		if building.buildingType == "PowerCore" and not building.isDestroyed then
			current = current + (building.currentEnergy or 0)
			max = max + (building.maxEnergyStorage or 0)
			if building.isPaused then
				anyPaused = true
			end
		end
	end

	return {current = current, max = max, paused = anyPaused}
end

-- Aktiivsed kaardid koos faasiga (Flux Tide / Null Surge naitavad faasi)
function StateBroadcaster:CollectCards()
	local cards = {}
	local cm = self.gameState.cardManager
	if not cm then
		return cards
	end

	for _, card in ipairs(cm.activeCards) do
		table.insert(cards, {
			name = card.cardName,
			scope = card.scope,
			phase = card.phase,
			targetQ = card.targetQ,
			targetR = card.targetR,
		})
	end

	return cards
end

-- Hoonete seis minimapi ja diagnostika jaoks
function StateBroadcaster:CollectBuildings()
	local list = {}

	for name, building in pairs(self.gameState.buildings) do
		if not building.isDestroyed then
			table.insert(list, {
				name = name,
				buildingType = building.buildingType,
				q = building.q,
				r = building.r,
				paused = building.isPaused or false,
				multiplier = building.activeMultipliers and building.activeMultipliers.production or 1,
				health = building.GetHealthPercent and building:GetHealthPercent() or 1,
			})
		end
	end

	return list
end

function StateBroadcaster:BuildPayload()
	local island = nil
	if self.gameState.islandManager then
		island = self.gameState.islandManager:GetClientState()
	end

	return {
		resources = self:CollectResources(),
		energy = self:CollectEnergy(),
		cards = self:CollectCards(),
		buildings = self:CollectBuildings(),
		connections = self.gameState.nodeSystem
			and self.gameState.nodeSystem:GetAllConnections() or {},
		faction = self.gameState.faction
			and self.gameState.faction:GetClientState() or nil,
		run = self.gameState.runManager
			and self.gameState.runManager:GetClientState() or nil,
		island = island,

		-- Saare nihe: klient vajab seda kaamera ja minimapi jaoks,
		-- sest saared ei ole enam koordinaadil (0,0)
		origin = {
			x = self.world.origin.X,
			z = self.world.origin.Z,
		},
		islandFolder = self.world.folder and self.world.folder.Name or nil,

		timestamp = os.clock(),
	}
end

-- Kutsutakse TickService'i poolt iga tick'i ajal; saadab ainult
-- BROADCAST_INTERVAL jarel, et vorku mitte ule koormata.
function StateBroadcaster:Tick()
	local now = os.clock()
	if now - self.lastBroadcast < StateBroadcaster.BROADCAST_INTERVAL then
		return
	end
	self.lastBroadcast = now

	local payload = self:BuildPayload()

	-- AINULT SELLE MAAILMA OMANIKELE. Varem FireAllClients -
	-- nuud naeks iga mangija koigi teiste saari.
	for _, player in ipairs(self.world.owners) do
		if player.Parent then
			self.remote:FireClient(player, payload)
		end
	end
end

return StateBroadcaster
