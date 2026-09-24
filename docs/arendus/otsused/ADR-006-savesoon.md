---
tüüp: ADR
number: 6
staatus: kehtib
kuupäev: 2026-09-15
commit: 5057b11, 6d76127
---

# ADR-006: Ostude salvestus koondatakse (SaveSoon)

**Otsus:** Hex Seeds ostud ja tutoriali edenemine kutsuvad
`SaveService.SaveSoon` — üks sunnitud kirjutus 7 s pärast esimest muudatust.

**Miks:** DataStore lubab sama võtit kirjutada ~1× 6 s jooksul; iga ostu
järel sunnitud kirjutus ummistaks järjekorra. Ainult autosave'ile (120 s)
jätmine kaotaks Studios ostud. Sunnitud, sest paralleelne run'i lõpu
salvestus võis dirty-lipu vahepeal puhastada.

**Kood:**
[SaveService.lua](../../../src/server/Core/SaveService.lua) (`SaveSoon`),
[PlayerActionHandler.lua](../../../src/server/Core/PlayerActionHandler.lua),
[Bootstrap.server.lua](../../../src/server/Bootstrap.server.lua)
