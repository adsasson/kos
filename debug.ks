@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

dependsOn("orbitLib.ks").
dependsOn("shipLib.ks").

PARAMETER recoverFile IS "executeNode.ks".

IF recoverFile <> -1 {
  copypath("0:" + recoverFile,"1:").
}
WAIT 1.
clearscreen.
engageDeployables().
orbitalInsertion(90,100000,100000,TRUE,TRUE).
