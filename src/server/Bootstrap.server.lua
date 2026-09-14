local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Karakterit ei tekitata: droonivaates tycoon ei vaja mangijamudelit
Players.CharacterAutoLoads = false

local Constants = require(ReplicatedStorage.Shared.Constants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local MapGenerator = require(ServerScriptService.Core.MapGenerator)
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
		local perRadius = Constants.Run.RewardPerMetaRadius

		for _, owner in ipairs(world.owners) do
			SaveService.AddStat(owner, "runsPlayed", 1)
			SaveService.AddStat(owner, "totalUpgradePoints", result.pointsProduced)
			SaveService.AddStat(owner, "attacksSurvived", result.attacksSurvived)
			SaveService.AddStat(owner, "buildingsLost", result.buildingsLost)
		end

		local gained = 0
		if world.islandManager then
			local steps = math.floor(result.payout / perRadius)
			for _ = 1, steps do
				local ok = world.islandManager:GrantMetaExpansion()
				if not ok then break end
				gained = gained + 1
			end
		end

		for _, owner in ipairs(world.owners) do
			SaveService.Save(owner, true)
		end

		print(string.format(
			"[Hexagonium] RUN LOPPES slot %d (%s): tasu=%d (%.0f%% %d-st), " ..
			"kestus=%.0fs, runnakuid=%d, meta+%d",
			world.slot, result.reason, result.payout, result.payoutRate * 100,
			result.banked, result.duration, result.attacksSurvived, gained))

		-- Jargmine run algab automaatselt samas maailmas: uus seeme,
		-- meta-raadius sailib, run-laiendused nullitakse. Viivitus
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
	local data = SaveService.Load(player)

	local world = WorldManager.CreateFor(player, {
		metaRadius = data.metaRadius,
		tutorialComplete = data.tutorialComplete,
	})

	if not world then
		warn("[Hexagonium] " .. player.Name .. " ei saanud saart (server tais?)")
		return
	end

	-- Puhas kuva-andmestruktuur peamenüü/start screen'i jaoks - TAHTLIKULT
	-- staatiline liitumishetke hetktõmmis ("save-faili ülevaade"), mitte
	-- live-uuenev loendur. Saadetakse kliendile StateBroadcaster'i kaudu.
	world.profileSnapshot = {
		metaRadius = data.metaRadius,
		tutorialComplete = data.tutorialComplete,
		stats = data.stats,
	}

	print(string.format(
		"[Hexagonium] %s -> slot %d, metaRadius=%d, runid=%d%s",
		player.Name, world.slot, data.metaRadius, data.stats.runsPlayed,
		SaveService.IsAvailable() and "" or "  (SALVESTAMINE VALJAS)"))

	-- Meta-laiendus salvestub selle maailma omanikele. UKS KORD:
	-- islandManager pusib run'ide ule, RestartRun ei loo seda uuesti.
	local island = world.islandManager
	if island then
		local originalGrant = island.GrantMetaExpansion
		island.GrantMetaExpansion = function(self, ...)
			local ok, newRadius = originalGrant(self, ...)
			if ok then
				for _, owner in ipairs(world.owners) do
					SaveService.SetMetaRadius(owner, newRadius)
					SaveService.Save(owner)
				end
			end
			return ok, newRadius
		end
	end

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
