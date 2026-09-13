--[[
	CardManager.lua
	Haldab aktiivseid kaarte, arvutab iga hoone efektiivse multiplikaatori
	ja rakendab kaartidevahelised erandireeglid.

	=== EXPLOIT-KAITSE (tähtis) ===
	Korrutav süsteem tekitab power-creepi riski. Kaks kaitsemehhanismi:

	1) NULL SURGE ASENDAB, EI KORRUTA.
	   Spec: "Overclock EI AKTIVEERU Null Surge efektifaasi ajal."
	   Kui lubaksime korrutamise, saaks mängija:
	     NullSurge(3.0) x Overclock(2.5) x Bloom(1.25) x Wild(1.20) = 11.25x
	   ILMA riskita (Null Surge ignoreerib ülekuumenemist ja sisendeid).
	   Seetõttu: Null Surge efektifaasis rakendub AINULT Null Surge kordaja,
	   Overclock jäetakse arvutusest välja.

	2) DIAGNOSTIKA LOGI.
	   Kui efektiivne kordaja ületab EXPLOIT_WARN_THRESHOLD, logitakse hoiatus.
	   See on playtesti tööriist, mitte hard-cap - tasakaalustamise otsused
	   teeme telemeetria põhjal, mitte ennatlikult.
]]

local CardManager = {}
CardManager.__index = CardManager

-- Kui efektiivne tootmiskordaja ületab selle, logi hoiatus playtesti jaoks.
CardManager.EXPLOIT_WARN_THRESHOLD = 6.0

function CardManager.new()
	local self = setmetatable({}, CardManager)

	self.activeCards = {}      -- list of CardBase instantse
	self.cardsByName = {}      -- kiire otsing nime järgi
	self.warningsLogged = {}   -- väldib sama hoiatuse korduvat spammimist

	return self
end

-- ============================================================
-- KAARTIDE AKTIVEERIMINE
-- Otsus: kord aktiveeritud kaart jääb aktiivseks kuni run'i lõpuni.
-- Tsüklilised efektid (Flux Tide, Null Surge) toimuvad kaardi SEES.
-- ============================================================

function CardManager:ActivateCard(card, context)
	table.insert(self.activeCards, card)
	self.cardsByName[card.cardName] = card
	card:OnActivate(context)
end

function CardManager:DeactivateCard(cardName, context)
	local card = self.cardsByName[cardName]
	if not card then
		return false
	end

	card:OnDeactivate(context)
	self.cardsByName[cardName] = nil

	for i, c in ipairs(self.activeCards) do
		if c == card then
			table.remove(self.activeCards, i)
			break
		end
	end
	return true
end

function CardManager:GetCard(cardName)
	return self.cardsByName[cardName]
end

function CardManager:IsCardActive(cardName)
	local card = self.cardsByName[cardName]
	return card ~= nil and card.isActive
end

-- ============================================================
-- ERANDIREEGLID (kaartidevahelised interaktsioonid)
-- ============================================================

-- Kas antud hexil on kaart, mis hälbeid (rikkeid) väldib?
-- Kasutab Stable Hex kaarti. OLULINE EXPLOIT-OTSUS:
-- Stable Hex kaitseb ainult Wild Hexi ENDA rikete vastu, MITTE
-- Overclocki ülekuumenemise vastu. Vastasel juhul oleks
-- "Stable Hex + Overclock" riskivaba 2.5x = dominantne strateegia,
-- mis muudaks kõik teised valikud mõttetuks.
function CardManager:HexPreventsFailures(q, r)
	for _, card in ipairs(self.activeCards) do
		if card.isActive
			and card.PreventsFailures
			and card.targetQ == q
			and card.targetR == r
		then
			if card:PreventsFailures() then
				return true
			end
		end
	end
	return false
end

-- Kas Null Surge on hetkel oma EFEKTIFAASIS (mitte lag-faasis)?
function CardManager:IsNullSurgeActive()
	local nullSurge = self.cardsByName["NullSurge"]
	if not nullSurge or not nullSurge.isActive then
		return false
	end
	return nullSurge.phase == "effect"
