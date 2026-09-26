#!/usr/bin/env bash
# Hexagoniumi kvaliteedilävend (vt CONSTRAINTS.md). Käivita repo juurest:
#   bash scripts/check.sh
# Väljumiskood 0 = kõik reeglid täidetud. Iga rikkumine prinditakse.
cd "$(dirname "$0")/.." || exit 1
fail=0
bad() { echo "RIKKUMINE: $1"; fail=1; }

# 1. Debug-lipud Constants'is avaldamisväärtustel
if grep -nE '^\s*(RunTests|RunBalanceSim|VerboseLogging|ExposeGameState|WipeSaveOnJoin)\s*=\s*true' src/shared/Constants.lua; then
	bad "Constants.Debug lipp on true (testiväärtused ainult LocalDebug.lua-sse)"
fi
grep -qE '^\s*ForceAttackAfter\s*=\s*0\s*,' src/shared/Constants.lua || bad "ForceAttackAfter ei ole 0"

# 2. LocalDebug.lua ei tohi olla gitis
git ls-files --error-unmatch src/shared/LocalDebug.lua >/dev/null 2>&1 && bad "src/shared/LocalDebug.lua on commit'itud"

# 3. Mänguloogika taimerid ainult GameClock'ist (lubatud: kell ise, broadcast'i sagedus, sagedusepiirang)
if grep -rn "os.clock()" src | grep -vE "Core/GameClock.lua|Core/StateBroadcaster.lua|Core/PlayerActionHandler.lua"; then
	bad "os.clock() mänguloogikas - kasuta GameClock.now()"
fi

# 4. Loetavus: TextSize vähemalt 12
if grep -rnE 'TextSize\s*=\s*([0-9]|1[01])\b' src; then
	bad "TextSize alla 12"
fi

# 5. Vaigistused ja saladused
if grep -rn -- '--!nocheck\|selene: allow' src; then
	bad "linteri/tüübikontrolli vaigistus"
fi
if grep -rniE 'api[_-]?key|x-api-key|bearer [a-z0-9]' src; then
	bad "võimalik saladus lähtekoodis"
fi

# 6. Iga klient -> server RemoteEvent on serveris seotud (bind)
for name in $(sed -n '/local EVENT_NAMES = {/,/}/p' src/shared/RemoteEvents.lua | grep -oE '"[A-Za-z]+"' | tr -d '"'); do
	case "$name" in GameStateUpdate|Notification|ProfileList) continue ;; esac
	grep -q "bind(\"$name\"" src/server/Core/PlayerActionHandler.lua || bad "RemoteEvent $name pole PlayerActionHandler'is seotud"
done

# 8. Serveris pole lõputuid tween'e (replikeeruvad igale kliendile iga kaadri)
if grep -rnE 'TweenInfo\.new\([^)]*-1' src/server; then
	bad "lõputu tween serveris - animeeri kliendis (WorldFx.client.lua)"
fi

# 7. Rojo projekt ehitub
rojo build default.project.json -o "${TEMP:-/tmp}/hexagonium-check.rbxlx" >/dev/null 2>&1 || bad "rojo build ebaõnnestus"

[ $fail -eq 0 ] && echo "OK: kõik CONSTRAINTS.md automaatreeglid täidetud"
exit $fail
