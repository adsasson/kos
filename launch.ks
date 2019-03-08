@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

dependsOn("shipLib.ks").

dependsOn("navigationLib.ks").

dependsOn("constants.ks").

//TODO: add param for inclination launch, which is heading =  90 + inclination


LOCAL launchTargetHeading IS 90.
LOCAL launchTargetApoapsis IS 100000.
LOCAL launchTargetPeriapsis IS 100000.
LOCAL launchScaleHeight IS 100000.
LOCAL launchGoalTWR IS 2.
LOCAL launchStaging TO TRUE.

FUNCTION sanitizeInput {
	IF launchTargetPeriapsis > launchTargetApoapsis {
		LOCAL tempValue IS launchTargetPeriapsis.
		SET launchTargetPeriapsis TO launchTargetApoapsis.
		SET launchTargetApoapsis TO tempValue.
	}

	IF launchTargetHeading > 360 {
		SET launchTargetHeading TO launchTargetHeading - 360*MOD(aHeading,360).
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

	IF launchTargetApoapsis < atmosphereHeight {
		SET launchTargetApoapsis TO atmosphereHeight * (1 + tolerance).
		notify("WARNING: Orbit will not clear atmosphere. Adjusting apoapsis to " + launchTargetApoapsis + " meters.").
	}

	ascentCurve(atmosphereHeight).
}

FUNCTION ascentCurve {
	PARAMETER atmosphereHeight.
	LOCAL LOCK maximumTWR TO maxTWR().
	//normalize altitude to scale height.
	LOCK normalizedAltitude TO ROUND((SHIP:ALTITUDE/launchScaleHeight),2).

	LOCK deltaPitch TO 90 * SQRT(normalizedAltitude).
	clearscreen.

	UNTIL SHIP:APOAPSIS >= launchTargetApoapsis {

		IF launchStaging {
			stageLogic().
		}

		IF SHIP:BODY:ATM:EXISTS {

			IF (maximumTWR > 0) SET lockedThrottle TO MIN(1,MAX(0,launchGoalTWR/maximumTWR)).
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
	IF (SHIP:APOAPSIS < launchTargetApoapsis) {
		notify("Correcting apoapsis for atmospheric drag.").
		LOCK STEERING TO SHIP:PROGRADE.
		waitForAlignmentTo(SHIP:PROGRADE).
		SET lockedThrottle TO MAX(1,(launchTargetApoapsis - SHIP:APOAPSIS)/launchTargetApoapsis * 10).

		WAIT UNTIL (SHIP:APOAPSIS >= launchTargetApoapsis).

		SET lockedThrottle TO 0.
	}
}

FUNCTION airlessAscent {
	PARAMETER tolerance TO 0.1.
	LOCAL minFeatureHeight TO surfaceFeature[SHIP:BODY:NAME].

	//check inputs
	IF launchTargetApoapsis < minFeatureHeight {
		SET launchTargetApoapsis TO minFeatureHeight * (1 + tolerance).
		notify("WARNING: Orbit will not clear minimum surface feature altitude. Adjusting apoapsis to " + launchTargetApoapsis + " m").
	}
	ascentCurve().
}


FUNCTION launchProgram {
	PARAMETER paramHeading IS 90, paramApoapsis IS 100000, paramPeriapsis IS 100000, paramScaleHeight IS 100000, paramGoalTWR IS 2, paramStaging TO TRUE.

	SET launchTargetHeading TO paramHeading.
	SET launchTargetApoapsis TO paramApoapsis.
	SET launchTargetPeriapsis TO paramPeriapsis.
	SET launchStaging TO paramStaging.
	SET launchScaleHeight TO paramScaleHeight.
	SET launchGoalTWR TO paramGoalTWR.

	sanitizeInput().
	initializeControls().
	SET lockedCompassHeading TO launchTargetHeading.
	ignition().
	ascend().
	engageDeployables().
}
