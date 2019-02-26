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

FUNCTION tagDecouplers {
  FOR part IN SHIP:PARTS {
    FOR module IN part:MODULES {
      IF part:GETMODULE(module):NAME = "ModuleDecouple"
      OR part:GETMODULE(module):NAME = "ModuleAnchoredDecouple" {
        SET part:TAG TO "decoupler".
      }
    }
  }
}

FUNCTION createSectionsLexicon {
  LOCAL shipEngines TO LIST().
  LIST ENGINES IN shipEngines.
  LOCAL sectionRoots IS LIST().
  sectionRoots:ADD(SHIP:ROOTPART).

  FOR decoupler IN SHIP:PARTSTAGGED("decoupler") {
    sectionRoots:ADD(decoupler).
  }
  LOCAL sectionsLexicon IS LEXICON().
  LOCAL sectionTag IS 0.

  FOR sectionRoot IN sectionRoots {
    //enter loop through section roots
    LOCAL sectionMass IS 0.
    LOCAL sectionFuelMass IS 0.
    LOCAL sectionEngineList IS LIST().
    LOCAL fuelFlow IS 0.
    LOCAL sectionParts IS LIST().
    sectionParts:ADD(sectionRoot).

    //add child parts, and tag with sectionNumber
    FROM {LOCAL sectionPartIndex IS 0.}
    UNTIL sectionPartIndex = sectionParts:LENGTH
    STEP {SET sectionPartIndex TO sectionPartIndex + 1.} DO {
      //enter build section parts loop
      IF sectionParts[sectionPartIndex]:CHILDREN:EMPTY = FALSE {
        FOR child IN sectionParts[sectionPartIndex]:CHILDREN {
          IF child:TAG <> "decoupler" AND child:NAME <> "LaunchClamp1" {
            sectionParts:ADD(child).
            SET child:TAG TO "section" + sectionTag.
          }
        } //end add children to section parts loop
      }
    } //end build section parts loop

    FOR part IN sectionParts {
      //enter loop through sectionparts
      LOCAL rcsFlag IS FALSE.
      SET sectionMass TO sectionMass + part:MASS.

      //exclude RCS (maybe not do this?)
      IF part:RESOURCES:EMPTY = FALSE {
        FOR resource IN part:RESOURCES {
          IF resource:NAME = "monopropellant" {
            SET rcsFlag TO TRUE.
          }
          IF rcsFlag = FALSE {
            SET sectionFuelMass TO sectionFuelMass + (part:MASS - part:DRYMASS).
          }
          IF shipEngines:CONTAINS(part) {
            sectionEngineList:ADD(part).
          }
        }

      }
    } //end loop through section parts
    LOCAL section IS LEXICON("sectionRoot",sectionRoot,
                            "sectionMass",sectionMass,
                            "sectionFuelMass",sectionFuelMass,
                            "sectionEngineList",sectionEngineList,
                            "fuelFlow",fuelFlow).
    sectionsLexicon:ADD("section" + sectionTag,section).
    SET sectionTag TO sectionTag + 1.

  } //end loop through section roots
  RETURN sectionsLexicon.
}

