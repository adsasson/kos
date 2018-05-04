//BASIC FUNCTIONS
FUNCTION initializeControls {
  PARAMETER currentHeading, currentThrottle.

  LOCK STEERING TO currentHeading.
  LOCK THROTTLE TO currentThrottle.

  pointTo(currentHeading).

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

FUNCTION unmanned {
  IF VESSEL:CREW:EMPTY {
    RETURN TRUE.
  } ELSE {
    RETURN FALSE.
  }
}

FUNCTION setGForceLimit {
  PARAMETER newLimit.
  SET GFORCELIMIT TO newLimit.
  notify("G-FORCE LIMIT SET TO " + GFORCELIMIT).
}

FUNCTION announce {
  PARAMETER message, delay IS 5, style IS 3, size IS 20, color IS YELLOW, echo IS TRUE.
  //style 1: upper left, 2:upper center, 3: lower right, 4:lower center.
  HUDTEXT("kOS: " + message,delay,style,size,color,echo).
}

FUNCTION notify {
  PARAMETER message, verbosity IS defaultsLexicon["kDefaultVerbosity"].

  LOCAL verbosityLexicon TO lexicon("VERBOSE",3,"STANDARD",2,"MINIMUM",1).

  IF verbosityLexicon(verbosity) > 2 {
    announce(message).
  }
  IF verbosityLexicon(verbosity) > 1 {
    print(message).
  }

  log message TO defaultLogFile.
}

FUNCTION countDown {
  PARAMETER defaultCount IS 5.
  announce("Beginning Count Down",1,3,20,YELLOW,FALSE).
  FROM {local x IS defaultCount.} UNTIL x = 0 STEP {SET x TO x - 1.} DO {
    announce("T - " + x, 1, 3, 20, YELLOW, FALSE).
  }
}

FUNCTION pointTo {
  //this function doesn't instruct ship to steer to goal. Rather, it waits until ship is pointing towards goal, or the timeout has been reached.
	PARAMETER goal, useRCS IS FALSE, timeOut IS 60, tol IS 1.

	IF useRCS {
		RCS ON.
	}

	IF goal:ISTYPE("DIRECTION")  {
		SET goal TO goal:VECTOR.
	}

	LOCAL timeStart TO TIME.
	UNTIL ABS(VANG(SHIP:FACING:VECTOR,goal)) < tol {
		IF (TIME - timeStart) > timeOut {
      notify("UNABLE TO ACHEIVE GOAL ORIENTATION IN TIME.","STANDARD").
			break.
		}
		WAIT 0.
	}.

	RETURN TRUE.
}
