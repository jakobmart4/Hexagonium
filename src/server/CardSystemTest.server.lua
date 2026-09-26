local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not require(ReplicatedStorage.Shared.Constants).Debug.RunTests then
	return
end

--[[
	CardSystemTest.lua
	Kontrollib kaardisüsteemi ja EXPLOIT-KAITSE toimimist.
	Käivitub automaatselt play-režiimis pärast GameManager'it.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local CardManager = require(ServerScriptService.Cards.CardManager)
local Overclock = require(ServerScriptService.Cards.CardEffects.Overclock)
local ResourceBloom = require(ServerScriptService.Cards.CardEffects.ResourceBloom)
local NullSurge = require(ServerScriptService.Cards.CardEffects.NullSurge)
local MirrorWorld = require(ServerScriptService.Cards.CardEffects.MirrorWorld)
local HexMutationWild = require(ServerScriptService.Cards.CardEffects.HexMutationWild)
local BlessedHex = require(ServerScriptService.Cards.CardEffects.BlessedHex)

-- Resource Bloomi Extractori kordaja Constants'ist (üks allikas; oli käsitsi 1.25)
local BLOOM = 1 + require(ReplicatedStorage.Shared.Constants).Cards.ResourceBloom.ExtractorBonus

task.wait(2)

print("")
print("=====================================================")
print("  HEXAGONIUM - KAARDISÜSTEEMI TEST")
print("=====================================================")

-- Fake-hoone testimiseks (jäljendab Extractorit hexil 0,0)
local function makeFakeBuilding(buildingType, q, r)
	return {
		buildingType = buildingType,
		q = q,
		r = r,
		isDestroyed = false,
		activeMultipliers = {production = 1.0, defense = 1.0},
		SetProductionMultiplier = function(self, v) self.activeMultipliers.production = v end,
		SetDefenseMultiplier = function(self, v) self.activeMultipliers.defense = v end,
		Pause = function(self, d) self.pausedFor = d end,
	}
end

local cm = CardManager.new()
local extractor = makeFakeBuilding("Extractor", 0, 0)
local ctx = {buildings = {extractor}, cardManager = cm}

local function report(label, expected)
	local m = cm:ComputeProductionMultiplier(extractor, ctx)
	local status = ""
	if expected then
		status = (math.abs(m - expected) < 0.01) and "  [OK]" or string.format("  [OODATI %.3f]", expected)
	end
	print(string.format("%-52s %.3fx%s", label, m, status))
	return m
end

print("")
print("--- 1. Üksikud kaardid ---")
report("Ilma kaartideta", 1.0)

cm:ActivateCard(Overclock.new(), ctx)
report("Overclock", 2.5)

cm:ActivateCard(ResourceBloom.new(), ctx)
report("Overclock + ResourceBloom", 2.5 * BLOOM)

cm:ActivateCard(HexMutationWild.new(0, 0), ctx)
report("+ HexMutationWild (sama hex)", 2.5 * BLOOM * 1.20)

print("")
print("--- 2. EXPLOIT-KAITSE: Null Surge + Overclock ---")
local ns = NullSurge.new()
cm:ActivateCard(ns, ctx)

ns.phase = "idle"
report("NullSurge idle (Overclock kehtib)", 2.5 * BLOOM * 1.20)

ns.phase = "effect"
local effectMult = report("NullSurge EFFECT (Overclock välistatud)", 3.0 * BLOOM * 1.20)
print(string.format("    -> ilma kaitseta oleks: %.2fx", 3.0 * 2.5 * BLOOM * 1.20))
print(string.format("    -> kaitse säästis: %.2fx", (3.0 * 2.5 * BLOOM * 1.20) - effectMult))

ns.phase = "lag"
report("NullSurge LAG (tootmine peatub)", 0)

ns.phase = "idle"

print("")
print("--- 3. Mirror World pöörab biome-efektid ümber ---")
cm:ActivateCard(MirrorWorld.new(), ctx)
report("+ MirrorWorld (Wild 1.20 -> 1.10, global 0.9)", 2.5 * BLOOM * 1.10 * 0.9)

print("")
print("--- 4. Hex-scope: kaart ei mõjuta teisi hexe ---")
local otherHex = makeFakeBuilding("Extractor", 5, 5)
local mOther = cm:ComputeProductionMultiplier(otherHex, ctx)
print(string.format("%-52s %.3fx  %s", "Hoone hexil (5,5) - Wild ei kehti", mOther,
	(math.abs(mOther - (2.5 * BLOOM * 0.9)) < 0.01) and "[OK]" or "[VIGA]"))

print("")
print("--- 5. BuildingType-scope: PowerCore ei saa Bloomi ---")
local pc = makeFakeBuilding("PowerCore", 1, 1)
local mPc = cm:ComputeProductionMultiplier(pc, ctx)
print(string.format("%-52s %.3fx  %s", "PowerCore (ainult Overclock + Mirror)", mPc,
	(math.abs(mPc - (2.5 * 0.9)) < 0.01) and "[OK]" or "[VIGA]"))

print("")
print("--- 6. CardRegistry: koik 10 kaarti loodavad nime jargi ---")
local CardRegistry = require(ServerScriptService.Cards.CardRegistry)
local names = CardRegistry.GetAllCardNames()
print("Registreeritud kaarte: " .. #names)
local allOk = true
for _, name in ipairs(names) do
	local card
	if CardRegistry.NeedsHex(name) then
		card = CardRegistry.Create(name, 0, 0)
	else
		card = CardRegistry.Create(name)
	end
	if not card then
		print("  [VIGA] " .. name)
		allOk = false
	end
end
print(allOk and "  [OK] Koik 10 kaarti loodavad" or "  [VIGA]")

print("")
print("--- 7. EXPLOIT: Stable Hex EI kaitse Overclocki eest ---")
local cm2 = CardManager.new()
local b2 = makeFakeBuilding("Extractor", 0, 0)
local ctx2 = {buildings = {b2}, cardManager = cm2}

local HexMutationStable = require(ServerScriptService.Cards.CardEffects.HexMutationStable)
cm2:ActivateCard(HexMutationStable.new(0, 0), ctx2)
cm2:ActivateCard(HexMutationWild.new(0, 0), ctx2)

local stablePrevents = cm2:HexPreventsFailures(0, 0)
print(string.format("%-52s %s", "Stable Hex valdib Wild Hexi rikkeid",
	stablePrevents and "jah  [OK]" or "ei  [VIGA]"))
print("  MARKUS: Overclocki ulekuumenemine EI ole kaitstud (teadlik otsus)")

print("")
print("--- 8. Null Surge ignoreerib sisendressursse ---")
local cm3 = CardManager.new()
local ns3 = NullSurge.new()
local b3 = makeFakeBuilding("Refinery", 2, 2)
b3.SetIgnoreInputs = function(self, v) self.ignoreInputs = v end
local ctx3 = {buildings = {b3}, cardManager = cm3}
cm3:ActivateCard(ns3, ctx3)

ns3.phase = "idle"
cm3:Tick({b3}, ctx3)
local idleIgnore = b3.ignoreInputs

ns3.phase = "effect"
cm3:Tick({b3}, ctx3)
local effectIgnore = b3.ignoreInputs

print(string.format("%-52s %s", "idle-faasis sisendid vajalikud",
	(idleIgnore == false) and "jah  [OK]" or "ei  [VIGA]"))
print(string.format("%-52s %s", "effect-faasis sisendid ignoreeritud",
	(effectIgnore == true) and "jah  [OK]" or "ei  [VIGA]"))

print("")
print("--- 9. Flux Tide mojutab PowerCore energiatootmist ---")
local PowerCoreMod = require(ServerScriptService.Buildings.PowerCore)
local FluxTide = require(ServerScriptService.Cards.CardEffects.FluxTide)

local pc9 = PowerCoreMod.new(0, 0)
local ft = FluxTide.new()
ft.isActive = true

local function measureEnergy(phase)
	ft.phase = phase
	pc9:SetProductionMultiplier(ft:GetProductionModifier(pc9, {}))
	pc9.currentEnergy = 0
	pc9:TryAccept(1)
	return pc9.currentEnergy
end

local normalEnergy = measureEnergy("normal")
local bonusEnergy = measureEnergy("bonus")
local penaltyEnergy = measureEnergy("penalty")

print(string.format("1 crystal -> normal:  %.0f energiat", normalEnergy))
print(string.format("1 crystal -> bonus:   %.0f energiat  %s", bonusEnergy,
	(bonusEnergy > normalEnergy) and "[OK]" or "[VIGA]"))
print(string.format("1 crystal -> penalty: %.0f energiat  %s", penaltyEnergy,
	(penaltyEnergy < normalEnergy) and "[OK]" or "[VIGA]"))

print("")
print("=====================================================")
print("  Test loppenud")
print("=====================================================")
print("")
