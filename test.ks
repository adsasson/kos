//test intercept

run testOrbitLib.ks.
testOI().


//SET currentShip TO SHIP.
//SET currentBody TO SHIP:BODY.
//IF currentShip:HASTARGET {
//	PRINT TARGET.	
//	SET currentTarget TO TARGET.
	
//		IF currentTarget:BODY = currentShip:BODY {
		
//			SET radius1 TO currentShip:ALTITUDE + currentBody:RADIUS.
//			SET radius2 TO currentTarget:ALTITUDE + currentBody:RADIUS.
//			SET alpha1 TO currentShip:ORBIT:SEMIMAJORAXIS.
//			SET alpha2 TO currentTarget:ORBIT:SEMIMAJORAXIS.
//			SET mu TO currentBody:MU.
			
//			SET omega1 TO SQRT(mu/alpha1^3).  //same as mean motion
//			SET omega2 TO SQRT(mu/alpha2^3).
			
//			SET leadAngleRad TO CONSTANT:PI*(1 - (1/2*SQRT(2))*(SQRT((radius1/radius2 + 1)^3))).
			
//			PRINT "LEAD ANGLE: " + ROUND(CONSTANT:RADTODEG*leadAngleRad,2).
			
//		} ELSE {
//			PRINT "TARGET ORBITING ANOTHER BODY".
//		}
//} ELSE {
//	PRINT "NO TARGET SET.".
//}