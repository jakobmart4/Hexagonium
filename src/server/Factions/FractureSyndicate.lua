--[[
	FractureSyndicate.lua
	Konkreetne fraktsioon. Kasutab FactionStateMachine'i ja lisab
	sellele Demand-loogika, taimerid ja Defenderite teavitamise.

	See moodul ON see, mida FracturePact kaart otsis:
	  EnterTrade(duration)
	  EnterHostile(attackDelay)
	Need olid ainus "punane lipp" koodibaasis.

	RUNNAKUD: Attack olek maargib Defenderid ruundeolekusse.
	Tegelikud liikuvad ruundajad tulevad jargmises sammus -
	olekumasin on juba valmis neid kaivitama.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local FactionStateMachine = require(ServerScriptService.Factions.FactionStateMachine)
local ResourceLedger = require(ServerScriptService.Resources.ResourceLedger)
local AttackManager = require(ServerScriptService.Factions.AttackManager)

local S = Constants.Faction.States
local RT = Constants.ResourceTypes
local CFG = Constants.Faction

local FractureSyndicate = {}
FractureSyndicate.__index = FractureSyndicate

-- Kui kaua rundamine kestab, enne kui minnakse Recover'isse.
-- Jargmises sammus asendub see paris runnaku lopuga.
FractureSyndicate.ATTACK_DURATION = 20
FractureSyndicate.RECOVER_DURATION = 30

-- Kui kaua parast Neutral'isse joudmist enne jargmist Demand'i
FractureSyndicate.DEMAND_INTERVAL = 150

function FractureSyndicate.new(gameState)
	local self = setmetatable({}, FractureSyndicate)

	self.gameState = gameState
	self.machine = FactionStateMachine.new("Fracture Syndicate")
	self.attackManager = AttackManager.new(gameState)

	-- Praegune noue (ainult Demand olekus)
	self.demand = nil

	-- Mitu tasuta kaarti mangija on teeninud (lunastamata)
	self.pendingRewardCards = 0

	-- Millal viimati Neutral'isse joudsime (Demand ajastuse jaoks)
	self.lastNeutralTime = os.clock()

	self:_wireTransitions()

	return self
end

-- ============================================================
-- OLEKUTE KAITUMINE
-- ============================================================

function FractureSyndicate:_wireTransitions()
	local m = self.machine

	m:OnEnter(S.DEMAND, function()
		self.demand = {
			ore = CFG.Demand.OreRequired,
			crystal = CFG.Demand.CrystalRequired,
			deadline = CFG.Demand.Deadline,
		}
	end)

	m:OnExit(S.DEMAND, function()
		self.demand = nil
	end)

	m:OnEnter(S.ATTACK, function()
		self:_setDefendersUnderAttack(true)
		self.attackManager:StartWave(FractureSyndicate.ATTACK_DURATION)
	end)

	m:OnExit(S.ATTACK, function()
		self:_setDefendersUnderAttack(false)

		-- Statistika salvestusse: mitu runnakut ule elatud ja
		-- mitu hoonet kaotatud
		local am = self.attackManager
		local lost = am.buildingsLost
		self:_recordStats(lost)

		am:EndWave()
	end)

	m:OnEnter(S.NEUTRAL, function()
		self.lastNeutralTime = os.clock()
	end)
end

function FractureSyndicate:_setDefendersUnderAttack(value)
	for _, b in pairs(self.gameState.buildings) do
		if b.buildingType == "Defender" and b.SetUnderAttack then
			b:SetUnderAttack(value)
		end
	end
end

-- Runnaku tulemus run'i statistikasse. SaveService'iga ei suhelda
-- siin otse - Bootstrap.server.lua salvestab KOGU run'i statistika
-- uhes kohas, alles siis kui run pariselt lopeb (vt run:OnEnd).
function FractureSyndicate:_recordStats(buildingsLost)
	local run = self.gameState.runManager
	if not run then
		return
	end

	-- Run'i tasu: ule elatud runnak on vaartuslik
	run:RecordAttackSurvived()

	if buildingsLost > 0 then
		run:RecordBuildingsLost(buildingsLost)
	end
end

-- ============================================================
-- LIIDES KAARTIDE JAOKS
-- FracturePact kutsub neid. Enne seda moodulit neid ei eksisteerinud.
-- ============================================================

function FractureSyndicate:EnterTrade(duration)
	return self.machine:SetState(S.TRADE, duration or CFG.Demand.Deadline, S.NEUTRAL)
end

function FractureSyndicate:EnterHostile(attackDelay)
	return self.machine:SetState(
		S.HOSTILE,
		attackDelay or CFG.AttackDelayAfterHostile,
		S.ATTACK
	)
end

function FractureSyndicate:EnterDemand()
	return self.machine:SetState(S.DEMAND, CFG.Demand.Deadline, S.HOSTILE)
end

-- ============================================================
-- MANGIJA OTSUSED
-- Tagastab: success (bool), message (string, INGLISE KEELES)
-- ============================================================

-- Mangija maksab noude
function FractureSyndicate:AcceptDemand()
	if not self.machine:IsState(S.DEMAND) then
		return false, "There is no active demand."
	end

	local costs = {
		[RT.ORE] = self.demand.ore,
		[RT.CRYSTAL] = self.demand.crystal,
	}

	if not ResourceLedger.Spend(self.gameState.buildings, costs) then
		local have = ResourceLedger.GetAll(self.gameState.buildings)
		return false, string.format(
			"Not enough resources: %d/%d ore, %d/%d crystal.",
			math.floor(have[RT.ORE]), self.demand.ore,
			math.floor(have[RT.CRYSTAL]), self.demand.crystal)
	end

	self.pendingRewardCards = self.pendingRewardCards + CFG.Demand.RewardFreeCards
	self.machine:SetState(S.FRIENDLY, Constants.Cards.FracturePact.TradeStateDuration, S.NEUTRAL)

	return true, "Demand paid. The Syndicate is friendly for now."
end

-- Mangija keeldub aktiivselt -> Hostile -> Attack
function FractureSyndicate:RefuseDemand()
	if not self.machine:IsState(S.DEMAND) then
		return false, "There is no active demand."
	end

	self:EnterHostile(CFG.AttackDelayAfterHostile)

	return true, string.format(
		"Demand refused. The Syndicate attacks in %d seconds.",
		CFG.AttackDelayAfterHostile)
end

-- ============================================================
-- TICK
-- ============================================================

function FractureSyndicate:Tick()
	local m = self.machine

	-- Ajastatud ulemingud (Demand deadline, Hostile -> Attack jne)
	m:Tick()

	-- Runnakulaine
	self.attackManager:Tick()

	-- Attack ja Recover kestused seatakse siin, sest need soltuvad
	-- fraktsioonist, mitte uldisest olekumasinast
	if m:IsState(S.ATTACK) and not m.stateDuration then
		m.stateDuration = FractureSyndicate.ATTACK_DURATION
		m.nextState = S.RECOVER
	end

	if m:IsState(S.RECOVER) and not m.stateDuration then
		m.stateDuration = FractureSyndicate.RECOVER_DURATION
		m.nextState = S.NEUTRAL
	end

	-- Neutral olekus: uus noue teatud aja parast
	if m:IsState(S.NEUTRAL) then
		if os.clock() - self.lastNeutralTime >= FractureSyndicate.DEMAND_INTERVAL then
			self:EnterDemand()
		end
	end
end

-- ============================================================
-- KLIENDILE SAADETAV SEIS
-- ============================================================

function FractureSyndicate:GetClientState()
	local m = self.machine
	local state = m:GetState()

	local data = {
		name = "Fracture Syndicate",
		state = state,
		remaining = m:GetRemaining(),
		rewardCards = self.pendingRewardCards,
		attack = self.attackManager:GetClientState(),
	}

	-- Neutral olekus pole olekumasinal taimerit, aga mangija peab
	-- teadma, millal jargmine noue tuleb. Ilma selleta tundub
	-- fraktsioon ettearvamatu ja runnak ebaausana.
	if state == S.NEUTRAL then
		local elapsed = os.clock() - self.lastNeutralTime
		data.nextDemandIn = math.max(0, FractureSyndicate.DEMAND_INTERVAL - elapsed)
	end

	if state == S.DEMAND and self.demand then
		local have = ResourceLedger.GetAll(self.gameState.buildings)
		data.demand = {
			ore = self.demand.ore,
			crystal = self.demand.crystal,
			haveOre = math.floor(have[RT.ORE]),
			haveCrystal = math.floor(have[RT.CRYSTAL]),
			canAfford = ResourceLedger.CanAfford(self.gameState.buildings, {
				[RT.ORE] = self.demand.ore,
				[RT.CRYSTAL] = self.demand.crystal,
			}),
		}
	end

	return data
end

return FractureSyndicate
