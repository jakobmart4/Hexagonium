--[[
	Refinery.lua
	Töötleb ore't alloyks.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local BuildingBase = require(script.Parent.BuildingBase)

local Refinery = setmetatable({}, {__index = BuildingBase})
Refinery.__index = Refinery

function Refinery.new(q, r)
	local self = BuildingBase.new("Refinery", q, r)
	setmetatable(self, Refinery)

	self.inputBuffer = 0
	self.outputBuffer = 0
	self.lastProcessTime = os.clock()

	return self
end

function Refinery:ReceiveInput(amount)
	self.inputBuffer = self.inputBuffer + amount
end

function Refinery:TryAccept(amount)
	self:ReceiveInput(amount)
	return amount
end

function Refinery:Tick()
	if not self:IsOperational() then
		return
	end

	local config = Constants.Buildings.Refinery
	local now = os.clock()

	if now - self.lastProcessTime >= config.OreToAlloyInterval then
		self.lastProcessTime = now

		local required = config.OreToAlloyRate

		-- Null Surge efektifaas: toodab ilma sisendit tarbimata (spec 5.6)
		if self:ShouldIgnoreInputs() then
			local produced = required * self:GetProductionMultiplier()
			self.outputBuffer = self.outputBuffer + produced
		elseif self.inputBuffer >= required then
			self.inputBuffer = self.inputBuffer - required
			local produced = required * self:GetProductionMultiplier()
			self.outputBuffer = self.outputBuffer + produced
		end
	end
end

function Refinery:DrainOutput(amount)
	local drained = math.min(self.outputBuffer, amount)
	self.outputBuffer = self.outputBuffer - drained
	return drained
end

function Refinery:GetInputResourceType()
	return Constants.ResourceTypes.ORE
end

function Refinery:GetOutputResourceType()
	return Constants.ResourceTypes.ALLOY
end

return Refinery
