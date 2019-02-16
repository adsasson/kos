@LAZYGLOBAL OFF.

FUNCTION ascentCurve {
	PARAMETER targetHeading IS 90, targetApo IS 100000, scaleHeight IS 100000, goalTWR IS 2.

	SAS OFF.

	LOCAL cPitch TO 0.		//current Pitch, pointing straight up
	LOCAL cHeading TO HEADING(targetHeading,cPitch). //currentHeading.

	LOCAL cThrottle TO 0.5.
	LOCAL LOCK mTWR TO maxTWR().
	LOCK THROTTLE TO cThrottle.

	LOCK STEERING TO cHeading.
	//normalize altitude to scaleHeight
	LOCK Ka TO ROUND((SHIP:ALTITUDE/scaleHeight),2).

	//ascent curves
	//LOCK deltaPitch TO 90 * (1.5 * Ka). //known good curve
	LOCK deltaPitch TO 90 * SQRT(Ka). //more efficient curve

	//ASCENT LOOP
	UNTIL SHIP:APOAPSIS >= targetApo {
		stageLogic().
		IF SHIP:BODY:ATM:EXISTS { //atmo
			IF (mTWR > 0) SET cThrottle TO MIN(1,MAX(0,goalTWR/mTWR)).
		} ELSE { //airless
			SET cThrottle TO 1.
		}
		SET cPitch TO 90 - (MIN(90,deltaPitch)). //pitch for ascent curve
		SET cHeading TO HEADING(targetHeading,cPitch).

		WAIT 0.
	}
	SET cHeading TO SHIP:PROGRADE.
	notify("Target apoapsis reached").

	SET cThrottle TO 0.
	UNLOCK THROTTLE.
}

FUNCTION atmosphericAscent {
	PARAMETER targetHeading IS 90, targetApo IS 100000, goalTWR IS 2.
	LOCAL atmoHeight TO SHIP:BODY:ATM:HEIGHT.

	//check inputs
	IF targetApo < atmoHeight {
		notify("WARNING: Orbit will not clear atmosphere. Adjusting apoapsis to " + atmoHeight + 1000 + " m").
		SET targetApo TO atmoHeight + 1000.
	}
	ascentCurve(targetHeading,targetApo,atmoHeight,goalTWR).
}

FUNCTION correctForDrag {
	PARAMETER targetApo.

	IF (SHIP:APOAPSIS < targetApo) {
		notify("Correcting apoapsis for atmospheric drag.").

		LOCK STEERING TO SHIP:PROGRADE.

		pointTo(SHIP:PROGRADE).

		LOCAL cThrottle TO MAX(1,(targetApo - SHIP:APOAPSIS)/targetApo * 10).
		LOCK THROTTLE to cTHROTTLE.

		WAIT UNTIL (SHIP:APOAPSIS >= targetApo).

		SET cThrottle TO 0.

		UNLOCK THROTTLE.
		UNLOCK STEERING.
	}
}

FUNCTION airlessAscent {
	PARAMETER targetHeading IS 90, targetApo IS 100000.
	LOCAL minFeatureHeight TO surfaceFeature[SHIP:BODY:NAME].

	//check inputs
	IF targetApo < minFeatureHeight {
		notify("WARNING: Orbit will not clear minimum surface feature altitude. Adjusting apoapsis to " + minFeatureHeight + " m").
		SET targetApo TO minFeatureHeight.
	}
	ascentCurve(targetHeading,targetApo).
}

FUNCTION ascend {
	PARAMETER targetHeading IS 90, targetApo IS 100000, goalTWR IS 2, staging IS true.

	SET stagingFlag TO staging.

	IF SHIP:BODY:ATM:EXISTS {
		atmosphericAscent(targetHeading,targetApo,goalTWR).
		LOCK STEERING TO SHIP:PROGRADE.
		WAIT UNTIL (SHIP:ALTITUDE >= SHIP:BODY:ATM:HEIGHT). 			correctForDrag(targetApo).
	} ELSE {
		airlessAscent(targetHeading,targetApo,goalTWR).
	}
	engageDeployables().
}
