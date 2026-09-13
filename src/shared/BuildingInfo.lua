--[[
	BuildingInfo.lua
	Mangijale nahtav info hoonete kohta - INGLISE KEELES.

	Nagu CardInfo: numbrid GENEREERITAKSE Constants.lua'st, et UI
	ei saaks balansi muutmisel mangijale valetama hakata.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)

local B = Constants.Buildings
local ISL = Constants.IslandExpansion
local RT = Constants.ResourceTypes

local BuildingInfo = {}

-- ============================================================
-- RESSURSIUHILDUVUS
-- UKS ALLIKAS nii serverile kui kliendile. Varem oli see teadmine
-- kolmes kohas (NodeSystem, BuildMenu, NodeLinks) ja oleks ajapikku
-- lahku lainud.
--
-- Extractor on eriline: tema valjund soltub hexist, seega "Variable".
-- Tegelik ressurss kusitakse hoonelt endalt (GetResourceType).
-- ============================================================

BuildingInfo.VARIABLE = "Variable"

local OUTPUTS = {
	Extractor = BuildingInfo.VARIABLE,
	Refinery  = RT.ALLOY,
}

local ACCEPTS = {
	PowerCore = RT.CRYSTAL,
	Refinery  = RT.ORE,
	Assembler = RT.ALLOY,
	-- Defender saab energiat OTSE Power Core'ist, mitte node'i kaudu
}

function BuildingInfo.GetOutput(buildingType)
	return OUTPUTS[buildingType]
end

function BuildingInfo.GetAccepts(buildingType)
	return ACCEPTS[buildingType]
end

function BuildingInfo.CanOutput(buildingType)
	return OUTPUTS[buildingType] ~= nil
end

function BuildingInfo.CanAccept(buildingType)
	return ACCEPTS[buildingType] ~= nil
end

BuildingInfo.Buildings = {
	Extractor = {
		displayName = "Extractor",
		tagline = "Mines the hex it stands on",
		description = string.format(
			"Produces %d ore per %ds on an ore hex, or %d crystal per %ds on a crystal hex. Must be placed on a resource hex.",
			B.Extractor.OreProductionRate, B.Extractor.OreProductionInterval,
			B.Extractor.CrystalProductionRate, B.Extractor.CrystalProductionInterval),
		requiresResourceHex = true,
	},
	PowerCore = {
		displayName = "Power Core",
		tagline = "Turns crystal into energy",
		description = string.format(
			"Stores up to %d energy and converts each crystal into %d. Defenders draw from it directly.",
			B.PowerCore.MaxEnergyStorage, B.PowerCore.EnergyPerCrystal),
		requiresResourceHex = false,
	},
	Refinery = {
		displayName = "Refinery",
		tagline = "Ore into alloy",
		description = string.format(
			"Consumes ore and outputs alloy every %ds. Connect an extractor to its input.",
			B.Refinery.OreToAlloyInterval),
		requiresResourceHex = false,
	},
	Assembler = {
		displayName = "Assembler",
		tagline = "Alloy into upgrade points (UP)",
		description = string.format(
			"Consumes alloy every %ds and produces UP, the currency for buildings and land. The first land reclaim costs %d UP.",
			B.Assembler.AlloyConsumptionInterval, ISL.RunExpansionBaseCost),
		requiresResourceHex = false,
	},
	Defender = {
		displayName = "Defender",
		tagline = "Automated defence turret",
		description = string.format(
			"Covers %d hexes and fires once per %ds when attacked. Draws %d energy every %ds and stops if the Power Core goes down.",
			B.Defender.DefenseRadius, B.Defender.FireInterval,
			B.Defender.EnergyCostPerTick, B.Defender.EnergyCostInterval),
		requiresResourceHex = false,
	},
}

-- Jarjekord ehitusmenuus: tootmisahela loogikas
BuildingInfo.DisplayOrder = {
	"Extractor",
	"PowerCore",
	"Refinery",
	"Assembler",
	"Defender",
}

function BuildingInfo.Get(buildingType)
	return BuildingInfo.Buildings[buildingType]
end

function BuildingInfo.GetDisplayName(buildingType)
	local info = BuildingInfo.Buildings[buildingType]
	return info and info.displayName or buildingType
end

return BuildingInfo
