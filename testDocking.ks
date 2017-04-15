runoncepath("testDockingLib").

IF HASTARGET {
  RCS ON.
  LOCAL ports TO getClosestTargetPort().
  LOCAL dockingPort TO ports["dockingPort"].
  LOCAL targetPort TO ports["targetPort"].
  IF ensureRange(targetPort,dockingPort,100,3) {
    moveOrthogonal(targetPort,dockingPort,100,3).
  }
  killRelativeVelocityRCS(targetPort).
  approachPort(targetPort,dockingPort,100,3).
  approachPort(targetPort,dockingPort,50,2).
  approachPort(targetPort,dockingPort,20,1).
  approachPort(targetPort,dockingPort,5,0.5).
  approachPort(targetPort,dockingPort,0,0.25).
  RCS OFF.
} ELSE {
  notify("No Target set.").
}
