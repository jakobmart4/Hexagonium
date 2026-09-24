---
tüüp: ADR
number: 5
staatus: kehtib
kuupäev: 2026-09-15
commit: 6d76127, 01e964e
---

# ADR-005: Telemeetria Robloxi AnalyticsService'iga

**Otsus:** üks moodul `Telemetry` (`Event`, `Economy`, `OnboardingStep`).
Studios prinditakse `[Telemetry] {json}`, avaldatud mängus kutsutakse
AnalyticsService'it pcall'i sees. Välju kuni 3, väärtused väikestest hulkadest.

**Mida mõõdetakse:** tutoriali lehter (1 TutorialStarted + 9 sammu),
Hex Seeds source/sink, run'i lõpp (põhjus, kestus, tasu, laiendused, ka Quit),
kaardid, laiendused koos run'i minutiga, tutoriali vahelejätmine.

**Miks:** beeta vajab andmeid, mitte oletusi (nt kas seemneid tuleb piisavalt).

**Kood:**
[Telemetry.lua](../../../src/server/Core/Telemetry.lua),
[Bootstrap.server.lua](../../../src/server/Bootstrap.server.lua),
[PlayerActionHandler.lua](../../../src/server/Core/PlayerActionHandler.lua)
