--------- initialise requirements --------
local component = require("component")
local computer = require("computer")
local navi = nil
local r = nil
local inv = nil
local serial=require("serialization")
--[[
-- check if the setting is right --
if not component.list("navigation")() then
	print("Please insert a Navigation upgrade")
	os.exit()
else
	navi = component.navigation
end]]

if not component.list("robot")() then
	print("Can only be used on Robots")
	os.exit()
else
	r = require("robot")
end

if not component.list("inventory_controller")() then
	print("Inventory upgrade is missing. It's still possible to use it without but one function needs to be changed")
	os.exit()
else
	inv = component.inventory_controller
end

function myerrorhandler( err )
	print("Error:", err)
end

----------- Vector Library ---------------

--[[
	https://github.com/themousery/vector.lua/blob/master/vector.lua
    Copyright (c) 2018 themousery
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:
    
    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.
]]--

local vector = {}
vector.__index = vector
local function abs(a)
	if a < 0 then return -a end
	return a
end
local function new(x,y,z) return setmetatable({x=x or 0, y=y or 0, z=z or 0},vector) end
local function isVector(t) return getmetatable(t) == vector end
function vector:set(x,y,z)
	if isVector(x) then self.x, self.y, self.z = x, y ,z return end
	self.x, self.y, self.z = x or self.x, y or self.y, z or self.z
	return self
end
function vector:abs() return new(abs(self.x),abs(self.y),abs(self.z)) end
-- meta function to add vectors together
function vector.__add(a,b) return new(a.x+b.x, a.y+b.y, a.z+b.z) end
-- meta function to subtract vectors
function vector.__sub(a,b) return new(a.x-b.x, a.y-b.y, a.z-b.z) end
-- meta function to check if vectors have the same values
function vector.__eq(a,b) return a.x==b.x and a.y==b.y and a.z==b.z end
-- return x and y of vector as a regular array
function vector:array() return {self.x, self.y, self.z} end
-- return x and y of vector, unpacked from table
function vector:unpack() return self.x, self.y, self.z end
-- meta function to change how vectors appear as string
-- ex: print(vector(2,8)) - this prints '(2,8)'
function vector:__tostring() return "("..self.x..", "..self.y..", "..self.z..")" end
  

-- returns a vector of the current Position
local function getLocation()
	--x,y,z = navi.getPosition()
	--return new(x,y,z)
	return new()
end

---------------- config -----------------

--[[
Robot			 Map
-x = 1			-x = 4
-z = 2			-z = 2
+x = 3			+x = 5
+z = 4			+z = 3
up = 5
down = 6
]]

local mapToRobot = {}
mapToRobot[4] = 1
mapToRobot[2] = 2
mapToRobot[5] = 3
mapToRobot[3] = 4

-- create and save the current location and facing
local curLocation = getLocation()
--local facing = mapToRobot[navi.getFacing()]
local facing = 1
-- update this when approaching a destination. It's purpose is to be saved in a config file to resume your job.
local curTarget = curLocation
-- colors
local colors = {}
colors.GoingToChest = 0x90662A
colors.Digging = 0x535ABE
colors.walking = 0x8A86BE
colors.GoingToRecharge = 0x17BE91
colors.obsticle = 0xBE175D
-- calibrate your power per move with this code --
--[[
---	startin = computer.energy()
---	robot.forward()
---	endin = computer.energy()
---	print(startin-endin)
]]--
local powerConfig = {}
powerConfig.forward = 17.5
powerConfig.up = 15.0
powerConfig.down = 15.0
powerConfig.dig = 0.35687499888081 -- unnecessary
powerConfig.minimum = 200.0
-- how often to check if the energy is full while recharging
powerConfig.updateInterval = 2
-- when recharging, your battery can't get 100% charged. Mostly a 0.6 charge can be remaining for the 100% that you will never achieve
powerConfig.rechargeTolerance = 3
---------- pre calculating facing directions and movement -----------
local dryTurn = {}
-- with modulo % we can get the exact direction but we need to first subtract 1 and add 1 at the end to match the mapping
function dryTurn.main(facing,num) return ((facing + num - 1) % 4) + 1 end
function dryTurn.left(facing) return dryTurn.main(facing,-1) end
function dryTurn.right(facing) return dryTurn.main(facing,1) end
function dryTurn.turn(facing) return dryTurn.main(facing,2) end

