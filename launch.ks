@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

dependsOn("shipLib.ks").

dependsOn("navigationLib.ks").

dependsOn("constants.ks").

//TODO: add param for inclination launch, which is heading =  90 + inclination


LOCAL targetHeading IS 90.
LOCAL targetApoapsis IS 100000.
LOCAL targetPeriapsis IS 100000.
LOCAL scaleHeight IS 100000.
LOCAL goalTWR IS 2.
LOCAL staging TO TRUE.

FUNCTION sanitizeInput {
	IF targetPeriapsis > targetApoapsis {
		LOCAL tempValue IS targetPeriapsis.
		SET targetPeriapsis TO targetApoapsis.
		SET targetApoapsis TO tempValue.
	}

	IF targetHeading > 360 {
		SET targetHeading TO targetHeading - 360*MOD(aHeading,360).
	}
}

FUNCTION ignition {
	initializeControls().
	SET lockedThrottle TO 1.
	countdown().
	stage.
}

FUNCTION countdown {
	PARAMETER countNumber IS 3.
	FROM {LOCAL count TO countNumber.} UNTIL count = 0 STEP {SET count TO count - 1.} DO {
		notify("..." + count + "...", "COUNTDOWN: ", "upperCenter").
		WAIT 1.
	}
}

FUNCTION ascend {
	PARAMETER tolerance IS 0.1.
	IF SHIP:BODY:ATM:EXISTS {
		atmosphericAscent(tolerance).
		LOCK STEERING TO SHIP:PROGRADE.
		//WAIT UNTIL (SHIP:ALTITUDE >= SHIP:BODY:ATM:HEIGHT).
		WAIT UNTIL (SHIP:STATUS <> "FLYING").
		correctForDrag().
	} ELSE {
		airlessAscent(tolerance).
	}
}

FUNCTION atmosphericAscent {
	PARAMETER tolerance TO 0.1.
	LOCAL atmosphereHeight TO SHIP:BODY:ATM:HEIGHT.

	IF targetApoapsis < atmosphereHeight {
		SET targetApoapsis TO atmosphereHeight * (1 + tolerance).
		notify("WARNING: Orbit will not clear atmosphere. Adjusting apoapsis to " + targetApoapsis + " meters.").
	}

	ascentCurve(atmosphereHeight).
}

FUNCTION ascentCurve {
	PARAMETER atmosphereHeight.
	LOCAL LOCK maximumTWR TO maxTWR().
	//normalize altitude to scale height.
	LOCK normalizedAltitude TO ROUND((SHIP:ALTITUDE/scaleHeight),2).

	LOCK deltaPitch TO 90 * SQRT(normalizedAltitude).
	clearscreen.

	UNTIL SHIP:APOAPSIS >= targetApoapsis {

		IF staging {
			stageLogic().
		}

		IF SHIP:BODY:ATM:EXISTS {

			IF (maximumTWR > 0) SET lockedThrottle TO MIN(1,MAX(0,goalTWR/maximumTWR)).
		} ELSE {
			SET lockedThrottle TO 1.
		}
		SET lockedPitch TO 90 - (MIN(90,deltaPitch)).
		WAIT 0.
	}
	LOCK STEERING TO SHIP:PROGRADE.
	notify("Target Apopasis Reached").
	SET lockedThrottle TO 0.
}

FUNCTION correctForDrag {
	IF (SHIP:APOAPSIS < targetApoapsis) {
		notify("Correcting apoapsis for atmospheric drag.").
		LOCK STEERING TO SHIP:PROGRADE.
		waitForAlignmentTo(SHIP:PROGRADE).
		SET lockedThrottle TO MAX(1,(targetApoapsis - SHIP:APOAPSIS)/targetApoapsis * 10).

		WAIT UNTIL (SHIP:APOAPSIS >= targetApoapsis).

		SET lockedThrottle TO 0.
	}
}

FUNCTION airlessAscent {
	PARAMETER tolerance TO 0.1.
	LOCAL minFeatureHeight TO surfaceFeature[SHIP:BODY:NAME].

	//check inputs
	IF targetApoapsis < minFeatureHeight {
		SET targetApoapsis TO minFeatureHeight * (1 + tolerance).
		notify("WARNING: Orbit will not clear minimum surface feature altitude. Adjusting apoapsis to " + targetApoapsis + " m").
	}
	ascentCurve().
}


FUNCTION launchProgram {
	PARAMETER paramHeading IS 90, paramApoapsis IS 100000, paramPeriapsis IS 100000, paramScaleHeight IS 100000, paramGoalTWR IS 2, paramStaging TO TRUE.

	SET targetHeading TO paramHeading.
	SET targetApoapsis TO paramApoapsis.
	SET targetPeriapsis TO paramPeriapsis.
	SET staging TO paramStaging.
	SET scaleHeight TO paramScaleHeight.
	SET goalTWR TO paramGoalTWR.

	sanitizeInput().
	initializeControls().
	SET lockedCompassHeading TO targetHeading.
	ignition().
	ascend().
	engageDeployables().
}
