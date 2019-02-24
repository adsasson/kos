@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

PARAMETER recoverFile.

dependsOn("launch.ks").

dependsOn("orbitLib.ks").


PARAMETER targetHeading IS 90, targetApoapsis IS 100000, targetPeriapsis IS 100000, scaleHeight IS 100000, goalTWR IS 2, staging TO TRUE.

IF recoverFile:DEFINED {
  download(recoverFile,1).
}

orbitalInsertion(targetHeading,targetApoapsis,targetPeriapsis,staging).
