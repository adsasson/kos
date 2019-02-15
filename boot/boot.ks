@lazyglobal off

//basic file handling that the rest of the system depends on
function hasFile {
    parameter fileName, volumeLabel.
    switch to volumeLabel.
    local fileList is list().
    list files in fileList.
    for aFile in fileList {
        if aFile:NAME = fileName {
            return true.
        }
    }
    return false.
}

function dependsOn {
    parameter fileName, volumeID is 1.
    if not hasFile(fileName, volumeID) {
        download(fileName,volumeID).
        print "Downloading dependency " + fileName + "."
    }
    runoncepath(volumeID + ":" + fileName).
}

function download {
    parameter fileName, volumeLabel, sourceVolumeID IS 0.
    switch to volumeLabel.
    copypath(sourceVolumeID + ":" + fileName, volumeLabel + ":")
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
  PARAMETER message, prefix is "kOS: ", location IS lowerRight.
  local locationValue IS 3.

  IF location = upperLeft {
      locationValue = 1.
  } else if location = upperCenter {
      locationValue = 2.
  } else if location = lowerRight {
      locationValue = 3.
  } else if location = lowerCenter {
      locationValue = 4.
  } else {
      print "error: function: notify: unrecognized location".
      return
  }
  HUDTEXT(prefix + message, 5, locationValue, 20, YELLOW, TRUE).
}
