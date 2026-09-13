--[[
	Defender.lua
	Kaitsetorn, mis tarbib energiat otse Power Core'ist (otsene viide,
	mitte node-põhine ressursivoog). Aktiveerub automaatselt rünnaku ajal.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local BuildingBase = require(script.Parent.BuildingBase)

local Defender = setmetatable({}, {__index = BuildingBase})
Defender.__index = Defender

function Defender.new(q, r)
	local self = BuildingBase.new("Defender", q, r)
	setmetatable(self, Defender)

	self.powerCoreRef = nil
	self.isUnderAttack = false
	self.hasEnergy = true

	self.lastEnergyDrawTime = os.clock()
	self.lastFireTime = os.clock()

	return self
end

function Defender:LinkPowerCore(powerCoreInstance)
	self.powerCoreRef = powerCoreInstance
end

function Defender:SetUnderAttack(underAttack)
	self.isUnderAttack = underAttack
end

function Defender:Tick()
	local config = Constants.Buildings.Defender
	local now = os.clock()

	if not self.powerCoreRef or not self.powerCoreRef:IsOperational() then
		return
	end

	if not self:IsOperational() then
		return
	end

	if now - self.lastEnergyDrawTime >= config.EnergyCostInterval then
		self.lastEnergyDrawTime = now
		local success = self.powerCoreRef:ConsumeEnergy(config.EnergyCostPerTick)
		self.hasEnergy = success
	end
end

-- ============================================================
-- TULISTAMINE
-- AttackManager kutsub seda: kui torn on valmis, tagastab kahju,
-- muidu nil. Nii otsustab sihtmargi AttackManager, mitte torn ise.
-- ============================================================
function Defender:TryFire()
	local config = Constants.Buildings.Defender
	local now = os.clock()

	if not self:IsOperational() then
		return nil
	end

	if not self.powerCoreRef or not self.powerCoreRef:IsOperational() then
		return nil
	end

	if not self.hasEnergy then
		return nil
	end

	if now - self.lastFireTime < config.FireInterval then
		return nil
	end

	self.lastFireTime = now

	-- Mirror World tostab kaitset; kordaja tuleb CardManagerilt
	return config.DefensePoints * self:GetDefenseMultiplier()
end

function Defender:GetDefenseRadius()
	return Constants.Buildings.Defender.DefenseRadius
end

return Defender
