class CodeMonException implements Exception {
  String message;
  CodeMonException(this.message);
}

class PatchException extends CodeMonException {
  PatchException(super.message);
}

class InputException extends CodeMonException {
  InputException(super.message);
}

class QuittingException extends CodeMonException {
  QuittingException() : super("The user choose the quit option");
}
