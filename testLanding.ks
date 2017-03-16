//LANDING SCRIPT AIRLESS
// from a given orbital radar altitude (Horbit) to landing altituge (H0) , burn to landing
//pitch as a function of altitude
//heading as a function of target
//Target TWR of 0.5

run orbitLib.ks.
run shipLib.ks.

DECLARE PARAMETER landingHeight IS 500. //height at which to switch to slower controlled descent


SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.

SAS OFF.
//declarations

SET currentShip TO SHIP.
SET currentBody TO currentShip:BODY.

LOCK currentThrottle TO SHIP:CONTROL:PILOTMAINTHROTTLE.

//SET orbitAltitude to currentShip:ALTITUDE.
SET orbitAltitude to ALT:RADAR.

//LOCK currentAltitude to currentShip:ALTITUDE.
LOCK currentAltitude to ALT:RADAR.


//SET currentYaw TO 270.
//SET currentYaw TO SHIP:RETROGRADE:YAW.
LOCK currentPitch TO SHIP:SRFRETROGRADE.

//SET currentHeading TO HEADING(currentYaw,currentPitch).
LOCK currentHeading TO SHIP:SRFRETROGRADE.


LOCK STEERING TO currentHeading.
//WAIT UNTIL ABS(currentPitch - SHIP:FACING:PITCH) < 0.15 AND ABS(currentYaw - SHIP:FACING:YAW) < 0.15.
WAIT 3.

SET currentThrottle TO 0.

LOCK THROTTLE TO currentThrottle.

SET Ka TO 1.
LOCK Ka TO ROUND((currentAltitude/orbitAltitude),2). //normalize distance to ground
//LOCK deltaPitch TO 90 * (1 - MIN(1,(1.5 * Ka))). //basis of descent curve (reverse gravity turn).
LOCK deltaPitch TO 90 * (1 - MIN(1,(1.5 * Ka))). //basis of descent curve (reverse gravity turn).
//LOCK deltaPitch TO 90 * (1.5 * Ka).

LOCK currentMass TO currentShip:MASS.
LOCK currentG to currentBody:MU/(currentShip:ALTITUDE + currentBody:RADIUS)^2.
LOCK maxTWR TO (currentShip:AVAILABLETHRUST/(currentMass * currentG)).

LOCK currentTWR TO maxTWR * currentThrottle.

//TWR PID LOOP SETTINGS
SET Kp TO 5.
SET Ki TO 0.
SET Kd TO 00.
SET twrPID TO PIDLOOP(Kp,Ki,Kd).
SET twrPID:SETPOINT TO 1.4.

deployLandingGear().

//landing loop
UNTIL currentAltitude <= landingHeight {

	stageLogic().
	
	SET currentThrottle TO 0.15.
	//SET currentThrottle TO MIN(1, MAX(0,currentThrottle + twrPID:UPDATE(TIME:SECONDS, currentTWR))).
	//SET currentPitch TO 360 - deltaPitch. //should vary from 180 to 90 with height
	
	//SET currentHeading TO currentHeading + R(0,deltaPitch,0).
	
	//DEBUG
	PRINT "Current PITCH: "+ ROUND(SHIP:FACING:PITCH,2) + " delta Pitch: " + ROUND(deltaPitch,2).
	clearscreen.


	WAIT 0.
}

SET Kp TO 2.
SET Ki TO 0.
SET Kd TO 1.

//new PID for velocity guided descent. Target of horizontal velocity = -altitude/10, not to go below 4 m/s.
LOCK currentDescentRate TO MIN(-4,(-currentAltitude/10)).
SET descentRatePID TO PIDLOOP(Kp,Ki,Kd).
SET descentRatePID:SETPOINT TO currentDescentRate.

//SET currentHeading TO UP.
RCS ON.
UNTIL currentShip:STATUS = "LANDED" {
	
	SET descentRatePID:SETPOINT TO currentDescentRate.

	SET currentThrottle TO MIN(1, MAX(0,currentThrottle + descentRatePID:UPDATE(TIME:SECONDS, SHIP:VERTICALSPEED))).

}
SAS ON.
SET currentThrottle TO 0.

UNLOCK THROTTLE.
UNLOCK STEERING.