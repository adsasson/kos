@LAZYGLOBAL OFF.




LOCAL timeOfNode IS 0.

//RUNONCEPATH(bootfile).

dependsOn("shipLib.ks").
dependsOn("navigationLib.ks").
dependsOn("shipStats.ks").

FUNCTION waitUntilNode {
	PARAMETER node IS NEXTNODE, shouldWarp IS FALSE, timeBuffer IS 60.
	IF NOT(HASNODE) RETURN.
	SET timeOfNode TO TIME:SECONDS + node:ETA.
	LOCAL LOCK nodePrograde TO node:BURNVECTOR.
	LOCAL nodeBurnTime TO calculateBurnTimeForDeltaV(node:DELTAV:MAG).

	//IF VERBOSE
	PRINT "Node in: " + ROUND(node:ETA) + ", DeltaV: " + ROUND(node:DELTAV:MAG).
	//IF VERBOSE
	PRINT "Burn Start in: " + ROUND(node:ETA - nodeBurnTime/2) + ", BurnTime: " + ROUND(nodeBurnTime).

	waitUntil((timeOfNode - nodeBurnTime/2),shouldWarp,timeBuffer).

	LOCK STEERING TO nodePrograde.

	IF VERBOSE notify("Orienting to node").
	waitForAlignmentTo(nodePrograde).
	IF VERBOSE notify("Completed orientation to node burn vector.").

	WAIT UNTIL (TIME:SECONDS >= (timeOfNode - nodeBurnTime/2)).

	RETURN TRUE.
}

FUNCTION performManeuverNodeBurn {
	PARAMETER node IS NEXTNODE.
	LOCAL done TO FALSE.
	LOCK STEERING TO node:BURNVECTOR.
.
	IF NOT(HASNODE) {PRINT "NO NODE IN FLIGHT PLAN". RETURN.}
	LOCAL oldNodeDeltaV IS node:DELTAV:MAG.
	//INITIAL DELTAV
	LOCAL deltaV0 TO node:DELTAV.
	UNTIL DONE {
		SET oldNodeDeltaV TO node:DELTAV:MAG.
		stageLogic().

		//RECALCULATE CURRENT MAX_ACCELERATION, AS IT CHANGES WHILE
		//WE BURN THROUGH FUEL
		LOCAL maxAcceleration TO SHIP:MAXTHRUST/SHIP:MASS.

		//debug escape
		IF maxAcceleration = 0 {
			IF VERBOSE notifyError("No available thrust.").
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
		//IF node:DELTAV:MAG > oldNodeDeltaV {PRINT "DELTA V INCREASING". BREAK.}
	}

}


FUNCTION executeNode {
	PARAMETER node IS NEXTNODE, shouldWarp IS FALSE, buffer IS 60.
	IF NOT(HASNODE) {PRINT "NO NODE IN FLIGHT PLAN". RETURN.}
	initializeControls().

	IF waitUntilNode(node, shouldWarp, buffer) {
			performManeuverNodeBurn(node).
	}

	REMOVE node.
	LOCK STEERING TO PROGRADE.
	deinitializeControls().

}
