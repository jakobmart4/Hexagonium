--[[
	Constants.lua
	Kõik mängu balance-väärtused ühes kohas.
	Kui midagi vajab tasakaalustamist, muuda ainult siin.
]]

local Constants = {}

-- ============================================================
-- SILUMINE
-- Koik arendusaegsed valjundid uhe luliti taga. Enne avaldamist
-- pane koik false - siis ei lekita mang konsooli ega _G kaudu
-- infot, mida mangija naha ei peaks.
-- ============================================================
Constants.Debug = {
	RunTests = false,        -- CardSystemTest iga Play vajutusega
	RunBalanceSim = false,   -- BalanceSimulator iga Play vajutusega
	VerboseLogging = false,  -- Bootstrapi ressursivoo print iga 3 sek
	ExposeGameState = false, -- _G.HexagoniumState testskriptide jaoks

	-- Kaivitab runnaku N sekundi parast mangu algust.
	-- 0 = valjas. Ainus viis runnakususteemi testida ilma
	-- 150 sekundit ootamata.
	ForceAttackAfter = 0,

	-- Kustutab mangija DataStore-salvestuse enne laadimist. Ainus viis
	-- Studios kontrollida, mida PARIS uus mangija naeb - olemasolev
	-- bonusExpansions jm CLAMPITAKSE uude vahemikku, kui Constants muutub,
	-- mitte ei lahtestata (vt SaveService.fillDefaults).
	WipeSaveOnJoin = false,
}

-- KOHALIKUD TESTILIPUD: src/shared/LocalDebug.lua (gitignore'is, iga arendaja
-- oma) kirjutab ülalolevad üle, nt `return {WipeSaveOnJoin = true}`.
-- Nii ei satu testiväärtus kogemata commit'i ega jää git'i "muudetud"
-- olekusse. Rakendub AINULT Studios - unustatud fail ei mõjuta avaldatud mängu.
local localDebug = script.Parent:FindFirstChild("LocalDebug")
if localDebug and game:GetService("RunService"):IsStudio() then
	for key, value in pairs(require(localDebug)) do
		Constants.Debug[key] = value
	end
end

-- ============================================================
-- RESSURSITÜÜBID (MVP: 3 tüüpi)
-- ============================================================
Constants.ResourceTypes = {
	ORE = "Ore",
	CRYSTAL = "Crystal",
	ALLOY = "Alloy",
}

-- ============================================================
-- HEX-TÜÜBID
-- ============================================================
Constants.HexTypes = {
	ORE_HEX = "OreHex",
	CRYSTAL_HEX = "CrystalHex",
}

-- ============================================================
-- HOONETE VÄÄRTUSED
-- ============================================================
Constants.Buildings = {
	Extractor = {
		-- 1 / 5 s = 12 ore/min = täpselt ühe Refinery tarbimine (1:1:1 ahel).
		-- Oli 5 (60/min): Play-test 7c-s kogunes ~3000 maaki Refinery
		-- sisendisse, alloy'd jäi paarsada (24.09).
		OreProductionRate = 1,
		OreProductionInterval = 5,
		-- 1 / 5 s = 12/min = 600 energiat/min ~ 5 Defenderit. Oli 3 (36/min):
		-- Play-test 7c kordusel kuhjus 332 kristalli, Power Core oli pidevalt
		-- täis ja 2 Defenderit tarbisid ~5 kristalli/min (24.09).
		CrystalProductionRate = 1,
		CrystalProductionInterval = 5,
	},

	PowerCore = {
		MaxEnergyStorage = 1000,
		StartingEnergy = 1000,
		EnergyLeakMultiplier = 0.95,
		EnergyLeakInterval = 30,
		EnergyLeakPauseThreshold = 0.8,
		EnergyLeakPauseDuration = 10,
		-- OLULINE EELDUS: spec ei määratlenud crystal->energia konversioonimäära.
		-- Väärtus on esialgne, playtestimisel tasakaalustatav. Muuda ainult siin.
		EnergyPerCrystal = 50,

		-- TOWN HALL: Power Core'i saab run'i jooksul uuendada. Maksab UP-d
		-- ja kristalli (ülejääv kristall saab kasutuse, 24.09). Boonus kehtib
		-- KÕIGI hoonete läbilaskevõimele ühtlaselt (ahel jääb 1:1:1); mitme
		-- Power Core'i korral loeb kõrgeim tase, mitte summa. Hävinud Power
		-- Core'iga kaob ka boonus. Tase 1 = ehitatud hoone.
		TownHall = {
			[2] = {Cost = 30, Crystal = 30, ProductionBonus = 0.15, MaxEnergy = 1500},
			[3] = {Cost = 60, Crystal = 60, ProductionBonus = 0.30, MaxEnergy = 2000},
		},
	},

	Defender = {
		EnergyCostPerTick = 10,
		EnergyCostInterval = 5,
		-- Tasakaalustatud SAMM 8 samm 3: 25 -> 35 (vt TASAKAALUSTAMINE.md
		-- punkt 4). Uhe torni DPS ei pidanud sammu ruutvordelise
		-- ohukasvuga (vt Attack.ScalePerMinute).
		DefensePoints = 35,
		DefenseRadius = 3,
		FireInterval = 1,
	},

	Refinery = {
		OreToAlloyRate = 1,
		OreToAlloyInterval = 5,
	},

	Assembler = {
		AlloyConsumptionRate = 1,
		AlloyConsumptionInterval = 5,
	},
}

