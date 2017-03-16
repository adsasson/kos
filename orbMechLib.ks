//orbital mechanics library

PRINT "orbMechLib loaded.".

//credit for E,f,M converstion to orbit nerd.
//EccAnToMeanAn(e,E)

// M = E -e * sin(E).

//---------------------------------

//EccAnToMeanAn
DECLARE FUNCTION EccAnToMeanAn {
	DECLARE PARAMETER eccAn, ecc IS SHIP:ORBIT:ECCENTRICITY.
	
	IF (NOT (ecc > 1))  {
		SET MeanAn TO EccAn - ecc * SIN(EccAn).
		RETURN MeanAn.
	} ELSE {
		RETURN FALSE.
	}
	
}

//=============================================

//EccAnToTrueAn
//  sinf = sin(E)*sqrt(1 - e^2)/(1 - e * cos(E));
//  cosf = (cos(E) - e)/(1 - e * cos(E));
//  f = atan2(sinf, cosf);

DECLARE FUNCTION EccAnToTrueAn {
	DECLARE PARAMETER eccAn, ecc IS SHIP:ORBIT:ECCENTRICITY.

	
	IF (NOT (ecc > 1))  {
		SET sinF TO SIN(EccAn)*SQRT(1-ecc^2)/(1 - ecc * cos(EccAn)).
		SET cosF TO (COS(EccAn) - ecc)/(1 - ecc * cos(EccAn)).
		SET TrueAn TO ARCTAN2(sinF,cosF).
		RETURN TrueAn.
	} ELSE {
		RETURN FALSE.
	}
}
//-----------------------------------------------------------
DECLARE FUNCTION MeanAnToEccAn {

	//uses newton's method (for f(x), roots R Ri+1 = Ri - (f(Ri)/f'(Ri)).
	DECLARE PARAMETER  MeanAn, ecc IS SHIP:ORBIT:ECCENTRICITY.

	
		IF (NOT (ecc > 1))  {
			//check range of M
			SET MeanAn TO MOD(MeanAn, 360).
			IF (MeanAn < 180) {
				SET MeanAn TO MeanAn + 360.
			} ELSE IF (MeanAn > 180) {
				SET MeanAn TO MeanAn - 360.
			}
			
			IF ((MeanAn > -180 AND MeanAn < 0) OR (MeanAn > 180)) {
				SET EccAn TO MeanAn - ecc.
			} ELSE {
				SET EccAn TO MeanAnn + ecc.
			}
			
			SET Enew TO EccAn.
			SET Flag TO TRUE.
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


//------------------===========

DECLARE FUNCTION MeanAnToTrueAn {
	DECLARE PARAMETER MeanAn, ecc IS SHIP:ORBIT:ECCENTRICITY.
	
	IF (NOT (ecc > 1)) {
		SET EccAn TO MeanAnToEccAn(MeanAn,ecc).
		SET TrueAn TO EccAnToTrueAn(EccAn,ecc).
		RETURN TrueAn.
	} ELSE {
		RETURN FALSE.
	}
}

//------------------
DECLARE FUNCTION TrueAnToEccAn {
	DECLARE PARAMETER TrueAn, ecc IS SHIP:ORBIT:ECCENTRICITY.
	
	//?? i1 = sqrt(1-ecc)/(1+ecc).
	// arctan(i1*tan(TA/2))*2
	
	IF (NOT (ecc > 1)) {
		SET sinEccAn TO SIN(TrueAn)*SQRT(1-ecc^2)/(1 + ecc*COS(TrueAn)).
		SET cosEccAn TO (ecc + COS(TrueAn))/(1 + ecc*COS(TrueAn)).
		SET EccAn TO ARCTAN2(sinEccAn, cosEccAn).
		RETURN EccAn.
	} ELSE {
		RETURN FALSE.
	}
}

//------------------------------
DECLARE FUNCTION TrueAnToMeanAn {
	DECLARE PARAMETER TrueAn, ecc IS SHIP:ORBIT:ECCENTRICITY.
	
	IF (NOT (ecc > 1)) {
		SET EccAn TO TrueAnToEccAn(TrueAn,ecc).
		SET MeanAn TO EccAnToMeanAn(EccAn,ecc).
		RETURN MeanAn.
	} ELSE {
		RETURN FALSE.
	}
}
//================
//tangential angle for eccAn
DECLARE FUNCTION EccAnToPhi {
	DECLARE PARAMETER  EccAn, ecc IS SHIP:ORBIT:ECCENTRICITY.
	
	IF (NOT (ecc > 1)) {
		//-tan t = swrt(1-ecc2)cotphi
		SET cotPhi TO (-TAN(EccAn))/SQRT(1 - ecc^2).
		
		SET tanPhi TO (90 - cotPhi).
		SET phi TO ARCTAN(tanPhi).
		
		RETURN phi.
		
	} ELSE {
		RETURN FALSE.
	}
}
//=====================
//eccAn for Ralt
DECLARE FUNCTION EccAnForR {

	//r = alt + body radius
	DECLARE PARAMETER R,ecc IS SHIP:ORBIT:ECCENTRICITY,alpha IS SHIP:ORBIT:SEMIMAJORAXIS.
	
	SET cosEccAn TO (alpha - R)/(alpha*ecc).
	SET EccAn TO ARCCOS(cosEccAn).
	RETURN EccAn.
}

//===========================
//vis viva

DECLARE FUNCTION VisViva {
	//v = sqrt(mu*(2/r - 1/a))

	DECLARE PARAMETER R, alpha IS SHIP:ORBIT:SEMIMAJORAXIS, currentBody IS SHIP:BODY.
	
	SET mu TO currentBody:MU.
	
	SET velAtR TO SQRT(mu*(2/R - 1/alpha)).
	
	RETURN velAtR.
	
}
//=======================
//flight path angle at R (phi or gamma)

DECLARE FUNCTION FlightPathAngleAtR {
	DECLARE PARAMETER R,ecc IS SHIP:ORBIT:ECCENTRICITY, alpha IS SHIP:ORBIT:SEMIMAJORAXIS.
	
	SET eccAn TO EccAnForR(R,ecc,alpha).
	SET trueAn TO EccAnToTrueAn(eccAn,ecc).
	
	SET numerator TO (1 + ecc*COS(trueAn)).
	SET denominator TO SQRT(1 + ecc^2 + 2*ecc*COS(trueAn)).
	
	SET phi TO ARCCOS(numerator/denominator).
	
	RETURN phi.	
}
//==============================
//flight path angle
DECLARE FUNCTION flightPathAngle {
	LOCAL ecc TO SHIP:ORBIT:ECCENTRICITY.
	LOCAL trueAn TO SHIP:ORBIT:TRUEANOMALY.
	LOCAL cosPhi TO (1 + ecc*COS(trueAn))/(SQRT(1 + ecc^2 + 2*ecc*COS(trueAn))).
	LOCAL phi TO ARCCOS(cosPhi).
	
	RETURN phi.
}
//==============================
//R for TA
//r = (a(1-e^2))/(1+e*cos(TA)).
DECLARE FUNCTION RfromTA {
	DECLARE PARAMETER TrueAn, ecc IS SHIP:ORBIT:ECCENTRICITY, alpha IS SHIP:ORBIT:SEMIMAJORAXIS.
	
	SET R TO alpha*((1-ecc^2)/(1 + ecc*COS(TrueAn))).
	
	RETURN R.
}
//==========================
//TA for R
//need to test
DECLARE FUNCTION TrueAnForR {
	DECLARE PARAMETER R, ecc IS SHIP:ORBIT:ECCENTRICITY, alpha IS SHIP:ORBIT:ALPHA.
	
	IF ecc = 0 {
		RETURN FALSE.
	} ELSE {
	
		//SET cosTA TO (alpha - alpha*ecc^2 - R)/(R*ecc).
		//PRINT "cosTA: " + cosTA.
		SET eCosTA TO (alpha/R)*(1-ecc^2) - 1.
		SET cosTA TO eCosTA/ecc.
		
		SET trueAn TO ARCCOS(cosTA).
	
		RETURN trueAn.
		
	}
}
//=========================
//compute position from orbital elements.
//
DECLARE FUNCTION etaToR {
	DECLARE PARAMETER R, ecc IS SHIP:ORBIT:ECCENTRICITY, alpha IS SHIP:ORBIT:SEMIMAJORAXIS, currentBody IS SHIP:BODY.
	
	SET currentR TO SHIP:ALTITUDE + currentBody:RADIUS.
	//SET currentEccAn TO eccAnForR(currentR,ecc,alpha).
	//SET currentMeanAn TO EccAnToMeanAn(currentEccAn,ecc).
		
	SET currentTrueAn TO TrueAnForR(currentR,ecc,alpha).
	SET currentMeanAn TO TrueAnToMeanAn(currentTrueAn, ecc).
	
	PRINT "currentMeanAn: " + round(currentMeanAn,2).
	
	SET currentMu TO currentBody:MU.
	
	SET meanMotion TO SQRT(currentMu/alpha^3).
	
	SET trueAnAtR TO TrueAnForR(R,ecc,alpha).
	SET meanAnAtR TO TrueAnToMeanAn(trueAnAtR, ecc).
	
	SET deltaM TO MOD(meanAnAtR - currentMeanAn+360,360).
	SET deltaT TO deltaM/meanMotion.
	
	RETURN deltaT.
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