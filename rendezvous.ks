@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

dependsOn("shipLib.ks").

LOCAL targetBody IS TARGET.

FUNCTION closestApproachTime {
	PARAMETER closestApproachDistance IS 5000, startingTimeIncrement IS 10000.
	LOCAL timeIncrement IS startingTimeIncrement.
	LOCAL tau IS TIME:SECONDS.
	LOCAL oldTargetDistance IS ABS(POSITIONAT(targetBody,tau):MAG - POSITIONAT(SHIP,tau):MAG).
	LOCAL newTargetDistance IS ABS(POSITIONAT(targetBody,(tau + timeIncrement)):MAG -
	POSITIONAT(SHIP, (tau + timeIncrement)):MAG).

	UNTIL timeIncrement < 10 {
		IF newTargetDistance <= oldTargetDistance { //old solution is better than new solution
			SET timeIncrement TO timeIncrement/2. //decrease time increment by factor of 10.
			SET oldTargetDistance TO newTargetDistance.
		} ELSE {
			SET tau TO tau + timeIncrement.
		}
		SET newTargetDistance TO ABS(POSITIONAT(targetBody,(tau + timeIncrement)):MAG -
		POSITIONAT(SHIP, (tau + timeIncrement)):MAG).
	}
	IF ABS(oldTargetDistance) <= closestApproachDistance {
		RETURN tau.
	} ELSE {
		notify("Closest approach to " + targetBody + " is " + ROUND(ABS(oldTargetDistance),2) +
		" which is greater than " + closestApproachDistance).
		RETURN tau.
	}
}
FUNCTION targetDistanceAtTime {
	PARAMETER tau.
	RETURN ABS(POSITIONAT(TARGET,TIME:SECONDS + tau):MAG - POSITIONAT(SHIP,TIME:SECONDS + tau):MAG).
}
//
// FUNCTION testClosestApproachTime {
// 	PARAMETER closestApproachDistance IS 5000, startingTimeIncrement IS 10000.
// 	LOCAL timeIncrement IS startingTimeIncrement.
// 	LOCAL tau IS TIME:SECONDS.
// 	LOCAL closestDistance IS targetDistanceAtTime(tau).
//
// 	// ship ----->bd(t - x) ------> Target(t) --------> td(t + x).
// 	//get current target distance
// 	LOCAL bottomTime IS 0.
// 	LOCAL topTime IS SHIP:ORBIT:PERIOD.
// 	LOCAL midTime IS (topTime - bottomTime)/2.
// 	LOCAL bottomTargetDistance IS targetDistanceAtTime(bottomTime).
// 	LOCAL topTargetDistance IS targetDistanceAtTime(topTime).
// 	IF bottomTargetDistance > topTargetDistance {
// 		LOCAL temp IS bottomTime.
// 		SET bottomTime TO topTime.
// 		SET topTime TO temp.
// 		SET bottomTargetDistance TO targetDistanceAtTime(bottomTime).
// 		SET topTargetDistance TO targetDistanceAtTime(topTime).
// 		SET midTime TO -midTime.
// 	}
// 	LOCAL midTargetDistance IS (topTargetDistance - bottomTargetDistance)/2.
//
// 	PRINT "STARTING DISTANCE: MID: " + ROUND(midTargetDistance) + " TOP: " + ROUND(topTargetDistance) + " BOTTOM: " + ROUND(bottomTargetDistance).
// 	UNTIL (topTime - bottomTime) < 10 {
// 		PRINT "DEBUG MID TIME: " + ROUND(midTime).
// 		IF midTargetDistance < closestDistance {// set bottom to mid
// 			PRINT "MID CLOSER THAN CLOSEST".
// 			SET bottomTime TO midTime.
// 			SET closestDistance TO midTargetDistance.
// 			PRINT "BOTTOM: " + ROUND(bottomTime).
// 			PRINT "TOP: " + ROUND(topTime).
// 			PRINT "CLOSEST: " + ROUND(closestDistance).
// 		} ELSE { //set top to mid
// 			PRINT "MID FARTHER THAN CLOSEST".
//
// 			SET topTime TO midTime.
// 			PRINT "BOTTOM: " + ROUND(bottomTime).
// 			PRINT "TOP: " + ROUND(topTime).
// 			PRINT "CLOSEST: " + ROUND(closestDistance).
// 		}
// 		PRINT "//////////////////////////////////////".
// 		SET midTime TO (topTime - bottomTime)/2.
// 		SET bottomTargetDistance TO targetDistanceAtTime(bottomTime).
// 		SET topTargetDistance TO targetDistanceAtTime(topTime).
// 		SET midTargetDistance TO (topTargetDistance - bottomTargetDistance)/2.
// 	}
// 	PRINT "RESULT IS: " + ROUND(topTime - bottomTime).
// }

