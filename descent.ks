//LANDING SCRIPT AIRLESS
// from a given orbital radar altitude to transition altitude, burn to landing
//pitch as a function of altitude
//heading as a function of target
//Target TWR of 0.5

runoncepath("orbitLib.ks").
runoncepath("shipLib.ks").
//dependsOn("orbitLib.ks").
//dependsOn("shipLib.ks").
SET TERMINAL:WIDTH TO 75.

DECLARE FUNCTION descent {
	DECLARE PARAMETER transitionHeight IS 750.
	//height at which transition from descent to hover/land

	//declarations
	LOCAL cShip TO SHIP.
	LOCAL cBody TO SHIP:BODY.

	LOCAL cMass TO cShip:MASS.
	LOCK cMass TO cShip:MASS.

	LOCAL cGrav TO cBody:MU/(cShip:ALTITUDE + cBody:RADIUS)^2.
	SET cGrav TO cBody:MU/(cShip:ALTITUDE + cBody:RADIUS)^2.

	LOCAL maxTWR TO (cShip:AVAILABLETHRUST/(cMass * cGrav)).
	LOCK cGrav TO cBody:MU/(cShip:ALTITUDE + cBody:RADIUS)^2.
	LOCK maxTWR TO (cShip:AVAILABLETHRUST/(cMass * cGrav)).


	LOCAL cThrottle TO 0.
	LOCAL orbitAltitude TO ALT:RADAR.
	LOCAL cAlt TO ALT:RADAR.
	LOCK cAlt TO ALT:RADAR.

	SAS OFF.
	SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.

	LOCAL cHeading TO SHIP:SRFRETROGRADE.

	LOCK cHeading TO SHIP:SRFRETROGRADE.

	LOCK STEERING TO cHeading.
	LOCK THROTTLE TO cThrottle.

	//WAIT UNTIL 	ABS(cHeading:PITCH - SHIP:FACING:PITCH) < 0.15 AND
	// 						ABS(cHeading:YAW - SHIP:FACING:YAW) < 0.15.

	WAIT UNTIL pointTo(cHeading).

	LOCAL Ka TO 1.
	LOCK Ka TO ROUND((cAlt/orbitAltitude),2). //normalize distance to ground
	LOCAL tempFacing TO SHIP:FACING.

	LOCAL cTWR TO maxTWR * cThrottle.
	LOCK cTWR TO maxTWR * cThrottle * SIN(VANG(SHIP:SRFRETROGRADE:VECTOR,tempFacing:VECTOR)).

	//TWR PID LOOP SETTINGS
	LOCAL Kp TO 0.5.
	LOCAL Ki TO 0.
	LOCAL Kd TO 0.
	LOCAL twrPID TO PIDLOOP(Kp,Ki,Kd).
	SET twrPID:SETPOINT TO 0.9.

	deployLandingGear().


	//landing loop

	UNTIL cAlt <= transitionHeight {
		PRINT "?down component of thrust: " + ROUND(cTWR,2) AT (TERMINAL:WIDTH/2,0).
		PRINT "facingPhi: " + ROUND(VANG(SHIP:SRFRETROGRADE:VECTOR,tempFacing:VECTOR),2) AT (TERMINAL:WIDTH/2,1).

		stageLogic().
		//debug
		//SET cThrottle TO 0.15.
		SET cThrottle TO MIN(1,MAX(0,cThrottle + twrPID:UPDATE(TIME:SECONDS, cTWR))).

		WAIT 0.
	}
}

DECLARE FUNCTION poweredLanding {

	LOCAL Kp TO 2.
	LOCAL Ki TO 0.
	LOCAL Kd TO 1.

	LOCAL cThrottle TO SHIP:CONTROL:PILOTMAINTHROTTLE.
	LOCK THROTTLE TO cThrottle.
	LOCAL cHeading TO SHIP:SRFRETROGRADE.
	LOCK cHeading TO SHIP:SRFRETROGRADE.
	LOCK STEERING TO cHeading.

	//new PID for velocity guided descent. Target of vertical velocity = -altitude/10, not to go below 4 m/s.
	LOCAL descentRate TO ALT:RADAR/10.
	LOCK descentRate TO MIN(-4,(-ALT:RADAR/10)).
	LOCAL descentRatePID TO PIDLOOP(Kp,Ki,Kd).
	SET descentRatePID:SETPOINT TO descentRate.

	LOCAL horizontalVelocity TO SHIP:VELOCITY:SURFACE.
	LOCK horizontalVelocity TO SHIP:VELOCITY:SURFACE.
	LOCAL starComponent TO (SHIP:SRFRETROGRADE:STARVECTOR:NORMALIZED * horizontalVelocity).
	LOCAL topComponent TO (SHIP:SRFRETROGRADE:TOPVECTOR:NORMALIZED * horizontalVelocity).

	LOCK starComponent TO (SHIP:SRFRETROGRADE:STARVECTOR:NORMALIZED * horizontalVelocity).
	LOCK topComponent TO (SHIP:SRFRETROGRADE:TOPVECTOR:NORMALIZED * horizontalVelocity).

	LOCK STEERING TO UP.
	RCS ON.
	UNTIL SHIP:STATUS = "LANDED" {
		PRINT "Vx: " + ROUND(SHIP:VELOCITY:SURFACE:X,2) AT (TERMINAL:WIDTH/2,0).
		PRINT "Vy: " + ROUND(SHIP:VELOCITY:SURFACE:Y,2) AT (TERMINAL:WIDTH/2,1).
		PRINT "Vz: " + ROUND(SHIP:VELOCITY:SURFACE:Z,2) AT (TERMINAL:WIDTH/2,2).
		PRINT "StarComp: " + ROUND(starComponent:MAG,2) AT (TERMINAL:WIDTH/2,3).
		PRINT "topComp: " + ROUND(topComponent:MAG,2) AT (TERMINAL:WIDTH/2,4).

		SET descentRatePID:SETPOINT TO descentRate.

		SET cThrottle TO MIN(1,MAX(0,cThrottle + descentRatePID:UPDATE(TIME:SECONDS,
			 													SHIP:VERTICALSPEED))).

		//try to zero out horizontal velocity
		IF (horizontalVelocity:MAG >= 0.1) {
			SET SHIP:CONTROL:STARBOARD TO -(MIN(MAX(starComponent,-1),1)).
			SET SHIP:CONTROL:TOP TO -(MIN(MAX(topComponent,-1),1)).
		}

	}
	SAS ON.
	SET cThrottle TO 0.

	UNLOCK THROTTLE.
	UNLOCK STEERING.
}
