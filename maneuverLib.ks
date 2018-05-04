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

// FUNCTION VisViva {
// 	//v = sqrt(mu*(2/r - 1/a))
// 	PARAMETER R, alpha IS SHIP:ORBIT:SEMIMAJORAXIS, cMu IS SHIP:BODY:MU.
//
// 	LOCAL velAtR TO SQRT(cMu * (2/R - 1/alpha)).
//
// 	RETURN velAtR.
// }

FUNCTION orbitalInsertion {
  PARAMETER targetAltitude IS 100000, burnPoint IS SHIP:APOAPSIS.
  LOCAL targetAlpha TO (((burnPoint + targetAltitude)/2) + SHIP:BODY:RADIUS).

  IF SHIP:ORBIT:ECCENTRICITY >= 1 {
    SET targetAltitude TO targetApoapsis.
    IF (SHIP:PERIAPSIS < SHIP:BODY:RADIUS) {
      SET burnPoint TO SHIP:BODY:RADIUS + surfaceFeature["SHIP:BODY:NAME"] + 1000.
    } ELSE {
      SET burnPoint TO SHIP:PERIAPSIS.
    }
  }

  LOCAL etaToBurn TO getTimeToPoint(burnPoint).
  LOCAL tau TO etaToBurn + TIME:SECONDS.


  FUNCTION onOrbitBurn {
    LOCAL maneuverDeltaV TO getManeuverDeltaV(burnPoint,SHIP:SEMIMAJORAXIS,targetAltitude,targetAlpha).

    LOCAL onOrbitBurnManeuverNode TO NODE(tau,0,0,maneuverDeltaV).
    ADD onOrbitBurnManeuverNode.
    executeNode().
  }

  onOrbitBurn().
}

transfer(startOrbitR,endOrbitR,burnPoint,transferTypeFlag)
  //hohmann transfer
  hohmann(startOrbit,endOrbit,burnPoint)
    getEnterTransferOrbitNode(burnPoint)
      getEnterTransferDeltaV
    executeNode()
    getExitTransferOrbitNode()
      getExitTransferDeltaV
    executeNode()
