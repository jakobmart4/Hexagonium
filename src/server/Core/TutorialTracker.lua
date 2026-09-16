--[[
	TutorialTracker.lua
	Uue mängija juhend (9 sammu): algbaasi tutvustus, ehitus, ühendus,
	kaart, Demand, rünnakud, laiendus, run'i lõpp, Hex Seeds.

	KAKS SAMMUTÜÜPI:
	  tegevus - märgitakse tehtuks olemasolevate õnnestumispunktide kaudu
	            (PlayerActionHandler, FractureSyndicate, Bootstrap run'i lõpp).
	            Võib juhtuda ka enne, kui samm on ekraanil - siis jäetakse
	            see lihtsalt vahele.
	  info    - seletus asjale, mida kohe teha ei saa (nt seemneid on
	            esimese run'i järel 0). Klient saadab "Next" (AdvanceTutorial),
	            server lubab seda AINULT praegusel infosammul.

	JÄTKAMINE: salvestatakse viimane JÄRJEST läbitud samm (SaveService
	tutorialStep) - terve run'i pikkune tutorial ei alga igal liitumisel
	uuesti algusest.

	SERVER ON AUTORITEETNE: sammu tüüp (InfoSteps) ja edenemine elavad siin.
	Tekst elab kliendis (Tutorial.client.lua).
]]

local TutorialTracker = {}
TutorialTracker.__index = TutorialTracker

TutorialTracker.Steps = {
	BASE_TOUR = 1,
	BUILD_EXTRACTOR = 2,
	LINK_EXTRACTOR = 3,
	ACTIVATE_CARD = 4,
	RESOLVE_DEMAND = 5,
	ATTACK_INFO = 6,
	EXPAND_ISLAND = 7,
	END_RUN = 8,
	HEX_SEEDS_INFO = 9,
}

TutorialTracker.TOTAL = 9

-- Stabiilsed nimed analüütika lehtri jaoks (Steps'i järjekorras)
TutorialTracker.StepNames = {
	"BaseTour", "BuildExtractor", "LinkExtractor", "ActivateCard",
	"ResolveDemand", "AttackInfo", "ExpandIsland", "EndRun", "HexSeedsInfo",
}

-- Infosammud ("Next"-nupp). Klient saab selle GetClientState'ist, seega on
-- tüübil üks allikas.
TutorialTracker.InfoSteps = {
	[TutorialTracker.Steps.BASE_TOUR] = true,
	[TutorialTracker.Steps.ATTACK_INFO] = true,
	[TutorialTracker.Steps.HEX_SEEDS_INFO] = true,
}

-- savedStep: viimane järjest läbitud samm eelmisest sessioonist (0 = uus)
function TutorialTracker.new(alreadyComplete, savedStep)
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
	elseif type(savedStep) == "number" and savedStep > 0 then
		-- Jätka sealt, kuhu eelmine sessioon jõudis. Need sammud on juba
		-- lehtrisse teavitatud, seega reportedSteps samuti.
		local resumeAt = math.min(math.floor(savedStep), TutorialTracker.TOTAL - 1)
		for i = 1, resumeAt do
			self.done[i] = true
		end
		self.reportedSteps = resumeAt
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

-- Esimene tegemata samm (1..TOTAL), voi TOTAL+1 kui koik on tehtud.
function TutorialTracker:_currentStep()
	for i = 1, TutorialTracker.TOTAL do
		if not self.done[i] then
			return i
		end
	end
	return TutorialTracker.TOTAL + 1
end

-- Markib sammu tehtuks. Idempotentne: korduv kutse (nt teine kaart
-- aktiveeritakse) ei tee midagi, kui samm juba tehtud voi tutorial
-- juba labi. silent = true -> OnStep kuulajaid ei teavitata (Skip).
function TutorialTracker:_markStep(index, silent)
	if self.complete or self.done[index] then
		return
	end

	self.done[index] = true

	-- Infosamm, millest mängija on tegudega juba mööda läinud (tegi hilisema
	-- tegevussammu "Next"-i vajutamata), loetakse tehtuks. Muidu jääks
	-- järjestikune lehter sellele sammule kinni ja kõik edasine jääks
	-- analüütikas nähtamatuks.
	if not TutorialTracker.InfoSteps[index] then
		for i = 1, index - 1 do
			if TutorialTracker.InfoSteps[i] then
				self.done[i] = true
			end
		end
	end

	-- Lehter peab olema JÄRJESTIKUNE: teavita ainult järjest tehtud sammudest.
	-- Tegevussamme saab teha enne, kui nad ekraanile jõuavad - ilma selleta
	-- ilmuks lehtris hilisem samm enne varasemat.
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

	if self:_currentStep() <= TutorialTracker.TOTAL then
		return
	end

	self.complete = true
	for _, callback in ipairs(self.onComplete) do
		local ok, err = pcall(callback)
		if not ok then
			warn("[TutorialTracker] onComplete viga: " .. tostring(err))
		end
	end
end

-- ============================================================
-- TEGEVUSSAMMUD (kutsutakse õnnestumispunktidest)
-- ============================================================

function TutorialTracker:NotifyBuiltExtractor()
	self:_markStep(TutorialTracker.Steps.BUILD_EXTRACTOR)
end

-- Extractor ühendati sobivasse sihtmärki (Crystal -> Power Core,
-- Ore -> Refinery). Varem nõudis see Power Core'i ja Ore-extractoriga
-- mängija jäi sammule kinni.
function TutorialTracker:NotifyLinkedExtractor()
	self:_markStep(TutorialTracker.Steps.LINK_EXTRACTOR)
end

function TutorialTracker:NotifyActivatedCard()
	self:_markStep(TutorialTracker.Steps.ACTIVATE_CARD)
end

-- Demand lahenes (makstud, keeldutud või tähtaeg möödus). Loeb AINULT
-- siis, kui Demand-samm on praegune samm: nõue, mis tuli enne, kui mängija
-- sammu selgitust nägi, ei tohi seda vahele jätta (vt HoldsDemands).
function TutorialTracker:NotifyDemandResolved()
	if self:_currentStep() == TutorialTracker.Steps.RESOLVE_DEMAND then
		self:_markStep(TutorialTracker.Steps.RESOLVE_DEMAND)
	end
end

function TutorialTracker:NotifyExpandedIsland()
	self:_markStep(TutorialTracker.Steps.EXPAND_ISLAND)
end

-- Run lõppes mis tahes põhjusel (Extract, Destroyed, Timeout).
function TutorialTracker:NotifyRunEnded()
	self:_markStep(TutorialTracker.Steps.END_RUN)
end

-- ============================================================
-- INFOSAMMUD ("Next" kliendist)
-- ============================================================

-- Tagastab true, kui samm edenes. Keeldub, kui step pole PRAEGUNE samm
-- või pole infosamm - klient ei saa sellega tegevussamme vahele jätta.
function TutorialTracker:AdvanceInfo(step)
	if self.complete or step ~= self:_currentStep() or not TutorialTracker.InfoSteps[step] then
		return false
	end
	self:_markStep(step)
	return true
end

-- ============================================================
-- FRAKTSIOONI AJASTUS (FractureSyndicate küsib)
-- ============================================================

-- Uus mängija: Demand'e EI tule enne, kui tutorial jõuab Demand-sammuni.
-- Varem tuli esimene nõue ~30 s pärast liitumist, kui mängija oli veel
-- ehituse juures: samm 5 jäeti vahele ja rünnak hävitas hooneid enne, kui
-- mängija teadis, mis toimub.
function TutorialTracker:HoldsDemands()
	return not self.complete and self:_currentStep() < TutorialTracker.Steps.RESOLVE_DEMAND
end

-- Demand-sammul tuleb nõue kiiresti (Constants.Faction.TutorialDemandInterval).
function TutorialTracker:NeedsFastDemand()
	return not self.complete and self:_currentStep() == TutorialTracker.Steps.RESOLVE_DEMAND
end

-- ============================================================
-- MUU
-- ============================================================

-- Skip-nupu jaoks: markib koik sammud korraga, lehtrit teavitamata.
function TutorialTracker:Complete()
	for i = 1, TutorialTracker.TOTAL do
		self:_markStep(i, true)
	end
end

function TutorialTracker:GetClientState()
	local step = self:_currentStep()
	return {
		step = step,
		total = TutorialTracker.TOTAL,
		complete = self.complete,
		isInfo = TutorialTracker.InfoSteps[step] == true,
	}
end

return TutorialTracker