-- ============================================================
-- NODE-SÜSTEEM (ressursivool)
-- ============================================================
Constants.NodeSystem = {
	TickInterval = 1,
}

-- ============================================================
-- KAARDID (Reality Cards)
-- ============================================================
Constants.Cards = {
	Overclock = {
		ProductionMultiplier = 2.5,
		OverheatCheckInterval = 60,
		OverheatChance = 0.05,
		OverheatDuration = 20,
	},

	FluxTide = {
		CycleInterval = 180,
		BonusMultiplier = 1.5,
		BonusDuration = 30,
		PenaltyMultiplier = 0.7,
		PenaltyDuration = 60,
	},

	BlessedHex = {
		EfficiencyBonus = 0.10,
	},

	FracturePact = {
		DemandPercentOfProduction = 0.10,
		TradeStateDuration = 60,
		AttackDelayAfterRefusal = 30,
	},

	MirrorWorld = {
		BlessedHexEffect = -0.10,
		WildHexEffect = 0.10,
		StableHexEffect = 0.0,
		GlobalProductionMultiplier = 0.9,
		GlobalDefenseMultiplier = 1.1,
	},

	NullSurge = {
		ActivationInterval = 240,
		EffectDuration = 10,
		ProductionMultiplier = 3.0,
		LagDuration = 5,
	},

	-- Ühtlane (oli 25/10/5 %): erinevad kordajad ahela lülidel viisid
	-- 1:1:1 ahela tasakaalust välja - maak/alloy kuhjus (24.09).
	ResourceBloom = {
		ExtractorBonus = 0.15,
		RefineryBonus = 0.15,
		AssemblerBonus = 0.15,
	},

	EnergyLeak = {},

	HexMutationWild = {
		ProductivityBonus = 0.20,
		FailChance = 0.10,
		FailCheckInterval = 45,
		FailDuration = 5,
	},

	HexMutationStable = {
		ProductivityBonus = 0.10,
		FailChance = 0.0,
	},
}

