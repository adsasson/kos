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

FUNCTION updateLibraryFiles {
  copyLibraryFiles().
  runLibraryFiles().
}

FUNCTION download {
  PARAMETER fileName, volumeLabel, sourceVolumeID IS 0.
  SWITCH TO volumeLabel.
  COPYPATH(sourceVolumeID + ":" + fileName, volumeLabel + ":").
}

FUNCTION copyLibraryFiles {
  PARAMETER targetVolume IS 1.
  FOR library IN libList {
    download(library,targetVolume).
  }
}

FUNCTION runLibraryFiles {
  PARAMETER volumeID IS 1.
  FOR library IN libList {
    RUNONCEPATH(volumeID + ":" + library).
  }
}

FUNCTION bootMain {
  updateLibraryFiles().
  //update craft specific files.
  //check for automated instructions.
}

bootMain().
