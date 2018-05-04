//orbit
//subOrbit
//launch
//ascend

//orbitalInsertion
//executeNode
//deOrbit
//tranfer
//intercept

//land
//reEnter
//descend
//poweredLanding
//unpoweredLanding

@LAZYGLOBAL OFF.

FUNCTION defaultAscentCurve {
  PARAMETER ratio.
  RETURN 90 * SQRT(ratio).
}

FUNCTION alternateAscentCurve {
  PARAMETER ratio.
  RETURN 90 * (1.5 * ratio).
}

LOCAL ascentCurves TO lexicon("kDefaultAscentCurve",defaultAscentCurve@,
        "kAlternateAscentCurve",alternateAscentCurve@).

FUNCTION getLaunchAzimuth {
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
  PARAMETER inertialAzimuth IS 0, targetOrbitalVelocity IS 0.
  LOCAL beta TO intertialAzimuth.
  LOCAL vGroundRotation TO SHIP:GROUNDSPEED.
  LOCAL vRotX TO (targetOrbitalVelocity*SIN(beta) - vGroundRotation).
  LOCAL vRotY TO (targetOrbitalVelocity*COS(beta)).

  RETURN ARCTAN(vRotX/vRotY).

}

FUNCTION launch {
  PARAMETER launchAzimuth IS 0.
  LOCAL currentPitch TO 0.

  initializeControls(HEADING(launchAzimuth,currentPitch),0.5).

  countDown().
  STAGE.
  notify("Launch!").
}

FUNCTION ascend {
  PARAMETER targetApoapsis, goalTWR, ascentCurve IS ascentCurves["kDefaultAscentCurve"].

  FUNCTION getScaleHeight {
    IF atmosphere {
      LOCAL atmosphereHeight TO SHIP:BODY:ATM:HEIGHT.
      IF targetApoapsis < atmosphereHeight {
        notify("WARNING: Orbit will not clear atmosphere. Adjusting apoapsis to " + atmosphereHeight + 1000 + " m").
        SET targetApoapsis TO atmosphereHeight + 1000.
      }
      RETURN atmosphereHeight.
    } ELSE {
      LOCAL minimumFeatureHeight TO surfaceFeature[SHIP:BODY:NAME].
      IF targetApoapsis < minimumFeatureHeight {
        notify("WARNING: Orbit will not clear minimum surface feature altitude. Adjusting apoapsis to " + minFeatureHeight + " m").
        SET targetApoapsis TO minFeatureHeight.
      }
      RETURN targetApoapsis.
    }
  }
  FUNCTION correctForDrag {
    IF (SHIP:APOAPSIS < targetApoapsis) {
      notify("Correcting for atmospheric drag.").
      pointTo(SHIP:PROGRADE).
      SET currentThrottle TO MAX(1,(targetApoapsis - SHIP:APOAPSIS)/targetApoapsis*10). //scale throttle to 1/10 difference between current apoapsis and target.
      WAIT UNTIL (SHIP:APOAPSIS >= targetApoapsis).
      SET currentThrottle TO 0.
    }
  }
  LOCAL atmosphere TO SHIP:BODY:ATM:EXISTS.
  LOCAL scaleHeight TO getScaleHeight().
  LOCK ratio TO ROUND((SHIP:ALTITUDE/scaleHeight),2).
  LOCK deltaPitch TO ascentCurve(ratio).
  LOCK maxTWR TO getMaximumTWR().

  //ASCENT LOOP
  IF ((NOT unmanned()) AND (goalTWR > GFORCELIMIT)) {
    SET goalTWR TO GFORCELIMIT.
  }

  UNTIL SHIP:APOAPSIS >= targetApoapsis {
    stageLogic().

    IF (atmosphere) {
      SET currentThrottle TO MIN(1,MAX(0,goalTWR/maximumTWR)).
    } ELSE { //unmanned and airless, no GForce/thrust restriction
      SET currentThrottle TO 1.
    }
    SET currentPitch TO 90 - (MIN(90,deltaPitch)).
    SET currentHeading TO HEADING(launchAzimuth, currentPitch).

    WAIT 0.
  }

  SET currentThrottle TO 0.
  SET currentHeading TO SHIP:PROGRADE.

  IF atmosphere {
    WAIT UNTIL (SHIP:ALTITUDE >= SHIP:BODY:ATM:HEIGHT).
    correctForDrag().
  }
  //engageDeployables("ASCENT").
}

FUNCTION orbit {
  PARAMETER targetInclination IS 0, targetApoapsis IS 100000, targetPeriapsis IS 100000, goalTWR is 2.
  //dependsOn("maneuverLib").

  //sanitize input
  IF targetApoapsis < targetPeriapsis {
    LOCAL oldValue TO targetPeriapsis.
    SET targetPeriapsis TO targetApoapsis.
    SET targetApoapsis TO oldValue.
  }
  IF targetInclination > 360 {
    SET targetInclination TO targetInclination - 360*MOD(targetInclination,360).
  }

  LOCAL targetOrbitalVelocity IS VisViva(targetApoapsis,(((targetApoapsis+targetPeriapsis)/2)+SHIP:BODY:RADIUS)).
  LOCAL launchAzimuth IS getLaunchAzimuth(targetInclination,targetOrbitalVelocity).

  launch(launchAzimuth).
  ascend(targetApoapsis,goalTWR).
  orbitalInsertion(targetPeriapsis).

  notify("ORBIT REACHED AT" + TIMESPAN:CLOCK).

  RETURN TRUE.
}

FUNCTION subOrbit {
  PARAMETER targetInclination IS 0, targetApoapsis IS 100000, goalTWR is 2.

  //sanitize input
  IF targetInclination > 360 {
    SET targetInclination TO targetInclination - 360*MOD(targetInclination,360).
  }

  LOCAL launchAzimuth IS getLaunchAzimuth(targetInclination).

  launch(launchAzimuth).
  ascend(targetApoapsis,goalTWR).

  RETURN TRUE.
}
