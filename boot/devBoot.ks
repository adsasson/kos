//boot
//LOAD scripts.

//launch
COPYPATH("0:launch.ks","1:").
COPYPATH("0:orbitLib.ks","1:").
COPYPATH("0:shipLib.ks","1:").
COPYPATH("0:orbMechLib.ks","1:").
COPYPATH("0:ascent.ks","1:").

//node
copypath("0:executenode.ks","1:").

//landing
COPYPATH("0:descent.ks","1:").
COPYPATH("0:land.ks","1:").




RUNONCEPATH("1:orbitLib.ks").
RUNONCEPATH("1:shipLib.ks").
RUNONCEPATH("1:orbMechLib.ks").
