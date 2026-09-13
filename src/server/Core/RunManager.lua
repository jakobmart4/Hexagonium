--[[
	RunManager.lua
	Run'i elutsukkel: algus, tasu kogunemine, kolm erinevat loppu.

	KOLM LOPPU:
	  TIMEOUT    - taimer sai labi. Garanteerib, et run alati lopeb.
	  DESTROYED  - koik hooned havinud. Annab runnakutele kaalu.
	  EXTRACT    - mangija otsustas lahkuda. Ahnuse-moment.

	MIKS TASU KASVAB AJAS:
	Extract on otsus ainult siis, kui jaamine on nii tulusam kui
	ohtlikum. Iga minut annab rohkem tasu kui eelmine (skaleeruv
	ajaboonus) ja iga minut teeb runnakud tugevamaks
	(Constants.Attack.ScalePerMinute). Nii tekib paris dilemma.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)

local CFG = Constants.Run

local RunManager = {}
RunManager.__index = RunManager

RunManager.States = {
	ACTIVE = "Active",
	ENDED = "Ended",
}

RunManager.EndReasons = {
	TIMEOUT = "Timeout",
	DESTROYED = "Destroyed",
	EXTRACT = "Extract",
}

function RunManager.new(gameState)
	local self = setmetatable({}, RunManager)

	self.gameState = gameState
	self.state = RunManager.States.ACTIVE
	self.startTime = os.clock()
	self.endReason = nil
	self.result = nil

	-- Kogunev tasu. Makstakse valja lopus, osakaal soltub loppemise
	-- tuubist.
	self.banked = 0

	-- Jalgime, kui palju upgradePoints'e on KOKKU toodetud.
	-- Ei saa kasutada praegust seisu, sest laiendus kulutab neid.
	self.lastPointsSnapshot = 0
	self.totalPointsProduced = 0

	self.lastMinuteRewarded = 0
	self.attacksSurvived = 0
	self.expansionsMade = 0

	-- Kuulajad run'i lopule
	self.onEnd = {}

	return self
end

function RunManager:OnEnd(callback)
	table.insert(self.onEnd, callback)
end

-- ============================================================
-- AEG
-- ============================================================

function RunManager:GetElapsed()
	return os.clock() - self.startTime
end

function RunManager:GetRemaining()
	return math.max(0, CFG.Duration - self:GetElapsed())
end

function RunManager:GetMinutes()
	return self:GetElapsed() / 60
end

-- Runnakute tugevuse kordaja. AttackManager kusib seda.
function RunManager:GetThreatScale()
	local atk = Constants.Attack
	local scale = 1 + self:GetMinutes() * atk.ScalePerMinute
	return math.min(scale, atk.MaxScale)
end

-- ============================================================
-- TASU KOGUNEMINE
-- ============================================================

-- Kui palju tasu annab N-s minut. Skaleeruv, et hilisem aeg
-- oleks vaartuslikum - see ongi ahnuse-moment.
function RunManager:GetMinuteValue(minuteIndex)
	return CFG.RewardPerMinute * ((1 + CFG.RewardMinuteScaling) ^ (minuteIndex - 1))
end

function RunManager:AddReward(amount)
	self.banked = self.banked + amount
end

function RunManager:RecordAttackSurvived()
	self.attacksSurvived = self.attacksSurvived + 1
	self:AddReward(CFG.RewardPerAttackSurvived)
end

function RunManager:RecordExpansion()
	self.expansionsMade = self.expansionsMade + 1
	self:AddReward(CFG.RewardPerExpansion)
end

-- Kui palju punkte on run'i jooksul KOKKU toodetud.
-- Kulutamine ei vahenda seda - muidu kaotaks mangija tasu iga
-- ehitatud hoone eest.
function RunManager:_currentPoints()
	local bank = self.gameState.pointBank
	return bank and bank:GetTotalProduced() or 0
end

-- ============================================================
-- TICK
-- ============================================================

function RunManager:Tick()
	if self.state ~= RunManager.States.ACTIVE then
		return
	end

	-- 1) Toodetud punktid tasusse.
	--    PointBank:GetTotalProduced() ainult KASVAB, seega piisab
	--    vahe vaatamisest. Kulutamine ei vahenda tasu.
	local current = self:_currentPoints()
	if current > self.lastPointsSnapshot then
		local produced = current - self.lastPointsSnapshot
		self.totalPointsProduced = self.totalPointsProduced + produced
		self:AddReward(produced * CFG.RewardPerUpgradePoint)
	end
	self.lastPointsSnapshot = current

	-- 2) Ajaboonus iga taismi nuti eest
	local minutes = math.floor(self:GetMinutes())
	while self.lastMinuteRewarded < minutes do
		self.lastMinuteRewarded = self.lastMinuteRewarded + 1
		self:AddReward(self:GetMinuteValue(self.lastMinuteRewarded))
	end

	-- 3) Kas baas on havinud?
	local alive = 0
	for _, b in pairs(self.gameState.buildings) do
		if not b.isDestroyed then
			alive = alive + 1
		end
	end
	if alive == 0 then
		self:EndRun(RunManager.EndReasons.DESTROYED)
		return
	end

	-- 4) Kas taimer sai labi?
	if self:GetRemaining() <= 0 then
		self:EndRun(RunManager.EndReasons.TIMEOUT)
	end
end

-- ============================================================
-- LOPETAMINE
-- ============================================================

function RunManager:CanExtract()
	if self.state ~= RunManager.States.ACTIVE then
		return false, "The run has already ended."
	end
	return true, nil
end

function RunManager:EndRun(reason)
	if self.state ~= RunManager.States.ACTIVE then
		return nil
	end

	self.state = RunManager.States.ENDED
	self.endReason = reason

	local payoutRate
	if reason == RunManager.EndReasons.EXTRACT then
		payoutRate = CFG.PayoutExtract
	elseif reason == RunManager.EndReasons.DESTROYED then
		payoutRate = CFG.PayoutDestroyed
	else
		payoutRate = CFG.PayoutTimeout
	end

	local payout = math.floor(self.banked * payoutRate)

	self.result = {
		reason = reason,
		banked = math.floor(self.banked),
		payoutRate = payoutRate,
		payout = payout,
		duration = self:GetElapsed(),
		attacksSurvived = self.attacksSurvived,
		expansionsMade = self.expansionsMade,
		pointsProduced = math.floor(self.totalPointsProduced),
	}

	for _, cb in ipairs(self.onEnd) do
		local ok, err = pcall(cb, self.result)
		if not ok then
			warn("[RunManager] lopukuulaja viga: " .. tostring(err))
		end
	end

	return self.result
end

-- ============================================================
-- KLIENDILE
-- ============================================================

function RunManager:GetClientState()
	return {
		state = self.state,
		elapsed = self:GetElapsed(),
		remaining = self:GetRemaining(),
		duration = CFG.Duration,
		banked = math.floor(self.banked),
		threatScale = self:GetThreatScale(),
		nextMinuteValue = math.floor(self:GetMinuteValue(self.lastMinuteRewarded + 1)),
		warning = self:GetRemaining() <= CFG.WarningAt,
		result = self.result,
	}
end

return RunManager
