@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).
//LANDING SCRIPT AIRLESS
dependsOn("navigationLib.ks").
dependsOn("hohmann.ks").
dependsOn("orbitalMechanicsLib.ks").

FUNCTION descent {
	PARAMETER transitionHeight IS 1000, flag IS "analytic".

	IF flag = "analytic" {
		descentAnalytic(transitionHeight).
	} ELSE {
		descentNumeric(transitionHeight).
	}
}

//analytic descent
FUNCTION descentAnalytic {
	PARAMETER transitionHeight IS 1000.
	//height at which transition from descent to hover/land

	SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
	//orient first

	initializeControls().

	LOCK STEERING TO SHIP:SRFRETROGRADE.

	SET lockedThrottle TO 0.

	waitForAlignmentTo(SHIP:SRFRETROGRADE,FALSE,30,1).

	//declarations

	LOCAL currentBody TO SHIP:BODY.
	LOCAL grav TO -currentBody:MU/(currentBody:RADIUS)^2. //grav at datum, down is negative

	LOCAL initialAltitude TO ALT:RADAR.
	LOCAL finalAltitude TO initialAltitude - transitionHeight.

	LOCAL velocityX0 TO SHIP:GROUNDSPEED.
	LOCAL velocityY0 TO SHIP:VERTICALSPEED.

	LOCAL TTI TO timeToImpact(velocityY0, finalAltitude, grav).
	LOCAL finalVelocity TO VisViva(finalAltitude + currentBody:RADIUS). //velocity at transition height
	LOCAL descentBurnTime TO burnTime(finalVelocity).

	LOCAL timeToManeuver TO TTI - descentBurnTime/2. //time to manuever is TTI minus burn time/2

	deployLandingGear().

	//landing loop
	stageLogic().

	LOCAL startTime TO TIME:SECONDS.
	UNTIL TIME:SECONDS >= (startTime + timeToManeuver) {
		PRINT "Time To Burn: " + ROUND((startTime + timeToManeuver - TIME:SECONDS),2) AT (TERMINAL:WIDTH/2, 1).
		PRINT "Time To Impact: " + ROUND((startTime + TTI - TIME:SECONDS),2) AT (TERMINAL:WIDTH/2, 2).
		WAIT 0.
	}

	SET lockedThrottle TO 1.
	WAIT descentBurnTime.
	SET lockedThrottle TO 0.

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
	LOCAL LOCK shipAltitude TO ALT:RADAR.

	LOCAL LOCK velocityMagnitude TO burnTime(SHIP:VELOCITY:ORBIT:MAG).
	LOCAL LOCK verticalImpactTime TO 	(shipAltitude - transitionHeight)/
																		-SHIP:VERTICALSPEED.

	SAS OFF.
	stageLogic().
	deployLandingGear().

	LOCK STEERING TO SHIP:SRFRETROGRADE.

	waitForAlignmentTo(SHIP:SRFRETROGRADE).

	UNTIL FALSE {
		PRINT "verticalImpactTime: " + round(verticalImpactTime,2)
																	AT (TERMINAL:WIDTH/2,1).
		IF velocityMagnitude >= verticalImpactTime  {
			SET lockedThrottle TO 1.
			WAIT UNTIL SHIP:GROUNDSPEED <= 1.
			BREAK.
		}
	}

	SET lockedThrottle TO 0.
}


FUNCTION poweredLanding {
	PARAMETER maximumImpactTolerance TO 8.
	SAS OFF.
	LOCAL Kp TO 0.1.
	LOCAL Ki TO 0.005.
	LOCAL Kd TO 0.01.

	LOCK STEERING TO SHIP:SRFRETROGRADE.

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

		SET lockedThrottle TO lockedThrottle + descentRatePID:UPDATE(TIME:SECONDS,
																 SHIP:VERTICALSPEED).

		//try to zero out horizontal velocity
		IF starComponent:MAG > 1 SET starComponent TO starComponent:NORMALIZED.
		IF topComponent:MAG > 1 SET topComponent TO topComponent:NORMALIZED.

	  SET SHIP:CONTROL:STARBOARD  TO starComponent 	* SHIP:FACING:STARVECTOR.
	  SET SHIP:CONTROL:TOP        TO topComponent 	* SHIP:FACING:TOPVECTOR.

	}
	SAS ON.
	SET lockedThrottle TO 0.
}

DECLARE FUNCTION hover {
	DECLARE PARAMETER hoverPoint, bingoFuel IS 0.1.

	LOCAL Kp TO 0.1.
	LOCAL Ki TO 0.005.
	LOCAL Kd TO 0.01.

	initializeControls().

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

		SET lockedThrottle TO MIN(1,MAX(0,cThrottle + hoverPID:UPDATE(TIME:SECONDS,
			 													ALT:RADAR))).

		//try to zero out horizontal velocity
		//try to zero out horizontal velocity
		IF starComponent:MAG 	> 1 SET starComponent TO starComponent:NORMALIZED.
		IF topComponent:MAG 	> 1 SET topComponent 	TO topComponent:NORMALIZED.

	  SET SHIP:CONTROL:STARBOARD  TO starComponent 	* SHIP:FACING:STARVECTOR.
	  SET SHIP:CONTROL:TOP        TO topComponent 	* SHIP:FACING:TOPVECTOR.
	}
	SAS ON.
	SET lockedThrottle TO 0.

	deinitializeControls().
}

FUNCTION deorbitBurn {
	PARAMETER transitionHeight IS 750.
	LOCAL startAltitude IS SHIP:ALTITUDE + SHIP:BODY:RADIUS.
	LOCAL endAltitude IS SHIP:BODY:RADIUS + transitionHeight.
	LOCAL burnLexicon IS hohmannStats(startAltitude,endAltitude).

	//perform burn 1
}

FUNCTION testDeorbitBurn {
	PARAMETER transitionHeight IS 30000, burnPoint IS SHIP:APOAPSIS.
	LOCAL targetSemiMajorAxis TO (burnPoint + transitionHeight)/2 + SHIP:BODY:RADIUS.
	LOCAL deorbitBurnDeltaV TO deltaV(burnPoint,SHIP:ORBIT:SEMIMAJORAXIS, targetSemiMajorAxis).
	LOCAL deorbitBurnTime IS burnTime(deorbitBurnDeltaV,SHIP:BODY:ATM:ALTITUDEPRESSURE(burnPoint)).
	LOCAL tau IS TIME:SECONDS + ETA:APOAPSIS.
	LOCAL startTime IS tau - deorbitBurnTime/2.
	LOCAL endTime IS startTime + deorbitBurnTime.
	LOCAL burnVector IS calculateBurnVector(-deorbitBurnDeltaV,tau).

	performBurn(burnVector,startTime,endTime).
	LOCK STEERING TO SHIP:SRFRETROGRADE.

}
