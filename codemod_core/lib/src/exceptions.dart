class CodeMonException implements Exception {
  CodeMonException(this.message);
  String message;
}

class PatchException extends CodeMonException {
  PatchException(super.message);
}

class InputException extends CodeMonException {
  InputException(super.message);
}

class QuittingException extends CodeMonException {
  QuittingException() : super('The user choose the quit option');
}
