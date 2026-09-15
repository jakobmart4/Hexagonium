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

-- Stabiilsed nimed analüütika lehtri jaoks (Steps'i järjekorras). Samm 4 on
-- "ExperienceAttack", mitte "Survive": see märgitakse rünnaku ALGUSES.
TutorialTracker.StepNames = {"BuildExtractor", "ConnectPowerCore", "ActivateCard", "ExperienceAttack"}

function TutorialTracker.new(alreadyComplete)
	local self = setmetatable({}, TutorialTracker)

	self.done = {}
	self.complete = alreadyComplete == true
	self.onComplete = {}
	self.onStep = {}
	-- Mitu sammu on lehtrisse JÄRJEST teavitatud (vt _markStep)
	self.reportedSteps = 0

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

-- Kutsutakse iga PÄRIS läbitud sammu järel: callback(step, stepName).
-- Skip (Complete) EI kutsu seda - muidu näitaks analüütika lehter
-- vahelejätjaid tutoriali läbinutena.
function TutorialTracker:OnStep(callback)
	table.insert(self.onStep, callback)
end

-- Markib sammu tehtuks. Idempotentne: korduv kutse (nt teine kaart
-- aktiveeritakse) ei tee midagi, kui samm juba tehtud voi tutorial
-- juba labi. silent = true -> OnStep kuulajaid ei teavitata (Skip).
function TutorialTracker:_markStep(index, silent)
	if self.complete or self.done[index] then
		return
	end

	self.done[index] = true

	-- Lehter peab olema JÄRJESTIKUNE: teavita ainult järjest tehtud sammudest.
	-- Samm 4 (rünnak) tuleb taimerist, sõltumata mängijast - ilma selleta
	-- näitaks lehter tegevusetut mängijat 4. sammul, kuigi 1-3 on tegemata.
	-- Varem tehtud hilisemad sammud teavitatakse siis, kui vahe täitub.
	if not silent then
		while self.reportedSteps < TutorialTracker.TOTAL and self.done[self.reportedSteps + 1] do
			self.reportedSteps += 1
			local step = self.reportedSteps
			for _, callback in ipairs(self.onStep) do
				local ok, err = pcall(callback, step, TutorialTracker.StepNames[step])
				if not ok then
					warn("[TutorialTracker] onStep viga: " .. tostring(err))
				end
			end
		end
	end

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
		self:_markStep(i, true)
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
