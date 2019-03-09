@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

dependsOn("rendezvous.ks").

WAIT 1.
//clearscreen.



LOCAL testTime IS testClosestApproachTime().
PRINT "Test Time: " + round(testTime).
PRINT "TestDistance: " + round(targetDistanceAtTime(testTime)).
