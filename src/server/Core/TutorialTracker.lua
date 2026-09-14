--[[
	TutorialTracker.lua
	Jälgib uue mängija esmaste sammude läbimist: ehita Extractor,
	ühenda see Power Core'iga, aktiveeri kaart, koge rünnakut.

	SERVER ON AUTORITEETNE: samm loetakse tehtuks juba olemasolevate
	õnnestumispunktide kaudu (PlayerActionHandler, FractureSyndicate) -
	see moodul ei lisa uut valideerimist, ainult "märgi tehtuks".

	TEKST ELAB KLIENDIS (Tutorial.client.lua), mitte siin - samamoodi
	nagu card.phase enum'e tõlgendab klient, mitte server.
]]

local TutorialTracker = {}
TutorialTracker.__index = TutorialTracker

TutorialTracker.Steps = {
	BUILD_EXTRACTOR = 1,
	CONNECT_POWER_CORE = 2,
	ACTIVATE_CARD = 3,
	SURVIVE_ATTACK = 4,
}

TutorialTracker.TOTAL = 4

function TutorialTracker.new(alreadyComplete)
	local self = setmetatable({}, TutorialTracker)

	self.done = {}
	self.complete = alreadyComplete == true
	self.onComplete = {}

	if self.complete then
		for i = 1, TutorialTracker.TOTAL do
			self.done[i] = true
		end
	end

	return self
end

function TutorialTracker:OnComplete(callback)
	table.insert(self.onComplete, callback)
end

-- Markib sammu tehtuks. Idempotentne: korduv kutse (nt teine kaart
-- aktiveeritakse) ei tee midagi, kui samm juba tehtud voi tutorial
-- juba labi.
function TutorialTracker:_markStep(index)
	if self.complete or self.done[index] then
		return
	end

	self.done[index] = true

	for i = 1, TutorialTracker.TOTAL do
		if not self.done[i] then
			return
		end
	end

	self.complete = true
	for _, callback in ipairs(self.onComplete) do
		local ok, err = pcall(callback)
		if not ok then
			warn("[TutorialTracker] onComplete viga: " .. tostring(err))
		end
	end
end

function TutorialTracker:NotifyBuiltExtractor()
	self:_markStep(TutorialTracker.Steps.BUILD_EXTRACTOR)
end

function TutorialTracker:NotifyConnectedToPowerCore()
	self:_markStep(TutorialTracker.Steps.CONNECT_POWER_CORE)
end

function TutorialTracker:NotifyActivatedCard()
	self:_markStep(TutorialTracker.Steps.ACTIVATE_CARD)
end

function TutorialTracker:NotifyAttackStarted()
	self:_markStep(TutorialTracker.Steps.SURVIVE_ATTACK)
end

-- Skip-nupu jaoks: markib koik sammud korraga.
function TutorialTracker:Complete()
	for i = 1, TutorialTracker.TOTAL do
		self:_markStep(i)
	end
end

-- Esimene tegemata samm (1-4), voi TOTAL+1 kui koik on tehtud.
function TutorialTracker:GetClientState()
	local step = TutorialTracker.TOTAL + 1
	for i = 1, TutorialTracker.TOTAL do
		if not self.done[i] then
			step = i
			break
		end
	end

	return {
		step = step,
		total = TutorialTracker.TOTAL,
		complete = self.complete,
	}
end

return TutorialTracker
