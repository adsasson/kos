@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

//PARAMETER recoverFile.

dependsOn("launch.ks").

dependsOn("shipLib.ks").


//PARAMETER targetHeading IS 90, targetApoapsis IS 100000, targetPeriapsis IS 100000, scaleHeight IS 100000, goalTWR IS 2, staging TO TRUE.

IF DEFINED recoverFile  {
  download(recoverFile,1).
}
clearscreen.
set terminal:height to 75.
set terminal:width to 60.
//orbitalInsertion(targetHeading,targetApoapsis,targetPeriapsis,staging).
tagDecouplers().
LOCAL shipSectionsLex TO parseShipSections().
print shipSectionsLex.
LOCAL shipFuelStatsLex TO sectionFuelStatsLexicon(shipSectionsLex).
print "SHIP SECTION FUEL STATS".
print shipFuelStatsLex.
