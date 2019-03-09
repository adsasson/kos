//orbital maneuver library
@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

dependsOn("orbitalMechanicsLib.ks").

dependsOn("shipStats.ks").

dependsOn("navigationLib.ks").

dependsOn("constants.ks").


LOCAL orbitTargetHeading IS 90.
LOCAL orbitTargetApoapsis IS 100000.
LOCAL orbitTargetPeriapsis IS 100000.
LOCAL orbitStaging IS TRUE.
//LOCAL useNode IS TRUE.

LOCAL targetApsisHeight IS orbitTargetApoapsis.
LOCAL apsis TO SHIP:APOAPSIS.
LOCAL burnDirection TO SHIP:PROGRADE.

FUNCTION correctForEccentricity {
	IF SHIP:ORBIT:ECCENTRICITY < 1 { //elliptical
		SET apsis TO SHIP:APOAPSIS.
		SET burnDirection TO SHIP:PROGRADE.
	} ELSE { //parabolic or hyperbolic
		SET apsis TO SHIP:PERIAPSIS.
		SET burnDirection TO SHIP:RETROGRADE.
		SET targetApsisHeight TO orbitTargetPeriapsis.
	}
}
//TODO: functions to check that burn apsis is above atmosphere or minimum feature HEIGHT,
//then correct burn time and burn point if too low. Which leads to the idea of:
//TODO: aerobrake function for atmospheric bodies.


FUNCTION checkPeriapsisMinimumValue {
	PARAMETER tolerance IS 0.1.
		//first make sure peri < apo.
		IF orbitTargetPeriapsis > orbitTargetApoapsis {
			LOCAL temp IS orbitTargetPeriapsis.
			SET orbitTargetPeriapsis TO orbitTargetApoapsis.
			SET orbitTargetApoapsis TO temp.
		}
		IF SHIP:BODY:ATM:EXISTS {
		IF orbitTargetPeriapsis < SHIP:BODY:ATM:HEIGHT {
			SET orbitTargetPeriapsis TO SHIP:BODY:ATM:HEIGHT * (1 + tolerance).
			notify("WARNING: Orbit will not clear atmosphere. " +
							"Adjusting periapsis to " +	orbitTargetPeriapsis + " m").
		}
	} ELSE {
		LOCAL minFeatureHeight TO surfaceFeature[SHIP:BODY:NAME].
		IF orbitTargetPeriapsis < minFeatureHeight {
			SET targetAlt TO minFeatureHeight * (1 + tolerance).
			notify("WARNING: Orbit will not clear minimum surface feature altitude."
						+ " Adjusting periapsis to " + orbitTargetPeriapsis + " m").
		}
	}
}

FUNCTION onOrbitBurn {
	LOCAL currentPressure IS SHIP:BODY:ATM:ALTITUDEPRESSURE(apsis).
	LOCAL etaToBurn TO ETA:APOAPSIS.

	IF SHIP:ORBIT:ECCENTRICITY >= 1 {
		//parabolic or hyperbolic
		SET etaToBurn TO ETA:PERIAPSIS.
	}

	LOCAL tau TO etaToBurn + TIME:SECONDS.

	LOCAL targetSemiMajorAxis TO (apsis + targetApsisHeight)/2 + SHIP:BODY:RADIUS.
	LOCAL orbitalInsertionBurnDV TO deltaV(apsis, SHIP:ORBIT:SEMIMAJORAXIS, targetSemiMajorAxis).
	LOCAL orbitalInsertionBurnTime TO burnTime(orbitalInsertionBurnDV, currentPressure).

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

	LOCAL startTime IS tau - orbitalInsertionBurnTime/2.
	//performBurn(burnVector,startTime,startTime + orbitalInsertionBurnTime).

	WAIT UNTIL TIME:SECONDS >= startTime. {
		SET lockedThrottle TO 1.
		stageLogic().
		WAIT orbitalInsertionBurnTime.
		SET lockedThrottle TO 0.
	}
}

FUNCTION createOnOrbitManeuverNode {
	LOCAL LOCK etaToBurn TO ETA:APOAPSIS.

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


FUNCTION killRelativeVelocity {
	PARAMETER posIntercept, posTarget, bufferVel IS 0.1.
	IF HASTARGET {
		LOCAL alpha1 TO SHIP:ORBIT:SEMIMAJORAXIS.
		LOCAL alpha2 TO TARGET:ORBIT:SEMIMAJORAXIS.
		LOCAL mu1 TO SHIP:BODY:MU.
		LOCAL mu2 TO TARGET:BODY:MU.

		//LOCAL v1 TO visViva(r1,alpha1,mu1). //interceptor position
		//LOCAL v2 TO visViva(r2,alpha2,mu2). //target position
		LOCAL velTarget TO TARGET:VELOCITY:ORBIT.
		LOCAL velIntercept TO SHIP:VELOCITY:ORBIT.

		LOCAL tgtRetrograde TO TARGET:VELOCITY:ORBIT - SHIP:VELOCITY:ORBIT.
		LOCK tgtRetrograde TO TARGET:VELOCITY:ORBIT - SHIP:VELOCITY:ORBIT.

		LOCAL velRel TO (tgtRetrograde):MAG.
		LOCK velRel TO (tgtRetrograde):MAG.

		IF (ABS(TARGET:DISTANCE/velRel) < 300) { //more than 5 minutes from TARGET
			//if intercept requires a 5 minute or more burn, something is wrong
			LOCK STEERING TO tgtRetrograde:DIRECTION.
			LOCAL cThrott TO 0.
			LOCK THROTTLE TO cThrott.

			WAIT UNTIL pointTo(tgtRetrograde:DIRECTION, FALSE, 0.3).
			//LOCAL deltaV TO ABS(velTarget - velIntercept).

			LOCAL cBurn TO burnTime(velRel).
			LOCK cBurn TO burnTime(velRel).

			LOCAL burnDistance TO (velRel + 2*bufferVel)/2*cBurn. //avg velocity + buffer velocity.
			LOCK burnDistance TO (velRel + 2*bufferVel)/2*cBurn. //avg velocity + buffer velocity.

			WAIT UNTIL (TARGET:DISTANCE <= burnDistance).
			//AIT UNTIL cBurn >= ABS(TARGET:DISTANCE/velRel).

			UNTIL velRel <= bufferVel*10 {
				SET cThrott TO 1.
				WAIT 0.
			}
			UNTIL velRel <= bufferVel {
				SET cThrott TO 0.1.
				WAIT 0.
			}

			SET cThrott TO 0.
		} ELSE {
			notify("Too far from target: " + TARGET:NAME).
		}
	} ELSE {
		notify("No target selected.").
	}

}

FUNCTION orbitalInsertion {
	PARAMETER paramHeading IS 90,
						paramApoapsis IS 100000,
						paramPeriapsis IS 100000,
						paramStaging TO TRUE,
						useNode IS FALSE.

	SET orbitTargetHeading TO paramHeading.
	SET orbitTargetApoapsis TO paramApoapsis.
	SET orbitTargetPeriapsis TO paramPeriapsis.
	SET orbitStaging TO paramStaging.



	initializeControls().
	correctForEccentricity().
	checkPeriapsisMinimumValue().
	IF useNode = FALSE {
		onOrbitBurn().
	} ELSE {
		LOCAL burnNode IS createOnOrbitManeuverNode().
		ADD burnNode.
		download("executeNode.ks",1).
		WAIT 0.5.
		RUNONCEPATH("executeNode.ks").
	}

}
