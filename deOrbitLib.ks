//de-orbital maneuver library
@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).
dependsOn("shipLib.ks").
dependsOn("navigationLib.ks").
dependsOn("orbitalMechanicsLib.ks").
dependsOn("shipStats.ks").


FUNCTION performDeOrbitBurn {
	PARAMETER transitionHeight IS 30000, burnPoint IS SHIP:APOAPSIS, timeBuffer IS 30.
	LOCAL tau IS TIME:SECONDS + ETA:APOAPSIS.
	IF SHIP:ORBIT:ECCENTRICITY < 0.1 {//orbit is basically circular so can burn at any point
		SET tau TO TIME:SECONDS + timeBuffer.
	}
	//LOCAL startTime IS tau - deorbitBurnTime/2.
	LOCAL startTime IS tau.
	print "eta " + (tau - TIME:SECONDS).
	//LOCAL endTime IS startTime + deorbitBurnTime.


	//performBurn(burnVector,startTime,endTime).
  LOCK STEERING TO SHIP:RETROGRADE.
  waitForAlignmentTo(SHIP:RETROGRADE).

  WAIT UNTIL TIME:SECONDS >= startTime. {
    SET lockedThrottle TO 1.
    stageLogic().
    WAIT UNTIL SHIP:ORBIT:PERIAPSIS <= transitionHeight.
    SET lockedThrottle TO 0.
  }
	LOCK STEERING TO SHIP:SRFRETROGRADE.
}

FUNCTION atmosphericEntry {
  PARAMETER transitionHeight IS 30000.
  initializeControls().
  performDeOrbitBurn(transitionHeight).
  WAIT UNTIL SHIP:STATUS = "FLYING".
  disengageDeployables().
  engageParachutes().
  WAIT UNTIL SHIP:VELOCITY:SURFACE:MAGNITUDE <= 10.
  deployLandingGear().
  WAIT UNTIL SHIP:STATUS = "LANDED".
}

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
	LOCAL descentBurnTime TO calculateBurnTimeForDeltaV(finalVelocity).

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

	LOCAL LOCK velocityMagnitude TO calculateBurnTimeForDeltaV(SHIP:VELOCITY:ORBIT:MAG).
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
	PARAMETER targetAltitude IS 1000, bingoFuel IS 0.1.

  LOCAL targetTWR IS 0.

  LOCAL Kp TO 2.7.
  LOCAL Ki TO 4.4.
  LOCAL Kd TO 0.12.

  LOCAL LOCK horizontalVelocity TO SHIP:VELOCITY:SURFACE.
	LOCAL LOCK starComponent 			TO SHIP:SRFRETROGRADE:STARVECTOR.
	LOCAL LOCK topComponent 			TO SHIP:SRFRETROGRADE:TOPVECTOR.

  LOCAL LOCK mTWR TO maxTWR().

  LOCAL hoverPID TO PIDLOOP(Kp,Ki,Kd,0,mTWR).
  //SET hoverPID:SETPOINT TO 0.

  //LOCAL LOCK fuelRes TO fuelReserve("liquidFuel").
	LOCK STEERING TO SHIP:SRFRETROGRADE.

  //LOCK STEERING TO descent_vector().
  LOCK THROTTLE TO MIN(targetTWR/mTWR,1).
	//RCS ON.

  UNTIL SHIP:STATUS = "LANDED" {
		SET hoverPID:SETPOINT TO -SHIP:ALTITUDE/50.

    SET hoverPID:MAXOUTPUT TO mTWR.
		//fix for going back up
    SET targetTWR TO hoverPID:UPDATE(TIME:SECONDS, SHIP:VERTICALSPEED).
		//IF starComponent:MAG > 1 SET starComponent TO starComponent:NORMALIZED.
		//IF topComponent:MAG > 1 SET topComponent TO topComponent:NORMALIZED.

	  //SET SHIP:CONTROL:STARBOARD  TO starComponent 	* SHIP:FACING:STARVECTOR.
	  //SET SHIP:CONTROL:TOP        TO topComponent 	* SHIP:FACING:TOPVECTOR.
    WAIT 0.
  }
	SAS ON.
	SET lockedThrottle TO 0.
}

function descent_vector {

	if vang(srfretrograde:vector, up:vector) > 90 return unrotate(up).

	return unrotate(up:vector * g() - velocity:surface).

}

  function g { return body:mu / ((ship:altitude + body:radius)^2). }

function unrotate {

	parameter v. if v:typename <> "Vector" set v to v:vector.

	return lookdirup(v, ship:facing:topvector).

}
