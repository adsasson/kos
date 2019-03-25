//orbital maneuver library
@LAZYGLOBAL OFF.

LOCAL targetHeading IS 90.
LOCAL targetApoapsis IS 100000.
LOCAL targetPeriapsis IS 100000.
//LOCAL scaleHeight IS 100000.
LOCAL goalTWR IS 2.
LOCAL staging IS TRUE.
LOCAL targetApsisHeight IS targetApoapsis.
LOCAL apsis TO SHIP:APOAPSIS.

LOCAL orbitalInsertionBurnDV IS 0.
LOCAL orbitalInsertionBurnTime IS 0.
LOCAL etaToBurn IS 0.

//LOCAL useNode IS TRUE.

//RUNONCEPATH(bootfile).

dependsOn("orbitalMechanicsLib.ks").
dependsOn("shipStats.ks").
dependsOn("navigationLib.ks").
dependsOn("executeNode.ks").

FUNCTION sanitizeInput {
	PARAMETER tolerance IS 0.1.
	IF targetHeading > 360 {
		SET targetHeading TO targetHeading - 360*MOD(targetHeading,360).
	}

	IF targetPeriapsis > targetApoapsis {
		LOCAL temp IS orbitTargetPeriapsis.
		SET targetPeriapsis TO targetApoapsis.
		SET targetApoapsis TO temp.
	}

	IF SHIP:BODY:ATM:EXISTS {
		IF targetApoapsis < SHIP:BODY:ATM:HEIGHT {
			SET targetApoapsis TO atmosphereHeight * (1 + tolerance).
			notify("WARNING: Orbit will not clear atmosphere. Adjusting apoapsis to " + targetApoapsis + " meters.").

			IF targetPeriapsis < SHIP:BODY:ATM:HEIGHT {
				SET targetPeriapsis TO SHIP:BODY:ATM:HEIGHT * (1 + tolerance).
				notify("WARNING: Orbit will not clear atmosphere. " +
				"Adjusting periapsis to " +	targetPeriapsis + " m").
			}

		}
	} ELSE {
		LOCAL minFeatureHeight TO surfaceFeature[SHIP:BODY:NAME].
		IF targetApoapsis < minFeatureHeight {
			SET targetApoapsis TO minFeatureHeight * (1 + tolerance).
			notify("WARNING: Orbit will not clear minimum surface feature altitude. Adjusting apoapsis to " + targetApoapsis + " m").
		}

		IF targetPeriapsis < minFeatureHeight {
			SET targetAlt TO minFeatureHeight * (1 + tolerance).
			notify("WARNING: Orbit will not clear minimum surface feature altitude."
			+ " Adjusting periapsis to " + targetPeriapsis + " m").
		}

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


FUNCTION correctForEccentricity {
	IF SHIP:ORBIT:ECCENTRICITY < 1 { //elliptical
		SET apsis TO SHIP:APOAPSIS.
	} ELSE { //parabolic or hyperbolic
		SET apsis TO SHIP:PERIAPSIS.
		SET targetApsisHeight TO targetPeriapsis.
	}
}

FUNCTION ascend {
	LOCAL LOCK maximumTWR TO maxTWR().
	//normalize altitude to scale height.
	//LOCK normalizedAltitude TO ROUND((SHIP:ALTITUDE/scaleHeight),2).
	LOCK normalizedAltitude TO ROUND((SHIP:ALTITUDE/targetApoapsis),2).

	LOCK deltaPitch TO 90 * SQRT(normalizedAltitude).
	clearscreen.

	UNTIL SHIP:APOAPSIS >= targetApoapsis {

		IF staging {
			stageLogic().
		}

		IF (SHIP:BODY:ATM:EXISTS AND (SHIP:ALTITUDE < SHIP:BODY:ATM:HEIGHT)) {
			IF (maximumTWR <> 0) SET lockedThrottle TO MIN(1,MAX(0,goalTWR/maximumTWR)).
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


//TODO: functions to check that burn apsis is above atmosphere or minimum feature HEIGHT,
//then correct burn time and burn point if too low. Which leads to the idea of:
//TODO: aerobrake function for atmospheric bodies.


FUNCTION performOnOrbitBurn {
	LOCAL tau TO etaToBurn + TIME:SECONDS.

	LOCAL LOCK r0 TO SHIP:POSITION.
	LOCAL LOCK r1 TO POSITIONAT(SHIP,tau).
	LOCAL LOCK deltaR TO r1 - r0.

	LOCAL LOCK v1 TO VELOCITYAT(SHIP,tau):ORBIT * orbitalInsertionBurnDV.
	LOCAL LOCK v0 TO SHIP:VELOCITY:ORBIT.
	LOCAL LOCK burnVector TO deltaR + v1.

	LOCK STEERING TO burnVector.

	waitForAlignmentTo(burnVector).
	print "Debug burn deltaV: " + orbitalInsertionBurnDV.
	print "Debug burn time: " + orbitalInsertionBurnTime.
	print "Debug eta time: " + etaToBurn.


}

FUNCTION createOnOrbitManeuverNode {
	LOCAL etaToBurn TO ETA:APOAPSIS.

	// IF SHIP:ORBIT:ECCENTRICITY >= 1 {
	// 	//parabolic or hyperbolic
	// 	LOCK etaToBurn TO ETA:PERIAPSIS.
	// }
	LOCAL tau TO etaToBurn + TIME:SECONDS.

	LOCAL targetSemiMajorAxis TO (apsis + targetApsisHeight)/2 + SHIP:BODY:RADIUS.
	LOCAL orbitalInsertionBurnDV TO deltaV(apsis, SHIP:ORBIT:SEMIMAJORAXIS, targetSemiMajorAxis).

	LOCAL onOrbitNode IS NODE(tau, 0, 0, orbitalInsertionBurnDV).
	RETURN onOrbitNode.
}

//======================================


FUNCTION performOrbitalInsertion {
	PARAMETER paramHeading IS 90,
	paramApoapsis IS 100000,
	paramPeriapsis IS 100000,
	paramStaging TO TRUE,
	useNode IS FALSE.

	SET targetHeading TO paramHeading.
	SET targetApoapsis TO paramApoapsis.
	SET targetPeriapsis TO paramPeriapsis.
	SET orbitStaging TO paramStaging.

	initializeControls().
	correctForEccentricity().
	checkPeriapsisMinimumValue().
	IF useNode = FALSE {
		performOnOrbitBurn().
	} ELSE {
		LOCAL burnNode IS createOnOrbitManeuverNode().
		ADD burnNode.
		WAIT 0.5.
		executeNode().
	}

	FUNCTION performLaunch {
		PARAMETER paramHeading IS 90,
		paramApoapsis IS 100000,
		paramPeriapsis IS 100000,
		paramScaleHeight IS 100000,
		useNode IS FALSE,
		warpFlag IS FALSE,
		orbitFlag IS TRUE,
		paramGoalTWR IS 2,
		paramStaging TO TRUE.

		SET targetHeading TO paramHeading.
		SET targetApoapsis TO paramApoapsis.
		SET targetPeriapsis TO paramPeriapsis.
		SET staging TO paramStaging.
		SET scaleHeight TO paramScaleHeight.
		SET goalTWR TO paramGoalTWR.

		sanitizeInput().
		initializeControls().
		SET lockedCompassHeading TO launchTargetHeading.
		ignition().
		ascend().

		IF orbitFlag { //put this here because calculating node may take some time
			correctForEccentricity().
			calculateBurnParameters().
		}

		IF SHIP:BODY:ATM:EXISTS {
			//WAIT UNTIL (SHIP:ALTITUDE >= SHIP:BODY:ATM:HEIGHT).
			WAIT UNTIL (SHIP:STATUS <> "FLYING").
			engageDeployables().
			correctForDrag().
		}
		IF orbitFlag{
			//wait until burn
			LOCAL startTime IS (etaToBurn + TIME:SECONDS) - orbitalInsertionBurnTime/2.
			//performBurn(burnVector,startTime,startTime + orbitalInsertionBurnTime).



			IF useNode {
				LOCAL onOrbitNode IS NODE(etaToBurn + TIME:SECONDS, 0, 0, orbitalInsertionBurnDV).
				ADD onOrbitNode.
				if not hasFile("executeNode.ks",1) {download("executeNode.ks",1).}
				WAIT 0.5.
				RUNONCEPATH("executeNode.ks").

				performManeuverNodeBurn(onOrbitNode).

				REMOVE node.
			} ELSE {
				WAIT UNTIL TIME:SECONDS >= startTime. {
					SET lockedThrottle TO 1.
					stageLogic().
					WAIT orbitalInsertionBurnTime.
					SET lockedThrottle TO 0.
				}
						}
		}
		LOCK STEERING TO PROGRADE.
		deinitializeControls().
	}

	FUNCTION calculateBurnParameters {
		PARAMETER pressure IS 0.
		IF SHIP:BODY:ATM:EXISTS {
			SET pressure TO SHIP:BODY:ATM:ALTITUDEPRESSURE(apsis).
		}
		SET etaToBurn TO ETA:APOAPSIS.

		IF SHIP:ORBIT:ECCENTRICITY >= 1 {
			//parabolic or hyperbolic
			SET etaToBurn TO ETA:PERIAPSIS.
		}
		LOCAL tau TO etaToBurn + TIME:SECONDS.

		LOCAL targetSemiMajorAxis TO (apsis + targetApsisHeight)/2 + SHIP:BODY:RADIUS.
		SET orbitalInsertionBurnDV TO deltaV(apsis, SHIP:ORBIT:SEMIMAJORAXIS, targetSemiMajorAxis).
		SET orbitalInsertionBurnTime TO calculateBurnTimeForDeltaV(orbitalInsertionBurnDV, currentPressure).

	}
}
