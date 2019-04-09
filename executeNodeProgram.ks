@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

PARAMETER inputNode IS NEXTNODE, warpFlag IS FALSE, inputBuffer IS 60.
dependsOn("executenode.ks").
executeNode(inputNode,warpFlag,inputBuffer).
