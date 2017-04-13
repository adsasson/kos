//orbital maneuver library
@LAZYGLOBAL OFF.
dependsOn("shipLib.ks").
dependsOn("util.ks").

DECLARE FUNCTION orbitalInsertion {

	RUNONCEPATH("orbMechLib.ks").

	//to be used in vacuum, assumes ship has cleared atmo.

	PARAMETER targetPeri IS 0.

	//adjust default periapsis for atmospheric height/terrain height
		IF SHIP:BODY:ATM:EXISTS {
			LOCAL atmoHeight TO SHIP:BODY:ATM:HEIGHT.
			IF targetPeri < atmoHeight {
				notify("ORBIT WILL NOT CLEAR ATMOSPHERE. ADJUSTING PERIAPSIS TO " +
								atmoHeight + 1000 + " m").
				SET targetPeri TO atmoHeight + 1000.
			}
		} ELSE {
			LOCAL minFeatureHeight TO surfaceFeature[SHIP:BODY:NAME].
			IF targetPeri < minFeatureHeight {
				notify("ORBIT WILL NOT CLEAR MINIMUM SURFACE FEATURE ALTITUDE." +
							" ADJUSTING PERIAPSIS TO " + minFeatureHeight + " m").
				SET targetPeri TO minFeatureHeight.
			}
		}

		//BURN CALCULATIONS
		LOCAL targetAlpha TO (SHIP:ORBIT:APOAPSIS + targetPeri)/2 + SHIP:BODY:RADIUS.
		LOCK OIdeltaV TO deltaV(SHIP:ORBIT:APOAPSIS, SHIP:ORBIT:SEMIMAJORAXIS, targetAlpha).
		LOCAL OIBurnTime TO burnTime(OIDeltaV,SHIP).

		//DIRECTION VECTORS
		LOCK progradeVec TO SHIP:PROGRADE:FOREVECTOR.
		LOCK cPhi TO flightPathAngle().
		LOCK targetVector TO progradeVec + R(0,-cPhi/2,0).
		LOCK targetHeading TO targetVector:DIRECTION.

		PRINT "Setting Periapsis to " + targetPeri.
		PRINT "DeltaV: " + ROUND(OIdeltaV,2) + " m/s".
		PRINT "Burn Time: " + ROUND(OIBurnTime,2) + " sec".

		LOCK STEERING TO targetHeading.

		IF (SHIP:ORBIT:MEANANOMALYATEPOCH > 0) OR ETA:APOAPSIS > OIBurnTime {
			notify("WAITING FOR apoapsis.").
			WAIT UNTIL ETA:APOAPSIS <= OIBurnTime/2.
		}

			LOCK mAcc TO SHIP:MAXTHRUST/SHIP:MASS.
			IF (mAcc > 0) {
				LOCK cThrottle TO MIN(ABS(OIdeltaV)/(MAX(0.0001,mAcc), 1).
			}
			LOCK THROTTLE TO cThrottle.

		LOCAL done TO FALSE.
		UNTIL done {
			stageLogic().
				clearscreen.
				PRINT "DeltaV: " + ROUND(OIdeltaV*COS(cPhi),2) + " m/s" AT (TERMINAL:WIDTH/2,0).
				IF (ABS(OIdeltaV*COS(cPhi)) < 0.1) {
				notify("FINALIZING BURN").
				LOCK THROTTLE TO 0.
				SET done TO TRUE.
			}
		}
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

	LOCAL enginesLex TO enginesStats(pressure).
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

	PRINT "BURN TIME FOR " + ROUND(currentDeltaV,2) + "m/s: " + ROUND(burn,2) + "s" AT (TERMINAL:WIDTH/2,0).
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