local dryMove = {    --    x,y,z
	function(i) return new(-i,0,0) end, -- -x
	function(i) return new(0,0,-i) end, -- -z
	function(i) return new(i,0,0) end,  -- +x
	function(i) return new(0,0,i) end,  -- +z
	function(i) return new(0,i,0) end,  -- +y
	function(i) return new(0,-i,0) end  -- -y
}

------------ Inventory Functions ------------

local invLib = {}
invLib.inventorySize = r.inventorySize()
invLib.keepingList = { "minecraft:torch" }
-- functions that checks if there is still space
function invLib.space()
	for i=1,invLib.inventorySize do
		if r.count(i) < 1 then
			return true -- there is space
		end
	end
	return false
end

-- function that compares if the block fits in the inventory
function invLib.canBeStacked(dir)
	-- for every slot
	for i=1,invLib.inventorySize do
		-- check if the block forward, up or down is the same with the current slot
		r.select(i)
		if r["compare"..dir]() then
			-- if the slot isn't full then return true
			if r.count() < 64 then
				return true
			end
		end
	end
	return false
end

-- function that checks if it's possible to store that block
function invLib.doesItFit(dir)
	if invLib.space() then return true end
	if invLib.canBeStacked(dir) then return true end
	return false
end

-- pre define the function. It is in the bottom of the script
invLib.goEmptyYourself = function() end

function invLib.drop(dir)
	local state, reason = r["drop"..dir]()
	-- it will repeat except if the state is false AND there is no reason
	while state or reason do
		-- if there is a reason print it
		if reason then print("Can't drop because "..reason) end
		-- try to drop it again
		state, reason = r["drop"..dir]()
	end
end

-- checks if the slot contains an unallowed item
function invLib.checkKeepList(slot)
	for z,name in pairs(invLib.keepingList) do
		local currentItem = inv.getStackInInternalSlot(slot)
		if currentItem then
			if currentItem["name"] == name then
				return false
			end
		end
	end
	return true
end

-- drops the whole inventory and checks for items that should be kept
function invLib.emptyInventory()
	-- for every slot
	for i=1,invLib.inventorySize do
		-- for every keep-item, compare it with the current slected one and proceed if it's not in the list
		if invLib.checkKeepList(i) then
			-- drop the item slot
			r.select(i)
			invLib.drop("") -- drop forward
		end
	end
end

------------- Digging Functions -------------
local dig = {}
function dig.dig(dir)
	-- if the block fits into the inventory then dig that block
	if invLib.doesItFit(dir) then
		return r["swing"..dir]()
	end
	-- else empty itself to the chest and come back
	invLib.goEmptyYourself()
	-- dig that block
	return r["swing"..dir]()
end
function dig.swing() return dig.dig("") end
function dig.swingUp() return dig.dig("Up") end
function dig.swingDown() return dig.dig("Down") end

----------- Move Functions -----------
local move = {}

function move.move(dir,num,specialTask,specialTask2)
	-- change the forward string to a blank string
	if dir == "forward" then sdir = "" else sdir = dir end
	-- walking loop
	for i = 1, num do
		-- execute a custom function before moving a block
		if specialTask then specialTask() end
		-- save the current light color
		local originalColor = r.getLightColor()
		-- check if it's possible to move up,down,forward
		while not r[dir]() do
			-- change color
			r.setLightColor(colors.obsticle)
			-- if it can't move then try to break that block in that direction
			local state, reason = r["swing"..sdir:gsub("^%l",string.upper)]() -- make the direction also uppercase | https://stackoverflow.com/questions/2421695/first-character-uppercase-lua
			if not state then print(reason) end
		end
		-- reapply the last color
		r.setLightColor(originalColor)
		-- execute a custom function at the end of moving a block
		if specialTask2 then specialTask2() end
	end
