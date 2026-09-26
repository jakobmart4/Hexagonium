--[[
	FeedbackService.lua
	Mängija tagasiside MENU-st (5.7, mängijate tagasiside 26.09).

	  hinnang 1-5 + kategooria -> AnalyticsService (Creator Dashboard,
	                              sündmus "FeedbackRating")
	  valikuline tekst          -> DataStore "HexagoniumFeedback_v1",
	                              võti "fb_<userId>_<os.time()>"

	Teksti näeb AINULT arendaja (mitte teised mängijad), seega seda ei
	filtreerita. Kustutusnõue (SaveService.EraseUserData) kustutab ka
	selle mängija tagasiside - võtme eesliide on userId.

	LUGEMINE Studios (Game Settings -> Security -> API Services sees),
	Command Bar:
	  require(game.ServerScriptService.Core.FeedbackService).PrintRecent(20)
	ListKeysAsync jõuab uute võtmeteni viitega (Studio test 27.09: värske
	kirje puudus nimekirjast minuteid, GetAsync leidis selle kohe).
]]

local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local Telemetry = require(ServerScriptService.Core.Telemetry)

local FeedbackService = {}

FeedbackService.STORE_NAME = "HexagoniumFeedback_v1"
FeedbackService.MAX_TEXT = 500
FeedbackService.CATEGORIES = {Fun = true, Bug = true, Idea = true}

local store = nil
local function getStore()
	if not store then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(FeedbackService.STORE_NAME)
		end)
		store = ok and result or nil
	end
	return store
end

-- Valideerib ja salvestab. Tagastab ok, sõnum (mängijale, inglise keeles).
function FeedbackService.Submit(player, rating, category, text)
	if type(rating) ~= "number" or rating ~= math.floor(rating) or rating < 1 or rating > 5 then
		return false, "Pick 1-5 stars."
	end
	if type(category) ~= "string" or not FeedbackService.CATEGORIES[category] then
		return false, "Pick a category."
	end
	if text ~= nil and type(text) ~= "string" then
		return false, "Invalid text."
	end
	-- Lõika ENNE trim'i: klient võib saata megabaitide pikkuse stringi
	text = text and text:sub(1, FeedbackService.MAX_TEXT):gsub("^%s+", ""):gsub("%s+$", "") or ""

	Telemetry.Event(player, "FeedbackRating", rating, {category})

	if text ~= "" then
		local ds = getStore()
		if not ds then
			return true, "Rating sent. (Text could not be saved right now.)"
		end
		local key = string.format("fb_%d_%d", player.UserId, os.time())
		local ok, err = pcall(function()
			ds:SetAsync(key, {rating = rating, category = category, text = text, time = os.time()}, {player.UserId})
		end)
		if not ok then
			warn("[FeedbackService] Salvestamine ebaõnnestus: " .. tostring(err))
			return true, "Rating sent. (Text could not be saved right now.)"
		end
		print(string.format("[FeedbackService] tekst salvestatud: %s (%d märki)", key, #text))
	end
	return true, "Thanks for the feedback!"
end

-- Kõik selle mängija tagasiside võtmed (kustutusnõue)
function FeedbackService.EraseUser(userId)
	local ds = getStore()
	if not ds then
		return false, "DataStore pole saadaval"
	end
	local ok, err = pcall(function()
		local pages = ds:ListKeysAsync("fb_" .. userId .. "_")
		while true do
			for _, info in ipairs(pages:GetCurrentPage()) do
				ds:RemoveAsync(info.KeyName)
			end
			if pages.IsFinished then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
	end)
	return ok, ok and "tagasiside kustutatud" or tostring(err)
end

-- Arendajale: prindib viimased N kirjet (Command Bar, vt päis)
function FeedbackService.PrintRecent(limit)
	local ds = getStore()
	if not ds then
		print("[Feedback] DataStore pole saadaval")
		return
	end
	local entries = {}
	local pages = ds:ListKeysAsync("fb_")
	while true do
		for _, info in ipairs(pages:GetCurrentPage()) do
			table.insert(entries, info.KeyName)
		end
		if pages.IsFinished then
			break
		end
		pages:AdvanceToNextPageAsync()
	end
	-- Võti lõpeb os.time()-ga -> uusimad eest
	table.sort(entries, function(a, b)
		return tonumber(a:match("_(%d+)$")) > tonumber(b:match("_(%d+)$"))
	end)
	for i = 1, math.min(limit or 20, #entries) do
		local data = ds:GetAsync(entries[i])
		if data then
			print(string.format("[Feedback] %s  %d*  %s  %s  %s", entries[i], data.rating, data.category,
				os.date("!%Y-%m-%d %H:%M", data.time), data.text))
		end
	end
	print(string.format("[Feedback] %d kirjet kokku", #entries))
end

return FeedbackService
