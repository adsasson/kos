//SHIP UTILITY LIBRARY
@LAZYGLOBAL OFF.

FUNCTION stageLogic {
	WHEN NOT (SHIP:AVAILABLETHRUST > 0) THEN {
		PRINT "ACTIVATING STAGE " + STAGE:NUMBER.
		STAGE.
		IF STAGE:NUMBER > 0 {
			RETURN TRUE.
		} ELSE {
			RETURN FALSE.
		}
	}
}

FUNCTION engageParachutes {
	PRINT "ENGAGING PARACHUTES".
	WHEN (NOT CHUTESSAFE) THEN {
		CHUTESSAFE ON.
		RETURN (NOT CHUTES).
	}
}

FUNCTION engageDeployables {
	PRINT "DEPLOYING".
	deployFairings().
	WAIT 1.
	PANELS ON.
	PRINT "DEPLOYING SOLAR PANELS".
	RADIATORS ON.
	PRINT "DELPOYING RADIATIORS".
	extendAntenna().
}

FUNCTION disengageDeployables {
	PRINT "RETRACTING".
	retractAntenna().
	PANELS OFF.
	RADIATORS OFF.
}

FUNCTION deployLandingGear {
	GEAR ON.
}

FUNCTION retractLandingGear {
	GEAR OFF.
}

FUNCTION extendAntenna {
	FOR antenna IN SHIP:MODULESNAMED("ModuleDeployableAntenna") {
		IF antenna:HASEVENT("extend antenna") {
			antenna:DOEVENT("extend antenna").
			PRINT "EXTENDING ANTENNA " + antenna:PART:TITLE.
		}
	}
 }

FUNCTION retractAntenna {
	FOR antenna IN SHIP:MODULESNAMED("ModuleDeployableAntenna") {
		IF antenna:HASEVENT("retract antenna") {
			antenna:DOEVENT("retract antenna").
			PRINT "RETRACTING ANTENNA " + antenna:PART:TITLE.
		}
	}
 }

FUNCTION deployFairings {
	FOR fairing IN SHIP:MODULESNAMED("ModuleProceduralFairing") {
		IF fairing:HASEVENT("deploy") {
			fairing:DOEVENT("deploy").
			PRINT "DEPLOYING FAIRING " + fairing:PART:TITLE.
		}
	}
}

FUNCTION pointTo {
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
			break.
		}
		WAIT 0.
	}.

	RETURN TRUE.
}

FUNCTION stageDeltaV {
	PARAMETER stageNumber is STAGE:NUMBER, pressure IS 0.
	LOCAL cEngines TO SHIP:ENGINES.
	LOCAL totalThrust TO 0.
	LOCAL totalISP TO 0.
	LOCAL avgISP TO 0.

	FOR eng IN cEngines {
		IF eng:STAGE = stageNumber {
				SET totalThrust TO totalThrust + eng:AVAILABLETHRUSTAT(pressure).
				SET totalISP TO totalISP + (eng:AVAILABLETHRUSTAT(pressure) /
																		eng:ISPAT(pressure)).
		}
	}

	IF totalISP > 0 {
		SET avgISP TO totalThrust/totalISP.
	}
	RETURN avgISP*9.81*LN(SHIP:MASS/SHIP:DRYMASS).
}

FUNCTION shipDeltaV {
	PARAMETER pressure IS 0.

	LOCAL totalDeltaV TO 0.

	FROM {LOCAL x IS STAGE:NUMBER.} UNTIL x = 0 STEP {SET x TO x-1.} DO {
		SET totalDeltaV TO totalDeltaV + stageDeltaV(x,pressure).
	}
	RETURN totalDeltaV.
}

FUNCTION maxTWR {
	LOCAL gravityAtAltitude TO SHIP:BODY:MU/(SHIP:ALTITUDE + SHIP:BODY:RADIUS)^2.
	//gravity for altitude
	RETURN (SHIP:AVAILABLETHRUST/(SHIP:MASS * gravityAtAltitude)).
}

FUNCTION timeToImpact {
	PARAMETER v0, distance, accel.
	RETURN MAX((-v0 - SQRT(v0^2 - 2*accel*distance))/accel,
						 (-v0 + SQRT(v0^2 - 2*accel*distance))/accel).
}

FUNCTION fuelReserve {
	PARAMETER resourceName, allStages IS FALSE.
	LOCAL fuelRes TO 0.
	LOCAL resList TO LIST().

	IF allStages {
		SET resList TO RESOURCES.
	} ELSE {
		SET resList TO STAGE:RESOURCES.
	}

	FOR res IN resList {
		IF res:NAME = resourceName.
		SET fuelRes TO res.
	}

	IF fuelRes <> 0 RETURN fuelRes:AMOUNT/fuelRes:CAPACITY.
}

FUNCTION engineStats {
		PARAMETER pressure IS 0.
		//for active engines only
		LOCAL totalThrust TO 0.
		LOCAL totalISP TO 0.
		LOCAL avgISP TO 0.
		LOCAL shipEngines TO LIST().
		LIST ENGINES IN shipEngines.
		FOR eng IN shipEngines {
		IF eng:IGNITION {
				SET totalThrust TO totalThrust + eng:AVAILABLETHRUSTAT(pressure).
				SET totalISP TO totalISP + (eng:AVAILABLETHRUSTAT(pressure)/
																		eng:ISPAT(pressure)).
		}
	}
	IF totalISP > 0 {
		SET avgISP TO totalThrust/totalISP.
	}
	RETURN LEXICON("totalISP",totalISP,"totalThrust",totalThrust,"avgISP",avgISP).
}
