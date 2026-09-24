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
- [ ] 7. Stsenaariumid A (uus mängija), B (pikk kokkuhoidev run), C (meta-tsükkel); tulemused TASAKAALUSTAMINE.md p.3, kangide otsused p.4
      A tehtud (16.09, -> 7a + Demand 30 s -> 10 s). B 1 run (8 min, 0 seemet) -> 7b. C tegemata.
- [x] 7b. Play-test B leiud: Overclock algkomplektist välja (ostetav), paremklõpsu menüüs voog/min + puhvrid + ummiku olek (`788c81e`)
- [ ] 7c. Play-test B kordus ilma Overclockita
- [x] 7d. Otsus (24.09): `Meta.MinSeedsPerRun = 1` iga Extract/Timeout run'i eest, määr 600 jääb kuni 7c andmeteni. Oli: seemnete kang — 8-min run annab 0 seemet (558 < `Meta.SeedsPerPayout` 600); valik 400 või min 1 seeme run'i kohta
- [ ] 7e. Otsus: algbaasi maak 5× ülepakkumises (Extractor 60 ore/min, Refinery 12) — teadlik või tuunida

### Kontrollpunkt C
- [ ] Tulemused koos üle, tuunimised tehtud

## Faas 4 — SAMM 10: piiratud beta
- [ ] 8a. Turvalisus: RemoteEvent'ide sagedusepiirang (`PlayerActionHandler`) (S)
- [ ] 8b. Turvalisus: Right to Erasure — Robloxi GDPR-soovi korral salvestuse `player_<id>` kustutamine (`SaveService`) (S)
- [ ] 8c. Review commit'idele `20d94a7..0666f32` (Lighting, ContextMenu voog, Overclocki lukk, LocalDebug) (S)
- [ ] 8d. `CONSTRAINTS.md` CLAUDE.md reeglitest (TextSize ≥ 12, inglise tekst, üks allikas, Debug-lipud) (XS)
- [ ] 8. Avaldamiseelne kontroll: Debug-lipud (testiväärtused ainult `LocalDebug.lua`-s), CardSystemTest, 2 mängijaga kohalik server, §15 (S)
- [ ] 9. Avaldamine piiratud betana + tagasivõtuplaan (kasutaja)
- [ ] 10. Avaldamisjärgne kontroll: salvestus live's, Error Report, Analytics ≤24 h (S)

## Muu tehtud (väljaspool faase)
- [x] Studio korrastus: topelt-Lighting parandatud, prügi kustutatud, hexi mallid `assets/HexTemplates.rbxm` (16.09)
- [x] `docs/arendus/` (roadmap, play-testid, kontrollid, ADR-001..009) + Understand-Anything graaf (24.09)
- [x] Testilipud `src/shared/LocalDebug.lua`-sse, Constants'is ainult avaldamisväärtused (`0666f32`)
- [x] Play-testi aja kiirendus 2x/3x/5x (Studio): `GameClock` + `GameSpeed.client.lua` (24.09)

## Tööriistad (kasutaja)
- [ ] Pythoni Store'i otseteed välja (Sätted -> Rakendused -> Täpsemad -> Rakenduse käivitamise pseudonüümid) — vajalik `/understand` uuendusteks

### Kontrollpunkt D
- [ ] Beta live, telemeetria voolab -> arutelu: mobiilitugi, "kinnita jätkamine", co-op
