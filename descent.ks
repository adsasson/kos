//LANDING SCRIPT AIRLESS

//runoncepath("orbitLib.ks").
//runoncepath("orbMechLib.ks").
//runoncepath("shipLib.ks").
dependsOn("orbitLib.ks").
dependsOn("orbMechLib.ks").
dependsOn("shipLib.ks").

SET TERMINAL:WIDTH TO 75.

DECLARE FUNCTION descent {
	DECLARE PARAMETER transitionHeight IS 1000, flag IS "analytic".

	IF flag = "analytic" {
		descentAnalytic(transitionHeight).
	} ELSE {
		descentNumeric(transitionHeight).
	}
}

//analytic descent
DECLARE FUNCTION descentAnalytic {
	DECLARE PARAMETER transitionHeight IS 1000.
	//height at which transition from descent to hover/land
	SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
	//orient first
	SAS OFF.
	LOCAL LOCK cHeading TO SHIP:SRFRETROGRADE.

	LOCAL cThrottle TO 0.
	LOCK STEERING TO cHeading.
	LOCK THROTTLE TO cThrottle.

	WAIT UNTIL pointTo(cHeading,FALSE,30,1).

	//declarations
	LOCAL LOCK cBody TO SHIP:BODY.
	LOCAL cGrav TO -cBody:MU/(cBody:RADIUS)^2. //grav at datum, down is negative

	LOCAL r0 TO ALT:RADAR. //initial
	LOCAL rF TO r0 - transitionHeight. //final altitude

	LOCAL vX0 TO SHIP:GROUNDSPEED.
	LOCAL vY0 TO SHIP:VERTICALSPEED.

	LOCAL TTI TO timeToImpact(vY0, rf, cGrav).
	LOCAL vF TO VisViva(rF + cBody:RADIUS). //velocity at transition height
	LOCAL tB TO burnTime(vF).

	LOCAL tManeuver TO TTI - tB/2. //time to manuever is TTI minus burn time/2

	deployLandingGear().

	//landing loop
	stageLogic().

	LOCAL startTime TO TIME:SECONDS.
	UNTIL TIME:SECONDS >= (startTime + tManeuver) {
		PRINT "Time To Burn: " + ROUND((startTime + tManeuver - TIME:SECONDS),2) AT (TERMINAL:WIDTH/2, 1).
		PRINT "Time To Impact: " + ROUND((startTime + TTI - TIME:SECONDS),2) AT (TERMINAL:WIDTH/2, 2).
		WAIT 0.
	}

	SET cThrottle TO 1.
	WAIT tB.
	SET cThrottle TO 0.

}

//descent numeric
DECLARE FUNCTION descentNumeric {
	DECLARE PARAMETER transitionHeight IS 750.
	//height at which transition from descent to hover/land

	//check to see if below transition height and exit if so
	IF ALT:RADAR <= transitionHeight {
		RETURN.
	}
	//declarations
	LOCAL cThrottle TO 0.
	LOCAL LOCK cAlt TO ALT:RADAR.

	LOCAL LOCK velBurnTime TO burnTime(SHIP:VELOCITY:ORBIT:MAG).
	LOCAL LOCK verticalImpactTime TO 	(cAlt - transitionHeight)/
																		-SHIP:VERTICALSPEED.

	SAS OFF.
	stageLogic().
	deployLandingGear().

	LOCK cHeading TO SHIP:SRFRETROGRADE.

	LOCK STEERING TO cHeading.
	LOCK THROTTLE TO cThrottle.

	pointTo(cHeading).

	UNTIL FALSE {
		PRINT "verticalImpactTime: " + round(verticalImpactTime,2)
																	AT (TERMINAL:WIDTH/2,1).
		IF velBurnTime >= verticalImpactTime  {
			SET cThrottle TO 1.
			WAIT UNTIL SHIP:GROUNDSPEED <= 1.
			BREAK.
		}
	}

	SET cThrottle TO 0.
}


