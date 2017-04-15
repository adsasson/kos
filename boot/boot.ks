//boot
//should update files to most current version
//should declare relevant globals
//should run library files
//should load files necessary for ship profile (eg satellites don't need
//landing scripts).
//? check for automated instructions?


GLOBAL surfaceFeature TO LEXICON("Mun",4000,"Minmus",6250,"Ike",13500,"Gilly",
																7500,"Dres",6500,"Moho",7500,"Eeloo",4500,"Bop",
																23000,"Pol",6000,"Tylo",13500,"Vall",9000).

//global constants?
GLOBAL kMu TO SHIP:BODY:MU.

GLOBAL kLiquidFuel TO "LIQUID FUEL".
GLOBAL kOx TO "OXIDIZER".
GLOBAL kMono TO "MONOPROPELLANT".

GLOBAL libList TO LIST("orbitLib.ks","shipLib.ks","utilLib.ks").
GLOBAL launchList TO LIST("launch.ks","ascent.ks").

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
FUNCTION bootMain {
  updateFiles(libList).
	copyFiles(launchList).
  //update craft specific files.
  //check for automated instructions.
}



bootMain().
