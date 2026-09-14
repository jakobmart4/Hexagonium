--[[
	Theme.lua
	KOGU mangu visuaalne keel uhes kohas: varvid, fondid, moodud.

	MIKS: varvitabel oli dubleeritud kolmes UI-failis (HUD, CardDeck,
	IslandPanel) ja neljandana MapGenerator'is. Uhe muutmine ja teiste
	unustamine oli ainult aja kusimus.

	REEGEL: uks UI-fail ei defineeri oma varve. Koik tuleb siit.

	--- VARVILOOGIKA ---
	Maailm on nuud ookeanis, seega MAA PEAB LUGEMA MAANA:
	  - neutraalne hex = soe kivi/liiv (mitte sinakashall, mis sulas veega)
	  - crystal hex   = violetne (mitte sinine, mis sulas veega)
	  - ore hex       = rooste/ooker
	Sinine jaab ookeanile ja UI aktsentidele.
]]

local TweenService = game:GetService("TweenService")

local Theme = {}

-- ============================================================
-- MAAILM (hexid, hooned, vesi)
-- ============================================================

Theme.World = {
	-- Hex-tuubid. Soojad maatoonid, et saar eristuks veest.
	hexOre       = Color3.fromRGB(186, 118, 52),   -- rooste/ooker
	hexCrystal   = Color3.fromRGB(146, 96, 202),   -- violetne (EI ole sinine)
	hexNeutral   = Color3.fromRGB(124, 114, 96),   -- tume soe kivi
	hexLocked    = Color3.fromRGB(42, 48, 58),     -- tume, vee all

	-- Hoonete varvid. Igauks peab eristuma nii omavahel kui hexidest.
	-- Refinery on teadlikult SININE, mitte roosa: roosa oli crystal-hexi
	-- violetile liiga lahedal ja hoone kadus tausta sisse.
	buildingExtractor = Color3.fromRGB(245, 210, 66),   -- kollane
	buildingPowerCore = Color3.fromRGB(70, 225, 230),   -- tsuaan
	buildingRefinery  = Color3.fromRGB(60, 120, 240),   -- sinine
	buildingAssembler = Color3.fromRGB(95, 215, 120),   -- roheline
	buildingDefender  = Color3.fromRGB(232, 62, 52),    -- punane
}

-- ============================================================
-- UI
-- ============================================================

Theme.UI = {
	-- Pinnad
	background   = Color3.fromRGB(20, 22, 28),
	panel        = Color3.fromRGB(31, 34, 43),
	panelHover   = Color3.fromRGB(43, 47, 59),

	-- Tekst
	text         = Color3.fromRGB(236, 239, 245),
	textDim      = Color3.fromRGB(148, 156, 173),
	textMuted    = Color3.fromRGB(105, 112, 128),

	-- Aktsendid
	accent       = Color3.fromRGB(92, 200, 232),   -- tsuaan: pealkirjad
	ocean        = Color3.fromRGB(82, 152, 222),   -- saare paneel

	-- Olekud
	success      = Color3.fromRGB(92, 220, 142),
	warning      = Color3.fromRGB(240, 176, 72),
	error        = Color3.fromRGB(234, 100, 86),
	blocked      = Color3.fromRGB(118, 126, 143),

	-- Energia
	energy       = Color3.fromRGB(255, 208, 80),
	energyLow    = Color3.fromRGB(230, 90, 70),

	-- Sihtimisrezhiim
	targeting    = Color3.fromRGB(255, 214, 92),
}

-- Ressursside varvid. Peavad kattuma hex-varvidega, et mangija
-- seoks HUD-i numbri maastikul oleva hexiga.
Theme.Resources = {
	Ore           = Theme.World.hexOre,
	Crystal       = Theme.World.hexCrystal,
	Alloy         = Color3.fromRGB(198, 202, 212),
	UpgradePoints = Color3.fromRGB(140, 220, 150),
}

-- Kaardi riskitase
Theme.Risk = {
	high   = Theme.UI.error,
	medium = Theme.UI.warning,
	none   = Color3.fromRGB(120, 200, 130),
}

-- ============================================================
-- TUPOGRAAFIA JA MOODUD
-- ============================================================

-- FONT
-- Montserrat valitud fondivordluse alusel: paksem ja teravam kui
-- Gotham, numbrid (1000 / 1000) on selgemini eristatavad.
Theme.Font = {
	regular = Enum.Font.Montserrat,
	bold    = Enum.Font.MontserratBold,
}

-- TEKSTISUURUSED
-- MARKUS: ara mine alla 12 - vaiksemal suurusel surutakse gluufid
-- kokku ja sonad jooksevad ukstiseks. See oli pohjus, miks tekst
-- nagi "vigane" valja.
Theme.TextSize = {
	label   = 12,   -- suurtahtedes sildid ("ENERGY")
	small   = 12,   -- abitekst (oli 10 - liiga vaike)
	body    = 13,
	value   = 14,
	large   = 19,   -- ressursinumbrid
}

Theme.Layout = {
	cornerRadius = 8,
	cornerSmall  = 6,
	padding      = 12,
	gap          = 6,
	panelAlpha   = 0.1,  -- paneeli taustalabipaistvus
}

-- ============================================================
-- VALUUTA
-- Uks nimi uhes kohas. Varem nimetati sama asja kolmel viisil:
-- "UPGRADES" (HUD), "upgrade points" (ehitusmenuu), "Banked"
-- (run-riba). Mangija pidi ise aru saama, et need on sama asi.
-- ============================================================

