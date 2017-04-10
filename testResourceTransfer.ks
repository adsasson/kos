@LAZYGLOBAL OFF.

runoncepath("util.ks").

DECLARE FUNCTION resupplyResource {
  PARAMETER resourceName, supplier, receivers, reserve IS 0.

  //assume for now supplier is an element and receiver is a list of elements.
  //iterate over receiver and make a list containing resource

  LOCAL needsResource TO LIST().
  FOR receiverElement IN receivers {
    LOCAL elementResources TO receiverElement:RESOURCES.
    FOR res IN elementResources {
      IF res:NAME = resourceName {
        needsResource:ADD(receiverElement).
        BREAK.
      }
    }
  }

  IF reserve = 0 { //transfer all
    LOCAL transferAction TO TRANSFERALL(resourceName,supplier,needsResource).
  } ELSE { //figure out how much resource supplier has and subtract reserve (if enough)
    LOCAL transferAvailable TO 0.
    LOCAL supplierResources TO supplier:RESOURCES.
    FOR res IN supplierResources {
      IF res:NAME = resourceName {
        SET transferAvailable TO res:AMOUNT.
        BREAK.
      }
    }
    IF transferAvailable > reserve {
      LOCAL transferAction TO TRANSFER(resourceName,supplier,needsResource,(transferAvailable-reserve)).
    } ELSE {
      notify("Insufficient " + resourceName + " available for transfer.").
      RETURN.
    }
  }

  //intiate transfer and notify status
  IF defined transferAction { //sanity check
    SET transferAction:ACTIVE TO TRUE.
    WAIT UNTIL transferAction:STATUS <> "Transferring".
    notify(transferAction:STATUS).
    IF transferAction:STATUS = "Failed" { notify(transferAction:MESSAGE). }
  }
}

DECLARE FUNCTION equalizeResource {
  PARAMETER resourceName IS "All", cShip IS SHIP.

  LOCAL shipResources TO cShip:RESOURCES.
  LOCAL resourceList TO LIST().

  //get resource in question or all
  FOR res IN shipResources {
    IF resourceName <> "All" {
      IF res:NAME = resourceName {
        resourceList:ADD(res).
        BREAK.
      }
    } ELSE {
      SET resourceList TO shipResources.
    }
  }

  //for each resource, calculate avg, and iterate over parts, and transfer to
  //equal average from remaining parts, and remove part
  LOCAL resourceParts TO LIST().
  LOCAL avgAmount TO 0.
  FOR res IN resourceList {
    IF res:CAPACITY <> 0 {
      SET avgAmount TO res:AMOUNT/res:CAPACITY.
    }
    IF avgAmount <> 0 {
      SET resourceParts TO res:PARTS.
      FOR rp IN resourceParts {
        IF resourceParts:LENGTH > 1 {
          LOCAL otherParts TO resourceParts:SUBLIST(1,(resourceParts:LENGTH - 1)).
        } ELSE {
          BREAK. //only one part, nothing to equalize move onto next resource in resource list.
        }
        FOR rpRes IN rp:RESOURCE {
          IF rpRes:NAME = res:NAME {
            LOCAL rpAvg TO rpRes:AMOUNT/rpRes:CAPACITY.
            LOCAL rpDiff TO rpRes:AMOUNT * (avgAmount - rpAvg).
            IF rpDiff > 0 {
              LOCAL transferAction TO TRANSFER(rpRes:NAME,rp,otherParts,rpDiff).
            } ELSE IF rpDiff < 0 {
              LOCAL transferAction TO TRANSFER(rpRes:NAME,otherParts,rp,rpDiff).
            }
            IF defined transferAction { //sanity check
              SET transferAction:ACTIVE TO TRUE.
              WAIT UNTIL transferAction:STATUS <> "Transferring".
              notify(transferAction:STATUS).
              IF transferAction:STATUS = "Failed" { notify(transferAction:MESSAGE). }
            }
            resourceParts:REMOVE(0).
          }
        }
      }
    }
  }
}
