--[[
	Telemetry.lua
	Mängu analüütika ÜHES kohas. Iga sündmus vastab küsimusele (vt
	peadokument, "Telemeetria"):
	  - kus uus mängija tutorialist välja kukub
	  - kuidas run'id lõpevad ja kui kaua kestavad
	  - kas saare laiendusi kasutatakse
	  - kas Hex Seeds majandus on tasakaalus
	  - milliseid kaarte kasutatakse

	LIVE: Roblox'i AnalyticsService. Sündmused lähevad AINULT avaldatud mängu
	serverist (mitte Studiost ega kliendist); armatuurlaud täitub kuni 24 h.
	Kutsed on pcall'is - analüütika viga ei tohi mängu katkestada.

	STUDIO: AnalyticsService sündmusi ei võta vastu, seega trükitakse sama
	sündmus konsooli ühe struktureeritud reana "[Telemetry] {json}". See on
	ühtlasi Play-testi logi.

	KARDINAALSUS: kuni 3 kohandatud välja (CustomField01..03), väärtused
	VÄIKESTEST fikseeritud hulkadest (lõpu põhjus, kaardi nimi, 0-4).
	Ära pane väljadesse mängija nime, ID-d ega vaba teksti.
]]

local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Telemetry = {}

local IS_STUDIO = RunService:IsStudio()

local FIELD_KEYS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
}

-- Live-rada ei saa Studios käivitada, seega kontrollime vähemalt, et kõik
-- kasutatavad meetodid on olemas - muidu leiaks vea alles avaldatud mängus.
for _, method in ipairs({"LogCustomEvent", "LogEconomyEvent", "LogOnboardingFunnelStepEvent"}) do
	local ok, fn = pcall(function()
		return AnalyticsService[method]
	end)
	if not ok or type(fn) ~= "function" then
		warn("[Telemetry] AnalyticsService." .. method .. " puudub - live-sündmused ei tööta")
	end
end

-- fields: kuni 3 väärtust JÄRJEKORRAS, nt {"Extract"} -> CustomField01
local function toCustomFields(fields)
	if not fields or #fields == 0 then
		return nil
	end
	local out = {}
	for i = 1, math.min(#fields, #FIELD_KEYS) do
		out[FIELD_KEYS[i]] = tostring(fields[i])
	end
	return out
end

local function emit(payload, send)
	if IS_STUDIO then
		print("[Telemetry] " .. HttpService:JSONEncode(payload))
		return
	end
	local ok, err = pcall(send)
	if not ok then
		warn("[Telemetry] " .. tostring(payload.kind) .. " ebaõnnestus: " .. tostring(err))
	end
end

-- Kohandatud sündmus. value = number (vaikimisi 1).
function Telemetry.Event(player, name, value, fields)
	value = value or 1
	local customFields = toCustomFields(fields)
	emit({kind = "event", event = name, value = value, fields = fields}, function()
		AnalyticsService:LogCustomEvent(player, name, value, customFields)
	end)
end

-- Majandus. flow: "Source" | "Sink"; transaction: AnalyticsEconomyTransactionType
-- nimi ("Gameplay", "Shop", ...). Enum'id lahendatakse ENNE Studio/live
-- hargnemist, et vale nimi viskaks vea juba Studios.
function Telemetry.Economy(player, flow, currency, amount, endingBalance, transaction, sku)
	local flowType = Enum.AnalyticsEconomyFlowType[flow]
	local transactionType = Enum.AnalyticsEconomyTransactionType[transaction].Name
	emit({
		kind = "economy", flow = flow, currency = currency, amount = amount,
		balance = endingBalance, transaction = transactionType, sku = sku,
	}, function()
		AnalyticsService:LogEconomyEvent(player, flowType, currency, amount,
			endingBalance, transactionType, sku)
	end)
end

-- Tutoriali lehter (1..N). Roblox näitab seda eraldi onboarding-vaates.
function Telemetry.OnboardingStep(player, step, stepName)
	emit({kind = "onboarding", step = step, stepName = stepName}, function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)
	end)
end

return Telemetry
