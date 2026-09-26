--[[
	WorldFx.client.lua (LocalScript)
	Maailma animatsioonid, mis jooksevad AINULT kliendis. Server märgib
	objektid atribuutidega; serveri tween'id replikeerisid iga kaadri igale
	kliendile ja tekitasid live'is lag'i (~90% liiklusest, 26.09).

	  Pulse = true        Power Core'i / Defenderi energiaosa "hingab"
	                      (MapGenerator.PlaceBuilding)
	  MoveTo, MoveTime    ründaja liigub sihtpunkti ühe tick'i jooksul
	                      (AttackManager:Tick - server hoiab loogilist asukohta)
	  FacingYaw           ründaja meshi "ette" nurk (BuildingMeshes.Goblin)

	Hooned (Model, atribuut BuildingType, kaustas Buildings) - 5.5, 26.09:
	  uus hoone           kerkib väikesest täissuurusesse (pop)
	  Level muutub        hüpe + laienev rõngas (MapGenerator.SetBuildingLevel)
	  Collapsing = true   vajub ja haihtub (MapGenerator.RemoveBuildingVisual,
	                      server kustutab COLLAPSE_TIME pärast)
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local PULSE = TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local LEVEL_RING_COLOR = Color3.fromRGB(255, 215, 110)

local islands = workspace:WaitForChild("Islands")

-- Skaleerib mudelit ajas; alus jääb hexile. fromMul = algne suhe
-- lõppsuurusest, easing annab Back'iga "põrke". Osade kaupa praegustest
-- mõõtudest (mitte Model:ScaleTo): serveri ScaleTo tegur (taseme suurus)
-- ei pruugi kliendini jõuda ja ScaleTo võiks hoone tagasi kahandada.
local function animateScale(model, fromMul, duration, style)
	local body = model.PrimaryPart
	if not body then
		return
	end
	local anchor = body.CFrame - Vector3.new(0, body.Size.Y / 2, 0)
	local parts = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, {part = d, size = d.Size, offset = anchor:ToObjectSpace(d.CFrame)})
		end
	end

	local function apply(scale)
		for _, p in ipairs(parts) do
			p.part.Size = p.size * scale
			p.part.CFrame = anchor * (p.offset.Rotation + p.offset.Position * scale)
		end
	end

	local started = time() -- päris aeg: kosmeetika ei kiirene mänguajaga
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if not model.Parent or model:GetAttribute("Collapsing") then
			connection:Disconnect()
			return
		end
		local t = math.min(1, (time() - started) / duration)
		apply(fromMul + (1 - fromMul) * TweenService:GetValue(t, style, Enum.EasingDirection.Out))
		if t >= 1 then
			connection:Disconnect()
			apply(1)
		end
	end)
	apply(fromMul)
end

-- Laienev ja haihtuv rõngas maapinnal (taseme tõus)
local function ringBurst(model)
	local body = model.PrimaryPart
	if not body then
		return
	end
	local width = math.max(body.Size.X, body.Size.Z)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.1, width, width)
	ring.CFrame = CFrame.new(body.Position.X, body.Position.Y - body.Size.Y / 2 + 0.2, body.Position.Z)
		* CFrame.Angles(0, 0, math.rad(90))
	ring.Color = LEVEL_RING_COLOR
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.2
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, width * 3, width * 3),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.8)
end

-- Kokkuvarisemine: kallutab, vajub alla ja haihtub
local function collapse(model)
	local body = model.PrimaryPart
	local height = body and body.Size.Y or 3
	local tilt = CFrame.Angles(math.rad(math.random(-20, 20)), 0, math.rad(math.random(-20, 20)))
	local info = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanQuery = false
			local goal = {CFrame = (d.CFrame - Vector3.new(0, height * 0.7, 0)) * tilt}
			if d.Transparency < 1 then
				goal.Transparency = 1
			end
			TweenService:Create(d, info, goal):Play()
		elseif d:IsA("BillboardGui") then
			d.Enabled = false
		end
	end
end

local function watchBuilding(model)
	-- Alamosad võivad samal kaadril alles saabuda
	task.defer(function()
		if not model.Parent or model:GetAttribute("Collapsing") then
			return
		end
		animateScale(model, 0.3, 0.45, Enum.EasingStyle.Back)
	end)
	model:GetAttributeChangedSignal("Level"):Connect(function()
		-- Server skaleeris ja lisas aluse enne atribuuti; oota need ära
		task.defer(function()
			animateScale(model, 0.8, 0.5, Enum.EasingStyle.Back)
			ringBurst(model)
		end)
	end)
	model:GetAttributeChangedSignal("Collapsing"):Connect(function()
		if model:GetAttribute("Collapsing") then
			collapse(model)
		end
	end)
end

local function watch(d)
	if d:IsA("Model") and d:GetAttribute("BuildingType") and d.Parent and d.Parent.Name == "Buildings" then
		watchBuilding(d)
		return
	end
	if not d:IsA("BasePart") then
		return
	end
	if d:GetAttribute("Pulse") then
		-- Tween on seotud osaga; hoone hävides koristab Roblox selle ise
		TweenService:Create(d, PULSE, {Transparency = 0.45}):Play()
	end
	if d.Name == "Attacker" then
		d:GetAttributeChangedSignal("MoveTo"):Connect(function()
			local target = d:GetAttribute("MoveTo")
			if target then
				-- Goblin vaatab liikumise suunas (ainult pööre ümber Y)
				local from = d.Position
				local flat = Vector3.new(target.X, from.Y, target.Z)
				-- FacingYaw: mesh'i "ette" nurk (BuildingMeshes.Goblin = 180)
				local goal = (flat - from).Magnitude > 0.05
					and CFrame.lookAt(target, target + (flat - from).Unit)
						* CFrame.Angles(0, math.rad(d:GetAttribute("FacingYaw") or 0), 0)
					or CFrame.new(target) * d.CFrame.Rotation
				TweenService:Create(d, TweenInfo.new(d:GetAttribute("MoveTime") or 1,
					Enum.EasingStyle.Linear), {CFrame = goal}):Play()
			end
		end)
	end
end

for _, d in ipairs(islands:GetDescendants()) do
	watch(d)
end
islands.DescendantAdded:Connect(watch)

print("[Hexagonium] WorldFx laaditud")
