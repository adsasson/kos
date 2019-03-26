@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).


PARAMETER inputHeading IS 90,
          inputApoapsis IS 100000,
          inputPeriapsis IS 100000,
          inputUseNode IS FALSE,
          inputUseWarp IS FALSE,
          inputGoalTWR IS 2.


          dependsOn("launch.ks").
          dependsOn("orbitLib.ks").
          dependsOn("shipStats.ks").

SET vesselStatsLexicon TO stageAnalysis().

performLaunch(inputHeading,inputApoapsis,inputGoalTWR).
IF VERBOSE PRINT "Finished launch program, beginning orbital insertion".
performOrbitalInsertion(inputHeading,inputApoapsis,inputPeriapsis,inputStaging,inputUseNode).
