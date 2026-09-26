local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- =========================================================
-- SEADED
-- =========================================================
local PAN_SPEED = 60
local ZOOM_MIN = 20
local ZOOM_MAX = 120
local ZOOM_STEP = 8
local START_PITCH = 55
local PITCH_MIN = 10
local PITCH_MAX = 89
local ORBIT_SENSITIVITY = 0.25
local START_TARGET = Vector3.new(0, 0, 0)

-- SERVAST PANNIMINE (RTS-tavaparane).
-- Ainus viis, mis tootab ka ilma keskmise hiirenuputa (sulearvutid).
local EDGE_PAN_ENABLED = true
local EDGE_MARGIN = 14
local EDGE_PAN_SPEED = 75

-- Kui kaugele saare keskpunktist tohib kaamera liikuda.
-- Ilma selleta saab mangija ookeani ara eksida.
local MAX_PAN_DISTANCE = 90

-- Klaviatuuriga pooramise kiirus (kraadi sekundis)
local KEY_ORBIT_SPEED = 90

local targetPosition = START_TARGET
local zoomDistance = 60
local yaw = 0
local pitch = START_PITCH

-- SAARE NIHE: saared ei ole enam koordinaadil (0,0). Server
-- saadab meile oma saare origin'i ja kaamera liigub sinna.
local islandOrigin = Vector3.new()
local originReceived = false

local moveInput = Vector2.new(0, 0)
local isOrbiting = false
local windowFocused = true

-- Paremkloops: KLOPS vs LOHISTAMINE
-- Paremkloops teenindab kahte asja - kaamera orbiiti ja
-- kontekstimenuud. Eristame neid liikumise jargi:
--   liigutus ule laveni -> orbiit (menuu ei avane)
--   liigutust pole       -> menuu avaneb (ContextMenu teeb seda ise)
-- Sama lavend peab olema ka ContextMenu's.
local DRAG_THRESHOLD = 6   -- pikslit
local rightPending = false
local rightStartPos = nil

local function isTargeting()
	local pg = player:FindFirstChild("PlayerGui")
	local flag = pg and pg:FindFirstChild("HexagoniumTargeting")
	return flag ~= nil and flag.Value == true
end

camera.CameraType = Enum.CameraType.Scriptable

-- MARKUS: karakterit ei tekitata uldse (Players.CharacterAutoLoads
-- = false, vt Bootstrap). Varasem labipaistvusega peitmine on
-- eemaldatud - see ei tootanud, sest Roblox lahtestas selle
-- suumimisel.

-- =========================================================
-- PAREMKLOOPS JA gameProcessed
--
-- Ilma karakterita margib Roblox paremkloopsu sageli
-- gameProcessed = true'ks. Kui me valjuksime siis kohe, ei
-- tootaks orbiit ega kontekstimenuu uldse.
--
-- Seega: paremkloopsu me TOOTLEME ALATI, teisi sisendeid mitte.
-- Kontroll, kas kursor on meie paneeli peal, tehakse eraldi.
-- =========================================================
local function isOverOwnUI()
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then
		return false
	end

	local mouse = UserInputService:GetMouseLocation()
	local objects = pg:GetGuiObjectsAtPosition(mouse.X, mouse.Y)

	for _, obj in ipairs(objects) do
		-- Ainult labipaistmatud paneelid loevad; kihid ja sildid mitte
		if obj.Visible and obj.BackgroundTransparency < 0.9 then
			return true
		end
	end
	return false
end

