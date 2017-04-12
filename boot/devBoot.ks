//devBoot
//should do boot
//+ load (and run?) test scripts of interest.
RUNONCEPATH("boot.ks").

LOCAL testList TO LIST(). //put testing files names here.

FUNCTION downloadTestFiles {
  PARAMETER targetVolume IS 1.
  FOR testFile in testList {
    download(testFile,targetVolume).
  }
}
