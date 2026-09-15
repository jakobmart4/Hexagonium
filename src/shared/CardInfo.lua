--[[
	CardInfo.lua
	Mangijale nahtav info koigi kaartide kohta - INGLISE KEELES.

	TAHTIS: kirjeldused GENEREERITAKSE Constants.lua vaartustest.
	Varem olid numbrid kasitsi sisse kirjutatud ja said Constants'ist
	lahku minna - siis oleks UI mangijale valetanud. Nuud piisab
	balansi muutmisel ainult Constants.lua muutmisest.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)

local C = Constants.Cards
local PC = Constants.Buildings.PowerCore

local CardInfo = {}

-- Kordaja protsendiks: 1.5 -> "+50%", 0.7 -> "-30%"
local function pct(multiplier)
	local delta = (multiplier - 1) * 100
	return string.format("%s%d%%", delta >= 0 and "+" or "", math.floor(delta + 0.5))
end

-- Osakaal protsendiks: 0.25 -> "+25%"
local function bonus(fraction)
	return string.format("+%d%%", math.floor(fraction * 100 + 0.5))
end

-- Osakaal lihtprotsendiks: 0.05 -> "5%"
local function plain(fraction)
	return string.format("%d%%", math.floor(fraction * 100 + 0.5))
end

CardInfo.Cards = {
	Overclock = {
		displayName = "Overclock",
		cardType = "Rule Card",
		description = string.format(
			"All production runs at %.1fx speed. Every %ds each building has a %s chance to overheat and shut down for %ds.",
			C.Overclock.ProductionMultiplier,
			C.Overclock.OverheatCheckInterval,
			plain(C.Overclock.OverheatChance),
			C.Overclock.OverheatDuration),
		risk = "high",
	},
	FluxTide = {
		displayName = "Flux Tide",
		cardType = "Cycle Card",
		description = string.format(
			"Every %ds: energy output surges %s for %ds, then drops %s for %ds.",
			C.FluxTide.CycleInterval,
			pct(C.FluxTide.BonusMultiplier), C.FluxTide.BonusDuration,
			pct(C.FluxTide.PenaltyMultiplier), C.FluxTide.PenaltyDuration),
		risk = "medium",
	},
	BlessedHex = {
		displayName = "Blessed Hex",
		cardType = "Hex Mutation",
		description = string.format(
			"The chosen hex grants %s efficiency to any building on it.",
			bonus(C.BlessedHex.EfficiencyBonus)),
		risk = "none",
	},
	FracturePact = {
		displayName = "Fracture Pact",
		cardType = "Faction Card",
		description = string.format(
			"The Fracture Syndicate demands %s of your ore and crystal output. Accept for %ds of trade, refuse and they attack after %ds.",
			plain(C.FracturePact.DemandPercentOfProduction),
			C.FracturePact.TradeStateDuration,
			C.FracturePact.AttackDelayAfterRefusal),
		risk = "high",
	},
	MirrorWorld = {
		displayName = "Mirror World",
		cardType = "Rule Card",
		description = string.format(
			"All biome effects invert. Global production %s, global defense %s.",
			pct(C.MirrorWorld.GlobalProductionMultiplier),
			pct(C.MirrorWorld.GlobalDefenseMultiplier)),
		risk = "medium",
	},
	NullSurge = {
		displayName = "Null Surge",
		cardType = "Event Card",
		description = string.format(
			"Every %ds: production hits %.0fx and ignores all inputs for %ds, followed by a %ds blackout.",
			C.NullSurge.ActivationInterval,
			C.NullSurge.ProductionMultiplier,
			C.NullSurge.EffectDuration,
			C.NullSurge.LagDuration),
		risk = "medium",
	},
	ResourceBloom = {
		displayName = "Resource Bloom",
		cardType = "Rule Card",
		description = string.format(
			"Permanent boost: Extractors %s, Refineries %s, Assemblers %s. Energy unaffected.",
			bonus(C.ResourceBloom.ExtractorBonus),
			bonus(C.ResourceBloom.RefineryBonus),
			bonus(C.ResourceBloom.AssemblerBonus)),
		risk = "none",
	},
	EnergyLeak = {
		displayName = "Energy Leak",
		cardType = "Rule Card",
		description = string.format(
			"Power Cores lose %s of stored energy every %ds. Below %s capacity they shut down for %ds.",
			plain(1 - PC.EnergyLeakMultiplier),
			PC.EnergyLeakInterval,
			plain(PC.EnergyLeakPauseThreshold),
			PC.EnergyLeakPauseDuration),
		risk = "high",
	},
	HexMutationWild = {
		displayName = "Wild Hex",
		cardType = "Hex Mutation",
		description = string.format(
			"The chosen hex grants %s output, but every %ds there is a %s chance the building stalls for %ds.",
			bonus(C.HexMutationWild.ProductivityBonus),
			C.HexMutationWild.FailCheckInterval,
			plain(C.HexMutationWild.FailChance),
			C.HexMutationWild.FailDuration),
		risk = "medium",
	},
	HexMutationStable = {
		displayName = "Stable Hex",
		cardType = "Hex Mutation",
		description = string.format(
			"The chosen hex grants %s output and never fails.",
			bonus(C.HexMutationStable.ProductivityBonus)),
		risk = "none",
	},
}

-- Jarjekord, milles kaardid UI-s kuvatakse
CardInfo.DisplayOrder = {
	"Overclock",
	"ResourceBloom",
	"FluxTide",
	"NullSurge",
	"MirrorWorld",
	"EnergyLeak",
	"FracturePact",
	"BlessedHex",
	"HexMutationWild",
	"HexMutationStable",
}

function CardInfo.Get(cardName)
	return CardInfo.Cards[cardName]
end

function CardInfo.GetDisplayName(cardName)
	local info = CardInfo.Cards[cardName]
	return info and info.displayName or cardName
end

-- Kas kaart on mangijale avatud. JAGATUD: server valideerib sellega
-- aktiveerimist ja ostu, klient naitab lukke - uks allikas molemale.
-- profile = SaveService'i andmetabel (kliendis payload.profile), voib olla nil.
function CardInfo.IsUnlocked(profile, cardName)
	for _, name in ipairs(Constants.Meta.StartingCards) do
		if name == cardName then
			return true
		end
	end
	if profile and type(profile.unlockedCards) == "table" then
		for _, name in ipairs(profile.unlockedCards) do
			if name == cardName then
				return true
			end
		end
	end
	return false
end

return CardInfo
