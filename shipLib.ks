@LAZYGLOBAL OFF.


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
//================================================================
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

// FUNCTION stageDeltaV {
// 	PARAMETER stageNumber is STAGE:NUMBER, pressure IS 0.
//
//   LOCAL stageEngineStats IS stageEngineStats(stageNumber,pressure).
//
// 	RETURN stageEngineStats["avgISP"]*9.81*LN(SHIP:MASS/SHIP:DRYMASS).
// }

FUNCTION stageEngineStats {
  PARAMETER stageNumber is STAGE:NUMBER, pressure IS 0.
  LOCAL shipEngines TO LIST().
  LIST ENGINES IN shipEngines.
  LOCAL totalThrust TO 0.
  LOCAL totalISP TO 0.
  LOCAL avgISP TO 0.

  FOR engine IN shipEngines {
    IF engine:STAGE = stageNumber {
      SET totalThrust TO totalThrust + engine:AVAILABLETHRUSTAT(pressure).
      SET totalISP TO totalISP + (engine:AVAILABLETHRUSTAT(pressure) /
      engine:ISPAT(pressure)).
    }
  }

  IF totalISP > 0 {
    SET avgISP TO totalThrust/totalISP.
  }
  RETURN LEXICON("stageTotalISP",totalISP,"stageTotalThrust",totalThrust,"stageAvgISP",avgISP,"stage",stageNumber).
}

FUNCTION stageMassStats {
  PARAMETER stageNumber IS STAGE:NUMBER.
  LOCAL totalMass TO 0.
  LOCAL totalDryMass TO 0.
    LOCAL shipParts TO LIST().
  LIST PARTS IN shipParts.

  FOR part IN shipParts {
    IF part:STAGE = stageNumber {
      SET totalMass TO totalMass + part:WETMASS.
      SET totalDryMass TO totalDryMass + part:DRYMASS.
    }
  }
  RETURN LEXICON("stageMass",totalMass,"stageDryMass",totalDryMass,"stage",stageNumber).
}

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

FUNCTION burnTime { //by stage
  PARAMETER burnDV, pressure IS 0.
  LOCAL g0 TO 9.82.

  //starting values for burn time, deltav, and mass counters
  LOCAL shipMass TO SHIP:MASS.
  LOCAL shipDryMass TO SHIP:DRYMASS.
  LOCAL currentBurnTime TO 0.
  LOCAL currentBurnDV TO burnDV.

  //iterate over stages to calculate stage deltaV and burnTime for stage.
  FROM {LOCAL stageNumber IS STAGE:NUMBER.}
    UNTIL STAGE = 0
    STEP {SET stageNumber TO stageNumber -1.}
  DO {
    LOCAL indexedStageEngineStats TO stageEngineStats(stageNumber,pressure).
    LOCAL indexedStageMass TO stageMassStats(stageNumber).

    LOCAL stageTotalThrust IS indexedStageEngineStats["stageTotalThrust"].
    LOCAL stageAvgISP IS indexedStageEngineStats["stageAvgISP"].
    LOCAL stageDryMass IS indexedStageMass["stageDryMass"].
    LOCAL stageMass IS indexedStageMass["stageMass"].
    LOCAL stageBurnTime IS 0.

    //get burn time for Stage for remaining deltaV
    IF stageTotalThrust > 0 {
      SET stageBurnTime TO g0 * shipMass * stageAvgISP *
      (1 - CONSTANT:E^(-currentBurnDV / (g0 * stageAvgISP)))/stageTotalThrust.
    }

    //get stage delta V
    LOCAL stageDeltaV IS stageAvgISP * g0 * LN(shipMass/shipDryMass).


    //increment total burn time by stage burn time
    SET currentBurnTime TO currentBurnTime + stageBurnTime.

    //decrement ship mass by stage mass
    SET shipMass TO shipMass - stageMass.
    SET shipDryMass TO shipDryMass - stageDryMass.

    //decrement deltaV counter.
    SET currentBurnDV TO currentBurnDV - stageDeltaV.

    IF verbose {
      print "Stage DeltaV: " + ROUND(stageDeltaV,2) + " " +
            "Stage Total Mass: " + ROUND(stageMass,2) + " " +
            "Stage Dry Mass: " + ROUND(stageDryMass,2) AT (0,(1+stageNumber)).
    }

    //if burnDV counter is >= 0, then we have calculated enough to complete burn
    IF currentBurnDV <= 0 BREAK.
  }
  //if we have looped through all stages, and there still is deltaV left on the burn counter
  //we don't have enough fuel to complete burn
  IF currentBurnDV > 0 notifyError("Insufficient deltaV in ship for burn").

  RETURN currentBurnTime.
}
