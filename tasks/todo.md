# Hexagonium — ülesanded (piiratud beta)

Plaan ja põhjendused: `tasks/plan.md`. Roadmap: `docs/HEXAGONIUM_Peadokument.txt` §16.

## Faas 0 — Dokumentatsioon
- [x] 1. Mobiilitugi pärast avaldamist + `tasks/plan.md` / `tasks/todo.md` (XS)

## Faas 1 — Mängijale nähtavad parandused
- [x] 2. Active Cards paneel loetavaks: kuvanimi + scope sildid, `affects` serverist (S)
      Kontrollitud: "Overclock · All buildings", "Resource Bloom · Assembler, Extractor, Refinery". Hex-silt kontrollimata (vajab 3D hex-klõpsu).
- [x] 3. Serveri kaardiluku kontroll päriselt testitud (Studio-ainult, XS)
      Kliendi kontroll ajutiselt välja -> server keeldus ("Null Surge is locked"), kaart jäi LOCKED.
- [x] 4. Ostud ei ummista DataStore'i: `SaveService.SaveSoon` (XS)
      Kontrollitud: 6 kaardiostu ~2 s jooksul, queue-hoiatust pole; pärast Stop/Play 65 seemet + kõik 6 kaarti alles.

### Kontrollpunkt A
- [x] Play smoke, konsool puhas, commit'id (kasutaja ülevaade kokkuvõttes)

## Faas 2 — Telemeetria (SAMM 10a)
- [x] 5. `Telemetry.lua` + run'i lõpp + Hex Seeds majandus (M)
- [x] 6. Tutoriali lehter + CardActivated + IslandExpanded + TutorialSkipped (S)

### Kontrollpunkt B
- [x] Kõik sündmused Studio konsoolis nähtud, peadokumendis "Telemeetria" alapunkt, commit
- [x] Koodiülevaatus (workflow: kvaliteet, turvalisus, lihtsustamine, jälgitavus)

