@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

dependsOn("hohmann.ks").
download("executeNode.ks",1).

LOCAL targetBody IS TARGET.

FUNCTION getTargetPhaseAngle {
  RETURN targetBody:LONGITUDE - SHIP:LONGITUDE. //works
}

FUNCTION calculateInterceptNode {
	//assumes coplanar circular orbits, assumes same parent body.

	LOCAL targetAltitude IS targetBody:ALTITUDE.
	LOCAL shipAltitude IS SHIP:ALTITUDE.

	LOCAL hohmmanStatsLex IS hohmannStats(shipAltitude,targetAltitude).
  LOCAL interceptPhaseAngle IS calculateInterceptAngle().
  LOCAL targetPhaseAngle IS getTargetPhaseAngle().

  LOCAL timeToInterceptBurn IS calculateTimeToInterceptBurn(targetPhaseAngle,interceptPhaseAngle).
  IF timeToInterceptBurn <> "UNDEFINED" {
		hohmannNodes(hohmmanStatsLex,timeToInterceptBurn).
	} ELSE {
		notifyError("intercept.ks: timeToInterceptBurn is undefined.").
	}
}

FUNCTION calculateTimeToInterceptBurn {
  PARAMETER phaseAngle, interceptAngle.
  LOCAL vesselMeanMotion IS 360/SHIP:ORBIT:PERIOD.
  LOCAL targetMeanMotion IS 360/targetBody:ORBIT:PERIOD.
  LOCAL deltaMeanMotion IS targetMeanMotion - vesselMeanMotion.
  LOCAL deltaAngle IS interceptAngle - phaseAngle.
	LOCAL timeToInterceptBurn IS "UNDEFINED".

  IF phaseAngle > 0 {
    SET deltaAngle TO -deltaAngle.
    SET deltaMeanMotion TO -deltaMeanMotion.
  }

  IF deltaAngle < 0 SET deltaAngle TO deltaAngle + 360.
  IF deltaAngle > 340 SET deltaAngle TO deltaAngle - 360.

  IF deltaMeanMotion <> 0 { SET timeToInterceptBurn TO deltaAngle/deltaMeanMotion.}

  RETURN timeToInterceptBurn.
}

// FUNCTION calculateTimeToInterceptBurn {
//   PARAMETER phaseAngle, interceptAngle.
//   LOCAL vesselMeanMotion IS 360/SHIP:ORBIT:PERIOD.
//   LOCAL targetMeanMotion IS 360/targetBody:ORBIT:PERIOD.
//   LOCAL deltaMeanMotion IS targetMeanMotion - vesselMeanMotion.
//   LOCAL deltaAngle IS interceptAngle - phaseAngle.
//   LOCAL timeToInterceptBurn IS "UNDEFINED".
//   //IF verbose
//   PRINT "target phase angle: " + phaseAngle.
//   IF phaseAngle < 0 {
//     IF deltaAngle < 0 SET deltaAngle TO deltaAngle + 360.
//     IF deltaAngle > 340 SET deltaAngle TO deltaAngle - 360.
//     IF deltaMeanMotion <> 0 { SET timeToInterceptBurn TO deltaAngle/deltaMeanMotion.}
//   } ELSE {
//     SET deltaAngle TO phaseAngle - interceptAngle.
//     SET deltaMeanMotion TO vesselMeanMotion - targetMeanMotion.
//     IF deltaAngle < 0 SET deltaAngle TO deltaAngle + 360.
//     IF deltaAngle > 340 SET deltaAngle TO deltaAngle - 360.
//     IF deltaMeanMotion <> 0 { SET timeToInterceptBurn TO deltaAngle/deltaMeanMotion.}
//   }
//   //IF verbose
//   PRINT "Time To Intercept Burn: " + timeToInterceptBurn.
//   RETURN timeToInterceptBurn.
// }

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
	PARAMETER useWarp IS TRUE, timeBuffer IS 60.
	IF (DEFINED targetBody) {
		calculateInterceptNode().
		FOR aNode IN ALLNODES {
			executeNode(NEXTNODE,useWarp,timeBuffer).//using next node since not sure if allnodes is sorted.
		}
	} ELSE {
		notifyError("Intercept.ks: Target is undefined.").
	}

}
//calculateInterceptNode().
//performIntercept().
