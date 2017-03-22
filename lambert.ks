//LAMBERT PROBLEM
//deltaPhi = 2PI(Thohmann/Touter)
//phiDot = nInner - nOuter

//STEP 1: DETERMINE ORBIT OF TARGET (Lambert) given r(t1) and r(t2)
//STEP 2: DETERMINE DESIRED POSITION OF TARGET
//STEP 3: FIND INTERCEPT TRAJECTORY
//STEP 4: CALCULATE DELTAV

//after IZZO(2014)"Revisiting Lambert's Problem",CelestMechDynAstr
//see also https://github.com/esa/pykep
runoncepath("mathLib.ks").
//LOCAL lambda TO "".
LOCAL v1 TO V(0,0,0).
LOCAL v2 TO V(0,0,0).

LOCAL LambertLexicon TO LEXICON("r1","","r2","","tof","","mu","","x","",
                                "iter","","nMax","","lambda","").

IF HASTARGET {
  SET LambertLexicon["r1"] TO SHIP:POSITION.
  SET LambertLexicon["r2"] TO TARGET:POSITION.
  SET LambertLexicon["mu"] TO SHIP:BODY:MU.
}

DECLARE FUNCTION lambertProblem {
  PARAMETER inputLexicon, tof, retroFlag IS FALSE, multiRev IS 5.
  SET LambertLexicon["tof"] TO tof.

  IF tof <= 0 {
    PRINT "ToF is negative.".
  }

  //calc lambda and tau
  LOCAL chord TO TARGET:DISTANCE.
  LOCAL r1Mag TO LambertLexicon["r1"]:MAG.
  LOCAL r2Mag TO LambertLexicon["r2"]:MAG.
  LOCAL semiPerimeter TO (chord + r1Mag + r2Mag)/2.

  LOCAL r1Norm TO LambertLexicon["r1"]:NORMALIZED.
  LOCAL r2Norm TO LambertLexicon["r2"]:NORMALIZED.

  LOCAL angMomentum TO VCRS(r1Norm,r2Norm).
  SET angMomentum TO angMomentum:NORMALIZED.

  IF angMomentum:Z = 0 {
    "No Z component to Angular Momentum. Unable to determine direction of rotation.".
  }

  SET LambertLexicon["lambda"] TO (1-chord/semiPerimeter).

  LOCAL t1, t2.

  IF angMomentum:Z < 0 {
    SET LambertLexicon["lambda"] TO -(1-chord/semiPerimeter).
    SET t1 TO VCRS(r1Norm,angMomentum).
    SET t2 TO VCRS(r2Norm,angMomentum).
  } ELSE {
    SET t1 TO VCRS(angMomentum,r1Norm).
    SET t2 TO VCRS(angMomentum,r2Norm).
  }
  SET t1 TO t1:NORMALIZED.
  SET t2 TO t2:NORMALIZED.

  IF retroFlag {
    LOCAL oldLambda TO LambertLexicon["lambda"].
    SET LambertLexicon["lambda"] TO -oldLambda.
    SET t1:X TO -t1:X.
    SET t1:Y TO -t1:Y.
    SET t1:Z TO -t1:Z.

    SET t2:X TO -t2:X.
    SET t2:Y TO -t2:Y.
    SET t2:Z TO -t2:Z.
  }

  GLOBAL cLambda TO LambertLexicon["lambda"].
  LOCAL tau TO (SQRT(2*(LambertLexicon["mu"])/semiPerimeter^3))*(LambertLexicon["tof"]).

  //find x
  LOCAL cNMax TO FLOOR(tau/CONSTANT:PI).
  SET LambertLexicon["nMax"] TO cNMax.
  LOCAL tau00 TO ARCCOS(cLambda) + cLambda*(SQRT(1-cLambda^2)).
  LOCAL tau0 TO tau00 + cNMax*CONSTANT:PI.
  LOCAL tau1 TO 2/3 * (1 - lambda^3).

  LOCAL dTLexicon TO LEXICON("dT",0,"ddT",0,"dddT",0).

  IF cNMax > 0 {
    IF (tau < tau0) {
      LOCAL it TO 0.
      LOCAL err TO 1.
      LOCAL tauMin TO tau0.
      LOCAL xOld TO 0.
      LOCAL xNew TO 0.

      UNTIL (err < 1e-13) OR (it > 12) {
        //dTdX
        dTdx(dTLexicon,xOld,tauMin).
        LOCAL cDT TO dTLexicon["dT"].
        LOCAL cDDT TO dTLexicon["ddT"].
        LOCAL cDDDT TO dTLexicon["dddT"].

         IF NOT (cDT = 0) {
           SET xNew TO xOld - cdT*cddT/(cddt^2 - cdT*cdddT/2).
         }
         SET err TO ABS(xOld-xNew).
         SET tauMin TO x2ToF(xNew,cNMax).
         SET xOld TO xNew.
         SET it TO it + 1.
      }//end UNTIL

      IF (tauMin > tau) {
        SET LambertLexicon["nMax"] TO cNMax - 1.
      }
    }
  }

  SET LambertLexicon["nMax"] TO MIN(mulitRev,LambertLexicon["nMax"]).
  SET cNMax TO LambertLexicon["nMax"].

  LOCAL v1List TO LIST().
  LOCAL v2List TO LIST().
  LOCAL iterList TO LIST().
  LOCAL xList TO LIST().

  FROM {LOCAL i IS 1} UNTIL i < (cNMax*2+1) STEP {SET i TO i+1} DO {
    v1List:ADD("").
    v2List:ADD("").
    iterList:ADD("").
    xList:ADD("").
  }

  //find x,y
  IF tau >= tau00 {
    SET xList[0] TO -(tau-tau00)/(tau - tau00 + 4).
  } ELSE IF tau <= tau1 {
    SET xList[0] TO tau1*(tau1-tau)/(2/5*(1-cLambda^5)*tau) + 1.
  } ELSE {
    SET xList[0] TO ((tau/tau00)^0.69)/LOG(tau1/tau00)) - 1.
  }
  LOCAL householderList TO householder(tau,xList[0],0,1e-15,15).
  SET xList[0] TO householderList[0].
  SET LambertLexicon["iter"] TO householderList[1].

  LOCAL tmp TO "".
  FROM {LOCAL i is 1} UNTIL i < cNMax STEP {SET i TO i+1} DO {
    SET tmp TO ((i*CONSTANT:PI^2)/(8*tau))^(2/3).
    SET xList[(2*i-1)] TO ((tmp-1)/(tmp+1)).
    SET householderList TO (householder(tau,xList[(2*i-1)],i,1e-8,15))
    SET xList[(2*i-1)] TO householderList[0].
    SET iterList[(2*i-1)] TO householderList[1].

    SET tmp TO ((8*tau)/(i*CONSTANT:PI))^(2/3).
    SET householderList TO (householder(tau,xList[(2*i)],i,1e-8,15))
    SET xList[(2*i)] TO householderList[0].
    SET iterList[(2*i)] TO householderList[1].
  }

  //get v for each x
  LOCAL gamma TO SQRT(cMu*semiPerimeter/2).
  LOCAL rho TO (r1Mag - r2Mag)/chord.
  LOCAL sigma TO SQRT(1-rho^2).
  LOCAL vR1 TO 0.
  LOCAL vR2 TO 0.
  LOCAL vT1 TO 0.
  LOCAL vT2 TO 0.
  LOCAL y TO 0.

  FOR xVal IN xList {
    SET y TO SQRT(1 - cLambda^2*xVal^2).
    SET vR1 = gamma * ((cLambda*y - xVal) - rho*(cLambda*y*xVal))/r1Mag.
    SET vR2 = -gamma * ((cLambda*y - xVal) + rho*(cLambda*y*xVal))/r2Mag.
    LOCAL vt TO gamma*sigma*(y*cLambda*xVal).
    SET vT1 TO vt/r1Mag.
    SET vT2 TO vt/r2Mag.
    LOCAL vec1 TO vR1*r1Norm + vT1*t1Norm.
    LOCAL vec2 TO vR2*r2Norm + vT2*t2Norm.
    v1List:ADD(vec1).
    v2List:ADD(vec2).
  }
  LambertLexicon:ADD("v1List",v1List).
  LambertLexicon:ADD("v2List",v2List).

  return LambertLexicon.
}


