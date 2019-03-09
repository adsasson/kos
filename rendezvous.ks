@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

dependsOn("shipLib.ks").

LOCAL targetBody IS TARGET.

FUNCTION closestApproachTime {
	PARAMETER closestApproachDistance IS 5000, startingTimeIncrement IS 10000,.
	LOCAL timeIncrement IS startingTimeIncrement.
	LOCAL tau IS TIME:SECONDS.
	LOCAL oldTargetDistance IS ABS(POSITIONAT(targetBody,tau) - POSITIONAT(SHIP,tau)).
	LOCAL newTargetDistance IS ABS(POSITIONAT(targetBody,(tau + timeIncrement)) -
	POSITIONAT(SHIP, (tau + timeIncrement))).

	UNTIL timeIncrement < 10 {
		IF newTargetDistance <= oldTargetDistance { //old solution is better than new solution
			SET timeIncrement TO timeIncrement/10. //decrease time increment by factor of 10.
			SET oldTargetDistance TO newTargetDistance.
		} ELSE {
			SET tau TO tau + timeIncrement.
		}
		SET newTargetDistance TO ABS(POSITIONAT(targetBody,(tau + timeIncrement)) -
		POSITIONAT(SHIP, (tau + timeIncrement))).
	}
	IF ABS(oldTargetDistance) <= closestApproachDistance {
		RETURN tau.
	} ELSE {
		notify("Closest approach to " + targetBody + " is " + ROUND(ABS(oldTargetDistance),2) +
		" which is greater than " + closestApproachDistance).
	}
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