end

-- move and save new position with that move
function move.forward(num) num = num or 1 move.move("forward",num) curLocation = curLocation + dryMove[facing](num) end
function move.up(num) num = num or 1 move.move("up",num) curLocation = curLocation + dryMove[5](num) end
function move.down(num) num = num or 1 move.move("down",num) curLocation = curLocation + dryMove[6](num) end
-- turn and save the new facing direction
function move.turnLeft() r.turnLeft() facing = dryTurn.left(facing) end
function move.turnRight() r.turnRight() facing = dryTurn.right(facing) end
function move.turn() r.turnLeft() r.turnLeft() facing = dryTurn.turn(facing) end
function move.turn2() r.turnRight() r.turnRight() facing = dryTurn.turn(facing) end
-- chached turn functions mapped to facing --
move[1] = move.turnRight
move[-1] = move.turnLeft
move[-2] = move.turn -- turn 180
move[2] = move.turn2 -- turn 180 but into the right direction | just for the swag
move[3] = move[-1] -- turnLeft
move[-3] = move[1] -- turnRight
move[0] = function() return end -- do nothing
-- turn to the new given direction
function move.turnTo(target) move[target - facing]() end

-- special movement with digging --
function move.specialDigging() dig.swingUp() dig.swing() end
function move.specialDigging2() dig.swingUp() end
function move.humanTunnel(num) num = num or 1 move.move("forward",num,move.specialDigging,move.specialDigging2) curLocation = curLocation + dryMove[facing](num) end

---------- Going to Position Functions ------------

local pos = {}
pos.verticalFirst = false
pos.selectedForward = move.humanTunnel
pos.selectedUp = move.up
pos.selectedDown = move.down
-- uses global curLocation
-- facingDir prescribes which direction x or y to go first.

function pos.goToX(num)
	if num < 0 then -- if negative walk in -X
		move.turnTo(1)
		pos.selectedForward(num*-1) -- the dryMove already uses negative so make it positive to prevent having a wrong number at the end
	elseif num > 0 then -- if positive walk in X
		move.turnTo(3)
		pos.selectedForward(num)
	end
end

function pos.goToZ(num)
	if num < 0 then
		move.turnTo(2)
		pos.selectedForward(num*-1)
	elseif num > 0 then
		move.turnTo(4)
		pos.selectedForward(num)
	end
end

function pos.goToY(num)
	if num < 0 then -- if negative walk Down
		pos.selectedDown(num*-1)
	elseif num > 0 then -- if Positive walk Up
		pos.selectedUp(num)
	end
end

-- uses all the three above functions to walk to a 3D vector position
function pos.goTo(facingDir,vectorPos)
	curTarget = vectorPos --used for resuming
	local deltaDir = (vectorPos-curLocation):array()
	-- cool to look at
	print(deltaDir[1],deltaDir[2],deltaDir[3])
	-- if it's an odd number then it's facing X
	local axis = facingDir%2
	-- check if it needs to go vertical first
	if pos.verticalFirst then -- Y
		pos.goToY(deltaDir[2])
	end
	if axis == 1 then -- X -> Z
		pos.goToX(deltaDir[1])
		pos.goToZ(deltaDir[3])
	else -- Z -> X
		pos.goToZ(deltaDir[3])
		pos.goToX(deltaDir[1])
	end
	if not pos.verticalFirst then -- Y
		pos.goToY(deltaDir[2])
	end
end


-------------- Mapping ---------------
--[[
= start Position / Home =
0: Pos, Chest Pos, Energy Pos
= the rest positions =
1: Pos, Left Position, Right Position
2:
3:
...
]]--
local mappedArea = {}
 