-- ============================================================
-- SAARE LAIENDUS (kaheastmeline)
--
--   START: saar alustab IGA run'i StartRadius'iga (sama mis Studio
--     Edit-vaade). Varem kasvas algsaar pusivalt - suurem algsaar
--     hajutas algbaasi ja jattis hooneid Defenderist kaugele.
--
--   META-TASAND: pusiv, ostetakse Hex Seeds'iga (start screen)
--     kuni MetaExpansionsMax lisalaienduskohta run'i kohta
--
--   RUN-TASAND: ajutine, lahtestub iga run'i alguses
--     kuni RunExpansionsMax + ostetud lisad ronga, igauks maksab
--     upgradePoints (Assembleri toodang)
--
-- Naide: 2 ostetud lisa -> run'is kuni 4 laiendust, raadius 3 -> 7
-- ============================================================
Constants.IslandExpansion = {
	-- Tasakaalustatud kasutaja tagasiside jargi. SEE TABEL ON AINUS
	-- allikas saare suuruse jaoks - Workspace.Islands._Preview
	-- (Studio Edit-vaates nahtav staatiline "eelvaade") EI OLE
	-- kunagi seotud selle koodiga (Bootstrap kustutab selle iga
	-- Play alguses, vt "eelvaade eemale" kommentaar) ja labi
	-- audititeerimise selgus, et see oli lihtsalt vananenud
	-- kasutamatta jaanud objekt, mitte usaldusvaarne vordlus.
	--
	-- MetaExpansionsMax = 4: pusiv progressioon on TAPSELT 4 ostu, igauks
	-- annab run'is uhe laiendusronga rohkem. Saar ise ei kasva enam
	-- pusivalt. MaxRadius TULETATAKSE tabeli all.
	--
	-- TESTIMINE: olemasolev salvestus CLAMPITAKSE uude vahemikku,
	-- mitte ei lahtestata, kui neid vaartusi muudad - kasuta
	-- Constants.Debug.WipeSaveOnJoin = true, et naha, mida PARIS uus
	-- mangija saab (ja lulita See uuesti valja parast testimist!).
	StartRadius = 3,        -- saar alustab IGA run'i sellega (= Studio Edit-vaade)
	MetaExpansionsMax = 4,  -- ostetavaid lisalaienduskohti (Hex Seeds)

	RunExpansionsMax = 2,   -- tasuta laienduskohti igas run'is (+ ostetud lisad)

	-- Esimene run-laiendus maksab BaseCost, iga jargmine korrutatakse
	-- CostMultiplier'iga. Nii ei saa mangija lopmatult laieneda.
	RunExpansionBaseCost = 40,      -- upgradePoints
	-- x1.75: kokkuhoidva mängija mudelis (1 ahel = 12 UP/min, 1 Defender)
	-- jõuab 60-min run'is 5 laienduseni, 6. jääb haruldaseks saavutuseks.
	-- x3 juures jäid kõik 4 ostetud lisakohta kasutamata. Laiendus ei anna
	-- tasu (RewardPerExpansion = 0), seega valik "saar VÕI kasum" jääb.
	-- Uuring 1.5-3: vt TASAKAALUSTAMINE.md 15.09.2026.
	RunExpansionCostMultiplier = 1.75, -- 40 -> 70 -> 122 -> 214 -> 375 -> 656
}

-- Genereeritud saare koguulatus = koige kaugem voimalik rong. TULETATUD,
-- mitte eraldi arv, et see ei saaks laienduskohtade arvust lahku minna.
Constants.IslandExpansion.MaxRadius = Constants.IslandExpansion.StartRadius
	+ Constants.IslandExpansion.RunExpansionsMax
	+ Constants.IslandExpansion.MetaExpansionsMax

-- ============================================================
-- HOONETE HINNAD
--
-- Makstakse upgradePoints'ides, samast pangast, millest
-- ostetakse saare laiendus. See on tahtlik: mangija peab valima
-- ROHKEM TOOTMIST vs ROHKEM MAAD vs KAITSE.
--
-- Enne hindu oli piirav ressurss hex-ruum. Nuud on piirav
-- ressurss aeg ja tootmisvoimsus - see on tycoonile omasem.
--
-- Arvutus: Assembler toodab 1 punkti / 5 sek = 12 punkti/min.
-- Algkapital 150 lubab avada tootmisahela, edasi tuleb teenida.
-- ============================================================
-- 24.09 (Play-test 7c kordus, kasutaja): kõik ~15% kallimaks. Uus ahel
-- Extractor+Refinery+Assembler = 120 UP, tasub end ära ~10 min (12 UP/min).
Constants.BuildCosts = {
	Extractor = 25,
	Refinery  = 40,
	Assembler = 55,
	PowerCore = 45,
	-- SAMM 8 samm 3: 45 -> 35, et 2./3. Defender oleks jõukohane, kui
	-- oht seda nõuab. 24.09: 35 -> 40 koos teiste hindadega.
	Defender  = 40,
}

