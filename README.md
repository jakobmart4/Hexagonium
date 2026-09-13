# Hexagonium

Run-põhine tycoon Roblox'is: hex-ruudustik saarel, Reality Cards
reeglimuutmise süsteem, run-süsteem meta-progressiooniga.

Place: `Hexagonium` (placeId 104026897810299)

Arhitektuur, konventsioonid ja tuntud lõksud: [CLAUDE.md](CLAUDE.md)
Täielik spec ja roadmap: [docs/HEXAGONIUM_Peadokument.txt](docs/HEXAGONIUM_Peadokument.txt)

## Areng

Rojo sünkroonib failid Studiosse:

```bash
rojo serve
```

Seejärel ühenda Roblox Studio pluginas "Connect".

Build (kontrolliks, ilma Studiota):

```bash
rojo build default.project.json -o Hexagonium.rbxlx
```
