

PRINT "SANITY CHECK".
UNLOCK ALL.

//ATMO RE_ENTRY
//target slope of reentry.
//Calculate target peri for burn altitude for target slope
//calculate delta v and burn time
//orient and burn

//retract deployables.
//orient for heat

//if fuel, control descent further?

//stage until heat shield

//stage logic for parachutes.

//gear
DECLARE FUNCTION atmoReentry {

	DECLARE PARAMETER gamma IS 45.

	PRINT "START".
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

	//LOCK STEERING TO SHIP:RETROGRADE.
	LOCK STEERING TO currentHeading.
	
	PRINT "ship "+ currentShip:NAME.

	SET currenThrottle TO 0.
	LOCK THROTTLE TO currentThrottle.
	SET currentThrottle TO 0.5.

	PRINT "throttle " + THROTTLE.
	PRINT "currentThrottle " + currentThrottle.
	SAS OFF. 
	
	
	IF (currentPeri < atmoHeight)  {
		PRINT "ding".
		LOCK cosTheta TO ((-currentAlpha*currentEcc^2) + currentAlpha - (atmoR))/(currentEcc*(atmoR)).
		//LOCK cosTheta TO ((-currentAlpha*currentEcc^2) + currentAlpha - (currentHeight))/(currentEcc*(currentHeight)).

		LOCK theta TO ARCCOS(cosTheta).

		LOCK tanPhi TO (currentEcc*(sin(theta)))/(1+ currentEcc * cos(theta)).
		LOCK phi TO arctan(tanPhi).

		PRINT "phi "+ phi.

		PRINT "THETA: " + ROUND(theta,2).
		PRINT "PHI: " + ROUND(phi,2).
		WAIT UNTIL phi > 5.
		SET currentThrottle TO 0.
		RETURN TRUE.
	} ELSE {
		PRINT "dong".

		LOCK currentThrottle TO SHIP:CONTROL:PILOTMAINTHROTTLE.
		

		LOCK THROTTLE TO currentThrottle.
		SET currentThrottle TO 0.5.
		WAIT UNTIL (currentPeri < atmoHeight).
		RETURN TRUE.
	}

	SAS ON.
	PANELS OFF. 
	RADIATIORS OFF.
	WHEN (NOT CHUTESSAFE) THEN {
		CHUTESSAFE ON.
		RETURN (NOT CHUTES).
	}

	
}

SET tSet TO 0.
LOCK THROTTLE TO tSet.

SET done TO FALSE.

UNTIL done {
	SET tSET TO 0.1.
	WAIT 2.
	SET done TO TRUE.
}


atmoReentry().