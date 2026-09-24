# Hexagonium — Tasakaalustamine

Allikas on alati `Constants.lua`. See fail on tööriist tasakaalu
jälgimiseks ja muudatuste logiks — mitte kirjeldus, miks kood on
selline (see elab `HEXAGONIUM_Peadokument.txt`'is).

Metoodika: `src/server/BalanceSimulator.server.lua`
(`Constants.Debug.RunBalanceSim = true`, Play, loe konsool) annab
kiire matemaatilise hinnangu küsimustele, mida saab arvutada.
Tunnetuslikud küsimused (pacing, UX) vajavad käsitsi Play-testi —
vt punkt 3.

---

## 1. Praegused väärtused (seisuga 15. september 2026)

| Parameter | Praegune väärtus | Koht Constants.lua's |
|---|---|---|
| Ründaja HP | ~~60~~ **30** (x threatScale) | `Attack.AttackerHealth` |
| Ründaja DPS hoonele | 20 kahju / 2s = 10 DPS | `Attack.AttackerDamage` / `AttackerHitInterval` |
| Ründaja kiirus | 6 studi/s | `Attack.AttackerSpeed` |
| Defenderi DPS | ~~25~~ **35** kahju / 1s = 35 DPS | `Buildings.Defender.DefensePoints` / `FireInterval` |
| Defenderi energiakulu | 10 energiat / 5s | `Buildings.Defender.EnergyCostPerTick` / `Interval` |
| Defenderi raadius | 3 hexi | `Buildings.Defender.DefenseRadius` |
| EnergyPerCrystal | 50 | `Buildings.PowerCore.EnergyPerCrystal` |
| Energy Leak | x0.95 iga 30s, seisak alla 80% (10s) | `Buildings.PowerCore.EnergyLeak*` |
| Demand intervall (tavaline) | 150s | `FractureSyndicate.DEMAND_INTERVAL` |
| Demand intervall (tutorial) | 10s (Demand-sammu algusest) | `Faction.TutorialDemandInterval` |
| Demand kulu | ~~50~~ **10** ore + 20 crystal, tähtaeg 30s | `Faction.Demand.*` |
| Extractor maak | ~~5~~ **1** ore / 5 s = 12/min (= 1 Refinery tarbimine) | `Buildings.Extractor.OreProductionRate` |
| Extractor kristall | ~~3~~ **1** crystal / 5 s = 12/min = 600 energiat/min (~5 Defenderit) | `Buildings.Extractor.CrystalProductionRate` |
| Hostile -> Attack viivitus | 30s | `Faction.AttackDelayAfterHostile` |
| Hoonete hinnad | Extractor 25, Refinery 40, Assembler 55, PowerCore 45, Defender 40 (24.09: kõik ~15% kallimaks; oli 20/35/50/40/35) | `BuildCosts` |
| Lammutuse tagastus | 50% | `DemolishRefund` |
| Saare laienduse kulu (run) | 40 -> 70 -> 122 -> 214 -> 375 -> 656 UP (x1.75; x2 ja x3 proovitud) | `IslandExpansion.RunExpansionBaseCost` / `CostMultiplier` |
| Laienduse run'i tasu | ~~40~~ **0** (laiendus ei anna tasu) | `Run.RewardPerExpansion` |
| Lisalaienduskoht (meta) | saar alustab alati raadiusega 3; N-s ostetud lisakoht = N Hex Seed'i (kuni 4, run'is 2 + ostetud laiendust); 1 seeme / 600 run'i tasu, vähemalt 1 seeme iga Extract/Timeout run'i eest | `IslandExpansion.MetaExpansionsMax` / `Meta.SeedsPerPayout`, `Meta.IslandUpgradeCostPerStep` |
| Run'i Timeout | 3600s (60 min, ülempiir) | `Run.Duration` |
| RestartDelay | 8s | `Run.RestartDelay` |
| Ohu kasv | +12%/min, lagi 8.0x (~60. minutil) | `Attack.ScalePerMinute` / `MaxScale` |
| Rünnaku laine suurus | 3 + 1/rõngas, lagi 20 | `Attack.BaseAttackers` / `AttackersPerRing` / `MaxAttackers` |
| Kaardikordajad | vt Constants.Cards — igal kaardil oma | `Cards.*` |

