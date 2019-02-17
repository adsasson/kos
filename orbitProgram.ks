@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

dependsOn("launch.ks").
WAIT 0.5.
dependsOn("orbitLib.ks").
WAIT 0.5.

PARAMETER targetHeading IS 90, targetApoapsis IS 100000, targetPeriapsis IS 100000, scaleHeight IS 100000, goalTWR IS 2, staging TO TRUE.

launchProgram(targetHeading,targetApoapsis,targetPeriapsis,scaleHeight,goalTWR,staging).
orbitalInsertion(targetHeading,targetApoapsis,targetPeriapsis,staging).
