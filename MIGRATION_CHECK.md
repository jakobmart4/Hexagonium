# Migratsiooni kontroll

Juhend Claude Code'ile pärast seda, kui kood on Roblox Studiost
`rbxlx-to-rojo` abil failidesse eksporditud.

Eesmärk: veenduda, et kõik on olemas, õiges kohas ja õige tüübiga.

---

## 0. Enne alustamist

Kontrolli, et place'ist on varukoopia olemas (`*_backup.rbxl`).
Kui ei ole, PEATU ja ütle seda — Rojo ühendamine kirjutab Studios
oleva koodi üle ja poolik eksport tähendaks koodikadu.

---

## 1. Failitüübid — kõige sagedasem viga

Rojo otsustab objekti tüübi **failinime järgi**. Vale sufiks tähendab,
et skript ei käivitu või käivitub vales kohas.

| Roblox tüüp | Failinimi |
|---|---|
| `ModuleScript` | `Nimi.lua` |
| `Script` (server) | `Nimi.server.lua` |
| `LocalScript` (klient) | `Nimi.client.lua` |

**Kontrolli, et need kaks on `.server.lua`:**
- `src/server/Bootstrap.server.lua`
- `src/server/CardSystemTest.server.lua`

**Kontrolli, et KÕIK `src/client/` failid on `.client.lua`.**

Kõik ülejäänud on `ModuleScript` ehk tavaline `.lua`.

Kui kaustas on `init.lua`, muutub kaust ise ModuleScript'iks —
meie projektis ei tohiks ühtegi `init.lua` olla. Kui leiad, eemalda.

---

## 2. Oodatav failipuu

```
src/
├── shared/                     → ReplicatedStorage.Shared
│   ├── Constants.lua
│   ├── RemoteEvents.lua
│   ├── Theme.lua
│   ├── CardInfo.lua
│   └── BuildingInfo.lua
│
├── server/                     → ServerScriptService
│   ├── Bootstrap.server.lua
│   ├── CardSystemTest.server.lua
│   ├── Core/
│   │   ├── GameManager.lua
│   │   ├── WorldManager.lua
│   │   ├── TickService.lua
│   │   ├── MapGenerator.lua
│   │   ├── IslandManager.lua
│   │   ├── RunManager.lua
│   │   ├── StateBroadcaster.lua
│   │   ├── PlayerActionHandler.lua
│   │   └── SaveService.lua
│   ├── Hex/
│   │   └── HexGrid.lua
│   ├── Buildings/
│   │   ├── BuildingBase.lua
│   │   ├── BuildingFactory.lua
│   │   ├── Extractor.lua
│   │   ├── PowerCore.lua
│   │   ├── Refinery.lua
│   │   ├── Assembler.lua
│   │   └── Defender.lua
│   ├── Resources/
│   │   ├── NodeSystem.lua
│   │   ├── ResourceLedger.lua
│   │   └── PointBank.lua
│   ├── Factions/
│   │   ├── FactionStateMachine.lua
│   │   ├── FractureSyndicate.lua
│   │   └── AttackManager.lua
│   └── Cards/
│       ├── CardBase.lua
│       ├── CardManager.lua
│       ├── CardRegistry.lua
│       └── CardEffects/
│           ├── Overclock.lua
│           ├── FluxTide.lua
│           ├── BlessedHex.lua
│           ├── FracturePact.lua
│           ├── MirrorWorld.lua
│           ├── NullSurge.lua
│           ├── ResourceBloom.lua
│           ├── EnergyLeak.lua
│           ├── HexMutationWild.lua
│           └── HexMutationStable.lua
│
└── client/                     → StarterPlayerScripts
    ├── DroneCamera.client.lua
    ├── HUD.client.lua
    ├── CardDeck.client.lua
    ├── BuildMenu.client.lua
    ├── NodeLinks.client.lua
    ├── ContextMenu.client.lua
    ├── IslandPanel.client.lua
    ├── FactionPanel.client.lua
    ├── Minimap.client.lua
    └── RunPanel.client.lua
```

