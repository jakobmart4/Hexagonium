local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Karakterit ei tekitata: droonivaates tycoon ei vaja mangijamudelit
Players.CharacterAutoLoads = false

local Constants = require(ReplicatedStorage.Shared.Constants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local MapGenerator = require(ServerScriptService.Core.MapGenerator)
local WorldManager = require(ServerScriptService.Core.WorldManager)
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
-- MANGIJA LIITUB
-- ============================================================

local function onPlayerJoined(player)
	local data = SaveService.Load(player)

	local world = WorldManager.CreateFor(player, {
		metaRadius = data.metaRadius,
	})

	if not world then
		warn("[Hexagonium] " .. player.Name .. " ei saanud saart (server tais?)")
		return
	end

	print(string.format(
		"[Hexagonium] %s -> slot %d, metaRadius=%d, runid=%d%s",
		player.Name, world.slot, data.metaRadius, data.stats.runsPlayed,
		SaveService.IsAvailable() and "" or "  (SALVESTAMINE VALJAS)"))

	-- Meta-laiendus salvestub selle maailma omanikele
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

	-- Run'i lopp -> meta-progressioon
	local run = world.runManager
	if run then
		run:OnEnd(function(result)
			local perRadius = Constants.Run.RewardPerMetaRadius

			for _, owner in ipairs(world.owners) do
				SaveService.AddStat(owner, "runsPlayed", 1)
				SaveService.AddStat(owner, "totalUpgradePoints", result.pointsProduced)
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
		end)
	end

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
