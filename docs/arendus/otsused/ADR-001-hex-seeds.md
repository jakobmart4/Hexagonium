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

**Muudatus 24.09:** iga run, mis ei lõppenud baasi hävinguga, annab vähemalt `Meta.MinSeedsPerRun` (1) seemne — 8-minutiline run andis 0 ([playtestid.md](../playtestid.md) B). Määr 600 vaadatakse üle pärast 7c-d.

**Muudatus 26.09 (Play-test C):** määr 600 → 400 ja miinimumseeme ainult run'ile, mis kestis ≥ 5 min (`Meta.MinSeedsRunSeconds`) — muidu oli Extract 1. minutil kõige tulusam. Hiljem samal päeval (ülevaatus): miinimum ainult **uuele mängijale** (0 seemet, midagi ostmata), sest 5-min AFK-Extract andis ikka rohkem seemneid tunnis kui päris mäng.

**Täispõhjendus:** [Peadokument](../../HEXAGONIUM_Peadokument.txt) §14.11

**Kood:**
[Constants.lua](../../../src/shared/Constants.lua) (`Constants.Meta`),
[SaveService.lua](../../../src/server/Core/SaveService.lua) (`AddSeeds`, `SpendSeeds`),
[PlayerActionHandler.lua](../../../src/server/Core/PlayerActionHandler.lua) (`HandleBuyMetaUpgrade`),
[Bootstrap.server.lua](../../../src/server/Bootstrap.server.lua) (`wireRunEnd`),
[StartScreen.client.lua](../../../src/client/StartScreen.client.lua)
