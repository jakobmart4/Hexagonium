--[[
	RangeRing.lua (AINULT kliendis)
	Raadiuse ring maapinnal: Defenderi laskeulatus, Town Hall'i parandusala
	(mängijate tagasiside 26.09). Kohalikud osad workspace'is - server ei
	näe, replikatsiooni pole.

	  RangeRing.Show(key, position, radiusStuds, color)
	  RangeRing.Hide(key)

	Ring = SEGMENTS õhukest neoonplokki ringjoonel + poolläbipaistev ketas
	(Robloxis pole toruse primitiivi).
]]

local Constants = require(script.Parent.Constants)

local RangeRing = {}

local SEGMENTS = 48
local rings = {} -- [key] = Model

-- Raadiused studides, samad valemid mis serveris
function RangeRing.DefenderRadius()
	local d = Constants.Buildings.Defender
	return d.DefenseRadius * d.StudsPerHex
end

-- Parandusala on hexi-kaugus: keskpunktid <= R hexi, ring ümbritseb ka
-- äärmiste hexide pinna (+ pool hexi)
function RangeRing.HealRadius(level)
	local townHall = Constants.Buildings.PowerCore.TownHall
	local hex = Constants.Buildings.Defender.StudsPerHex
	return (townHall[level] or townHall[1]).HealRadius * hex + hex / 2
end

function RangeRing.Hide(key)
	if rings[key] then
		rings[key]:Destroy()
		rings[key] = nil
	end
end

function RangeRing.Show(key, position, radius, color)
	local existing = rings[key]
	if existing and existing:GetAttribute("Radius") == radius then
		existing:PivotTo(CFrame.new(position))
		return
	end
	RangeRing.Hide(key)

	local model = Instance.new("Model")
	model.Name = "RangeRing_" .. key
	model:SetAttribute("Radius", radius)

	local center = Instance.new("Part")
	center.Name = "Fill"
	center.Shape = Enum.PartType.Cylinder
	center.Size = Vector3.new(0.05, radius * 2, radius * 2)
	center.CFrame = CFrame.Angles(0, 0, math.rad(90))
	center.Color = color
	center.Material = Enum.Material.SmoothPlastic
	center.Transparency = 0.85
	center.Parent = model

	local segLength = 2 * math.pi * radius / SEGMENTS + 0.05
	for i = 1, SEGMENTS do
		local angle = (i / SEGMENTS) * math.pi * 2
		local seg = Instance.new("Part")
		seg.Size = Vector3.new(segLength, 0.15, 0.3)
		seg.CFrame = CFrame.new(math.cos(angle) * radius, 0.05, math.sin(angle) * radius)
			* CFrame.Angles(0, -angle + math.pi / 2, 0)
		seg.Color = color
		seg.Material = Enum.Material.Neon
		seg.Transparency = 0.2
		seg.Parent = model
	end

	for _, part in ipairs(model:GetChildren()) do
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
	end

	-- Pivot = ringi keskpunkt ilma pöördeta (PrimaryPart'i pole - ketta
	-- 90° pööre kaoks PivotTo'ga)
	model.WorldPivot = CFrame.new()
	model:PivotTo(CFrame.new(position))
	model.Parent = workspace
	rings[key] = model
end

return RangeRing
