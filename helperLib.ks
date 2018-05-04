@LAZYGLOBAL OFF.

GLOBAL defaultLogFile TO defaultLogFile.txt.
GLOBAL defaultsLexicon TO lexicon(
  "kDefaultVerbosity","VERBOSE").
)

GLOBAL GFORCELIMIT TO 4.

// FUNCTION setGForceLimit {
//   PARAMETER newLimit.
//   SET GFORCELIMIT TO newLimit.
//   notify("G-FORCE LIMIT SET TO " + GFORCELIMIT).
// }

// FUNCTION unmanned {
//   IF VESSEL:CREW:EMPTY {
//     RETURN TRUE.
//   } ELSE {
//     RETURN FALSE.
//   }
// }

FUNCTION launchAzimuth { //THIS DOES NOT CALCULATE A ROTATING AZIMUTH
  PARAMETER targetInclination IS 0, targetOrbitalVelocity IS 0.
  LOCAL beta TO getInertialAzimuth(targetInclination).

  IF targetOrbitalVelocity <> 0 {
    RETURN getRotationalAzimuth(beta,targetOrbitalVelocity).
  }
  RETURN beta.
}

FUNCTION getInertialAzimuth {
  PARAMETER targetInclination IS 0.

  LOCAL phi TO SHIP:LATITUDE.
  IF phi > targetInclination {
    notify("CANNOT REACH TARGET INCLINATION FROM CURRENT LAUNCH SITE.").
  } ELSE {
    LOCAL beta TO ARCSIN(COS(targetInclination)/COS(phi)). //INERTIAL AZIMUTH
    //correct for retrograde?
    //IF targetInclination > 180 return 18- - beta.?
    RETURN beta.
  }
  RETURN 0.
}

FUNCTION getRotationalAzimuth {
  PARAMTER inertialAzimuth IS 0, targetOrbitalVelocity IS 0.
  LOCAL beta TO intertialAzimuth.
  LOCAL vGroundRotation TO SHIP:GROUNDSPEED.
  LOCAL vRotX TO (targetOrbitalVelocity*SIN(beta) - vGroundRotation).
  LOCAL vRotY TO (targetOrbitalVelocity*COS(beta)).

  RETURN ARCTAN(vRotX/vRotY).

}
// FUNCTION announce {
//   PARAMETER message, delay IS 5, style IS 3, size IS 20, color IS YELLOW, echo IS TRUE.
//   //style 1: upper left, 2:upper center, 3: lower right, 4:lower center.
//   HUDTEXT("kOS: " + message,delay,style,size,color,echo).
// }
//
// FUNCTION notify {
//   PARAMETER message, verbosity IS defaultsLexicon["kDefaultVerbosity"].
//
//   LOCAL verbosityLexicon TO lexicon("VERBOSE",3,"STANDARD",2,"MINIMUM",1).
//
//   IF verbosityLexicon(verbosity) > 2 {
//     announce(message).
//   }
//   IF verbosityLexicon(verbosity) > 1 {
//     print(message).
//   }
//
//   log message TO defaultLogFile.
// }
//
// FUNCTION countDown {
//   PARAMETER defaultCount IS 5.
//   announce("Beginning Count Down",1,3,20,YELLOW,FALSE).
//   FROM {local x IS defaultCount.} UNTIL x = 0 STEP {SET x TO x - 1.} DO {
//     announce("T - " + x, 1, 3, 20, YELLOW, FALSE).
//   }
// }

FUNCTION getMaximumTWR {
	LOCAL gravityAtAltitude TO SHIP:BODY:MU/(SHIP:ALTITUDE + SHIP:BODY:RADIUS)^2.
	//gravity for altitude
	RETURN (SHIP:AVAILABLETHRUST/(SHIP:MASS * gravityAtAltitude)).
}

// FUNCTION pointTo {
// 	PARAMETER goal, useRCS IS FALSE, timeOut IS 60, tol IS 1.
//
// 	IF useRCS {
// 		RCS ON.
// 	}
//
// 	IF goal:ISTYPE("DIRECTION")  {
// 		SET goal TO goal:VECTOR.
// 	}
//
// 	LOCAL timeStart TO TIME.
// 	UNTIL ABS(VANG(SHIP:FACING:VECTOR,goal)) < tol {
// 		IF (TIME - timeStart) > timeOut {
// 			break.
// 		}
// 		WAIT 0.
// 	}.
//
// 	RETURN TRUE.
// }

FUNCTION getManeuverDeltaV {
    //v^2 = GM*(2/r-1/a) for inplane orbit changes
    PARAMETER altitude0 IS SHIP:ALTITUDE,
              alpha0 IS SHIP:ORBIT:SEMIMAJORAXIS,
              altitude1 IS SHIP:ALTITUDE,
              alpha1 IS SHIP:ORBIT:SEMIMAJORAXIS,
              currentBody IS SHIP:BODY.

    LOCAL r0 TO currentBody:RADIUS + altitude0.
    LOCAL r1 TO currentBody:RADIUS + altitude1.
    LOCAL mu TO currentBody:MU.
    LOCAL velocity0 TO 0.
    LOCAL velocity1 TO 0.

    IF (alpha0 > 0) {
      SET velocity0 TO SQRT(mu*(2/r0 - 1/alpha0)).
    }
    IF (alpha1 > 0) {
      SET velocity1 TO SQRT(mu(2/r2 - 1/alpha1)).
    }

    RETURN ABS(velocity0 - velocity1).
}

