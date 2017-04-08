//landing

DECLARE PARAMETER transitionPoint IS 1000, deorbit IS FALSE.


runoncepath("descent.ks").
IF deorbit {
  doi().
}
descent(transitionPoint).
poweredLanding().
