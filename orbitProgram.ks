@LAZYGLOBAL OFF.

PARAMETER inputHeading IS 90,
          inputApoapsis IS 100000,
          inputPeriapsis IS 100000,
          inputOrbitFlag IS TRUE,
          inputUseNode IS TRUE,
          inputWarpFlag IS FALSE,
          inputGoalTWR IS 2,
          inputStaging TO TRUE,
          inputBuffer IS 60.

          RUNONCEPATH(bootfile).

          dependsOn("orbitLib.ks").
          dependsOn("shipStats.ks").

SET vesselStatsLexicon TO stageAnalysis().

performLaunch(inputHeading,inputApoapsis,inputPeriapsis,inputOrbitFlag,inputUseNode,inputWarpFlag,inputGoalTWR,inputStaging,inputBuffer).
IF VERBOSE PRINT "Finished launch program, beginning orbital insertion".
performOrbitalInsertion(inputHeading,inputApoapsis,inputPeriapsis,inputStaging,inputUseNode).
