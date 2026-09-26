---
tüüp: play-testid
seis: 2026-09-24
allikas: docs/TASAKAALUSTAMINE.md punkt 3
---

# Play-testid (SAMM 9)

Mängib kasutaja Studios, Claude loeb konsooli (`RUN LOPPES`, `[Telemetry]`).
Täistulemused: [TASAKAALUSTAMINE.md](../TASAKAALUSTAMINE.md) punkt 3.

## A — uus mängija · tehtud (16.09)

- Leid: tutorial arvas, et Extractor pandi alati kristallile; tutorial oli
  lühike. → [ADR-007](otsused/ADR-007-tutorial.md)
- Kordus: "muud asjad on nüüd head", esimene Demand oli pikk → 30 s → 10 s.
- Kood: [TutorialTracker.lua](../../src/server/Core/TutorialTracker.lua),
  [Tutorial.client.lua](../../src/client/Tutorial.client.lua),
  [FractureSyndicate.lua](../../src/server/Factions/FractureSyndicate.lua)

## B — pikk kokkuhoidev run · tehtud (16.09 + kordus 24.09)

- 8 min, Extract, tasu 558, 1 rünnak, laiendused minutil 4 ja 5, **0 seemet**.
- Leid: tasuta Overclock tegi majanduse liiga lihtsaks → lukku
  ([ADR-002](otsused/ADR-002-kaardilukud.md)).
- Leid: ühendusi ei saa optimeerida ilma kiiruste ja puhvriteta →
  [ADR-009](otsused/ADR-009-hoone-voog.md).
- Kordus ilma Overclockita (7c, 24.09, kiirendusega): 18,6 min, Extract, tasu 633
  (~34/min), 1 rünnak, laiendused minutil 10 ja 12, **+1 seeme**. Määr 600 annab
  ~1 seemne 18 minuti kohta — otsus Kontrollpunktis C.
- Kood: [PlayerActionHandler.lua](../../src/server/Core/PlayerActionHandler.lua)
  (IslandExpanded minut), [Constants.lua](../../src/shared/Constants.lua)

## C — meta-tsükkel · tehtud ühe Play jooksul (26.09)

- 3 run'i järjest: 20,1 min / 851 tasu / 4 rünnakut / +1 seeme; 8,8 min / 323 /
  +1 (miinimumreegel); ostis Overclocki (2 seemet) ja kasutas järgmises run'is.
- Leid: miinimumseeme tegi lühikese run'i sama tulusaks → ajapiir 5 min, määr
  600 → 400 ([ADR-001](otsused/ADR-001-hex-seeds.md)).
- Leid: DataStore HTTP 500 üks kord (ajutine; autosave kordab).
- Kontrollimata: seemnete püsimine üle Play-sessioonide (`WipeSaveOnJoin` oli sees).
- Kood: [SaveService.lua](../../src/server/Core/SaveService.lua),
  [StartScreen.client.lua](../../src/client/StartScreen.client.lua)