end

-- Kas Null Surge on lag-faasis? (tootmine = 0 kõigile)
function CardManager:IsNullSurgeLagging()
	local nullSurge = self.cardsByName["NullSurge"]
	if not nullSurge or not nullSurge.isActive then
		return false
	end
	return nullSurge.phase == "lag"
end

-- Kas hooned peaksid sisendressursse ignoreerima?
-- Null Surge efektifaasis toodavad hooned ka ilma sisendita (spec 5.6).
function CardManager:ShouldIgnoreInputs()
	return self:IsNullSurgeActive()
end

-- ============================================================
-- EFEKTIIVSE MULTIPLIKAATORI ARVUTUS
-- ============================================================

function CardManager:ComputeProductionMultiplier(building, context)
	-- ERAND 1: Null Surge lag-periood peatab tootmise täielikult.
	if self:IsNullSurgeLagging() then
		return 0
	end

	local nullSurgeActive = self:IsNullSurgeActive()
	local multiplier = 1.0

	for _, card in ipairs(self.activeCards) do
		if card:AffectsBuilding(building) then
			-- ERAND 2 (EXPLOIT-KAITSE): Null Surge efektifaasis jäetakse
			-- Overclock arvutusest välja - see EI korrutu Null Surge'iga.
			local skip = nullSurgeActive and card.cardName == "Overclock"

			if not skip then
				local mod = card:GetProductionModifier(building, context)
				multiplier = multiplier * mod
			end
		end
	end

	self:_CheckForExploit(building, multiplier)

	return multiplier
end

function CardManager:ComputeDefenseMultiplier(building, context)
	local multiplier = 1.0
	for _, card in ipairs(self.activeCards) do
		if card:AffectsBuilding(building) then
			multiplier = multiplier * card:GetDefenseModifier(building, context)
		end
	end
	return multiplier
end

-- Playtesti diagnostika: logi, kui kordaja läheb ootamatult suureks.
function CardManager:_CheckForExploit(building, multiplier)
	if multiplier < CardManager.EXPLOIT_WARN_THRESHOLD then
		return
	end

	local key = building.buildingType .. ":" .. string.format("%.1f", multiplier)
	if self.warningsLogged[key] then
		return
	end
	self.warningsLogged[key] = true

	local activeNames = {}
	for _, card in ipairs(self.activeCards) do
		if card:AffectsBuilding(building) then
			table.insert(activeNames, card.cardName)
		end
	end

	warn(string.format(
		"[Hexagonium EXPLOIT-HOIATUS] %s kordaja = %.2fx (lävi %.1fx). Aktiivsed kaardid: %s",
		building.buildingType,
		multiplier,
		CardManager.EXPLOIT_WARN_THRESHOLD,
		table.concat(activeNames, ", ")
	))
end

-- ============================================================
-- TICK
-- Kutsutakse TickService'i poolt. Kõigepealt uuendab kaartide
-- sisemised tsüklid, seejärel rakendab kordajad hoonetele.
-- ============================================================

function CardManager:Tick(buildings, context)
	for _, card in ipairs(self.activeCards) do
		if card.isActive then
			card:OnTick(context)
		end
	end

	-- Null Surge efektifaasis toodavad hooned ilma sisendressurssideta.
	-- Seame lipu hoonetele, et nad ei peaks CardManager'it ise tundma.
	local ignoreInputs = self:ShouldIgnoreInputs()

	for _, building in ipairs(buildings) do
		if not building.isDestroyed then
			building:SetProductionMultiplier(self:ComputeProductionMultiplier(building, context))
			building:SetDefenseMultiplier(self:ComputeDefenseMultiplier(building, context))
			if building.SetIgnoreInputs then
				building:SetIgnoreInputs(ignoreInputs)
			end
		end
	end
end

return CardManager
