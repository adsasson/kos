@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

dependsOn("launch.ks").
dependsOn("orbitLib.ks").
dependsOn("shipStats.ks").


PARAMETER inputHeading IS 90, inputApoapsis IS 200000, inputPeriapsis IS 200000, inputScaleHeight IS 100000, inputGoalTWR IS 2, inputStaging TO TRUE, inputUseNode IS TRUE.
SET vesselStatsLexicon TO stageAnalysis().

launchProgram(inputHeading,inputApoapsis,inputScaleHeight,inputGoalTWR,inputStaging).
IF VERBOSE PRINT "Finished launch program, beginning orbital insertion".
orbitalInsertion(inputHeading,inputApoapsis,inputPeriapsis,inputStaging,inputUseNode).
