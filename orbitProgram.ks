@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

dependsOn("launch.ks").
dependsOn("orbitLib.ks").
dependsOn("shipStats.ks").


PARAMETER inputHeading, inputApoapsis, inputPeriapsis, inputScaleHeight IS 100000, inputGoalTWR IS 2, inputStaging TO TRUE, inputUseNode IS TRUE.
SET vesselStatsLexicon TO stageAnalysis().
PRINT "DEBUG: VESSEL LEXICON " + vesselStatsLexicon.

launchProgram(inputHeading,inputApoapsis,inputPeriapsis,inputScaleHeight,inputGoalTWR,inputStaging).
IF VERBOSE PRINT "Finished launch program, beginning orbital insertion".
orbitalInsertion(inputHeading,inputApoapsis,inputPeriapsis,inputStaging,inputUseNode).