FUNCTION createStatsForStage {
  PARAMETER sectionsLexicon, pressure IS 0, includeAllStages IS FALSE.
  LOCAL g0 IS 9.81.
  //get highest stage number
  LOCAL firstStageNumber IS 0.
  LOCAL shipEngines TO LIST().

  LIST ENGINES IN shipEngines.
  LOCAL activeEngines IS LIST().

  LOCAL stageStatLexicon IS LEXICON().
  FOR engine IN shipEngines {
    IF engine:IGNITION = FALSE {
      engine:ACTIVATE.
    } ELSE {
      activeEngines:ADD(engine).
    }
    IF engine:STAGE > firstStageNumber {
      SET firstStageNumber TO engine:STAGE.
    }
  }

  FROM {LOCAL stageNumber IS firstStageNumber.}
  UNTIL stageNumber = -1
  STEP {SET stageNumber TO stageNumber - 1.} DO {
    //start stage loop
    LOCAL stageMass IS 0.
    LOCAL stageThrust IS 0.
    LOCAL stageFuelFlow IS 0.
    LOCAL stageBurnTime IS 987654321. //some random big number

    LOCAL stageMaxAcceleration IS 0.
    LOCAL stageMinimumAcceleration IS 0.
    LOCAL stageISP IS 0.
    LOCAL stageDeltaV IS 0.


    //if decoupler activates on this stage, remove section
    FROM {LOCAL sectionNumber IS sectionsLexicon:LENGTH - 1.}
    UNTIL sectionNumber = 0
    STEP {SET sectionNumber TO sectionNumber - 1.} DO {
      //start decoupler loop
      LOCAL sectionTag IS "section" + sectionNumber.
      IF sectionsLexicon[sectionTag]["sectionRoot"]:STAGE = stageNumber {
        sectionsLexicon:REMOVE(sectionTag).
      }
    } //end remove decoupler loop

    //get base stats for stage
    FOR sectionKey IN sectionsLexicon:KEYS {
      //enter cycle through sections in sectionsLexicon

      LOCAL sectionLex IS sectionsLexicon[sectionKey].
      LOCAL sectionMass IS sectionLex["sectionMass"].
      LOCAL sectionFuelMass IS sectionLex["sectionFuelMass"].
      SET sectionLex["fuelFlow"] TO 0.
      LOCAL sectionBurnTime IS 0.

      SET stageMass TO stageMass + sectionMass.
      IF sectionLex["sectionEngineList"]:EMPTY = FALSE {
        FOR engine IN sectionLex["sectionEngineList"] {
          PRINT "DEBUG ENGINE IGNITION IS " + engine:IGNITION.
          SET stageThrust TO stageThrust + engine:AVAILABLETHRUSTAT(pressure).
          SET stageFuelFlow TO stageFuelFlow + engine:AVAILABLETHRUSTAT(pressure)/engine:ISPAT(pressure).
          SET sectionLex["fuelFlow"] TO sectionLex["fuelFlow"] + engine:AVAILABLETHRUSTAT(pressure)/engine:ISPAT(pressure).
          PRINT "DEBUG STAGE THRUST IS " + stageThrust.
        }
      }

      IF sectionLex["fuelFlow"] > 0 {
        SET sectionBurnTime TO g0 * sectionLex["sectionFuelMass"]/sectionLex["fuelFlow"].
        //if section will stage next or is last stageEndMass
        IF (sectionLex["sectionRoot"]:STAGE = stageNumber - 1 OR
        stageNumber = 0) AND (sectionBurnTime < stageBurnTime) {
          SET stageBurnTime TO sectionBurnTime.
        }
      }
      //calculate additional params
      //if no active engines this stage
      IF stageBurnTime = 987654321 {
        SET stageBurnTime TO 0.
      }

      IF stageBurnTime > 0 {
        PRINT "DEBUG STAGE BURN TIME IS " + stageBurnTime + " STAGE IS " + stageNumber.
        LOCAL stageEndMass IS stageMass - stageBurnTime * stageFuelFlow/g0.
        SET stageMinimumAcceleration TO stageThrust/stageMass.
        SET stageMaxAcceleration TO stageThrust/stageEndMass.
        SET stageISP TO stageThrust/stageFuelFlow.
        SET stageDeltaV TO stageISP * g0 * LN(stageMass/stageEndMass).
        LOCAL consumedFuelMass IS sectionLex["fuelFlow"]/g0 * stageBurnTime.
        SET sectionLex["sectionMass"] TO sectionLex["sectionMass"] - consumedFuelMass.
        SET sectionLex["sectionFuelMass"] TO sectionLex["sectionFuelMass"] - consumedFuelMass.
      }
    }//end cycle through section in sections lexicon




    LOCAL currentStageLex IS LEXICON("stageMass",stageMass,
    "stageISP",stageISP,
    "stageThrust",stageThrust,
    "stageMinimumAcceleration",stageMinimumAcceleration,
    "stageMaxAcceleration",stageMaxAcceleration,
    "stageDeltaV",stageDeltaV,
    "stageBurnTime",stageBurnTime).

    stageStatLexicon:ADD(stageNumber,currentStageLex).

  } //end stage loop
  IF includeAllStages = FALSE {
    FOR stageKey IN stageStatLexicon:KEYS {
      IF stageStatLexicon[stageKey]["stageBurnTime"] = 0 {
        stageStatLexicon:REMOVE(stageKey).
      }
    }
  }

  //shutdown activated engines for stats
  FOR engine IN shipEngines {
    IF activeEngines:CONTAINS(engine) = FALSE {
      engine:SHUTDOWN.
    }
  }
  RETURN stageStatLexicon.
}

