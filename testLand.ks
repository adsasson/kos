//landing

DECLARE PARAMETER transitionPoint IS 1000, deorbit IS FALSE, flag IS FALSE.

copypath("0:descent","1:").
clearscreen.
runoncepath("descent.ks").
IF deorbit {
  LOCAL vStart TO SHIP:GROUNDSPEED.
  LOCK STEERING TO SHIP:SRFRETROGRADE.
  WAIT 3.
  SET THROTTLE TO 1.
  stageLogic().
  WAIT UNTIL SHIP:GROUNDSPEED <= (vStart/2).
  SET THROTTLE TO 0.
  UNLOCK STEERING.
}
IF flag {
  descent(transitionPoint).
} ELSE {
  testDescent(transitionPoint).
}
poweredLanding().
