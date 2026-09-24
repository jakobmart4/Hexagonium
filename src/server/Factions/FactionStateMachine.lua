--[[
	FactionStateMachine.lua
	Uldine olekumasin. Ei tea midagi Fracture Syndicate'ist -
	konkreetne kaitumine elab FractureSyndicate.lua sees.

	OLEKUD (spec 6):
	  Neutral -> Friendly -> Trade -> Demand -> Hostile -> Attack -> Recover

	Iga olek voib olla AJASTATUD: kestuse lopus minnakse
	automaatselt jargmisse olekusse. Nii ei pea iga fraktsioon
	taimereid ise haldama.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local GameClock = require(game:GetService("ServerScriptService").Core.GameClock)

local S = Constants.Faction.States

local FactionStateMachine = {}
FactionStateMachine.__index = FactionStateMachine

function FactionStateMachine.new(factionName)
	local self = setmetatable({}, FactionStateMachine)

	self.factionName = factionName
	self.state = S.NEUTRAL
	self.stateStartTime = GameClock.now()

	-- Kui seatud, minnakse kestuse lopus automaatselt siia
	self.stateDuration = nil
	self.nextState = nil

	-- Kuulajad: [olek] = list of function(self, previousState)
	self.onEnter = {}
	self.onExit = {}

	return self
end

-- ============================================================
-- KUULAJAD
-- ============================================================

function FactionStateMachine:OnEnter(state, callback)
	self.onEnter[state] = self.onEnter[state] or {}
	table.insert(self.onEnter[state], callback)
end

function FactionStateMachine:OnExit(state, callback)
	self.onExit[state] = self.onExit[state] or {}
	table.insert(self.onExit[state], callback)
end

local function fire(list, ...)
	for _, cb in ipairs(list or {}) do
		local ok, err = pcall(cb, ...)
		if not ok then
			warn("[FactionStateMachine] kuulaja viga: " .. tostring(err))
		end
	end
end

-- ============================================================
-- OLEKU MUUTMINE
--   duration + nextState: automaatne ulemink kestuse lopus
-- ============================================================

function FactionStateMachine:SetState(newState, duration, nextState)
	if newState == self.state then
		-- Sama olek uuesti: uuenda ainult taimerit
		self.stateStartTime = GameClock.now()
		self.stateDuration = duration
		self.nextState = nextState
		return true
	end

	local previous = self.state

	fire(self.onExit[previous], self, newState)

	self.state = newState
	self.stateStartTime = GameClock.now()
	self.stateDuration = duration
	self.nextState = nextState

	fire(self.onEnter[newState], self, previous)

	return true
end

function FactionStateMachine:GetState()
	return self.state
end

function FactionStateMachine:IsState(state)
	return self.state == state
end

function FactionStateMachine:GetElapsed()
	return GameClock.now() - self.stateStartTime
end

-- Mitu sekundit on praeguses olekus veel jaanud (nil = piiramatu)
function FactionStateMachine:GetRemaining()
	if not self.stateDuration then
		return nil
	end
	return math.max(0, self.stateDuration - self:GetElapsed())
end

-- ============================================================
-- TICK
-- Kutsutakse TickService'i poolt. Ainus asi, mida uldine
-- olekumasin ise teeb, on ajastatud ulemink.
-- ============================================================

function FactionStateMachine:Tick()
	if not self.stateDuration or not self.nextState then
		return
	end

	if self:GetElapsed() >= self.stateDuration then
		local target = self.nextState
		self.stateDuration = nil
		self.nextState = nil
		self:SetState(target)
	end
end

return FactionStateMachine
