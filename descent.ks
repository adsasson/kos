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

DECLARE FUNCTION descentOld {
	DECLARE PARAMETER transitionHeight IS 1000, deorbitBurn TO TRUE.
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


	LOCAL Kp TO 0.5.
	LOCAL Ki TO 0.
	LOCAL Kd TO 0.
	LOCAL descentRate TO (MIN(SHIP:GROUNDSPEED,ALT:RADAR/10)).
	LOCK descentRate TO (MIN(SHIP:GROUNDSPEED,ALT:RADAR/10)).
	LOCAL descentRatePID TO PIDLOOP(Kp,Ki,Kd).
	SET descentRatePID:SETPOINT TO descentRate.

	deployLandingGear().
	PRINT deorbitBurn.
	//landing loop
	IF deorbitBurn {
		SET cThrottle TO 0.5.
		//WAIT UNTIL SHIP:PERIAPSIS <= transitionHeight.
		WAIT UNTIL SHIP:GROUNDSPEED/v0 <= 0.5.
	}
	UNTIL cAlt <= transitionHeight {
		PRINT "GROUNDSPEED: " + SHIP:GROUNDSPEED AT (TERMINAL:WIDTH/2,0).
		PRINT "ALT/100: " + descentRate AT (TERMINAL:WIDTH/2,2).

		stageLogic().
		//debug
		//SET cThrottle TO MIN(1,MAX(0,(tempSetPoint/maxTWR - ((tempSetPoint/maxTWR)*SIN(beta))/2))).
		//SET cThrottle TO (MIN(1,MAX(0,2/maxTWR))).
	//	IF v0/SHIP:GROUNDSPEED > Ka {
			//SET cThrottle TO MIN(1,MAX(0,cThrottle + hrzPID:UPDATE(TIME:SECONDS, -SHIP:GROUNDSPEED))).
		//}
		SET descentRatePID:SETPOINT TO descentRate.

		SET cThrottle TO MIN(1,MAX(0,cThrottle + descentRatePID:UPDATE(TIME:SECONDS,descentRate/SHIP:GROUNDSPEED))).
		//SET cThrottle TO (1 - descentRate/SHIP:GROUNDSPEED).
		WAIT 0.
	}
}

DECLARE FUNCTION descent {
	DECLARE PARAMETER transitionHeight IS 750.
	//height at which transition from descent to hover/land

	//declarations
	LOCAL cShip TO SHIP.
	LOCAL cBody TO SHIP:BODY.

	LOCAL ecc TO SHIP:ORBIT:ECCENTRICITY.
	LOCK ecc TO SHIP:ORBIT:ECCENTRICITY.

	LOCAL trueAn TO SHIP:ORBIT:TRUEANOMALY.
	LOCK trueAn TO SHIP:ORBIT:TRUEANOMALY.

	LOCAL cosPhi TO (1 + ecc*COS(trueAn))/(SQRT(1 + ecc^2 + 2*ecc*COS(trueAn))).
	LOCK cosPhi TO (1 + ecc*COS(trueAn))/(SQRT(1 + ecc^2 + 2*ecc*COS(trueAn))).
	LOCAL sinPhi TO SQRT(1 - cosPhi^2).
	LOCK sinPhi TO SQRT(1 - cosPhi^2).

	LOCAL cThrottle TO 0.
	LOCAL cAlt TO ALT:RADAR.
	LOCK cAlt TO ALT:RADAR.

	LOCAL vHoriz TO (SHIP:VELOCITY:SURFACE:X).
	LOCAL vVert TO (SHIP:VELOCITY:SURFACE:Y).

	LOCAL velBurnTime TO burnTime(SHIP:VELOCITY:ORBIT:MAG).
	LOCK velBurnTime TO burnTime(SHIP:VELOCITY:ORBIT:MAG).

	LOCAL verticalImpactTime TO (cAlt - transitionHeight)/(SHIP:VELOCITY:ORBIT:MAG * sinPhi).
	LOCK verticalImpactTime TO (cAlt - transitionHeight)/(SHIP:VELOCITY:ORBIT:MAG * sinPhi) + velBurnTime/2.


	SAS OFF.
	SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
	stageLogic().
	deployLandingGear().

	LOCK cHeading TO SHIP:SRFRETROGRADE.
	//LOCK tempHeading TO V(cheading:X - tempSinThrust, cheading:Y + tempCosThrust, 0).


	LOCK STEERING TO cHeading.
	LOCK THROTTLE TO cThrottle.

	pointTo(cHeading).

	UNTIL FALSE {
		//PRINT "velBurnTime: " + round(velBurnTime,2) AT (TERMINAL:WIDTH/2,1).
		PRINT "verticalImpactTime: " + round(verticalImpactTime,2) AT (TERMINAL:WIDTH/2,1).
		IF velBurnTime*1.2 >= verticalImpactTime  {
			SET cThrottle TO 1.
			WAIT UNTIL SHIP:GROUNDSPEED <= 1.
			BREAK.
		}
	}

	SET cThrottle TO 0.
}


