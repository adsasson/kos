//orbital maneuver library
@LAZYGLOBAL OFF.
RUNONCEPATH("utilLib.ks").

dependsOn("shipLib.ks").
dependsOn("utilLib.ks").

LOCAL apsis TO SHIP:APOAPSIS.
LOCAL burnDirection TO SHIP:PROGRADE.

IF SHIP:ORBIT:ECCENTRICITY < 1 { //elliptical
	SET apsis TO SHIP:APOAPSIS.
	SET burnDirection TO SHIP:PROGRADE.
} ELSE { //parabolic or hyperbolic
	SET apsis TO SHIP:PERIAPSIS.
	SET burnDirection TO SHIP:RETROGRADE.
}

FUNCTION orbitalInsertion {
	PARAMETER targetAlt IS 0.
	IF SHIP:BODY:ATM:EXISTS {
		IF targetAlt < SHIP:BODY:ATM:HEIGHT {
			SET targetAlt TO SHIP:BODY:ATM:HEIGHT + 1000.
			notify("WARNING: Orbit will not clear atmosphere. " +
							"Adjusting periapsis to " +	targetAlt + " m").
		}
	} ELSE {
		LOCAL minFeatureHeight TO surfaceFeature[SHIP:BODY:NAME].
		IF targetAlt < minFeatureHeight {
			notify("WARNING: Orbit will not clear minimum surface feature altitude."
						+ " Adjusting periapsis to " + minFeatureHeight + " m").
			SET targetAlt TO minFeatureHeight.
		}
	}
	OIBurn(targetAlt).
}

FUNCTION OIBurn {
	PARAMETER targetAlt.
	LOCAL LOCK etaToBurn TO ETA:APOAPSIS.

	IF SHIP:ORBIT:ECCENTRICITY < 1 { //elliptical
		LOCK etaToBurn TO ETA:APOAPSIS.
	} ELSE { //parabolic or hyperbolic
		LOCK etaToBurn TO ETA:PERIAPSIS.
	}

	LOCAL tau TO etaToBurn + TIME:SECONDS.

	LOCAL targetSemiMajorAxis TO (apsis + targetAlt)/2 + SHIP:BODY:RADIUS.
	LOCAL LOCK OIdeltaV TO deltaV(apsis,
																SHIP:ORBIT:SEMIMAJORAXIS,
																targetSemiMajorAxis).
	LOCAL LOCK OIBurnTime TO burnTime(OIdeltaV).

	LOCAL LOCK r0 TO SHIP:POSITION.
	LOCAL r1 TO POSITIONAT(SHIP,tau).
	LOCAL LOCK deltaR TO r1 - r0.

	LOCAL LOCK v1 TO VELOCITYAT(SHIP,tau):ORBIT * OIdeltaV.
	LOCAL LOCK v0 TO SHIP:VELOCITY:ORBIT.
	LOCAL LOCK burnVector TO deltaR + v1.

	LOCAL cThrottle TO 0.
	LOCK THROTTLE TO cThrottle.

	LOCK STEERING TO burnVector:DIRECTION.

	pointTo(burnVector).

	WAIT UNTIL etaToBurn <= OIBurnTime/2. {


	SET cThrottle TO 1.
	stageLogic().
	WAIT OIBurnTime.
	SET cThrottle TO 0.
}

//======================================

DECLARE FUNCTION deltaV {

	//v^2= GM*(2/r-1/a)
	PARAMETER burnPoint,
						alpha1 IS SHIP:BODY:RADIUS,
						alpha2 IS SHIP:BODY:RADIUS,
						cBody IS SHIP:BODY.

	LOCAL r0 TO cBody:RADIUS + burnPoint.

	LOCAL mu TO cBody:MU.
	LOCAL vel1 TO 0.
	LOCAL vel2 TO 0.

	IF (alpha1 > 0) {
		SET vel1 TO SQRT(mu*(2/r0 - 1/alpha1)).
	}
	IF (alpha2 > 0) {
		SET vel2 TO SQRT(mu*(2/r0 - 1/alpha2)).
	}

	return ABS(vel1 - vel2).
}

DECLARE FUNCTION deltaVgeneral {

	//v^2= GM*(2/r-1/a)
	PARAMETER alt1 IS SHIP:ALTITUDE,
						alt2 IS SHIP:ALTITUDE,
						alpha1 IS SHIP:ORBIT:SEMIMAJORAXIS,
						alpha2 IS SHIP:ORBIT:SEMIMAJORAXIS,
						cBody IS SHIP:BODY.

	LOCAL r1 TO cBody:RADIUS + alt1.
	LOCAL r2 TO cBody:RADIUS + alt2.
	LOCAL mu TO cBody:MU.
	LOCAL vel1 TO 0.
	LOCAL vel2 TO 0.

	IF (alpha1 > 0) {
		SET vel1 TO SQRT(mu*(2/r1 - 1/alpha1)).
	}
	IF (alpha2 > 0) {
		SET vel2 TO SQRT(mu*(2/r2 - 1/alpha2)).
	}

	return ABS(vel1 - vel2).
}
//===============================================
//burn time.

// Base formulas:
// deltav = integral F / (m0 - consumptionRate * t) dt
// consumptionRate = F / (Isp * g)
// integral deltav = integral F / (m0 - (F * t / g * Isp)) dt

// Integrate:
// integral F / (m0 - (F * t / g * Isp)) dt = -g * Isp * log(g * m0 * Isp - F * t)
// F(t) - F(0) = known ?v
// Expand, simplify, and solve for t
// credit: gisikw, reddit.

//parameters SHIP, deltaV.
DECLARE FUNCTION burnTime {
	DECLARE PARAMETER currentDeltaV, currentShip IS SHIP, pressure is 0.

	LOCAL totalFuelMass TO SHIP:MASS - SHIP:DRYMASS.

	LOCAL g0 TO 9.82.

	LOCAL enginesLex TO engineStats(pressure).
	LOCAL avgISP TO enginesLex["avgISP"].
	LOCAL totalThrust TO enginesLex["totalThrust"].
	LOCAL burn TO 0.

	//check for div by 0.
	IF totalThrust > 0 {
		SET burn TO g0 * SHIP:MASS * avgISP *
		(1-CONSTANT:E^(-currentDeltaV / (g0 * avgISP)))
		/totalThrust.
	} ELSE {
		notify("ERROR: AVAILABLE THRUST IS 0.").
	}

	PRINT "BURN TIME FOR " + ROUND(currentDeltaV,2) + "m/s: " + ROUND(burn,2) + " s" AT (0,TERMINAL:HEIGHT - 1).
	RETURN burn.
}


DECLARE FUNCTION killRelativeVelocity {
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
