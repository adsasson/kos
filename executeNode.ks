FUNCTION executeNode {
  PARAMETER warpFlag IS FALSE.
  LOCAL done TO FALSE.
  LOCAL nodePrograde TO SHIP:PROGRADE. //placeholder initialization.
  LOCAL nodeBurnTime TO 0. //placeholder initialization.

  initializeNode().
  initializeControls(nodePrograde,0).

  doNodeBurn ().

  deInitializeControls().
  deInitializeNode().
}
FUNCTION initializeNode {
  LOCAL node TO NEXTNODE.
  SET nodePrograde TO node:DELTAV.
  SET nodeBurnTime TO getManueverBurnTime(node:DELTAV:MAG).
}

FUNCTION initializeControls {
  PARAMETER currentHeading, currentThrottle.

  LOCK STEERING TO currentHeading.
  LOCK THROTTLE TO currentThrottle.

  pointTo(currentHeading).

}

FUNCTION deInitializeNode {
  REMOVE node.
}

FUNCTION deInitializeControls {
  UNLOCK THROTTLE.
  SET THROTTLE TO 0.
  UNLOCK STEERING.
  SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
}


FUNCTION doWarp {
  PARAMTER warpTime.
  KUNIVERSE:TIMEWARP:WARPTO(warpTime)
}

FUNCTION waitForBurn {
  IF warpFlag {
    doWarp(TIME:SECONDS + (node:ETA + nodeBurnTime/2 + 60)).
  }
  WAIT UNTIL node:ETA <= (nodeBurnTime/2).
}

FUNCTION doNodeBurn {
  LOCAL done TO FALSE.
  LOCAL deltaV0 TO node:DELTA.
  LOCAL maxAcceleration TO SHIP:MAXTHRUST/SHIP:MASS.
  LOCK nodeBurnVectorDotProduct TO VDOT(deltaV0,node:DELTAV).


  FUNCTION beginNodeBurn {

    IF maxAcceleration > 0 {
      IF unmanned() {
        SET currentThrottle TO MIN(node:DELTAV:MAG/maxAcceleration,1).
      } ELSE {
        SET currentThrottle TO MIN(MIN(node:DELTAV:MAG/maxAcceleration,node:DELTAV:MAG/(GFORCELIMIT*9.82)),1).
      }
    } ELSE {
      notify("ERROR: NO AVAILABLE THRUST").
    }
  }
  FUNCTION checkNodeBurn {

    IF nodeBurnVectorDotProduct < 0 {
      notify("END BURN, remaining deltaV " + ROUND(node:DELTAV:MAG,1) + " m/s, VDOT: " + ROUND(nodeBurnVectorDotProduct,1),"STANDARD").
      SET currentThrottle TO 0.
      RETURN TRUE.
    }
    RETURN FALSE.
  }
  FUNCTION endNodeBurn {
    FUNCTION trimBurn {
      IF node:DELTAV:MAG < 0.1 {
        UNTIL nodeBurnVectorDotProduct < 0.5 {
          SET currentThrottle TO MIN(node:DELTAV:MAG/maxAcceleration,0.1).
        }
      }
    }

    trimBurn().

    SET currentThrottle TO 0.
    notify("END BURN, REMAIN DV " + ROUND(node:DELTAV:MAG,1) + "M/S, VDOT: " + ROUND(nodeBurnVectorDotProduct),1),"STANDARD").
  }

  waitForBurn().

  LOCK done TO checkNodeBurn().

  UNTIL done {
    SET maxAcceleration TO SHIP:MAXTHRUST/SHIP:MASS.
    beginNodeBurn().
  }
  endNodeBurn().
}