## 2. Tuletatud suurused

| Suurus | Valem | Väärtus |
|---|---|---|
| Assembler baastoodang | 1 UP / 5s | 12 UP/min |
| Tuumaheла hind (Extractor+Refinery+Assembler+PowerCore) | 25+40+55+45 | 165 UP (algkapital 150; algbaas on juba ehitatud) |
| Uue tootmisahela tasuvus (Extractor+Refinery+Assembler) | 120 UP / 12 UP/min | ~10 min |
| Defender taskukohane | 35 UP / 12 UP/min | ~3. minutil |
| 1. saare laiendus taskukohane | 40 UP / 12 UP/min | ~4. minutil |
| Esimene Demand tutoriali ajal | TutorialDemandInterval | enne sammu 5 nõudeid ei tule; sammul 5 10s (oli 30s, Play-testis pikk); pärast 150s |
| Kõik 6 run-laiendust kokku | floor(40 * 1.75^(n-1)), n=1..6 | 1477 UP |
| 4. laiendus vs tootmisahel | 214 UP / 105 UP (Extractor+Refinery+Assembler) | ~2 ahelat (+12 UP/min igaüks) |

---

## 3. Testide tulemused

Täidetakse `BalanceSimulator.server.lua` väljundi ja käsitsi
Play-testide põhjal. Vormis: kuupäev, mida testiti, mis leiti.