FUNCTION stageAnalysis {
  PARAMETER pressure IS 0, includeAllStages IS FALSE.
  tagDecouplers().
  LOCAL sectionsLexicon IS createSectionsLexicon().
  LOCAL stageStats IS createStatsForStage(sectionsLexicon,pressure,includeAllStages).
  RETURN stageStats.
}

FUNCTION stageAnalysisOld {
  //this is inspired by a script called 'stageAnalysis' by brekus from reddit.
  LIST ENGINES in shipEngines.
  LIST PARTS in shipParts.
  LOCAL g0 TO 9.82.

  //label decouplers/separators
  FOR part IN shipParts {
    for module IN part:MODULES {
      if part:GETMOUDLE(module):NAME = "ModuleDecouple" OR
         part:GETMOUDLE(module):NAME = "ModuleAnchorDecouple" {
           SET part:TAG TO "decoupler".
         }
    }
  }

  LOCAL sectionRoots IS LIST().
  sectionRoots:ADD(SHIP:ROOTPART).
  FOR decoupler IN SHIP:PARTSTAGGED("decoupler") {
    sectionRoots:ADD(decoupler).
  }

  LOCAL sections IS LIST().

  FOR sectionRoot IN sectionRoots {
    LOCAL sectionMass IS 0.
    LOCAL sectionFuelMass IS 0.
    LOCAL sectionEngineList IS LIST().
    LOCAL fuelFlow IS 0.

    LOCAL sectionParts IS LIST().

    sectionParts:ADD(sectionRoot).
    FROM {LOCAL sectionPartIndex IS 0.}
      UNTIL sectionPartIndex = sectionParts:LENGTH
      STEP {SET sectionPartIndex TO sectionPartIndex + 1.}
      DO {
        IF sectionParts[sectionPartIndex]:CHILDREN:EMPTY = FALSE {
          FOR child IN sectionParts[sectionPartIndex]:CHILDREN {
            IF child:TAG <> "decoupler" AND
            child:NAME <> "LaunchClamp1" {
              sectionParts:ADD(child).
            }
          }
        }
      }

      FOR part IN sectionParts {
        SET sectionMass TO sectionMass + part:MASS.
        LOCAL rcsFlag IS FALSE.

        IF part:RESOURCES:EMPTY = FALSE {
          FOR resource IN part:RESOURCES {
            IF resource:NAME = "monopropellant" {
              SET rcsFlag TO TRUE.
            }
            IF rcsFlag = FALSE {
              SET sectionFuelMass TO sectionFuelMass + part:MASS - part:DRYMASS.
            }
          }
        }

        IF shipEngines:CONTAINS(parts) {
          sectionEngineList:ADD(part).
        }
      }
      LOCAL section IS LIST(sectionRoot,sectionMass,sectionFuelMass,sectionEngineList,fuelFlow).
      sections:ADD(section).

  }
  LOCAL firstStageNum IS 0.
  FOR engine IN shipEngines {
    IF engine:STAGE > firstStageNum {
      SET firstStageNum TO engine:STAGE.
    }
    FROM {LOCAL i IS 0.} UNTIL i = -1 STEP {SET i TO i - 1.} DO {
      LOCAL stageMass IS 0.
      LOCAL stageThrust IS 0.
      LOCAL stageFuelFlow IS 0.
      LOCAL stageBurnTime IS 987654321.

      LOCAL stageMinA IS 0.
      LOCAL stageMaxA IS 0.
      LOCAL stageISP IS 0.
      LOCAL stageDeltaV IS 0.

      LOCAL currentStage IS LIST().

      FROM {LOCAL k IS sections:LENGTH - 1.} UNTIL k = 0 STEP {SET k TO k - 1.} DO {
        IF sections[k][0]:STAGE = i {
          sections:REMOVE(k).
        }
      }
      FOR section IN sections {
        LOCAL sectionMass IS section[1].
        LOCAL sectionFuelMass IS section[2].
        //reset fuel fuelFlow
        SET section[4] TO 0.
        LOCAL sectionBurnTime IS 0.

        SET stageMass TO stageMass + sectionMass.

        IF section[3]:EMPTY = FALSE {
          FOR engine IN section[3] {
            IF engine:STAGE >= i {
              SET stageThrust TO stageThrust + engine:MAXTHRUST(0).
              SET stageFuelFlow TO stageFuelFlow + engine:MAXTHRUST(0)/engine:VISP.
              SET section[4] TO section[4] + engine:MAXTHRUST(0)/engine:VISP.
            }
          }
        }
        IF section[4] > 0{
          SET sectionBurnTime TO g0 * section[2]/section[4].
          IF section[0]:STAGE = (i - 1) OR i = 0 {
            IF sectionBurnTime < stageBurnTime {
              SET stageBurnTime TO sectionBurnTime.
            }
          }
          IF stageBurnTime = 987654321 {
            SET stageBurnTime TO 0.
          }

          IF stageBurnTime > 0 {
            LOCAL stageEndMass IS stageMass - stageBurnTime * stageFuelFlow/g0.
            SET stageMinA TO stageThrust / stageMass.
            SET stageMaxA TO stageThrust / stageEndMass.
            SET stageISP TO stageThrust / stageFuelFlow.
            SET stageDeltaV TO stageISP  * g0 * LN(stageMass/stageEndMass).
          }
          SET currentStage TO LIST(stageMass,stageISP,stageThrust,stageMinA,stageMaxA,stageDeltaV,stageBurnTime).
          stages:ADD(currentStage).
          FOR section IN sections {
            SET section[1] TO section[1] - stageBurnTime * section[4]/g0.
            SET section[2] TO section[2] - stageBurnTime * section[4]/g0.
          }

        }

      }
    }
  }

}

