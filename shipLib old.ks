//ship lib
PRINT "shipLib loaded.".

DECLARE FUNCTION engageParachutes {
	PRINT "ENGAGING CHUTES".
		WHEN (NOT CHUTESSAFE) THEN {
		CHUTESSAFE ON.
		RETURN (NOT CHUTES).
	}
}

DECLARE FUNCTION engageDeployables {
	PRINT "DEPLOYING".
	PANELS ON.
	RADIATORS ON.
}

DECLARE FUNCTION disengageDeployables {
	PRINT "RETRACTING".
	PANELS OFF.
	RADIATORS OFF.
}

DECLARE FUNCTION deployLandingGear {
	GEAR ON.
}