| Kuupäev | Küsimus | Simulatsiooni tulemus | Manuaalse testi tähelepanek |
|---|---|---|---|
| 14.09.2026 | 1. Kaotuse % | 20 run'i (4 arhetüüpi x 5 seemet), ENNE muudatusi: **75% DESTROYED**. Üks Defender puhastab minut-0 laine, aga MITTE enam minutist 15. Käsitsi tuunitud (vt punkt 4 muudatuste logi) — checkpoint-tabel paranes minut-15 osas, aga agregeeritud % jäi samaks tööriista enda piirangu tõttu (üksainus Defender kogu run'i jooksul), mitte muudatuste ebaõnnestumise tõttu. Täielik analüüs punktis 4. | — |
| 14.09.2026 | 2/3. Demand-maksmine / Defenderi ehitamine | Arhetüübi-eeldused (mitte mõõdetud): 75% maksavad, 75% ehitavad kunagi Defenderi (3/4 arhetüüpi). Tautoloogiline tulemus praeguse mudeliga — vajab reaalset mängijaandmeid (telemeetria), kui see peaks kunagi täpsem olema. | — |
| 14.09.2026 | 4. UP majanduse tempo | Tuumahel (145 UP) valmib algkapitalist minutil 0. Sealt 12 UP/min — Defender ja 1. saare laiendus mõlemad taskukohased ~minutil 4. Tundub mõistlik: mängija saab midagi uut otsustada iga paari minuti tagant, mitte liiga tihti ega liiga harva. | — |
| 14.09.2026 | 5. Tutoriali pacing | Deterministlik: ~90s halvimal juhul (30+30+30s). | KINNITATUD SAMM 7 Play-testimisel: täielik 4-sammuline tsükkel (ehitus->ühendus->kaart->rünnak) läbis reaalselt ~90-120s piires liitumisest — tundus mõistlik, mitte venitatud ega kiirustatud. |
| 14.09.2026 | 6. Rünnaku raskus | Checkpointid: minut 0 OK (Defender puhastab), minut 15/30/60 EI puhasta üksi. Vahe minuti 0 ja 15 vahel on JÄRSK (threatScale 1.0x -> 2.8x kasvatab ründaja koguHP-d 180 -> 1344, 7.5x). | — |
| 14.09.2026 | 7. Run'i pikkus | Keskmine simuleeritud lõpp minut 25/60 — enamik run'e lõpeb tunduvalt enne Timeout'it (baas hävib enne 60 min täitumist). Duration=3600s ülempiir tundub harva reaalselt mõjutav tegur — enamik run'e lõpeb DESTROYED/EXTRACT kaudu enne. | — |
| 14.09.2026 | 8. RestartDelay | (arv ei kohaldu) | Vaadeldud SAMM 6/7 Play-testimisel (Extract-nupp -> "RUN COMPLETE" ekraan 5 reaga tulemusi -> 8-9s -> uus run algas automaatselt): 8s tundus piisav tulemuse lugemiseks, mitte liiga pikk tegevusetuks jäämiseks. |
| 14.09.2026 | (lisaks) Demand-bänneri hoiatusaeg | — | Vaadeldud SAMM 7 testimisel: "Decide within Ns" pöördloendus koos "Wants X ore + Y crystal (have A/B)" progressiga oli selgelt loetav; 30s tundus piisav teadliku Pay/Refuse otsuse jaoks. |
| 15.09.2026 | 9. Laienduse kordaja (kokkuhoidev mängija) | Kordajad 1.5-3, mängija ostab 1 Defenderi ja kogub ülejäänu. x3: 60-min run'is 3 laiendust -> kõik 4 ostetud lisakohta kasutamata. x1.75: 5 laiendust, 6. haruldane. Täielik tabel punktis 4. | Kasutaja: 1. laiendus sobiv, järgmised liiga suur kulu. |
| 16.09.2026 | 10. Play-test B (kokkuhoidev run, uus mängija, bonus 0) | — | Kestus **8 min** (plaan 20-30), lõpp **Extract**, tasu **558** (100%), rünnakuid üle elatud 1. Laiendused minutil **4 ja 5** -> run'i lagi (2) täis juba 5. minutil, edasi polnud saart kuhugi laiendada. Kaardid: Resource Bloom, Overclock. Tutorial Skip sammul 1. **Hex Seeds +0**: 558 < SeedsPerPayout 600 (~70 tasu/min -> 1. seeme alles ~8,6 min). Kasutaja muljed: ootel. |
| 24.09.2026 | 11. Play-test 7c (B kordus ILMA Overclockita, uus mängija, bonus 0, kiirendus 2-5x) | — | Kestus **18,6 min** mänguaega (1115 s), lõpp **Extract**, tasu **633** (~34 tasu/min; B-s Overclockiga ~70/min), rünnakuid 1. Laiendused minutil **10 ja 12** (B-s 4 ja 5). Kaart: Resource Bloom. Tutorial Skip. **Hex Seeds +1** (633/600 = 1, miinimumreeglit ei läinud vaja). Järeldus: määr 600 = ~1 seeme 18 min kohta; kaardi avamine (2 seemet) = 2 sellist run'i. Kasutaja muljed: ootel. |

## 4. Muudatuste logi

### 24.09.2026 (hiljem) — Kristall 36 -> 12/min, hoonete hinnad ~15% kõrgemaks

Play-test (7e järel, minut ~9): 332 kristalli kuhjunud Extractori väljundisse, Power Core pidevalt 1000/1000, 2 Defenderit tarbisid ~5 kristalli/min (tootmine 45/min Resource Bloomiga). Kristall 3 -> 1 / 5 s (soovitus, kasutaja kinnitas). Hinnad: analüüs näitas uue ahela tasuvust ~9 min ja soovitas odavamaks; kasutaja valis vastupidi "natuke kallimaks" -> Extractor 25, Refinery 40, Assembler 55, PowerCore 45, Defender 40 (tasuvus ~10 min). Jälgida: kas kokkuhoidev mängija ehitab veel teise ahela ja kas Defender 40 on rünnakute kasvuga õigel ajal jõukohane (SAMM 8 alandas selle 45 -> 35 just sel põhjusel).

### 24.09.2026 — Maagi tootmine 60 -> 12/min, Demand 50 -> 10 ore (7e)

