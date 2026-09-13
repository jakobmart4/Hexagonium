--[[
	PointBank.lua
	Tsentraalne upgradePoints'ide pank.

	MIKS PANK, MITTE HOONETE SEES:
	Varem elasid punktid Assemblerite sees. Sellel oli kolm viga:
	  1) Run'i alguses pole hooneid -> pole punkte -> ei saa ehitada
	  2) Hoone havimisel kadusid ka tema punktid
	  3) Iga lugeja pidi summeerima koik Assemblerid labi

	Nuud on uks arv uhes kohas. Assembler DEPONEERIB siia.

	KULUTAJAD:
	  - hoonete ehitamine (Constants.BuildCosts)
	  - saare laiendus (Constants.IslandExpansion)
	Nad votavad samast pangast, mis loobki valiku.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)

local PointBank = {}
PointBank.__index = PointBank

function PointBank.new(startingPoints)
	local self = setmetatable({}, PointBank)

	self.points = startingPoints or Constants.Run.StartingPoints

	-- Kogu run'i jooksul TOODETUD punktid. Eraldi saldost, sest
	-- kulutamine ei tohi run'i tasu vahendada.
	self.totalProduced = 0

	return self
end

function PointBank:Get()
	return self.points
end

function PointBank:GetTotalProduced()
	return self.totalProduced
end

-- Assembler kutsub seda
function PointBank:Deposit(amount)
	if amount <= 0 then
		return
	end
	self.points = self.points + amount
	self.totalProduced = self.totalProduced + amount
end

function PointBank:CanAfford(amount)
	return self.points >= amount
end

-- Tagastab true, kui maks onnestus
function PointBank:Spend(amount)
	if amount <= 0 then
		return true
	end
	if self.points < amount then
		return false
	end
	self.points = self.points - amount
	return true
end

-- Lammutamise tagastus. EI suurenda totalProduced'i - see poleks
-- toodang, vaid tagasimakse.
function PointBank:Refund(amount)
	if amount <= 0 then
		return
	end
	self.points = self.points + amount
end

return PointBank
