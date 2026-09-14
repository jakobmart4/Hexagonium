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
}

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
		OreProductionRate = 5,
		OreProductionInterval = 5,
		CrystalProductionRate = 3,
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

	ResourceBloom = {
		ExtractorBonus = 0.25,
		RefineryBonus = 0.10,
		AssemblerBonus = 0.05,
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
--   META-TASAND: pusiv, sailib run'ide vahel (Hex Seed)
--     StartRadius -> MetaMaxRadius
--
--   RUN-TASAND: ajutine, lahtestub iga run'i alguses
--     kuni RunExpansionsMax ronga meta-raadiusest kaugemale
--     maksab upgradePoints (Assembleri toodang)
--
-- Naide: meta=5, run-laiendusi 2 -> aktiivne raadius 7
-- ============================================================
Constants.IslandExpansion = {
	StartRadius = 4,        -- uue mangija algne saar
	MetaMaxRadius = 6,      -- meta-progressiooni lagi
	MaxRadius = 8,          -- genereeritud saare koguulatus

	RunExpansionsMax = 2,   -- mitu ronga saab uhe run'i jooksul avada

	-- Esimene run-laiendus maksab BaseCost, iga jargmine korrutatakse
	-- CostMultiplier'iga. Nii ei saa mangija lopmatult laieneda.
	RunExpansionBaseCost = 40,      -- upgradePoints
	RunExpansionCostMultiplier = 3, -- 40 -> 120 -> 360 ...
}

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
Constants.BuildCosts = {
	Extractor = 20,
	Refinery  = 35,
	Assembler = 50,
	PowerCore = 40,
	-- Tasakaalustatud SAMM 8 samm 3: 45 -> 35, et 2./3. Defender oleks
	-- majanduslikult jouetav lahedal ajal, mil oht seda juba nouab.
	Defender  = 35,
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
	RewardPerExpansion = 40,

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

	-- META-PROGRESSIOON
	RewardPerMetaRadius = 600,

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
		OreRequired = 50,
		CrystalRequired = 20,
		Deadline = 30,
		RewardFreeCards = 1,
	},

	AttackDelayAfterHostile = 30,

	-- Esimene Neutral -> Demand tsükkel tutoriali lõpetamata mängijale
	-- (tavaliselt FractureSyndicate.DEMAND_INTERVAL = 150s). Ilma selleta
	-- peaks uus mängija ootama runnaku-sammu jaoks üle 2 minuti.
	TutorialDemandInterval = 30,
}

return Constants
