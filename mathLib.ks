@LAZYGLOBAL OFF.
//arrcosh = ln(x + sqrt(x^2-1)).
//arcsinh = ln(x + sqrt(x^2+1)).
//sinh = e^x - e^-x/2
//cosh =  e^x + e^-x/2

DECLARE FUNCTION ARCCOSH {
  PARAMETER x.
  RETURN LN(x + SQRT(x^2 - 1)).
}

DECLARE FUNCTION ARCSINH {
  PARAMETER x.
  RETURN LN(x + SQRT(x^2 + 1)).
}

DECLARE FUNCTION COSH {
  PARAMETER x.
  RETURN (CONSTANT:E^x - CONSTANT:E^(-x))/2.
}

DECLARE FUNCTION SINH {
  PARAMETER x.
  RETURN (CONSTANT:E^x + CONSTANT:E^(-x))/2.
}
