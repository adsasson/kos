@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).


//===============================================
FUNCTION stageLogic {
  IF STAGE:NUMBER = 0 RETURN.
  WHEN NOT (SHIP:AVAILABLETHRUST > 0) THEN {
    PRINT "ACTIVATING STAGE " + STAGE:NUMBER AT (0,0).
    STAGE.
    IF STAGE:NUMBER > 0 {
      RETURN TRUE.
    } ELSE {
      RETURN FALSE.
    }
  }
}
//==============================================================
FUNCTION performModuleAction {
  PARAMETER moduleName, moduleAction.
  FOR module IN SHIP:MODULESNAMED(moduleName) {
    IF module:HASEVENT(moduleAction) {
      module:DOEVENT(moduleAction).
      IF verbose PRINT "PERFORMING EVENT: " + moduleAction + " WITH PART " + module:PART:TITLE.
    } ELSE {
      PRINT "Error: " + moduleName + " does not have event " + moduleAction.
    }
  }
}

FUNCTION deployFairings {
  performModuleAction("ModuleProceduralFairing","deploy").
}

FUNCTION extendAntenna {
  performModuleAction("ModuleDeployableAntenna","extend antenna").
}

FUNCTION engageDeployables {
  IF verbose PRINT "DEPLOYING".
  deployFairings().
  WAIT 1.
  PANELS ON.
  IF verbose PRINT "DEPLOYING SOLAR PANELS".
  RADIATORS ON.
  IF verbose PRINT "DELPOYING RADIATIORS".
  extendAntenna().
}

FUNCTION engageParachutes {
	PRINT "ENGAGING PARACHUTES".
	WHEN (NOT CHUTESSAFE) THEN {
		CHUTESSAFE ON.
		RETURN (NOT CHUTES).
	}
}
//================================================================


FUNCTION burnTimeTotal {
  PARAMETER burnDV, pressure IS 0.

  LOCAL totalFuelMass IS SHIP:MASS - SHIP:DRYMASS.

  LOCAL g0 TO 9.82.

  LOCAL enginesLex TO engineStats(pressure).
  LOCAL avgISP TO enginesLex["avgISP"].
  LOCAL totalThrust TO enginesLex["totalThrust"].
  LOCAL burn TO 0.

  //check for div by 0..
  IF totalThrust > 0 {
    SET burn TO g0 * SHIP:MASS * avgISP *
    (1 - CONSTANT:E^(-burnDV / (g0 * avgISP))) /totalThrust.
  } ELSE {
    notifyError("AVAILABLE THRUST IS 0.").
  }
  //notify("BURN TIME FOR " + ROUND(burnDV,2) + "m/s: " + ROUND(burn,2) + " s").
  RETURN burn.
}

FUNCTION engineStats {
  PARAMETER pressure IS 0.
  //for active engines only
  LOCAL totalThrust TO 0.
  LOCAL totalISP TO 0.
  LOCAL avgISP TO 0.

  LOCAL shipEngines TO LIST().
  LIST ENGINES IN shipEngines.
  FOR engine IN shipEngines {
    IF engine:IGNITION {
      SET totalThrust TO totalThrust + engine:AVAILABLETHRUSTAT(pressure).
      SET totalISP TO totalISP + (engine:AVAILABLETHRUSTAT(pressure)/engine:ISPAT(pressure)).
    }
  }
  IF totalISP > 0 {
    SET avgISP TO totalThrust/totalISP.
  }
  RETURN LEXICON("totalISP",totalISP,"totalThrust",totalThrust,"avgISP",avgISP).
}

//===================================================================
FUNCTION maxTWR {
  LOCAL gravityAtAltitude TO SHIP:BODY:MU/(SHIP:ALTITUDE + SHIP:BODY:RADIUS)^2.
  //gravity for altitude
  RETURN (SHIP:AVAILABLETHRUST/(SHIP:MASS * gravityAtAltitude)).
}
//burn time.

// Base formulas:
// deltav = integral F / (m0 - consumptionRate * t) dt
// consumptionRate = F / (Isp * g)
// integral deltav = integral F / (m0 - (F * t / g * Isp)) dt

// Integrate:
// integral F / (m0 - (F * t / g * Isp)) dt = -g * Isp * log(g * m0 * Isp - F * t)
// F(t) - F(0) = known ?v
// Expand, simplify, and solve for t
// credit: gisikw, reddit.
