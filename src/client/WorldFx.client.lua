--[[
	WorldFx.client.lua (LocalScript)
	Maailma animatsioonid, mis jooksevad AINULT kliendis. Server märgib
	objektid atribuutidega; serveri tween'id replikeerisid iga kaadri igale
	kliendile ja tekitasid live'is lag'i (~90% liiklusest, 26.09).

	  Pulse = true        Power Core'i / Defenderi energiaosa "hingab"
	                      (MapGenerator.PlaceBuilding)
	  MoveTo, MoveTime    ründaja liigub sihtpunkti ühe tick'i jooksul
	                      (AttackManager:Tick - server hoiab loogilist asukohta)
]]

local TweenService = game:GetService("TweenService")

local PULSE = TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local islands = workspace:WaitForChild("Islands")

local function watch(part)
	if not part:IsA("BasePart") then
		return
	end
	if part:GetAttribute("Pulse") then
		-- Tween on seotud osaga; hoone hävides koristab Roblox selle ise
		TweenService:Create(part, PULSE, {Transparency = 0.45}):Play()
	end
	if part.Name == "Attacker" then
		part:GetAttributeChangedSignal("MoveTo"):Connect(function()
			local target = part:GetAttribute("MoveTo")
			if target then
				-- Goblin vaatab liikumise suunas (ainult pööre ümber Y)
				local from = part.Position
				local flat = Vector3.new(target.X, from.Y, target.Z)
				-- FacingYaw: mesh'i "ette" nurk (BuildingMeshes.Goblin = 180)
				local goal = (flat - from).Magnitude > 0.05
					and CFrame.lookAt(target, target + (flat - from).Unit)
						* CFrame.Angles(0, math.rad(part:GetAttribute("FacingYaw") or 0), 0)
					or CFrame.new(target) * part.CFrame.Rotation
				TweenService:Create(part, TweenInfo.new(part:GetAttribute("MoveTime") or 1,
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
