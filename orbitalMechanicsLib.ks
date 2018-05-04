@LAZYGLOBAL OFF.

FUNCTION meanAnomalyFromEccentricAnomaly {
  PARAMETER eccentricAnomaly, eccentricity IS SHIP:ORBIT:ECCENTRICITY.

  IF (eccentricity <= 1) {
    RETURN eccentricAnomaly - eccentricity * SIN(eccentricAnomaly).
  }
  RETURN FALSE.
}

FUNCTION eccentricAnomalyFromMeanAnomaly {
  //uses Newton's method
  PARAMETER meanAnomaly, eccentricity IS SHIP:ORBIT:ECCENTRICITY.
  LOCAL eccentricAnomaly TO FALSE.

  IF (eccentricity <= 1) {
    SET meanAnomaly TO MOD(meanAnomaly,360).
    IF (meanAnomaly < 180) {
      SET meanAnomaly TO meanAnomaly + 360.
    } ELSE IF (meanAnomaly > 180)  {
      SET meanAnomaly TO meanAnomaly - 360.
    }

    IF ((meanAnomaly > -180 AND meanAnomaly < 0) OR (meanAnomaly > 180)) {
      SET eccentricAnomaly TO meanAnomaly - eccentricity.
    } ELSE {
      SET eccentricAnomaly TO meanAnomaly + eccentricity.
    }

    LOCAL f TO eccentricAnomaly - eccentricity*SIN(eccentricAnomaly) - meanAnomaly.
    LOCAL fPrime TO 1 - eccentricity*COS(eccentricAnomaly).

    LOCAL newValue TO eccentricAnomaly.
    LOCAL flag TO TRUE.
    UNTIL (flag OR (ABS(newValue - eccentricAnomaly) > 0)) {
      SET flag TO FALSE.
      SET f TO eccentricAnomaly - eccentricity*SIN(eccentricAnomaly) - meanAnomaly.
      SET fPrime TO 1 - eccentricity*COS(eccentricAnomaly).
      SET eccentricAnomaly TO newValue.
      SET newValue TO eccentricAnomaly - (f/fPrime).
    }
    RETURN ecccentricAnomaly.
  }
  RETURN FALSE.
}

FUNCTION trueAnomalyFromEccentricAnomaly {
  PARAMETER eccentricAnomaly, eccentricity IS SHIP:ORBIT:ECCENTRICITY.
  IF (eccentricity <= 1) {
    LOCAL sinF TO SIN(eccentricAnomaly)*SQRT(1 - eccentricity^2)/(1 - eccentricity * COS(eccentricAnomaly)).
    LOCAL cosF TO (COS(eccentricAnomaly) - eccentricity)/(1 - eccentricity*COS(eccentricAnomaly).
    return ARCTAN2(sinF/cosF).
  }
  RETURN FALSE.
}

FUNCTION eccentricAnomalyFromTrueAnomaly {
  PARAMETER trueAnomaly, eccentricity IS SHIP:ORBIT:ECCENTRICITY.

  IF (eccentricity <= 1) {
    LOCAL sinEccentricAnomaly TO SIN(trueAnomaly)*SQRT(1 - eccentricity^2)/(1 + eccentricity*COS(trueAnomaly)).
    LOCAL cosEccentricAnomaly TO (eccentricity + COS(trueAnomaly))/(1 + eccentricity*COS(trueAnomaly)).
    RETURN ARCTAN2(sinEccentricAnomaly/cosEccentricAnomaly).
  }
  RETURN FALSE.
}

FUNCTION trueAnomalyFromMeanAnomaly {
  PARAMETER meanAnomaly, eccentricity IS SHIP:ORBIT:ECCENTRICITY.
  IF (eccentricity <= 1) {
    LOCAL eccentricAnomaly TO eccentricAnomalyFromMeanAnomaly(meanAnomaly,eccentricity).
    RETURN trueAnomalyFromEccentricAnomaly(eccentricAnomaly,eccentricity).
  }
  RETURN FALSE.
}

FUNCTION meanAnomalyFromTrueAnomaly {
  PARAMETER trueAnomaly, eccentricity IS SHIP:ORBIT:ECCENTRICITY.
  IF (eccentricity <= 1) {
    LOCAL eccentricAnomaly TO eccentricAnomalyFromTrueAnomaly(trueAnomaly,eccentricity).
    RETURN meanAnomalyFromEccentricAnomaly(eccentricAnomaly,eccentricity).
  }
  RETURN FALSE.
}

FUNCTION trueAnomalyFromPosition {
  PARAMETER radius, eccentricity IS SHIP:ORBIT:ECCENTRICITY, alpha IS SHIP:ORBIT:SEMIMAJORAXIS.
  IF (eccentricity <> 0) {
    LOCAL cosTA TO ()(alpha/radius)*(1 - eccentricity^2)/eccentricity).
    RETURN ARCCOS(cosTA).
  }
  RETURN FALSE.
}

FUNCTION positionFromTrueAnomaly {
  PARAMETER trueAnomaly, eccentricity IS SHIP:ORBIT:ECCENTRICITY, alpha IS SHIP:ORBIT:SEMIMAJORAXIS.
  RETURN alpha * ((1 - eccentricity^2)/(1 + eccentricity * COS(trueAnomaly))).
}

FUNCTION eccentricAnomalyFromPosition {
  PARAMETER radius, eccentricity IS SHIP:ORBIT:ECCENTRICITY, alpha IS SHIP:ORBIT:SEMIMAJORAXIS.

  LOCAL cosEccentricAnomaly TO (alpha - radius)/(alpha * eccentricity).
  RETURN ARCCOS(cosEccentricAnomaly).
}

FUNCTION visViva {
	//v = sqrt(mu*(2/r - 1/a))
	PARAMETER radius, alpha IS SHIP:ORBIT:SEMIMAJORAXIS, cMu IS SHIP:BODY:MU.

	 RETURN SQRT(cMu * (2/radius - 1/alpha)).
}

FUNCTION getTimeToPoint {
  PARAMETER point, eccentricity IS SHIP:ORBIT:ECCENTRICITY, alpha IS SHIP:ORBIT:SEMIMAJORAXIS.
  IF point = SHIP:APOAPSIS { RETURN ETA:APOAPSIS. }
  IF point = SHIP:PERIAPSIS { RETURN ETA:PERIAPSIS. }

  LOCAL currentPosition TO SHIP:ALTITUDE + SHIP:BODY:RADIUS.
  LOCAL currentTrueAnomaly TO trueAnomalyFromPosition(point,eccentricity,alpha).
  LOCAL currentMeanAnomaly TO meanAnomalyFromTrueAnomaly(currentTrueAnomaly,eccentricity).
  LOCAL meanMotion TO SQRT(SHIP:BODY:MU/alpha^3).
  LOCAL trueAnomalyAtPoint TO trueAnomalyFromPosition(point,eccentricity,alpha).
  LOCAL meanAnomalyAtPoint TO meanAnomalyFromTrueAnomaly(trueAnomaly,eccentricity).

  LOCAL deltaMeanAnomaly TO MOD(meanAnomalyAtPoint - currentMeanAnomaly + 360,360).
  RETURN deltaMeanAnomaly/meanMotion.

}
