@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

PARAMETER hoverHeight IS 100, bingoFuel IS 0.1.


dependsOn("navigationLib.ks").

FUNCTION hover {


  LOCAL LOCK horizontalVelocity TO SHIP:VELOCITY:SURFACE.
  LOCAL Kp TO 0.0001.
  LOCAL Ki TO 0.
  LOCAL Kd TO 0.
    LOCK STEERING TO UP.
    stage.
    initializeControls().
    RCS ON.
    SET lockedThrottle TO 0.
    LOCAL hoverPID TO PIDLOOP(Kp,Ki,Kd,0,1).
    SET hoverPID:SETPOINT TO hoverHeight.
    clearscreen.
    UNTIL FALSE {
      PRINT lockedThrottle AT (0,0).

      SET lockedThrottle TO MIN(1,MAX(,0)).

      SET lockedThrottle TO MIN(1,MAX(0,lockedThrottle + hoverPID:UPDATE(TIME:SECONDS,
  			 													ALT:RADAR))).

      WAIT 0.
    }
}

hover().