-- Servast pannimine tohib tootada AINULT siis, kui mangu aken on
-- fookuses. Muidu triivib kaamera minema, kui kursor juhtub akna
-- serval seisma (nt Studio's teise paneeli juures).
UserInputService.WindowFocused:Connect(function()
	windowFocused = true
end)
UserInputService.WindowFocusReleased:Connect(function()
	windowFocused = false
end)

-- =========================================================
-- MINIMAPI KLOPS
-- Minimap kirjutab sihtpunkti Vector3Value'sse; meie kuulame.
-- =========================================================
task.spawn(function()
	local pg = player:WaitForChild("PlayerGui")
	local target = pg:WaitForChild("HexagoniumCameraTarget", 15)
	if not target then
		return
	end

	target.Changed:Connect(function(value)
		if value and value.Magnitude > 0 then
			targetPosition = Vector3.new(value.X, 0, value.Z)
		end
	end)
end)

-- =========================================================
-- ORBIIT
-- Kolm viisi, sest paremkloops laks kontekstimenuu alla ja
-- keskmist hiirenuppu pole koigil olemas:
--   1) keskmine hiirenupp + lohistamine
--   2) Alt + vasak hiirenupp + lohistamine
--   3) nooleklahvid
-- =========================================================
local function altHeld()
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	local isRight = input.UserInputType == Enum.UserInputType.MouseButton2

	-- Paremkloopsu tootleme ka siis, kui Roblox selle "tarbituks"
	-- margib - muidu ei toota orbiit ilma karakterita.
	if gameProcessed and not isRight then
		return
	end

	local isMiddle = input.UserInputType == Enum.UserInputType.MouseButton3
	local isAltLeft = input.UserInputType == Enum.UserInputType.MouseButton1 and altHeld()

	if isMiddle or isAltLeft then
		isOrbiting = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	end

	-- Paremkloops: ootame, kas tuleb lohistamine voi klops.
	-- EI lukusta kursorit kohe - muidu ei saaks kontekstimenuud kasutada.
	if isRight and not isTargeting() and not isOverOwnUI() then
		rightPending = true
		-- Moodame lohistamist KURSORI POSITSIOONI, mitte Delta jargi.
		-- Delta on null, kuni hiir pole lukustatud - ja meie lukustame
		-- alles parast lave uletamist. Delta'ga jaaks see igaveseks
		-- ootele ja orbiit ei kaivituks kunagi.
		rightStartPos = UserInputService:GetMouseLocation()
	end

	-- Home voi F viib kaamera saare keskele tagasi
	if input.KeyCode == Enum.KeyCode.Home or input.KeyCode == Enum.KeyCode.F then
		targetPosition = islandOrigin
		zoomDistance = 60
		pitch = START_PITCH
	end
end)

