@LAZYGLOBAL OFF.

//ascend
//orbital insertion


DECLARE PARAMETER aHeading IS 90, anApoapsis IS 100000, aPeriapsis IS 0, orbitInsert IS true, goalTWR IS 2.

//SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
//initialize controls
//sanitize input
IF anApoapsis < aPeriapsis {
	LOCAL oldValue TO aPeriapsis.
	SET aPeriapsis TO anApoapsis.
	SET anApoapsis TO oldValue.
}
IF aHeading > 360 {
	SET aHeading TO aHeading - 360*MOD(aHeading,360).
}

ignition().
ascend(aHeading, anApoapsis, goalTWR).
if orbitInsert {
	orbitalInsertion(aPeriapsis).
} else {
	//handle suborbital trajectory
}