FUNCTION poweredLanding {
	PARAMETER maximumImpactTolerance TO 8.
	SAS OFF.
	LOCAL Kp TO 0.1.
	LOCAL Ki TO 0.005.
	LOCAL Kd TO 0.01.

	LOCAL cThrottle TO SHIP:CONTROL:PILOTMAINTHROTTLE.
	LOCK THROTTLE TO cThrottle.
	LOCAL LOCK cHeading TO SHIP:SRFRETROGRADE.
	LOCK STEERING TO cHeading.

	//new PID for velocity guided descent.
	//Target of vertical velocity = -altitude/10,
	//not to go below max impact tolerance/2 m/s.
	LOCAL LOCK descentRate TO MIN(-maximumImpactTolerance/2,(-ALT:RADAR/10)).
	LOCAL descentRatePID TO PIDLOOP(Kp,Ki,Kd,0,1).
	SET descentRatePID:SETPOINT TO descentRate.

	LOCAL LOCK horizontalVelocity TO SHIP:VELOCITY:SURFACE.
	LOCAL LOCK starComponent 			TO SHIP:SRFRETROGRADE:STARVECTOR.
	LOCAL LOCK topComponent 			TO SHIP:SRFRETROGRADE:TOPVECTOR.

	//LOCK STEERING TO SHIP:BODY:UP.
	RCS ON.
	clearscreen.
	UNTIL SHIP:STATUS = "LANDED" {
		PRINT "StarComp: " + ROUND(starComponent,2) AT (TERMINAL:WIDTH/2,1).
		PRINT "topComp: " + ROUND(topComponent,2) AT (TERMINAL:WIDTH/2,2).

		SET descentRatePID:SETPOINT TO descentRate.

		SET cThrottle TO cThrottle + descentRatePID:UPDATE(TIME:SECONDS,
																 SHIP:VERTICALSPEED).

		//try to zero out horizontal velocity
		IF starComponent:MAG > 1 SET starComponent TO starComponent:NORMALIZED.
		IF topComponent:MAG > 1 SET topComponent TO topComponent:NORMALIZED.

	  SET SHIP:CONTROL:STARBOARD  TO starComponent 	* SHIP:FACING:STARVECTOR.
	  SET SHIP:CONTROL:TOP        TO topComponent 	* SHIP:FACING:TOPVECTOR.

	}
	SAS ON.
	SET cThrottle TO 0.

	UNLOCK THROTTLE.
	UNLOCK STEERING.
}

DECLARE FUNCTION hover {
	DECLARE PARAMETER hoverPoint, bingoFuel IS 0.1.

	LOCAL Kp TO 0.1.
	LOCAL Ki TO 0.005.
	LOCAL Kd TO 0.01.

	LOCAL cThrottle TO SHIP:CONTROL:PILOTMAINTHROTTLE.
	LOCK THROTTLE TO cThrottle.
	LOCAL cHeading TO HEADING(90,90).
	LOCK STEERING TO cHeading.

	//new PID for velocity guided descent. Target of vertical velocity = -altitude/10, not to go below 4 m/s.
	LOCAL hoverPID TO PIDLOOP(Kp,Ki,Kd,0,1).
	SET hoverPID:SETPOINT TO hoverPoint.

	LOCAL LOCK horizontalVelocity TO SHIP:VELOCITY:SURFACE.
	LOCAL LOCK starComponent 			TO SHIP:SRFRETROGRADE:STARVECTOR.
	LOCAL LOCK topComponent 			TO SHIP:SRFRETROGRADE:TOPVECTOR.

	//LOCK STEERING TO SHIP:BODY:UP.
	RCS ON.

	LOCAL LOCK fuelRes TO fuelReserve(kLiquidFuel).
	clearscreen.
	UNTIL fuelRes <= bingoFuel {
		PRINT "StarComp: " + ROUND(starComponent,2) AT (TERMINAL:WIDTH/2,0).
		PRINT "TopComp: " + ROUND(topComponent,2) AT (TERMINAL:WIDTH/2,1).
		PRINT "Star Control: " + ROUND(SHIP:CONTROL:STARBOARD,2) AT (TERMINAL:WIDTH/2,3).
		PRINT "Top Control: " + ROUND(SHIP:CONTROL:TOP,2) AT (TERMINAL:WIDTH/2,4).

		SET cThrottle TO MIN(1,MAX(0,cThrottle + hoverPID:UPDATE(TIME:SECONDS,
			 													ALT:RADAR))).

		//try to zero out horizontal velocity
		//try to zero out horizontal velocity
		IF starComponent:MAG 	> 1 SET starComponent TO starComponent:NORMALIZED.
		IF topComponent:MAG 	> 1 SET topComponent 	TO topComponent:NORMALIZED.

	  SET SHIP:CONTROL:STARBOARD  TO starComponent 	* SHIP:FACING:STARVECTOR.
	  SET SHIP:CONTROL:TOP        TO topComponent 	* SHIP:FACING:TOPVECTOR.
	}
	SAS ON.
	SET cThrottle TO 0.

	UNLOCK THROTTLE.
	UNLOCK STEERING.
}

DECLARE FUNCTION doi {
	//PARAMETER periBody IS (surfaceFeature[SHIP:BODY:NAME] + 100).
	PARAMETER periBody IS 0.
	LOCK STEERING TO RETROGRADE.
	UNTIL SHIP:PERIAPSIS <= periBody {
		LOCK THROTTLE TO 1.
	}
	LOCK THROTTLE TO 0.
	UNLOCK STEERING.
	UNLOCK THROTTLE.
}
