// This file is modified from lib_gui_box.ks from kOS community library,
//originally based on lib_window.ks from akrOS by akrasuski1.
@LAZYGLOBAL OFF.

function draw_custom_gui_box {
  parameter
  x, y, w, h,
  horizontal_char,
  vertical_char,
  corner_char.

  // Start Input Sanitization

  if x < 0 or x >= terminal:width {
    SET x to max(0,min(terminal:width - 1,x)).
    HUDTEXT("Error: [draw_custom_gui_box] X value outside terminal.", 10, 2, 30, RED, FALSE).
  }

  if y < 0 or y >= (terminal:height - 1) {
    set y to max(0,min(terminal:height - 2,y)).
    HUDTEXT("Error: [draw_custom_gui_box] Y value outside terminal", 10, 2, 30, RED, FALSE).
  }

  if w < 1 or x + w > terminal:width {
    set w to max(1,min(terminal:width - x,w)).
    HUDTEXT("Error: [draw_custom_gui_box] W value outside terminal.", 10, 2, 30, RED, FALSE).
  }

  if h < 1 or y + h >= terminal:height {
    set h to max(1,min(terminal:height - 1  - y,h)).
    HUDTEXT("Error: [draw_custom_gui_box] H value outside terminal.", 10, 2, 30, RED, FALSE).
  }

  // End Input Sanitization

  local horizontal_str is "".
  local i is 1.
  until i > w {
    if i = 1 or i = w {
      set horizontal_str to horizontal_str + corner_char.
      } else {
        set horizontal_str to horizontal_str + horizontal_char.
      }
      set i to i + 1.
    }
    print horizontal_str at(x, y).
    print horizontal_str at(x, y + h - 1).
    set i to 1.
    until i >= h - 1 {
      print vertical_char at(x , y + i).
      print vertical_char at(x + w - 1, y + i).
      set i to i + 1.
    }
  }

function draw_gui_box {
 parameter
  x, y, w, h.
 draw_custom_gui_box(x, y, w, h, "-", "|", "+").
}

function draw_one_char_gui_box {
 parameter
  x, y, w, h,
  border_char.
 draw_custom_gui_box(x, y, w, h, border_char, border_char, border_char).
}

DECLARE FUNCTION intializeRegister {
  PARAMETER registerTerms, defaultX IS TRUE, defaultY IS 0.
  //should print in upper right quadrant of terminal.

  IF defaultX {
    SET defaultX TO TERMINAL:WIDTH/2.
  }

  IF registerTerms:ISTYPE("LIST") {
    LOCAL listIterator TO registerTerms:ITERATOR.
    FOR listTerm IN registerTerms {
      PRINT listTerm + ": " AT (defaultX, defaultY + listIterator:INDEX.).
    }
  } ELSE IF registerTerms:ISTYPE("LEXICON") {
    LOCAL lexiconIterator TO registerTerms:KEYS:ITERATOR.
    FOR registerKey IN registerTerms:KEYS {
      PRINT registerKey + ": " AT (defaultX, defaultY + lexiconIterator:INDEX).
      PRINT registerTerms[registerKey] AT (FLOOR(defaultX * 1.5), defaultY + lexiconIterator:INDEX).
    }
  } ELSE IF registerTerms:ISTYPE("STRING") {
    PRINT registerTerms + ": " AT (defaultX,defaultY).
  }
}

DECLARE FUNCTION printToRegister {
  PARAMETER  registerValues, defaultX IS TRUE, defaultY IS 0.
  IF defaultX {
    SET defaultX TO ROUND(TERMINAL:WIDTH/4 * 3).
  }
  IF registerValues:ISTYPE("LIST") {
    LOCAL listIterator TO registerTerms:ITERATOR.
    FOR listTerm IN registerTerms {
      PRINT listTerm AT (defaultX, defaultY + listIterator:INDEX.).
    }
  } ELSE IF registerValues:ISTYPE("LEXICON") {
    LOCAL lexiconIterator TO registerValues:KEYS:ITERATOR.
    FOR registerKey IN registerTerms:KEYS {
      PRINT registerKey + ": " AT (defaultX, defaultY + lexiconIterator:INDEX).
      PRINT registerValues[registerKey] AT (ROUND(TERMINAL:WIDTH/2), defaultY + lexiconIterator:INDEX).
    }
  } ELSE IF registerValues:ISTYPE("STRING") {
    PRINT registerValues AT (defaultX,defaultY).
  }
}
