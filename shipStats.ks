@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

FUNCTION parseVesselSections {
  tagDecouplers().
  //find section roots
  LOCAL sectionRoots IS LIST().
  //add vessel root
  sectionRoots:ADD(SHIP:ROOTPART).
  //iterate through roots (decouplers)
  FOR decoupler IN SHIP:PARTSTAGGED("decoupler") {sectionRoots:ADD(decoupler).}

  LOCAL sectionPartsLexicon IS LEXICON().
  LOCAL sectionTagNumber IS 0.
  //traverse part tree, adding parts to section, excclude decoupler
  FOR rootPart IN sectionRoots {
    LOCAL sectionParts IS LIST().

    sectionParts:ADD(rootPart).

    // FROM {LOCAL sectionPartIndex IS 0.}
    // UNTIL sectionPartIndex = sectionParts:LENGTH
    // STEP {SET sectionPartIndex TO sectionPartIndex + 1.} DO {
    //   LOCAL sectionPart IS sectionParts[sectionPartIndex].
    //   IF sectionPart:CHILDREN:EMPTY = FALSE {
    //     FOR child IN sectionPart:CHILDREN {
    //       IF child:TAG <> "decoupler" AND child:NAME <> "LaunchClamp1". {
    //         sectionParts:ADD(child).
    //         IF child:TAG <> "decoupler" SET child:TAG TO "section" + sectionTagNumber.
    //       }//endif not decoupler or launch clamp
    //     }//end for child loop
    //   }//endif childen = empty
    // }//end from sectionPartIndex do loop
    //the above should be equivalent to below,
    //but doesn't sem to work correctly, so had to do it manually

    LOCAL i IS 0.
    UNTIL i = sectionParts:length {
      if sectionParts[i]:children:empty = false {
        for child in sectionParts[i]:children {
          if child:tag <> "decoupler" AND child:name <> "LaunchClamp1" {
            sectionParts:add(child).
          }
        }
      }
      set i to i + 1.
    }

    sectionPartsLexicon:ADD("section" + sectionTagNumber,sectionParts).
    SET sectionTagNumber TO sectionTagNumber + 1.

  }//end for rootpart in sectionroots
  RETURN sectionPartsLexicon.
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

FUNCTION createSectionMassLexicon {
  PARAMETER vesselSectionLexicon.
  //result lexicon
  LOCAL sectionMassLexicon IS LEXICON().
  //ship engines
  LOCAL shipEngines IS LIST().
  LIST ENGINES IN shipEngines.

  //iterate over sections
  FOR sectionNumber IN vesselSectionLexicon:KEYS {
    //initialize counters
    LOCAL sectionMass IS 0.
    LOCAL sectionFuelMass IS 0.
    //LOCAL sectionMonopropellantMass IS 0.
    LOCAL sectionFuelFlow IS 0.
    LOCAL sectionEngineList IS LIST().
    LOCAL currentSectionList IS vesselSectionLexicon[sectionNumber].
    LOCAL sectionRoot IS currentSectionList[0].
    //print "currentsectionlist " + currentSectionList.

    //iterate over parts in section list, add up masses
    FOR part IN currentSectionList {
      SET sectionMass TO sectionMass + part:MASS.
      //get section fuel mass
      // IF part:RESOURCES:EMPTY = FALSE {
      //   FOR resource IN part:RESOURCES {
      //     IF resource:NAME <> "monopropellant" {
      //       SET sectionFuelMass TO sectionFuelMass + (part:MASS - part:DRYMASS).
      //     }//endif not mono.. consier else for mono/other resource calcs
      //   }//endfor resource in part
      // }//enif resources empty

      LOCAL rcsFlag IS FALSE.
      IF part:RESOURCES:EMPTY = FALSE {
        FOR resource in part:RESOURCES {
          IF resource:NAME = "monopropellant" SET rcsFlag TO TRUE.
        }
        IF rcsFlag = FALSE SET sectionFuelMass TO sectionFuelMass + part:MASS - part:DRYMASS.
      }

      IF shipEngines:CONTAINS(part) {sectionEngineList:ADD(part).}
    }//endfor part in section
    LOCAL currentSectionLexicon IS LEXICON(
      "sectionRoot",sectionRoot,
      "sectionMass",sectionMass,
      "sectionFuelMass",sectionFuelMass,
      "sectionEngineList",sectionEngineList,
      "sectionFuelFlow",0
    ).
    print "debug section fuel mass: " + sectionFuelMass.

    sectionMassLexicon:ADD(sectionNumber,currentSectionLexicon).
  }//end for sectino in vessel section lexicon
  //print sectionMassLexicon.
  RETURN sectionMassLexicon.
}

FUNCTION createStageStatsLexicon {
  PARAMETER sectionMassLexicon, startingStageNumber IS 0,
            pressure IS 0, includeAllStages IS FALSE.
  LOCAL g0 IS 9.81.
  LOCAL shipEngines IS LIST().
  LIST ENGINES IN shipEngines.
  //result lexicon
  LOCAL stageStatsLexicon IS LEXICON().

  IF startingStageNumber = 0 {
    //get highest stage number
    FOR engine IN shipEngines {
      IF engine:STAGE > startingStageNumber {
        SET startingStageNumber TO engine:STAGE.
      } //endif stage> stagenumber
    }//end for engine loop
  }//endif stage number = 0

  //iterate over stage and create stage data
  FROM {LOCAL stageNumber IS startingStageNumber.}
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

    //if section decoupler activates on the current stage, remove section
    //except first section root which should be ship root part
    FOR sectionKey IN sectionMassLexicon:KEYS {
      IF sectionMassLexicon[sectionKey]["sectionRoot"]:STAGE = stageNumber {
        sectionMassLexicon:REMOVE(sectionKey).
      }
    }//end remove current stage decoupler section

    FOR sectionKey IN sectionMassLexicon:KEYS {
      LOCAL currentSectionLexicon IS sectionMassLexicon[sectionKey].

      LOCAL sectionMass IS currentSectionLexicon["sectionMass"].
      LOCAL sectionFuelMass IS currentSectionLexicon["sectionFuelMass"].
      LOCAL sectionEngineList IS currentSectionLexicon["sectionEngineList"].

      SET currentSectionLexicon["fuelFlow"] TO 0.
      LOCAL sectionBurnTime IS 0.

      //calculate stagte masses
      SET stageMass TO stageMass + sectionMass.

      //calculate stage thrust and feulflow
      IF sectionEngineList:EMPTY = FALSE {
        FOR engine IN sectionEngineList {
          IF engine:STAGE >= stageNumber {
            SET stageThrust TO stageThrust + engine:POSSIBLETHRUSTAT(pressure).
            SET stageFuelFlow TO stageFuelFlow + (engine:POSSIBLETHRUSTAT(pressure)/engine:ISPAT(pressure)).
            SET currentSectionLexicon["fuelFlow"] TO currentSectionLexicon["fuelFlow"] +
                (engine:POSSIBLETHRUSTAT(pressure)/engine:ISPAT(pressure)).

          }//endif engine stage >= stageNumber
        }//end for engine in enginelist
      }//end if sectionEngineList is empty
      IF currentSectionLexicon["fuelFlow"] > 0 {
        //set bburn time
        SET sectionBurnTime TO g0 * sectionFuelMass/currentSectionLexicon["fuelFlow"].
        //if section will stasge next or on last stage
        // PRINT "Section Root Stage:  Stage Number:  Equal?".
        // PRINT currentSectionLexicon["sectionRoot"]:STAGE + " // " + (stageNumber -1 ) + " // "
        // + (currentSectionLexicon["sectionRoot"]:STAGE = stageNumber - 1).
        // IF (currentSectionLexicon["sectionRoot"]:STAGE = stageNumber - 1) {
        //
        //           PRINT "Section Burn Time:  Stage Burn Time: Less than?".
        //           PRINT sectionBurnTime + " // " + stageBurnTime + " // " + (sectionBurnTime<stageBurnTime).
        // }
        print "DEBUG: STAGE: " + stageNumber + " sectionBurnTime: " + sectionBurnTime.

        IF ((currentSectionLexicon["sectionRoot"]:STAGE = stageNumber - 1)
              OR (stageNumber = 0)
              AND (sectionBurnTime < stageBurnTime)) {
                SET stageBurnTime TO sectionBurnTime.
              }//endif next or last stage and sec burn < stage burn

      }//endif section fuel flow > 0

    }//end for section in sectionmass lexicon
    //if no active engines on this stage (haven't changed stageburn time)
    //set burn time to 0
    IF stageBurnTime = 987654321 {SET stageBurnTime TO 0.}

    //calculate additional stage terms
    IF stageBurnTime > 0 {
      LOCAL stageEndMass IS stageMass - stageBurnTime * stageFuelFlow/g0.
      SET stageMinimumAcceleration TO stageThrust/stageMass.
      SET stageMaximumAcceleration TO stageThrust/stageEndMass.
      SET stageISP TO stageThrust/stageFuelFlow.
      SET stageDeltaV TO stageISP * g0 * LN(stageMass/stageEndMass).

    }//endig burntime > 0
    //populate current stage lexicoin
    LOCAL currentStageLexicon IS LEXICON(
      "stageMass",stageMass,
      "stageISP",stageISP,
      "stageThrust",stageThrust,
      "stageMinimumAcceleration",stageMinimumAcceleration,
      "stageMaximumAcceleration",stageMaximumAcceleration,
      "stageDeltaV",stageDeltaV,
      "stageBurnTime",stageBurnTime
    ).

    //add current stage lex to result lexicon
    stageStatsLexicon:ADD(stageNumber,currentStageLexicon).

    //reduce mass of section with active engines

    FOR section IN sectionMassLexicon:VALUES {
      SET section["sectionMass"] TO section["sectionMass"] - (stageBurnTime * section["fuelFlow"]/g0).
      SET section["sectionFuelMass"] TO section["sectionFuelMass"] - (stageBurnTime * section["fuelFlow"]/g0).
    }//end for section reduce fuel mass
  }//end iterate over stage numbers

  //remove empty stages
  IF includeAllStages = FALSE {

    FOR stageKey IN stageStatsLexicon:KEYS {
      IF stageStatsLexicon[stageKey]["stageBurnTime"] = 0 {
        stageStatsLexicon:REMOVE(stageKey).
      }
    }//end for key in stage keys
  }//endif includeAllStages = false
  //PRINT "DEBUG: RESULT: " + stageStatsLexicon.
  RETURN stageStatsLexicon.
}
