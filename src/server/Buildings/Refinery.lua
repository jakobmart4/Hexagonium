--[[
	Refinery.lua
	Töötleb ore't alloyks.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local GameClock = require(game:GetService("ServerScriptService").Core.GameClock)
local BuildingBase = require(script.Parent.BuildingBase)

local Refinery = setmetatable({}, {__index = BuildingBase})
Refinery.__index = Refinery

function Refinery.new(q, r)
	local self = BuildingBase.new("Refinery", q, r)
	setmetatable(self, Refinery)

	self.inputBuffer = 0
	self.outputBuffer = 0
	self.lastProcessTime = GameClock.now()

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
	local now = GameClock.now()

	if now - self.lastProcessTime >= config.OreToAlloyInterval then
		self.lastProcessTime = now

		-- Kordaja = LÄBILASKEVÕIME: 1.1x tarbib ka 1.1x maaki. Varem tõstis
		-- kordaja ainult väljundit ja 1:1:1 ahel läks kaartidega sassi
		-- (maak/alloy kuhjus, 24.09).
		local batch = config.OreToAlloyRate * self:GetProductionMultiplier()

		-- Null Surge efektifaas: toodab ilma sisendit tarbimata (spec 5.6)
		if self:ShouldIgnoreInputs() then
			self.outputBuffer = self.outputBuffer + batch
		else
			local amount = math.min(self.inputBuffer, batch)
			if amount > 0 then
				self.inputBuffer = self.inputBuffer - amount
				self.outputBuffer = self.outputBuffer + amount
			end
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
