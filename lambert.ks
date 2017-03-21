//LAMBERT PROBLEM
//deltaPhi = 2PI(Thohmann/Touter)
//phiDot = nInner - nOuter

//STEP 1: DETERMINE ORBIT OF TARGET (Lambert) given r(t1) and r(t2)
//STEP 2: DETERMINE DESIRED POSITION OF TARGET
//STEP 3: FIND INTERCEPT TRAJECTORY
//STEP 4: CALCULATE DELTAV

IF HASTARGET {
  LOCAL currentTarget TO TARGET.
  LOCAL rTarget TO currentTarget:POSITION.
  LOCAL vTarget TO currentTarget:VELOCITY.

  LOCAL interceptor TO SHIP.
  LOCAL rInterceptor TO interceptor:POSITION.
  LOCAL vInterceptor TO interceptor:VELOCITY.

  


} ELSE {
  PRINT "NO TARGET SELECTED."
}
