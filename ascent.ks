//ASCENT
//atmospheric vs airless


//orbit library
RUNONCEPATH("shipLib.ks").

DECLARE FUNCTION ascentInclination {
	PARAMETER targetInclination IS 0, targetApo IS 100000.
	ascent(targetInclination + 90, targetApo).
}

////////////////////////////////////////////////////////////

DECLARE FUNCTION ascent {
	PARAMETER targetHeading IS 90, targetApo IS 100000.

	//sanitize input
	IF targetHeading > 360 {
		LOCAL thMod TO MOD(targetHeading,360).
		LOCAL targetHeading TO targetHeading - 360*thMod.
	}

	//call ascent routine

	IF SHIP:BODY:ATM:EXISTS {
	
		ascentCurve(targetHeading, targetApo, SHIP:BODY:ATM:HEIGHT).
		
		ON (SHIP:ALTITUDE > SHIP:BODY:ATM:HEIGHT) {
			engageDeployables().
		}
	
		WAIT UNTIL (SHIP:ALTITUDE >= SHIP:BODY:ATM:HEIGHT + 100).
		
		//correct for drag?
		IF (SHIP:APOAPSIS < targetApo) {
			PRINT "Correcting apoapsis for atmospheric drag.".
			
			LOCAL cHeading TO HEADING(targetHeading,0).
			LOCK STEERING TO cHeading.
			
			WAIT UNTIL ABS(cHeading:PITCH - SHIP:FACING:PITCH) < 0.15 AND ABS(cHeading:YAW - SHIP:FACING:YAW) < 0.15.
			
			LOCAL cThrottle TO 0.1.
			LOCK THROTTLE to cTHROTTLE.
			
			WAIT UNTIL (SHIP:APOAPSIS >= targetApo).
			
			SET cThrottle TO 0.
			
			UNLOCK THROTTLE.
			UNLOCK STEERING.
		}

	} ELSE {
		ascentCurve(targetHeading, targetApo, targetApo).
		engageDeployables().
	}
}

///////////////////////////////////////////////////////////

DECLARE FUNCTION ascentCurve {
	PARAMETER targetHeading IS 90, targetApo IS 100000, scaleHeight IS 100000.

	//initialize controls

	SAS OFF.
	SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.

//++++++DECLARATIONS
	LOCAL cShip TO SHIP. 		//current Ship
	LOCAL cBody TO cShip:BODY. 	//current Body
		
	LOCAL cPitch TO 0.		//current Pitch
	LOCAL cHeading TO HEADING(targetHeading,cPitch). //currentHeading.


	//THRUST locks
	LOCK cThrottle TO SHIP:CONTROL:PILOTMAINTHROTTLE. //current Throttle
	LOCAL cThrottle TO 0.5.

	LOCK cMass TO cShip:MASS.
	LOCK cGravity TO cBody:MU/(cShip:ALTITUDE + cBody:RADIUS)^2. //gravity for altitude
	LOCK maxTWR TO (cShip:AVAILABLETHRUST/(cMass * cGravity)).

	LOCK cTWR TO maxTWR * cThrottle. //current TWR

	LOCK THROTTLE TO cThrottle.

	//NAVIGATION locks
	LOCK STEERING TO cHeading.
	LOCK Ka TO ROUND((cShip:ALTITUDE/scaleHeight),2). //normalize altitude to scaleHeight

	//ascent curves
	//LOCK deltaPitch TO 90 * (1.5 * Ka). //known good curve
	LOCK deltaPitch TO 90 * SQRT(Ka). //more efficient curve 
	

	//TWR PID LOOP SETTINGS
	LOCAL Kp TO 0.1.
	LOCAL Ki TO 0.006.
	LOCAL Kd TO 0.001.
	LOCAL twrPID TO PIDLOOP(Kp,Ki,Kd).
	SET twrPID:SETPOINT TO 2.
	//SET twrPID:MAXOUTPUT TO maxTWR. //pid doesn't seem to work correctly when limits set
	//SET twrPID:MINOUTPUT TO 0.

//++++++ASCENT LOOP

	UNTIL cSHIP:APOAPSIS >= targetApo {
		SET cThrottle TO cThrottle + twrPID:UPDATE(TIME:SECONDS, cTWR). //thrust PID LOOP
		SET cPitch TO 90 - (MIN(90,deltaPitch)). //pitch for ascent curve
		SET cHeading TO HEADING(targetHeading,cPitch).

		stageLogic().

		WAIT 0.
	}

	PRINT "TARGET APOAPSIS REACHED".
	
	//DEINITIALIZE
	SET cThrottle TO 0.
	UNLOCK THROTTLE.
	UNLOCK STEERING.
}