Play-test 7c: ~3000 maaki kogunes Refinery sisendisse, alloy'd paarsada — Extractor tootis 60 ore/min, Refinery tarbis 12 (1 Extractor vajas 5 Refineryt + 5 Assemblerit). Kasutaja valik (3 variandi seast): Extractor aeglasemaks -> ahel 1:1:1, UP-tempo sama (12/min ahela kohta). Demand'i maagi nõue skaleeriti samas suhtes (50 -> 10, ~50 s tootmist), sest 1:1:1 ahelas maaki ei kogune ja uus mängija ei saaks esimest nõuet maksta. Kristall (36/min) jäi muutmata.

### 24.09.2026 — Vähemalt 1 Hex Seed run'i kohta (`Meta.MinSeedsPerRun = 1`)

Play-test B: 8-min run (tasu 558, koos Overclockiga) andis 0 seemet; ilma Overclockita annaks ka 20-min run hinnanguliselt ~500 tasu = 0 seemet. Uus mängija ei näeks meta-tsüklit (tutoriali samm 9) üldse. Otsus (kasutaja): iga run, mis ei lõpe baasi hävinguga, annab vähemalt 1 seemne; `SeedsPerPayout` 600 jääb, kuni 7c (B ilma Overclockita) annab päris tasuandmed.

### 15.09.2026 (õhtul) — Laienduse kordaja x3 -> x1.75 (kokkuhoidva mängija uuring)

**Kasutaja tagasiside**: 1. laiendus (40 UP) sobib, järgmised muutuvad
liiga suureks kuluks. Uurida kordajaid 1.5-3, eeldada kokkuhoidvat
mängijat.