DECLARE FUNCTION dTdX {
  PARAMETER inputLexicon, x, tau.

  LOCAL umx2 TO 1 - x^2.
  LOCAL y TO SQRT(1 - cLambda^2*umx2).

  LOCAL cDT TO 1/umx2 * (3*tau*x - 2 + 2*cLambda^3*x/y).
  LOCAL cDDT TO 1/umx2 * (3*tau + 5*x*dT + 2*(1-cLambda^2)*cLambda^3/y^3).
  LOCAL cDDDT TO 1/umx2 * (7*x*ddT + 8*dT - 6*(1-lambcLambdada^2)*cLambda^2*cLambda^3*x/y^3/y^2).

  SET inputLexicon["dT"] TO cDT.
  SET inputLexicon["ddT"] TO cDDT.
  SET inputLexicon["dddT"] TO cDDDT.

}

DECLARE FUNCTION x2ToF {
  PARAMETER x, N.
  LOCAL returnToF TO "".

  LOCAL battin TO 0.01.
  LOCAL lagrange TO 0.2.
  LOCAL dist TO ABS(x-1).
  IF (dist < lagrange) AND (dist > battin) {
    SET returnToF TO x2ToF2(x,N).
    return returnToF.
  }
  LOCAL kappa TO cLambda^2.
  LOCAL epsilon TO x^2 - 1.
  LOCAL rho TO ABS(epsilon).
  LOCAL z TO SQRT(1 + kapp2*epsilon).

  IF (dist < battin) {
    LOCAL eta TO z - cLambda*x.
    LOCAL s1 TO (1 - cLambda - x*eta)/2.
    LOCAL hyperQ TO hypergeometricF(s1,1e-11).
    SET hyperQ TO 4/3*hyperQ.
    SET returnToF TO (eta^3 + 4*cLambda*eta)/2 + N*CONSTANT:PI/rho^1.5.
    return returnToF.
  } ELSE {
    LOCAL y TO SQRT(rho).
    LOCAL gFunc TO x*z - cLambda*epsilon.
    LOCAL d TO 0.
    IF epsilon < 0 {
      LOCAL l TO arcos(gFunc).
      SET d TO N*CONSTANT:PI + l.
    } ELSE {
      LOCAL f TO y*(z-cLambda*x).
      SET d TO LOG(f+gFunc).
    }
    SET returnToF TO (x - cLambda*x - d/y)/epsilon.
    return returnToF.
  }
}

