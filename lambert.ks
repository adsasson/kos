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

DECLARE FUNCTION lambertSolver {

  IF HASTARGET {
    PARAMETER tof.
    PARAMETER currentTarget IS TARGET.
    LOCAL rTarget TO currentTarget:POSITION. //r2
    LOCAL vTarget TO currentTarget:VELOCITY. //v2

    PARAMETER interceptor IS SHIP.
    LOCAL rInterceptor TO interceptor:POSITION. //r1
    LOCAL vInterceptor TO interceptor:VELOCITY. //v1

    PARAMETER cMu IS SHIP:BODY:MU.
    PARAMETER retro IS FALSE.


    //LAMBERT VARIABLES
    LOCAL cVec TO rTarget - rInterceptor.
    LOCAL cMag TO cVec:MAG.
    LOCAL rTargetMag TO rTarget:MAG.
    LOCAL rInterceptorMag TO rInterceptor:MAG.
    LOCAL semiPerimeter TO (cMag + rTargetMag + rInterceptorMag)/2.

    LOCAL rTargetNorm TO rTarget:NORMALIZED.
    LOCAL rInterceptorNorm TO rInterceptor:NORMALIZED.
    LOCAL angMomentumNorm TO VCRS(rInterceptorNorm,rInterceptorNorm).

    LOCAL lambda TO SQRT(1 - cMag/semiPerimeter).

    IF angMomentumNorm:Z < 0 {
      SET lambda TO -lambda.
      LOCAL t1Norm TO VCRS(rInterceptorNorm,angMomentumNorm).
      LOCAL t2Norm TO VCRS(rTargetNorm,angMomentumNorm).
      } ELSE {
        LOCAL t1Norm TO VCRS(angMomentumNorm,rInterceptorNorm).
        LOCAL t2Norm TO VCRS(angMomentumNorm,rTargetNorm).
      }

      IF retro {
        SET lambda to -lambda.
        SET t1Norm:X to -t1Norm:X.
        SET t1Norm:Y to -t1Norm:Y.
        SET t1Norm:Z to -t1Norm:Z.
        SET t2Norm:X to -t2Norm:X.
        SET t2Norm:Y to -t2Norm:Y.
        SET t2Norm:Z to -t2Norm:Z.
      }

      //non dimensional TOF
      LOCAL tau TO (SQRT(2*cMu/semiPerimeter^3))*tof.

    } ELSE {
      PRINT "NO TARGET SELECTED.".
    }
}
DECLARE FUNCTION findXY {
  //require abs(gamma) < 1, T < 0.
  PARAMETER lambda, tau, mulitRev.

  IF (ABS(lambda) < 1) AND (tau < 0) {
    LOCAL nMax TO FLOOR(tau/CONSTANT:PI).

    LOCAL tau00 TO ARCCOS(lambda) + lambda*(SQRT(1-lambda^2)).
    LOCAL tau0 TO tau00 + nMax*CONSTANT:PI.
    LOCAL tau1 TO 2/3 * (1 - lambda^3).
    DT=0.0,DDT=0.0,DDDT=0.0;
    LOCAL dT TO 0.
    LOCAL ddT TO 0.
    LOCAL dddT TO 0.

    IF (tau < tau0) AND (nMax > 0) {
        //hally iteration
        LOCAL iter TO 0.
        LOCAL err TO 1.
        LOCAL tauMin TO tau0.
        LOCAL xOld TO 0.
        LOCAL xNew TO 0.

        UNTIL (err < 1e-13) OR (iter > 12) {
          //dTdX
           LOCAL newDeriv TO dTdx(lambda,xOld,tauMin).
           SET dT TO newDeriv[1].
           SET ddT TO newDeriv[2].
           SET dddT TO newDeriv[3].

           IF NOT (dT = 0) {
             SET xNew TO xOld - dT*ddT/(ddt^2 - dT*dddT/2).
           }
           SET err TO ABS(xOld-xNew).
           SET tauMin TO x2ToF(xNew,lambda,nMax).
           SET xOld TO xNew.
           SET iter TO iter + 1.
        }//end UNTIL
        IF tauMin > tau {
          SET nMax TO nMAx - 1.
        }
    }

    SET nMax TO MIN(nMax,multiRev).

    LOCAL v1List TO LIST().
    LOCAL v2List TO LIST().
    LOCAL iterList TO LIST().
    LOCAL xList TO LIST().

    FROM {LOCAL i IS 1} UNTIL i < (nMax*2+1) STEP {SET i TO i+1} DO {
      v1List:ADD("").
      v2List:ADD("").
      iterList:ADD("").
      xList:ADD("").
    }


    IF tau >= tau00 {
      SET xList[0] TO -(tau-tau00)/(tau - tau00 + 4).
    } ELSE IF tau <= tau1 {
      SET xList[0] TO tau1*(tau1-tau)/(2/5*(1-lambda^5)*tau) + 1.
    } ELSE {
      SET xList[0] TO ((tau/tau00)^0.69)/LOG(tau1/tau00)) - 1.
    }
    //householder
    iterList[0]=householder(tau,xList[0],lambda,0,1e-5,15).

    LOCAL tmp TO "".

    FROM {LOCAL i is 1} UNTIL i < nMax STEP {SET i TO i+1} DO {
      SET tmp TO ((i*CONSTANT:PI^2)/(8*tau))^(2/3).
      SET xList[(2*i-1)] TO ((tmp-1)/(tmp+1)).
      SET iterList[(2*i-1)] TO (householder(tau,xList[(2*i-1)],lambda,i,1e-8,15)).

      SET tmp TO ((8*tau)/(i*CONSTANT:PI))^(2/3).
      SET xList[(2*i)] TO (tmp-1)/(tmp+1).
      SET iterList[(2*i)] TO (householder(tau,xList[2*i],lambda,i,1e-8,15)).
    }


  } ELSE {
    PRINT "some sort of problem with lambda or tau".
  }

}