FUNCTION bisectionMethod {
	PARAMETER f, endpointA, endpointB, tolerance, maximumIterations.
	// CONDITIONS: a < b, either f(a) < 0 and f(b) > 0 or f(a) > 0 and f(b) < 0
	// OUTPUT: value which differs from a root of f(x)=0 by less than TOL
	LOCAL midPoint IS (endpointA + endpointB)/2.
	LOCAL n IS 1.
	UNTIL (n >= maximumIterations) {
		SET midPoint TO (endpointA + endpointB)/2.
		IF (f:CALL(midPoint) = 0) OR (endpointB - endpointA)/2 < tolerance { RETURN midPoint.}
		SET n TO n + 1.
		IF (f:CALL(midPoint) > 0) AND (f:CALL(endpointA) > 0) {
			SET endpointA TO midPoint.
		} ELSE {
			SET endpointB TO midPoint.
		}
	}
	PRINT "Exceeded maximum number of iterations.".
	PRINT "Last Results is: " + midPoint.
}

FUNCTION binarySearch {
	PARAMETER f, endpointA, endpointB, tolerance, maximumIterations.
	LOCAL midPoint IS ABS((endpointA - endpointB)/2).
	LOCAL bestResult IS f:CALL(endpointA).
	LOCAL n IS 1.
    UNTIL (n >= maximumIterations) {
			SET n TO n + 1.
			IF midPoint <= tolerance {RETURN midPoint.}
			IF f:CALL(midPoint) <= bestResult {
				SET bestResult TO f:CALL(midPoint).
				SET endpointB TO midPoint.
			} ELSE {
				SET endpointA TO midPoint.
			}
		}
		PRINT "Exceeded maximum number of iterations.".
		PRINT "Last Results is: " + midPoint.
		RETURN midPoint.
}

FUNCTION testClosestApproachTime {
	//RETURN bisectionMethod(targetDistanceAtTime@,0,SHIP:ORBIT:PERIOD,10,25).
	//RETURN binarySearch(targetDistanceAtTime@,0,SHIP:ORBIT:PERIOD,10,25).
	PARAMETER closestTime IS TIME:SECONDS.
	LOCAL timeIncrement IS 10.

	UNTIL FALSE {

		IF targetDistanceAtTime(closestTime + timeIncrement) < targetDistanceAtTime(closestTime) {
			SET closestTime TO closestTime + timeIncrement.
		} ELSE IF  targetDistanceAtTime(closestTime - timeIncrement) < targetDistanceAtTime(closestTime) {
			SET closestTime TO closestTime - timeIncrement.
		} ELSE {
			BREAK.
		}
	}
	RETURN closestTime.

	// LOCAL positionVector IS TARGET:POSITION - SHIP:POSITION.
	// LOCAL velocityVector IS TARGET:VELOCITY:ORBIT - SHIP:VELOCITY:ORBIT.
	// LOCAL xPosition IS positionVector:X. LOCAL xVelocity IS velocityVector:X.
	// LOCAL yPosition IS positionVector:Y. LOCAL yVelocity IS velocityVector:Y.
	// LOCAL zPosition IS positionVector:Z. LOCAL zVelocity IS velocityVector:Z.
	// LOCAL xTime IS xPosition/xVelocity. IF xTime < 0 {SET xTIME TO 2^64.}
	// LOCAL yTime IS yPosition/yVelocity. IF yTime < 0 {SET yTIME TO 2^64.}
	// LOCAL zTime IS zPosition/zVelocity. IF zTime < 0 {SET zTIME TO 2^64.}
	// LOCAL minTime IS MIN(MIN(MIN(xTime,yTime),MIN(xTime,zTime)),yTime).
	// RETURN minTime.
}

FUNCTION killRelativeVelocity {
	PARAMETER timeToApproach, warpFlag IS FALSE, timeBuffer IS 60.


	LOCAL targetVelocity IS VELOCITYAT(targetBody,timeToApproach):ORBIT.
	LOCAL shipVelocity IS VELOCITYAT(SHIP,timeToApproach):ORBIT.
	LOCAL targetDeltaV IS ABS(targetVelocity - shipVelocity).
	LOCAL killVelocityBurnTime IS burnTime(targetDeltaV).

	IF warpFlag {
		KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + (timeToApproach - killVelocityBurnTime/2) + 300).
	}
	LOCK STEERING TO -(targetBody:DIRECTION). //should be retrograde vector in target frame.
	waitForAlignmentTo(-(targetBody:DIRECTION)).

	stageLogic().
	WAIT UNTIL (TIME:SECONDS + (timeToApproach - killVelocityBurnTime/2)).
	SET lockedThrottle TO 1.
	WAIT killVelocityBurnTime.
	SET lockedThrottle TO 0.

}
