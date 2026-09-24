---
tüüp: ADR
number: 3
staatus: kehtib
kuupäev: 2026-09-15
commit: ce5099e, 3e52bc7
---

# ADR-003: Algsaar on alati raadius 3

**Otsus:** iga run algab raadiusega 3. Ostud ei suurenda algsaart, vaid
annavad lisalaienduskohti (`bonusExpansions`, kuni 4). Algbaasi maagiahel
paigutatakse Defenderi lähedale.

**Miks:** suurem algsaar hajutas algbaasi Defenderist kaugele ja rikkus
~40% mängudest (simulatsioon 37–53% → 0–0,7%).

**Täispõhjendus:** [Peadokument](../../HEXAGONIUM_Peadokument.txt) §14.13

**Kood:**
[Constants.lua](../../../src/shared/Constants.lua) (`IslandExpansion`),
[IslandManager.lua](../../../src/server/Core/IslandManager.lua),
[MapGenerator.lua](../../../src/server/Core/MapGenerator.lua) (`PlaceDemoBase`),
[SaveService.lua](../../../src/server/Core/SaveService.lua) (migratsioon `metaRadius` → `bonusExpansions`)
