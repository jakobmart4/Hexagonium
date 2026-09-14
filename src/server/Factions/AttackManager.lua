--[[
	AttackManager.lua
	Haldab uhe runnakulaine elutsuklit: ruundajate tekitamine,
	liikumine, Defenderite tulistamine ja hoonete kahjustamine.

	KUJUNDUS:
	  - Ruundajad tekivad saare servalt, valivad sihtmargiks lahima
	    hoone ja liiguvad selle poole maailmaruumis (mitte hex-kaupa,
	    sest see on lihtsam ja naeb sujuvam valja).
	  - Defenderid tulistavad automaatselt lahimat ruundajat oma
	    raadiuses. Sihtmargi valik on SIIN, mitte tornis - nii ei pea
	    torn ruundajatest midagi teadma.
	  - Laine lopeb, kui koik ruundajad on surnud VOI aeg saab labi.

	RUUNDAJAD ON SERVERIPOOLSED Part'id - nad replikeeruvad
	automaatselt, seega kliendi koodi pole vaja.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Theme = require(ReplicatedStorage.Shared.Theme)

local CFG = Constants.Attack

local AttackManager = {}
AttackManager.__index = AttackManager

function AttackManager.new(gameState)
	local self = setmetatable({}, AttackManager)

	self.gameState = gameState
	self.attackers = {}
	self.active = false
	self.waveStartTime = nil
	self.spawnQueue = 0
	self.lastSpawnTime = 0

	-- Statistika kliendile
	self.killed = 0
	self.buildingsLost = 0
	self.threatScale = 1

	return self
end

-- ============================================================
-- KONTEINER
-- ============================================================

function AttackManager:_getFolder()
	local folder = self.gameState.folder
	if not folder then
		return nil
	end
	return folder:FindFirstChild("Attackers")
end

-- ============================================================
-- SIHTMARGID
-- ============================================================

-- Hoone visuaali Model (Q/R atribuudi jargi) - jagatud mitme funktsiooni vahel
function AttackManager:_getBuildingVisual(building)
	local buildings = self.gameState.folder
		and self.gameState.folder:FindFirstChild("Buildings")
	if not buildings then
		return nil
	end

	for _, visual in ipairs(buildings:GetChildren()) do
		if visual:GetAttribute("Q") == building.q
			and visual:GetAttribute("R") == building.r
		then
			return visual
		end
	end
	return nil
end

-- Hoone visuaali maailmapositsioon
function AttackManager:_getBuildingPosition(building)
	local visual = self:_getBuildingVisual(building)
	return visual and visual.PrimaryPart and visual.PrimaryPart.Position or nil
end

-- Koik elus hooned koos positsioonidega
function AttackManager:_getTargets()
	local targets = {}
	for _, b in pairs(self.gameState.buildings) do
		if not b.isDestroyed then
			local pos = self:_getBuildingPosition(b)
			if pos then
				table.insert(targets, {building = b, position = pos})
			end
		end
	end
	return targets
end

-- ============================================================
-- LAINE ALUSTAMINE
-- ============================================================

function AttackManager:StartWave(durationSeconds)
	if self.active then
		return 0
	end

	local targets = self:_getTargets()
	if #targets == 0 then
		return 0   -- pole midagi runnata
	end

	-- Laine suurus soltub saare suurusest
	local radius = self.gameState.islandManager
		and self.gameState.islandManager:GetActiveRadius()
		or Constants.IslandExpansion.StartRadius

	local extra = math.max(0, radius - Constants.IslandExpansion.StartRadius)
	local count = math.min(
		CFG.BaseAttackers + extra * CFG.AttackersPerRing,
		CFG.MaxAttackers
	)

	-- AJAS KASVAV OHT: hilisemad runnakud on suuremad ja tugevamad.
	-- Ilma selleta poleks Extract'il motet - jaamine oleks tasuta.
	local threat = 1
	if self.gameState.runManager then
		threat = self.gameState.runManager:GetThreatScale()
	end

	count = math.min(math.floor(count * threat), CFG.MaxAttackers)
	self.threatScale = threat

	self.active = true
	self.waveStartTime = os.clock()
	self.waveDuration = durationSeconds
	self.spawnQueue = count
	self.lastSpawnTime = 0
	self.killed = 0
	self.buildingsLost = 0

	return count
end

function AttackManager:EndWave()
	self.active = false
	self.spawnQueue = 0

	for _, attacker in ipairs(self.attackers) do
		if attacker.model and attacker.model.Parent then
			attacker.model:Destroy()
		end
	end
	self.attackers = {}
end

-- ============================================================
-- RUUNDAJA TEKITAMINE
-- ============================================================

function AttackManager:_spawnAttacker()
	local targets = self:_getTargets()
	if #targets == 0 then
		return nil
	end

	-- Juhuslik suund saare umber
	local angle = math.random() * math.pi * 2
	local radius = self.gameState.islandManager
		and self.gameState.islandManager:GetActiveRadius()
		or Constants.IslandExpansion.StartRadius

	-- Ruundajad ilmuvad SAARE umber, mitte maailma keskpunkti umber
	local origin = self.gameState.origin or Vector3.new()
	local spawnRadius = radius * 7 + CFG.SpawnDistance
	local spawnPos = origin + Vector3.new(
		math.cos(angle) * spawnRadius,
		3,
		math.sin(angle) * spawnRadius
	)

	-- Sihtmark: lahim hoone tekkekohale
	local best, bestDist = nil, math.huge
	for _, t in ipairs(targets) do
		local d = (t.position - spawnPos).Magnitude
		if d < bestDist then
			best, bestDist = t, d
		end
	end

	if not best then
		return nil
	end

	local folder = self:_getFolder()
	if not folder then
		return nil
	end

	local fullSize = Vector3.new(2.2, 2.2, 2.2)

	local model = Instance.new("Part")
	model.Name = "Attacker"
	model.Shape = Enum.PartType.Ball
	model.Size = fullSize * 0.3
	model.Color = Theme.UI.error
	model.Material = Enum.Material.Neon
	model.Anchored = true
	model.CanCollide = false
	model.CanQuery = false
	model.Transparency = 0.6
	model.Position = spawnPos
	model.Parent = folder

	-- Tekke-pop: vaiksest labipaistvast tais suurusesse/nahtavaks
	TweenService:Create(
		model,
		TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Size = fullSize, Transparency = 0}
	):Play()

	self.nextAttackerId = (self.nextAttackerId or 0) + 1

	local attacker = {
		id = self.nextAttackerId,
		model = model,
		health = CFG.AttackerHealth * (self.threatScale or 1),
		maxHealth = CFG.AttackerHealth * (self.threatScale or 1),
		target = best.building,
		lastHitTime = 0,
	}

	table.insert(self.attackers, attacker)
	return attacker
end

-- ============================================================
-- TICK
-- ============================================================

function AttackManager:Tick()
	if not self.active then
		return
	end

	local now = os.clock()
	local dt = Constants.NodeSystem.TickInterval

	-- 1) Tekita jargmine ruundaja
	if self.spawnQueue > 0 and (now - self.lastSpawnTime) >= CFG.SpawnInterval then
		self.lastSpawnTime = now
		if self:_spawnAttacker() then
			self.spawnQueue = self.spawnQueue - 1
		end
	end

	-- 2) Liiguta ruundajaid ja lase neil loua
	for i = #self.attackers, 1, -1 do
		local a = self.attackers[i]

		if a.health <= 0 or not a.model or not a.model.Parent then
			if a.model then
				if a.health <= 0 then
					self:_showBurst(a.model.Position, Theme.UI.error, 4.5)
				end
				a.model:Destroy()
			end
			table.remove(self.attackers, i)
			continue
		end

		-- Sihtmark havis -> vali uus
		if not a.target or a.target.isDestroyed then
			local targets = self:_getTargets()
			if #targets == 0 then
				a.model:Destroy()
				table.remove(self.attackers, i)
				continue
			end
			local best, bestDist = nil, math.huge
			for _, t in ipairs(targets) do
				local d = (t.position - a.model.Position).Magnitude
				if d < bestDist then
					best, bestDist = t, d
				end
			end
			a.target = best.building
		end

		local targetPos = self:_getBuildingPosition(a.target)
		if not targetPos then
			continue
		end

		local toTarget = targetPos - a.model.Position
		local distance = toTarget.Magnitude

		if distance > 4 then
			-- Liigu sihtmargi poole
			local step = math.min(CFG.AttackerSpeed * dt, distance - 4)
			local newPos = a.model.Position + toTarget.Unit * step
			TweenService:Create(
				a.model,
				TweenInfo.new(dt, Enum.EasingStyle.Linear),
				{Position = newPos}
			):Play()
		else
			-- Kohal - loo hoonet
			if (now - a.lastHitTime) >= CFG.AttackerHitInterval then
				a.lastHitTime = now
				self:_flashBuilding(a.target)
				local destroyed = a.target:TakeDamage(CFG.AttackerDamage)
				if destroyed then
					self.buildingsLost = self.buildingsLost + 1
					self:_removeBuildingVisual(a.target)
				end
			end
		end
	end

	-- 3) Defenderid tulistavad
	self:_defendersFire()

	-- 4) Kas laine on labi?
	local timeUp = self.waveDuration and (now - self.waveStartTime) >= self.waveDuration
	local allDead = (#self.attackers == 0 and self.spawnQueue == 0)

	if timeUp or allDead then
		self:EndWave()
	end
end

-- ============================================================
-- DEFENDERITE TULI
-- ============================================================

function AttackManager:_defendersFire()
	if #self.attackers == 0 then
		return
	end

	local hexGrid = self.gameState.hexGrid

	for _, b in pairs(self.gameState.buildings) do
		if b.buildingType == "Defender" and not b.isDestroyed and b.TryFire then
			local defenderPos = self:_getBuildingPosition(b)
			if defenderPos then
				-- Raadius hexides -> studides (hexi labimoot ~6.9)
				local rangeStuds = b:GetDefenseRadius() * 7

				-- Lahim ruundaja raadiuses
				local best, bestDist = nil, math.huge
				for _, a in ipairs(self.attackers) do
					if a.health > 0 and a.model and a.model.Parent then
						local d = (a.model.Position - defenderPos).Magnitude
						if d <= rangeStuds and d < bestDist then
							best, bestDist = a, d
						end
					end
				end

				if best then
					local damage = b:TryFire()
					if damage then
						best.health = best.health - damage
						self:_showTracer(defenderPos, best.model.Position)

						if best.health <= 0 then
							self.killed = self.killed + 1
						else
							-- Vilgu, et tabamus oleks naha
							local pct = best.health / best.maxHealth
							best.model.Transparency = 0.5 * (1 - pct)
						end
					end
				end
			end
		end
	end
end

-- Luhike laserjoon, mis naitab tabamust
function AttackManager:_showTracer(fromPos, toPos)
	local folder = self:_getFolder()
	if not folder then
		return
	end

	local mid = (fromPos + toPos) / 2
	local dist = (toPos - fromPos).Magnitude

	local beam = Instance.new("Part")
	beam.Name = "Tracer"
	beam.Size = Vector3.new(0.25, 0.25, dist)
	beam.CFrame = CFrame.lookAt(mid, toPos)
	beam.Color = Theme.UI.energy
	beam.Material = Enum.Material.Neon
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.Parent = folder

	TweenService:Create(
		beam,
		TweenInfo.new(0.25),
		{Transparency = 1}
	):Play()

	task.delay(0.3, function()
		if beam and beam.Parent then
			beam:Destroy()
		end
	end)
end

-- Laienev, hajuv sfaar - kasutatakse nii runndaja surma kui hoone
-- havimise juures (erinev varv/suurus eristab neid).
function AttackManager:_showBurst(position, color, maxSize)
	local folder = self:_getFolder()
	if not folder then
		return
	end

	local burst = Instance.new("Part")
	burst.Name = "Burst"
	burst.Shape = Enum.PartType.Ball
	burst.Size = Vector3.new(1, 1, 1)
	burst.Position = position
	burst.Color = color
	burst.Material = Enum.Material.Neon
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanQuery = false
	burst.Transparency = 0.2
	burst.Parent = folder

	TweenService:Create(
		burst,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = Vector3.new(maxSize, maxSize, maxSize), Transparency = 1}
	):Play()

	task.delay(0.3, function()
		if burst and burst.Parent then
			burst:Destroy()
		end
	end)
