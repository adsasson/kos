//boot
//LOAD scripts.

//launch
COPYPATH("0:launch.ks","1:").
COPYPATH("0:ascent.ks","1:").
COPYPATH("0:orbitLib.ks","1:").
COPYPATH("0:executeNode.ks","1:").
COPYPATH("0:shipLib.ks","1:").
COPYPATH("0:orbMechLib.ks","1:").


RUNONCEPATH("1:orbitLib.ks").
RUNONCEPATH("1:shipLib.ks").
RUNONCEPATH("1:orbMechLib.ks").
