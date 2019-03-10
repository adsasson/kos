@LAZYGLOBAL OFF.
RUNONCEPATH(bootfile).

dependsOn("rendezvous.ks").

WAIT 1.
//clearscreen.


LOCAL tti IS closestApproachTime().
print "TTI: " + tti.
print "deltaV: " + killRelativeVelocityBurnDeltaV(tti).

killRelativeVelocity().
