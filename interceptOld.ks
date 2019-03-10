@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

dependsOn("hohmann.ks").
dependsOn("executeNode.ks").

LOCAL targetBody.
//INTERCEPT FUNCTION -- HOHMANN
//USES A HOHMANN TRANSFER (GENERALIZED FOR ELLIPTICAL ORBITS THAT ARE COLINEAR WITH RESPECT TO ARGUMENT OF PERIAPSIS AND ARE COINCLINED)
//CALCULATES THE TRANSFER ORBIT PARAMETERS, AND PHASE ANGLE FOR INTERCEPTION
//CALCULATES THE DELTA V NEEDED FOR TRANSFER ORBIT MANEUVERS.
//WAITS FOR CORRECT PHASE ANGLE BETWEEN SHIP AND TARGET TO INITIATE BURN.
//****PLEASE NOTE***** BECAUSE THE PHASE ANGLE AT SHIP PERIAPSIS AND TARGET FOR ELLIPTICAL ORBITS MAY NOT COINCIDE, I STRONGLY RECOMMEND THAT THE STARTING ORBIT BE
//CIRCULAR TO ELIMINATE UNECESSARILY WAITING FOR THE CORRECT PHASE ANGLE BETWEEN SHIP AND TARGET.

//MAY TRY TO GENERALIZE FOR ELIPTICAL ORBITS AT ANGLE AND/OR ELLIPTICAL STARTING ORBITS WITH TRANSFER ORBIT INITIATION AT AN ARBITRARY POINT WITH CORRECT PHASE ANGLE AND
//ADJUSTING CALCUATED DELTA V FOR BURN AT POINT OTHER THEN FIRST ORBIT PERIAPSIS
//WOULD HAVE TO MIN/MAX PHASE ANGLE FOR TARGET AT APOAPSIS AND SHIP AT SOME ARBITRARY POINT ON ORBIT 1


//TERMS:
//STARTING ORBIT == ORBIT 1.
//TARGET ORBIT == ORBIT 2.
//TRANSFER ORBIT == ORBIT T.
//INITIAL TRANSFER BURN == BURN_1
//FINAL TRANSFER BURR == BURN_2

//ORBITAL PARAMETERS BASED ON THIS NOMENCLATURE.
//FOR EXAMPLE, PERIAPSIS OF ORBIT 1 == PERI_1.
//SEMI-MAJOR AXIS OF TRANSFER ORBIT == A_T

//GENERAL APPROACH:
//CALCULATE TRANSFER ORBIT SEMI-MAJOR AXIS.
//CALCULATE TRANSFER ORBIT TOF.
//CALCULATE MEAN MOTION OF TARGET
//CALCULATE ECCENTRIC ANOMALY AT BURN_1 FROM MEAN ANOMALY AT INTERCEPT (WHICH SHOULD BE APO_2), AND THEREFORE 180 DEGREES/PI RADIANS, LESS MEAN MOTION * TOF.
//CALCULATE TRUE ANOMALY OF TARGET AT BURN 1.
//PHASE ANGLE SHOULD BE TRUE ANOMALY TARGET - TRUE ANOMALY SHIP, BUT BURN ONE SHOULD BE AT PER1_1 SO TRUE ANOMALY SHIP SHOULD BE 0.


//CALCULATE DELTA V == DELTA V BURN_1 + DELTA V BURN_2
//DELTA V BURN_1 == ORBIT_T VELOCITY AT PERI (PERI_T) - VELOCITY AT PERI_1.
//DELTA V BURN_2 == VELOCITY AT APO_2 - VELOCITY AT APO_T

//PLEASE NOTE THIS ASSUMES SMALLER ORBIT TO LARGER ORBIT (A_2 > A_1). TERMS WILL BE REVERSED FOR LARGER ORBIT TO SMALLER ORBIT.

//===========================================================================================================//
FUNCTION timeToPhaseAngle {
	PARAMETER targetPhaseAngle.

	//targetPhase Angle = startPhaseAngle + deltaAngVelocity*time
	//targetPhaseAngle - startPhaseAngle/(deltaAngVelocity) = time
	//(targetPhase Angle - (deltaTrueAnomaly))/deltaAngularVelocity = time
	//angular velocity = radians/SECONDS
	//orbital velocity is meters per second, so radians*circumference = meters
	//radians/second = m/s/circuferemce

	LOCAL targetTrueAnomaly targetBody:ORBIT:TRUEANOMALY.
	LOCAL vesselTrueAnomaly IS SHIP:ORBIT:TRUEANOMALY.
	LOCAL startingPhaseAngle IS targetTrueAnomaly - vesselTrueAnomaly.
	LOCAL targetAngularVelocity IS targetBody:VELOCITY:ORBIT.
	LOCAL vesselAngularVelocity IS SHIP:VELOCITY:ORBIT.

	RETURN (targetPhaseAngle - startingPhaseAngle)/(targetAngularVelocity - vesselAngularVelocity).
}

