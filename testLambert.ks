LOCAL testToF TO CONSTANT:PI*SQRT(((TARGET:POSITION:MAG+SHIP:POSITION:MAG))^3/8*SHIP:BODY:MU).
runoncepath("lambert.ks").
PRINT "TOF: " + testToF.
lambertProblem(testToF).
