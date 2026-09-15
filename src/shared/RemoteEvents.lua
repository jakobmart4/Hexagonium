--[[
	RemoteEvents.lua
	Koik server<->klient kanalid uhes kohas. Loob RemoteEventid
	jooksvalt, kui neid veel pole (nii toimib nii serveris kui kliendis).

	SUUNAD:
	  GameStateUpdate  server -> klient   (HUD andmed, iga tick)
	  ActivateCard     klient -> server   (mangija aktiveerib kaardi)
	  BuildBuilding    klient -> server   (mangija ehitab hoone hexile)
	  ConnectNodes     klient -> server   (mangija loob node-uhenduse)
	  FactionDecision  klient -> server   (Fracture Pact jah/ei)
	  SkipTutorial     klient -> server   (mängija jätab tutoriali vahele)
	  BuyMetaUpgrade   klient -> server   (Hex Seeds kulutamine start screen'il)
	  Notification     server -> klient   (teated: runnak, kaardi efekt)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = {}

local EVENT_NAMES = {
	"GameStateUpdate",
	"ActivateCard",
	"BuildBuilding",
	"DemolishBuilding",
	"ConnectNodes",
	"FactionDecision",
	"ExpandIsland",
	"ExtractRun",
	"SkipTutorial",
	"BuyMetaUpgrade",
	"Notification",
}

-- Konteinerkaust RemoteEventidele
local function getContainer()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	return folder
end

-- Tagastab RemoteEventi nime jargi. Serveris loob selle vajadusel,
-- kliendis ootab, kuni server on selle loonud.
function RemoteEvents.Get(eventName)
	local container = getContainer()

	local existing = container:FindFirstChild(eventName)
	if existing then
		return existing
	end

	if game:GetService("RunService"):IsServer() then
		local remote = Instance.new("RemoteEvent")
		remote.Name = eventName
		remote.Parent = container
		return remote
	else
		-- Klient ootab kuni kanal tekib. EI kasuta ajapiirangut:
		-- server voib kaivituda aeglasemalt (nt DataStore laadimine)
		-- ja nil-tagastus pohjustaks vea alles hiljem, raskesti
		-- jalgitavas kohas.
		local found = container:WaitForChild(eventName, 10)
		if not found then
			warn("[RemoteEvents] " .. eventName .. " ei ilmunud 10 sekundiga, ootan edasi")
			found = container:WaitForChild(eventName)
		end
		return found
	end
end

-- Serveris kutsutav: loob koik RemoteEventid korraga
function RemoteEvents.InitAll()
	for _, name in ipairs(EVENT_NAMES) do
		RemoteEvents.Get(name)
	end
end

function RemoteEvents.GetAllNames()
	return EVENT_NAMES
end

return RemoteEvents
