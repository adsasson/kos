//bug test

PRINT "SANITY CHECK".



DECLARE FUNCTION bugTest {

	DECLARE PARAMETER gamma IS 45.

	SET currentShip TO SHIP.
	SET atmoHeight TO SHIP:BODY:ATM:HEIGHT.
	SET atmoR TO atmoHeight + SHIP:BODY:RADIUS.
	SET currentHeight TO SHIP:ALTITUDE + SHIP:BODY:RADIUS.

	LOCK currentPeri TO SHIP:ORBIT:PERIAPSIS.
	LOCK currentRp TO SHIP:BODY:RADIUS + SHIP:ORBIT:PERIAPSIS.
	LOCK currentApo TO SHIP:ORBIT:APOAPSIS.
	LOCK currentRa TO SHIP:BODY:RADIUS + SHIP:ORBIT:APOAPSIS.
	LOCK currentAlpha TO SHIP:ORBIT:SEMIMAJORAXIS.

	LOCK currentEcc TO SHIP:ORBIT:ECCENTRICITY.

	SET currentHeading TO currentShip:RETROGRADE.

	LOCK STEERING TO currentHeading.
	WAIT UNTIL VANG(SHIP:FACING:VECTOR, currentHeading) < 2.
	//WAIT 5.
	
	SET currentThrottle TO 0.
	LOCK THROTTLE TO currentThrottle.
	//SET currentThrottle TO 0.5.

	PRINT "throttle " + THROTTLE.
	PRINT "currentThrottle " + currentThrottle.
	SAS OFF. 
	
	IF (currentPeri > atmoHeight) {
		PRINT "dong".
	
		SET currentThrottle TO 0.5.

		//WAIT UNTIL (currentPeri < atmoHeight).
		//	disengageDeployables().
		//RETURN TRUE.
	}
	
	WAIT UNTIL (currentPeri < atmoHeight).
	
	IF (currentPeri < atmoHeight)  {
		PRINT "ding".
		
		LOCK cosTheta TO ((-currentAlpha*currentEcc^2) + currentAlpha - (atmoR))/(currentEcc*(atmoR)).
		//LOCK cosTheta TO ((-currentAlpha*currentEcc^2) + currentAlpha - (currentHeight))/(currentEcc*(currentHeight)).

		LOCK theta TO ARCCOS(cosTheta).

		LOCK tanPhi TO (currentEcc*(sin(theta)))/(1+ currentEcc * cos(theta)).
		LOCK phi TO arctan(tanPhi).
		
		LOCK gamma TO FlightPathAngleAtR(atmoR,currentEcc,currentAlpha).
		

		
		WAIT UNTIL phi > 5.
			SET currentThrottle TO 0.
		PRINT "phi: " + ROUND(phi,2).
		PRINT "gamma: "+ ROUND(gamma,2).
		//RETURN TRUE.
	} 
 
	PRINT "dingdong".
	//SAS ON.
	disengageDeployables().
	engageParachutes().
	SAS ON.
	WAIT 1.
	SET SASMODE TO "RETROGRADE".
	
	WAIT UNTIL SHIP:ALTITUDE <2000. 

	SAS ON.
	WAIT 1.
	SET SASMODE TO "RETROGRADE".
	deployLandingGear().
	UNLOCK STERRING.
	UNSET THROTTLE. 
	UNLOCK THROTTLE.

	RETURN TRUE.
	
}

run orbMechLib.ks.
run shipLib.ks.
bugTest().