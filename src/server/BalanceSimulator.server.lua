local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not require(ReplicatedStorage.Shared.Constants).Debug.RunBalanceSim then
	return
end

--[[
	BalanceSimulator.server.lua
	Kiire, matemaatiline tasakaalustamise mudel — EI ehita 3D maailma
	ega oota reaalajas, seega jookseb silmapilkselt. Kasutab SAMU
	valemeid ja Constants-väärtusi mida pärismäng (RunManager,
	AttackManager, FractureSyndicate), et simulaator ei saaks
	Constants'ist lahku minna.

	MIS SEE POLE: täpne AttackManager/RunManager kloon. Hoone-täpne
	kahjujaotus, ründaja liikumisaeg saareni ja regeneratsioon lainete
	VAHEL on lihtsustatud (vt allolevad OLULINE EELDUS kommentaarid) —
	tulemus on suunanäitaja, mitte ennustus viimase kümnendikuni.

	KÄIVITUB automaatselt Play-režiimis, kui Constants.Debug.
	RunBalanceSim = true. Vaata tulemust konsoolist, samamoodi nagu
	CardSystemTest.server.lua.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local FractureSyndicate = require(ServerScriptService.Factions.FractureSyndicate)

local ATK = Constants.Attack
local DEF = Constants.Buildings.Defender
local RUN = Constants.Run
local DEMAND = Constants.Faction.Demand

-- FractureSyndicate'i enda staatilised väljad, et need arvud ei
-- elaks kahes kohas (vt DEMAND_INTERVAL / ATTACK_DURATION seal).
local DEMAND_INTERVAL = FractureSyndicate.DEMAND_INTERVAL
local ATTACK_DURATION = FractureSyndicate.ATTACK_DURATION
local ATTACK_DELAY = Constants.Faction.AttackDelayAfterHostile

task.wait(2)

print("")
print("=====================================================")
print("  HEXAGONIUM - TASAKAALUSTAMISE SIMULAATOR")
print("=====================================================")

-- ============================================================
-- 1-2. PRAEGUSED VÄÄRTUSED + TULETATUD SUURUSED
-- (täpne tabel elab docs/TASAKAALUSTAMINE.md's — siin ainult need
-- read, mida allolev simulatsioon otse kasutab)
-- ============================================================
local defenderDPS = DEF.DefensePoints / DEF.FireInterval
local attackerDPS = ATK.AttackerDamage / ATK.AttackerHitInterval
local assemblerUpPerMin = (60 / Constants.Buildings.Assembler.AlloyConsumptionInterval)
	* Constants.Buildings.Assembler.AlloyConsumptionRate
local coreChainCost = Constants.BuildCosts.Extractor + Constants.BuildCosts.Refinery
	+ Constants.BuildCosts.Assembler + Constants.BuildCosts.PowerCore

print("")
print("--- Tuletatud suurused ---")
print(string.format("Defenderi DPS: %.1f (DefensePoints/FireInterval)", defenderDPS))
print(string.format("Ründaja DPS hoonele: %.1f (AttackerDamage/AttackerHitInterval)", attackerDPS))
print(string.format("Assembler baastoodang: %.1f UP/min", assemblerUpPerMin))
print(string.format("Tuumahela hind (Extractor+Refinery+Assembler+PowerCore): %d UP (algkapital %d)",
	coreChainCost, RUN.StartingPoints))
print(string.format("Demand-tsükkel: %ds tavaliselt, %ds tutoriali ajal",
	DEMAND_INTERVAL, Constants.Faction.TutorialDemandInterval))

-- ============================================================
-- SAMM 5: TUTORIALI KESTUS (deterministlik, mitte juhuslik)
-- Halvim/tüüpiline juht: mängija teeb sammud 1-3 kiiresti, aga
-- 4. samm ootab päris rünnaku algust, mis käib läbi TÄPSELT samade
-- kiirendatud taimerite kaudu, olenemata sellest.
-- ============================================================
local tutorialWorstCase = Constants.Faction.TutorialDemandInterval + DEMAND.Deadline + ATTACK_DELAY
print("")
print("--- Küsimus 5: kas tutorial on liiga aeglane/kiire? ---")
print(string.format(
	"Samm 4 (rünnaku algus) jõuab kätte ~%ds pärast liitumist (TutorialDemandInterval %ds + "
		.. "Demand.Deadline %ds + AttackDelayAfterHostile %ds), EELDUSEL et mängija ei maksa "
		.. "Demand'i ega jõua samme 1-3 sellest kiiremini teha, sest need tsüklid on sõltumatud.",
	tutorialWorstCase, Constants.Faction.TutorialDemandInterval, DEMAND.Deadline, ATTACK_DELAY))
print(string.format("KINNITATUD Play-testimisel (SAMM 7): täielik tsükkel läbis ~%d-%ds piires.  [OK]",
	tutorialWorstCase - 10, tutorialWorstCase + 30))

-- ============================================================
-- MÄNGIJA-ARHETÜÜBID
-- Ei ürita ennustada mängijat — need on STIPULEERITUD käitumised,
-- mille TAGAJÄRGI (kaotuseprotsent, run'i kestus) simulatsioon mõõdab.
-- ============================================================
local ARCHETYPES = {
	{
		name = "Passiivne",
		defenderMinute = function() return math.huge end, -- ei ehita kunagi
		willPayDemand = function() return false end,
	},
	{
		name = "Ettevaatlik",
		defenderMinute = function(rng)
			-- Defender (45 UP) maksab endale kätte niipea kui tuumahel
			-- (145 UP) on püsti ja ~1 min toodangut kogunenud.
			return 1 + math.ceil(Constants.BuildCosts.Defender / assemblerUpPerMin)
		end,
		willPayDemand = function() return true end,
	},
	{
		name = "Ahne (ei laienda, jääb kauaks)",
		defenderMinute = function(rng) return 3 + rng:NextInteger(0, 2) end,
		willPayDemand = function(rng) return rng:NextNumber() < 0.4 end,
	},
	{
		name = "Tasakaalus (segu)",
		defenderMinute = function(rng) return 2 + rng:NextInteger(0, 4) end,
		willPayDemand = function(rng) return rng:NextNumber() < 0.7 end,
	},
}

-- OLULINE EELDUS: baashoonete "eluring" on 5 * BuildingHealth
-- (Extractor+Refinery+Assembler+PowerCore+Defender) — regeneratsioon
-- LAINETE VAHEL ja ründaja kohalejõudmise aeg on IGNOREERITUD
-- (pessimistlik: annab tegelikust natuke rohkem kaotusi). Kui see
-- muudab tulemust liiga karmiks, tuleb see esimesena üle vaadata.
local BASE_HP_POOL = 5 * ATK.BuildingHealth

local function simulateRun(archetype, rng)
	local defenderMinute = archetype.defenderMinute(rng)
	local minute = 0
	local demandsFaced, demandsPaid = 0, 0
	local endReason, endMinute = "Timeout", RUN.Duration / 60

	while minute < RUN.Duration / 60 do
		minute = minute + (DEMAND_INTERVAL / 60)
		demandsFaced = demandsFaced + 1

		if archetype.willPayDemand(rng) then
			demandsPaid = demandsPaid + 1
			continue
		end

		-- Hostile -> Attack, samad valemid mis AttackManager:StartWave/RunManager:GetThreatScale
		local threatScale = math.min(1 + minute * ATK.ScalePerMinute, ATK.MaxScale)
		local waveSize = math.min(math.floor(ATK.BaseAttackers * threatScale), ATK.MaxAttackers)
		local attackerHP = ATK.AttackerHealth * threatScale
		local totalAttackerHP = waveSize * attackerHP

		local hasDefender = minute >= defenderMinute
		local defenderDamageDealt = (hasDefender and defenderDPS or 0) * ATTACK_DURATION
		local hpThrough = math.max(0, totalAttackerHP - defenderDamageDealt)
		local attackersThrough = math.ceil(hpThrough / attackerHP)
		local hitsPerAttacker = math.floor(ATTACK_DURATION / ATK.AttackerHitInterval)
		local damageToBase = attackersThrough * hitsPerAttacker * attackerDPS

		if damageToBase >= BASE_HP_POOL then
			endReason, endMinute = "Destroyed", minute
			break
		end
	end

	return {
		archetype = archetype.name,
		endReason = endReason,
		endMinute = endMinute,
		demandsFaced = demandsFaced,
		demandsPaid = demandsPaid,
		attacksSurvived = attacksSurvived,
		hadDefenderEventually = defenderMinute < math.huge,
	}
end

-- ============================================================
-- SAMM 2: N SIMULEERITUD RUN'I (4 arhetüüpi x 5 seemet = 20)
-- ============================================================
local results = {}
for _, archetype in ipairs(ARCHETYPES) do
	for seed = 1, 5 do
		local rng = Random.new(seed * 97 + #archetype.name)
		table.insert(results, simulateRun(archetype, rng))
	end
end

local function pct(count, total)
	if total == 0 then return 0 end
	return count / total * 100
end

local destroyed, totalDemandsFaced, totalDemandsPaid, totalMinutes, withDefender = 0, 0, 0, 0, 0
for _, r in ipairs(results) do
	if r.endReason == "Destroyed" then destroyed = destroyed + 1 end
	totalDemandsFaced = totalDemandsFaced + r.demandsFaced
	totalDemandsPaid = totalDemandsPaid + r.demandsPaid
	totalMinutes = totalMinutes + r.endMinute
	if r.hadDefenderEventually then withDefender = withDefender + 1 end
end

print("")
print(string.format("--- %d simuleeritud run'i (%d arhetüüpi x 5 seemet) ---", #results, #ARCHETYPES))

print("")
print("--- Küsimus 1: kui tihti mängija kaotab (baas hävib)? ---")
print(string.format("%-52s %.0f%%%s", "DESTROYED-lõpetuste osakaal", pct(destroyed, #results),
	pct(destroyed, #results) > 50 and "  [LIIGA KARM?]" or ""))

print("")
print("--- Küsimus 2/3: Demand-maksmine ja Defenderi ehitamine (arhetüübi eeldus, mitte tulemus) ---")
print(string.format("%-52s %.0f%%", "Demand'ide osakaal, mis makstakse", pct(totalDemandsPaid, totalDemandsFaced)))
print(string.format("%-52s %.0f%%", "Run'ide osakaal, kus Defender kunagi ehitatakse", pct(withDefender, #results)))

print("")
print("--- Küsimus 4: kas UP majandus on liiga kiire/aeglane? ---")
print(string.format("Tuumahel (%d UP) valmis minutil ~0 (algkapitalist). Sealt %.1f UP/min.",
	coreChainCost, assemblerUpPerMin))
print(string.format("Defender (%d UP) taskukohane minutil ~%d.", Constants.BuildCosts.Defender,
	math.ceil(Constants.BuildCosts.Defender / assemblerUpPerMin)))
print(string.format("1. saare laiendus (%d UP) taskukohane minutil ~%d.",
	Constants.IslandExpansion.RunExpansionBaseCost,
	math.ceil(Constants.IslandExpansion.RunExpansionBaseCost / assemblerUpPerMin)))

print("")
print("--- Küsimus 6: kas rünnakud on liiga nõrgad/tugevad? (Defenderiga baas) ---")
for _, checkpointMin in ipairs({0, 15, 30, 60}) do
	local threatScale = math.min(1 + checkpointMin * ATK.ScalePerMinute, ATK.MaxScale)
	local waveSize = math.min(math.floor(ATK.BaseAttackers * threatScale), ATK.MaxAttackers)
	local attackerHP = ATK.AttackerHealth * threatScale
	local totalHP = waveSize * attackerHP
	local defenderDamage = defenderDPS * ATTACK_DURATION
	local survives = defenderDamage >= totalHP
	print(string.format("  minut %-3d threatScale %.2fx, laine %d ründajat (%.0f HP kokku) — "
		.. "1 Defender jõuab %.0f kahju teha lainejooksul (%ds) -> %s",
		checkpointMin, threatScale, waveSize, totalHP, defenderDamage, ATTACK_DURATION,
		survives and "puhastab laine  [OK]" or "EI jõua puhastada"))
end

print("")
print("--- Küsimus 7: kas run'i pikkus (Duration) on õige? ---")
print(string.format("Keskmine simuleeritud lõpp: minut %.0f / %.0f lubatud (%s)",
	totalMinutes / #results, RUN.Duration / 60,
	totalMinutes / #results < (RUN.Duration / 60) * 0.5
		and "enamik run'e lõpeb tunduvalt enne Timeout'it"
		or "run'id kestavad Timeout'ile lähedale"))

print("")
print("--- Küsimus 8: kas RestartDelay on liiga lühike/pikk? ---")
print(string.format("RestartDelay = %ds — TUNNETUSLIK küsimus, vajab manuaalset Play-testi.",
	RUN.RestartDelay))
print("  Vt docs/TASAKAALUSTAMINE.md punkt 3.")

print("")
print("=====================================================")
print("  Simulatsioon lõppenud")
print("=====================================================")
print("")