-- Lammutamisel tagastatav osa. Alla poole, et ehitusvead maksaksid,
-- aga umberpaigutamine ei oleks karistus.
Constants.DemolishRefund = 0.5

-- ============================================================
-- RUN-SUSTEEM
--
-- Run lopeb KOLMEL viisil:
--   1) Taimer  - garanteerib, et run alati lopeb
--   2) Baas havib - annab runnakutele paris kaalu
--   3) Extract - mangija otsustab ise lahkuda
--
-- Extract toimib ainult siis, kui jaamine on nii TULUSAM kui
-- OHTLIKUM. Seetottu kasvavad nii tasu kui runnakud ajas.
-- ============================================================
Constants.Run = {
	-- Run'i pikkus on MUUTUV. Taimer on ohutuspiir, mitte peamine
	-- lopp - moni run lopeb paari minutiga, teine venib tunnini.
	-- Paris surve tuleb kasvavast ohust, mitte kellast.
	Duration = 3600,         -- 60 minutit (ulempiir)
	WarningAt = 120,         -- hoiatus, kui nii palju jaanud

	-- TASU KOGUNEMINE
	RewardPerUpgradePoint = 1,
	RewardPerAttackSurvived = 25,
	-- 0: laiendus EI anna tasu. Kulutamine ei vähenda run'i tasu (tasu
	-- loeb TOODETUD UP-d), nii et +40 tegi 1. laienduse tasuta. Nüüd
	-- maksab laiendus ainult tootmisvõimsuses - valik "saar VÕI kasum".
	RewardPerExpansion = 0,

	-- Ajaboonus: iga minut vaartuslikum kui eelmine.
	-- MARKUS: 6% liitkasv, MITTE 15%. Tunnipikkuse run'i puhul
	-- annaks 15% viimasel minutil ~19000 punkti - absurd.
	-- 6% juures on 60. minut ~160 ja kogusumma ~2700.
	RewardPerMinute = 5,
	RewardMinuteScaling = 0.06,

	-- VALJAMAKSE OSAKAAL lopu tuubi jargi
	PayoutExtract = 1.0,     -- lahkud ise: koik alles
	PayoutTimeout = 1.0,     -- pead loppuni vastu: koik alles
	PayoutDestroyed = 0.10,  -- baas havib: kaotad 90%

	-- ALGKAPITAL
	-- Ilma selleta ei saaks run'i alguses midagi ehitada:
	-- punkte toodab Assembler, aga Assembler ise maksab punkte.
	StartingPoints = 150,

	-- Kui kaua RUN COMPLETE/LOST ekraan seisab, enne kui jargmine
	-- run samas maailmas automaatselt algab. Piisavalt pikk, et
	-- mangija jouaks tulemust lugeda, aga mitte nii pikk, et istuks
	-- tegevuseta.
	RestartDelay = 8,
}

-- ============================================================
-- META-PROGRESSIOON (Hex Seeds)
--
-- Run'i tasu muutub SEEMNETEKS, mida mangija kulutab ise run'ide
-- vahel (start screen). Varem andis run'i lopp saare laiendused
-- OTSE ja KORRAGA (floor(tasu / 600)) - uks 60-minutiline run
-- (~2700 tasu) ammendas kogu 4-sammulise meta-progressiooni.
-- ============================================================
Constants.Meta = {
	-- Sama maar mis vana Run.RewardPerMetaRadius, et balanss ei
	-- nihkuks: 1 seeme = endine 1 tasuta laiendus.
	SeedsPerPayout = 600,

	-- Vähemalt nii palju seemneid iga run'i eest, mis ei lõppenud baasi
	-- hävinguga (Extract/Timeout). Play-test B: 8-min run andis 0 seemet
	-- ja uus mängija ei näinud meta-tsüklit üldse (16.09).
	MinSeedsPerRun = 1,

	-- N-s ostetud lisalaiendus maksab N * see. Tabelit TAHTLIKULT pole:
	-- ostude arv tuleb ainult IslandExpansion.MetaExpansionsMax'ist,
	-- mitte teisest kohast, mis voiks sellest lahku minna.
	IslandUpgradeCostPerStep = 1,

	-- KAARDID: uus mangija alustab nende kaartidega, ulejaanud avatakse
	-- seemnete eest (start screen). Algkomplekt = madala riskiga kaardid
	-- + uks hex-kaart, et hex-sihtimine oleks ilma ostuta opitav.
	-- Overclock (x2.5) on OSTETAV: algkomplektis oli see 0. minutist
	-- sees ja tegi majanduse liiga lihtsaks (Play-test B, 16.09.2026).
	-- Kaardi-listi allikas on endiselt CardRegistry/CardInfo.
	StartingCards = {"ResourceBloom", "BlessedHex", "HexMutationStable"},
	CardUnlockCost = 2,
}

