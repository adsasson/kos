@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

dependsOn("shipStats.ks").

PARAMETER recoverFile IS "shipStats.ks".

IF recoverFile <> -1 {
  copypath("0:" + recoverFile,"1:").
}
WAIT 1.
//clearscreen.
//set terminal:height to 75.
set terminal:width to 60.
//orbitalInsertion(targetHeading,targetApoapsis,targetPeriapsis,staging).

//PRINT "Ship Sections:".
LOCAL shipSections IS parseVesselSections().
//PRINT shipSections.
//PRINT "Fuel Stats".
 LOCAL fuelStats IS createSectionMassLexicon(shipSections).
//PRINT fuelStats.
//PRINT "Stage Stats:".
LOCAL stageStats IS createStageStatsLexicon(fuelStats,0,(100*CONSTANT:kPAtoATM),false).
//PRINT stageStats.
// LOCAL testStageStats IS test(fuelStats).
// PRINT testStageStats.
