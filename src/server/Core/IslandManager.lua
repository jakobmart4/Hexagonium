--[[
	IslandManager.lua
	Haldab saare laiendust KAHEL TASANDIL:

	  META  - pusiv raadius, sailib run'ide vahel (Hex Seed tasu).
	          Salvestatakse hiljem DataStore'i; praegu hoitakse malus.

	  RUN   - ajutine laiendus run'i sees, makstakse upgradePoints'idega.
	          Lahtestub iga run'i alguses.

	AKTIIVNE RAADIUS = metaRadius + runExpansions

	KULU KASVAB: iga jargmine run-laiendus on CostMultiplier korda
	kallim. See on tahtlik - ilma selleta laiendaks mangija lopmatult
	ja meta-progressioon kaotaks motte.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local MapGenerator = require(ServerScriptService.Core.MapGenerator)

local IslandManager = {}
IslandManager.__index = IslandManager

function IslandManager.new(gameState, metaRadius)
	local self = setmetatable({}, IslandManager)

	local config = Constants.IslandExpansion

	self.gameState = gameState
	self.metaRadius = math.clamp(
		metaRadius or config.StartRadius,
		config.StartRadius,
		config.MetaMaxRadius
	)
	self.runExpansions = 0

	return self
end

-- ============================================================
-- OLEK
-- ============================================================

function IslandManager:GetActiveRadius()
	return self.metaRadius + self.runExpansions
end

-- Mitu upgradePoints maksab jargmine run-laiendus
function IslandManager:GetNextCost()
	local config = Constants.IslandExpansion
	return math.floor(
		config.RunExpansionBaseCost
		* (config.RunExpansionCostMultiplier ^ self.runExpansions)
	)
end

-- Kogub kokku koik saadaolevad upgradePoints (PointBank'ist)
function IslandManager:GetAvailablePoints()
	local bank = self.gameState.pointBank
	return bank and bank:Get() or 0
end

-- Kulutab upgradePoints pangast
function IslandManager:SpendPoints(amount)
	local bank = self.gameState.pointBank
	if not bank then
		return false
	end
	return bank:Spend(amount)
end

-- ============================================================
-- KAS LAIENDUS ON VOIMALIK?
-- Tagastab: canExpand (bool), reason (string, INGLISE KEELES)
-- ============================================================

function IslandManager:CanExpand()
	local config = Constants.IslandExpansion

	if self.runExpansions >= config.RunExpansionsMax then
		return false, "Island expansion limit reached for this run."
	end

	if self:GetActiveRadius() >= config.MaxRadius then
		return false, "The island cannot grow any further."
	end

	local nextRing = MapGenerator.GetNextLockedRing(self.gameState.folder)
	if not nextRing then
		return false, "No submerged land remains."
	end

	local cost = self:GetNextCost()
	local available = self:GetAvailablePoints()

	if available < cost then
		return false, string.format(
			"Not enough: %d / %d UP",
			math.floor(available),
			cost
		)
	end

	return true, nil
end

-- ============================================================
-- RUN-SISENE LAIENDUS (maksab upgradePoints)
-- ============================================================

function IslandManager:TryExpand()
	local canExpand, reason = self:CanExpand()
	if not canExpand then
		return false, reason
	end

	local cost = self:GetNextCost()
	if not self:SpendPoints(cost) then
		return false, "Payment failed."
	end

	local nextRing = MapGenerator.GetNextLockedRing(self.gameState.folder)
	local unlocked = MapGenerator.UnlockRing(self.gameState.folder, nextRing, {animate = true})

	self.runExpansions = self.runExpansions + 1

	-- Run'i tasu: laiendus on saavutus
	local run = self.gameState.runManager
	if run then
		run:RecordExpansion()
	end

	return true, string.format("Island expanded: %d new hexes claimed.", unlocked)
end

-- ============================================================
-- META-LAIENDUS (run'ide vahel, Hex Seed tasu)
-- Ei maksa upgradePoints - see on meta-progressiooni tasu.
-- ============================================================

function IslandManager:GrantMetaExpansion()
	local config = Constants.IslandExpansion

	if self.metaRadius >= config.MetaMaxRadius then
		return false, "Meta island size is already at maximum."
	end

	self.metaRadius = self.metaRadius + 1
	return true, self.metaRadius
end

-- Kutsutakse uue run'i alguses: run-laiendused kaovad,
-- meta-raadius jaab alles.
function IslandManager:ResetForNewRun()
	self.runExpansions = 0
	return self.metaRadius
end

-- ============================================================
-- KLIENDILE SAADETAV SEIS
-- ============================================================

function IslandManager:GetClientState()
	local config = Constants.IslandExpansion
	local canExpand, reason = self:CanExpand()

	return {
		metaRadius = self.metaRadius,
		runExpansions = self.runExpansions,
		runExpansionsMax = config.RunExpansionsMax,
		activeRadius = self:GetActiveRadius(),
		maxRadius = config.MaxRadius,
		nextCost = self:GetNextCost(),
		availablePoints = math.floor(self:GetAvailablePoints()),
		canExpand = canExpand,
		reason = reason,
	}
end

return IslandManager