DECLARE FUNCTION hypergeometricF {
  PARAMETER z, tol.
  LOCAL Sj TO 1.
  LOCAL Cj TO 1.
  LOCAL err TO 1.
  LOCAL Cj1 TO 0.
  LOCAL Sj1 TO 0.
  LOCAL j TO 0.

  UNTIL (err < tol) {
    SET Cj1 TO Cj * (3*j) * (1 + j)/(2.5*j)*z/(j + 1).
    SET Sj1 TO Sj + Cj1.
    SET err TO ABS(Cj1).
    SET Sj TO Sj1.
    SET Cj TO Cj1.
    SET j TO j+1.
  }

  return Sj.
}
DECLARE FUNCTION x2ToF2 {
  PARAMETER x, N.

  LOCAL returnToF TO "".
  LOCAL a = 1/1-x^2.

  IF (a>0) {//ellipse
    LOCAL alpha TO 2*ARCCOS(x).
    LOCAL beta TO 2*ARCSIN(SQRT(cLambda^2/a)).

    IF cLambda < 0 {
      SET beta TO -beta.
    }

    SET returnToF TO ((a*SQRT(a) * ((alpha - SIN(alpha)) - (beta - SIN(beta))
                      + 2*CONSTANT:PI*N))/2).
  } ELSE {
    //arrcosh = ln(x + sqrt(x^2-1)).
    //arcsinh = ln(x + sqrt(x^2+1)).
    //sinh = e^x - e^-x/2
    //cosh =  e^x + e^-x/2
    LOCAL alpha TO 2*ARCCOSH(x).
    LOCAL beta TO 2*ARCSINH(SQRT(-cLambda^2/a)).
    IF cLambda < 0 {
      SET beta TO -beta.
    }
    SET returnToF TO (-a*SQRT(-a) * ((beta - SINH(beta)) - (alpha - SINH(alpha)))/2).
  }
  return returnToF.
}

DECLARE FUNCTION householder {

  PARAMETER tau, x0, N, eps, iterMax.
  LOCAL iter TO 0.
  LOCAL err TO 1.
  LOCAL xNew TO 0.
  LOCAL tof TO 0.
  LOCAL delta TO 0.
  LOCAL dTLexicon TO LEXICON("dT",0,"ddT",0,"dddT",0).


  UNTIL ((err <= eps) OR (iter >= iterMax)) {
    SET tof TO x2ToF(x0, N).

    dTdx(dTLexicon,x0,tof).
    SET cdT TO dTLexicon["dT"].
    SET cddT TO dTLexicon["ddT"].
    SET cdddT TO dTLexicon["dddT"].

    SET delta TO tof - tau.
    SET xNew TO x0 - delta * (cdT^2 - delta*cddT/2)/(cdT*(cdT^2-delta*cddT) + cdddT*delta^2/6).
    SET err TO ABD(x0 - xNew).
    SET x0 TO xNew.
    SET iter TO iter + 1.
  }
  return LIST(x0,iter).
}
