@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

dependsOn("shipLib.ks").
dependsOn("navigationLib.ks").

PARAMETER warpFlag IS FALSE, timeBuffer IS 60.

LOCAL node TO NEXTNODE.
LOCAL nodeBurnTime IS burnTime(node:DELTAV:MAG).
LOCAL nodePrograde IS node:DELTAV.


IF verbose PRINT "Node in: " + ROUND(node:ETA) + ", DeltaV: " + ROUND(node:DELTAV:MAG).

FUNCTION waitUntilNode {
	IF warpFlag {
	KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + (node:ETA - nodeBurnTime/2 + 60)).
}
	WAIT UNTIL node:ETA <= (nodeBurnTime/2 + timeBuffer)
LOCK STEERING TO nodePrograde.

notify("Orienting to node").
waitForAlignmentTo(nodePrograde).

WAIT UNTIL node:ETA <= (nodeBurnTime/2).
}

FUNCTION maneuverNodeBurn {
LOCAL done TO FALSE.

//INITIAL DELTAV
LOCAL deltaV0 TO node:DELTAV.
UNTIL DONE {

	stageLogic().

	//RECALCULATE CURRENT MAX_ACCELERATION, AS IT CHANGES WHILE
	//WE BURN THROUGH FUEL
	LOCAL maxAcceleration TO SHIP:MAXTHRUST/SHIP:MASS.

	//debug escape
	IF maxAcceleration = 0 {
		notifyError("No available thrust.").
	} ELSE {
		//THROTTLE IS 100% UNTIL THERE IS LESS THAN 1 SECOND OF TIME LEFT TO BURN
		//WHEN THERE IS LESS THAN 1 SECOND - DECREASE THE THROTTLE LINEARLY
		SET lockedThrottle TO MIN(node:DELTAV:MAG/maxAcceleration, 1).
	}

	//HERE'S THE TRICKY PART, WE NEED TO CUT THE THROTTLE AS SOON AS OUR
	//ND:DELTAV AND INITIAL DELTAV START FACING OPPOSITE DIRECTIONS
	//THIS CHECK IS DONE VIA CHECKING THE DOT PRODUCT OF THOSE 2 VECTORS
	IF VDOT(deltaV0, node:DELTAV) < 0 {
		PRINT "END BURN, REMAIN DV " + ROUND(node:DELTAV:MAG,1) + "M/S, VDOT: " + ROUND(VDOT(deltaV0, node:DELTAV),1).
		SET lockedThrottle TO 0.
		BREAK.
	}

	//WE HAVE VERY LITTLE LEFT TO BURN, LESS THEN 0.1M/S
	IF node:DELTAV:MAG < 0.1 {
		PRINT "FINALIZING BURN, REMAIN DV " + ROUND(node:DELTAV:MAG,1) + "M/S, VDOT: " + ROUND(VDOT(deltaV0,node:DELTAV),1).
		//WE BURN SLOWLY UNTIL OUR NODE VECTOR STARTS TO DRIFT SIGNIFICANTLY FROM INITIAL VECTOR
		//THIS USUALLY MEANS WE ARE ON POINT
		WAIT UNTIL VDOT(deltaV0, node:DELTAV) < 0.5.

		SET lockedThrottle TO 0.
		PRINT "END BURN, REMAIN DV " + ROUND(node:DELTAV:MAG,1) + "M/S, VDOT: " + ROUND(VDOT(deltaV0,node:DELTAV),1).
		SET done TO TRUE.
		WAIT 1.
	}
}

}

FUNCTION executeNode {
	initializeControls().
	waitUntilNode(warpFlag).
	maneuverNodeBurn().
	REMOVE node.
	deinitializeControls().

}
