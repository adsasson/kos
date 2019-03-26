@LAZYGLOBAL OFF.

PARAMETER inputHeading IS 90,
          inputApoapsis IS 100000,
          inputPeriapsis IS 100000,
          inputOrbitFlag IS TRUE,
          inputUseNode IS TRUE,
          inputWarpFlag IS FALSE,
          inputGoalTWR IS 2,
          inputBuffer IS 60.

          RUNONCEPATH(bootfile).

          dependsOn("orbitLib.ks").
          dependsOn("shipStats.ks").

SET vesselStatsLexicon TO stageAnalysis().

performLaunch(inputHeading,inputApoapsis,inputPeriapsis,inputOrbitFlag,inputUseNode,inputWarpFlag,inputGoalTWR,inputBuffer).
