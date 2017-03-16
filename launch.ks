//LAUNCH SCRIPT

//atmo_ascent
//orbital insertion
DECLARE PARAMETER cHeading IS 90, cApo IS 100000, cPeri IS 0.


runoncepath("ascent.ks").
runoncepath("orbitLib.ks").

ascent(cHeading,cApo).
orbitalInsertion(cPeri).
