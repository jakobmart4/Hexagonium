--[[
	SoundEffects.client.lua (LocalScript)
	Heliefektid mängu peamiste hetkede jaoks. EI KUVA midagi - puhtalt
	heli, samamoodi nagu teised klienskriptid tõlgendavad serveri
	toorseisundit (vrd Tutorial.client.lua, FactionPanel.client.lua).

	KAKS SIGNAALIALLIKAT, MÕLEMAD JUBA OLEMAS - server ei vaja uusi
	remote'e, ainult PlayerActionHandler:Notify'le valikuline 4.
	parameeter (soundHint):
	  1) Notification remote - server annab otsese vihje (data.sound),
	     mis heli mängida (ehitus/lammutus/ühendus/kaart), muidu
	     langeb kind="warning"/"error" peale tagasi.
	  2) GameStateUpdate remote - see skript jälgib ISE EELMISE ja
	     PRAEGUSE payload'i vahet (fraktsiooni olek, run'i tulemus,
	     kaotatud hooned), sest server saadab ainult toorseisundi.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local MASTER_VOLUME = 0.5

-- Kõik valitud helid ühes kohas - kui mõni ei kõla oodatult, vaheta
-- siin, mujal midagi muutma ei pea.
local SOUND_IDS = {
	build           = 9119730203,
	demolish        = 102757491685632,
	error           = 5229833733,
	-- kaardi hex-sihtimise nurjumine - kasutaja tagasiside jargi vahetatud
	-- eraldi heliks, mitte enam uldine "error"
	cardTargetError = 127004853365412,
	card            = 134787800528297,
	connect         = 9125539780,
	demand          = 6783209805,
	attack          = 9118805665,
	destroyed       = 9116547480,
	victory         = 110616737058623,
	defeat          = 107485186727325,
}

local sounds = {}
for name, assetId in pairs(SOUND_IDS) do
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = "rbxassetid://" .. assetId
	sound.Volume = MASTER_VOLUME
	sound.Parent = SoundService
	sounds[name] = sound
end

local function play(name)
	local sound = sounds[name]
	if sound then
		sound:Play()
	end
end

-- =========================================================
-- NOTIFICATION: otsene vihje serverilt, muidu kind-pohine tagasilangus
-- =========================================================
local notifyRemote = RemoteEvents.Get("Notification")
if notifyRemote then
	notifyRemote.OnClientEvent:Connect(function(data)
		if not data then
			return
		end

		if data.sound then
			play(data.sound)
		elseif data.kind == "warning" or data.kind == "error" then
			play("error")
		end
	end)
end

-- =========================================================
-- GAME STATE UPDATE: jalgime muutust ise, server saadab toorseisundi
-- =========================================================
local lastFactionState = nil
local hadRunResult = false
local lastBuildingsLost = 0

local stateRemote = RemoteEvents.Get("GameStateUpdate")
if stateRemote then
	stateRemote.OnClientEvent:Connect(function(payload)
		if not payload then
			return
		end

		local faction = payload.faction
		if faction then
			if faction.state ~= lastFactionState then
				if faction.state == "Demand" then
					play("demand")
				elseif faction.state == "Attack" then
					play("attack")
				end
				lastFactionState = faction.state
			end

			local lost = faction.attack and faction.attack.buildingsLost or 0
			if lost > lastBuildingsLost then
				play("destroyed")
			end
			lastBuildingsLost = lost
		end

		local run = payload.run
		if run and run.result and not hadRunResult then
			hadRunResult = true
			if run.result.reason == "Destroyed" then
				play("defeat")
			else
				play("victory")
			end
		elseif run and not run.result then
			-- Uus run algas (automaatne taaskaivitus) - lubame
			-- jargmise tulemuse jaoks uuesti helise
			hadRunResult = false
		end
	end)
end

print("[Hexagonium] SoundEffects laaditud")
