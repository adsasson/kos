@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

dependsOn("shipLib.ks").
dependsOn("shipStats.ks").
dependsOn("navigationLib.ks").

LOCAL targetBody IS TARGET.


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

FUNCTION oldkillRelativeVelocity {
	PARAMETER tau, warpFlag IS FALSE, timeBuffer IS 60.
	LOCAL timeOfClosestApproach IS tau + TIME:SECONDS.
	LOCAL relativeVelocityAtTime IS (VELOCITYAT(TARGET,tau):ORBIT - VELOCITYAT(SHIP,tau):ORBIT).
	PRINT "relativeVelocityAtTime " + ROUND(relativeVelocityAtTime:MAG).
	LOCAL killRelativeVelocityDeltaV IS (relativeVelocityAtTime:MAG).
	//todo: if small enough use rcs and/or limit throttle.
	LOCAL killRelativeVelocityBurnTime IS burnTime(killRelativeVelocityDeltaV).
	PRINT "killRelativeVelocityBurnTime " + killRelativeVelocityBurnTime.
	IF warpFlag {
		KUNIVERSE:TIMEWARP:WARPTO((timeOfClosestApproach - killRelativeVelocityBurnTime/2) + timeBuffer*2).
	}
	LOCK STEERING TO -(TARGET:DIRECTION). //should be retrograde vector in target frame.
	waitForAlignmentTo(-(TARGET:DIRECTION)).

	// stageLogic().
	// WAIT UNTIL (timeOfClosestApproach - killRelativeVelocityBurnTime/2).
	// SET THROTTLE TO 1.
	// WAIT killRelativeVelocityBurnTime.
	// SET THROTTLE TO 0.
}

// FUNCTION testClosestApproachTime {
// 	//RETURN bisectionMethod(targetDistanceAtTime@,0,SHIP:ORBIT:PERIOD,10,25).
// 	//RETURN binarySearch(targetDistanceAtTime@,0,SHIP:ORBIT:PERIOD,10,25).
// 	// PARAMETER closestTime IS TIME:SECONDS.
// 	// LOCAL timeIncrement IS 10.
// 	//
// 	// UNTIL FALSE {
// 	//
// 	// 	IF targetDistanceAtTime(closestTime + timeIncrement) < targetDistanceAtTime(closestTime) {
// 	// 		SET closestTime TO closestTime + timeIncrement.
// 	// 	} ELSE IF  targetDistanceAtTime(closestTime - timeIncrement) < targetDistanceAtTime(closestTime) {
// 	// 		SET closestTime TO closestTime - timeIncrement.
// 	// 	} ELSE {
// 	// 		BREAK.
// 	// 	}
// 	// }
// 	// RETURN closestTime.
//
// 	// LOCAL positionVector IS TARGET:POSITION - SHIP:POSITION.
// 	// LOCAL velocityVector IS TARGET:VELOCITY:ORBIT - SHIP:VELOCITY:ORBIT.
// 	// LOCAL xPosition IS positionVector:X. LOCAL xVelocity IS velocityVector:X.
// 	// LOCAL yPosition IS positionVector:Y. LOCAL yVelocity IS velocityVector:Y.
// 	// LOCAL zPosition IS positionVector:Z. LOCAL zVelocity IS velocityVector:Z.
// 	// LOCAL xTime IS xPosition/xVelocity. IF xTime < 0 {SET xTIME TO 2^64.}
// 	// LOCAL yTime IS yPosition/yVelocity. IF yTime < 0 {SET yTIME TO 2^64.}
// 	// LOCAL zTime IS zPosition/zVelocity. IF zTime < 0 {SET zTIME TO 2^64.}
// 	// LOCAL minTime IS MIN(MIN(MIN(xTime,yTime),MIN(xTime,zTime)),yTime).
// 	// RETURN minTime.
//
// 	LOCAL relativeVelocity IS (TARGET:VELOCITY:ORBIT - SHIP:VELOCITY:ORBIT).
// 	PRINT "relativeVelocity: " + ROUND(relativeVelocity:MAG).
// 	LOCAL targetRetrograde IS -1 * TARGET:DIRECTION:VECTOR.
// 	PRINT "TARGET:DISTANCE: " + TARGET:DISTANCE.
// 	LOCAL tti IS (TARGET:DISTANCE / relativeVelocity:MAG).
// 	//LOCAL relativeVelocityAtTime IS (VELOCITYAT(TARGET,tti):ORBIT - VELOCITYAT(SHIP,tti):ORBIT).
// 	LOCAL closestApproach IS 	(TARGET:DISTANCE * SIN(VANG(relativeVelocity,targetRetrograde))).
// 	PRINT "closestApproachTime: " + ROUND(tti).
// 	PRINT "closestApproachTime, min: " + (tti/60).
// 	PRINT "closestApproach: " + ROUND(closestApproach).
// 	RETURN tti.
//
// }

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
// FUNCTION killRelativeVelocity {
// 	PARAMETER timeToApproach, warpFlag IS FALSE, timeBuffer IS 60.
//
//
// 	LOCAL targetVelocity IS VELOCITYAT(targetBody,timeToApproach):ORBIT.
// 	LOCAL shipVelocity IS VELOCITYAT(SHIP,timeToApproach):ORBIT.
// 	LOCAL targetDeltaV IS ABS(targetVelocity - shipVelocity).
// 	LOCAL killVelocityBurnTime IS burnTime(targetDeltaV).
//
// 	IF warpFlag {
// 		KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + (timeToApproach - killVelocityBurnTime/2) + 300).
// 	}
// 	LOCK STEERING TO -(targetBody:DIRECTION). //should be retrograde vector in target frame.
// 	waitForAlignmentTo(-(targetBody:DIRECTION)).
//
// 	stageLogic().
// 	WAIT UNTIL (TIME:SECONDS + (timeToApproach - killVelocityBurnTime/2)).
// 	SET lockedThrottle TO 1.
// 	WAIT killVelocityBurnTime.
// 	SET lockedThrottle TO 0.
//
// }