FUNCTION calculateInterceptNode {
	//assumes coplanar circular orbits, assumes same parent body.

	LOCAL targetAltitude IS targetBody:ALTITUDE.
	LOCAL shipAltitude IS SHIP:ALTITUDE.

	LOCAL hohmmanStatsLex IS hohmannStats(shipAltitude,targetAltitude).
	LOCAL targetPhaseAngle IS hohmmanStatsLex["phaseAngle"].
	LOCAL timeToPhaseAngle IS timeToPhaseAngle(targetPhaseAngle).
	hohmannNodes(hohmmanStatsLex,TIME:SECONDS + timeToPhaseAngle).
}

FUNCTION hillClimbClosestApproachTime {
	PARAMETER closestApproachDistance IS 5000, startingTimeIncrement IS 10000.
	LOCAL timeIncrement IS startingTimeIncrement.
	LOCAL tau IS TIME:SECONDS.
	LOCAL oldTargetDistance IS ABS(POSITIONAT(targetBody,tau):MAG - POSITIONAT(SHIP,tau):MAG).
	LOCAL newTargetDistance IS ABS(POSITIONAT(targetBody,(tau + timeIncrement)):MAG -
	POSITIONAT(SHIP, (tau + timeIncrement)):MAG).

	UNTIL timeIncrement < 10 {
		IF newTargetDistance <= oldTargetDistance { //old solution is better than new solution
			SET timeIncrement TO timeIncrement/2. //decrease time increment by factor of 10.
			SET oldTargetDistance TO newTargetDistance.
		} ELSE {
			SET tau TO tau + timeIncrement.
		}
		SET newTargetDistance TO ABS(POSITIONAT(targetBody,(tau + timeIncrement)):MAG -
		POSITIONAT(SHIP, (tau + timeIncrement)):MAG).
	}
	IF ABS(oldTargetDistance) <= closestApproachDistance {
		RETURN tau.
	} ELSE {
		notify("Closest approach to " + targetBody + " is " + ROUND(ABS(oldTargetDistance),2) +
		" which is greater than " + closestApproachDistance).
		RETURN tau.
	}
}

FUNCTION performIntercept {
	SET targetBody TO TARGET.
	IF (DEFINED targetBody) {
		calculateInterceptNode().
		run executeNode.ks.
	} ELSE {
		notifyError("Intercept.ks: Target is umdefined.").
	}

}