**Kokku: 5 + 38 + 10 = 53 faili.**

Loenda tegelikud failid. Kui arv erineb, nimeta täpselt, mis on
puudu või üle.

---

## 3. Mida KUSTUTADA

`rbxlx-to-rojo` ekspordib kogu place'i. Need ei kuulu repo koodi alla:

- `Workspace/` — maailma andmed, luuakse jooksvalt
- `Lighting/` — taevas, atmosfäär, efektid (jäävad place-faili)
- `Terrain` — ookean, luuakse jooksvalt
- `StarterGui/` — peab olema tühi (UI-skriptid on `client/` all)
- `StarterPack/`, `StarterCharacterScripts/`
- `Players/`, `Teams/`, `SoundService/`, `Chat/` jms teenused
- `ReplicatedStorage/BuildingTemplates`, `HexTemplates` — binaarsed
  mudelid, jäävad place-faili
- `ServerStorage/` — `HexOriginals`, `UnusedSkies`, varukoopiad

**Reegel:** repo hoiab KOODI. Mudelid, taevas ja valgustus jäävad
place-faili. Nii on Roblox-projektides tavaline — kaks allikat.

---

## 4. Require'ide kontroll

Kõik moodulid viitavad üksteisele absoluutsete teede kaudu, näiteks:

```lua
require(ServerScriptService.Core.MapGenerator)
require(ReplicatedStorage.Shared.Constants)
require(script.Parent.BuildingBase)
```

Kontrolli `grep`-iga, et iga `require(...)` sihtkoht on failipuus
olemas. Levinud probleem: eksport paneb midagi valesse alamkausta ja
`require` ei lahene enam.

Erilist tähelepanu vajavad:
- `Cards/CardEffects/*` — kasutavad `require(ServerScriptService.Cards.CardBase)`
- `Buildings/*` — kasutavad `require(script.Parent.BuildingBase)`
- kõik `client/*` — kasutavad `require(ReplicatedStorage.Shared.*)`

---

## 5. Sisu tervikluse kontroll

Ekspordi ajal võib tekst katki minna. Kontrolli:

- **Kas failid lõpevad `return <Moodul>`-iga?** Iga ModuleScript peab.
- **Kas täpitähed on terved?** Kommentaarid on eesti keeles;
  kui näed `Ã¤` või `?`, on kodeering katki (peab olema UTF-8).
- **Kas ükski fail pole tühi või kärbitud?** Võrdle ridade arvu
  ootusega: `MapGenerator.lua` ja `PlayerActionHandler.lua` on
  suurimad (kumbki 400+ rida).

---

## 6. Lõppkontroll

1. `rojo serve` käivitub ilma vigadeta
2. Studios "Connect" → skriptid ilmuvad õigetesse kohtadesse
3. Play → konsool näitab 10 laadimisteadet ja ühtegi viga:

```
[Hexagonium] DroneCamera laaditud
[Hexagonium] HUD laaditud
[Hexagonium] CardDeck laaditud
[Hexagonium] BuildMenu laaditud
[Hexagonium] NodeLinks laaditud
[Hexagonium] ContextMenu laaditud
[Hexagonium] IslandPanel laaditud
[Hexagonium] FactionPanel laaditud
[Hexagonium] Minimap laaditud
[Hexagonium] RunPanel laaditud
[Hexagonium] <nimi> -> slot 1, metaRadius=4, runid=N
```

Kui mõni teade puudub, on see skript kas puudu, vale tüübiga või
viskab laadimisel vea.

4. `git status` — kontrolli, et `.gitignore` töötab ja `*.rbxl`
   ei ole lisatud

---

## 7. Kui midagi on puudu

ÄRA kirjuta puuduvat faili mälu järgi uuesti. Ütle, mis on puudu —
originaal on veel Studio place-failis alles ja selle saab sealt
eksportida.
