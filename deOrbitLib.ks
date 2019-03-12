//de-orbital maneuver library
@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).
dependsOn("shipLib.ks").
dependsOn("navigationLib.ks").


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
