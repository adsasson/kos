@LAZYGLOBAL OFF.

// FUNCTION stageLogic {
// 	//LOCAL engineList TO SHIP:ENGINES.
// 	LOCAL stageFlag IS TRUE.
// 	//LOCAL endOfLine IS TERMINAL.WIDTH - 10.
//
// 	LOCAL engineList TO BUILDLIST("engines").
// 	UNTIL  (NOT stageFlag) {
// 		PRINT "Stage: " + STAGE:NUMBER AT (0,1).
// 		FOR engine IN engineList {
// 			IF engine:FLAMEOUT OR (NOT(SHIP:AVAILABLETHRUST > 0)) {
// 				STAGE.
// 				PRINT "STAGING!" AT (0,1).
// 				IF STAGE:NUMBER = 0 {
// 					SET stageFlag TO FALSE.
// 					RETURN.
// 				}
// 				UNTIL STAGE:READY {
// 					WAIT 0.
// 				}
// 				SET engineList TO BUILDLIST("engines").
// 				CLEARSCREEN.
// 			}
// 		}
// 	}
//
// }

FUNCTION stageLogic {
  WHEN NOT (SHIP:AVAILABLETHRUST > 0) THEN {
    PRINT "ACTIVATING STAGE " + STAGE:NUMBER.
    STAGE.
    IF STAGE:NUMBER > 0 {
      RETURN TRUE.
    } ELSE {
      RETURN FALSE.
    }
  }
}
