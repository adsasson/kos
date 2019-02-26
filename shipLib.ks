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

// FUNCTION stageDeltaV {
// 	PARAMETER stageNumber is STAGE:NUMBER, pressure IS 0.
//
//   LOCAL stageEngineStats IS stageEngineStats(stageNumber,pressure).
//
// 	RETURN stageEngineStats["avgISP"]*9.81*LN(SHIP:MASS/SHIP:DRYMASS).
// }

FUNCTION tagDecouplersOLD {
  FOR part IN SHIP:PARTS {
    FOR module IN part:MODULES {
      IF part:GETMODULE(module):NAME = "ModuleDecouple"
      OR part:GETMODULE(module):NAME = "ModuleAnchoredDecouple" {
        SET part:TAG TO "decoupler".
      }
    }
  }
}

FUNCTION tagDecouplers {
  LOCAL decouplers is UNIQUESET().
  FOR part IN SHIP:PARTS {
    LOCAL decoupler IS part:DECOUPLER.
    IF decoupler <> "None" {
      SET decoupler:TAG TO "decoupler".
    }
  }
}

FUNCTION parseShipSections {
  //create roots
  LOCAL sectionRoots IS LIST().
  sectionRoots:ADD(SHIP:ROOTPART).
  FOR decoupler IN SHIP:PARTSTAGGED("decoupler") {
    sectionRoots:ADD(decoupler).
  }
  LOCAL sectionsLexicon IS LEXICON().

  LOCAL sectionTagNumber IS 0.
  //traverse part tree, adding parts to sections, excluding decouplers and LaunchClamp.
  FOR rootPart IN sectionroots {
    LOCAL sectionParts IS LIST().
    sectionParts:ADD(rootPart).
    FROM {LOCAL sectionPartIndex IS 0.}
    UNTIL sectionPartIndex = sectionParts:LENGTH
    STEP {SET sectionPartIndex TO sectionPartIndex + 1.} DO {
      LOCAL sectionPart IS sectionParts[sectionPartIndex].
      IF sectionPart:CHILDREN:EMPTY = FALSE {
        FOR child IN sectionPart:CHILDREN {
          IF child:TAG <> "decoupler" AND child:NAME <> "LaunchClamp1" {
            sectionParts:ADD(child).
            SET child:TAG TO "section" + sectionTagNumber.
          }
        }
      }
    } //end do loop
    sectionsLexicon:ADD("section" + sectionTagNumber,sectionParts).
    SET sectionTagNumber TO sectionTagNumber + 1.
  }
  RETURN sectionsLexicon.
}

FUNCTION sectionFuelStatsLexicon {
  PARAMETER sectionsLexicon.

  //LOCAL sectionMonopropellantMass IS 0.

  LOCAL shipEngines IS LIST().
  LIST ENGINES in shipEngines.
  LOCAL sectionsFuelLexicon IS LEXICON().

  FOR sectionIndex IN sectionsLexicon:KEYS {

    LOCAL sectionMass IS 0.
    LOCAL sectionFuelMass IS 0.
    LOCAL sectionFuelFlow IS 0.
    LOCAL sectionEngineList IS LIST().
    LOCAL sectionList IS sectionsLexicon[sectionIndex].
    LOCAL sectionRoot IS sectionList[0].
    print "debug " + sectionRoot.
    FOR part IN sectionList { //get fuel stats for section
      SET sectionMass TO sectionMass + part:MASS.
      IF shipEngines:CONTAINS(part) {
        sectionEngineList:ADD(part).
      }

      IF part:RESOURCES:EMPTY = FALSE {
        FOR resource IN part:RESOURCES {
          IF resource:NAME <> "monopropellant" {
            SET sectionFuelMass TO sectionFuelMass +
            (part:MASS - part:DRYMASS).
          } //end if mono

        } //end for resources
      } //end if resources != empty

    } //end for part in section list.
    LOCAL sectionFuelLexicon IS LEXICON(
      "sectionRoot",sectionRoot,
      "sectionMass",sectionMass,
      "sectionFuelMass",sectionFuelMass,
      "sectionEngineList",sectionEngineList,
      "sectionFuelFlow",0
    ).
    sectionsFuelLexicon:ADD(sectionIndex,sectionFuelLexicon).
  } //end for index in lexicon

  RETURN sectionsFuelLexicon.
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
            SET sectionFuelMass TO sectionFuelMass +
            (part:MASS - part:DRYMASS).
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

FUNCTION test {
  PARAMETER sectionsFuelLexicon.
  LOCAL shipEngines IS LIST().
  LIST ENGINES IN shipEngines.

  //get first stage number by finding engine with highest stage number
  LOCAL firstStageNumber IS 0.
  FOR engine IN shipEngines {
    IF engine:STAGE > firstStageNumber {
      SET firstStageNumber TO engine:STAGE.
    }
  }
  //iterate over sections to get stage stats 
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
