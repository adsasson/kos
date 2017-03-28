//LANDING SCRIPT AIRLESS
// from a given orbital radar altitude to transition altitude, burn to landing
//pitch as a function of altitude
//heading as a function of target
//Target TWR of 0.5

runoncepath("orbitLib.ks").
runoncepath("orbMechLib.ks").
runoncepath("shipLib.ks").
//dependsOn("orbitLib.ks").
//dependsOn("shipLib.ks").
SET TERMINAL:WIDTH TO 75.

DECLARE FUNCTION descent {
	DECLARE PARAMETER transitionHeight IS 1000.
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

	LOCAL cTWR TO maxTWR * cThrottle.
	LOCK cTWR TO maxTWR * cThrottle.

	LOCAL alt0 TO ALT:RADAR + transitionHeight.
	LOCAL Ka TO ALT:RADAR/alt0.
	LOCK Ka TO ALT:RADAR/alt0.
	LOCAL v0 TO SHIP:GROUNDSPEED.


	LOCAL Kp TO 2.
	LOCAL Ki TO 0.
	LOCAL Kd TO 1.
	LOCAL descentRate TO ALT:RADAR/10.
	LOCK descentRate TO MIN(-4,(-ALT:RADAR/10)).
	LOCAL descentRatePID TO PIDLOOP(Kp,Ki,Kd).
	SET descentRatePID:SETPOINT TO descentRate.

	LOCAL hrzPID TO PIDLOOP(Kp,Ki,Kd).
	SET hrzPID:SETPOINT TO v0*Ka.

	deployLandingGear().

	//landing loop
	SET cThrottle TO 0.5.
	//WAIT UNTIL SHIP:PERIAPSIS <= transitionHeight.
	WAIT UNTIL SHIP:GROUNDSPEED/v0 <= 0.5.

	UNTIL cAlt <= transitionHeight {
		SET hrzPID:SETPOINT TO v0*Ka.

		stageLogic().
		//debug
		//SET cThrottle TO MIN(1,MAX(0,(tempSetPoint/maxTWR - ((tempSetPoint/maxTWR)*SIN(beta))/2))).
		//SET cThrottle TO (MIN(1,MAX(0,2/maxTWR))).
	//	IF v0/SHIP:GROUNDSPEED > Ka {
			//SET cThrottle TO MIN(1,MAX(0,cThrottle + hrzPID:UPDATE(TIME:SECONDS, -SHIP:GROUNDSPEED))).
		//}
		SET descentRatePID:SETPOINT TO descentRate.

		SET cThrottle TO MIN(1,MAX(0,cThrottle + descentRatePID:UPDATE(TIME:SECONDS,
			 													SHIP:VERTICALSPEED))).
		WAIT 0.
	}
}

DECLARE FUNCTION testDescent {
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

	LOCAL vHoriz TO (SHIP:VELOCITY:SURFACE:X).
	LOCAL vVert TO (SHIP:VELOCITY:SURFACE:Y).

	LOCAL tempTime TO SQRT(2*ALT:RADAR/(cGrav*0.9)).
	LOCAL tempSinThrust TO vHoriz/tempTime.
	LOCAL tempCosThrust TO (0.9*cGrav).

	LOCAL tanThrust TO tempSinThrust/tempCosThrust.

	LOCAL goalThrust TO tanThrust*SHIP:AVAILABLETHRUST.
	LOCAL goalPhi TO ARCTAN(tanThrust).


	SAS OFF.
	SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.

	LOCK cHeading TO SHIP:VELOCITY:ORBIT:NORMALIZED.
	//LOCK tempHeading TO V(cheading:X - tempSinThrust, cheading:Y + tempCosThrust, 0).
	LOCK tempHeading TO SHIP:SRFRETROGRADE.

	LOCK STEERING TO tempHeading.
	LOCK THROTTLE TO cThrottle.

	//WAIT UNTIL 	ABS(cHeading:PITCH - SHIP:FACING:PITCH) < 0.15 AND
	// 						ABS(cHeading:YAW - SHIP:FACING:YAW) < 0.15.

	LOCK testPhi TO flightPathAngle().
	LOCK tempSetPoint TO 0.5/(MAX(0.0001,SIN(testPhi))).

	WAIT UNTIL pointTo(tempHeading).


	LOCAL cTWR TO maxTWR * cThrottle.
	LOCK cTWR TO maxTWR * cThrottle.

	//TWR PID LOOP SETTINGS
	LOCAL Kp TO 0.5.
	LOCAL Ki TO 0.
	LOCAL Kd TO 0.
	LOCAL twrPID TO PIDLOOP(Kp,Ki,Kd).
	SET twrPID:SETPOINT TO 0.9.

	deployLandingGear().


	//landing loop
	IF cAlt <= transitionHeight {
		RETURN TRUE.
	}
	SET vHoriz TO (SHIP:VELOCITY:SURFACE:X).
	LOCK cHoriz TO SHIP:VELOCITY:SURFACE:X.

	SET cThrottle TO 1.
	WAIT UNTIL cHoriz/vHoriz <= 0.3.

	UNTIL cAlt <= transitionHeight {
		PRINT "sin phi: " + ROUND(SIN(testPhi),2) AT (TERMINAL:WIDTH/2,0).
		PRINT "SETPOINT: " + ROUND(tempSetPoint,2) AT (TERMINAL:WIDTH/2,1).
		//PRINT "arccosbeta: " + ROUND(ARCCOS(beta),2) AT (TERMINAL:WIDTH/2,2).

		stageLogic().
		//debug
		SET cThrottle TO MIN(1,MAX(0,(tempSetPoint/(MAX(0.00001,maxTWR))))).
		//SET cThrottle TO (MIN(1,MAX(0,2/maxTWR))).
		//SET cThrottle TO MIN(1,MAX(0,cThrottle + twrPID:UPDATE(TIME:SECONDS, cTWR))).

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

	//LOCK STEERING TO SHIP:BODY:UP.
	RCS ON.
	clearscreen.
	UNTIL SHIP:STATUS = "LANDED" {
		PRINT "Vx: " + ROUND(SHIP:VELOCITY:SURFACE:X,2) AT (TERMINAL:WIDTH/2,0).
		PRINT "Vy: " + ROUND(SHIP:VELOCITY:SURFACE:Y,2) AT (TERMINAL:WIDTH/2,1).
		PRINT "Vz: " + ROUND(SHIP:VELOCITY:SURFACE:Z,2) AT (TERMINAL:WIDTH/2,2).
		PRINT "StarComp: " + ROUND(starComponent,2) AT (TERMINAL:WIDTH/2,3).
		PRINT "topComp: " + ROUND(topComponent,2) AT (TERMINAL:WIDTH/2,4).

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
