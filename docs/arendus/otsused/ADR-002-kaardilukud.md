---
tüüp: ADR
number: 2
staatus: kehtib
kuupäev: 2026-09-15
muudetud: 2026-09-16
commit: b36ebae, 788c81e
---

# ADR-002: Kaardid on lukus

**Otsus:** uus mängija alustab 3 kaardiga (Resource Bloom, Blessed Hex,
Stable Hex), ülejäänud 7 avatakse Hex Seeds'iga (`Meta.CardUnlockCost`).
Server kontrollib lukku aktiveerimisel ja ostul.

**Muudatus 16.09:** Overclock (x2.5) eemaldati algkomplektist — tasuta 0.
minutist tegi see majanduse liiga lihtsaks ([playtestid.md](../playtestid.md) B).

**Miks:** seemnetele teine kulutuskoht, mis muudab mängu ennast, mitte
ainult numbrit.

**Täispõhjendus:** [Peadokument](../../HEXAGONIUM_Peadokument.txt) §14.12

**Kood:**
[Constants.lua](../../../src/shared/Constants.lua) (`Meta.StartingCards`),
[CardInfo.lua](../../../src/shared/CardInfo.lua) (`IsUnlocked`),
[PlayerActionHandler.lua](../../../src/server/Core/PlayerActionHandler.lua) (`HandleActivateCard`),
[CardDeck.client.lua](../../../src/client/CardDeck.client.lua),
[StartScreen.client.lua](../../../src/client/StartScreen.client.lua)
