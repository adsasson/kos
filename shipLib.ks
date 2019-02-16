@LAZYGLOBAL OFF.



FUNCTION stageLogic {
  WHEN NOT (SHIP:AVAILABLETHRUST > 0) THEN {
    PRINT "ACTIVATING STAGE " + STAGE:NUMBER AT (0,0).
    STAGE.
    IF STAGE:NUMBER > 0 {
      RETURN TRUE.
    } ELSE {
      RETURN FALSE.
    }
  }
}

FUNCTION performModuleAction {
	PARAMETER moduleName, moduleAction.
	FOR module IN SHIP:MODULESNAMED(moduleName) {
		IF module:HASEVENT(moduleAction) {
			module:DOEVENT(moduleAction).
			PRINT "PERFORMING EVENT: " + moduleAction + " WITH PART " + module:PART:TITLE.
		} ELSE {
			PRINT "Error: " + moduleName + " does not have event " + moduleAction.
		}
	}
}
FUNCTION deployFairings {
  performModuleAction("ModuleProceduralFairing","deploy").
}
FUNCTION extendAntenna {
  performModuleAction("ModuleDeployableAntenna","extend antenna").
 }
 

FUNCTION engageDeployables {
	PRINT "DEPLOYING".
	deployFairings().
	WAIT 1.
	PANELS ON.
	PRINT "DEPLOYING SOLAR PANELS".
	RADIATORS ON.
	PRINT "DELPOYING RADIATIORS".
	extendAntenna().
}