-- distance between strip mines
mappedArea.stripDistance = 3
-- distance into the left and right strip
mappedArea.stripDistLeft = 2
mappedArea.stripDistRight = 2
-- how many strips to go
mappedArea.strips = 100
-- location of the chest
mappedArea.depositChest = curLocation + dryMove[ dryTurn.left(facing) ](2) -- default it 2 to the left of the start position
mappedArea.depositChestFacing = dryTurn.left(facing)
-- default it to the left and behind of the start pos
mappedArea.energy = curLocation + dryMove[ dryTurn.left(facing) ](2) + dryMove[ dryTurn.turn(facing) ](2) -- move 2 to the left and 2 behind
-- other options
mappedArea.startFacing = facing
mappedArea.startLeft = true
-- movement Functions for swapping
mappedArea.SpecialForward = move.humanTunnel
mappedArea.SpecialdUp = move.up
mappedArea.SpecialDown = move.down
mappedArea.DefaultForward = move.forward
mappedArea.DefaultdUp = move.up
mappedArea.DefaultDown = move.down
-- cache and resume
mappedArea.startStrippingAt = 1
mappedArea.currentStage = 0
mappedArea.lastPosition = curLocation
mappedArea.lastFacing = facing
-- cache
mappedArea.swappedFunctions = false


mappedArea.map = {}

function mappedArea.goToMainPath(facing)
	-- go to the current layer main-pos to go the main path/hall: mappedArea.startStrippingAt variable gets updated every strip so use it to first go the main path
	pos.goTo(facing, mappedArea.map[ mappedArea.currentStage ].Pos)
end

function mappedArea.cachePosition()
	mappedArea.lastPosition = curLocation
	mappedArea.lastFacing = facing
end

function mappedArea.goToCachedPosition()
	pos.goTo(facing, mappedArea.lastPosition)
	move.turnTo( mappedArea.lastFacing )
end

-- used while strip mining
function mappedArea.goToStartPosition()
	-- go to the main path
	mappedArea.goToMainPath(facing)
	-- then go to the start Position
	pos.goTo(facing, mappedArea.map[0].Pos)
	-- set the current stage to start Position
	mappedArea.currentStage = 0
end

function mappedArea.goToChest()
	-- change color
	r.setLightColor(colors.GoingToChest)
	-- go to the start Position
	mappedArea.goToStartPosition()
	-- then go to the chest
	pos.goTo(facing, mappedArea.map[0].Chest)
	-- turn to the chest
	move.turnTo( mappedArea.depositChestFacing )
end

function mappedArea.goToEnergy()
	-- change color
	r.setLightColor(colors.GoingToRecharge)
	-- go to the start Position
	mappedArea.goToStartPosition()
	-- then go to the Energy spot
	pos.goTo(facing, mappedArea.map[0].Energy)
end

function mappedArea.returnToJob()
	-- change color
	r.setLightColor(colors.walking)
	-- go the main path
	mappedArea.goToMainPath(facing)
	-- go to the last layer main-pos
	pos.goTo(facing, mappedArea.map[ mappedArea.startStrippingAt ].Pos)
	-- set the current stage
	mappedArea.currentStage = mappedArea.startStrippingAt
	-- change colors
	r.setLightColor(colors.Digging)
	-- go to the last-position and face to last-facing
	mappedArea.goToCachedPosition()
end

function mappedArea.swapFunctions(SpecialActivated)
	if SpecialActivated then
		-- change color
		r.setLightColor(colors.Digging)
		-- change functions
		pos.selectedForward = mappedArea.SpecialForward
		pos.selectedUp = mappedArea.SpecialdUp
		pos.selectedDown = mappedArea.SpecialDown
		-- change state
		mappedArea.swappedFunctions = true
	else
		-- change color
		r.setLightColor(colors.walking)
		-- change functions
		pos.selectedForward = mappedArea.DefaultForward
		pos.selectedUp = mappedArea.DefaultdUp
		pos.selectedDown = mappedArea.DefaultDown
		-- change state
		mappedArea.swappedFunctions = false
	end
