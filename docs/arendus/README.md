---
tüüp: arenduse-indeks
seis: 2026-09-24
---

# Hexagoniumi arendus

Arenduse kaart graafi-dashboardi jaoks (Understand-Anything). Iga fail siin
on üks sõlm ja viitab koodifailidele, mida ta puudutab, nii et graafis on
näha, milline otsus, test või kontroll millist koodi mõjutab.

**See kaust EI OLE allikas.** Tõde elab:

- kood: `src/`
- spec ja otsuste täispõhjendused: [Peadokument](../HEXAGONIUM_Peadokument.txt)
- balansi arvud ja testitulemused: [TASAKAALUSTAMINE.md](../TASAKAALUSTAMINE.md)
- ülesanded: [todo.md](../../tasks/todo.md), plaan: [plan.md](../../tasks/plan.md)

Siin on lühikokkuvõtted ja viited. Kui kood või allikas muutub, uuenda ka
vastav fail siin.

## Seis

**Faas:** SAMM 9 Play-test (Faas 3) → järgmine piiratud beta (Faas 4).

| Ala | Seis | Fail |
|---|---|---|
| Tee beetani | Kontrollpunkt C → Faas 4 (avaldamiseelne kontroll) | [roadmap.md](roadmap.md) |
| Play-testid | A, B (+7c), C, 7h tehtud (26.09) | [playtestid.md](playtestid.md) |
| Juhendi kontrollid | 4 OK, 2 osaliselt, 1 tegemata | [kontrollid.md](kontrollid.md) |
| Otsused | 10 kirjet | [otsused/](otsused/) |

## Avaldamise blokeerijad


- CardSystemTest pole pärast viimaseid muudatusi jooksnud → [CardSystemTest.server.lua](../../src/server/CardSystemTest.server.lua)

## Lahtised otsused

- Seemnete püsimine üle Play-sessioonide kontrollimata (`WipeSaveOnJoin` oli testis sees) → [SaveService.lua](../../src/server/Core/SaveService.lua)
- Pärast kristalli (12/min) ja hindade (+15%) muutust: kas teine tootmisahel ja Defender 40 on õigel ajal jõukohased → [Constants.lua](../../src/shared/Constants.lua)

## Otsused

- [ADR-001 Meta-progressioon on ostetav (Hex Seeds)](otsused/ADR-001-hex-seeds.md)
- [ADR-002 Kaardid on lukus](otsused/ADR-002-kaardilukud.md)
- [ADR-003 Algsaar alati raadius 3](otsused/ADR-003-fikseeritud-algsaar.md)
- [ADR-004 Laienduse hind x1.75, tasu 0](otsused/ADR-004-laienduse-hind.md)
- [ADR-005 Telemeetria AnalyticsService'iga](otsused/ADR-005-telemeetria.md)
- [ADR-006 Ostude salvestus koondatakse (SaveSoon)](otsused/ADR-006-savesoon.md)
- [ADR-007 Tutorial 9 sammu, Demand ootab](otsused/ADR-007-tutorial.md)
- [ADR-008 Valgustus ainult koodist](otsused/ADR-008-valgustus.md)
- [ADR-009 Hoone voog kontekstimenüüs](otsused/ADR-009-hoone-voog.md)
- [ADR-010 Kordaja = läbilaskevõime, Town Hall](otsused/ADR-010-labilaskevoime-town-hall.md)
