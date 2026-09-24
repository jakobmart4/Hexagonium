---
tüüp: ADR
number: 7
staatus: kehtib
kuupäev: 2026-09-16
commit: 7dca0e5, 73ca54b
---

# ADR-007: Tutorial on 9 sammu ja Demand ootab sammu 5

**Otsus:** 9 sammu, segatüüp — tegevussammud (server märgib päris tegevuse
järgi) ja infosammud ("Next", server lubab ainult praegusel sammul).
Enne sammu 5 Demand'e ei tule; sammul 5 tuleb nõue 10 s pärast.
Edenemine salvestub (`tutorialStep`) ja jätkub järgmisel sessioonil.

**Miks:** Play-test A — ühenduse samm nõudis Power Core'i (Ore-extractoriga
mängija jäi kinni) ja 4 sammu ei tutvustanud majandust, Demand'i,
laiendust, Extract'i ega meta-süsteemi. Varajane Demand hävitas uue
mängija hooneid enne selgitust.

**Kood:**
[TutorialTracker.lua](../../../src/server/Core/TutorialTracker.lua),
[Tutorial.client.lua](../../../src/client/Tutorial.client.lua),
[FractureSyndicate.lua](../../../src/server/Factions/FractureSyndicate.lua) (`HoldsDemands`, `_demandInterval`),
[PlayerActionHandler.lua](../../../src/server/Core/PlayerActionHandler.lua) (`HandleAdvanceTutorial`),
[SaveService.lua](../../../src/server/Core/SaveService.lua) (`tutorialStep`),
[RemoteEvents.lua](../../../src/shared/RemoteEvents.lua) (`AdvanceTutorial`)