## Faas 3a — Vahepala: tutoriali ümbertegemine (Play-test A leid)
- [x] 7a. Samm 2 viga (Ore-extractor ei saanud Power Core'i) + 9-sammuline tutorial: majandus, Demand, rünnakud, laiendus, Extract, Hex Seeds; tegevus- + infosammud ("Next"); Demand'id ootavad sammu 5; pooleli tutorial jätkub (M) — Play-s kontrollitud 16.09

## Faas 3 — SAMM 9: Play-test (kasutaja mängib Studios)
- [x] 7. Stsenaariumid A (uus mängija), B (pikk kokkuhoidev run), C (meta-tsükkel); tulemused TASAKAALUSTAMINE.md p.3, kangide otsused p.4
      A tehtud (16.09, -> 7a + Demand 30 s -> 10 s). B 1 run (8 min, 0 seemet) -> 7b. C tegemata.
- [x] 7b. Play-test B leiud: Overclock algkomplektist välja (ostetav), paremklõpsu menüüs voog/min + puhvrid + ummiku olek (`788c81e`)
- [x] 7c. Play-test B kordus ilma Overclockita (24.09): 18,6 min, tasu 633, +1 seeme, laiendused min 10/12
- [x] 7d. Otsus (24.09): `Meta.MinSeedsPerRun = 1` iga Extract/Timeout run'i eest, määr 600 jääb kuni 7c andmeteni. Oli: seemnete kang — 8-min run annab 0 seemet (558 < `Meta.SeedsPerPayout` 600); valik 400 või min 1 seeme run'i kohta
- [x] 7g. Kordaja = läbilaskevõime, Resource Bloom +15 % ühtlaselt, Power Core -> Town Hall (Lv2/3, UP + kristall) (24.09) — Play-testis: ahel puhas, Lv3 enne 11. min
- [x] 7h. Power Core = tuum + parandusala (Lv1-3: 2/3/4 hexi); hävimine võtab boonuse ja parandamise (24.09) — kasutaja: korras (26.09)
- [x] 7i. Play-test C: 3 run'i + Overclocki ost; seemned 600 -> 400, miinimum alles 5 min run'ist (26.09)
- [x] 7f. Kristall 36 -> 12/min, hoonete hinnad ~15% kallimaks (Extractor 25, Refinery 40, Assembler 55, PowerCore 45, Defender 40) (24.09)
- [x] 7e. Maak 60 -> 12 ore/min (ahel 1:1:1), Demand 50 -> 10 ore (24.09). Oli: algbaasi maak 5× ülepakkumises

### Kontrollpunkt C
- [ ] Tulemused koos üle, tuunimised tehtud

## Faas 4 — SAMM 10: piiratud beta
- [x] 8a. Turvalisus: RemoteEvent'ide sagedusepiirang (`PlayerActionHandler` allowRequest, 0,1 s) (26.09)
- [x] 8b. Right to Erasure: `SaveService.EraseUserData(userId)` + juhend peadokumendi §15 (26.09)
- [x] 8c. Review `20d94a7^..d7e54a9` (4 mõõdet + vastukontroll): 12 kinnitatud leidu parandatud, CardSystemTest 9/9, püsivus kontrollitud (26.09)
- [x] 8d. `CONSTRAINTS.md` + `scripts/check.sh` (7 automaatreeglit, 4 Studio-kontrolli) (26.09)
      26.09 tehtud: CardSystemTest 9/9, püsivus üle Play-sessioonide, 2 mängijaga Local Server (eraldi slotid/saared, laiendus ja Extract ei lekkinud, lahkumine vabastas sloti + RunEnded Quit, konsool puhas). Jäänud: check.sh + §15 lõpp-läbivaatus.
- [ ] 8. Avaldamiseelne kontroll: Debug-lipud (testiväärtused ainult `LocalDebug.lua`-s), CardSystemTest, 2 mängijaga kohalik server, §15 (S)
- [x] 9. Avaldamine piiratud betana (kasutaja, 26.09; server size 6)
- [ ] 10. Avaldamisjärgne kontroll: salvestus live's ✓ (runid 0 -> 1), lag parandatud ✓ (Recv 58 -> 2,6 KB/s, Data Ping ~500 ms -> ping 171 ms asukohast), Error Report + Analytics ≤24 h — ootel

## Faas 5 — Title screen, UI, mudelid, animatsioonid (kasutaja valik 26.09)
- [x] 5.1–5.2 Title screen + 3 profiili + MENU (Resume / Back to title / seemnepood); run algab profiili valikul. Studio: uus profiil, tagasi title'isse, teine profiil, kustutamine, püsivus üle sessioonide, vana salvestuse migratsioon profiili 1, pood (26.09)
- [ ] 5.3 UI kattumised: tutoriali paneel vs kaardipakk/ehitusmenüü, ehitusmenüü kärbitud tekst, paremate paneelide suurus
- [ ] 5.4 Mudelid: Town Hall taseme järgi, Defender tornina, veidi suuremad hooned
- [ ] 5.5 Animatsioonid kliendis: ehitus, Town Hall'i tase, hävimine

## Muu tehtud (väljaspool faase)
- [x] Studio korrastus: topelt-Lighting parandatud, prügi kustutatud, hexi mallid `assets/HexTemplates.rbxm` (16.09)
- [x] `docs/arendus/` (roadmap, play-testid, kontrollid, ADR-001..009) + Understand-Anything graaf (24.09)
- [x] Testilipud `src/shared/LocalDebug.lua`-sse, Constants'is ainult avaldamisväärtused (`0666f32`)
- [x] Play-testi aja kiirendus 2x/3x/5x (Studio): `GameClock` + `GameSpeed.client.lua` (24.09)

## Tööriistad (kasutaja)
- [ ] Pythoni Store'i otseteed välja (Sätted -> Rakendused -> Täpsemad -> Rakenduse käivitamise pseudonüümid) — vajalik `/understand` uuendusteks

### Kontrollpunkt D
- [ ] Beta live, telemeetria voolab -> arutelu: mobiilitugi, "kinnita jätkamine", co-op