FUNCTION executeNode {
  PARAMETER warpFlag IS FALSE.
  SAS OFF.
  LOCAL node TO NEXTNODE.
  LOCAL nodePrograde TO node:DELTAV.
  LOCAL nodeBurnTime TO getManueverBurnTime(node:DELTAV:MAG).
  LOCAL done TO FALSE.

  IF warpFlag {
    KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + (node:ETA - nodeBurnTime/2 + 60)).
  }

  LOCK STEERING TO nodePrograde.
  pointTo(nodePrograde).

  WAIT UNTIL node:ETA <= (nodeBurnTime/2).

  LOCAL currentThrottle TO 0.
  LOCK THROTTLE TO currentThrottle.

  LOCAL deltaV0 TO node:DELTAV.

  //burn loop
  UNTIL done {
    stageLogic().

    LOCAL maxAcceleration TO SHIP:MAXTHRUST/SHIP:MASS.

    IF maxAcceleration = 0 {
      notify("ERROR: NO AVAILABLE THRUST").
    } ELSE {
      SET currentThrottle TO MIN(node:DELTAV:MAG/maxAcceleration,1).
    }

    IF VDOT(deltaV0, node:DELTAV) < 0 {
      notify("END BURN, remaining deltaV " + ROUND(node:DELTAV:MAG,1) + " m/s, VDOT: " + ROUND(VDOT(deltaV0, node:DELTAV),1),"STANDARD").
      SET currentThrottle TO 0.
      BREAK.
    }

    IF node:DELTAV:MAG < 0.1 {
      notify("FINALIZING BURN, REMAIN DV " + ROUND(node:DELTAV:MAG,1) + "M/S, VDOT: " + ROUND(VDOT(deltaV0,node:DELTAV),1),"STANDARD").
      //WE BURN SLOWLY UNTIL OUR NODE VECTOR STARTS TO DRIFT SIGNIFICANTLY FROM INITIAL VECTOR
      //THIS USUALLY MEANS WE ARE ON POINT
      WAIT UNTIL VDOT(deltaV0, node:DELTAV) < 0.5.

      SET currentThrottle TO 0.
      notify("END BURN, REMAIN DV " + ROUND(node:DELTAV:MAG,1) + "M/S, VDOT: " + ROUND(VDOT(deltaV0,node:DELTAV),1),"STANDARD").
      SET done TO TRUE.
    }
  }

  UNLOCK STEERING.
  UNLOCK THROTTLE.
  WAIT 1.

  REMOVE node.

  SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
}

FUNCTION getEngineStats {
  PARAMETER pressure IS 0.
  //for active engines only
  LOCAL totalThrust TO 0.
  LOCAL totalISP TO 0.
  LOCAL avgISP TO 0.
  LIST ENGINES IN shipEngines.
  FOR eng IN shipEngines {
    IF eng:IGNITION {
      SET totalThrust TO totalThrust + eng:AVAILABLETHRUSTAT(pressure).
      SET totalISP TO totalISP + (engine:AVAILABLETHRUSTAT(pressure)/eng:ISPAT(pressure)).
    }
  }
  IF totalISP > 0 {
    SET avgISP TO totalThrust/totalISP.
  }

  RETURN LEXICON("totalISP",totalISP,
                "totalThrust",totalThrust,
                "averageISP",avgISP).
}

FUNCTION getManueverBurnTime {
  PARAMETER maneuverDeltaV, currentShip IS SHIP, pressure IS 0.

  LOCAL totalFuelMass TO SHIP:MASS - SHIP:DRYMASS.
  LOCAL g0 TO 9.82.
  LOCAL engineStats TO  getEngineStats(pressure).
  LOCAL averageISP TO engineStats["averageISP"].
  LOCAL totalThrust TO engineStats["totalThrust"].
  LOCAL maneuverBurnTime TO 0.

  IF totalThrust > 0 {
    IF (NOT unmanned()) AND totalThrust/(SHIP:MASS * g0) > GFORCELIMIT {
      SET totalThrust TO GFORCELIMIT * SHIP:MASS * g0.
    }
    SET maneuverBurnTime TO g0 * SHIP:MASS * averageISP * (1 - CONSTANT:E^(-maneuverDeltaV / (g0 * averageISP)))/totalThrust.
  } ELSE {
    notify("ERROR: AVAILABLE THRUST IS 0.").
  }
  notify("BURN TIME FOR " + ROUND(maneuverDeltaV,2) + "m/s: " + ROUND(maneuverBurnTime,2) + " s", "STANDARD").

  RETURN maneuverBurnTime.
}
