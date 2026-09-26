--[[
	IslandManager.lua
	Haldab saare laiendust.

	  START - saar alustab IGA run'i IslandExpansion.StartRadius'iga
	          (sama suurus mis Studio Edit-vaates). Varem kasvas algsaar
	          pusivalt (metaRadius) - suurem algsaar hajutas algbaasi
	          laiali ja jattis hooneid Defenderist kaugele.

	  META  - bonusExpansions: pusivalt OSTETUD lisalaiendused (Hex Seeds,
	          MENU). Iga ost = run'is uks laiendusrong rohkem.
	          Salvestub DataStore'i (SaveService.SetBonusExpansions).

	  RUN   - runExpansions: selle run'i jooksul avatud rongad, makstakse
	          upgradePoints'idega. Lahtestub iga run'i alguses.

	AKTIIVNE RAADIUS      = StartRadius + runExpansions
	RUN'I LAIENDUSTE LAGI = RunExpansionsMax + bonusExpansions

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

function IslandManager.new(gameState, bonusExpansions)
	local self = setmetatable({}, IslandManager)

	local config = Constants.IslandExpansion

	self.gameState = gameState
	self.bonusExpansions = math.clamp(bonusExpansions or 0, 0, config.MetaExpansionsMax)
	self.runExpansions = 0

	return self
end

-- ============================================================
-- OLEK
-- ============================================================

function IslandManager:GetActiveRadius()
	return Constants.IslandExpansion.StartRadius + self.runExpansions
end

-- Mitu ronga tohib selles run'is KOKKU avada
function IslandManager:GetExpansionsMax()
	return Constants.IslandExpansion.RunExpansionsMax + self.bonusExpansions
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

	if self.runExpansions >= self:GetExpansionsMax() then
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
	local unlocked = MapGenerator.UnlockRing(self.gameState.folder, nextRing, {
		animate = true,
		-- Saare nihe: ilma selleta kerkiks rong maailma Y=0 peale,
		-- mitte selle saare enda tasapinnale (vt UnlockRing).
		origin = self.gameState.origin,
	})

	self.runExpansions = self.runExpansions + 1

	-- Run'i tasu: laiendus on saavutus
	local run = self.gameState.runManager
	if run then
		run:RecordExpansion()
	end

	return true, string.format("Island expanded: %d new hexes claimed.", unlocked)
end

-- ============================================================
-- META: ostetud lisalaiendus (Hex Seeds, vt PlayerActionHandler)
-- Kehtib KOHE - lagi loetakse igal CanExpand'il, saart ei pea
-- uuesti genereerima.
-- ============================================================

function IslandManager:GrantBonusExpansion()
	local config = Constants.IslandExpansion

	if self.bonusExpansions >= config.MetaExpansionsMax then
		return false, "All permanent expansions are already unlocked."
	end

	self.bonusExpansions = self.bonusExpansions + 1
	return true, self.bonusExpansions
end

-- Kutsutakse uue run'i alguses: run-laiendused kaovad,
-- ostetud lisalaiendused jaavad alles.
function IslandManager:ResetForNewRun()
	self.runExpansions = 0
end

-- ============================================================
-- KLIENDILE SAADETAV SEIS
-- ============================================================

function IslandManager:GetClientState()
	local config = Constants.IslandExpansion
	local canExpand, reason = self:CanExpand()

	return {
		bonusExpansions = self.bonusExpansions,
		runExpansions = self.runExpansions,
		runExpansionsMax = self:GetExpansionsMax(),
		activeRadius = self:GetActiveRadius(),
		maxRadius = config.MaxRadius,
		nextCost = self:GetNextCost(),
		availablePoints = math.floor(self:GetAvailablePoints()),
		canExpand = canExpand,
		reason = reason,
	}
end

return IslandManager
