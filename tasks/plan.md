# Plaan: piiratud beta (SAMM 9 + 10), mobiilitugi pärast avaldamist

## Context

Roadmap (`docs/HEXAGONIUM_Peadokument.txt` §16, v4.5) jõudis punkti, kus
järgmised sammud on **uue majanduse Play-test** ja **avaldamine**.
Kasutaja otsused:
- **Mobiilitugi jääb praegu täiesti kõrvale** — arutatakse pärast
  avaldamist, mitte roadmapi järjekorras.
- **Esimene avaldamine = piiratud beta** (privaatne / sõbrad lingiga).
- **Play-testi teeb kasutaja ise Studios**, enne avaldamist.

Uuringust tulnud faktid, mis kujundavad järjekorra:
- Roblox'i `AnalyticsService` katab telemeetria sisseehitatult
  (onboarding-lehter, majandus, kohandatud sündmused) — omaehitatud
  lahendust pole vaja. **Sündmused lähevad ainult avaldatud mängu
  serverist, mitte Studiost**; armatuurlaud täitub kuni 24 h.
  Max 100 kohandatud sündmuse nime, 3 kohandatud välja
  (`Enum.AnalyticsCustomFieldKeys.CustomField01..03`), väärtused peavad
  olema madala kardinaalsusega. Mitu sündmust kohe liitumisel annab
  Studios "too many events" vea.
- Seetõttu **telemeetria ENNE Play-testi**: Studios kirjutab sama moodul
  sündmused konsooli struktureeritud reana -> kasutaja Play-testist tuleb
  loetav logi, betas lähevad samad sündmused päriselt Roblox'ile.
- Leitud avaldamiseelsed probleemid: Active Cards paneel näitab mängijale
  toorest sisemist teksti (`FluxTide`, `buildingType`); iga Hex Seeds ost
  teeb kohe sunnitud DataStore-kirjutuse (`PlayerActionHandler.lua:439`,
  `:465`) — kiired järjestikused ostud ületavad ~6 s võtmepõhise piirangu.

Meetod: `agent-skills` — `planning-and-task-breakdown` (väikesed
ülesanded, vastuvõtukriteeriumid, kontrollpunktid, `tasks/plan.md` +
`tasks/todo.md`), `observability-and-instrumentation` (küsimused enne
sündmusi), `shipping-and-launch` (avaldamiseelne kontroll, järkjärguline
avaldamine, tagasivõtuplaan) — kohandatud Roblox'ile.

---

## Arhitektuuriotsused

- **Telemeetria = üks server-moodul** `src/server/Core/Telemetry.lua`
  (3+ kutsekohta ja Studio/live erinev käitumine õigustavad ühte kohta).
  Studios (`RunService:IsStudio()`) -> üks rida
  `[Telemetry] {json}` (`HttpService:JSONEncode`); live -> `AnalyticsService`
  `pcall`'i sees (ebaõnnestumine = `warn`, mäng ei katke).
  Eraldi kill-switch'i EI tee: Roblox'is vajab ka lipu muutmine
  uuesti avaldamist, seega lipp ei annaks kiiremat tagasivõttu.
- **Sündmused vastavad küsimustele** (mitte "logi kõike"):
  | Küsimus | Sündmus |
  |---|---|
  | Kus uus mängija tutorialist välja kukub? | `LogOnboardingFunnelStepEvent` sammud 1-4 + `TutorialSkipped` |
  | Kuidas run'id lõpevad ja kui kaua kestavad? | `RunEnded` (väärtus = minutid, väli = lõpu põhjus), `RunPayout` |
  | Kas laiendusi kasutatakse? | `RunExpansions` (väli = ostetud lisakohti 0-4), `IslandExpanded` |
  | Kas meta-majandus on tasakaalus? | `LogEconomyEvent` HexSeeds: Source `Gameplay` / Sink `Shop` (sku `ExpansionSlot`, `Card_<Nimi>`) |
  | Milliseid kaarte kasutatakse? | `CardActivated` (väli = kaardi nimi, 10 väärtust) |
  | Kas live's on vigu? | Creator Dashboard Error Report (sisseehitatud, koodi pole vaja) |
  Kokku ~7 sündmuse nime; ükski väli ei sisalda mängija ID-d. Liitumisel
  sündmusi ei saadeta.
- **Plaan repo's**: `tasks/plan.md` + `tasks/todo.md` (skill'i konventsioon).
  Peadokument §16 viitab neile, ei dubleeri.

---

## Ülesanded

### Faas 0 — Dokumentatsioon

**Ülesanne 1: Mobiilitugi pärast avaldamist + plaanifailid** — XS
- Peadokument: §1 PUUDUB-nimekirjast mobiil välja; §16 SAMM 11 ->
  uus sektsioon "PÄRAST AVALDAMIST (arutada)": mobiilitugi, "kinnita
  jätkamine", co-op. §15 "UI fikseeritud pikslid" -> märge "teadlikult
  pärast avaldamist". Loo `tasks/plan.md` (see plaan) + `tasks/todo.md`
  (ülesannete checklist); §16 viitab neile.
