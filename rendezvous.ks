@LAZYGLOBAL OFF.

LOCAL targetBody IS TARGET.

RUNONCEPATH(bootfile).

dependsOn("shipLib.ks").
dependsOn("shipStats.ks").
dependsOn("navigationLib.ks").

FUNCTION targetDistanceAtTime {
	PARAMETER tau.
	RETURN ABS(POSITIONAT(TARGET,TIME:SECONDS + tau):MAG - POSITIONAT(SHIP,TIME:SECONDS + tau):MAG).
}

FUNCTION closestApproachTime {
	LOCAL relativeVelocity IS (TARGET:VELOCITY:ORBIT - SHIP:VELOCITY:ORBIT).
	LOCAL targetRetrograde IS -1 * TARGET:DIRECTION:VECTOR.
	LOCAL tau IS (TARGET:DISTANCE / relativeVelocity:MAG).
	LOCAL closestApproach IS 	(TARGET:DISTANCE * SIN(VANG(relativeVelocity,targetRetrograde))).
	//TODO: intercept if too far?
	RETURN tau.
}

FUNCTION killRelativeVelocityBurnDeltaV {
	PARAMETER tau.
	LOCAL relativeVelocityAtTime IS (VELOCITYAT(TARGET,(TIME:SECONDS + tau)):ORBIT - VELOCITYAT(SHIP,(TIME:SECONDS + tau)):ORBIT).
	LOCAL killBurnDeltaV IS (relativeVelocityAtTime:MAG).
	PRINT "killBurnDeltaV " + killBurnDeltaV.
	RETURN killBurnDeltaV.
}

FUNCTION killRelativeVelocity {
	PARAMETER warpFlag IS FALSE, timeBuffer IS 60.

	LOCAL tau IS closestApproachTime().
	PRINT "tau: " + tau.
	LOCAL killBurnDeltaV IS killRelativeVelocityBurnDeltaV(tau).
	LOCAL killRelativeVelocityBurnTime IS burnTime(killBurnDeltaV).
	PRINT "burnTime: " + killRelativeVelocityBurnTime.
	LOCAL timeOfBurn IS (TIME:SECONDS + tau) - killRelativeVelocityBurnTime/2.

	IF warpFlag {
		KUNIVERSE:TIMEWARP:WARPTO(timeOfBurn + timeBuffer).
	}
	LOCK STEERING TO -(TARGET:DIRECTION:VECTOR). //should be retrograde vector in target frame.
	waitForAlignmentTo(-(TARGET:DIRECTION:VECTOR)).

	stageLogic().
	clearscreen.
	 UNTIL TIME:SECONDS >= timeOfBurn {
		 PRINT "Time: " + (timeOfBurn - TIME:SECONDS) AT (0,0).
	 }.
	 SET THROTTLE TO 1.
	 WAIT killRelativeVelocityBurnTime.
	 SET THROTTLE TO 0.
}
