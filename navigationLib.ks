@LAZYGLOBAL OFF.

GLOBAL lockedThrottle IS 0.
GLOBAL lockedPitch IS 90.
GLOBAL lockedCompassHeading IS 90.

FUNCTION initializeControls {
	SAS OFF.
	LOCK THROTTLE TO lockedThrottle.

	LOCK STEERING TO HEADING(lockedCompassHeading, lockedPitch).
}

FUNCTION deinitializeControls {
	SET lockedThrottle TO 0.
	SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
	UNLOCK THROTTLE.
	UNLOCK STEERING.
	SAS ON.
}

FUNCTION waitForAlignmentTo {
	PARAMETER goal, useRCS IS FALSE, timeOut IS 60, tolerance IS 1.

	IF useRCS {
		RCS ON.
	}

	IF goal:ISTYPE("DIRECTION")  {
		SET goal TO goal:VECTOR.
	}

	LOCAL timeStart TO TIME.
	IF VERBOSE {PRINT "Orienting.".}
	UNTIL ABS(VANG(SHIP:FACING:VECTOR,goal)) < tolerance {
		IF (TIME - timeStart) > timeOut {
			BREAK.
		}
		WAIT 0.
	}.
	IF VERBOSE {PRINT "Completed orienting.".}

  RCS OFF.
	RETURN TRUE.
}

FUNCTION waitUntil {
	PARAMETER absoluteTime, useWarp IS FALSE, timeBuffer IS 60.

	IF useWarp {
		KUNIVERSE:TIMEWARP:WARPTO(absoluteTime - (timeBuffer * 2)).
	} ELSE {
		WAIT UNTIL TIME:SECONDS >= (absoluteTime - timeBuffer).
	}
}

FUNCTION performBurn {
	PARAMETER burnVector, burnStartTime, burnEndTime, targetThrottle IS 1.
	LOCK STEERING TO burnVector.
	waitForAlignmentTo(burnVector).
	IF verbose PRINT "Waiting for burn.".
	WAIT UNTIL TIME:SECONDS >= burnStartTime.
	SET lockedThrottle TO targetThrottle.
	stageLogic().
	WAIT UNTIL TIME:SECONDS >= burnEndTime.
	SET lockedThrottle TO 0.
}

FUNCTION timeToImpact {
	PARAMETER v0, distance, accel.
	RETURN MAX((-v0 - SQRT(v0^2 - 2*accel*distance))/accel,
						 (-v0 + SQRT(v0^2 - 2*accel*distance))/accel).
}
