@LAZYGLOBAL OFF.

PARAMETER startAltitude IS SHIP:ALTITUDE, endAltitude IS (SHIP:ALTITUDE * 2), timeToBurn IS 300.

RUNONCEPATH(bootfile).

dependsOn("hohmann.ks").
dependsOn("executeNode.ks").

createHohmannManeuver(startAltitude,endAltitude,timeToBurn).
executeNode(NEXTNODE,TRUE).
