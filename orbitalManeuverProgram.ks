@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

dependsOn("hohmann.ks").
//dependsOn("executeNode.ks").

PARAMETER startAltitude IS SHIP:ALTITUDE, endAltitude IS (SHIP:ALTITUDE * 2), timeToBurn IS 300.

createHohmannManeuver(startAltitude,endAltitude,timeToBurn).
executeNode(NEXTNODE,TRUE).
