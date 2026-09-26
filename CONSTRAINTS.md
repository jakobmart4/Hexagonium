# Constraints

Hexagoniumi kvaliteedilävend. Viimati üle vaadatud: 2026-09-26.

Seda faili **ei nõrgendata**, et muudatus läbi läheks. Reegli muutmine käib
eraldi commit'iga koos põhjusega.

## Põhi (alati)

- Ei uusi vaigistusi: `--!nocheck`, `selene: allow`.
- Ei saladusi lähtekoodis (API võtmed, tokenid).
- Testi (`CardSystemTest`) ei kustutata ega jäeta vahele ilma põhjuseta commit'is.
- Testiväärtused ainult `src/shared/LocalDebug.lua`-s (gitignore), mitte Constants'is.
- Mängijale nähtav tekst inglise keeles; numbrid tekstides genereeritakse Constants'ist.

## Automaatselt kontrollitud

Kõik read kontrollib `bash scripts/check.sh` (väljumiskood 0 = OK, ~5 s).

| Mõõde | Reegel | Kontroll | Millal |
|---|---|---|---|
| Avaldamise ohutus | `Constants.Debug` lipud `false`, `ForceAttackAfter = 0` | check.sh #1 | iga commit |
| Avaldamise ohutus | `LocalDebug.lua` pole gitis | check.sh #2 | iga commit |
| Kiirendus | mänguloogika ei kasuta `os.clock()` (ainult `GameClock`, broadcast, sagedusepiirang) | check.sh #3 | iga commit |
| Loetavus | `TextSize` ≥ 12 | check.sh #4 | iga commit |
| Vaigistused/saladused | põhi | check.sh #5 | iga commit |
| Serveri autoriteet | iga klient→server RemoteEvent on `PlayerActionHandler`-is seotud (sagedusepiirang + valideerimine) | check.sh #6 | iga commit |
| Ehitus | `rojo build default.project.json` õnnestub | check.sh #7 | iga commit |

## Studios kontrollitud (käsitsi, enne avaldamist)

| Mõõde | Reegel | Kuidas |
|---|---|---|
| Kaardiloogika | `CardSystemTest` 9/9 `[OK]` | `LocalDebug.lua`: `RunTests = true` → Play → konsool |
| Salvestus | seemned/run'id püsivad üle Play-sessioonide | `WipeSaveOnJoin = false`, Play → Stop → Play |
| Mitu mängijat | 2 mängijat, eraldi saared, konsool puhas | Studio Test → Local Server, 2 mängijat |
| Konsool | Play-s pole punaseid vigu | Play → konsool |
| Serveri suurus | Max Players = 6 (= `MapGenerator.MAX_SLOTS`) | Game Settings → Places → Server Size |

## Mõõdetud, mitte veel jõustatud

| Mõõdik | Täna | Suund |
|---|---|---|
| CardSystemTest | 9/9 OK | ei tohi langeda |
| Luau süntaks/lint | pole tööriista (selene/luau pole paigaldatud) | lisada `selene` rokit'iga, kui vaja |

## Erandid

| ID | Reegel | Koht | Põhjus |
|---|---|---|---|
| E1 | `os.clock()` | `Core/GameClock.lua`, `Core/StateBroadcaster.lua`, `Core/PlayerActionHandler.lua` | päris aeg: kella alus, võrgusagedus, sagedusepiirang (kiirendus ei tohi neid muuta) |
