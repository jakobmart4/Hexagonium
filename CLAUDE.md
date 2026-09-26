# Hexagonium

Run-põhine tycoon Roblox'is: hex-ruudustik saarel, Reality Cards
reeglimuutmise süsteem, run-süsteem meta-progressiooniga.

Place: `Hexagonium` (placeId 104026897810299)

**Täielik spec, seisund ja roadmap: `docs/HEXAGONIUM_Peadokument.txt`**

**Kvaliteedilävend: `CONSTRAINTS.md`** — loe enne koodi kirjutamist, ära nõrgenda seda muudatuse läbisaamiseks. Kontroll: `bash scripts/check.sh`.
Loe see enne suuremate muudatuste tegemist. Allikas on alati KOOD;
dokument selgitab, *miks* kood on selline.

---

## Arhitektuuri põhimõtted

**Üks allikas iga asja kohta.** Kui midagi on kahes kohas, on see viga:
- `shared/Constants.lua` — kõik balance-arvud + Debug-lipud
- `shared/Theme.lua` — värvid, fondid, mõõdud, hotkeyd, valuuta ühik
- `shared/BuildingInfo.lua` — ressursiühilduvus (server JA klient)
- `shared/CardInfo.lua` / `BuildingInfo.lua` — kirjeldused GENEREERITAKSE
  Constants'ist, mitte kirjutatud käsitsi
- `core/MapGenerator.lua` — kogu maailma genereerimine
- `buildings/BuildingFactory.lua` — hoonete loomine
- `resources/ResourceLedger.lua` / `PointBank.lua` — ressursid ja valuuta

**Klient ei ole usaldusväärne.** Klient teeb eelkontrolli ainult kohese
tagasiside jaoks (roheline/punane esiletõstmine). Server valideerib iga
päringu uuesti. `PlayerActionHandler` leiab maailma **mängijast**, mitte
päringust — nii ei saa keegi teise saarel tegutseda.

**Visuaal on loogikast lahutatud.** Hoone = `Model` + `PrimaryPart` +
atribuudid (`Q`, `R`, `BuildingType`). Mudelite vahetamine puudutab
ainult `MapGenerator`-it.

**Hooned ei tunne kaarte.** `CardManager` seab hoonetele lipud
(multiplikaatorid, `ignoreInputs`). Kaardid ei tunne üksteist — nad
küsivad `CardManager`-ilt.

**Maailmad on isoleeritud.** Kuni 6 saart ühes serveris, igaüks oma
`Workspace.Islands.Island_<userId>` kaustas ja oma nihkega.
`world.owners` on list — co-op tähendab mängija lisamist olemasolevasse
maailma, mitte uut arhitektuuri.

---

## Konventsioonid

- **Mängijale nähtav tekst on inglise keeles.** Kood, kommentaarid ja
  konsoolilogid võivad olla eesti keeles või segakeelsed, täpitähtedega.
- **Loe fail enne muutmist.** Ära rekonstrueeri vana teksti mälu järgi —
  see on murdnud otsi-asenda operatsioone korduvalt.
- **Ära mine alla `TextSize` 12.** Väiksemal suurusel surutakse glüüfid
  kokku ja sõnad jooksevad üksteise sisse.
- **Testi iga tüki järel:** Play → konsool → vaata → Stop.

---

## Roblox'i lõksud (kõik päris, kõik maksid aega)

1. **ModuleScript'id on Edit-režiimis vahemälustatud.** Uue koodi
   testimiseks klooni moodul või testi Play-režiimis.
2. **`screen_capture` ei renderda `BillboardGui` ega `Beam` elemente.**
   Kontrolli neid programmaatiliselt.
3. **`_G` ei jagune plugina ja mängu serveri vahel.** Silumine peab
   toimuma mängu seest (`Constants.Debug` lipud).
4. **`StarterGui` kopeeritakse `PlayerGui`-sse alles karakteri
   tekkimisel.** Kuna `CharacterAutoLoads = false`, elavad UI-skriptid
   `StarterPlayerScripts`-is.
5. **`StreamingEnabled` vajab replikatsiooni fookuspunkti.** Ilma
   karakterita see puudub ja maailm ei jõua kliendini. Streaming on
   välja lülitatud.
6. **`input.Delta` on NULL, kui hiir pole lukustatud.** Lohistamise
   tuvastus peab kasutama `GetMouseLocation()` absoluutset positsiooni.
7. **`GetMouseLocation` ja `AbsolutePosition` mõõdavad eri
   nullpunktist** (~36px topbar inset). Kasuta
   `GuiService:GetGuiInset()`.
8. **Ilma karakterita märgib Roblox paremklõpsu `gameProcessed`-iks.**
   Käsitlejad lasevad paremklõpsu läbi, aga kontrollivad
   `GetGuiObjectsAtPosition` abil, kas kursor on paneeli peal.
9. **Karakteri peitmine läbipaistvusega ei tööta** — Roblox lähtestab
   selle suumimisel. Lahendus: `Players.CharacterAutoLoads = false`.
10. **`Players.MaxPlayers` on skriptist kirjutuskaitstud** — Game
    Settings.
11. **MCP `execute_luau` sandbox blokeerib mängu koodi.** `require()`
    mängu moodulitele, `FireServer()` ja ServerStorage'isse parent'imine
    ebaõnnestuvad (Capabilities). Mängija tegevused päris sisendiga
    (`user_mouse_input`/`user_keyboard_input`, eelista `instance_path`'i),
    loogikat kontrolli elavate Instance'ide pealt.
12. **Rojo ei märka nimevahetusega ümber kirjutatud faili** (`sed -i`).
    Kirjuta failid kohapeal ja kontrolli Studios sünkrooni.
13. **Testkonto salvestus püsib.** Constants'i muutus ainult clampib
    olemasolevat salvestust — uue mängija vaade: `WipeSaveOnJoin`.

---

## Silumine

`Constants.Debug` — kõik peavad avaldamisel olema `false` / `0`:

```lua
RunTests         -- CardSystemTest iga Play vajutusega
RunBalanceSim    -- BalanceSimulator iga Play vajutusega
VerboseLogging   -- ressursivoo print
ExposeGameState  -- _G.HexagoniumState
ForceAttackAfter -- käivitab rünnaku N sekundi pärast (0 = väljas, ainult Studios)
WipeSaveOnJoin   -- kustutab salvestuse liitumisel (uue mängija vaade, ainult Studios)
```

`ForceAttackAfter` on ainus viis rünnakusüsteemi testida ilma
150 sekundit ootamata.

**Aja kiirendus (ainult Studios):** Play-s all keskel nupud 2x/3x/5x
(`GameSpeed.client.lua`, aktiivse uus klõps = 1x). Kogu mänguloogika
loeb aega `Core/GameClock.now()`-st, mitte `os.clock()`-ist — uus taimer
peab kasutama sama, muidu ei kiirene see kaasa.

**Testiväärtused pane `src/shared/LocalDebug.lua`-sse, mitte
Constants'i:** `return {WipeSaveOnJoin = true}`. Fail on gitignore'is,
kehtib ainult Studios ja kirjutab `Constants.Debug` üle. Constants'is
jäävad alati avaldamisväärtused.

---

## Studio ühendus

Kood elab failides, aga testimine käib Studios. Hoia Roblox Studio MCP
ühendatud, et saaks Play-testida ja konsooli lugeda ilma aknaid
vahetamata.

Rojo sünkroonib failid Studiosse: `rojo serve`, siis Studio pluginas
"Connect".

**Studio instantsi id vahetub sessioonide vahel** — küsi see iga kord
uuesti.
