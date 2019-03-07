@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

dependsOn("launch.ks").

dependsOn("orbitLib.ks").

PARAMETER targetHeading IS 90, targetApoapsis IS 100000, targetPeriapsis IS 100000, scaleHeight IS 100000, goalTWR IS 2, staging TO TRUE, useNode IS FALSE.

launchProgram(targetHeading,targetApoapsis,targetPeriapsis,scaleHeight,goalTWR,staging).
//IF VERBOSE
PRINT "Finished launch. Program, beginning orbital insertion".
orbitalInsertion(targetHeading,targetApoapsis,targetPeriapsis,staging,useNode).
