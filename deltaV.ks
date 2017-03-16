//ORBITAL INSERTION BURN
//PARAMETERS: BODY IS , burnAlt , targetAlt E, alpha (semimajor axis)

DECLARE FUNCTION deltaV {
 PARAMETER start, end, currentBody IS SHIP:BODY.

SET r0 TO start + currentBody:RADIUS.
SET r1 to end  + currentBody:RADIUS.
SET currentOrbit TO SHIP:VELOCITY:ORBIT.


//CHECKING CALCS FOR NOW
SET currentMu TO currentBody:MU.
LOCK currentMass TO SHIP:MASS.
LOCK currentAlt TO SHIP:ALTITUDE + currentBody:RADIUS.

//SET velocity1 TO SQRT(currentMu * (2/r1 - 1/alpha)).
SET currentDeltaV TO SQRT(currentMu/r0)*(sqrt((2*r1)/(r0+r1))-1).

CLEARSCREEN.

PRINT "delta: " + currentDeltaV.

return currentDeltaV.
}