- Vastuvõtt: ükski järjestatud roadmapi samm ei maini mobiili; `tasks/` olemas.
- Kontroll: grep "MOBIIL" peadokumendis — ainult pärast-avaldamist sektsioonis.
- Sõltuvused: puudub. Failid: peadokument, `tasks/plan.md`, `tasks/todo.md`.

### Faas 1 — Mängijale nähtavad parandused (enne Play-testi)

**Ülesanne 2: Active Cards paneel loetavaks** — S
- `StateBroadcaster:CollectCards` saadab lisaks `affects` (kaardi
  `affectedBuildingTypes` võtmed, sorteeritud) — server jääb ainsaks
  allikaks. `HUD.client.lua` (~rida 290-305): nimi
  `CardInfo.GetDisplayName(card.name)`; detail: global -> "All buildings",
  buildingType -> kuvanimed `BuildingInfo`-st komaga, hex -> "Hex (q, r)".
- Vastuvõtt: ühelgi 10 kaardil ei näe mängija sisemist stringi.
- Kontroll: Play; algkomplekt katab kõik 3 scope'i (Overclock global,
  Resource Bloom buildingType, Blessed Hex hex) — aktiveeri, loe HUD
  sildid `execute_luau`'ga. Pärast: dismiss task chip `task_9c6d3ed5`.
- Sõltuvused: puudub. Failid: `StateBroadcaster.lua`, `HUD.client.lua`.

**Ülesanne 3: Serveri kaardiluku kontroll päriselt testitud** — XS
- AINULT Studios (mitte kettal): eemalda ajutiselt CardDeck'i kliendi
  lukukontroll, klõpsa lukus kaarti -> server peab keelduma
  ("is locked"), kaart ei aktiveeru. Taasta Studio source.
- Vastuvõtt: server keeldub; kettal muudatust pole.
- Sõltuvused: puudub. Failid: pole.

**Ülesanne 4: Ostud ei ummista DataStore'i** — XS
- `PlayerActionHandler.lua:439` ja `:465`: sunnitud
  `SaveService.Save(player, true)` -> uus `SaveService.SaveSoon(player)`,
  mis koondab lähestikku ostud ÜHEKS kirjutuseks ~7 s pärast.
  MUUDETUD implementeerimisel: pelgalt eemaldamine oleks jätnud ostud
  Studios salvestamata (BindToClose jätab Studio vahele, autosave 120 s),
  mis rikuks kasutaja Play-testi (Faas 3).
- Vastuvõtt: kiire 6 kaardi ost ei tekita DataStore queue-hoiatust.
- Kontroll: Play, osta mitu kaarti järjest, konsool; Stop/Play -> ostud püsivad.
- Sõltuvused: puudub. Failid: `PlayerActionHandler.lua` (+ peadokument §8).

**Kontrollpunkt A** (1-4): Play smoke, konsool puhas, commit'id, kasutaja vaatab üle.

### Faas 2 — Telemeetria (SAMM 10a)

**Ülesanne 5: Telemetry-moodul + run'i lõpp + majandus** — M
- Uus `src/server/Core/Telemetry.lua` (`Event`, `Economy`,
  `OnboardingStep`; Studio print / live AnalyticsService pcall).
- Konksud: `Bootstrap.wireRunEnd` -> `RunEnded`, `RunPayout`,
  `RunExpansions`, HexSeeds Source; `PlayerActionHandler:HandleBuyMetaUpgrade`
  -> HexSeeds Sink (`ExpansionSlot` / `Card_<Nimi>`).
