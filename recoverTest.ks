@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

dependsOn("launch.ks").

dependsOn("orbitLib.ks").


PARAMETER targetHeading IS 90, targetApoapsis IS 100000, targetPeriapsis IS 100000, scaleHeight IS 100000, goalTWR IS 2, staging TO TRUE.

orbitalInsertion(targetHeading,targetApoapsis,targetPeriapsis,staging).
