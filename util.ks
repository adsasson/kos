@LAZYGLOBAL OFF


DECLARE FUNCTION notify {
  PARAMETER message.
  HUDTEXT("kOS: " + message, 5, 2, 50, YELLOW, false).
}

DECLARE FUNCTION download {
  PARAMETER fileName, volumeID IS 1, volumeName IS "", sourceVolumeID IS 0.

  LOCAL volumeLabel.
  IF volumeName <> "" {
    SET volumeLabel TO volumeID.
  } ELSE {
    SET volumeLabel TO volumeName.
  }
  SWITCH TO volumeLabel.
  COPYPATH(sourceVolumeID + ":" + fileName,volumeLabel + ":").
}

DECLARE FUNCTION dependsOn {
  PARAMETER fileName.
  SWITCH TO 1.
  LOCAL fileList.
  LOCAL hasFile TO FALSE.
  LIST FILES IN fileList.
  FOR cFile IN fileList {
    IF cFile:NAME = fileName {
      SET hasFile TO TRUE.
      }
  }
  IF hasFile {
    RUNONCEPATH(fileName).
  } ELSE {
    download(fileName).
    PRINT "Downlaoding dependency.".
    RUNONCEPATH(fileName).
  }
}