FUNCTION stageEngineStatsOLD {
  //this doesn't work, because stage doesn't mean what one might think
  //for example, and engine, and the fuel tank attached, might be in different stageEngineStats
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
      SET totalMass TO totalMass + part:MASS.
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

FUNCTION  burnTime {
  PARAMETER burnDV, pressure IS 0.
  //get stage stats LEXICON
  LOCAL stageStats IS stageAnalysis(pressure).
  PRINT "DEBUG STAGE STATS: ".
  PRINT stageStats:DUMP.

  LOCAL currentBurnTime IS 0.
  LOCAL currentBurnDV IS burnDV.
  FROM {LOCAL stageNumber IS STAGE:NUMBER.}
  UNTIL stageNumber = 0
  STEP {SET stageNumber TO stageNumber - 1.} DO {
    SET currentBurnTime TO currentBurnTime + stageStats[stageNumber]["stageBurnTime"].
    SET currentBurnDV TO currentBurnDV - stageStats[stageNumber]["stageDeltaV"].
    IF currentBurnDV <= 0 BREAK.
  }
  //if we have cycled through all stages and burnDV hasn't been reduced to 0, we don't have enough fuel.
  IF currentBurnDV > 0 notifyError("Insufficient deltaV in ship for burn").
  RETURN currentBurnTime.
}

FUNCTION burnTimeOld { //by stage
  PARAMETER burnDV, pressure IS 0.
  LOCAL g0 TO 9.82.

  //starting values for burn time, deltav, and mass counters
  LOCAL shipMass TO SHIP:MASS.
  LOCAL shipDryMass TO SHIP:DRYMASS.
  LOCAL currentBurnTime TO 0.
  LOCAL currentBurnDV TO burnDV.

  //iterate over stages to calculate stage deltaV and burnTime for stage.
  clearscreen.

  FROM {LOCAL stageNumber IS STAGE:NUMBER.}
    UNTIL stageNumber = 0
    STEP {SET stageNumber TO stageNumber -1.}
    //Debug
  DO {
    PRINT "DEBUG: ENTERED STAGE BURN TIME LOOP. STAGE NUMBER IS " + stageNumber AT (0,(TERMINAL:HEIGHT - 1)).
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
    //for the stage, the ship mass will be the ship mass, but the ship dry MASS
    //will be the ship mass less the (stagemass - stagedrymass) because the stage
    //is pushing the whole ship (shipmass), but the available fuel is only
    //the tage fuel. The stage fuel is stageMass - stageDryMass.
    LOCAL stageDeltaV IS stageAvgISP * g0 * LN(shipMass/shipDryMass).
    //LOCAL stageDeltaV IS stageAvgISP * g0 * LN(shipMass/(shipMass - (stageMass - stageDryMass))).


    //increment total burn time by stage burn time
    SET currentBurnTime TO currentBurnTime + stageBurnTime.

    //decrement ship mass by stage mass
    SET shipMass TO shipMass - stageMass.
    SET shipDryMass TO shipDryMass - stageDryMass.

    //decrement deltaV counter.
    SET currentBurnDV TO currentBurnDV - stageDeltaV.

    IF verbose {
      print "Stage DeltaV: " + ROUND(stageDeltaV,2)  AT (0,(1+stageNumber)).
      print "Stage Total Mass: " + ROUND(stageMass,2)  AT (0,(2+stageNumber)).
      print "Stage Dry Mass: " + ROUND(stageDryMass,2) AT (0,(3+stageNumber)).
    }

    //if burnDV counter is >= 0, then we have calculated enough to complete burn
    IF currentBurnDV <= 0 BREAK.
  }
  //if we have looped through all stages, and there still is deltaV left on the burn counter
  //we don't have enough fuel to complete burn
  IF currentBurnDV > 0 notifyError("Insufficient deltaV in ship for burn").

  RETURN currentBurnTime.
}
FUNCTION createStatsForStage {
  PARAMETER sectionsLexicon, pressure IS 0, includeAllStages IS FALSE.
  LOCAL g0 IS 9.81.
  //get highest stage number
  LOCAL firstStageNumber IS 0.
  LOCAL shipEngines TO LIST().

  LIST ENGINES IN shipEngines.
  LOCAL activeEngines IS LIST().

  LOCAL stageStatLexicon IS LEXICON().
  FOR engine IN shipEngines {
    IF engine:IGNITION = FALSE {
      engine:ACTIVATE.
    } ELSE {
      activeEngines:ADD(engine).
    }
    IF engine:STAGE > firstStageNumber {
      SET firstStageNumber TO engine:STAGE.
    }
  }

  FROM {LOCAL stageNumber IS firstStageNumber.}
  UNTIL stageNumber = -1
  STEP {SET stageNumber TO stageNumber - 1.} DO {
    //start stage loop
    LOCAL stageMass IS 0.
    LOCAL stageThrust IS 0.
    LOCAL stageFuelFlow IS 0.
    LOCAL stageBurnTime IS 987654321. //some random big number

    LOCAL stageMaxAcceleration IS 0.
    LOCAL stageMinimumAcceleration IS 0.
    LOCAL stageISP IS 0.
    LOCAL stageDeltaV IS 0.


    //if decoupler activates on this stage, remove section
    FROM {LOCAL sectionNumber IS sectionsLexicon:LENGTH - 1.}
    UNTIL sectionNumber = 0
    STEP {SET sectionNumber TO sectionNumber - 1.} DO {
      //start decoupler loop
      LOCAL sectionTag IS "section" + sectionNumber.
      IF sectionsLexicon[sectionTag]["sectionRoot"]:STAGE = stageNumber {
        sectionsLexicon:REMOVE(sectionTag).
      }
    } //end remove decoupler loop

    //get base stats for stage
    FOR sectionKey IN sectionsLexicon:KEYS {
      //enter cycle through sections in sectionsLexicon

      LOCAL sectionLex IS sectionsLexicon[sectionKey].
      LOCAL sectionMass IS sectionLex["sectionMass"].
      LOCAL sectionFuelMass IS sectionLex["sectionFuelMass"].
      SET sectionLex["fuelFlow"] TO 0.
      LOCAL sectionBurnTime IS 0.

      SET stageMass TO stageMass + sectionMass.
      IF sectionLex["sectionEngineList"]:EMPTY = FALSE {
        FOR engine IN sectionLex["sectionEngineList"] {
          PRINT "DEBUG ENGINE IGNITION IS " + engine:IGNITION.
          SET stageThrust TO stageThrust + engine:AVAILABLETHRUSTAT(pressure).
          SET stageFuelFlow TO stageFuelFlow + engine:AVAILABLETHRUSTAT(pressure)/engine:ISPAT(pressure).
          SET sectionLex["fuelFlow"] TO sectionLex["fuelFlow"] + engine:AVAILABLETHRUSTAT(pressure)/engine:ISPAT(pressure).
          PRINT "DEBUG STAGE THRUST IS " + stageThrust.
        }
      }

      IF sectionLex["fuelFlow"] > 0 {
        SET sectionBurnTime TO g0 * sectionLex["sectionFuelMass"]/sectionLex["fuelFlow"].
        //if section will stage next or is last stageEndMass
        IF (sectionLex["sectionRoot"]:STAGE = stageNumber - 1 OR
        stageNumber = 0) AND (sectionBurnTime < stageBurnTime) {
          SET stageBurnTime TO sectionBurnTime.
        }
      }
      //calculate additional params
      //if no active engines this stage
      IF stageBurnTime = 987654321 {
        SET stageBurnTime TO 0.
      }

      IF stageBurnTime > 0 {
        PRINT "DEBUG STAGE BURN TIME IS " + stageBurnTime + " STAGE IS " + stageNumber.
        LOCAL stageEndMass IS stageMass - stageBurnTime * stageFuelFlow/g0.
        SET stageMinimumAcceleration TO stageThrust/stageMass.
        SET stageMaxAcceleration TO stageThrust/stageEndMass.
        SET stageISP TO stageThrust/stageFuelFlow.
        SET stageDeltaV TO stageISP * g0 * LN(stageMass/stageEndMass).
        LOCAL consumedFuelMass IS sectionLex["fuelFlow"]/g0 * stageBurnTime.
        SET sectionLex["sectionMass"] TO sectionLex["sectionMass"] - consumedFuelMass.
        SET sectionLex["sectionFuelMass"] TO sectionLex["sectionFuelMass"] - consumedFuelMass.
      }
    }//end cycle through section in sections lexicon




    LOCAL currentStageLex IS LEXICON("stageMass",stageMass,
    "stageISP",stageISP,
    "stageThrust",stageThrust,
    "stageMinimumAcceleration",stageMinimumAcceleration,
    "stageMaxAcceleration",stageMaxAcceleration,
    "stageDeltaV",stageDeltaV,
    "stageBurnTime",stageBurnTime).

    stageStatLexicon:ADD(stageNumber,currentStageLex).

  } //end stage loop
  IF includeAllStages = FALSE {
    FOR stageKey IN stageStatLexicon:KEYS {
      IF stageStatLexicon[stageKey]["stageBurnTime"] = 0 {
        stageStatLexicon:REMOVE(stageKey).
      }
    }
  }

  //shutdown activated engines for stats
  FOR engine IN shipEngines {
    IF activeEngines:CONTAINS(engine) = FALSE {
      engine:SHUTDOWN.
    }
  }
  RETURN stageStatLexicon.
}
