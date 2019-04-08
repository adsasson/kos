@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

PARAMETER hoverHeight IS 100, bingoFuel IS 0.1.

dependsOn("shipLib.ks").

dependsOn("navigationLib.ks").
FUNCTION maxTWR {
  LOCAL gravityAtAltitude TO SHIP:BODY:MU/(SHIP:ALTITUDE + SHIP:BODY:RADIUS)^2.
  //gravity for altitude
  LOCAL pressure IS SHIP:BODY:ATM:ALTITUDEPRESSURE(SHIP:ALTITUDE).
  //RETURN (SHIP:AVAILABLETHRUST/(SHIP:MASS * gravityAtAltitude)).
  RETURN (SHIP:AVAILABLETHRUSTAT(pressure)/(SHIP:MASS * gravityAtAltitude)).
}

FUNCTION hoverOld {
  LOCAL target_twr is 0.
  LOCK STEERING TO UP.

  initializeControls().

  LOCAL LOCK maxThrustToWeight TO maxtwr().
//  LOCK throttle to min(target_twr / maxThrustToWeight, 1).
  lock steering to heading(90, 90).

  SET ship:control:pilotmainthrottle to 0.

  stage.
  LOCK throttle TO 1.
  Wait 2.
  LOCK throttle to min(target_twr / maxThrustToWeight, 1).
  LOCAL Kp TO 2.7.
  LOCAL Ki TO 4.4.
  LOCAL Kd TO 0.12.
  local pid is pidloop(Kp, Ki, Kd, 0, maxtwr).

  set pid:setpoint to 0.
  UNTIL FALSE {
  set pid:maxoutput to maxThrustToWeight.

  set target_twr to pid:update(time:seconds, ship:verticalspeed).

  wait 0.01.
}
    // RCS ON.
    // SET lockedThrottle TO 0.
    // LOCAL hoverPID TO PIDLOOP(Kp,Ki,Kd,0,1).
    // SET hoverPID:SETPOINT TO hoverHeight.
    // clearscreen.
    // UNTIL FALSE {
    //   PRINT lockedThrottle AT (0,0).
    //
    //   SET lockedThrottle TO MIN(1,MAX(,0)).
    //
    //   SET lockedThrottle TO MIN(1,MAX(0,lockedThrottle + hoverPID:UPDATE(TIME:SECONDS,
  	// 		 													ALT:RADAR))).
    //
    //   WAIT 0.
    // }
}

FUNCTION hover {
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
  SET hoverPID:SETPOINT TO targetAltitude.

  LOCAL LOCK fuelRes TO fuelReserve("liquidFuel").

  LOCK STEERING TO UP.
  LOCK THROTTLE TO MIN(targetTWR/mTWR,1).

  UNTIL false {
    SET hoverPID:MAXOUTPUT TO mTWR.
    //SET targetTWR TO hoverPID:UPDATE(TIME:SECONDS, SHIP:VERTICALSPEED).
    SET targetTWR TO hoverPID:UPDATE(TIME:SECONDS, SHIP:APOAPSIS).
    WAIT 0.
  }
}

initializeControls().
stage.
hover().
