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
  PARAMETER fileName, targetVolume IS 1.

  IF NOT hasFile(fileName,targetVolume) { //if not, get file
    download(fileName,targetVolume).
    PRINT "Downloading dependency " + fileName + ".".
  }
  RUNONCEPATH(targetVolume + ":" + fileName). //run file
}

FUNCTION download {
  PARAMETER fileName, volumeLabel, sourceVolumeID IS 0.
  SWITCH TO volumeLabel.
  COPYPATH(sourceVolumeID + ":" + fileName, volumeLabel + ":").
}

FUNCTION updateFiles {
	PARAMETER fileList, targetVolume IS 1.
	copyFiles(fileList,targetVolume).
	runFiles(fileList,targetVolume).
}

FUNCTION copyFiles {
	PARAMETER fileList, targetVolume IS 1.
	FOR f IN fileList {
		download(f,targetVolume).
	}
}

FUNCTION runFiles {
	PARAMETER fileList, targetVolume IS 1.
	FOR f IN fileList {
		RUNONCEPATH(volumeID + ":" + f).
  }
}

FUNCTION deleteFiles {
	PARAMETER fileList, targetVolume IS 1.
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
