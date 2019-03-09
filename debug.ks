@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

dependsOn("hohmann.ks").
download("executeNode.ks",1).

WAIT 1.
//clearscreen.

FUNCTION getTargetPhaseAngle {
  PRINT "Reference: " + (targetBody:LONGITUDE - SHIP:LONGITUDE). //works
	LOCAL targetVector IS TARGET:ORBIT:POSITION.
	LOCAL shipVector IS SHIP:ORBIT:POSITION.
	LOCAL targetReference IS TARGET:ORBIT:POSITIONAT(TARGET:PERIAPSIS).
	LOCAL shipReference IS SHIP:ORBIT:POSITIONAT(SHIP:PERIAPSIS).
	LOCAL correctedShipVector IS shipVector - shipReference.
	LOCAL correctedTargetVector IS targetVector - targetReference.
	PRINT "Test: " + VANG(correctedTargetVector,correctedShipVector).

}


getTargetPhaseAngle().
