@LAZYGLOBAL OFF.
RUNONCEPATH("utilLib.ks").

dependsOn("orbitLib.ks").
dependsOn("shipLib.ks").

DECLARE PARAMETER warpFlag IS FALSE.

LOCAL node TO NEXTNODE.
PRINT "Node in: " + ROUND(node:ETA) + ", DeltaV: " + ROUND(node:DELTAV:MAG).

LOCAL nodeBurnTime TO burnTime(node:DELTAV:MAG,SHIP).

//INSERT WARP LOGIC
IF warpFlag {
	KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + (node:ETA - nodeBurnTime/2 + 60)).
}

WAIT UNTIL node:ETA <= (nodeBurnTime/2 + 60).

SAS OFF.
LOCAL nodePrograde TO node:DELTAV.
LOCK STEERING TO nodePrograde.

notify("Orienting to node").
pointTo(nodePrograde).

WAIT UNTIL node:ETA <= (nodeBurnTime/2).

LOCAL currentThrottle TO 0.
LOCK THROTTLE TO currentThrottle.

LOCAL done TO FALSE.

//INITIAL DELTAV
LOCAL deltaV0 TO node:DELTAV.

UNTIL DONE {

	stageLogic().

	//RECALCULATE CURRENT MAX_ACCELERATION, AS IT CHANGES WHILE
	//WE BURN THROUGH FUEL
	LOCAL maxAcc TO SHIP:MAXTHRUST/SHIP:MASS.

	//debug escape
	IF maxAcc = 0 {
		notify("ERROR: No available thrust.").
	} ELSE {
		//THROTTLE IS 100% UNTIL THERE IS LESS THAN 1 SECOND OF TIME LEFT TO BURN
		//WHEN THERE IS LESS THAN 1 SECOND - DECREASE THE THROTTLE LINEARLY
		SET currentThrottle TO MIN(node:DELTAV:MAG/maxAcc, 1).
	}

	//HERE'S THE TRICKY PART, WE NEED TO CUT THE THROTTLE AS SOON AS OUR
	//ND:DELTAV AND INITIAL DELTAV START FACING OPPOSITE DIRECTIONS
	//THIS CHECK IS DONE VIA CHECKING THE DOT PRODUCT OF THOSE 2 VECTORS
	IF VDOT(deltaV0, node:DELTAV) < 0 {
		PRINT "END BURN, REMAIN DV " + ROUND(node:DELTAV:MAG,1) + "M/S, VDOT: " + ROUND(VDOT(deltaV0, node:DELTAV),1).
		SET currentThrottle TO 0.
		BREAK.
	}

	//WE HAVE VERY LITTLE LEFT TO BURN, LESS THEN 0.1M/S
	IF node:DELTAV:MAG < 0.1 {
		PRINT "FINALIZING BURN, REMAIN DV " + ROUND(node:DELTAV:MAG,1) + "M/S, VDOT: " + ROUND(VDOT(deltaV0,node:DELTAV),1).
		//WE BURN SLOWLY UNTIL OUR NODE VECTOR STARTS TO DRIFT SIGNIFICANTLY FROM INITIAL VECTOR
		//THIS USUALLY MEANS WE ARE ON POINT
		WAIT UNTIL VDOT(deltaV0, node:DELTAV) < 0.5.

		SET currentThrottle TO 0.
		PRINT "END BURN, REMAIN DV " + ROUND(node:DELTAV:MAG,1) + "M/S, VDOT: " + ROUND(VDOT(deltaV0,node:DELTAV),1).
		SET done TO TRUE.
	}
}

UNLOCK STEERING.
UNLOCK THROTTLE.
WAIT 1.

//WE NO LONGER NEED THE MANEUVER NODE
REMOVE node.

//SET THROTTLE TO 0 JUST IN CASE.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
