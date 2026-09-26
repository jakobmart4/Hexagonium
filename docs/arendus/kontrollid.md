---
tüüp: kvaliteedikontrollid
seis: 2026-09-24
allikas: "C:/Skills/Juhendid/Ohutus ja Review.md"
---

# Juhendi kontrollid

Seis juhendi 7 kontrolli järgi. Staatused: **OK**, **osaliselt**,
**puudujääk**, **blokeeritud**, **tegemata**.

## Koodikvaliteet ja turvalisus

### code-review-and-quality · OK (26.09)
Kolm mitmemõõtmelist review'd (telemeetria, tutorial, 8c: `20d94a7^..d7e54a9`
kvaliteet/turvalisus/lihtsustamine/jälgitavus). 8c: 16 leidu, 12 kinnitatud
ja parandatud (nt vale "Waiting for input" 1:1:1 ahelas, AFK-seemned,
Town Hall tase 1 tabelisse), 4 ümber lükatud. CardSystemTest 9/9 OK,
salvestuse püsivus üle Play-sessioonide kontrollitud.

### security-and-hardening · OK (26.09)
Server autoriteetne, remote'id valideerivad tüüpe, Debug-lipud ja aja
kiirendus ainult Studios. Sagedusepiirang kõigile päringutele
([PlayerActionHandler.lua](../../src/server/Core/PlayerActionHandler.lua)
`allowRequest`) ja Right to Erasure
([SaveService.lua](../../src/server/Core/SaveService.lua) `EraseUserData`,
juhend peadokumendi §15-s). Live'is kontrollimata.

### code-simplification · osaliselt (26.09)
8c ülevaatus lihtsustas uue koodi (üks Power Core'ide läbikäik, Town Hall tase 1
tabelis, hex-tüübi topeltteisendus ära). Vana kood (MapGenerator jne) pärast beetat.
Suurimad failid: [MapGenerator.lua](../../src/server/Core/MapGenerator.lua)
(920 rida), [CardDeck.client.lua](../../src/client/CardDeck.client.lua),
[PlayerActionHandler.lua](../../src/server/Core/PlayerActionHandler.lua).
Pärast beetat.

### observability-and-instrumentation · OK
[Telemetry.lua](../../src/server/Core/Telemetry.lua): onboarding-lehter,
Hex Seeds majandus, run'i lõpp, kaardid, laiendused. Live'is kontrollimata.
Vt [ADR-005](otsused/ADR-005-telemeetria.md).

### constraint-driven-development · OK (26.09)
[CONSTRAINTS.md](../../CONSTRAINTS.md): 7 automaatreeglit (`bash scripts/check.sh`, ~5 s)
ja 4 Studio-kontrolli enne avaldamist. Negatiivne test: skript tabas lisatud `os.clock()`-i.

## Arhitektuur ja tehniline võlg

### documentation-and-adrs · osaliselt
Otsused on [Peadokument](../HEXAGONIUM_Peadokument.txt) §14-s ja
kaartidena [otsused/](otsused/) kaustas. Vanad failid on [arhiiv/](../arhiiv/README.md) kaustas.

### engineering:architecture · tegemata
Arhitektuur kirjas `CLAUDE.md`-s (isoleeritud maailmad,
[WorldManager.lua](../../src/server/Core/WorldManager.lua),
[GameManager.lua](../../src/server/Core/GameManager.lua)). Hindamine enne
co-op'i või mobiilituge.