DECLARE FUNCTION dTdX {
  PARAMETER lambda, x, tau.

  LOCAL umx2 TO 1- x^2.
  LOCAL y TO SQRT(1 - lambda^2*umx2).

  LOCAL dT TO 1/umx2 * (3*tau*x - 2 _ 2*lambda^3*x/y).
  LOCAL ddT TO 1/umx2 * (3*tau + 5*x*dT + 2*(1-lambda^2)*lambda^3/y^3).
  LOCAL dddT TO 1/umx2 * (7*x*ddT + 8*dT - 6*(1-lambda^2)*lambda^2*lambda^3*x/y^3/y^2).

  LOCAL resultList TO LIST(dT,ddT,dddT).

}

DECLARE FUNCTION x2ToF {
  PARAMETER x, lambda, N.
  LOCAL returnToF TO "".

  LOCAL battin TO 0.01.
  LOCAL lagrange TO 0.2.
  LOCAL dist TO ABS(x-1).
  IF (dist < lagrange) AND (dist > battin) {
    SET returnToF TO x2ToF2(x,lambda,N).
    return returnValue.
  }
  LOCAL kappa TO lambda^2.
  LOCAL epsilon TO x^2 - 1.
  LOCAL rho TO ABS(epsilon).
  LOCAL z TO SQRT(1 + kapp2*epsilon).

  IF (dist < battin) {
    LOCAL eta TO z - lambda*x.
    LOCAL s1 TO (1 - lambda - x*eta)/2.
    LOCAL hyperQ TO hypergeometricF(s1,1e-11).
    SET hyperQ TO 4/3*hyperQ.
    SET returnToF TO (eta^3 + 4*lambda*eta)/2 + N*CONSTANT:PI/rho^1.5.
    return returnToF.
  } ELSE {
    LOCAL y TO SQRT(rho).
    LOCAL gFunc TO x*z - lambda*epsilon.
    LOCAL d TO 0.
    IF epsilon < 0 {
      LOCAL l TO arcos(gFunc).
      SET d TO N*CONSTANT:PI + l.
    } ELSE {
      LOCAL f TO y*(z-lambda*x).
      SET d TO LOG(f+gFunc).
    }
    SET returnToF TO (x - lambda*x - d/y)/epsilon.
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
  PARAMETER x, lambda, N.

  LOCAL returnToF TO "".
  LOCAL a = 1/1-x^2.

  IF (a>0) {//ellipse
    LOCAL alpha TO 2*ARCCOS(x).
    LOCAL beta TO 2*ARCSIN(SQRT(lambda^2/a)).

    IF lambda < 0 {
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
    LOCAL beta TO 2*ARCSINH(SQRT(-lambda^2/a)).
    IF lambda < 0 {
      SET beta TO -beta.
    }
    SET returnToF TO (-a*SQRT(-a) * ((beta - SINH(beta)) - (alpha - SINH(alpha)))/2).
  }
  return returnToF.
}

DECLARE FUNCTION householder {
  DECLARE PARAMTER parameterList.
  //PARAMETER tau, x0, lambda, N, eps, iterMax.
  LOCAL iter TO 0.
  LOCAL err TO 1.
  LOCAL xNew TO 0.
  LOCAL tof TO 0.
  LOCAL delta TO 0.
  LOCAL dT TO 0.
  LOCAL ddT TO 0.
  LOCAL dddT TO 0.

  UNTIL ((err <= eps) OR (iter >= iterMax)) {
    SET tof TO x2ToF(x0,lambda, N).

    LOCAL newDeriv TO dTdx(lambda,x0,tof).
    SET dT TO newDeriv[1].
    SET ddT TO newDeriv[2].
    SET dddT TO newDeriv[3].

    SET delta TO tof - tau.
    SET xNew TO x0 - delta * (dT^2 - delta*ddT/2)/(dT*(dT^2-delta*ddT) + dddT*delta^2/6).
    SET err TO ABD(x0 - xNew).
    SET x0 TO xNew.
    SET iter TO iter + 1.
  }
  return x0.
}