performIntercept().
// SET currentShip TO SHIP.
// SET currentMu TO currentShip:BODY:MU.
// SET currentRadius TO currentShip:BODY:RADIUS.
//
// //check if ship has target
// IF HASTARGET { //this doesn't work
// //IF TARGET:SHIP:NAME {
//
//
// //	SET currentTarget TO currentShip:TARGET.
// 	SET currentTarget TO TARGET.
//
// 	//DEBUG
// 	PRINT "current Target: " + currentTarget.
// 	//DEBUG
//
// 	SET apo1 TO currentShip:ORBIT:APOAPSIS + currentRadius.
// 	SET peri1 TO currentShip:ORBIT:PERIAPSIS + currentRadius.
// 	SET a1 TO currentShip:ORBIT:SEMIMAJORAXIS. //you could also calculate this from above.
//
// 	//calculate mean motion of ship (currently in orbit 1)
//
// 	SET meanMotion1 TO (SQRT(currentMu/apo1^3)).
//
// 	SET apo2 TO currentTarget:ORBIT:APOAPSIS + currentRadius.
// 	SET peri2 TO currentTarget:ORBIT:PERIAPSIS + currentRadius.
// 	SET a2 TO currentTarget:ORBIT:SEMIMAJORAXIS.
// 	SET ecc2 TO currentTarget:ORBIT:ECCENTRICITY.
//
// 	//calculate MEAN MOTION OF TARGET. (mean motion is inverse of period)
// 	SET meanMotion2 TO (SQRT(currentMu/apo2^3)).
//
// 	//TRANSFER ORBIT WILL HAVE SEMI-MAJOR AXIS WITH PERIAPSIS AT PERIAPSIS OF ORBIT 1, AND APOAPSIS AT APOAPSIS OF ORBIT 2. THIS DEFINES SEMIMAJOR AXIS FOR TRASNFER ORBIT.
//
// 	SET apoT TO apo2.
// 	SET periT TO peri1.
// 	//a == (Rmin + Rmax)/2.
// 	//or a == Rmin/(1-e)
// 	//or a == Rmax/(1+e)
// 	SET aT TO (apoT + periT)/2.
//
// 	//TOF will be half the period of the transfer orbit. Period == 2pi *sqrt (a^3/mu).
// 	SET timeOfFlight TO CONSTANT:PI * SQRT(apoT^3/currentMu).
//
//
// 	//mean anomaly at intercept should be at target periapsis or mean anomaly of 180 degrees.
// 	//so MEAN ANOMALY AT INTERCEPT (180) = MEAN ANOMALY AT BURN_1 + MEANMOTION * TOF
//
// 	SET meanAnAtBurn1 TO 180/(meanMotion2*timeOfFlight).
//
//
// 	//calculate eccentric anomaly of orbit_2 from Mean Anomaly (this requires orbMechLib)
//
// 	SET eccAnAtBurn1 TO MeanAnToEccAn(meanAnAtBurn1,ecc2).
//
// 	//calculate true anomaly at burn_1
//
// 	SET trueAnAtBurn1 TO EccAnToTrueAn(eccAnAtBurn1,ecc2).
//
// 	SET burnPhaseAngle TO trueAnAtBurn1.
//
// 	//DEBUG
// 	PRINT "BurnPhaseAngle: " + ROUND(burnPhaseAngle,2).
// 	PRINT "MEAN MOTION 1: " + ROUND(MeanMotion1,2) + " MEAN MOTION 2: " + ROUND(MEANMOTION2,2).
// 	//DEBUG
//
// 	LOCK shipAngle TO currentShip:ORBIT:LONGITUDEOFASCENDINGNODE + currentShip:ORBIT:ARGUMENTOFPERIAPSIS + currentShip:TRUEANOMALY.
// 	LOCK targetAngle TO currentTarget:ORBIT:LONGITUDEOFASCENDINGNODE + currentTarget:ORBIT:ARGUMENTOFPERIAPSIS + currentTarget:TRUEANOMALY.
//
// 	LOCK phaseAngle TO (targetAngle - shipAngle) - 360 * (FLOOR((targetAngle-phaseAngle)/360)).
//
// 	//LOCK currentPhaseAngle TO currentTarget:TRUEANOMALY - currentShip:TRUEANOMALY.
//
// 	//if the orbits don't have the same argument of periapsis, then this will need to be corrected.
// 	//?? Target Angle = Long of Asc Node + arg of Peri + trueAn
// 	//?? ship angle = same as above for ship
// 	//phase angle = target angle - ship angle. phase angle = phaseangle - 360deg*(FLOOR(phase angle/360)
//
// 	//calculate time to burn:
// 	//you also can get time to burn1 from this (again assumes orbit 1 is essentially circular).
// 	//phase angle final = phase angle initial + (mean motion target - mean motino ship) * time to Burn.
// 	//time to burn = (phase angle final phase angle intial)/(mean motion target - mean motion ship).
//
//
// 	SET deltaPhi TO MOD((MeanAnAtBurn1 - currentTarget:ORBIT:MEANANOMALYATEPOCH+360),360).
// 	//SET deltaPhi TO (deltaPhi - 360) * (FLOOR(deltaPhi/360)).
//
// 	//DEBUG
// 	PRINT "Mean An at Burn: " + ROUND(MeanAnAtBurn1,2).
// 	PRINT "MeanAn at Epoch: " + ROUND(currentTarget:ORBIT:MEANANOMALYATEPOCH,2).
// 	PRINT "Delta Phi: "+ ROUND(deltaPhi,2).
// 	//DEBUG
//
// 	SET timeToBurn TO deltaPhi/(MeanMotion2 - MeanMotion1).
//
// 	//DEBUG
// 	PRINT "Time To Burn (min) : " + ROUND(timeToBurn/60,2).
// 	//DEBUG
//
// 	//calculate deltaV
//
// 	SET peri1vel TO visviva(peri1,a1).
// 	SET periTvel TO visviva(perit,at).
//
// 	SET deltaBurn1 TO abs(periTvel - peri1vel).
//
// 	SET burnTime1 TO burn_time(currentShip,deltaBurn1).
//
// 	SET apoTvel TO visviva(apoT,aT).
// 	SET apo2vel TO visviva(apo2,a2).
//
// 	SET deltaBurn2 TO abs(apo2vel - apoTvel).
//
// 	SET burnTime2 TO burn_time(currentShip,deltaBurn2).
//
// 	SET totalDeltaV TO deltaBurn1 + deltaBurn2.
//
// 	//DEBUG
// 	PRINT "Delta 1: " + ROUND(deltaBurn1,2).
// 	PRINT "Delta 2: " + ROUND(deltaBurn2,2).
// 	//DEBUG
//
// 	//Set direction
//
//
//
// 	//WAIT UNTIL timeToBurn < burnTime1/2.
//
//
//
// } ELSE {
// 	PRINT "NO TARGET SET. EXITING.".
// 	RETURN FALSE.
// }
