--[[
	SaveService.lua
	Mangija puusiva edenemise salvestamine DataStore'i.

	MIDA SALVESTATAKSE:
	  bonusExpansions  - ostetud lisalaiendused run'i kohta (Hex Seeds)
	  tutorialComplete - kas mangija on esmase tutoriali labinud
	  tutorialStep     - pooleli tutoriali viimane järjest läbitud samm
	  stats            - mangustatistika (runid, runnakud, punktid)

	OLULINE STUDIO KOHTA:
	DataStore ei toota Studios, kui "Enable Studio Access to API
	Services" on valjas (Game Settings -> Security). Sel juhul
	langeme vaikevaartustele ja logime hoiatuse - mang tootab
	edasi, ainult ilma salvestamiseta.

	KOIK DATASTORE KUTSED ON pcall'i sees. DataStore voib
	ebaonnestuda ka avaldatud mangus (vorguprobleemid, limiidid),
	ja siis ei tohi mang katki minna.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local SaveService = {}

-- Versioon nimes: kui andmestruktuur muutub uhilduvusetult,
-- tosta numbrit, et vanad andmed ei laguneks.
SaveService.STORE_NAME = "HexagoniumPlayer_v1"
SaveService.AUTOSAVE_INTERVAL = 120

local store = nil
local storeAvailable = false

-- Malus hoitav seis mangija kohta: [userId] = data
local cache = {}
local dirty = {}

-- ============================================================
-- VAIKEANDMED
-- ============================================================

function SaveService.GetDefaults()
	return {
		bonusExpansions = 0,
		tutorialComplete = false,
		tutorialStep = 0, -- viimane JÄRJEST läbitud tutoriali samm (jätkamiseks)
		hexSeeds = 0,
		unlockedCards = {}, -- ostetud kaardid; algkomplekt on Constants.Meta
		stats = {
			runsPlayed = 0,
			attacksSurvived = 0,
			buildingsLost = 0,
			totalUpgradePoints = 0,
		},
	}
end

-- Liidab puuduvad valjad vaikeandmetest. Nii ei lagune vanad
-- salvestused, kui lisame uue valja.
local function fillDefaults(data)
	local defaults = SaveService.GetDefaults()

	if type(data) ~= "table" then
		return defaults
	end

	-- MIGRATSIOON: vana metaRadius (pusiv algsaare raadius) -> sama arv
	-- ostetud lisalaiendusi. Seemned on juba makstud, mangija ei kaota midagi.
	if type(data.bonusExpansions) ~= "number" then
		data.bonusExpansions = type(data.metaRadius) == "number"
			and data.metaRadius - Constants.IslandExpansion.StartRadius
			or defaults.bonusExpansions
	end
	data.metaRadius = nil

	if type(data.tutorialComplete) ~= "boolean" then
		data.tutorialComplete = defaults.tutorialComplete
	end

	if type(data.tutorialStep) ~= "number" then
		data.tutorialStep = defaults.tutorialStep
	end
	data.tutorialStep = math.max(0, math.floor(data.tutorialStep))

	if type(data.hexSeeds) ~= "number" then
		data.hexSeeds = defaults.hexSeeds
	end
	data.hexSeeds = math.max(0, math.floor(data.hexSeeds))

	if type(data.unlockedCards) ~= "table" then
		data.unlockedCards = defaults.unlockedCards
	end

	if type(data.stats) ~= "table" then
		data.stats = defaults.stats
	else
		for key, value in pairs(defaults.stats) do
			if type(data.stats[key]) ~= "number" then
				data.stats[key] = value
			end
		end
	end

	-- Kaitse rikutud vaartuste vastu
	data.bonusExpansions = math.clamp(math.floor(data.bonusExpansions), 0,
		Constants.IslandExpansion.MetaExpansionsMax)

	return data
end

-- ============================================================
-- ALGSEADISTUS
-- ============================================================

function SaveService.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(SaveService.STORE_NAME)
	end)

	if ok and result then
		store = result
		storeAvailable = true
	else
		storeAvailable = false
		warn("[SaveService] DataStore pole saadaval. Studios: luba " ..
			"Game Settings -> Security -> Enable Studio Access to API Services. " ..
			"Mang tootab edasi, aga edenemine ei salvestu.")
	end

	return storeAvailable
end

function SaveService.IsAvailable()
	return storeAvailable
end

-- ============================================================
-- LAADIMINE
-- ============================================================

function SaveService.Load(player)
	local userId = player.UserId

	if cache[userId] then
		return cache[userId]
	end

	local data = nil

	if storeAvailable then
		local ok, result = pcall(function()
			return store:GetAsync("player_" .. userId)
		end)

		if ok then
			data = result
		else
			warn("[SaveService] Laadimine ebaonnestus (" .. player.Name .. "): " ..
				tostring(result))
		end
	end

	data = fillDefaults(data)
	cache[userId] = data
	dirty[userId] = false

	return data
end

function SaveService.Get(player)
	return cache[player.UserId]
end

-- ============================================================
-- MUUTMINE
-- ============================================================

function SaveService.SetBonusExpansions(player, amount)
	local data = cache[player.UserId]
	if not data then
		return false
	end

	data.bonusExpansions = math.clamp(amount, 0, Constants.IslandExpansion.MetaExpansionsMax)
	dirty[player.UserId] = true
	return true
end

function SaveService.SetTutorialComplete(player, value)
	local data = cache[player.UserId]
	if not data then
		return false
	end

	data.tutorialComplete = value and true or false
	dirty[player.UserId] = true
	return true
end

-- Viimane järjest läbitud samm; ainult kasvab (vana sündmus ei vii tagasi)
function SaveService.SetTutorialStep(player, step)
	local data = cache[player.UserId]
	if not data or type(step) ~= "number" then
		return false
	end

	data.tutorialStep = math.max(data.tutorialStep, math.floor(step))
	dirty[player.UserId] = true
	return true
end

function SaveService.AddStat(player, key, amount)
	local data = cache[player.UserId]
	if not data or type(data.stats[key]) ~= "number" then
		return false
	end

	data.stats[key] = data.stats[key] + (amount or 1)
	dirty[player.UserId] = true
	return true
end

function SaveService.AddSeeds(player, amount)
	local data = cache[player.UserId]
	if not data or type(amount) ~= "number" or amount <= 0 then
		return false
	end

	data.hexSeeds = data.hexSeeds + math.floor(amount)
	dirty[player.UserId] = true
	return true
end

-- Tagastab true ainult siis, kui seemneid oli piisavalt JA need kulutati
function SaveService.SpendSeeds(player, amount)
	local data = cache[player.UserId]
	if not data or type(amount) ~= "number" or amount < 0 or data.hexSeeds < amount then
		return false
	end

	data.hexSeeds = data.hexSeeds - amount
	dirty[player.UserId] = true
	return true
end

-- Lisab ostetud kaardi. Tagastab false, kui juba olemas (duplikaate ei teki)
function SaveService.UnlockCard(player, cardName)
	local data = cache[player.UserId]
	if not data or type(cardName) ~= "string" then
		return false
	end

	for _, name in ipairs(data.unlockedCards) do
		if name == cardName then
			return false
		end
	end

	table.insert(data.unlockedCards, cardName)
	dirty[player.UserId] = true
	return true
end

-- ============================================================
-- SALVESTAMINE
-- ============================================================

function SaveService.Save(player, force)
	local userId = player.UserId
	local data = cache[userId]

	if not data then
		return false, "no data"
	end

	if not dirty[userId] and not force then
		return true, "unchanged"
	end

	if not storeAvailable then
		return false, "datastore unavailable"
	end

	local ok, err = pcall(function()
		store:SetAsync("player_" .. userId, data)
	end)

	if ok then
		dirty[userId] = false
		return true, "saved"
	end

	warn("[SaveService] Salvestamine ebaonnestus (" .. player.Name .. "): " .. tostring(err))
	return false, tostring(err)
end

-- Koondab lähestikku tehtud muudatused (nt mitu Hex Seeds ostu järjest)
-- ÜHEKS kirjutuseks. DataStore lubab sama võtit kirjutada ~1x 6 s jooksul;
-- sunnitud SetAsync iga ostu järel ummistaks kirjutusjärjekorra. Pelgalt
-- autosave'ile (120 s) jätmine kaotaks aga ostud Studios, kus BindToClose
-- jäetakse vahele.
local SAVE_SOON_DELAY = 7
local pendingSave = {}

function SaveService.SaveSoon(player)
	local userId = player.UserId
	if pendingSave[userId] then
		return
	end
	pendingSave[userId] = true

	task.delay(SAVE_SOON_DELAY, function()
		pendingSave[userId] = nil
		-- Lahkunud mängija salvestas juba Release (PlayerRemoving)
		if player.Parent then
			-- SUNNITUD: pooleli olev teine SetAsync (nt run'i lõpp) võib
			-- dirty-lipu vahepeal puhastada ostueelsete andmetega. Kirjutuste
			-- arvu piirab niikuinii see viivitus, mitte dirty-lipp.
			SaveService.Save(player, true)
		end
	end)
end

function SaveService.Release(player)
	SaveService.Save(player, true)
	cache[player.UserId] = nil
	dirty[player.UserId] = nil
end

-- ============================================================
-- TESTIMINE (Constants.Debug.WipeSaveOnJoin taga)
-- ============================================================

-- Kustutab mangija salvestuse TAIELIKULT enne laadimist - ilma
-- selleta ei saa Studios kunagi kontrollida, mida PARIS uus mangija
-- naeb: olemasolev bonusExpansions jm ainult CLAMPITAKSE uude vahemikku
-- (vt fillDefaults), mitte ei lahtestata, kui Constants.lua muutub.
function SaveService.WipeForTesting(player)
	local userId = player.UserId
	cache[userId] = nil
	dirty[userId] = nil

	if not storeAvailable then
		return
	end

	local ok, err = pcall(function()
		store:RemoveAsync("player_" .. userId)
	end)
	if not ok then
		warn("[SaveService] Testi-kustutus ebaonnestus (" .. player.Name .. "): " .. tostring(err))
	end
end

-- ============================================================
-- AUTOMAATNE SALVESTAMINE JA VALJUMINE
-- ============================================================

function SaveService.StartAutosave()
	task.spawn(function()
		while true do
			task.wait(SaveService.AUTOSAVE_INTERVAL)
			for _, player in ipairs(Players:GetPlayers()) do
				SaveService.Save(player)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		SaveService.Release(player)
	end)

	-- Serveri sulgemisel: viimane voimalus salvestada.
	-- Studios ei kaivitu BindToClose alati, avaldatud mangus kull.
	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		for _, player in ipairs(Players:GetPlayers()) do
			SaveService.Save(player, true)
		end
	end)
end

return SaveService
