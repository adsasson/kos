@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

dependsOn("orbitalMechanicsLib.ks").
dependsOn("shipLib.ks").
dependsOn("navigationLib.ks").
dependsOn("shipStats.ks").

FUNCTION testDeorbitBurn {
	PARAMETER transitionHeight IS 30000, burnPoint IS SHIP:APOAPSIS.
	LOCAL targetSemiMajorAxis TO (burnPoint + transitionHeight)/2 + SHIP:BODY:RADIUS.
	LOCAL deorbitBurnDeltaV TO deltaV(burnPoint,SHIP:ORBIT:SEMIMAJORAXIS, targetSemiMajorAxis).
	LOCAL deorbitBurnTime IS burnTime(deorbitBurnDeltaV,SHIP:BODY:ATM:ALTITUDEPRESSURE(burnPoint)).
	LOCAL tau IS TIME:SECONDS + ETA:APOAPSIS.
	LOCAL startTime IS tau - deorbitBurnTime/2.
  print "eta " + ETA:APOAPSIS.
	LOCAL endTime IS startTime + deorbitBurnTime.
	LOCAL burnVector IS calculateBurnVector(-deorbitBurnDeltaV,tau).

	//performBurn(burnVector,startTime,endTime).
  LOCK STEERING TO burnVector.
  WAIT UNTIL TIME:SECONDS >= startTime. {
    SET lockedThrottle TO 1.
    stageLogic().
    WAIT deorbitBurnTime.
    SET lockedThrottle TO 0.
  }
	LOCK STEERING TO SHIP:SRFRETROGRADE.

}
initializeControls().
testDeorbitBurn().
engageParachutes().
