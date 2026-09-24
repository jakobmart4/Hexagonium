---
tüüp: roadmap
seis: 2026-09-24
allikas: tasks/todo.md, tasks/plan.md
---

# Tee beetani

Allikas on [todo.md](../../tasks/todo.md) ja [plan.md](../../tasks/plan.md).
Mobiilitugi, "kinnita jätkamine" ja co-op on teadlikult pärast avaldamist.

## Tehtud

- **SAMM 1–8** (13.–14.09): põhimäng, run'id, tutorial, balansiraamistik,
  visuaal. Vt [Peadokument](../HEXAGONIUM_Peadokument.txt) §15.
- **Meta-progressioon** (15.09): [ADR-001](otsused/ADR-001-hex-seeds.md),
  [ADR-002](otsused/ADR-002-kaardilukud.md),
  [ADR-003](otsused/ADR-003-fikseeritud-algsaar.md),
  [ADR-004](otsused/ADR-004-laienduse-hind.md).
- **Beeta-eelsed parandused + telemeetria** (15.09):
  [ADR-005](otsused/ADR-005-telemeetria.md), [ADR-006](otsused/ADR-006-savesoon.md).
- **Tutoriali ümbertegemine** (16.09, todo 7a): [ADR-007](otsused/ADR-007-tutorial.md).

## Pooleli — Faas 3, SAMM 9 Play-test

- Stsenaariumid A/B/C → [playtestid.md](playtestid.md)
- Kontrollpunkt C: kangide otsused
  [TASAKAALUSTAMINE.md](../TASAKAALUSTAMINE.md) punktis 4.

## Ees — Faas 4, piiratud beta

1. Avaldamiseelne kontroll: Debug-lipud
   ([Constants.lua](../../src/shared/Constants.lua)), CardSystemTest,
   2 mängijaga kohalik server, juhendi kontrollid ([kontrollid.md](kontrollid.md)).
2. Avaldamine piiratud betana (kasutaja) + tagasivõtuplaan.
3. Järelkontroll ≤ 24 h: salvestus live's, Error Report, Analytics
   ([Telemetry.lua](../../src/server/Core/Telemetry.lua)).
