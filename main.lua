--------- initialise requirements --------
component = require("component")

-- check if the setting is right --
if not component.list("navigation")() then
	print("Please insert a Navigation upgrade")
	os.exit()
else
	navi = component.navigation
end

if not component.list("robot")() then
	print("Can only be used on Robots")
	os.exit()
else
	r = require("robot")
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

vector = {}
vector.__index = vector

function new(x,y,z) return setmetatable({x=x or 0, y=y or 0, z=z or 0},vector) end
function isVector(t) return getmetatable(t) == vector end
function vector:set(x,y,z)
	if isvector(x) then self.x, self.y, self.z = x, y ,z return end
	self.x, self.y, self.z = x or self.x, y or self.y, z or self.z
	return self
end
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
function getLocation()
	x,y,z = navi.getPosition()
	return new(x,y,z)
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

mapToRobot = {}
mapToRobot[4] = 1
mapToRobot[2] = 2
mapToRobot[5] = 3
mapToRobot[3] = 4

-- create and save the current location and facing
curLocation = getLocation()
facing = mapToRobot[navi.getFacing()]
-- update this when approaching a destination. It's purpose is to be saved in a config file to resume your job.
curTarget = curLocation
-- calibrate your power per move with this code --
--[[
---	startin = computer.energy()
---	robot.forward()
---	endin = computer.energy()
---	print(startin-endin)
]]--
powerConfig = {}
powerConfig.forward = 17.5
powerConfig.up = 15.0
powerConfig.down = 15.0

---------- pre calculating facing directions and movement -----------
dryTurn = {}
-- with modulo % we can get the exact direction but we need to first subtract 1 and add 1 at the end to match the mapping
function dryTurn.main(facing,num) return ((facing + num - 1) % 4) + 1 end
function dryTurn.left(facing) return dryTurn.main(facing,-1) end
function dryTurn.right(facing) return dryTurn.main(facing,1) end
function dryTurn.turn(facing) return dryTurn.main(facing,2) end

dryMove = {
--						    x,y,z
	function(i) return new(-i,0,0) end, -- -x
	function(i) return new(0,0,-i) end, -- -z
	function(i) return new(i,0,0) end,  -- +x
	function(i) return new(0,0,i) end,  -- +z
	function(i) return new(0,i,0) end,  -- +y
	function(i) return new(0,-i,0) end  -- -y
}

----------- Move Functions -----------
move = {}

function move.move(dir,num,specialTask,specialTask2)
	-- walking loop
	for i = 1, num do
		if specialTask then specialTask() end
		-- check if it's possible to move up,down,forward
		local isItForward = dir == "forward"
		if isItForward then sdir = "" else sdir = dir end
		while not r[dir]() do
			-- if it can't move then try to break that block in that direction
			local state, reason = r["swing"..sdir:gsub("^%l",string.upper)]() -- make the direction also uppercase | https://stackoverflow.com/questions/2421695/first-character-uppercase-lua
			if not state then print(reason) end
		end
		if specialTask2 then specialTask2() end
	end
end

-- move and save new position with that move
function move.forward(num) num = num or 1 move.move("forward",num) curLocation = curLocation + dryMove[facing](num) end
function move.up(num) num = num or 1 move.move("up",num) curLocation = curLocation + dryMove[5](num) end
function move.down(num) num = num or 1 move.move("down",num) curLocation = curLocation + dryMove[6](num) end
-- turn functions
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

function move.turnTo(target) move[target - facing]() end

-- special movement with digging -- 
function move.specialDigging() r.swingUp() r.swing() end
function move.humanTunnel(num) num = num or 1 print("walking "..num) move.move("forward",num,move.specialDigging) curLocation = curLocation + dryMove[facing](num) end

---------- Going to Position Functions ------------

pos = {}
pos.verticalFirst = false
pos.selectedForward = move.humanTunnel
pos.selectedUp = move.up
pos.selectedDown = move.down
-- uses global curLocation
-- facingDir prescribes which direction x or y to go first.

function pos.goToX(num)
	if num < 0 then -- if negative
		move.turnTo(1)
		pos.selectedForward(num*-1) -- the dryMove already uses negative so make it positive
	elseif num > 0 then -- if positive
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
	if num < 0 then
		pos.selectedDown(num*-1)
	elseif num > 0 then
		pos.selectedUp(num)
	end