-- =========================================================
-- SAARE NIHE SERVERILT
-- =========================================================
task.spawn(function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
	local stateRemote = RemoteEvents.Get("GameStateUpdate")
	if not stateRemote then
		return
	end

	stateRemote.OnClientEvent:Connect(function(payload)
		if not payload or not payload.origin then
			return
		end

		islandOrigin = Vector3.new(payload.origin.x, 0, payload.origin.z)

		-- Esimesel korral vii kaamera kohe oma saarele
		if not originReceived then
			originReceived = true
			targetPosition = islandOrigin
		end
	end)
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton3
		or input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.MouseButton2
	then
		if isOrbiting then
			isOrbiting = false
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end

	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		rightPending = false
		rightStartPos = nil
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		-- Kerimine paneelil (kaardipakk, ehitusmenüü jne) ei suumi kaamerat
		if not isOverOwnUI() then
			zoomDistance = math.clamp(zoomDistance - input.Position.Z * ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
		end
		return
	end

	if input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end

	-- Paremkloops ootel: kui hiir liigub ule laveni, on tegu
	-- lohistamisega -> alusta orbiiti
	if rightPending and not isOrbiting and rightStartPos then
		local nowPos = UserInputService:GetMouseLocation()
		if (nowPos - rightStartPos).Magnitude >= DRAG_THRESHOLD then
			isOrbiting = true
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		end
	end

	if isOrbiting then
		yaw = yaw - input.Delta.X * ORBIT_SENSITIVITY
		pitch = math.clamp(pitch - input.Delta.Y * ORBIT_SENSITIVITY, PITCH_MIN, PITCH_MAX)
	end
end)

-- =========================================================
-- PANN JA KLAVIATUURIGA POORAMINE
-- =========================================================
local function updateInput(dt)
	local dir = Vector2.new(0, 0)

	if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += Vector2.new(0, 1) end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir += Vector2.new(0, -1) end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir += Vector2.new(-1, 0) end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += Vector2.new(1, 0) end

	-- Nooleklahvid pooravad (orbiidi alternatiiv klaviatuurilt)
	if UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		yaw = yaw + KEY_ORBIT_SPEED * dt
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		yaw = yaw - KEY_ORBIT_SPEED * dt
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Up) then
		pitch = math.clamp(pitch + KEY_ORBIT_SPEED * dt, PITCH_MIN, PITCH_MAX)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Down) then
		pitch = math.clamp(pitch - KEY_ORBIT_SPEED * dt, PITCH_MIN, PITCH_MAX)
	end

	-- Servast pannimine
	if EDGE_PAN_ENABLED and not isOrbiting and windowFocused then
		local mouse = UserInputService:GetMouseLocation()
		local view = camera.ViewportSize

		-- Kursor peab olema akna SEES. Valjaspool akent tagastab
		-- GetMouseLocation viimase teadaoleva positsiooni, mis voib
		-- olla serval - ilma selle kontrollita triibiks kaamera.
		local insideWindow = mouse.X >= 0 and mouse.X <= view.X
			and mouse.Y >= 0 and mouse.Y <= view.Y

		if insideWindow then
			local edge = Vector2.new(0, 0)

			if mouse.X <= EDGE_MARGIN then
				edge += Vector2.new(-1, 0)
			elseif mouse.X >= view.X - EDGE_MARGIN then
				edge += Vector2.new(1, 0)
			end

			if mouse.Y <= EDGE_MARGIN then
				edge += Vector2.new(0, 1)
			elseif mouse.Y >= view.Y - EDGE_MARGIN then
				edge += Vector2.new(0, -1)
			end

			if edge.Magnitude > 0 then
				dir += edge * (EDGE_PAN_SPEED / PAN_SPEED)
			end
		end
	end

	moveInput = dir
end

-- =========================================================
-- KAAMERA UUENDUS
-- BindToRenderStep prioriteediga Camera+1, et Robloxi enda
-- kaameraskriptid ei kirjutaks meie CFrame'i ule.
-- =========================================================
local function updateCamera(dt)
	updateInput(dt)

	local yawRad = math.rad(yaw)
	local pitchRad = math.rad(pitch)

	local lookFlat = Vector3.new(-math.sin(yawRad), 0, -math.cos(yawRad))
	local rightFlat = Vector3.new(math.cos(yawRad), 0, -math.sin(yawRad))

	local delta = (rightFlat * moveInput.X + lookFlat * moveInput.Y) * PAN_SPEED * dt
	targetPosition = targetPosition + delta

	-- Hoia kaamera SAARE umbruses (mitte maailma keskpunkti)
	local flat = Vector3.new(
		targetPosition.X - islandOrigin.X,
		0,
		targetPosition.Z - islandOrigin.Z
	)
	if flat.Magnitude > MAX_PAN_DISTANCE then
		flat = flat.Unit * MAX_PAN_DISTANCE
		targetPosition = Vector3.new(
			islandOrigin.X + flat.X,
			0,
			islandOrigin.Z + flat.Z
		)
	end

	local horizontalDist = zoomDistance * math.cos(pitchRad)
	local height = zoomDistance * math.sin(pitchRad)

	local offset = Vector3.new(
		horizontalDist * math.sin(yawRad),
		height,
		horizontalDist * math.cos(yawRad)
	)

	camera.CFrame = CFrame.lookAt(targetPosition + offset, targetPosition)

	-- Fookus = koht, mida kaamera vaatab. Minimap loeb seda.
	-- Varem arvutas minimap fookust LookVector * 60 kaudu, mis
	-- nihkus suumimisel - kaamera kaugus muutus, fikseeritud 60 mitte.
	camera.Focus = CFrame.new(targetPosition)
end

RunService:BindToRenderStep(
	"HexagoniumDroneCamera",
	Enum.RenderPriority.Camera.Value + 1,
	updateCamera
)

print("[Hexagonium] DroneCamera laaditud")
