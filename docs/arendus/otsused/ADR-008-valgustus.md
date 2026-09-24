---
tüüp: ADR
number: 8
staatus: kehtib
kuupäev: 2026-09-16
commit: 20d94a7, 3c1704d
---

# ADR-008: Valgustus tuleb ainult koodist

**Otsus:** `Environment.Setup` eemaldab Studios käsitsi lisatud
Atmosphere'i, Bloom'i ja ColorCorrection'i enne omade loomist. Studio
prügi (Baseplate, SpawnLocation, UnusedSkies, DepthOfField, HexOriginals)
kustutati. Hexide mallid, mida koodist luua ei saa, on varukoopiana
`assets/HexTemplates.rbxm`.

**Miks:** mängus oli 2 Atmosphere't (Roblox kasutab suvaliselt ühte) ja
2 Bloom'i (kahekordne helendus).

**Kood:**
[Environment.lua](../../../src/server/Core/Environment.lua),
[MapGenerator.lua](../../../src/server/Core/MapGenerator.lua) (`EnsureOcean`, `GetHexTemplates`)
