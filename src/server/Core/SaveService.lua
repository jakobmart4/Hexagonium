--[[
	SaveService.lua
	Mangija puusiva edenemise salvestamine DataStore'i.

	PROFIILID (26.09): üks DataStore võti mängija kohta, selles kuni 3
	profiili (nagu Minecrafti maailmad): {slots = {["1"] = andmed, ...}}.
	Mängija valib profiili title screen'il (SelectSlot); kõik muud
	funktsioonid (Get, AddSeeds, ...) töötavad AKTIIVSE profiili peal.
	Vana ühe-profiilne salvestus kolib automaatselt profiili 1.

	MIDA PROFIIL SALVESTAB:
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

SaveService.SLOTS = 3

-- Versioon nimes: kui andmestruktuur muutub uhilduvusetult,
-- tosta numbrit, et vanad andmed ei laguneks.
SaveService.STORE_NAME = "HexagoniumPlayer_v1"
SaveService.AUTOSAVE_INTERVAL = 120

local store = nil
local storeAvailable = false

-- Malus hoitav seis mangija kohta
local roots = {}      -- [userId] = {slots = {["1"] = profiil, ...}}
local activeSlot = {} -- [userId] = "1".."3" (nil = title screen'il)
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
		lastPlayed = 0,     -- os.time() viimase valiku hetkel (title screen)
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

	if type(data.lastPlayed) ~= "number" then
		data.lastPlayed = defaults.lastPlayed
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

-- Profiilide juur. MIGRATSIOON: vana ühe-profiilne salvestus -> profiil 1.
local function normalizeRoot(raw)
	if type(raw) ~= "table" then
		return {slots = {}}
	end
	if type(raw.slots) ~= "table" then
		return {slots = {["1"] = fillDefaults(raw)}}
	end
	for key, profile in pairs(raw.slots) do
		raw.slots[key] = fillDefaults(profile)
	end
	return raw
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

-- Laeb profiilide juure (profiili EI vali - vt SelectSlot)
function SaveService.Load(player)
	local userId = player.UserId

	if roots[userId] then
		return roots[userId]
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

	roots[userId] = normalizeRoot(data)
	dirty[userId] = false

	return roots[userId]
end

-- AKTIIVSE profiili andmed (nil, kui mängija on title screen'il)
function SaveService.Get(player)
	local root = roots[player.UserId]
	local slot = activeSlot[player.UserId]
	return root and slot and root.slots[slot] or nil
end

-- ============================================================
-- PROFIILID (title screen)
-- ============================================================

-- Kokkuvõte kõigist kohtadest kliendi profiilivalikuks
function SaveService.GetProfileSummaries(player)
	local root = roots[player.UserId]
	local list = {}
	for i = 1, SaveService.SLOTS do
		local profile = root and root.slots[tostring(i)]
		if profile then
			list[i] = {
				slot = i,
				hexSeeds = profile.hexSeeds,
				runsPlayed = profile.stats.runsPlayed,
				tutorialComplete = profile.tutorialComplete,
				bonusExpansions = profile.bonusExpansions,
				cardsUnlocked = #profile.unlockedCards,
				lastPlayed = profile.lastPlayed,
			}
		else
			list[i] = {slot = i, empty = true}
		end
	end
	return list
end

local function slotKey(slot)
	if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > SaveService.SLOTS then
		return nil
	end
	return tostring(slot)
end

-- Teeb profiili aktiivseks (loob uue, kui koht on tühi). Tagastab andmed.
function SaveService.SelectSlot(player, slot)
	local root = roots[player.UserId]
	local key = slotKey(slot)
	if not root or not key then
		return nil
	end
	if not root.slots[key] then
		root.slots[key] = SaveService.GetDefaults()
	end
	root.slots[key].lastPlayed = os.time()
	activeSlot[player.UserId] = key
	dirty[player.UserId] = true
	return root.slots[key]
end

-- Tagasi title screen'ile: ükski profiil pole aktiivne
function SaveService.ClearActive(player)
	activeSlot[player.UserId] = nil
end

-- Kustutab profiili. Aktiivset (mängus olevat) ei saa kustutada.
function SaveService.DeleteSlot(player, slot)
	local root = roots[player.UserId]
	local key = slotKey(slot)
	if not root or not key or not root.slots[key] or activeSlot[player.UserId] == key then
		return false
	end
	root.slots[key] = nil
	dirty[player.UserId] = true
	return true
end

-- ============================================================
-- MUUTMINE
-- ============================================================

function SaveService.SetBonusExpansions(player, amount)
	local data = SaveService.Get(player)
	if not data then
		return false
	end

	data.bonusExpansions = math.clamp(amount, 0, Constants.IslandExpansion.MetaExpansionsMax)
	dirty[player.UserId] = true
	return true
end

function SaveService.SetTutorialComplete(player, value)
	local data = SaveService.Get(player)
	if not data then
		return false
	end

	data.tutorialComplete = value and true or false
	dirty[player.UserId] = true
	return true
end

-- Viimane järjest läbitud samm; ainult kasvab (vana sündmus ei vii tagasi)
function SaveService.SetTutorialStep(player, step)
	local data = SaveService.Get(player)
	if not data or type(step) ~= "number" then
		return false
	end

	data.tutorialStep = math.max(data.tutorialStep, math.floor(step))
	dirty[player.UserId] = true
	return true
end

function SaveService.AddStat(player, key, amount)
	local data = SaveService.Get(player)
	if not data or type(data.stats[key]) ~= "number" then
		return false
	end

	data.stats[key] = data.stats[key] + (amount or 1)
	dirty[player.UserId] = true
	return true
end

function SaveService.AddSeeds(player, amount)
	local data = SaveService.Get(player)
	if not data or type(amount) ~= "number" or amount <= 0 then
		return false
	end

	data.hexSeeds = data.hexSeeds + math.floor(amount)
	dirty[player.UserId] = true
	return true
end

-- Tagastab true ainult siis, kui seemneid oli piisavalt JA need kulutati
function SaveService.SpendSeeds(player, amount)
	local data = SaveService.Get(player)
	if not data or type(amount) ~= "number" or amount < 0 or data.hexSeeds < amount then
		return false
	end

	data.hexSeeds = data.hexSeeds - amount
	dirty[player.UserId] = true
	return true
end

-- Lisab ostetud kaardi. Tagastab false, kui juba olemas (duplikaate ei teki)
function SaveService.UnlockCard(player, cardName)
	local data = SaveService.Get(player)
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
	local data = roots[userId]

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
	roots[player.UserId] = nil
	activeSlot[player.UserId] = nil
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
	local ok, err = SaveService.EraseUserData(player.UserId)
	if not ok then
		warn("[SaveService] Testi-kustutus ebaonnestus (" .. player.Name .. "): " .. tostring(err))
	end
end

-- ============================================================
-- RIGHT TO ERASURE (GDPR / Roblox'i kustutusnõue)
--
-- Roblox saadab kustutusnõude (Creator Hub teavitus / e-kiri) koos
-- userId'ga. Arendaja kohustus: kustutada selle mängija salvestus.
-- Käivitamine Studios (Game Settings -> Security -> API Services sees),
-- Command Bar'ist:
--   print(require(game.ServerScriptService.Core.SaveService).EraseAllUserData(123456))
-- (EraseAllUserData = salvestus + tagasiside; EraseUserData ainult salvestus)
-- Tagastab true või false + veateade. Analüütika (AnalyticsService) ei
-- vaja midagi - Roblox käsitleb selle ise.
-- ============================================================
function SaveService.EraseUserData(userId)
	if type(userId) ~= "number" then
		return false, "userId peab olema number"
	end

	roots[userId] = nil
	activeSlot[userId] = nil
	dirty[userId] = nil

	-- Command Bar'ist kutsudes pole Init'i tehtud
	if not store then
		SaveService.Init()
	end
	if not storeAvailable then
		return false, "DataStore pole saadaval"
	end

	local ok, err = pcall(function()
		store:RemoveAsync("player_" .. userId)
	end)
	return ok, ok and "kustutatud: player_" .. userId or tostring(err)
end

-- Päris kustutusnõue: salvestus + tagasiside tekst (FeedbackService).
-- WipeForTesting kasutab ainult EraseUserData't - Studio testi-tagasiside
-- jääb loetavaks.
function SaveService.EraseAllUserData(userId)
	local ok, message = SaveService.EraseUserData(userId)
	local fbOk, fbMessage = require(script.Parent.FeedbackService).EraseUser(userId)
	return ok and fbOk, message .. "; " .. fbMessage
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
