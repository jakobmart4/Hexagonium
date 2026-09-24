---
tüüp: ADR
number: 10
staatus: kehtib
kuupäev: 2026-09-24
---

# ADR-010: Kordaja on läbilaskevõime; Power Core on uuendatav Town Hall

**Otsus 1:** tootmiskordaja (kaardid, Town Hall) tõstab Refinery ja
Assembleri tarbimist JA tootmist võrdselt. Resource Bloom annab kõigile
kolmele ahela lülile ühtlaselt +15 %.

**Miks:** 1:1:1 ahelas (ADR/7e) lõid erinevad kordajad ja ainult väljundit
tõstev kordaja ahela sassi — maak ja alloy kuhjusid uuesti.

**Otsus 2:** Power Core'i saab run'is uuendada tasemeteni 2 ja 3 (UP +
kristall). Tase annab kõigile hoonetele ühtlase tootmisboonuse ja suurema
energiavaru. Mitme Power Core'i korral loeb kõrgeim tase; hävinguga kaob.

**Miks:** tasuta kristalli-Extractor toodab üle; ülejääk saab kasutuse ja
Power Core'ist saab kaitsmist vääriv "Town Hall".

**Otsus 3 (hiljem 24.09):** Power Core on baasi tuum ja paranduspunkt: hooned
tervenevad ainult selle raadiuses (kasvab tasemega). Hävimine ei lõpeta run'i,
vaid võtab boonuse ja parandamise, kuni ehitad uue Power Core'i.

**Numbrid:** [TASAKAALUSTAMINE.md](../../TASAKAALUSTAMINE.md) punkt 1.

**Kood:**
[Refinery.lua](../../../src/server/Buildings/Refinery.lua),
[Assembler.lua](../../../src/server/Buildings/Assembler.lua),
[PowerCore.lua](../../../src/server/Buildings/PowerCore.lua) (`Upgrade`),
[TickService.lua](../../../src/server/Core/TickService.lua) (`_getTownHallBonus`),
[PlayerActionHandler.lua](../../../src/server/Core/PlayerActionHandler.lua) (`HandleUpgradeBuilding`),
[ContextMenu.client.lua](../../../src/client/ContextMenu.client.lua),
[Constants.lua](../../../src/shared/Constants.lua) (`PowerCore.TownHall`, `Cards.ResourceBloom`)