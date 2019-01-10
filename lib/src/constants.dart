const ansiEscapeLiteral = '\x1B';

/// Clears the terminal screen of all content.
const ansiClearScreen = '$ansiEscapeLiteral[2J';

/// Moves the cursor back to the "home" position (top-left).
const ansiCursorHome = '$ansiEscapeLiteral[H';
