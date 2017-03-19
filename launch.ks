//LAUNCH SCRIPT

//atmo_ascent
//orbital insertion
DECLARE PARAMETER cHeading IS 90, cApo IS 100000, cPeri IS 0.


runoncepath("ascent.ks").
runoncepath("orbitLib.ks").

//sanitize input
IF cApo < cPeri {
	LOCAL oldValue TO cPeri.
	SET cPeri TO cApo.
	SET cApo TO oldValue. 
}

ascent(cHeading,cApo).
orbitalInsertion(cPeri).
