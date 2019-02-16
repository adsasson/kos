@LAZYGLOBAL OFF.

//ascend
//orbital insertion


// DECLARE PARAMETER aHeading IS 90, anApoapsis IS 100000, aPeriapsis IS 0, orbitInsert IS true, goalTWR IS 2.
//
// //SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
// //initialize controls
// //sanitize input
// IF anApoapsis < aPeriapsis {
// 	LOCAL oldValue TO aPeriapsis.
// 	SET aPeriapsis TO anApoapsis.
// 	SET anApoapsis TO oldValue.
// }
// IF aHeading > 360 {
// 	SET aHeading TO aHeading - 360*MOD(aHeading,360).
// }
//
// ignition().
// ascend(aHeading, anApoapsis, goalTWR).
// if orbitInsert {
// 	orbitalInsertion(aPeriapsis).
// } else {
// 	//handle suborbital trajectory
// }
GLOBAL lockedThrottle IS 0.
GLOBAL lockedPitch IS 90.
GLOBAL lockedCompassHeading IS 90.

LOCAL targetHeading IS 90.
LOCAL targetApoapsis IS 100000.
LOCAL targetPeriapsis IS 100000.
LOCAL scaleHeight IS 100000.
LOCAL goalTWR IS 2.
LOCAL staging TO TRUE.

runoncepath("1:/boot/devboot.ks").


FUNCTION maxTWR {
	LOCAL gravityAtAltitude TO SHIP:BODY:MU/(SHIP:ALTITUDE + SHIP:BODY:RADIUS)^2.
	//gravity for altitude
	RETURN (SHIP:AVAILABLETHRUST/(SHIP:MASS * gravityAtAltitude)).
}

FUNCTION timeToImpact {
	PARAMETER v0, distance, accel.
	RETURN MAX((-v0 - SQRT(v0^2 - 2*accel*distance))/accel,
						 (-v0 + SQRT(v0^2 - 2*accel*distance))/accel).
}

//orbit
//ignite
//ascend
	//performAscentProfile
//onOrbitBurn
FUNCTION stageLogic {
	//LOCAL engineList TO SHIP:ENGINES.
	LOCAL stageFlag IS TRUE.

	LOCAL engineList TO BUILDLIST("engines").
	UNTIL  (NOT stageFlag) {
		PRINT "Stage: " + STAGE:NUMBER AT (0,0).
		FOR engine IN engineList {
			IF engine:FLAMEOUT OR (NOT(SHIP:AVAILABLETHRUST > 0)) {
				STAGE.
				PRINT "STAGING!" AT (0,0).
				IF STAGE:NUMBER = 0 {
					SET stageFlag TO FALSE.
					RETURN.
				}
				UNTIL STAGE:READY {
					WAIT 0.
				}
				SET engineList TO BUILDLIST("engines").
				CLEARSCREEN.
			}
		}
	}

}
FUNCTION test {
	initializeControls().
	ignition().
	ascend().

}

FUNCTION ignition {
	initializeControls().
	SET lockedThrottle TO 1.
	countdown().
	stage.
}

FUNCTION initializeControls {
	SAS OFF.
	LOCK THROTTLE TO lockedThrottle.
	SET lockedCompassHeading TO targetHeading.
	LOCK STEERING TO HEADING(lockedCompassHeading, lockedPitch).
}

FUNCTION deinitializeControls {
	SET lockedThrottle TO 0.
	UNLOCK ALL.
	SAS ON.
}

FUNCTION countdown {
	PARAMETER countNumber IS 3.
	FROM {LOCAL count TO countNumber.} UNTIL count = 0 STEP {SET count TO count - 1.} DO {
		notify("..." + count + "...", "COUNTDOWN: ", "upperCenter").
		WAIT 1.
	}
}

FUNCTION ascend {
	PARAMETER shouldStage IS TRUE.

	SET staging TO shouldStage.


	IF SHIP:BODY:ATM:EXISTS {
		atmosphericAscent().
		LOCK STEERING TO SHIP:PROGRADE.
		//correctForDrag().
	} ELSE {
		airlessAscent().
	}
	//engageDeployables().
}

FUNCTION atmosphericAscent {
	LOCAL atmosphereHeight TO SHIP:BODY:ATM:HEIGHT.
	IF targetApoapsis < atmosphereHeight {
		SET targetApoapsis TO atmosphereHeight * 1.1.
		notify("WARNING: Orbit will not clear atmosphere. Adjusting apoapsis to " + targetApoapsis + " meters.").
	}

	ascentCurve(atmosphereHeight).
}

FUNCTION ascentCurve {
	PARAMETER atmosphereHeight.
	LOCAL LOCK maxTWR TO maxTWR().
	//normalize altitude to scale height.
	LOCK normalizedAltitude TO ROUND((SHIP:ALTITUDE/scaleHeight),2).

	LOCK deltaPitch TO 90 * SQRT(normalizedAltitude).

	UNTIL SHIP:APOAPSIS >= targetApoapsis {
		stageLogic().
		IF SHIP:BODY:ATM:EXISTS {
			IF (maxTWR > 0) SET lockedThrottle TO MIN(1,MAX(0,goalTWR/maxTWR)).
		} ELSE {
			SET lockedThrottle TO 1.
		}
		SET lockedPitch TO 90 - (MIN(90,deltaPitch)).
		PRINT "LOCKED PITCH: " + lockedPitch AT (0,0).
		WAIT 0.
	}
	LOCK STEERING TO SHIP:PROGRADE.
	notify("Target Apopasis Reached").
	SET lockedThrottle TO 0.
}

//ignition().
test().
