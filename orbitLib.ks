//orbital maneuver library
@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

LOCAL targetApoapsis IS 100000.
LOCAL targetPeriapsis IS 100000.
LOCAL useNode IS FALSE.
LOCAL useWarp IS FALSE.

LOCAL targetApsisHeight IS targetApoapsis.
LOCAL apsis TO SHIP:APOAPSIS.
LOCAL burnDirection TO SHIP:PROGRADE.

LOCAL orbitalInsertionBurnDV IS 0.
LOCAL orbitalInsertionBurnTime IS 0.
LOCAL etaToBurn IS 0.

dependsOn("orbitalMechanicsLib.ks").
dependsOn("shipStats.ks").
dependsOn("navigationLib.ks").
//dependsOn("constants.ks").

FUNCTION correctForEccentricity {
	IF SHIP:ORBIT:ECCENTRICITY < 1 { //elliptical
		SET apsis TO SHIP:APOAPSIS.
		SET burnDirection TO SHIP:PROGRADE.
		SET etaToBurn TO ETA:APOAPSIS.
	} ELSE { //parabolic or hyperbolic
		SET apsis TO SHIP:PERIAPSIS.
		SET burnDirection TO SHIP:RETROGRADE.
		SET targetApsisHeight TO targetPeriapsis.
		SET etaToBurn TO ETA:PERIAPSIS.
	}
}
//TODO: functions to check that burn apsis is above atmosphere or minimum feature HEIGHT,
//then correct burn time and burn point if too low. Which leads to the idea of:
//TODO: aerobrake function for atmospheric bodies.

FUNCTION checkPeriapsisMinimumValue {
	PARAMETER tolerance IS 0.1.
	//first make sure peri < apo.
	IF targetPeriapsis > targetApoapsis {
		LOCAL temp IS targetPeriapsis.
		SET targetPeriapsis TO targetApoapsis.
		SET targetApoapsis TO temp.
	}

	IF SHIP:BODY:ATM:EXISTS {
		IF targetPeriapsis < SHIP:BODY:ATM:HEIGHT {
			SET targetPeriapsis TO SHIP:BODY:ATM:HEIGHT * (1 + tolerance).
			notify("WARNING: Orbit will not clear atmosphere. " +
			"Adjusting periapsis to " +	targetPeriapsis + " m").
		}
	} ELSE {
		LOCAL minFeatureHeight TO surfaceFeature[SHIP:BODY:NAME].
		IF targetPeriapsis < minFeatureHeight {
			SET targetAlt TO minFeatureHeight * (1 + tolerance).
			notify("WARNING: Orbit will not clear minimum surface feature altitude."
			+ " Adjusting periapsis to " + targetPeriapsis + " m").
		}
	}
}

FUNCTION calculateOrbitBurnParameters {
	LOCAL pressure IS 0.
	IF SHIP:BODY:ATM:EXISTS {SET pressure TO SHIP:BODY:ATM:ALTITUDEPRESSURE(apsis).}

	LOCAL targetSemiMajorAxis IS (targetPeriapsis + targetApoapsis)/2 + SHIP:BODY:RADIUS.
	SET orbitalInsertionBurnDV TO deltaV(apsis, SHIP:ORBIT:SEMIMAJORAXIS, targetSemiMajorAxis).
	SET orbitalInsertionBurnTime TO calculateBurnTimeForDeltaV(orbitalInsertionBurnDV, pressure).
}

FUNCTION performOnOrbitBurn {
	LOCAL currentPressure IS SHIP:BODY:ATM:ALTITUDEPRESSURE(apsis).

	LOCAL tau TO etaToBurn + TIME:SECONDS.

	// LOCAL LOCK r0 TO SHIP:POSITION.
	// LOCAL LOCK r1 TO POSITIONAT(SHIP,tau).
	// LOCAL LOCK deltaR TO r1 - r0.
	//
	// LOCAL LOCK v1 TO VELOCITYAT(SHIP,tau):ORBIT * orbitalInsertionBurnDV.
	// LOCAL LOCK v0 TO SHIP:VELOCITY:ORBIT.
	// LOCAL LOCK burnVector TO deltaR + v1.

	LOCAL burnVector IS calculateBurnVector(orbitalInsertionBurnDV,tau).
	
	LOCK STEERING TO burnVector.

	waitForAlignmentTo(burnVector).
	IF VERBOSE {
		print "Burn deltaV: " + ROUND(orbitalInsertionBurnDV,2).
		print "Burn time: " + ROUND(orbitalInsertionBurnTime,2).
		print "Burn eta: " + ROUND(etaToBurn,2).
	}

	LOCAL startTime IS tau - orbitalInsertionBurnTime/2.


	waitUntil(startTime,useWarp).
	IF useNode {
		LOCAL burnNode IS createOnOrbitManeuverNode().
		ADD burnNode.
		if not hasFile("executeNode.ks",1) {download("executeNode.ks",1).}
		WAIT 0.5.
		RUNONCEPATH("executeNode.ks").
		performManeuverNodeBurn(burnNode).
	} ELSE {
			performBurn(burnVector,startTime,(startTime + orbitalInsertionBurnTime)).
	}

	// WAIT UNTIL TIME:SECONDS >= startTime. {
	// 	SET lockedThrottle TO 1.
	// 	stageLogic().
	// 	WAIT orbitalInsertionBurnTime.
	// 	SET lockedThrottle TO 0.
	// }
}

FUNCTION createOnOrbitManeuverNode {
	LOCAL tau TO etaToBurn + TIME:SECONDS.

	LOCAL onOrbitNode IS NODE(tau, 0, 0, orbitalInsertionBurnDV).
	RETURN onOrbitNode.
}

//======================================


FUNCTION performOrbitalInsertion {
	PARAMETER paramApoapsis IS 100000,
	paramPeriapsis IS 100000,
	paramUseNode IS FALSE,
	paramUseWarp IS FALSE.

	SET targetApoapsis TO paramApoapsis.
	SET targetPeriapsis TO paramPeriapsis.
	SET useWarp TO paramUseWarp.
	SET useNode TO paramUseNode.

	//initializeControls().
	checkPeriapsisMinimumValue().
	correctForEccentricity().
	calculateOrbitBurnParameters().

	performOnOrbitBurn().

}
