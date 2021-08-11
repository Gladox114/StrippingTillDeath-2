# StrippingTillDeath-2
StrippingTillDeath 2 is written out of scratch for OpenComputers but uses a similiar logic like in StrippingTillDeath

## What can it do?

It Stripmines custom strips. Meaning that you can change the length in any direction and amount of strips. You can also change positions dynamically and hard positions.

Dynamic positions are offset positions from the robot itself. Right now the chest is left of the Robot and the strip is infront of the Robot but this can be changed regardless of the Robots position and direction making it then a Hard position. It can be used with a Navigation Map or by manually typing in the real world/custom positions and facing direction.

If the Robot is full it will empty itself and if it barely manages to go home it will notice that and recharge itself. On every strip it calculates the energy consumption to go Home.

### There are config variables that you can change:

under mappedArea:
* stripDistance
* stripDistLeft
* stripDistRight
* strips
* startLeft (bool)
* depositChest (vector3 location)
* depositChestFacing (in which direction to face for the chest)
* energy (vector3 location)

### you can also resume your job with these variables:

under mappedArea:
* startStrippingAt (number of the strips it made to resume there)
* lastPosition
* lastFacing



### change colors for each task
under colors:
* GoingToChest
* Digging
* walking
* GoingToRecharge
* obsticle


For digging it uses dynamic functions meaning that
you can create custom functions that check for something specific each move
or it makes extra steps or extra digs to create bigger tunnels
