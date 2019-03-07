@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

//HOHMANN TRANSFER
//assumes coplanar circular orbits

FUNCTION hohmannStats {
  PARAMETER startAltitude, endAltitude.

  LOCAL cMu TO SHIP:BODY:MU.
  LOCAL startRadius IS SHIP:BODY:RADIUS + startAltitude.
  LOCAL endRadius IS SHIP:BODY:RADIUS + endAltitude.


    LOCAL deltaV1 TO SQRT(cMu/startRadius)*(SQRT(2*endRadius/(startRadius+endRadius))-1).
    LOCAL deltaV2 TO SQRT(cMu/endRadius)*(1-SQRT(2*startRadius/(startRadius+endRadius))).

    LOCAL totalDeltaV TO deltaV1 + deltaV2.

    //Time of flight of transfer
    LOCAL timeOfFlight TO CONSTANT:PI*SQRT((startRadius+endRadius)^3/8*cMu).

    //phase angle (in radians) between vessel and object in target orbit to intercept
    LOCAL phaseAngle TO CONSTANT:PI*(1-(1/2*SQRT(2))*SQRT((startRadius/endRadius+1)^3)).

    LOCAL result TO LEXICON("deltaV1",deltaV1,"deltaV2",deltaV2,
                            "totalDeltaV", totalDeltaV,"timeOfFlight",timeOfFlight,
                            "phaseAngle",phaseAngle,"startRadius",startRadius,
                            "endRadius",endRadius).
    RETURN result.
  }


FUNCTION hohmannNodes {
  PARAMETER hohmmanStatsLex, nodeTime TO (TIME:SECONDS + 600).
    IF (hohmmanStatsLex:ISTYPE) = "Lexicon") AND
      (hohmmanStatsLex:HASKEY("deltaV1")) {
      //assumes lexicon is complete if dv1 present

      //create nodes, assumes raising
      LOCAL nodeExit TO NODE(0,0,0,0).
      LOCAL nodeEntry TO NODE(0,0,0,0).

      SET nodeExit:ETA TO nodeTime.
      SET nodeExit:PROGRADE TO hohmmanStatsLex["deltaV1"].
      SET nodeEntry:ETA TO (nodeTime + hohmmanStatsLex["timeOfFlight"]).
      SET nodeEntry:PROGRADE TO -(hohmmanStatsLex["deltaV2"]).

      //if lowering
      IF (hohmmanStatsLex["startRadius"] > hohmmanStatsLex["endRadius"]) {
        SET nodeExit:PROGRADE TO -nodeExit:PROGRADE.
        SET nodeEntry:PROGRADE TO -nodeEntry:PROGRADE.
      }
      ADD nodeExit.
      ADD nodeEntry.
    } ELSE {
    notifyError("Hohmann transfer parameters are undefined.").
  }
}

FUNCTION createHohmannManeuver {
  PARAMETER startAltitude, endAltitude, startTime.
  LOCAL maneuverLexicon IS hohmannStats(startAltitude,endAltitude).
  //create nodes
  IF verbose PRINT "Creating Hohmann Maneuver Nodes.".
  hohmannNodes(maneuverLexicon,startTime).
}