- Vastuvõtt: iga ülaltoodud küsimus (run'id, laiendused, majandus) saab sündmuse; live-kutse pcall'is.
- Kontroll: Studio Play -> Extract + üks ost -> konsoolis `[Telemetry]`
  read kehtiva JSON'iga, õiged väärtused (võrdle `RUN LOPPES` reaga).
- Sõltuvused: puudub. Failid: `Telemetry.lua` (uus), `Bootstrap.server.lua`, `PlayerActionHandler.lua`.

**Ülesanne 6: Tutoriali lehter + kaardid + laiendused** — S
- `TutorialTracker`: `OnStep(callback)` samas stiilis mis `OnComplete`
  (kutsutakse `_markStep`'is) -> `Bootstrap.wireTutorial` ->
  `OnboardingStep` omanikele. `HandleSkipTutorial` -> `TutorialSkipped`.
  `HandleActivateCard` -> `CardActivated`; `HandleExpandIsland` edu -> `IslandExpanded`.
- Vastuvõtt: kõik 4 tutoriali sammu + skip + kaart + laiendus logivad; liitumisel mitte ühtegi sündmust.
- Kontroll: `WipeSaveOnJoin = true`, Play läbi tutoriali (või skip), aktiveeri kaart, laienda -> konsool; lülita lipp tagasi.
- Sõltuvused: 5. Failid: `TutorialTracker.lua`, `Bootstrap.server.lua`, `PlayerActionHandler.lua`.

**Kontrollpunkt B** (5-6): kõik ~7 sündmust nähtud Studio konsoolis, peadokumenti uus
"Telemeetria" alapunkt (küsimus -> sündmus tabel), commit.

### Faas 3 — SAMM 9: uue majanduse Play-test (kasutaja mängib)

**Ülesanne 7: Play-testi sessioonid** — kasutaja + mina
- Stsenaariumid: (A) uus mängija `WipeSaveOnJoin`'iga läbi tutoriali ja
  esimese run'i Extract'ini; (B) kokkuhoidev pikk run 20-30 min, laiendused;
  (C) meta-tsükkel 2-3 run'i: seemned -> lisakoht + kaart.
- Mina pärast iga sessiooni: loen konsooli (`RUN LOPPES` + `[Telemetry]`),
  kirjutan `TASAKAALUSTAMINE.md` punkti 3 (aeg 1./2. laienduseni, seemned
  run'i kohta, lõpu põhjus/kestus) + kasutaja muljed (kas laiendamine
  tasub, kas seemneid tuleb piisavalt, kas lukus kaardid motiveerivad,
  kas rünnakud on ausad).
- Kangid otsuseks: `RunExpansionCostMultiplier`, `Meta.SeedsPerPayout`,
  `Meta.CardUnlockCost`, `Meta.IslandUpgradeCostPerStep`.
- Vastuvõtt: 3 stsenaariumi logitud; iga kangi kohta otsus (jätta/muuta) punktis 4.
- Sõltuvused: 2, 4, 5, 6.

**Kontrollpunkt C**: tulemused koos üle, tuunimised tehtud, alles siis avaldamine.

### Faas 4 — SAMM 10: piiratud beta

**Ülesanne 8: Avaldamiseelne kontroll** — S
- `Constants.Debug` kõik false/0; `CardSystemTest` ühe korra
  (`RunTests = true` -> Play -> false); kasutaja: Studio Test ->
  kohalik server 2 mängijaga (saared isoleeritud, eraldi slotid, konsool
  puhas); peadokument §15 "ENNE AVALDAMIST" läbi.
- Vastuvõtt: kõik punktid rohelised, kirjas §15.
- Sõltuvused: 7.

**Ülesanne 9: Avaldamine piiratud betana** — kasutaja (välismõjuga tegevus)
- Kasutaja Studios / Creator Dashboard'is: Publish, privaatsus
  privaatne/sõbrad, Max Players 6 (Game Settings — skriptist
  kirjutuskaitstud), vajadusel kogemuse küsimustik.
- **Tagasivõtuplaan** (kirjas peadokumendis): Creator Dashboard ->
  Version History -> eelmine versioon, või `git revert` + uus Publish.
  PIIRANG: salvestuse migratsioon (metaRadius -> bonusExpansions) on
  ühesuunaline — vanem versioon loeks uue salvestuse vaikeväärtustega.
- Sõltuvused: 8.

**Ülesanne 10: Avaldamisjärgne kontroll** — S
- Esimene tund: kasutaja liitub live-mänguga, mängib run'i Extract'ini,
  lahkub, liitub uuesti -> salvestus püsib; Creator Dashboard Error Report
  ilma uute vigadeta. ≤24 h: Analytics näitab `RunEnded`, onboarding-lehtrit,
  HexSeeds majandust.
- Vastuvõtt: kõik kolm andmetüüpi nähtavad; tulemus peadokumendi SAMM 10 alla.
- Sõltuvused: 9.

**Kontrollpunkt D**: beta live, telemeetria voolab -> alles siis arutelu
"PÄRAST AVALDAMIST": mobiilitugi, "kinnita jätkamine", co-op.

---

## Riskid

| Risk | Mõju | Leevendus |
|---|---|---|
| AnalyticsService'i ei saa Studios testida | Keskmine | Studio konsooli peegeldus (sama kood) + live kontroll ülesandes 10 |
| Liigne kardinaalsus / sündmuste arv | Madal | ~7 nime, väljad fikseeritud väikestest hulkadest, ID-sid pole |
| DataStore throttling ostudel | Keskmine | Ülesanne 4 |
| Tagasivõtt pärast salvestuse migratsiooni | Keskmine | Dokumenteeritud; beta on privaatne, mängijaid vähe |
| Play-test on subjektiivne, mudel optimistlik | Keskmine | Konsoolilogi + kirja pandud kangid ja otsused |
| "Too many events" liitumisel | Madal | Liitumisel sündmusi ei saadeta |

## Avatud küsimused

- Pole blokeerivaid. Avaliku (mitte piiratud) avaldamise otsus ja
  mobiilitugi arutatakse pärast Kontrollpunkti D.
