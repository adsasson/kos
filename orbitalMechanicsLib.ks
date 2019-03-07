//orbital mechanics library
@LAZYGLOBAL OFF.


//credit for E,f,M conversion to orbit nerd.
//EccAnToMeanAn(e,E)

// M = E -e * sin(E).

//---------------------------------

//EccAnToMeanAn
FUNCTION meanAnomalyFromEccentricAnomaly {
	PARAMETER eccAn, ecc IS SHIP:ORBIT:ECCENTRICITY.

	IF (NOT (ecc > 1))  {
		LOCAL MeanAn TO EccAn - ecc * SIN(EccAn).
		RETURN MeanAn.
	} ELSE {
		RETURN FALSE.
	}
}
//-----------------------------------------------------------
FUNCTION eccentricAnomalyFromMeanAnomaly {

	//uses newton's method (for f(x), roots R Ri+1 = Ri - (f(Ri)/f'(Ri)).
	PARAMETER  MeanAn, ecc IS SHIP:ORBIT:ECCENTRICITY.


		IF (NOT (ecc > 1))  {
			//check range of M
			SET MeanAn TO MOD(MeanAn, 360).
			IF (MeanAn < 180) {
				SET MeanAn TO MeanAn + 360.
			} ELSE IF (MeanAn > 180) {
				SET MeanAn TO MeanAn - 360.
			}

			IF ((MeanAn > -180 AND MeanAn < 0) OR (MeanAn > 180)) {
				LOCAL EccAn TO MeanAn - ecc.
			} ELSE {
				LOCAL EccAn TO MeanAnn + ecc.
			}

			LOCAL Enew TO EccAn.
			LOCAL Flag TO TRUE.
			UNTIL (FLAG OR (ABS(Enew - EccAn) > 0)) {
				SET Flag TO FALSE.
				SET EccAn TO Enew.
				SET Enew TO EccAn + (MeanAn - EccAn + ecc*SIN(EccAn))/(1 - ecc*COS(EccAn)).
			}
			SET EccAn TO Enew.
			RETURN EccAn.
	} ELSE {
		RETURN FALSE.
	}

}

//EccAnToTrueAn
//  sinf = sin(E)*sqrt(1 - e^2)/(1 - e * cos(E));
//  cosf = (cos(E) - e)/(1 - e * cos(E));
//  f = atan2(sinf, cosf);

FUNCTION trueAnomalyFromEccentricAnomaly {
	PARAMETER eccAn, ecc IS SHIP:ORBIT:ECCENTRICITY.

	IF (NOT (ecc > 1))  {
		LOCAL sinF TO SIN(EccAn)*SQRT(1-ecc^2)/(1 - ecc * cos(EccAn)).
		LOCAL cosF TO (COS(EccAn) - ecc)/(1 - ecc * cos(EccAn)).
		LOCAL TrueAn TO ARCTAN2(sinF,cosF).
		RETURN TrueAn.
	} ELSE {
		RETURN FALSE.
	}
}
//------------------
FUNCTION eccentricAnomalyFromTrueAnomaly {
	PARAMETER TrueAn, ecc IS SHIP:ORBIT:ECCENTRICITY.

	//?? i1 = sqrt(1-ecc)/(1+ecc).
	// arctan(i1*tan(TA/2))*2

	IF (NOT (ecc > 1)) {
		LOCAL sinEccAn TO SIN(TrueAn)*SQRT(1-ecc^2)/(1 + ecc*COS(TrueAn)).
		LOCAL cosEccAn TO (ecc + COS(TrueAn))/(1 + ecc*COS(TrueAn)).
		LOCAL EccAn TO ARCTAN2(sinEccAn, cosEccAn).
		RETURN EccAn.
	} ELSE {
		RETURN FALSE.
	}
}

//------------------===========
FUNCTION trueAnomalyFromMeanAnomaly {
	PARAMETER MeanAn, ecc IS SHIP:ORBIT:ECCENTRICITY.

	IF (NOT (ecc > 1)) {
		LOCAL EccAn TO eccentricAnomalyFromMeanAnomaly(MeanAn,ecc).
		LOCAL TrueAn TO trueAnomalyFromEccentricAnomaly(EccAn,ecc).
		RETURN TrueAn.
	} ELSE {
		RETURN FALSE.
	}
}

//------------------------------
FUNCTION meanAnomalyFromTrueAnomaly {
	PARAMETER TrueAn, ecc IS SHIP:ORBIT:ECCENTRICITY.

	IF (NOT (ecc > 1)) {
		LOCAL EccAn TO eccentricAnomalyFromTrueAnomaly(TrueAn,ecc).
		LOCAL MeanAn TO meanAnomalyFromEccentricAnomaly(EccAn,ecc).
		RETURN MeanAn.
	} ELSE {
		RETURN FALSE.
	}
}