**Mudel** (sama sissetulek mis `BalanceSimulator`'is): algbaas tasuta,
algkapital 150, mängija ostab 1 Defenderi (35) ja kogub ÜLEJÄÄNU
laienduste jaoks. Hind = `floor(40 * m^(n-1))` nagu
`IslandManager:GetNextCost`'is. Tabelis: mitmendal minutil on laiendus
1..6 taskukohane.

| Kordaja | Hinnad | 1 ahel (12 UP/min) | 2 ahelat (24 UP/min) | 25 / 60 min sisse (1 ahel) |
|---|---|---|---|---|
| x1.5 | 40 60 90 135 202 303 | 0 0 6 18 34 60 | 1 4 8 13 22 34 | 4 / 6 |
| **x1.75** | 40 70 122 214 375 656 | 0 0 10 28 59 114 | 1 4 9 18 34 61 | 3 / 5 |
| x2 | 40 80 160 320 640 1280 | 0 0 14 40 94 200 | 1 5 11 25 51 105 | 3 / 4 |
| x2.5 | 40 100 250 625 1562 3906 | 0 2 23 75 205 531 | 1 5 16 42 107 270 | 3 / 3 |
| x3 | 40 120 360 1080 3240 9720 | 0 4 34 124 394 1204 | 1 6 21 66 201 606 | 2 / 3 |

**Otsus (kasutaja)**: x1.75. Pika run'iga jõuab kokkuhoidev mängija 5
laienduseni (4. ~28. minutil, 5. ~59. minutil), 6. jääb haruldaseks
saavutuseks. x1.5 oleks lubanud kõik 6 (60. minutil).

| Parameter | Vana -> uus |
|---|---|
| `IslandExpansion.RunExpansionCostMultiplier` | 3 -> 1.75 |

**Mudeli piirangud** (reaalne mängija jõuab hiljem, v.a kaardid):
kaardid (nt Overclock x2.5) kiirendavad; hoonete taasehitus rünnakute
järel, 1 Defender ei pea alates ~15. minutist (punkt 3, küsimus 6) ja
+1 ründaja rõnga kohta aeglustavad.

**Kontroll**: väärtust loeb ainult `IslandManager:GetNextCost`
(`math.floor`), valem on Play-režiimis kontrollitud. Eraldi Play-testi
x1.75 jaoks ei tehtud.

### 15.09.2026 (hiljem) — x2 tagasi x3-le, RewardPerExpansion 40 -> 0

**Kasutaja otsus**: laiendus peab olema terav valik "saar VÕI kasum".
Allpool olev x2 kirje jättis kaks lahjendust: kulutamine ei vähenda
run'i tasu ja iga laiendus andis +40 tasu, nii et 1. laiendus oli tasu
mõttes tasuta.

**Muudatused** (`Constants.lua`):

| Parameter | Vana -> uus | Põhjus |
|---|---|---|
| `Run.RewardPerExpansion` | 40 -> 0 | laiendus maksab ainult tootmisvõimsuses, ei anna tasu tagasi |
| `IslandExpansion.RunExpansionCostMultiplier` | 2 -> 3 | laiendus jääb tahtlikult kalliks |

**Teadlik tagajärg**: lisakohad 3-6 maksavad 360, 1080, 3240 ja 9720 UP
(kõik 6 kokku 14560 UP). Ostetud lisakohad on pikk eesmärk (tugev
majandus pikas run'is), mitte iga run'i asi.

**Kontroll**: kumbagi väärtust loetakse ühes kohas
(`RunManager:RecordExpansion`, `IslandManager:GetNextCost`). x3 valem on
Play-režiimis kontrollitud (pärast 2 laiendust "Not enough: 8 / 360 UP").
Eraldi Play-testi ei tehtud.

### 15.09.2026 — Saare laienduse kordaja x3 -> x2

**Põhjus**: algsaar on nüüd alati raadius 3 ja run'is on 2 + kuni 4
ostetud (Hex Seeds) laienduskohta. x3 kordajaga maksid kohad 3-6
360, 1080, 3240 ja 9720 UP — ostetud kohad olid praktiliselt
kasutamatud.

**Muudatus** (`Constants.lua`):

| Parameter | Vana -> uus | Põhjus |
|---|---|---|
| `IslandExpansion.RunExpansionCostMultiplier` | 3 -> 2 | 40 -> 80 -> 160 -> 320 -> 640 -> 1280, kokku 2520 UP |

**Disainipõhimõte (kasutaja)**: laiendus peab olema valik "saar VÕI
kasum". Iga laienduse UP läheb tootmisest ära (4. laiendus = ~3
tootmisahelat) ja iga rõngas lisab rünnakutele +1 ründaja
(`Attack.AttackersPerRing`).

**TEADAOLEV LAHJENDUS, muutmata**: kulutamine ei vähenda run'i tasu
(tasu loeb TOODETUD UP-d, `RunManager:_currentPoints`) ja iga laiendus
annab ise +40 tasu (`Run.RewardPerExpansion`). 1. laiendus (40 UP) on
seega tasu mõttes tasuta. Kui valik peab olema teravam, on see
järgmine kang.

**Kontroll**: väärtust loeb ainult `IslandManager:GetNextCost`, mille
valem testiti Play-režiimis eelmise muudatuse juures (x3: pärast 2
laiendust "Not enough: 8 / 360 UP"). Eraldi Play-testi x2 jaoks ei
tehtud.

### 14.09.2026 — SAMM 8 samm 3: varajase rünnaku raskuse pehmendamine

**Diagnoos**: `Attack.ScalePerMinute` korrutab KORRAGA nii laine
SUURUST (`waveSize = BaseAttackers * threatScale`) kui ka iga
ründaja TERVIST (`attackerHP = AttackerHealth * threatScale`).
Need kaks kordajat KORRUTUVAD, mistõttu ründajate koguHP kasvab
ligikaudu ruutvõrdeliselt, aga Defenderi DPS on fikseeritud ja
mängija UP-sissetulek (12/min) kasvab lineaarselt. Käsitsi
arvutatuna: minutil 15 vajaks laine (1344 HP) puhastamine 3
Defenderit (280 UP kokku), aga majandus jõuab selleni alles
minutil ~23 — nõue saabub 8 min enne, kui seda saab täita.

**Muudatused** (`Constants.lua`):

| Parameter | Vana -> uus | Põhjus |
|---|---|---|
| `Buildings.Defender.DefensePoints` | 25 -> 35 | +40% DPS ühe torni kohta |
| `BuildCosts.Defender` | 45 -> 35 | 2./3. Defender taskukohane varem |
| `Attack.AttackerHealth` | 60 -> 45 -> **30** | Esimene katse (-25%, 45) ei piisanud — simulaator kinnitas, laine 15. minutil jäi ikka puhastamatuks. Teine katse (-50%, 30) tegi minut-15 checkpointi puhastatavaks (672 HP vs 700 Defenderi kahju). |

**MITTE puudutatud**: `ScalePerMinute`/`MaxScale` (kalibreeritud
minut-60 lae jaoks, vt Constants.lua rida ~286), laine SUURUS
(`BaseAttackers`/`AttackersPerRing`/`MaxAttackers` — nähtav
eskaleerumine säilib), Demand/Run/Card parameetrid (simulaator ei
tuvastanud nendega probleemi).

**AUS LEID kontrollimise käigus** — miks agregeeritud DESTROYED%
JÄI 75%-le, kuigi checkpoint-tabel selgelt paranes:

1. Esimene põhjus (parandatud): simulaator ei modelleerinud hoonete
   REGENERATSIOONI lainete vahel (`BuildingRegenPerSecond`/`Delay`),
   nii et iga, kasvõi väike korduv kahju kuhjus lõpuks paratamatult
   üle piiri. Lisasin `BalanceSimulator.server.lua`'sse taastumise
   samade valemitega mis pärismängus (vt koodikommentaar
   `REGEN_PER_CYCLE`). See on tööriista täpsuse parandus, mitte
   mänguloogika muudatus.
2. Teine, PÄRISEM põhjus: simulaator modelleerib iga arhetüüpi
   TÄPSELT 1 Defenderiga kogu run'i jooksul — aga päriskoodis
   (`AttackManager.lua`/`Defender.lua`) pole Defenderite arvule
   MINGIT piirangut. Käsitsi läbi arvutatuna: mängija, kes investeeriks
   IGA teenitud UP Defenderitesse pärast tuumahelat, jõuaks minutiks
   30 ~6 Defenderini (210 DPS) ja minutiks 60 ~16-ni (560 DPS) — see
   ületab isegi minut-60 lae (4800 HP) mugavalt, sest Defenderite arv
   kasvab LINEAARSELT ajaga (UP-sissetulek on konstantne), samas kui
   ründajate koguHP kasvab ainult 60-minutilise `MaxScale`-lae SEES
   (mitte lõpmatult, sest threatScale peatub 8.0x juures).
   TÄHENDAB: praeguste (uute) arvudega on täieliku
   kaitse-investeeringu strateegia ("turtle") ellujäämine kogu run'i
   vältel MATEMAATILISELT VÕIMALIK — see ei pruugi olla viga
   (tycoon-mängus on "ehita rohkem torne" legitiimne strateegia),
   aga väärib teadmist.

**JÄRELDUS**: kolm muudatust on valideeritud, PÕHJENDATUD parandus
varajase-keskmise mängu jaoks (minut-15 checkpoint: puhastamatust
puhastatavaks), ilma et minut-30/60 lagi (ühe Defenderiga) muutuks
liiga pehmeks. Agregeeritud DESTROYED% simulaatoris EI ole usaldusväärne
lõplik mõõdik enne, kui arhetüübid modelleerivad ka mitme Defenderi
investeeringut ajas — see on tööriista teadaolev piirang, mitte
mänguloogika viga. TÄPSEM kalibreerimine (kas 30 on "õige" number,
mitte lihtsalt "parem kui 60") vajab PÄRIS mängijate telemeetriat
(vt peadokumendi punkt 16, "PÄRAST TASAKAALUSTAMIST"), mitte
täiendavat simulaatori-arvamist.

**Kontrollitud Play-režiimis**: ForceAttackAfter=5 sunnitud minut-0
rünnak — Defenderi tuli tabas nähtavalt (tracer, "1 destroyed" 6s
sees), hooned said kahjumärgi. Visuaal/mehaanika töötab õigesti
uute arvudega. Mõlemad debug-lipud (RunBalanceSim, ForceAttackAfter)
taastatud vaikeväärtusteks pärast testimist.
