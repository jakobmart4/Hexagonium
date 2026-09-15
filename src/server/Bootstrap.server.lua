local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Karakterit ei tekitata: droonivaates tycoon ei vaja mangijamudelit
Players.CharacterAutoLoads = false

local Constants = require(ReplicatedStorage.Shared.Constants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local MapGenerator = require(ServerScriptService.Core.MapGenerator)
local Environment = require(ServerScriptService.Core.Environment)
local WorldManager = require(ServerScriptService.Core.WorldManager)
local GameManager = require(ServerScriptService.Core.GameManager)
local PlayerActionHandler = require(ServerScriptService.Core.PlayerActionHandler)
local SaveService = require(ServerScriptService.Core.SaveService)

local DEBUG = Constants.Debug

-- ============================================================
-- KAIVITUS
--
-- IGAL MANGIJAL ON OMA SAAR. Kuni 6 uhes serveris.
-- Uhised osad (ookean, hoonemallid, RemoteEventid, tegevuste
-- kasitleja) luuakse UKS KORD; maailmad tekivad liitumisel.
-- ============================================================

RemoteEvents.InitAll()
Environment.Setup()
MapGenerator.EnsureOcean()
MapGenerator.CreateBuildingTemplates()

-- Edit-rezhiimi eelvaade eemale. Saared luuakse jooksvalt, aga
-- Studios on vaja midagi nahtavat - eelvaate nimi algab "_"-ga
-- ja see kustutatakse mangu alguses.
local islandsRoot = workspace:FindFirstChild("Islands")
if islandsRoot then
	for _, folder in ipairs(islandsRoot:GetChildren()) do
		if folder.Name:sub(1, 1) == "_" then
			folder:Destroy()
		end
	end
end

SaveService.Init()
SaveService.StartAutosave()

-- Uks kasitleja koigile; ta leiab igale mangijale tema maailma
local actionHandler = PlayerActionHandler.new(WorldManager)
actionHandler:Connect()

-- ============================================================
-- RUN'I LOPP -> STATISTIKA, META-PROGRESSIOON, JARGMISE RUN'I ALGUS
--
-- Kutsutakse mangija liitumisel JA iga run'i taaskaivituse jarel
-- uuesti, sest GameManager.RestartRun loob world.runManager'ile UUE
-- instantsi - vana OnEnd-nimekiri ei kandu automaatselt edasi.
-- ============================================================
local function wireRunEnd(world)
	local run = world.runManager
	if not run then
		return
	end

	run:OnEnd(function(result)
		-- Tasu -> Hex Seeds. Mangija kulutab need ise run'ide vahel
		-- (PlayerActionHandler:HandleBuyMetaUpgrade). Varem anti saare
		-- laiendused siin OTSE ja korraga - vt Constants.Meta.
		local seeds = math.floor(result.payout / Constants.Meta.SeedsPerPayout)

		for _, owner in ipairs(world.owners) do
			SaveService.AddStat(owner, "runsPlayed", 1)
			SaveService.AddStat(owner, "totalUpgradePoints", result.pointsProduced)
			SaveService.AddStat(owner, "attacksSurvived", result.attacksSurvived)
			SaveService.AddStat(owner, "buildingsLost", result.buildingsLost)
			SaveService.AddSeeds(owner, seeds)
		end

		for _, owner in ipairs(world.owners) do
			SaveService.Save(owner, true)
		end

		print(string.format(
			"[Hexagonium] RUN LOPPES slot %d (%s): tasu=%d (%.0f%% %d-st), " ..
			"kestus=%.0fs, runnakuid=%d, seemned+%d",
			world.slot, result.reason, result.payout, result.payoutRate * 100,
			result.banked, result.duration, result.attacksSurvived, seeds))

		-- Jargmine run algab automaatselt samas maailmas: uus seeme,
		-- ostetud lisalaiendused sailivad, run-laiendused nullitakse. Viivitus
		-- annab mangijale aega tulemust lugeda (RunPanel "RUN COMPLETE").
		task.delay(Constants.Run.RestartDelay, function()
			if #world.owners == 0 then
				return -- mangija lahkus, maailm juba havitatud
			end
			GameManager.RestartRun(world)
			wireRunEnd(world)
		end)
	end)
end

-- ============================================================
-- TUTOORIUM VALMIS -> SALVESTA
--
-- Erinevalt wireRunEnd'ist EI pea seda RestartRun'i jarel uuesti
-- kutsuma: world.tutorial (nagu world.islandManager) pusib run'ide
-- ule, seega OnComplete-nimekiri ei kao kunagi.
-- ============================================================
local function wireTutorial(world)
	local tutorial = world.tutorial
	if not tutorial then
		return
	end

	tutorial:OnComplete(function()
		for _, owner in ipairs(world.owners) do
			SaveService.SetTutorialComplete(owner, true)
			SaveService.Save(owner, true)
		end

		print(string.format("[Hexagonium] TUTOORIUM LOPETATUD slot %d", world.slot))
	end)
end

-- ============================================================
-- MANGIJA LIITUB
-- ============================================================

local function onPlayerJoined(player)
	if DEBUG.WipeSaveOnJoin then
		SaveService.WipeForTesting(player)
	end

	local data = SaveService.Load(player)

	local world = WorldManager.CreateFor(player, {
		bonusExpansions = data.bonusExpansions,
		tutorialComplete = data.tutorialComplete,
	})

	if not world then
		warn("[Hexagonium] " .. player.Name .. " ei saanud saart (server tais?)")
		return
	end

	-- Start screen'i andmed = VIIDE salvestuse cache-tabelile, mitte koopia.
	-- Varem oli see "tahtlikult staatiline" tõmmis, aga stats oli niikuinii
	-- viide ja Hex Seeds ostud (BuyMetaUpgrade) PEAVAD kohe nähtavaks
	-- saama - viide teeb selle ilma käsitsi sünkroonimiseta. Saadetakse
	-- kliendile StateBroadcaster'i "profile"-väljana.
	world.profileSnapshot = data

	print(string.format(
		"[Hexagonium] %s -> slot %d, lisalaiendusi=%d, runid=%d%s",
		player.Name, world.slot, data.bonusExpansions, data.stats.runsPlayed,
		SaveService.IsAvailable() and "" or "  (SALVESTAMINE VALJAS)"))

	wireRunEnd(world)
	wireTutorial(world)

	if DEBUG.ForceAttackAfter and DEBUG.ForceAttackAfter > 0 then
		task.delay(DEBUG.ForceAttackAfter, function()
			if world.faction then
				print("[Hexagonium] SUNNITUD RUNNAK slot " .. world.slot)
				world.faction.machine:SetState("Hostile", 1, "Attack")
			end
		end)
	end
end

local function onPlayerLeaving(player)
	WorldManager.RemovePlayer(player)
	print(string.format("[Hexagonium] %s lahkus, maailmu alles: %d",
		player.Name, WorldManager.Count()))
end

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerJoined, player)
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(onPlayerJoined, player)
end)

Players.PlayerRemoving:Connect(onPlayerLeaving)
