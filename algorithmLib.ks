@LAZYGLOBAL OFF.

FUNCTION bisectionMethod {
	PARAMETER f, endpointA, endpointB, tolerance, maximumIterations.
	// CONDITIONS: a < b, either f(a) < 0 and f(b) > 0 or f(a) > 0 and f(b) < 0
	// OUTPUT: value which differs from a root of f(x)=0 by less than TOL
	LOCAL midPoint IS (endpointA + endpointB)/2.
	LOCAL n IS 1.
	UNTIL (n >= maximumIterations) {
		SET midPoint TO (endpointA + endpointB)/2.
		IF (f:CALL(midPoint) = 0) OR (endpointB - endpointA)/2 < tolerance { RETURN midPoint.}
		SET n TO n + 1.
		IF (f:CALL(midPoint) > 0) AND (f:CALL(endpointA) > 0) {
			SET endpointA TO midPoint.
		} ELSE {
			SET endpointB TO midPoint.
		}
	}
	PRINT "Exceeded maximum number of iterations.".
	PRINT "Last Results is: " + midPoint.
}

FUNCTION binarySearch {
	PARAMETER f, endpointA, endpointB, tolerance, maximumIterations.
	LOCAL midPoint IS ABS((endpointA - endpointB)/2).
	LOCAL bestResult IS f:CALL(endpointA).
	LOCAL n IS 1.
    UNTIL (n >= maximumIterations) {
			SET n TO n + 1.
			IF midPoint <= tolerance {RETURN midPoint.}
			IF f:CALL(midPoint) <= bestResult {
				SET bestResult TO f:CALL(midPoint).
				SET endpointB TO midPoint.
			} ELSE {
				SET endpointA TO midPoint.
			}
		}
		PRINT "Exceeded maximum number of iterations.".
		PRINT "Last Results is: " + midPoint.
		RETURN midPoint.
}
