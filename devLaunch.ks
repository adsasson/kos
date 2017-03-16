//LAUNCH script
//Takes Target Apo, Target Heading, and targetPeri. 
//Initiates GT to target Apo, PID to TWR (though may change to target air resistance or max q). 
//Calls onOrbitBurn at target apo

run orbitLib.ks.

DECLARE PARAMETER targetHeading IS 90, targetApo IS 100000, targetPeri IS 0.
sanityCheck().
WAIT 3.

LOCAL OKtoLAUNCH TO FALSE.
LOCAL OKtoSTAGE TO FALSE. //may remove

SET currentShip TO SHIP.
SET currentBody TO currentShip:BODY.
LOCAL atmoHeight TO 0.
//LOCAL targetPeri TO 0. 							//until you can figure out minimun altitude for atmosphere vs terrain features on airless worlds.
LOCAL currentPitch TO 90.
LOCK currentThrottle TO SHIP:CONTROL:PILOTMAINTHROTTLE.


LOCK currentMass TO currentShip:MASS.
LOCK currentG to currentBody:MU/(currentShip:ALTITUDE + currentBody:RADIUS)^2.
LOCK maxTWR TO (currentShip:AVAILABLETHRUST/(currentMass * currentG)).
LOCK currentTWR TO maxTWR * currentThrottle.

IF currentBody:ATM:EXISTS { 				//check for atmo, if present, set peri to atmo + 1000
	SET atmoHeight TO currentBody:ATM:HEIGHT.
		IF targetApo >= atmoHeight {
			SET OKtoLaunch TO TRUE.
			IF targetPeri < atmoHeight {
				SET targetPeri TO (atmoHeight + 1000).
				PRINT "Target periapsis does not clear atmosphere. Setting target Periapsis to " + targetPeri.
			}
		} ELSE {
		PRINT "Target Apoapsis will not clear " + currentBody:NAME + "'s atmosphere.".
	}
}

//TWR PID LOOP SETTINGS
SET Kp TO 0.1.
SET Ki TO 0.006.
SET Kd TO 0.001.
SET twrPID TO PIDLOOP(Kp,Ki,Kd).
SET twrPID:SETPOINT TO 2.

//HEADING
SET currentHeading TO HEADING(targetHeading,currentPitch).
SET Ka TO 1.

//LAUNCH ROUTINE
//?countdown?

SET currentThrottle TO 0.5.
LOCK STEERING TO currentHeading.
LOCK THROTTLE TO currentThrottle.

IF OKtoLaunch {
	STAGE.
} ELSE {
	PRINT "No go for launch".
}
LOCK currentStage TO STAGE.
LOCK nextStage TO currentStage:NUMBER - 1.


//atmospheric ascent with gravity turn. make general by testing for atmoshpere and choosing different Ka/pitch formula

LOCK Ka TO ROUND((currentShip:ALTITUDE/atmoHeight),2). //fraction of atmosphere height

LOCK deltaPitch TO 90 * (1.5 * Ka).
//LOCK deltaPitch TO 90 * -CONSTANT:E^(-Ka). //diffferent ascent curves
//LOCK deltaPitch TO 90 * LN(MAX(Ka,0.01)).

UNTIL currentShip:APOAPSIS >= targetApo {
	SET currentThrottle TO MIN(1, MAX(0,currentThrottle + twrPID:UPDATE(TIME:SECONDS, currentTWR))).
	SET currentPitch TO 90 - (MIN(90,deltaPitch)).
	
	SET currentHeading TO HEADING(targetHeading,currentPitch).
	
	
	//TEST STAGING LOGIC
	WHEN NOT (currentShip:AVAILABLETHRUST > 0) THEN {
		PRINT "TIME TO STAGE " + STAGE:NUMBER.
		STAGE.
		IF STAGE:NUMBER > 0 {
			RETURN TRUE. 
		} ELSE {
			RETURN FALSE.
		}
	}

	WAIT 0.
}

PRINT "Target Apoapsis Reached.".

IF currentShip:ALTITUDE < targetApo {
	SET currentThrottle TO 0.
}

LOCK currentHeading TO currentShip:PROGRADE.

//TODO deploy deployables

//ORBITAL INSERTION
//placeholder for now. Need to generalize to function that can take a vector and start altitude or node.
//will need:
//delta V calculation
//burn time calculation
//burn control method.

SET alpha TO currentShip:ORBIT:SEMIMAJORAXIS.

SET OIdeltaV TO deltaV(currentShip:ORBIT:PERIAPSIS, targetPeri).
PRINT "OI DELTA: " + OIdeltaV.

SET OIBurnTime TO burn_Time(currentShip,OIDeltaV).

PRINT "OI BURN TIME: " + OIBurnTime.

IF (currentShip:ORBIT:MEANANOMALYATEPOCH > 0) OR ETA:APOAPSIS > OIBurnTime {
	PRINT "WAITING FOR APO.".
	WAIT UNTIL ETA:APOAPSIS < OIBurnTime/2.
} 

//ELSE {//we missed our window so burn baby burn

//burn to tartgetPeri
UNTIL currentShip:PERIAPSIS >= targetPeri {
	SET currentThrottle TO 1.
	WAIT 0.
}

SET currentThrottle TO 0.

WAIT 10.

//test

LOCK currentHeading TO currentShip:RETROGRADE.
SET currentThrottle TO 0.2.

run "atmospheric_entry.ks".
atmoReentry().

UNLOCK THROTTLE.
UNLOCK STEERING.

