//burn time.

//parameters SHIP, deltaV.
DECLARE FUNCTION burn_time {
DECLARE PARAMETER currentShip, currentDeltaV.

LIST ENGINES IN currentEngines.
//SET currentFuel TO STAGE:RESOURCESLEX("LIQUIDFUEL").
//SET currentOx TO STAGE:RESOURCESLEX("OXIDIZER").

//SET currentFuelMass TO currentFuel:AMOUNT * currentFuel:DENSITY.
//SET currentOxMass TO currentOX:AMOUNT * currentOx:MASS.

SET totalFuelMass TO SHIP:MASS - SHIP:DRYMASS.

SET g0 TO 9.82.


SET totalThrust TO 0.
SET totalIsp TO 0.
SET avgISP TO 0.

SET currentStage TO STAGE:NUMBER.

FOR eng IN currentEngines {
	IF eng:IGNITION {
			SET totalThrust TO totalThrust + eng:AVAILABLETHRUST.
			SET totalISP TO totalISP + (eng:AVAILABLETHRUST/eng:ISP).
	}
}
IF totalISP > 0 { 
	SET avgISP TO totalThrust/totalISP.
}

//check for div by 0.
IF totalThrust > 0 {
	SET burnTime TO g0*SHIP:MASS*avgISP*(1-CONSTANT:E^(-currentDeltaV/(g0*avgISP)))/totalThrust.
} ELSE {
	PRINT "ERROR: AVAILABLE THRUST IS 0.".
}

RETURN burnTime.
}