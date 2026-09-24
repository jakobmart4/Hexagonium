---
tüüp: ADR
number: 1
staatus: kehtib
kuupäev: 2026-09-15
commit: 6a6b9b6
---

# ADR-001: Meta-progressioon on ostetav (Hex Seeds)

**Otsus:** run'i tasu muutub seemneteks (1 seeme / `Meta.SeedsPerPayout`
tasu), mängija kulutab need ise start screen'il lisalaienduskohtadele ja
kaartidele.

**Miks:** varem andis run'i lõpp laiendused otse ja korraga — üks pikk run
ammendas kogu meta-progressiooni.

**Lahtine:** 8-minutiline run annab 0 seemet ([playtestid.md](../playtestid.md) B).

**Täispõhjendus:** [Peadokument](../../HEXAGONIUM_Peadokument.txt) §14.11

**Kood:**
[Constants.lua](../../../src/shared/Constants.lua) (`Constants.Meta`),
[SaveService.lua](../../../src/server/Core/SaveService.lua) (`AddSeeds`, `SpendSeeds`),
[PlayerActionHandler.lua](../../../src/server/Core/PlayerActionHandler.lua) (`HandleBuyMetaUpgrade`),
[Bootstrap.server.lua](../../../src/server/Bootstrap.server.lua) (`wireRunEnd`),
[StartScreen.client.lua](../../../src/client/StartScreen.client.lua)
