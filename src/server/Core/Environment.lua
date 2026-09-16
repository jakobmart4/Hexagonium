--[[
	Environment.lua
	Valgustus/atmosfäär/post-effektid - kogu mängu visuaalne "ilm"
	ühes kohas, üks kord seatud (nagu MapGenerator.EnsureOcean).

	Mängul polnud varem ÜHTEGI neist - kõik Robloxi vaikeväärtustel,
	mistõttu saar/ookean nägi lamedana ja kontrastitult välja.
]]

local Lighting = game:GetService("Lighting")

local Environment = {}

function Environment.Setup()
	if Lighting:GetAttribute("HexagoniumEnvironmentReady") then
		return
	end

	-- Poolelouna madal paike - pikemad varjud, soojem toon hexidel
	Lighting.ClockTime = 15.5
	Lighting.GeographicLatitude = 30
	Lighting.Ambient = Color3.fromRGB(58, 64, 78)
	Lighting.OutdoorAmbient = Color3.fromRGB(94, 104, 124)
	Lighting.Brightness = 2.2
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1

	-- Kood on ainus allikas: Studios käsitsi lisatud samad efektid
	-- eemaldatakse. Muidu oli mängus 2 Atmosphere't (Roblox kasutab
	-- neist suvaliselt ühte) ja 2 Bloom'i (kahekordne helendus).
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Atmosphere") or child:IsA("BloomEffect") or child:IsA("ColorCorrectionEffect") then
			child:Destroy()
		end
	end

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "HexagoniumAtmosphere"
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(199, 209, 224)
	atmosphere.Decay = Color3.fromRGB(92, 122, 148)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.3
	atmosphere.Parent = Lighting

	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "HexagoniumColorCorrection"
	colorCorrection.Brightness = 0.02
	colorCorrection.Contrast = 0.08
	colorCorrection.Saturation = 0.12
	colorCorrection.TintColor = Color3.fromRGB(255, 250, 244)
	colorCorrection.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "HexagoniumBloom"
	bloom.Intensity = 0.4
	bloom.Size = 24
	bloom.Threshold = 1.7
	bloom.Parent = Lighting

	Lighting:SetAttribute("HexagoniumEnvironmentReady", true)
end

return Environment