-- ============================================================
-- RUNNAKUD
-- Fraktsiooni Attack olek saadab laine ruundajaid, kes liiguvad
-- saare servalt sihtmargi poole. Defenderid tulistavad neid teel.
-- ============================================================
Constants.Attack = {
	-- Laine suurus kasvab, mida suurem on saar
	BaseAttackers = 3,
	AttackersPerRing = 1,    -- +1 ruundaja iga raadiuse uhiku kohta ule algse
	MaxAttackers = 20,       -- tosteti 10 -> 20, sest run voib kesta tunni

	-- Tasakaalustatud SAMM 8 samm 3: 60 -> 30 (-50%). threatScale
	-- korrutab KORRAGA nii laine suurust KUI KA seda vaartust - koos
	-- kasvavad need ruutvordeliselt. Esimene katse (-25%, 45) ei
	-- piisanud (simulaator kinnitas: DESTROYED% ei liikunud) - vt
	-- TASAKAALUSTAMINE.md punkt 4.
	AttackerHealth = 30,
	AttackerDamage = 20,     -- kahju hoonele uhe loogi kohta
	AttackerHitInterval = 2, -- sekundit loogi vahel
	AttackerSpeed = 6,       -- studi sekundis

	SpawnDistance = 18,      -- kui kaugelt saare servast ilmuvad
	SpawnInterval = 1.5,     -- viivitus ruundajate vahel

	-- Hoone elupunktid. Uks vaartus koigile - MVP lihtsus.
	BuildingHealth = 100,
	-- Hoone taastub aeglaselt, kui teda ei runnata
	BuildingRegenPerSecond = 2,
	BuildingRegenDelay = 15, -- sekundit parast viimast kahju

	-- AJAS KASVAV OHT
	-- Ilma selleta poleks Extract'il motet: 20. minutil oleks
	-- runnak sama norк kui 2. minutil ja jaamine oleks tasuta.
	--
	-- LAGI 8.0 saabub 60. minutil (1 + 60*0.12 = 8.2). Nii ei jaa
	-- pikk run kunagi turvaliseks - lopuks murrab iga baasi.
	ScalePerMinute = 0.12,
	MaxScale = 8.0,
}

-- ============================================================
-- FRAKTSIOON: Fracture Syndicate
-- ============================================================
Constants.Faction = {
	States = {
		NEUTRAL = "Neutral",
		FRIENDLY = "Friendly",
		TRADE = "Trade",
		DEMAND = "Demand",
		HOSTILE = "Hostile",
		ATTACK = "Attack",
		RECOVER = "Recover",
	},

	Demand = {
		-- Skaleeritud koos Extractoriga (50 -> 10): ~50 s ühe Extractori
		-- tootmist nagu enne. 1:1:1 ahelas maaki ei kogune, nõue peab olema
		-- täidetav lisa-Extractoriga või ahela korraks peatamisega.
		OreRequired = 10,
		CrystalRequired = 20,
		Deadline = 30,
	},

	AttackDelayAfterHostile = 30,

	-- Tutoriali Demand-sammul (5): mitu sekundit pärast sammu kättejõudmist
	-- nõue tuleb (tavaliselt FractureSyndicate.DEMAND_INTERVAL = 150s).
	-- Piisav sammu teksti lugemiseks; 30s tundus Play-testis pikk (16.09).
	TutorialDemandInterval = 10,
}

return Constants