end

-- function that tries to go back at home to empty itself
invLib.goEmptyYourself = function(DoNotreturnToJob,DoNotCache)
	if not DoNotCache then
		-- while on the job, save the last position and facing from the job
		mappedArea.cachePosition()
		-- save last swapFunction state
		local lastSwapState = mappedArea.swappedFunctions
	end
	-- disable special functions
	mappedArea.swapFunctions(false)
	-- go to the chest and face to it
	mappedArea.goToChest()
	-- empty the inventory
	invLib.emptyInventory()
	-- go back to the job
	if not DoNotreturnToJob then mappedArea.returnToJob() end
	-- change functions to the last state
	if not DoNotCache then mappedArea.swapFunctions(lastSwapState) end
end

-- returns the vector Pos
function mappedArea.getChest()
	-- if it's a string return the waypoint with that name
	if type(mappedArea.chest) == "string" then
		print("not implemented yet")
	else
		return mappedArea.depositChest
	end
end
function mappedArea.getEnergy()
	-- if it's a string return the waypoint with that name
	if type(mappedArea.chest) == "string" then
		print("not implemented yet")
	else
		return mappedArea.energy
	end
end

-------- Pre calculate energy consumption ---------

local energy = {}
-- add all vector positions with x and z together
-- add all y together
-- multiply powerConfig.forward with the sum of all vectors of x and z
-- multply powerConfig.up with the sum of all vectors of y
-- add them all together and compare them to the current energy state if it's possible to go home or to the destination

function energy.sumOfAllVectors(vecList)
	local vecSum = new(0,0,0)
	-- add all vectors together
	for _,vec in pairs(vecList) do vecSum = vecSum + vec:abs() end
	-- convert the vector into an Array/Table
	vecSum = vecSum:array()
	-- calculate the power Consumption for horizontal moves
	local energyConsumption = (vecSum[1]+vecSum[3]) * powerConfig.forward
	-- calculate and add the power Consumption for vertical moves
	energyConsumption = energyConsumption + vecSum[2] * powerConfig.up

	return energyConsumption
end

function energy.hitsMinimum(energyToGoHome)
	print("energyToGoHome:"..energyToGoHome)
	print("energy:".. computer.energy())
	print("remaining:"..computer.energy() - energyToGoHome)
	if (computer.energy() - energyToGoHome) > powerConfig.minimum then
		return false
	end
	return true
end

-- used to predict if it's even worth to go back
function energy.calcReturnToJob()
	
end
-- used to know when your remaining energy is really close to die if returning to home
function energy.calcToHome()
	local vecList = {}
	-- going to the main path
	vecList[1] = mappedArea.map[ mappedArea.currentStage ].Pos - curLocation
	-- going to the startPosition from the main path
	vecList[2] = mappedArea.map[0].Pos - mappedArea.map[ mappedArea.currentStage ].Pos
	-- going to the energy from the startPosition
	vecList[3] = mappedArea.map[0].Energy - mappedArea.map[0].Pos
	-- for debugging
	for i,v in pairs(vecList) do
		file = io.open("calcToHome.log","w")
		file:write(serial.serialize(vecList))
		file:close()
	end
	-- return if it's below it's minimum Energy mark
	return energy.hitsMinimum( energy.sumOfAllVectors(vecList) )
end

function energy.isRecharged()
	local chargeRemaining = computer.maxEnergy() - computer.energy()
	-- it's charged when the remaining charge is below the tolerance
	if chargeRemaining < powerConfig.rechargeTolerance then
		return true
	end
	print("Charge Remaining: "..chargeRemaining)
	return false
end

function energy.recharge()
	-- save the current Position
	mappedArea.cachePosition()
	-- go to the energy spot
	mappedArea.goToEnergy()
	-- wait till it's recharged
	print("Recharging...")
	while not energy.isRecharged() do
		os.sleep(powerConfig.updateInterval)
	end
	print("Done Recharging")
