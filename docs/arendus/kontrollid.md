---
tüüp: kvaliteedikontrollid
seis: 2026-09-24
allikas: "C:/Skills/Juhendid/Ohutus ja Review.md"
---

# Juhendi kontrollid

Seis juhendi 7 kontrolli järgi. Staatused: **OK**, **osaliselt**,
**puudujääk**, **blokeeritud**, **tegemata**.

## Koodikvaliteet ja turvalisus

### code-review-and-quality · osaliselt
Kaks mitmemõõtmelist review'd (telemeetria, tutorial), kõik kinnitatud
leiud parandatud. Ülevaatamata: commit'id `20d94a7..788c81e` —
[Environment.lua](../../src/server/Core/Environment.lua),
[ContextMenu.client.lua](../../src/client/ContextMenu.client.lua),
[BuildingInfo.lua](../../src/shared/BuildingInfo.lua),
[StateBroadcaster.lua](../../src/server/Core/StateBroadcaster.lua).

### security-and-hardening · OK (26.09)
Server autoriteetne, remote'id valideerivad tüüpe, Debug-lipud ja aja
kiirendus ainult Studios. Sagedusepiirang kõigile päringutele
([PlayerActionHandler.lua](../../src/server/Core/PlayerActionHandler.lua)
`allowRequest`) ja Right to Erasure
([SaveService.lua](../../src/server/Core/SaveService.lua) `EraseUserData`,
juhend peadokumendi §15-s). Live'is kontrollimata.

### code-simplification · tegemata
Suurimad failid: [MapGenerator.lua](../../src/server/Core/MapGenerator.lua)
(920 rida), [CardDeck.client.lua](../../src/client/CardDeck.client.lua),
[PlayerActionHandler.lua](../../src/server/Core/PlayerActionHandler.lua).
Pärast beetat.

### observability-and-instrumentation · OK
[Telemetry.lua](../../src/server/Core/Telemetry.lua): onboarding-lehter,
Hex Seeds majandus, run'i lõpp, kaardid, laiendused. Live'is kontrollimata.
Vt [ADR-005](otsused/ADR-005-telemeetria.md).

### constraint-driven-development · blokeeritud
`CONSTRAINTS.md` puudub. Reeglid on `CLAUDE.md`-s (TextSize ≥ 12,
mängijale inglise tekst, üks allikas, Debug-lipud väljas).

## Arhitektuur ja tehniline võlg

### documentation-and-adrs · osaliselt
Otsused on [Peadokument](../HEXAGONIUM_Peadokument.txt) §14-s ja
kaartidena [otsused/](otsused/) kaustas. Vanad failid on [arhiiv/](../arhiiv/README.md) kaustas.

### engineering:architecture · tegemata
Arhitektuur kirjas `CLAUDE.md`-s (isoleeritud maailmad,
[WorldManager.lua](../../src/server/Core/WorldManager.lua),
[GameManager.lua](../../src/server/Core/GameManager.lua)). Hindamine enne
co-op'i või mobiilituge.
