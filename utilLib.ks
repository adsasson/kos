@LAZYGLOBAL OFF.

FUNCTION hasFile {
	PARAMETER fileName, volumeLabel.
	SWITCH TO volumeLabel.
	LOCAL fileList IS LIST().
	LIST FILES IN fileList.
	FOR f in fileList {
		IF f:NAME = fileName {
			RETURN TRUE.
		}
	}
	RETURN FALSE.
}

FUNCTION dependsOn {
  PARAMETER fileName, volumeID IS 1.

  IF NOT hasFile(fileName,volumeID) { //if not, get file
    download(fileName,volumeID).
    PRINT "Downloading dependency " + fileName + ".".
  }
  RUNONCEPATH(volumeID + ":" + fileName). //run file
}

FUNCTION download {
  PARAMETER fileName, volumeLabel, sourceVolumeID IS 0.
  SWITCH TO volumeLabel.
  COPYPATH(sourceVolumeID + ":" + fileName, volumeLabel + ":").
}

FUNCTION notify {
  PARAMETER message.
  HUDTEXT("kOS: " + message, 5, 3, 20, YELLOW, TRUE).
}