DECLARE FUNCTION poweredLanding {
	SAS OFF.
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

DECLARE FUNCTION hover {
	DECLARE PARAMETER hoverPoint.

	LOCAL Kp TO 0.1.
	LOCAL Ki TO 0.
	LOCAL Kd TO 0.

	LOCAL cThrottle TO SHIP:CONTROL:PILOTMAINTHROTTLE.
	LOCK THROTTLE TO cThrottle.
	LOCAL cHeading TO HEADING(90,90).
	LOCK cHeading TO HEADING(90,90).
	LOCK STEERING TO cHeading.

	//new PID for velocity guided descent. Target of vertical velocity = -altitude/10, not to go below 4 m/s.
	LOCAL hoverPID TO PIDLOOP(Kp,Ki,Kd).
	SET hoverPID:SETPOINT TO hoverPoint.

	LOCAL horizontalVelocity TO SHIP:VELOCITY:SURFACE.
	LOCK horizontalVelocity TO SHIP:VELOCITY:SURFACE.
	LOCAL starComponent TO (cHeading:STARVECTOR:NORMALIZED * horizontalVelocity).
	LOCAL topComponent TO (cHeading:TOPVECTOR:NORMALIZED * horizontalVelocity).

	LOCK starComponent TO (cHeading:STARVECTOR:NORMALIZED * horizontalVelocity).
	LOCK topComponent TO (cHeading:TOPVECTOR:NORMALIZED * horizontalVelocity).

	//LOCK STEERING TO SHIP:BODY:UP.
	RCS ON.
	LOCAL fuelRes TO 0.

	FOR res IN STAGE:RESOURCES {
		IF res:NAME = "LIQUIDFUEL".
		SET fuelRes TO res.
	}

	//LOCAL fuelLeft TO fuelRes:AMOUNT/fuelRes:CAPACITY.
	//LOCK fuelLeft TO fuelRes:AMOUNT/fuelRes:CAPACITY.

	clearscreen.
	UNTIL FALSE {
		PRINT "StarComp: " + ROUND(starComponent,2) AT (TERMINAL:WIDTH/2,0).
		PRINT "TopComp: " + ROUND(topComponent,2) AT (TERMINAL:WIDTH/2,1).
		PRINT "Star Control: " + ROUND(SHIP:CONTROL:STARBOARD,2) AT (TERMINAL:WIDTH/2,3).
		PRINT "Top Control: " + ROUND(SHIP:CONTROL:TOP,2) AT (TERMINAL:WIDTH/2,4).

		SET cThrottle TO MIN(1,MAX(0,cThrottle + hoverPID:UPDATE(TIME:SECONDS,
			 													ALT:RADAR))).

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

DECLARE FUNCTION doi {
	PARAMETER periBody IS (surfaceFeature[SHIP:BODY:NAME] + 100).
	LOCK STEERING TO SRFRETROGRADE.
	UNTIL SHIP:PERIAPSIS <= periBody {
		LOCK THROTTLE TO 1.
	}
	LOCK THROTTLE TO 0.
	UNLOCK STEERING.
	UNLOCK THROTTLE.
}

DECLARE FUNCTION pdi {
	//after afshari et al (2009) J Mech Sci Tech 23:3239-3244,
	LOCK beta TO VANG(SHIP:FACING:VECTOR,SHIP:VELOCITY:SURFACE).
	LOCK phi TO flightPathAngle().
	LOCAL uStar TO SHIP:VELOCITY:ORBIT * SIN(phi).
	LOCAL vStar TO SHIP:VELOCITY:ORBIT * COS(phi).
	LOCAL tStar TO TIME:SECONDS/uStar.
	LOCAL yStar TO ALT:RADAR.

	LOCAL uBar TO (SHIP:VELOCITY:ORBIT * SIN(phi))/uStar.
	LOCK uBar TO (SHIP:VELOCITY:ORBIT * SIN(phi))/uStar.
	LOCAL vBar TO (SHIP:VELOCITY:ORBIT * COS(phi))/vStar.
	LOCK vBar TO (SHIP:VELOCITY:ORBIT * COS(phi))/vStar.
	LOCAL tau TO TIME:SECONDS/tStar.
	LOCK tau TO TIME:SECONDS/tStar.
	LOCAL yBar TO SHIP:POSITION/yStar.
	LOCK yBar TO SHIP:POSITION/yStar.

	LOCAL maxThrust TO SHIP:AVAILABLETHRUST.
	LOCK maxThrust TO SHIP:AVAILABLETHRUST.

	LOCAL bodyG TO SHIP:BODY:MU/(SHIP:BODY:RADIUS)^2. //using gravity at datum

	LOCAL omega1 TO maxThrust*tStar/uStar.
	LOCAL omega2 TO bodyG * tStar/uStar.
	LOCAL omega3 TO uStar * tStar/yStar.

	LOCK omega1 TO maxThrust*tStar/uStar.
	LOCK omega2 TO bodyG * tStar/uStar.
	LOCK omega3 TO uStar * tStar/yStar.

	LOCAL sumBetaR TO 0.

	FROM {LOCAL n IS 1.} UNTIL n = 6 STEP {SET n TO n+1.} DO {
	  SET sumBetaR TO sumBetaR + (COS((2 * n + 1)*beta))/(2*n+1)^3.
	}

	LOCAL kappa1 TO 1.
	LOCAL kappa2 TO 1.
	LOCAL kappa3 TO 1.
	LOCAL gammaU TO kappa1.
	LOCAL gammaV TO -kappa3 * omega3 * tau + kappa2.
	LOCAL gammaY TO kappa3.

	LOCAL dUdBeta TO (8 * omega1 * COS(beta) * SIN(beta))/CONSTANT:PI * gammaY.
}
