@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

dependsOn("rendezvous.ks").

WAIT 1.
//clearscreen.



LOCAL testTime IS testClosestApproachTime().
LOCAL testTime2 IS testClosestApproachTime(TIME:SECONDS + 6000).
PRINT "Test Time: " + round(testTime).
PRINT "Test Time2: " + round(testTime2).
PRINT "TestDistance: " + round(targetDistanceAtTime(testTime)).
PRINT "TestDistance2: " + round(targetDistanceAtTime(testTime2)).