Theme.Currency = {
	name = "Upgrade Points",
	short = "UPGRADES",   -- veeru pealkiri HUD-is
	suffix = "UP",        -- arvu jarel: "40 UP"
}

-- Vormistab summa koos uhikuga: 40 -> "40 UP"
function Theme.Points(amount)
	return string.format("%d %s", math.floor(amount), Theme.Currency.suffix)
end

-- ============================================================
-- HOTKEYD
-- Uks koht, et nupusildid ja tegelikud klahvid ei laheks lahku.
--
-- MIKS EI KASUTA ESC-i: Roblox votab ESC endale (avab oma menuu),
-- seega mangu enda tuhistamiseks see ei sobi. Kasutame Q-d ja
-- paremkloppsu, mis on RTS-mangudes tavaparane.
--
-- MIKS L, MITTE E: E on inglise keeles uks sagedasemaid tahti ja
-- satub vestluses kergesti ette. L = Land.
-- ============================================================

Theme.Hotkeys = {
	cards  = "C",
	build  = "B",
	links  = "N",
	map    = "M",
	expand = "L",
	cancel = "Q",
}

-- ============================================================
-- ABIFUNKTSIOONID (korduv UI-kood uhes kohas)
-- ============================================================

function Theme.Corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or Theme.Layout.cornerSmall)
	c.Parent = parent
	return c
end

-- Loob standardse paneeli (taust + umarad nurgad)
function Theme.Panel(name, size, position, parent)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = Theme.UI.background
	frame.BackgroundTransparency = Theme.Layout.panelAlpha
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Theme.Corner(frame, Theme.Layout.cornerRadius)
	return frame
end

-- ============================================================
-- ANIMATSIOON
-- Uhes kohas, et koik paneelid liiguksid sama "tunnetusega".
-- MIKS CanvasGroup, mitte Frame: GroupTransparency mojutab KOIKI
-- jareltulijaid korraga (ei pea iga TextLabel'it eraldi tween'ima).
-- ============================================================

Theme.TweenTime = {
	fast = 0.15,
	normal = 0.25,
	slow = 0.4,
}

function Theme.Tween(instance, props, duration, style)
	return TweenService:Create(instance, TweenInfo.new(
		duration or Theme.TweenTime.normal,
		style or Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	), props)
end

-- Loob animeeritava paneeli (nagu Theme.Panel, aga CanvasGroup).
-- Algselt peidetud (Visible=false, GroupTransparency=1) - naita
-- Theme.ShowPanel'iga.
function Theme.AnimatedPanel(name, size, position, parent)
	local group = Instance.new("CanvasGroup")
	group.Name = name
	group.Size = size
	group.Position = position
	group.BackgroundColor3 = Theme.UI.background
	group.BackgroundTransparency = Theme.Layout.panelAlpha
	group.BorderSizePixel = 0
	group.GroupTransparency = 1
	group.Visible = false
	group.Parent = parent
	Theme.Corner(group, Theme.Layout.cornerRadius)
	return group
end

function Theme.ShowPanel(group, duration)
	group.Visible = true
	Theme.Tween(group, {GroupTransparency = 0}, duration):Play()
end

function Theme.HidePanel(group, duration)
	local tween = Theme.Tween(group, {GroupTransparency = 1}, duration)
	tween.Completed:Connect(function()
		group.Visible = false
	end)
	tween:Play()
end

-- Hoiab fikseeritud-offset paneeli ekraani SEES ka vaiksemal aknal
-- (nt dokitud Studio viewport). Mirrors ContextMenu.client.lua
-- kursori-kloppimise loogikat, aga reageerib viewporti suuruse
-- muutusele, mitte klopsule.
--
-- LOEB ALATI algsest deklareeritud Position'ist (mitte
-- frame.AbsolutePosition'ist, mis on Robloxis lazily uuendatav ja
-- voib viewport-muutuse sundmuse ajal olla veel eelmise kaadri
-- vaartus) - nii ei saa uks vigane/enneaegne korrektsioon kuhjuda
-- Position'isse jaadavalt (see oli pohjus, miks Menu-nupp hupas
-- x=436-lt x=0-le).
function Theme.ClampToViewport(frame)
	local camera = workspace.CurrentCamera
	local base = frame.Position
	local function clamp()
		local viewport = camera.ViewportSize
		local size = frame.AbsoluteSize
		local baseX = base.X.Scale * viewport.X + base.X.Offset
		local baseY = base.Y.Scale * viewport.Y + base.Y.Offset
		local clampedX = math.clamp(baseX, 0, math.max(0, viewport.X - size.X))
		local clampedY = math.clamp(baseY, 0, math.max(0, viewport.Y - size.Y))
		frame.Position = UDim2.new(
			base.X.Scale, clampedX - base.X.Scale * viewport.X,
			base.Y.Scale, clampedY - base.Y.Scale * viewport.Y
		)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(clamp)
end

-- Paneeli pealkiri (suurtahtedes, aktsentvarvis)
function Theme.Title(text, parent, color)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -Theme.Layout.padding * 2, 0, 20)
	label.Position = UDim2.new(0, Theme.Layout.padding, 0, 8)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or Theme.UI.accent
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = Theme.Font.bold
	label.TextSize = Theme.TextSize.label
	label.Parent = parent
	return label
end

return Theme
