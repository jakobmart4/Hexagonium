---
tüüp: ADR
number: 9
staatus: kehtib
kuupäev: 2026-09-16
commit: 788c81e
---

# ADR-009: Hoone voog ja puhvrid kontekstimenüüs

**Otsus:** paremklõpsu menüü näitab reaalajas olekut (Waiting for input,
Input piling up, No input/output link, No Power Core), tootmist ja tarbimist
minutis ning puhvrite sisu. Kiirused genereeritakse Constants'ist
(`BuildingInfo.GetFlow`), puhvrid saadab server.

**Miks:** Play-test B — ühendusi ei saanud optimeerida, kui puhvrite suurust
ja tootmiskiirust polnud näha. Menüü näitas kohe, et algbaasi maak on
5× ülepakkumises.

**Kood:**
[ContextMenu.client.lua](../../../src/client/ContextMenu.client.lua),
[BuildingInfo.lua](../../../src/shared/BuildingInfo.lua) (`GetFlow`),
[StateBroadcaster.lua](../../../src/server/Core/StateBroadcaster.lua) (`CollectBuildings`)
