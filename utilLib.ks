@LAZYGLOBAL OFF.


FUNCTION notify {
  PARAMETER message.
  HUDTEXT("kOS: " + message, 5, 3, 20, YELLOW, TRUE).
}


FUNCTION dependsOn {
  PARAMETER fileName, targetVolume IS 1.
  SWITCH TO targetVolume.

  LOCAL fileList TO FILES.
  LOCAL hasFile TO FALSE.

  FOR cFile IN fileList { //find file
    IF cFile:NAME = fileName {
      SET hasFile TO TRUE.
      }
  }
  IF hasFile = FALSE { //if not, get file
    download(fileName,targetVolume).
    PRINT "Downloading dependency.".
  }
  RUNONCEPATH(fileName). //run file
}
