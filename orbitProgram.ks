@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

dependsOn("launch.ks").
dependsOn("orbitLib.ks").
dependsOn("shipStats.ks").


PARAMETER inputHeading IS 90,
          inputApoapsis IS 100000,
          inputPeriapsis IS 100000,
          inputScaleHeight IS 100000,
          inputGoalTWR IS 2,
          inputStaging TO TRUE,
          inputUseNode IS FALSE.
SET vesselStatsLexicon TO stageAnalysis().

performLaunch(inputHeading,inputApoapsis,inputScaleHeight,inputGoalTWR,inputStaging).
IF VERBOSE PRINT "Finished launch program, beginning orbital insertion".
performOrbitalInsertion(inputHeading,inputApoapsis,inputPeriapsis,inputStaging,inputUseNode).
