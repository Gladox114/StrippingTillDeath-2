# StrippingTillDeath-2
StrippingTillDeath 2 is written out of scratch for OpenComputers but uses a similiar logic like in StrippingTillDeath

(new) It can now go to the Chest position and saved facing direction when the Inventory is full


### There are config variables that you can change:

under mappedArea:
* stripDistance
* stripDistLeft
* stripDistRight
* strips
* startLeft (bool)
* depositChest (vector3 location)
* depositChestFacing (in which direction to face for the chest)

### you can also resume your job with these variables:

under mappedArea:
* startStrippingAt (number of the strips it made to resume there)
* lastPosition
* lastFacing

For digging it uses dynamic functions meaning that
you can create custom functions that check for something specific each move
or it makes extra steps or extra digs to create bigger tunnels