end

-------- generate map Functions ---------

function mappedArea.generateMapStrip()
	local startPosition = curLocation
	-- the start position can be pre defined or here be here initialized with the config
	if not mappedArea.map[0] then
		mappedArea.map[0] = {}
		mappedArea.map[0].Pos = startPosition
		mappedArea.map[0].Chest = mappedArea.getChest()
		mappedArea.map[0].Energy = mappedArea.getEnergy()
	end
	-- generate the map
	local tempPosition = startPosition
	for i = 1,mappedArea.strips do
		-- init table
		mappedArea.map[i] = {}
		-- precalculate the strip positions and save them to the table
		tempPosition = tempPosition + dryMove[ mappedArea.startFacing ]( mappedArea.stripDistance )
		mappedArea.map[i].Pos = tempPosition
		-- with the startFacing, dryturn left and calculate the position with the distance to the left
		mappedArea.map[i].LeftPos = tempPosition + dryMove[ dryTurn.left( mappedArea.startFacing ) ]( mappedArea.stripDistLeft )
		-- same with right
		mappedArea.map[i].RightPos = tempPosition + dryMove[ dryTurn.right( mappedArea.startFacing ) ]( mappedArea.stripDistLeft )
	end
end

function mappedArea.goToMainLine(i)
	-- disable special digging because it goes back
	mappedArea.swapFunctions(false)
	-- go back to the main line
	pos.goTo(facing,mappedArea.map[i].Pos)
	-- continue with special functions
	mappedArea.swapFunctions(true)
end

function mappedArea.executeJobStrip()
	for i=mappedArea.startStrippingAt, mappedArea.strips do
		-- swap into special movement
		mappedArea.swapFunctions(true)
		-- go the main path strip by strip (it visits a new strip so it digs)
		pos.goTo(facing,mappedArea.map[i].Pos)
		-- set the current stage
		mappedArea.startStrippingAt = i -- nice if you want to resume the job or smth
		mappedArea.currentStage = i
		-- check if it should start left or right
		if mappedArea.startLeft then
			-- go left
			pos.goTo(facing,mappedArea.map[i].LeftPos)
			-- go back to the main line
			mappedArea.goToMainLine(i)
			-- go right
			pos.goTo(facing,mappedArea.map[i].RightPos)
		else
			-- go right
			pos.goTo(facing,mappedArea.map[i].RightPos)
			-- go back to the main line
			mappedArea.goToMainLine(i)
			-- go left
			pos.goTo(facing,mappedArea.map[i].LeftPos)
		end
		-- go back to the main line
		mappedArea.goToMainLine(i)
		-- check if it has enough Power to go back at home
		if energy.calcToHome() then
			energy.recharge()
			invLib.goEmptyYourself(true,true)
			
		end
		-- save the current strip number
		--mappedArea.startStrippingAt = i -- nice if you want to resume the job or smth
	end
end



local function printMap(map)
	for i,content in pairs(map) do
		print(i.." "..tostring(content.Pos).." "..tostring(content.LeftPos).." "..tostring(content.RightPos))
		os.sleep(1)
	end
end

mappedArea.generateMapStrip()
mappedArea.executeJobStrip()
invLib.goEmptyYourself(true)
pos.goTo( facing, mappedArea.map[0].Pos )


--print(curLocation)
--print(dryMove[2](-5))
--print(facing)
--print(curLocation+dryMove[2](-5))
--printMap(mappedArea.map)

--[[
print("curLocation",curLocation)
print("facing",facing)
pos.goTo(facing,mappedArea.map[1].Pos)
print("curLocation",curLocation)
print("facing",facing)
pos.goTo(facing,mappedArea.map[1].LeftPos)
print("curLocation",curLocation)
print("target",mappedArea.map[1].LeftPos)
print("facing",facing)
]]