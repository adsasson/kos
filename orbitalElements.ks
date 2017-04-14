//calculate orbital elements from r,v and vice versa
@LAZYGLOBAL OFF.

// h = r x v
//n = K x h (=vector(-hj,hi,0))
//e = 1/mu * ((v^2 - mu/r)r - (r dot v)v)
//p = h^2/mu
//e = e:mag
//i => cos i = hk/h
//omega = long of AN => cos omega = ni/n (nk > 0, omega < 180)
//w = arg of peri => cos w = n dot e /ne (ek > 0, w < 180)
//nu0 = true anomaly at epoch => cos nu = e dot r/er (rdotv > 0, nu < 180)
//u0 = arg of latitude at epoch => cos u = n dot r/nr (rk > 0, u < 180)
//l0 = true Longitude at epoch => omega + w + nu0 = omega + u0
//pi = longitude of periapsis => omega + w


FUNCTION specAngMomentum {
  PARAMETER rParam IS rVec, vParam is vVec.
  //invert because ksp uses left hand system
  RETURN VCRS(vParam, rParam).
}

FUNCTION lineOfNodes {
  PARAMETER hParam IS orbitalElements["h"].
  IF hParam:DEFINED {
    RETURN V(-hParam:Y,hParam:X,0).
  }
}

FUNCTION eccVec {
  PARAMETER rParam IS rVec, vParam IS vVec, muParam IS orbitalElements["mu"].
  LOCAL rTerm TO vParam:SQRMAGNITUDE - muParam/vParam:MAG.
  LOCAL vTerm TO VDOT(rParam,vParam).
  IF muParam <> 0 {
    SET rTerm TO rTerm * (1/muParam).
  }
  SET rTerm TO rTerm * rParam.
  SET vTerm TO vTerm * vParam.
  SET returnEcc TO rParam - vParam.

  RETURN returnEcc.
}

FUNCTION incAngle {
  PARAMETER hParam IS orbitalElements["h"].
  RETURN ARCCOS((hParam:Z)/hParam:MAG).
}

FUNCTION omegaAng {
  PARAMETER nParam IS orbitalElements["n"].
  LOCAL returnOmega TO ARCCOS((nParam:X)/nParam:MAG).
  IF nParam:Y < 0 {
    SET returnOmega TO returnOmega + 180.
  }
  RETURN returnOmega.
}

FUNCTION wAng {
  PARAMETER nParam IS orbitalElements["n"], eParam IS orbitalElements["e"].
  LOCAL cosW TO VDOT(nParam,eParam)/(nParam:MAG * eParam:MAG).
  LOCAL returnW TO ARCCOS(cosW).
  IF eParam:Z < 0 {
    SET returnW TO returnW + 180.
  }
  RETURN returnW.
}

FUNCTION trueAnAtEpoch {
  PARAMETER rParam IS rVec, eParam IS orbitalElements["e"], vParam IS vVec.
  LOCAL cosNu TO VDOT(eParam,rParam)/(eParam:MAG * rParam:MAG).
  LOCAL returnNu TO ARCCOS(cosNu).
  IF VDOT(rParam,vParam) < 0 {
    SET returnNu TO returnNu + 180.
  }
  RETURN returnNu.
}

FUNCTION latAtEpoch {
  PARAMETER rParam IS rVec, nParam IS orbitalElements["n"].
  LOCAL cosU TO VDOT(nParam,rParam)/(nParam:MAG * rParam:MAG).
  LOCAL returnU TO ARCCOS(cosU).
  IF rParam:Z < 0 {
    SET returnU TO returnU + 180.
  }
  RETURN returnU.
}

FUNCTION trueLongAtEpoch {
  LOCAL returnL TO 0.
  IF orbitalElements["omega"] < 0.1 {
    //equatorial
    SET returnL TO orbitalElements["w"] + orbitalElements["nu"].
  } ELSE IF orbitalElements["w"] < 0.1 {
    //circular
    SET returnL TO orbitalElements["omega"] + orbitalElements["u"].
  } ELSE {
    SET returnL TO VANG(V(1,0,0),orbitalElements["nu"]).
  }
  RETURN returnL.
}

FUNCTION longOfPeriapsis {
  LOCAL omega TO orbitalElements["omega"].
  LOCAL w TO orbitalElements["w"].
  IF omega:DEFINED AND w:DEFINED {
    RETURN omega + w.
  }
  RETURN "".
}

FUNCTION constructOrbitalElements {
  orbitalElements:ADD("mu",vessel:BODY:MU).
  orbitalElements:ADD("r",rVec).
  orbitalElements:ADD("v",vVec).
  orbitalElements:ADD("h",specAngMomentum()).
  orbitalElements:ADD("n",lineOfNodes()).
  orbitalElements:ADD("e",eccVec()).
  orbitalElements:ADD("i",incAngle()).
  orbitalElements:ADD("omega",omegaAng()).
  orbitalElements:ADD("w",wAng()).
  orbitalElements:ADD("nu",trueAnAtEpoch()).
  orbitalElements:ADD("u",latAtEpoch()).
  orbitalElements:ADD("l", trueLongAtEpoch()).
  orbitalElements:ADD("pi",longOfPeriapsis()).
}


DECLARE PARAMETER vessel IS SHIP.
GLOBAL orbitalElements TO LEXICON().
LOCAL rVec TO vessel:POSITION.
LOCAL vVec TO vessel:VELOCITY:ORBIT.

constructOrbitalElements().
