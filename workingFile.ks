//ignition
@lazyglobal off
local cThrottle IS 0.
local cHeading IS 0.
local cPitch IS 0.

FUNCTION startEngines {
    PARAMETER countdown IS 10.

    //turn off sas
    //lock pitch to up
    //countdown to countdown

    CLEARSCREEN
    
    FROM countdown UNTIL countdown = 0 STEP {SET countdown TO countdown - 1.} DO {
        notify(countdown, "Countdown: ", 2).
        WAIT 1.
    }

    //initialize controls
}

FUNCTION initializeControls {
    PARAMETER aThrottle IS 0.5.
    SAS OFF.
    SET cThrottle TO aThrottle.

    LOCK STEERING TO UP.
    LOCK THROTTLE TO cThrottle.
}



