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

FUNCTION getFuelStatsForSections {
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

FUNCTION getShipStatsForStages {
  PARAMETER sectionsFuelLexicon, pressure IS 0, includeAllStages IS FALSE.
  LOCAL g0 IS 9.81.
  LOCAL shipEngines IS LIST().
  LIST ENGINES IN shipEngines.
  LOCAL stagesLexicon IS LEXICON().

  //get first stage number by finding engine with highest stage number
  LOCAL firstStageNumber IS 0.
  FOR engine IN shipEngines {
    IF engine:STAGE > firstStageNumber {
      SET firstStageNumber TO engine:STAGE.
    }
  }
  //iterate over sections to get stage stats

  FROM {LOCAL stageNumber IS firstStageNumber.}
  UNTIL stageNumber = -1
  STEP {SET stageNumber TO stageNumber - 1.} DO {
    LOCAL stageMass IS 0.
    LOCAL stageThrust IS 0.
    LOCAL stageFuelFlow IS 0.
    LOCAL stageBurnTime IS 987654321.

    LOCAL stageMaximumAcceleration IS 0.
    LOCAL stageMinimumAcceleration IS 0.
    LOCAL stageISP IS 0.
    LOCAL stageDeltaV IS 0.

    //loop through sections, if section rootpart activates on this stage, remove sectionNumber
    FOR sectionKey IN sectionsFuelLexicon:KEYS {
      IF sectionsFuelLexicon[sectionKey]["sectionRoot"]:STAGE = stageNumber {
        sectionsFuelLexicon:REMOVE(sectionKey).
      }
    }//end loop through sections for tagDecouplers

    //loop through (again? can this be done in same loop?) to calculate STATS
    FOR sectionKey IN sectionsFuelLexicon:KEYS {
      LOCAL sectionLexicon IS sectionsFuelLexicon[sectionKey].
      LOCAL sectionMass IS sectionLexicon["sectionMass"].
      LOCAL sectionFuelMass IS sectionLexicon["sectionFuelMass"].
      SET sectionLexicon["fuelFlow"] TO 0.
      LOCAL sectionBurnTime IS 0.
      LOCAL sectionEngineList IS sectionLexicon["sectionEngineList"].

      SET stageMass TO stageMass + sectionMass.
      IF sectionEngineList:EMPTY = FALSE {
        FOR engine IN sectionEngineList {
          SET stageThrust TO stageThrust + engine:POSSIBLETHRUSTAT(pressure).
          SET stageFuelFlow TO stageFuelFlow + engine:POSSIBLETHRUSTAT(pressure)/engine:ISPAT(pressure).
          SET sectionLexicon["fuelFlow"] TO sectionLexicon["fuelFlow"] + engine:POSSIBLETHRUSTAT(pressure)/engine:ISPAT(pressure).
        } //end loop through section engines
      }//end if sectionEngineList is empty

        // PRINT "DEBUG: STAGE // THRUST // FUEL FLOW: ".
        // PRINT stageNumber + " // " + stageThrust + " // " + stageFuelFlow.

      IF sectionLexicon["fuelFlow"] > 0 {
        SET sectionBurnTime TO g0 * sectionFuelMass/sectionLexicon["fuelFlow"].
        //if section will stage next or is last stage
        LOCAL sectionRootStage IS (sectionLexicon["sectionRoot"]:STAGE).
        LOCAL nextStageNumber IS stageNumber - 1.
        IF sectionRootStage = 4 PRINT "DEBUG sectionRootStage: = 4".
        IF nextStageNumber = 4 PRINT "DEBUG nextStageNumber: = 4".
        IF 4=4 PRINT "DEBUG 4=4".
        IF ((sectionRootStage = nextStageNumber) OR stageNumber = 0) {
          PRINT "DEBUG sectionRootStage = nextStageNumber".
          PRINT sectionBurnTime + " // " + stageBurnTime.
        }

        IF ((sectionRootStage = nextStageNumber) OR stageNumber = 0) AND
        (sectionBurnTime < stageBurnTime) {
          PRINT "DEBUG ENTERED IF".
          SET stageBurnTime TO sectionBurnTime.
        } //end if last/next section

      } //end if fuelflow > 0

    IF stageBurnTime = 987654321 { //this seems unnecessary? couldn't this have beein set to 0 at init?
      SET stageBurnTime TO 0.
    }//end if no engines on this stageEndMass

    IF stageBurnTime > 0 {
      LOCAL stageEndMass IS stageMass - stageBurnTime * stageFuelFlow/g0.
      SET stageMinimumAcceleration TO stageThrust/stageMass.
      SET stageMaximumAcceleration TO stageThrust/stageEndMass.
      SET stageISP TO stageThrust/stageFuelFlow.
      SET stageDeltaV TO stageISP * g0 * LN(stageMass/stageEndMass).
      LOCAL consumedFuelMass IS sectionLexicon["fuelFlow"]/g0 * stageBurnTime.
      SET sectionLexicon["sectionMass"] TO sectionLexicon["sectionMass"] - consumedFuelMass.
      SET sectionLexicon["sectionFuelMass"] TO sectionLexicon["sectionFuelMass"] - consumedFuelMass.
    }//endif burntime > 0

  }//end loop through sections for stats

  LOCAL stageLexicon IS LEXICON("stageMass",stageMass,
  "stageISP",stageISP,
  "stageThrust",stageThrust,
  "stageMinimumAcceleration",stageMinimumAcceleration,
  "stageMaximumAcceleration",stageMaximumAcceleration,
  "stageDeltaV",stageDeltaV,
  "stageBurnTime",stageBurnTime).

  // PRINT "DEBUG stageLexicon: ".
  // PRINT stageLexicon.
  stagesLexicon:ADD(stageNumber,stageLexicon).
  } //end stage loop
  IF includeAllStages = FALSE {
    FOR stageKey IN stagesLexicon:KEYS {
      IF stagesLexicon[stageKey]["stageBurnTime"] = 0 {
        stagesLexicon:REMOVE(stageKey).
      } //endif stage burn time is 0
    }//end for stage loop
  }//endif includeAllStages
  RETURN stagesLexicon.
} //end function

FUNCTION stageAnalysis {//fix this
  PARAMETER pressure IS 0, includeAllStages IS FALSE.
  tagDecouplers().
  LOCAL shipSections IS parseShipSections().
  LOCAL fuelStats IS getFuelStatsForSections(shipSections).
  LOCAL shipStats IS getShipStatsForStages(fuelStats,pressure,includeAllStages).
  RETURN shipStats.
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



FUNCTION test {
  PARAMETER sectionsFuelLexicon, startingStageNumber IS 0, pressure IS 0, includeAllStages IS FALSE.

  //constants
  LOCAL g0 IS 9.81.
  //return value
  LOCAL stagesLexicon IS LEXICON().
  IF startingStageNumber = 0 {
    //get highest stage
    LOCAL shipEngines IS LIST().
    LIST ENGINES IN shipEngines.
    FOR engine IN shipEngines {
      IF engine:STAGE > startingStageNumber {
        SET startingStageNumber TO engine:STAGE.
      }
    }
  }

  //iterate over stages
  FROM {LOCAL stageNumber IS startingStageNumber.}
  UNTIL stageNumber = -1
  STEP {SET stageNumber TO stageNumber -1.} DO {
    //initialize variables for stage stats
    LOCAL stageMass IS 0. LOCAL stageThrust IS 0.
    LOCAL stageFuelFlow IS 0. LOCAL stageBurnTime IS 987654321.
    PRINT "DEBUG: Stage: " + stageNumber + "stageBurnTime: " + stageBurnTime.

    LOCAL stageMaximumAcceleration IS 0. LOCAL stageMinimumAcceleration IS 0.
    LOCAL stageISP IS 0. LOCAL stageDeltaV IS 0.

    //remove sections that activate on current stage
    FOR sectionKey IN sectionsFuelLexicon:KEYS {
      IF sectionsFuelLexicon[sectionKey]["sectionRoot"]:STAGE = stageNumber {
        PRINT "DEBUG Removing Section: " + sectionsFuelLexicon[sectionKey].
        sectionsFuelLexicon:REMOVE(sectionKey).
      }
    }

    //Loop through sections. accumulate mass values
    FOR sectionKey IN sectionsFuelLexicon:KEYS {
      //initialize counter variables
      LOCAL currentSectionLexicon IS sectionsFuelLexicon[sectionKey].
      LOCAL sectionMass IS currentSectionLexicon["sectionMass"].
      LOCAL sectionFuelMass IS currentSectionLexicon["sectionFuelMass"].
      LOCAL sectionEngineList IS currentSectionLexicon["sectionEngineList"].
      LOCAL sectionBurnTime IS 0.
      SET currentSectionLexicon["fuelFlow"] TO 0.

      //increment stage mass by section mass of remaining sections
      SET stageMass TO stageMass + sectionMass.

      //loop through engines in section, incrmeent stage fuel and thrust
      IF sectionEngineList:EMPTY = FALSE {
        FOR engine IN sectionEngineList {
          SET stageThrust TO stageThrust + engine:POSSIBLETHRUSTAT(pressure).
          SET stageFuelFlow TO stageFuelFlow + engine:POSSIBLETHRUSTAT(pressure)/engine:ISPAT(pressure).
          SET currentSectionLexicon["fuelFlow"] TO currentSectionLexicon["fuelFlow"] + engine:POSSIBLETHRUSTAT(pressure)/engine:ISPAT(pressure).
        }
      }

      //if there is fuel flow in this section
      IF currentSectionLexicon["fuelFlow"] > 0 {
        SET sectionBurnTime TO g0 * sectionFuelMass/currentSectionLexicon["fuelFlow"].

        IF (currentSectionLexicon["sectionRoot"]:STAGE = (stageNumber - 1)
            OR (stageNumber = 0)
            AND (sectionBurnTime < stageBurnTime)) {
              PRINT "DEBUG ENTERED IF ".
              SET stageBurnTime TO sectionBurnTime.
            }
      }
      PRINT "DEBUG stageBurnTime: " + stageBurnTime.
      //if we got here and didn't change stageburn time there must not have been engines
      //on this stage
      IF stageBurnTime = 987654321 SET stageBurnTime TO 0.

      IF stageBurnTime > 0 {
        LOCAL stageEndMass IS stageMass - stageBurnTime * stageFuelFlow/g0.
        SET stageMinimumAcceleration TO stageThrust/stageMass.
        SET stageMaximumAcceleration TO stageThrust/stageEndMass.
        SET stageISP TO stageThrust/stageFuelFlow.
        SET stageDeltaV TO stageISP * g0 * LN(stageMass/stageEndMass).
        LOCAL consumedFuelMass IS sectionLexicon["fuelFlow"]/g0 * stageBurnTime.
        SET currentSectionLexicon["sectionMass"] TO currentSectionLexicon["sectionMass"] - consumedFuelMass.
        SET currentSectionLexicon["sectionFuelMass"] TO currentSectionLexicon["sectionFuelMass"] - consumedFuelMass.
      }//endif burntime > 0

    }
    LOCAL currentStageLexicon IS LEXICON("stageMass",stageMass,
    "stageISP",stageISP,
    "stageThrust",stageThrust,
    "stageMinimumAcceleration",stageMinimumAcceleration,
    "stageMaximumAcceleration",stageMaximumAcceleration,
    "stageDeltaV",stageDeltaV,
    "stageBurnTime",stageBurnTime).

    stagesLexicon:ADD(stageNumber,currentStageLexicon).

  }
  IF includeAllStages = FALSE {
    FOR stageKey IN stagesLexicon:KEYS {
      IF stagesLexicon[stageKey]["stageBurnTime"] = 0 {
        stagesLexicon:REMOVE(stageKey).
      } //endif stage burn time is 0
    }//end for stage loop
  }//endif includeAllStages

  RETURN stagesLexicon.
}
