--[[
	GameClock.lua
	Mänguaeg: kõik mänguloogika taimerid (tootmine, Demand, rünnakud,
	run'i kell, kaardid) loevad aega siit, mitte os.clock()-ist. Nii saab
	Studio Play-testis aega kiirendada (2x/3x/5x) ilma, et tasakaal nihkuks:
	TickService tiksub sama palju kordi kiiremini (vt TickService:Start).

	Kiirus on serveri-ülene (kõik saared). Muudetav ainult Studios
	(PlayerActionHandler:HandleSetGameSpeed).
]]

local GameClock = {}

local speed = 1
local anchorReal = os.clock() -- päris aeg viimase kiirusemuutuse hetkel
local anchorGame = anchorReal -- mänguaeg samal hetkel

function GameClock.now()
	return anchorGame + (os.clock() - anchorReal) * speed
end

function GameClock.GetSpeed()
	return speed
end

-- Uus kiirus kehtib alates praegusest hetkest - mänguaeg ei hüppa.
function GameClock.SetSpeed(value)
	anchorGame = GameClock.now()
	anchorReal = os.clock()
	speed = value
	-- Klient (GameSpeed.client.lua) näitab aktiivset nuppu selle järgi
	game:GetService("ReplicatedStorage"):SetAttribute("GameSpeed", value)
end

return GameClock
