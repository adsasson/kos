//LAUNCH script
//Takes Target Apo, Target Heading, and targetPeri. 
//Initiates GT to target Apo, PID to TWR (though may change to target air resistance or max q). 
//Calls onOrbitBurn at target apo

run orbitLib.ks.
run shipLib.ks.

DECLARE PARAMETER targetHeading IS 90, targetApo IS 100000, targetPeri IS 0.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.


LOCAL OKtoLAUNCH TO FALSE.
SAS OFF.
RCS OFF.

IF targetHeading > 360 {
	SET thModulus TO MOD(targetHeading,360).
	SET targetHeading TO targetHeading - (360*thModulus).
}

SET currentShip TO SHIP.
SET currentBody TO currentShip:BODY.
LOCAL atmoHeight TO 0.
//LOCAL targetPeri TO 0. 							//until you can figure out minimum altitude for atmosphere vs terrain features on airless worlds.
LOCAL currentPitch TO 90.
LOCK currentThrottle TO SHIP:CONTROL:PILOTMAINTHROTTLE.
SET atmoFlag TO currentBody:ATM:EXISTS.

LOCK currentMass TO currentShip:MASS.
LOCK currentG to currentBody:MU/(currentShip:ALTITUDE + currentBody:RADIUS)^2.
LOCK maxTWR TO (currentShip:AVAILABLETHRUST/(currentMass * currentG)).

//LOCK maxTWR to maxTWR().
LOCK currentTWR TO maxTWR * currentThrottle.

IF atmoFlag { 				//check for atmo, if present, set peri to atmo + 1000
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
} ELSE {
	set targetPeri TO minAirlessPeri(currentBody).
	SET OKtoLaunch TO TRUE.
}

//TWR PID LOOP SETTINGS for atmospheric ascent
SET Kp TO 0.1.
SET Ki TO 0.006.
SET Kd TO 0.001.
SET twrPID TO PIDLOOP(Kp,Ki,Kd).
SET twrPID:SETPOINT TO 2.

//HEADING
SET currentHeading TO HEADING(targetHeading,currentPitch).
//SET Ka TO 1.

//LAUNCH ROUTINE
//?countdown?

FROM {local countdown is 3.} UNTIL countdown = 0 STEP {SET countdown to countdown - 1.} DO {
    PRINT "..." + countdown.
    WAIT 1. // pauses the script here for 1 second.
}

//----------------------------------
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
IF atmoFlag {
	LOCK Ka TO ROUND((currentShip:ALTITUDE/atmoHeight),2). //fraction of atmosphere height
} ELSE {
	LOCK Ka TO ROUND((currentShip:ALTITUDE/targetApo),2).
}

LOCK deltaPitch TO 90 * (1.5 * Ka).
//LOCK deltaPitch TO 90 * -CONSTANT:E^(-Ka). //diffferent ascent curves
//LOCK deltaPitch TO 90 * LN(MAX(Ka,0.01)).

UNTIL currentShip:APOAPSIS >= targetApo {
	IF atmoFlag {
		SET currentThrottle TO MIN(1, MAX(0,currentThrottle + twrPID:UPDATE(TIME:SECONDS, currentTWR))).
	} ELSE {
		SET currentThrottle TO 1.
	}
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

//LOCK currentHeading TO currentShip:PROGRADE.

LOCK currentHeading TO HEADING(targetHeading,0).
SET horizon TO HEADING(targetHeading,0).
//test correct for angle off of prograde
SET horizonVector TO horizon:FOREVECTOR.
LOCK progradeAngle TO VECTORANGLE(currentShip:PROGRADE:FOREVECTOR,horizonVector).

SET currentEcc TO currentShip:ORBIT:ECCENTRICITY.
LOCK eCosV TO currentEcc * COS(currentShip:ORBIT:TRUEANOMALY).
LOCK currentPhi TO ARCCOS((1 + eCosV)/(SQRT(1 + currentEcc^2 + 2 * eCosV))).

ON (currentShip:ALTITUDE > atmoHeight) {
	engageDeployables().
}

//CORRECT APO FOR DRAG

UNTIL currentShip:APOAPSIS >= targetApo {
	SET currentHeading TO HEADING(targetHeading,0).
	SET currentThrottle TO 1.
	
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

SET currentThrottle TO 0.
//ORBITAL INSERTION
//placeholder for now. Need to generalize to function that can take a vector and start altitude or node.
//will need:
//delta V calculation
//burn time calculation
//burn control method.



SET alpha TO currentShip:ORBIT:SEMIMAJORAXIS.
PRINT "current Phi: " + currentPhi.
SET OIdeltaV TO deltaV(currentShip:ORBIT:PERIAPSIS, targetPeri).
PRINT "OI DELTA: " + ROUND(OIdeltaV,2).

SET OIBurnTime TO burn_Time(OIDeltaV,currentShip).

PRINT "OI BURN TIME: " + ROUND(OIBurnTime,2).

IF (currentShip:ORBIT:MEANANOMALYATEPOCH > 0) OR ETA:APOAPSIS > OIBurnTime {
	PRINT "WAITING FOR APO.".
	WAIT UNTIL ETA:APOAPSIS < OIBurnTime/2.
	PRINT "TEST ANGLE: " + round(progradeAngle,2).
	//LOCK currentHeading TO HEADING(targetHeading,ROUND((0-progradeAngle),0)). //should be positive if before apo

} 

//ELSE {//we missed our window so burn baby burn

//burn to tartgetPeri
UNTIL currentShip:PERIAPSIS >= targetPeri {
	SET currentThrottle TO 1.
	//LOCK currentHeading TO HEADING(targetHeading,ROUND((0-progradeAngle),0)). //should be positive if before apo
	WAIT 0.
}

SET currentThrottle TO 0.

UNLOCK THROTTLE.
UNLOCK STEERING.

