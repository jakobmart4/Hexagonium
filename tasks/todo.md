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

### Kontrollpunkt C
- [ ] Tulemused koos üle, tuunimised tehtud

## Faas 4 — SAMM 10: piiratud beta
- [ ] 8. Avaldamiseelne kontroll: Debug-lipud, CardSystemTest, 2 mängijaga kohalik server, §15 (S)
- [ ] 9. Avaldamine piiratud betana + tagasivõtuplaan (kasutaja)
- [ ] 10. Avaldamisjärgne kontroll: salvestus live's, Error Report, Analytics ≤24 h (S)

### Kontrollpunkt D
- [ ] Beta live, telemeetria voolab -> arutelu: mobiilitugi, "kinnita jätkamine", co-op
