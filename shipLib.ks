//SHIP UTILITY LIBRARY

@LAZYGLOBAL OFF.

PRINT "shipLib loaded.".

DECLARE FUNCTION stageLogic {
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

DECLARE FUNCTION engageParachutes {
	PRINT "ENGAGING PARACHUTES".
	WHEN (NOT CHUTESSAFE) THEN {
		CHUTESSAFE ON.
		RETURN (NOT CHUTES).
	}
}

DECLARE FUNCTION engageDeployables {
	PRINT "DEPLOYING".
	deployFairings().
	WAIT 1.
	PANELS ON.
	PRINT "DEPLOYING SOLAR PANELS".
	RADIATORS ON.
	PRINT "DELPOYING RADIATIORS".
	extendAntenna().
}

DECLARE FUNCTION disengageDeployables {
	PRINT "RETRACTING".
	retractAntenna().
	PANELS OFF.
	RADIATORS OFF.
}

DECLARE FUNCTION deployLandingGear {
	GEAR ON.
}

DECLARE FUNCTION retractLandingGear {
	GEAR OFF.
}

DECLARE FUNCTION extendAntenna {
	FOR antenna IN SHIP:MODULESNAMED("ModuleDeployableAntenna") {
		IF antenna:HASEVENT("extend antenna") {
			antenna:DOEVENT("extend antenna").
			PRINT "EXTENDING ANTENNA " + antenna:PART:TITLE.
		}
	}
 }

DECLARE FUNCTION retractAntenna {
	FOR antenna IN SHIP:MODULESNAMED("ModuleDeployableAntenna") {
		IF antenna:HASEVENT("retract antenna") {
			antenna:DOEVENT("retract antenna").
			PRINT "RETRACTING ANTENNA " + antenna:PART:TITLE.
		}
	}
 }

DECLARE FUNCTION deployFairings {
	FOR fairing IN SHIP:MODULESNAMED("ModuleProceduralFairing") {
		IF fairing:HASEVENT("deploy") {
			fairing:DOEVENT("deploy").
			PRINT "DEPLOYING FAIRING " + fairing:PART:TITLE.
		}
	}
}

DECLARE FUNCTION pointTo {
	PARAMETER goal, tol IS 0.15.

	IF goal:ISTYPE("Vector")  {
		SET goal TO goal:DIRECTION.
	}
	WAIT UNTIL (ABS(goal:PITCH - SHIP:FACING:PITCH) < tol) AND (ABS(goal:YAW - SHIP:FACING:YAW) < tol).

	RETURN TRUE.
}
