//HOHMANN TRANSFER
//assumes circular orbits


DECLARE FUNCTION hohmman {
  PARAMETER rStart, rEnd.

  LOCAL cMu TO SHIP:BODY:MU.

  IF (defined rStart) AND (defined rEnd) {

    LOCAL dv1 TO SQRT(cMu/rStart)*(SQRT(2*rEnd/(rStart+rEnd))-1).
    LOCAL dv2 TO SQRT(cMu/rEnd)*(1-SQRT(2*rStart/(rStart+rEnd))).

    LOCAL dvTotal TO dv1 + dv2.

    //Time of flight of transfer
    LOCAL tof TO CONSTANT:PI*SQRT((rStart+rEnd)^3/8*cMu).

    //phase angle (in radians) between start and end
    LOCAL alpha TO CONSTANT:PI*(1-(1/2*SQRT(2))*SQRT((rStart/rEnd+1)^3)).

    LOCAL result TO LEXICON("dv1",dv1,"dv2",dv2,"dvTotal",dvTotal,"tof",tof,
                            "alpha",alpha,"rStart",rStart,"rEnd",rEnd).

    RETURN result.
  } ELSE {
    PRINT "Start and end points undefined".
    RETURN LEXICON().
  }
}

DECLARE FUNCTION hohmannNodes {
  PARAMETER hohmann, nodeTime TO (TIME:SECONDS + 600).

  IF (defined hohmann) {
    //validate
    IF (hohmann:ISTYPE) = "Lexicon") AND (hohmann:HASKEY("dv1")) {
      //assumes lexicon is complete if dv1 present

      //create nodes, assumes raising
      LOCAL nodeExit TO NODE(0,0,0,0).
      LOCAL nodeEntry TO NODE(0,0,0,0).

      SET nodeExit:ETA TO nodeTime.
      SET nodeExit:PROGRADE TO hohmann["dv1"].
      SET nodeEntry:ETA TO (nodeTime + hohmann["tof"]).
      SET nodeEntry:PROGRADE TO -(hohmann["dv2"]).

      //if lowering
      IF (hohmann["rStart"] > hohmann["rEnd"]) {
        SET nodeExit:PROGRADE TO -nodeExit:PROGRADE.
        SET nodeEntry:PROGRADE TO -nodeEntry:PROGRADE.
      }

      ADD nodeExit.
      ADD nodeEntry.
    }
  }
}
