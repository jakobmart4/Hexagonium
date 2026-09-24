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

## B — pikk kokkuhoidev run · pooleli (16.09, 1 run)

- 8 min, Extract, tasu 558, 1 rünnak, laiendused minutil 4 ja 5, **0 seemet**.
- Leid: tasuta Overclock tegi majanduse liiga lihtsaks → lukku
  ([ADR-002](otsused/ADR-002-kaardilukud.md)).
- Leid: ühendusi ei saa optimeerida ilma kiiruste ja puhvriteta →
  [ADR-009](otsused/ADR-009-hoone-voog.md).
- Järgmine: kordus ilma Overclockita.
- Kood: [PlayerActionHandler.lua](../../src/server/Core/PlayerActionHandler.lua)
  (IslandExpanded minut), [Constants.lua](../../src/shared/Constants.lua)

## C — meta-tsükkel · tegemata

- 2–3 run'i: seemned → lisakoht + kaart. Vajab `WipeSaveOnJoin = false`.
- Sõltub seemnete otsusest ([README](README.md) lahtised otsused).
- Kood: [SaveService.lua](../../src/server/Core/SaveService.lua),
  [StartScreen.client.lua](../../src/client/StartScreen.client.lua)