end


function pos.goTo(facingDir,vectorPos)
	curTarget = vectorPos --used for resuming
	local deltaDir = (vectorPos-curLocation):array()
	--print("curLocation: ",curLocation)
	--print("facing:",facing)
	--print("vectorPos: ",vectorPos)
	print(deltaDir[1],deltaDir[2],deltaDir[3])
	local axis = facingDir%2
	-- check if the facingDir is the same axis
	--if not facing%2 == axis then -- is not facing on the same axis
		-- rotate the robot to that direction
	--end
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
start Position / Home = 
0: Pos, Chest Pos, Energy Pos
the rest positions = 
1: Pos, Left Position, Right Position
2:
3:
...
]]--
mappedArea = {}

-- distance between strip mines
mappedArea.stripDistance = 3
-- distance into the left and right strip
mappedArea.stripDistLeft = 5
mappedArea.stripDistRight = 5
-- how many strips to go
mappedArea.strips = 2
-- location of the chest
mappedArea.depositChest = curLocation + dryMove[ dryTurn.left(facing) ](2) -- default it to the left of the start position
mappedArea.depositChestFacing = dryTurn.left(facing)
-- default it to the left and behind of the start pos
mappedArea.energy = curLocation + dryMove[ dryTurn.left(facing) ](2) + dryMove[ dryTurn.turn(facing) ](2) -- move 2 to the left and 2 behind
-- other options
mappedArea.startFacing = facing
mappedArea.startLeft = true
mappedArea.startStrippingAt = 1
-- movement Functions for swapping
mappedArea.SpecialForward = move.humanTunnel
mappedArea.SpecialdUp = move.up
mappedArea.SpecialDown = move.down
mappedArea.DefaultForward = move.forward
mappedArea.DefaultdUp = move.up
mappedArea.DefaultDown = move.down



mappedArea.map = {}

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
		-- init pos
		mappedArea.map[i] = {}
		-- precalculate and save
		tempPosition = tempPosition + dryMove[ mappedArea.startFacing ]( mappedArea.stripDistance )	
		mappedArea.map[i].Pos = tempPosition
		-- with the startFacing, dryturn left and calculate the position with the distance to the left
		mappedArea.map[i].LeftPos = tempPosition + dryMove[ dryTurn.left( mappedArea.startFacing ) ]( mappedArea.stripDistLeft )
		-- same with right
		mappedArea.map[i].RightPos = tempPosition + dryMove[ dryTurn.right( mappedArea.startFacing ) ]( mappedArea.stripDistLeft )
	end
end

function swapFunctions(SpecialActivated)
	if SpecialActivated then
		pos.selectedForward = mappedArea.SpecialForward
		pos.selectedUp = mappedArea.SpecialdUp
		pos.selectedDown = mappedArea.SpecialDown
	else
		pos.selectedForward = mappedArea.DefaultForward 
		pos.selectedUp = mappedArea.DefaultdUp
		pos.selectedDown = mappedArea.DefaultDown
	end
end

function mappedArea.executeJobStrip()
	for i=mappedArea.startStrippingAt, mappedArea.strips do
		-- swap into special movement
		swapFunctions(true)
		-- go the main path strip by strip
		pos.goTo(facing,mappedArea.map[i].Pos)
		
		if mappedArea.startLeft then
			-- go left
			pos.goTo(facing,mappedArea.map[i].LeftPos)
			-- go right
			pos.goTo(facing,mappedArea.map[i].RightPos)
		else
			-- go right
			pos.goTo(facing,mappedArea.map[i].RightPos)
			-- go left
			pos.goTo(facing,mappedArea.map[i].LeftPos)
		end
		-- go back to the main line
		swapFunctions(true)
		pos.goTo(facing,mappedArea.map[i].Pos)
		-- save the current strip number
		mappedArea.startStrippingAt = i -- nice if you want to resume the job or smth
	end
end



function printMap(map)
	for i,content in pairs(map) do
		print(i.." "..tostring(content.Pos).." "..tostring(content.LeftPos).." "..tostring(content.RightPos))
		os.sleep(1)
	end
end

mappedArea.generateMapStrip()
mappedArea.executeJobStrip()
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