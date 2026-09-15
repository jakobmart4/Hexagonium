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
| Demand intervall (tutorial) | 30s | `Faction.TutorialDemandInterval` |
| Demand kulu | 50 ore + 20 crystal, tähtaeg 30s | `Faction.Demand.*` |
| Hostile -> Attack viivitus | 30s | `Faction.AttackDelayAfterHostile` |
| Hoonete hinnad | Extractor 20, Refinery 35, Assembler 50, PowerCore 40, Defender ~~45~~ **35** | `BuildCosts` |
| Lammutuse tagastus | 50% | `DemolishRefund` |
| Saare laienduse kulu (run) | ~~40 -> 120 -> 360~~ **40 -> 80 -> 160 -> 320 -> 640 -> 1280** UP (x2) | `IslandExpansion.RunExpansionBaseCost` / `CostMultiplier` |
| Lisalaienduskoht (meta) | saar alustab alati raadiusega 3; N-s ostetud lisakoht = N Hex Seed'i (kuni 4, run'is 2 + ostetud laiendust); 1 seeme / 600 run'i tasu | `IslandExpansion.MetaExpansionsMax` / `Meta.SeedsPerPayout`, `Meta.IslandUpgradeCostPerStep` |
| Run'i Timeout | 3600s (60 min, ülempiir) | `Run.Duration` |
| RestartDelay | 8s | `Run.RestartDelay` |
| Ohu kasv | +12%/min, lagi 8.0x (~60. minutil) | `Attack.ScalePerMinute` / `MaxScale` |
| Rünnaku laine suurus | 3 + 1/rõngas, lagi 20 | `Attack.BaseAttackers` / `AttackersPerRing` / `MaxAttackers` |
| Kaardikordajad | vt Constants.Cards — igal kaardil oma | `Cards.*` |

## 2. Tuletatud suurused

| Suurus | Valem | Väärtus |
|---|---|---|
| Assembler baastoodang | 1 UP / 5s | 12 UP/min |
| Tuumaheла hind (Extractor+Refinery+Assembler+PowerCore) | 20+35+50+40 | 145 UP (algkapital 150) |
| Defender taskukohane | 35 UP / 12 UP/min | ~3. minutil |
| 1. saare laiendus taskukohane | 40 UP / 12 UP/min | ~4. minutil |
| Tutoriali samm 4 (rünnaku algus) | 30+30+30s | ~90s (worst case) |
| Kõik 6 run-laiendust kokku | 40 * (2^6 - 1) | 2520 UP |
| 4. laiendus vs tootmisahel | 320 UP / 105 UP (Extractor+Refinery+Assembler) | ~3 ahelat (+12 UP/min igaüks) |

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

## 4. Muudatuste logi

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
