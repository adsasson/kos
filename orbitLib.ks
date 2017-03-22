//orbital maneuver library
runoncepath("shipLib.ks").

GLOBAL surfaceFeature TO LEXICON("Mun","4000","Minimus","6250","Ike","13500",
																"Gilly","7500","Dres","6500","Moho","7500",
																"Eeloo","4500","Bop","23000","Pol","6000",
																"Tylo","13500","Vall","9000").


DECLARE FUNCTION orbitalInsertion {

	RUNONCEPATH("orbMechLib.ks").

	//to be used in vacuum, assumes ship has cleared atmo.

	PARAMETER targetPeri IS 0.

	//adjust default periapsis for atmospheric height/terrain height
		IF SHIP:BODY:ATM:EXISTS {
			LOCAL atmoHeight TO SHIP:BODY:ATM:HEIGHT.
			IF targetPeri < atmoHeight {
				PRINT "ORBIT WILL NOT CLEAR ATMOSPHERE. ADJUSTING PERIAPSIS TO " + atmoHeight + 1000 + " m".
				SET targetPeri TO atmoHeight + 1000.
			}
		} ELSE {
			LOCAL minFeatureHeight TO surfaceFeature[SHIP:BODY:NAME].
			IF targetPeri < minFeatureHeight {
				PRINT "ORBIT WILL NOT CLEAR MINIMUM SURFACE FEATURE ALTITUDE. ADJUSTING PERIAPSIS TO " + minFeatureHeight + " m".
				SET targetPeri TO minFeatureHeight.
			}
		}

		//BURN CALCULATIONS
		LOCAL targetAlpha TO (SHIP:ORBIT:APOAPSIS + targetPeri)/2 + SHIP:BODY:RADIUS.
		LOCK OIdeltaV TO deltaV(SHIP:ORBIT:APOAPSIS, SHIP:ORBIT:SEMIMAJORAXIS, targetAlpha).
		LOCAL OIBurnTime TO burnTime(OIDeltaV,SHIP).

	LOCAL nodeFlag TO FALSE.

	IF nodeFlag {
		LOCAL OInode TO NODE(TIME:SECONDS + ETA:APOAPSIS, 0, 0, OIdeltaV).
		ADD OInode.
		run executeNode.

	} ELSE {
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
			PRINT "WAITING FOR apoapsis.".
			WAIT UNTIL ETA:APOAPSIS <= OIBurnTime/2.
		}

			LOCK mAcc TO SHIP:MAXTHRUST/SHIP:MASS.
			LOCK cThrottle TO MIN(ABS(OIdeltaV)/mAcc, 1).
			LOCK THROTTLE TO cThrottle.

		LOCAL done TO FALSE.
		UNTIL DONE {
			stageLogic().
				clearscreen.
				PRINT "DeltaV: " + ROUND(OIdeltaV,2) + " m/s".
				IF (ABS(OIdeltaV) < 0.1) {
				PRINT "FINALIZING BURN".
				LOCK THROTTLE TO 0.
				SET done TO TRUE.
			}
		}
	}
}

//======================================

DECLARE FUNCTION deltaV {

	//v^2= GM*(2/r-1/a)
	PARAMETER burnPoint, alpha1 IS SHIP:BODY:RADIUS, alpha2 IS SHIP:BODY:RADIUS, cBody IS SHIP:BODY.

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
//======================================
DECLARE FUNCTION deltaVhohmann {
	//this only works for circular orbits.

	PARAMETER start, end, cBody IS SHIP:BODY.

	LOCAL r0 TO start + cBody:RADIUS.
	LOCAL r1 TO end  + cBody:RADIUS.

	LOCAL currentMu TO cBody:MU.

	LOCAL currentDeltaV TO SQRT(currentMu/r0)*(sqrt((2*r1)/(r0+r1))-1).

	return currentDeltaV.
}


DECLARE FUNCTION deltaVgeneral {

	//v^2= GM*(2/r-1/a)
	PARAMETER alt1 IS 0, alt2 IS 0, alpha1 IS 0, alpha2 IS 0, cBody IS SHIP:BODY.

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
	DECLARE PARAMETER currentDeltaV, currentShip IS SHIP.

	LIST ENGINES IN currentEngines.

	LOCAL totalFuelMass TO SHIP:MASS - SHIP:DRYMASS.

	LOCAL g0 TO 9.82.


	LOCAL totalThrust TO 0.
	LOCAL totalIsp TO 0.
	LOCAL avgISP TO 0.

	LOCAL currentStage TO STAGE:NUMBER.

	FOR eng IN currentEngines {
		IF eng:IGNITION {
				SET totalThrust TO totalThrust + eng:AVAILABLETHRUST.
				SET totalISP TO totalISP + (eng:AVAILABLETHRUST/eng:ISP).
		}
	}
	IF totalISP > 0 {
		SET avgISP TO totalThrust/totalISP.
	}
	LOCAL burn TO 0.
	//check for div by 0.
	IF totalThrust > 0 {
		SET burn TO g0*SHIP:MASS*avgISP*(1-CONSTANT:E^(-currentDeltaV/(g0*avgISP)))/totalThrust.
	} ELSE {
		PRINT "ERROR: AVAILABLE THRUST IS 0.".
	}

	PRINT "BURN TIME FOR " + ROUND(currentDeltaV,2) + "m/s: " + ROUND(burn,2) + "s".
	RETURN burn.
}
//=================================================
DECLARE FUNCTION minAirlessPeri {
	DECLARE PARAMETER airlessBody.

	LOCAL bodyName TO airlessBody:Name.
	LOCAL minPeri TO 0.

	IF bodyName = "Mun" {
			SET minPeri TO 4000.
	} ELSE IF bodyName = "Minimus" {
			SET minPeri TO 6250.
	} ELSE IF bodyName = "Ike" {
			SET minPeri TO 13500.
	} ELSE IF bodyName = "Gilly" {
				SET minPeri TO 7500.
	} ELSE IF bodyName = "Dres" {
			SET minPeri TO 6500.
	} ELSE IF bodyName = "Moho" {
			SET minPeri TO 7500.
	} ELSE IF bodyName = "Eeloo" {
			SET minPeri TO 4500.
	} ELSE IF bodyName = "Bop" {
			SET minPeri TO 23000.
	} ELSE IF bodyName = "Pol" {
			SET minPeri TO 6000.
	} ELSE IF bodyName = "Tylo" {
			SET minPeri TO 13500.
	} ELSE IF bodyName = "Vall" {
			SET minPeri TO 9000.
	} ELSE {
		PRINT "Fell through airless body height. Something is wrong".
	}

	return minPeri.
}
