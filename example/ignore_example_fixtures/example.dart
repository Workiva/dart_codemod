// Example file demonstrating ignore mechanism

// This function will be modified
String example1() {
  return 'test';
}

// codemod_ignore
// This function will be ignored (single line ignore)
String example2() {
  return 'test';
}

// codemod_ignore: This is a special case
// This function will also be ignored with a reason
String example3() {
  return 'test';
}

// codemod_ignore_start
// All functions in this block will be ignored
String example4() {
  return 'test';
}

String example5() {
  return 'test';
}
// codemod_ignore_end

// This function will be modified again
String example6() {
  return 'test';
}