//================
//tangential angle for eccAn
FUNCTION phiFromEccentricAnomaly {
	PARAMETER  EccAn, ecc IS SHIP:ORBIT:ECCENTRICITY.

	IF (NOT (ecc > 1)) {
		//-tan t = swrt(1-ecc2)cotphi
		LOCAL cotPhi TO (-TAN(EccAn))/SQRT(1 - ecc^2).

		LOCAL tanPhi TO (90 - cotPhi).
		LOCAL phi TO ARCTAN(tanPhi).

		RETURN phi.

	} ELSE {
		RETURN FALSE.
	}
}
//=====================
//eccAn for Ralt
FUNCTION eccentricAnomalyFromPosition {

	//r = alt + body radius
	PARAMETER R,
						ecc IS SHIP:ORBIT:ECCENTRICITY,
						alpha IS SHIP:ORBIT:SEMIMAJORAXIS.

	LOCAL cosEccAn TO (alpha - R)/(alpha*ecc).
	LOCAL EccAn TO ARCCOS(cosEccAn).
	RETURN EccAn.
}

//===========================
//vis viva

FUNCTION VisViva {
	//v = sqrt(mu*(2/r - 1/a))
	PARAMETER R, alpha IS SHIP:ORBIT:SEMIMAJORAXIS, cMu IS SHIP:BODY:MU.

	LOCAL velAtR TO SQRT(cMu * (2/R - 1/alpha)).

	RETURN velAtR.
}
//=======================
//flight path angle at R (phi or gamma)

FUNCTION FlightPathAngleAtR {
	PARAMETER R, ecc IS SHIP:ORBIT:ECCENTRICITY, alpha IS SHIP:ORBIT:SEMIMAJORAXIS.

	LOCAL eccAn TO eccentricAnomalyFromPosition(R,ecc,alpha).
	LOCAL trueAn TO trueAnomalyFromEccentricAnomaly(eccAn,ecc).

	LOCAL numerator TO (1 + ecc*COS(trueAn)).
	LOCAL denominator TO SQRT(1 + ecc^2 + 2*ecc*COS(trueAn)).

	LOCAL phi TO ARCCOS(numerator/denominator).

	RETURN phi.
}
//==============================
//flight path angle
FUNCTION flightPathAngle {
	LOCAL ecc 		TO SHIP:ORBIT:ECCENTRICITY.
	LOCAL trueAn 	TO SHIP:ORBIT:TRUEANOMALY.
	LOCAL cosPhi 	TO (1 + ecc*COS(trueAn))/(SQRT(1 + ecc^2 + 2*ecc*COS(trueAn))).
	LOCAL phi 		TO ARCCOS(cosPhi).

	RETURN phi.
}
//==============================
//R for TA
//r = (a(1-e^2))/(1+e*cos(TA)).
FUNCTION positionFromTrueAnomaly {
	PARAMETER TrueAn, ecc IS SHIP:ORBIT:ECCENTRICITY, alpha IS SHIP:ORBIT:SEMIMAJORAXIS.

	LOCAL position TO alpha*((1-ecc^2)/(1 + ecc*COS(TrueAn))).

	RETURN position.
}
//==========================
//TA for R
//need to test
FUNCTION trueAnomalyFromPosition {
	PARAMETER R, ecc IS SHIP:ORBIT:ECCENTRICITY, alpha IS SHIP:ORBIT:ALPHA.

	IF ecc = 0 {
		RETURN FALSE.
	} ELSE {

		//SET cosTA TO (alpha - alpha*ecc^2 - R)/(R*ecc).
		//PRINT "cosTA: " + cosTA.
		LOCAL eCosTA TO (alpha/R)*(1-ecc^2) - 1.
		LOCAL cosTA TO eCosTA/ecc.

		LOCAL trueAn TO ARCCOS(cosTA).

		RETURN trueAn.

	}
}
//=========================
//compute position from orbital elements.
//
FUNCTION etaToPosition {
	PARAMETER position, ecc IS SHIP:ORBIT:ECCENTRICITY, alpha IS SHIP:ORBIT:SEMIMAJORAXIS, currentBody IS SHIP:BODY.

	LOCAL currentPosition TO SHIP:ALTITUDE + currentBody:RADIUS.

	//SET currentEccAn TO eccAnForR(currentR,ecc,alpha).
	//SET currentMeanAn TO EccAnToMeanAn(currentEccAn,ecc).

	LOCAL currentTrueAn TO trueAnomalyFromPosition(currentPosition,ecc,alpha).
	LOCAL currentMeanAn TO meanAnomalyFromTrueAnomaly(currentTrueAn, ecc).

	PRINT "currentMeanAn: " + round(currentMeanAn,2).

	LOCAL currentMu TO currentBody:MU.

	LOCAL meanMotion TO SQRT(currentMu/alpha^3).

	LOCAL trueAnAtR TO trueAnomalyFromPosition(position,ecc,alpha).
	LOCAL meanAnAtR TO meanAnomalyFromTrueAnomaly(trueAnAtR, ecc).

	LOCAL deltaM TO MOD(meanAnAtR - currentMeanAn+360,360).
	LOCAL deltaT TO deltaM/meanMotion.

	RETURN deltaT.
}

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
