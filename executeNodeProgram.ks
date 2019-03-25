@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).
PARAMETER shouldWarp IS TRUE, buffer IS 60.

dependsOn("executeNode.ks").



executeNode(shouldWarp,buffer).
