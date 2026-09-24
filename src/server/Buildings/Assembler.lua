--[[
	Assembler.lua
	Tarbib alloyd ja toodab upgradePoints'e.

	Punktid EI JÄÄ siia - need deponeeritakse PointBank'i.
	Varem hoidis Assembler neid ise, mis tähendas, et hoone
	hävimisel kadusid ka punktid ja run'i alguses ei olnud
	üldse millegagi ehitada.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local GameClock = require(game:GetService("ServerScriptService").Core.GameClock)
local BuildingBase = require(script.Parent.BuildingBase)

local Assembler = setmetatable({}, {__index = BuildingBase})
Assembler.__index = Assembler

function Assembler.new(q, r)
	local self = BuildingBase.new("Assembler", q, r)
	setmetatable(self, Assembler)

	self.inputBuffer = 0
	self.pointBank = nil        -- seotakse BuildingFactory kaudu
	self.producedThisRun = 0    -- ainult statistika/kuvamise jaoks
	self.lastProcessTime = GameClock.now()

	return self
end

function Assembler:SetPointBank(bank)
	self.pointBank = bank
end

function Assembler:ReceiveInput(amount)
	self.inputBuffer = self.inputBuffer + amount
end

function Assembler:TryAccept(amount)
	self:ReceiveInput(amount)
	return amount
end

function Assembler:Tick()
	if not self:IsOperational() then
		return
	end

	local config = Constants.Buildings.Assembler
	local now = GameClock.now()

	if now - self.lastProcessTime >= config.AlloyConsumptionInterval then
		self.lastProcessTime = now

		local required = config.AlloyConsumptionRate
		local produced = nil

		-- Null Surge efektifaas: toodab ilma sisendit tarbimata (spec 5.6)
		if self:ShouldIgnoreInputs() then
			produced = required * self:GetProductionMultiplier()
		elseif self.inputBuffer >= required then
			self.inputBuffer = self.inputBuffer - required
			produced = required * self:GetProductionMultiplier()
		end

		if produced then
			self.producedThisRun = self.producedThisRun + produced
			if self.pointBank then
				self.pointBank:Deposit(produced)
			end
		end
	end
end

function Assembler:GetInputResourceType()
	return Constants.ResourceTypes.ALLOY
end

return Assembler
