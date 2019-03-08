@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

dependsOn("hohmann.ks").
download("executeNode.ks",1).

WAIT 1.
//clearscreen.
SET verbose TO TRUE.

LOCAL targetBody IS TARGET.
FUNCTION getTimeToPhaseAngle {
	PARAMETER targetPhaseAngle.

	// LOCAL targetTrueAnomaly IS targetBody:ORBIT:TRUEANOMALY.
	// LOCAL vesselTrueAnomaly IS SHIP:ORBIT:TRUEANOMALY.
	// LOCAL startingPhaseAngle IS targetTrueAnomaly - vesselTrueAnomaly.
	// //LOCAL targetAngularVelocity IS targetBody:VELOCITY:ORBIT.
	// //LOCAL vesselAngularVelocity IS SHIP:VELOCITY:ORBIT.
  // LOCAL targetAngularVelocity IS targetBody:ANGULARVEL - targetBody:BODY:POSITION.
	// LOCAL vesselAngularVelocity IS SHIP:ANGULARVEL - SHIP:BODY:POSITION.
  //
  // LOCAL vesselMeanMotion IS 360/SHIP:ORBIT:PERIOD.
  // LOCAL targetMeanMotion IS 360/targetBody:ORBIT:PERIOD.
  // //LOCAL deltaPhaseAngle IS targetPhaseAngle - startingPhaseAngle.
  // LOCAL deltaMeanMotion IS targetMeanMotion - vesselMeanMotion.
  //
  // LOCAL deltaPhaseAngle IS targetBody:LONGITUDE - SHIP:LONGITUDE. //works
  // //PRINT "DEBUG deltaPhaseAngle " + deltaPhaseAngle.
  // LOCAL deltaAngularVelocity IS targetAngularVelocity - vesselAngularVelocity.
  // PRINT "DEBUG deltaMeanMotion " + deltaMeanMotion.
	RETURN deltaPhaseAngle/deltaMeanMotion.
}
FUNCTION getTargetPhaseAngle {
  RETURN targetBody:LONGITUDE - SHIP:LONGITUDE. //works
  //PRINT (targetBody:LONGITUDE - SHIP:LONGITUDE).
  //RETURN (360 - (targetBody:LONGITUDE - SHIP:LONGITUDE))*-1.
}

FUNCTION calculateInterceptNode {
	//assumes coplanar circular orbits, assumes same parent body.

	LOCAL targetAltitude IS targetBody:ALTITUDE.
	LOCAL shipAltitude IS SHIP:ALTITUDE.

	LOCAL hohmmanStatsLex IS hohmannStats(shipAltitude,targetAltitude).
  //LOCAL targetPhaseAngle IS hohmmanStatsLex["phaseAngle"].
  LOCAL interceptPhaseAngle IS calculateInterceptAngle().
  LOCAL targetPhaseAngle IS getTargetPhaseAngle().

  LOCAL timeToInterceptBurn IS calculateTimeToInterceptBurn(targetPhaseAngle,interceptPhaseAngle).
  hohmannNodes(hohmmanStatsLex,(timeToInterceptBurn)).
}

// FUNCTION calculateTimeToInterceptBurn {
//   PARAMETER phaseAngle, interceptAngle.
//   LOCAL vesselMeanMotion IS 360/SHIP:ORBIT:PERIOD.
//   LOCAL targetMeanMotion IS 360/targetBody:ORBIT:PERIOD.
//   LOCAL deltaMeanMotion IS targetMeanMotion - vesselMeanMotion.
//   LOCAL deltaAngle IS interceptAngle - phaseAngle.
//   IF phaseAngle > 0 {
//     SET deltaAngle TO -deltaAngle.
//     SET deltaMeanMotion TO -deltaMeanMotion.
//   }
//
//   IF deltaAngle < 0 SET deltaAngle TO deltaAngle + 360.
//   IF deltaAngle > 340 SET deltaAngle TO deltaAngle - 360.
//
//   IF deltaMeanMotion <> 0 { RETURN deltaAngle/deltaMeanMotion.}
//
//   RETURN "UNDEFINED".
// }
FUNCTION calculateTimeToInterceptBurn {
  PARAMETER phaseAngle, interceptAngle.
  LOCAL vesselMeanMotion IS 360/SHIP:ORBIT:PERIOD.
  LOCAL targetMeanMotion IS 360/targetBody:ORBIT:PERIOD.
  LOCAL deltaMeanMotion IS targetMeanMotion - vesselMeanMotion.
  LOCAL deltaAngle IS interceptAngle - phaseAngle.
  LOCAL timeToInterceptBurn IS "UNDEFINED".
  //IF verbose
  PRINT "target phase angle: " + phaseAngle.
  IF phaseAngle < 0 {
    IF deltaAngle < 0 SET deltaAngle TO deltaAngle + 360.
    IF deltaAngle > 340 SET deltaAngle TO deltaAngle - 360.
    IF deltaMeanMotion <> 0 { SET timeToInterceptBurn TO deltaAngle/deltaMeanMotion.}
  } ELSE {
    SET deltaAngle TO phaseAngle - interceptAngle.
    SET deltaMeanMotion TO vesselMeanMotion - targetMeanMotion.
    IF deltaAngle < 0 SET deltaAngle TO deltaAngle + 360.
    IF deltaAngle > 340 SET deltaAngle TO deltaAngle - 360.
    IF deltaMeanMotion <> 0 { SET timeToInterceptBurn TO deltaAngle/deltaMeanMotion.}
  }
  //IF verbose
  PRINT "Time To Intercept Burn: " + timeToInterceptBurn.
  RETURN timeToInterceptBurn.
}

 FUNCTION calculateInterceptAngle {
   LOCAL shipRadius IS (SHIP:ORBIT:SEMIMAJORAXIS + SHIP:ORBIT:SEMIMINORAXIS)/2.
   LOCAL targetRadius IS (targetBody:ORBIT:SEMIMAJORAXIS + targetBody:ORBIT:SEMIMINORAXIS)/2.
   LOCAL interceptAngle IS 180.0 * (1.0 - ((shipRadius + targetRadius) / (2.0 * targetRadius))^1.5).
   IF ABS(SHIP:ORBIT:INCLINATION - targetBody:ORBIT:INCLINATION) > 90 {
     RETURN (360 - (180 - interceptAngle)).
   }
   //IF verbose
   PRINT "Intercept Angle is: " + interceptAngle.
   RETURN interceptAngle.
}

FUNCTION performIntercept {
//	SET targetBody TO TARGET.
	IF (DEFINED targetBody) {
		calculateInterceptNode().
		RUNONCEPATH("executeNode.ks").
	} ELSE {
		notifyError("Intercept.ks: Target is umdefined.").
	}

}
calculateInterceptNode().
