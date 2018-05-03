@LAZYGLOBAL OFF.

// //ascent
// //orbital insertion
// RUNONCEPATH("utilLib.ks").
//
// dependsOn("ascent.ks").
// dependsOn("orbitLib.ks").
//
// DECLARE PARAMETER cHeading IS 90, cApo IS 100000, cPeri IS 0, goalTWR IS 2.
//
// SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
// //sanitize input
// IF cApo < cPeri {
// 	LOCAL oldValue TO cPeri.
// 	SET cPeri TO cApo.
// 	SET cApo TO oldValue.
// }
// IF cHeading > 360 {
// 	SET cHeading TO cHeading - 360*MOD(cHeading,360).
// }
//
// ascent(cHeading,cApo,goalTWR).
// orbitalInsertion(cPeri).
