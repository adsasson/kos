@LAZYGLOBAL OFF.

GLOBAL bootFile IS SHIP:MODULESNAMED("kosprocessor")[0]:BOOTFILENAME.
GLOBAL verbose IS FALSE.

//basic file handling that the rest of the system depends on
FUNCTION hasFile {
    PARAMETER fileName, volumeLabel.
    SWITCH TO volumeLabel.
    LOCAL fileList IS LIST().
    LIST FILES IN fileList.
    FOR aFile IN fileList {
        IF aFile:NAME = fileName {
            RETURN TRUE.
        }
    }
    return FALSE.
}

FUNCTION dependsOn {
    PARAMETER fileName, volumeID is 1.
    IF not hasFile(fileName, volumeID) {
        download(fileName,volumeID).
        IF verbose PRINT "Downloading dependency " + fileName + ".".
    }
    IF verbose PRINT "Running dependency: " + fileName + ".".
    RUNONCEPATH(volumeID + ":" + fileName).
    WAIT 0.1.
}

function download {
    parameter fileName, volumeLabel, sourceVolumeID IS 0.
    switch to volumeLabel.
    copypath(sourceVolumeID + ":" + fileName, volumeLabel + ":").
}

FUNCTION updateFiles {
	PARAMETER fileList, volumeID IS 1.
	copyFiles(fileList,volumeID).
	runFiles(fileList,volumeID).
}

FUNCTION copyFiles {
	PARAMETER fileList, volumeID IS 1.
	FOR f IN fileList {
		download(f,volumeID).
	}
}

FUNCTION runFiles {
	PARAMETER fileList, volumeID IS 1.
	FOR f IN fileList {
		RUNONCEPATH(volumeID + ":" + f).
  }
}

FUNCTION deleteFiles {
	PARAMETER fileList, volumeID IS 1.
	FOR f IN fileList {
		DELETEPATH(volumeID + ":" + f).
	}
}

FUNCTION notify {
  PARAMETER message, prefix is "kOS: ", location IS "lowerRight".
  LOCAL locationValue IS 3.

  IF location = "upperLeft" {
      SET locationValue TO 1.
  } ELSE IF location = "upperCenter" {
      SET locationValue TO 2.
  } ELSE IF location = "lowerRight" {
      SET locationValue TO 3.
  } ELSE IF location = "lowerCenter" {
      SET locationValue TO 4.
  } ELSE {
      PRINT "error: function: notify: unrecognized location".
      RETURN.
  }
  HUDTEXT(prefix + message, 5, locationValue, 20, YELLOW, TRUE).
}

FUNCTION notifyError {
  PARAMETER message.
  HUDTEXT(message, 10, 2, 20, RED, TRUE).
}

FUNCTION restore {
  PARAMETER fileName, archiveVolumeID IS 0, targetVolume IS 1.
  copypath(archiveVolumeID + ":" + fileName, targetVolume + ":").
  PRINT "Restored " + fileName + " from archive.".
}
 //dependsOn("debug.ks").
