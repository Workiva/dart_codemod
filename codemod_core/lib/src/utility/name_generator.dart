class NameGenerator {
  static String nextLetter = 'a';
  static String currentBase = '';

  String next() {
    final generated = '$currentBase$nextLetter';

    if (nextLetter == 'z') {
      nextLetter = 'a';
      currentBase = generated;
    } else {
      nextLetter = String.fromCharCode(nextLetter.codeUnitAt(0) + 1);
    }
    return generated;
  }
}

class VariableNameGenerator {
  int _counter = 0;

  String next() {
    final variableName = _generateVariableName(_counter);
    _counter++;
    return variableName;
  }

  String _generateVariableName(int index) {
    const base = 26; // Number of letters in the alphabet
    var variableName = '';

    do {
      final remainder = index % base;
      variableName =
          String.fromCharCode('a'.codeUnitAt(0) + remainder) + variableName;
      index = (index ~/ base) - 1;
    } while (index >= 0);

    return variableName;
  }
}