end

-- Luhike varvivilgatus hoonel, kui ta saab tabamuse - kaib labi koik
-- osad (alus + aktsent), et sobida 2-osalise silhuetiga (vt MapGenerator).
function AttackManager:_flashBuilding(building)
	local visual = self:_getBuildingVisual(building)
	if not visual then
		return
	end

	for _, part in ipairs(visual:GetDescendants()) do
		if part:IsA("BasePart") then
			local original = part.Color
			part.Color = Theme.UI.error
			TweenService:Create(part, TweenInfo.new(0.3), {Color = original}):Play()
		end
	end
end

-- Havinud hoone visuaali eemaldamine
function AttackManager:_removeBuildingVisual(building)
	local visual = self:_getBuildingVisual(building)
	if visual then
		if visual.PrimaryPart then
			self:_showBurst(visual.PrimaryPart.Position, Theme.UI.warning, 7)
		end
		visual:Destroy()
	end

	-- Eemalda registrist ja tick-susteemist
	for key, b in pairs(self.gameState.buildings) do
		if b == building then
			self.gameState.buildings[key] = nil
			break
		end
	end
	self.gameState.tickService:UnregisterBuilding(building)
end

-- ============================================================
-- KLIENDILE
-- ============================================================

function AttackManager:GetClientState()
	if not self.active then
		return nil
	end

	-- Ruundajate positsioonid minimapi jaoks.
	-- Ainult X ja Z - minimap on tasapinnaline. `id` laseb kliendil
	-- tapikuid sujuvalt liigutada (mitte iga uuendus umber joonistada),
	-- targetQ/R laseb minimapil esile tosta runnatavat hoonet.
	local positions = {}
	for _, a in ipairs(self.attackers) do
		if a.model and a.model.Parent then
			table.insert(positions, {
				id = a.id,
				x = a.model.Position.X,
				z = a.model.Position.Z,
				health = a.health / a.maxHealth,
				targetQ = a.target and a.target.q or nil,
				targetR = a.target and a.target.r or nil,
			})
		end
	end

	return {
		active = true,
		attackers = #self.attackers,
		incoming = self.spawnQueue,
		killed = self.killed,
		buildingsLost = self.buildingsLost,
		positions = positions,
	}
end

return AttackManager
