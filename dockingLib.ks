@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).
//this is mostly adapted from gisikw and 'KS programming' on youtube

LOCAL targetBody IS SHIP:TARGET.

FUNCTION translate {
  PARAMETER targetVector.
  RCS ON.
  IF targetVector:MAG > 1 SET targetVector TO targetVector:normalized.

  SET SHIP:CONTROL:STARBOARD  TO targetVector * SHIP:FACING:STARVECTOR.
  SET SHIP:CONTROL:FORE       TO targetVector * SHIP:FACING:FOREVECTOR.
  SET SHIP:CONTROL:TOP        TO targetVector * SHIP:FACING:TOPVECTOR.
}

FUNCTION getClosestTargetPort {
  IF SHIP:CONTROLPART:ISTYPE("DOCKINGPORT") {
    LOCAL controlPort TO SHIP:CONTROLPART.
    LOCAL portSize TO controlPort:NODETYPE.
    LOCAL portDistance TO 999.
    LOCAL portAngle TO 999.
    LOCAL targetPort TO controlPort.
    LOCAL targetPorts TO TARGET:DOCKINGPORTS.

    //make sure ports exist on target vessel.
    IF targetPorts:LENGTH = 0 {
      notifyError("No docking ports found on target vessel.").
      RETURN.
    }
    //iterate over target ports that have same size, find closest port by
    //distance or angle, and set to target port.
    FOR port IN targetPorts {
      IF (port:STATE = "Ready") AND (port:NODETYPE = portSize) {
        LOCAL cDistance TO (port:NODEPOSITION - controlPort:NODEPOSITION):MAG.
        LOCAL cAng TO VANG(port:PORTFACING:VECTOR,controlPort:PORTFACING:VECTOR).
        IF (cDistance < portDistance) OR (cAng < portAngle) {
          SET portDistance TO cDistance.
          SET cAng TO portAngle.
          SET targetPort TO port.
        }
      }
    }
    RETURN LEXICON("dockingPort",controlPort,"targetPort",targetPort).
  } ELSE {
    notify("Setting control point to docking port.").
    LOCAL ports TO SHIP:DOCKINPORTS.
    IF ports:LENGTH <> 0 {
      ports[0]:CONTROLFROM.
      getClosestTargetPort().
    } ELSE {
      notifyError("No docking port found on vessel.").
      RETURN.
    }
  }
}

FUNCTION approachPort {
  PARAMETER targetPort, dockingPort, distance, speed.

  dockingPort:CONTROLFROM().

  LOCAL LOCK distanceOffset TO targetPort:PORTFACING:VECTOR * distance.
  LOCAL LOCK approachVector TO targetPort:NODEPOSITION - dockingPort:NODEPOSITION + distanceOffset.
  LOCAL LOCK relativeVelocity TO SHIP:VELOCITY:ORBIT - targetPort:SHIP:VELOCITY:ORBIT.
  LOCK STEERING TO -1 * targetPort:PORTFACING:VECTOR.

  UNTIL dockingPort:STATE <> "Ready" { //until ship:status = "DOCKED"?
    translate((approachVector:normalized * speed) - relativeVelocity).
    LOCAL distanceVector IS (targetPort:NODEPOSITION - dockingPort:NODEPOSITION).
    IF VANG(dockingPort:PORTFACING:VECTOR, distanceVector) < 2 AND abs(distance - distanceVector:MAG) < 0.1 {
      BREAK.
    }
    WAIT 0.
  }

  translate(V(0,0,0)).
}

FUNCTION ensureRange {
  PARAMETER targetPort, dockingPort, distance, speed.

  //if we are already close to inline with target port
  LOCAL LOCK distanceOffset TO targetPort:PORTFACING:VECTOR * distance.
  LOCAL LOCK approachVector TO targetPort:NODEPOSITION - dockingPort:NODEPOSITION + distanceOffset.
  IF VANG(targetPort:PORTFACING:VECTOR,approachVector) < 45 {
    IF ABS(dockingPort:NODEPOSITION:MAG - targetPort:NODEPOSITION:MAG) > distance/2 {
      //we are within a 90 degree range centered on target port and more than
      //half the safe margin distance , so don't mess around with ensuring range.
      RETURN FALSE.
    }
  }

  LOCAL LOCK relativePosition TO SHIP:POSITION - targetPort:SHIP:POSITION.
  LOCAL LOCK departVector TO (relativePosition:normalized * distance) - relativePosition.
  LOCAL LOCK relativeVelocity TO SHIP:VELOCITY:ORBIT - targetPort:SHIP:VELOCITY:ORBIT.
  LOCK STEERING TO -1 * targetPort:PORTFACING:VECTOR.

  UNTIL FALSE {
    translate((departVector:normalized * speed) - relativeVelocity).
    IF departVector:MAG < 0.1 BREAK.
    WAIT 0.01.
  }

  translate(V(0,0,0)).
  RETURN TRUE.
}

FUNCTION moveOrthogonal {
  PARAMETER targetPort, dockingPort, distance, speed.

  dockingPort:CONTROLFROM().

  LOCAL LOCK sideDirection TO targetPort:SHIP:FACING:STARVECTOR.
  IF abs(sideDirection * targetPort:PORTFACING:VECTOR) = 1 {
    LOCK sideDirection TO targetPort:SHIP:FACING:TOPVECTOR.
  }

  LOCAL LOCK distanceOffset TO sideDirection * distance.
  LOCAL LOCK approachVector TO targetPort:NODEPOSITION - dockingPort:NODEPOSITION + distanceOffset.
  LOCAL LOCK relativeVelocity TO SHIP:VELOCITY:ORBIT - targetPort:SHIP:VELOCITY:ORBIT.
  LOCK STEERING TO -1 * targetPort:PORTFACING:VECTOR.

  UNTIL FALSE {
    translate((approachVector:normalized * speed) - relativeVelocity).
    IF approachVector:MAG < 0.1 BREAK.
    WAIT 0.01.
  }

  translate(V(0,0,0)).
}

FUNCTION killRelativeVelocityRCS {
  PARAMETER targetPort.

  LOCAL LOCK relativeVelocity TO SHIP:VELOCITY:ORBIT - targetPort:SHIP:VELOCITY:ORBIT.
  UNTIL relativeVelocity:MAG < 0.1 {
    translate(-relativeVelocity).
  }
  translate(V(0,0,0)).
}

FUNCTION closeDistance {
  PARAMETER closestApproachDistance IS 5000, relativeVelocityLimit IS 10, endDistance IS 500.
  IF (targetBody:DISTANCE < closestApproachDistance) AND
    ((targetBody:VELOCITY:ORBIT - SHIP:VELOCITY:ORBIT) > relativeVelocityLimit) {
    LOCK STEERING TO targetBody:DIRECTION.
    waitForAlignmentTo(targetBody:DIRECTION).
    RCS ON.
    UNTIL (targetBody:DISTANCE) <= endDistance {
      translate(targetBody:DIRECTION).
    }
  } ELSE {
    notifyError("Rendezvous.ks: Too far or too fast from target body.").
  }
}
