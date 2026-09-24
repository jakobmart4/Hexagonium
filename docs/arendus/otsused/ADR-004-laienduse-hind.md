---
tüüp: ADR
number: 4
staatus: kehtib
kuupäev: 2026-09-15
commit: 2c72e56, 4ade46b
---

# ADR-004: Laiendus ei anna tasu, hinnakordaja x1.75

**Otsus:** `RewardPerExpansion = 0` — laiendus on puhas valik "rohkem maad
või rohkem kasumit". Iga järgmine laiendus maksab 1.75× eelmisest.

**Ajalugu:** x3 → x2 → x3 (koos tasu nullimisega) → x1.75 kokkuhoidva
mängija uuringu põhjal (kordajad 1.5–3).

**Täispõhjendus:** [Peadokument](../../HEXAGONIUM_Peadokument.txt) §14.14,
[TASAKAALUSTAMINE.md](../../TASAKAALUSTAMINE.md) punkt 4

**Kood:**
[Constants.lua](../../../src/shared/Constants.lua) (`IslandExpansion.RunExpansionCostMultiplier`),
[IslandManager.lua](../../../src/server/Core/IslandManager.lua) (`TryExpand`),
[BalanceSimulator.server.lua](../../../src/server/BalanceSimulator.server.lua)
