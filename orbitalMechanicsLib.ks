//basic orbital mechanics library
@LAZYGLOBAL OFF.


FUNCTION deltaV {

	//v^2= GM*(2/r-1/a)
	PARAMETER burnPoint,
						alpha1 IS SHIP:BODY:RADIUS,
						alpha2 IS SHIP:BODY:RADIUS,
						cBody IS SHIP:BODY.

	LOCAL r0 TO cBody:RADIUS + burnPoint.

	LOCAL mu TO cBody:MU.
	LOCAL v1 TO 0.
	LOCAL v2 TO 0.

	IF (alpha1 > 0) {
		SET v1 TO SQRT(mu*(2/r0 - 1/alpha1)).
	}
	IF (alpha2 > 0) {
		SET v2 TO SQRT(mu*(2/r0 - 1/alpha2)).
	}

	RETURN ABS(v1 - v2).
}

DECLARE FUNCTION deltaVgeneral {

	//v^2= GM*(2/r-1/a)
	PARAMETER alt1 IS SHIP:ALTITUDE,
						alt2 IS SHIP:ALTITUDE,
						alpha1 IS SHIP:ORBIT:SEMIMAJORAXIS,
						alpha2 IS SHIP:ORBIT:SEMIMAJORAXIS,
						cBody IS SHIP:BODY.

	LOCAL r1 TO cBody:RADIUS + alt1.
	LOCAL r2 TO cBody:RADIUS + alt2.
	LOCAL mu TO cBody:MU.
	LOCAL vel1 TO 0.
	LOCAL vel2 TO 0.

	IF (alpha1 > 0) {
		SET vel1 TO SQRT(mu*(2/r1 - 1/alpha1)).
	}
	IF (alpha2 > 0) {
		SET vel2 TO SQRT(mu*(2/r2 - 1/alpha2)).
	}

	return ABS(vel1 - vel2).
}

FUNCTION calculateBurnVector {
	PARAMETER burnDeltaV, timeOfBurn.
	LOCAL r0 TO SHIP:POSITION.
	LOCAL r1 TO POSITIONAT(SHIP,timeOfBurn).
	LOCAL v0 TO SHIP:VELOCITY:ORBIT.
	LOCAL v1 TO VELOCITYAT(SHIP,timeOfBurn):ORBIT * burnDeltaV.
	RETURN (r1 - r0) + v1.
}
//tofang
//
//a angle around orbit
//currentTA
//TAatT == currentTA + a

//eccan from ta

//r2d  CONSTANT RADTODEG
//currentMeanAn TO currentEccAn - ecc * SIN(currentEc)*r2d
//meananAtT TO eccAanAtT - ecc* SIN(eccAnAtT)*r2d

//set dmTO mod(mt-m0 +360,360).
//retrun (dM * orbitperiod/360)+orbitperido*floor(a/360)*(a/abs(a))
